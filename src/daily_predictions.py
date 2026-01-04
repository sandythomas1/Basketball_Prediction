"""
Daily Predictions CLI - Generate predictions for today's NBA games.

Usage:
    # Predict today's games
    python src/daily_predictions.py

    # Predict specific date
    python src/daily_predictions.py --date 2026-01-03

    # Output to JSON file
    python src/daily_predictions.py --output predictions.json

    # Output to CSV file  
    python src/daily_predictions.py --output predictions.csv

    # App-friendly JSON format
    python src/daily_predictions.py --output predictions.json --app-format

    # Include all games (not just scheduled)
    python src/daily_predictions.py --all-games
"""

import argparse
from datetime import datetime, date
from pathlib import Path

from core import (
    TeamMapper,
    StateManager,
    ESPNClient,
    FeatureBuilder,
    Predictor,
    GamePrediction,
    PredictionOutput,
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate predictions for NBA games."
    )
    parser.add_argument(
        "--date",
        type=str,
        default=None,
        help="Date to predict (YYYY-MM-DD). Default: today",
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        default=None,
        help="Output file path (.json or .csv). Default: print to console",
    )
    parser.add_argument(
        "--app-format",
        action="store_true",
        help="Use simplified JSON format for app consumption",
    )
    parser.add_argument(
        "--all-games",
        action="store_true",
        help="Include all games, not just scheduled ones",
    )
    parser.add_argument(
        "--state-dir",
        type=str,
        default=None,
        help="State directory path. Default: ./state",
    )
    parser.add_argument(
        "--model-path",
        type=str,
        default=None,
        help="Path to XGBoost model. Default: ./models/xgb_v2_modern.json",
    )
    parser.add_argument(
        "--calibrator-path",
        type=str,
        default=None,
        help="Path to calibrator. Default: ./models/calibrator.pkl",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    # Determine target date
    if args.date:
        target_date = datetime.strptime(args.date, "%Y-%m-%d").date()
    else:
        target_date = date.today()

    # Setup paths
    project_root = Path(__file__).parent.parent
    state_dir = Path(args.state_dir) if args.state_dir else project_root / "state"
    model_path = Path(args.model_path) if args.model_path else project_root / "models" / "xgb_v2_modern.json"
    calibrator_path = Path(args.calibrator_path) if args.calibrator_path else project_root / "models" / "calibrator.pkl"

    print(f"{'=' * 70}")
    print(f"NBA Game Predictions - {target_date}")
    print(f"{'=' * 70}")

    # Initialize components
    print("\nLoading components...")
    
    state_manager = StateManager(state_dir)
    team_mapper = TeamMapper()
    espn_client = ESPNClient(team_mapper)

    # Load state
    if not state_manager.exists():
        print("Error: No state files found. Run bootstrap_state.py first.")
        return

    elo_tracker, stats_tracker = state_manager.load()
    print(f"  ✓ {elo_tracker}")
    print(f"  ✓ {stats_tracker}")

    # Load predictor
    if not model_path.exists():
        print(f"Error: Model not found at {model_path}")
        return

    predictor = Predictor(
        model_path,
        calibrator_path if calibrator_path.exists() else None,
    )
    print(f"  ✓ {predictor}")

    # Create feature builder
    feature_builder = FeatureBuilder(elo_tracker, stats_tracker)

    # Fetch games from ESPN
    print(f"\nFetching games for {target_date}...")
    try:
        if args.all_games:
            games = espn_client.get_games(target_date)
            # Filter out completed games
            games = [g for g in games if not g.is_final]
        else:
            games = espn_client.get_scheduled_games(target_date)
    except Exception as e:
        print(f"Error fetching games: {e}")
        return

    print(f"  Found {len(games)} games to predict")

    if not games:
        print("\nNo upcoming games found for this date.")
        return

    # Generate predictions
    print("\nGenerating predictions...")
    predictions = []

    for game in games:
        # Skip if we can't map teams
        if game.home_team_id is None or game.away_team_id is None:
            print(f"  ⚠ Skipping {game.away_team} @ {game.home_team}: Could not map team IDs")
            continue

        home_id = game.home_team_id
        away_id = game.away_team_id

        # Get prediction
        result = predictor.predict_game(home_id, away_id, game.game_date, feature_builder)

        # Get feature details for context
        features = feature_builder.build_features_dict(home_id, away_id, game.game_date)

        # Build prediction object
        pred = GamePrediction(
            game_date=game.game_date,
            game_time=game.game_time,
            home_team=game.home_team,
            away_team=game.away_team,
            home_team_id=home_id,
            away_team_id=away_id,
            prob_home_win=result["prob_home_win"],
            prob_away_win=result["prob_away_win"],
            confidence_tier=result["confidence_tier"],
            home_elo=features["elo_home"],
            away_elo=features["elo_away"],
            elo_diff=features["elo_diff"],
            home_win_pct=features["win_roll_home"],
            away_win_pct=features["win_roll_away"],
            home_margin=features["margin_roll_home"],
            away_margin=features["margin_roll_away"],
            home_rest_days=int(features["home_rest_days"]),
            away_rest_days=int(features["away_rest_days"]),
            home_b2b=bool(features["home_b2b"]),
            away_b2b=bool(features["away_b2b"]),
        )
        predictions.append(pred)

    # Create output
    output = PredictionOutput(predictions)

    # Handle output
    if args.output:
        output_path = Path(args.output)
        
        if output_path.suffix.lower() == ".csv":
            output.save_csv(output_path)
            print(f"\n✓ Saved {len(predictions)} predictions to {output_path}")
        else:
            output.save_json(output_path, app_format=args.app_format)
            print(f"\n✓ Saved {len(predictions)} predictions to {output_path}")
            if args.app_format:
                print("  (app-friendly format)")
    else:
        # Print to console
        output.print_summary()

    # Show quick stats
    if predictions:
        home_favored = sum(1 for p in predictions if p.prob_home_win > 0.5)
        away_favored = len(predictions) - home_favored
        
        print(f"\nSummary:")
        print(f"  Home favored: {home_favored}")
        print(f"  Away favored: {away_favored}")
        
        # Confidence breakdown
        tiers = {}
        for p in predictions:
            tier = p.confidence_tier
            tiers[tier] = tiers.get(tier, 0) + 1
        
        print(f"\nConfidence breakdown:")
        for tier, count in sorted(tiers.items()):
            print(f"  {tier}: {count}")


if __name__ == "__main__":
    main()

