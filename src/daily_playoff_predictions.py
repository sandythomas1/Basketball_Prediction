"""
Daily Playoff Predictions CLI - Generate predictions for today's NBA playoff games.

Usage:
    # Predict today's playoff games
    python src/daily_playoff_predictions.py

    # Predict specific date
    python src/daily_playoff_predictions.py --date 2026-05-14

    # Output to JSON file (app format)
    python src/daily_playoff_predictions.py --output predictions/playoff_daily.json --app-format
"""

import argparse
import json
from datetime import datetime, date
from pathlib import Path

from core import TeamMapper, Predictor, OddsClient, InjuryClient
from core.playoff_state_manager import PlayoffStateManager
from core.playoff_espn_client import PlayoffESPNClient
from core.playoff_feature_builder import PlayoffFeatureBuilder, compute_series_win_probability
from core.playoff_series_tracker import PlayoffSeriesTracker


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate predictions for today's NBA playoff games."
    )
    parser.add_argument("--date", type=str, default=None, help="Date to predict (YYYY-MM-DD). Default: today")
    parser.add_argument("--output", "-o", type=str, default=None, help="Output JSON file path")
    parser.add_argument("--app-format", action="store_true", help="Use simplified JSON format for app consumption")
    parser.add_argument("--state-dir", type=str, default=None, help="State directory path. Default: ./state")
    parser.add_argument("--no-odds", action="store_true", help="Skip fetching betting odds")
    parser.add_argument("--no-injury-adjustments", action="store_true", help="Disable injury-based Elo adjustments")
    parser.add_argument("--season", type=int, default=2026, help="NBA season year. Default: 2026")
    return parser.parse_args()


def main():
    args = parse_args()

    if args.date:
        target_date = datetime.strptime(args.date, "%Y-%m-%d").date()
    else:
        target_date = date.today()

    print(f"{'=' * 70}")
    print(f"NBA Playoff Game Predictions - {target_date}")
    print(f"{'=' * 70}")

    # Setup paths
    project_root = Path(__file__).parent.parent
    state_dir = Path(args.state_dir) if args.state_dir else project_root / "state"
    model_path = project_root / "models" / "xgb_v3_with_injuries.json"
    calibrator_path = project_root / "models" / "calibrator_v3.pkl"

    # Initialize components
    print("\nLoading components...")

    team_mapper = TeamMapper()
    state_manager = PlayoffStateManager(state_dir, season=args.season)
    espn_client = PlayoffESPNClient(team_mapper)

    if not state_manager.exists():
        # Fall back to regular season state if playoff state not yet initialized
        print("  ⚠ No playoff state found — using regular season state as baseline")
        from core import StateManager
        reg_state = StateManager(state_dir)
        if not reg_state.exists():
            print("Error: No state files found at all. Run bootstrap_state.py first.")
            return
        elo_tracker, stats_tracker = reg_state.load()
        from core.playoff_series_tracker import PlayoffSeriesTracker
        series_tracker = PlayoffSeriesTracker(season=args.season)
    else:
        elo_tracker, stats_tracker, series_tracker = state_manager.load()

    print(f"  ✓ {elo_tracker}")
    print(f"  ✓ {stats_tracker}")
    print(f"  ✓ {series_tracker}")

    if not model_path.exists():
        print(f"Error: Model not found at {model_path}")
        return

    predictor = Predictor(model_path, calibrator_path if calibrator_path.exists() else None)
    print(f"  ✓ {predictor}")

    # Initialize injury client
    injury_client = None
    if not args.no_injury_adjustments:
        injury_client = InjuryClient(team_mapper)
        print(f"  ✓ {injury_client} (Elo adjustments enabled)")

    # Create playoff feature builder
    feature_builder = PlayoffFeatureBuilder(elo_tracker, stats_tracker, injury_client=injury_client)

    # Initialize odds client
    odds_dict = {}
    if not args.no_odds:
        odds_client = OddsClient(team_mapper=team_mapper)
        print(f"  ✓ {odds_client}")

    # Fetch play-in and playoff games from ESPN
    print(f"\nFetching games for {target_date}...")
    try:
        play_in_games = espn_client.get_scheduled_play_in_games(target_date)
        playoff_games = espn_client.get_scheduled_playoff_games(target_date)
        games = play_in_games + playoff_games
    except Exception as e:
        print(f"Error fetching games: {e}")
        return

    print(f"  Found {len(play_in_games)} play-in game(s) and {len(playoff_games)} playoff game(s)")

    if not games:
        print("\nNo upcoming playoff games found for this date.")
        if args.output:
            # Write empty output so the daily job doesn't fail
            output_data = {
                "date": target_date.isoformat(),
                "generated_at": datetime.now().isoformat(),
                "round": series_tracker.current_round,
                "count": 0,
                "games": [],
            }
            Path(args.output).parent.mkdir(parents=True, exist_ok=True)
            with open(args.output, "w", encoding="utf-8") as f:
                json.dump(output_data, f, indent=2)
        return

    # Fetch betting odds
    if not args.no_odds:
        print("\nFetching betting odds...")
        try:
            odds_dict = odds_client.get_odds_dict()
            print(f"  Found odds for {len(odds_dict)} matchups")
        except Exception:
            print("  No odds available (using neutral market probabilities)")

    # Pre-warm injury cache
    if injury_client:
        print("\nFetching injury reports...")
        n_teams = feature_builder.prefetch_all_injuries()
        if n_teams:
            print(f"  Cached injury data for {n_teams} teams (valid 4h)")

    # Generate predictions
    print("\nGenerating playoff predictions...")
    predictions = []

    from core.feature_builder import FEATURE_COLS

    for game in games:
        if game.home_team_id is None or game.away_team_id is None:
            print(f"  ⚠ Skipping {game.away_team} @ {game.home_team}: Could not map team IDs")
            continue

        home_id = game.home_team_id
        away_id = game.away_team_id
        is_play_in = getattr(game, "is_play_in", False)

        # Determine series context — play-in games have no series wins tracking
        home_series_wins = 0
        away_series_wins = 0
        game_number = 1
        series_id = game.series_id
        round_name = game.round_name or ("play_in" if is_play_in else None)

        if is_play_in:
            series_context = "Play-In Tournament"
            home_short = game.home_team.split()[-1]
            away_short = game.away_team.split()[-1]
            series_context = f"{away_short} @ {home_short} — Play-In"
        else:
            series_context = "Game 1"
            if series_tracker:
                series = series_tracker.get_series_for_teams(home_id, away_id)
                if series:
                    series_id = series.series_id
                    round_name = series.round_name
                    series_context = series.get_series_context_string()
                    if home_id == series.higher_seed_id:
                        home_series_wins = series.higher_seed_wins
                        away_series_wins = series.lower_seed_wins
                    else:
                        home_series_wins = series.lower_seed_wins
                        away_series_wins = series.higher_seed_wins
                    game_number = series.next_game_number

        # Get odds
        ml_home, ml_away = None, None
        if odds_dict:
            key = (home_id, away_id)
            if key in odds_dict:
                ml_home, ml_away = odds_dict[key]

        # Build features — no series pressure for play-in (it's a single game)
        features = feature_builder.build_features(
            home_id, away_id, target_date.isoformat(),
            ml_home=ml_home, ml_away=ml_away,
            home_series_wins=home_series_wins,
            away_series_wins=away_series_wins,
        )

        # Get prediction
        result = predictor.predict_game(
            home_id, away_id, target_date.isoformat(), feature_builder,
            ml_home=ml_home, ml_away=ml_away,
        )

        # Series win probability only meaningful for best-of-7
        if is_play_in:
            series_win_prob_home = result["prob_home_win"]
            series_win_prob_away = result["prob_away_win"]
        else:
            series_win_prob_home, series_win_prob_away = compute_series_win_probability(
                result["prob_home_win"], home_series_wins, away_series_wins
            )

        features_dict = dict(zip(FEATURE_COLS, features))

        pred_entry = {
            "series_id": series_id,
            "round_name": round_name,
            "conference": game.conference,
            "game_number": game_number,
            "is_play_in": is_play_in,
            "game_date": game.game_date,
            "game_time": game.game_time,
            "home_team": game.home_team,
            "away_team": game.away_team,
            "home_team_id": home_id,
            "away_team_id": away_id,
            "home_series_wins": home_series_wins,
            "away_series_wins": away_series_wins,
            "prediction": {
                "home_win_prob": round(result["prob_home_win"], 3),
                "away_win_prob": round(result["prob_away_win"], 3),
                "confidence_tier": result["confidence_tier"],
                "confidence_score": result.get("confidence_score"),
                "confidence_qualifier": result.get("confidence_qualifier"),
                "series_win_prob_home": series_win_prob_home,
                "series_win_prob_away": series_win_prob_away,
                "series_context": series_context,
                "favored": "home" if result["prob_home_win"] > 0.5 else "away",
            },
            "context": {
                "home_elo": round(features_dict["elo_home"], 1),
                "away_elo": round(features_dict["elo_away"], 1),
                "home_recent_wins": round(features_dict["win_roll_home"], 2),
                "away_recent_wins": round(features_dict["win_roll_away"], 2),
                "home_rest_days": int(features_dict["home_rest_days"]),
                "away_rest_days": int(features_dict["away_rest_days"]),
                "home_b2b": bool(features_dict["home_b2b"]),
                "away_b2b": bool(features_dict["away_b2b"]),
            },
        }
        predictions.append(pred_entry)

        # Print summary
        favored = game.home_team if result["prob_home_win"] > 0.5 else game.away_team
        prob = max(result["prob_home_win"], result["prob_away_win"])
        label = "[PLAY-IN]" if is_play_in else f"[Game {game_number}]"
        print(
            f"  {label} {game.away_team} @ {game.home_team} → "
            f"{favored} {prob:.0%} ({result['confidence_tier']})"
        )

    # Write output
    if args.output:
        output_data = {
            "date": target_date.isoformat(),
            "generated_at": datetime.now().isoformat(),
            "round": series_tracker.current_round,
            "play_in_active": series_tracker.play_in_active or bool(play_in_games),
            "count": len(predictions),
            "games": predictions,
        }
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output_data, f, indent=2)
        print(f"\n✓ Saved {len(predictions)} playoff predictions to {output_path}")
    else:
        print(f"\nGenerated {len(predictions)} playoff predictions")

    print(f"\n✓ Playoff predictions complete!")


if __name__ == "__main__":
    main()
