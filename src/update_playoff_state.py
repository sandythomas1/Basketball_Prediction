"""
CLI script to update playoff state with completed playoff games from ESPN.

Usage:
    # Process today's playoff games
    python src/update_playoff_state.py

    # Process specific date
    python src/update_playoff_state.py --date 2026-05-14

    # Dry run (show what would be processed)
    python src/update_playoff_state.py --dry-run

    # Force re-process even if date was already processed
    python src/update_playoff_state.py --force
"""

import argparse
from datetime import datetime, date
from pathlib import Path

from core import TeamMapper
from core.elo_tracker import EloTracker
from core.playoff_state_manager import PlayoffStateManager
from core.playoff_espn_client import PlayoffESPNClient
from core.playoff_series_tracker import PlayoffSeriesTracker

# Playoff Elo K-factor (higher than regular season K=20 to reflect higher stakes)
PLAYOFF_K_FACTOR = 30.0
HOME_COURT_ADVANTAGE = 70.0  # Same as regular season


def update_playoff_elo(
    elo_tracker: EloTracker,
    home_id: int,
    away_id: int,
    home_won: bool,
) -> tuple[float, float]:
    """
    Update playoff Elo with K=30.

    Returns:
        Tuple of (elo_change_home, elo_change_away)
    """
    e_home = elo_tracker.get_elo(home_id)
    e_away = elo_tracker.get_elo(away_id)

    # Expected win probability (includes home court advantage)
    p_home = 1.0 / (1.0 + 10.0 ** (-(e_home - e_away + HOME_COURT_ADVANTAGE) / 400.0))

    result = 1.0 if home_won else 0.0
    change = PLAYOFF_K_FACTOR * (result - p_home)

    elo_tracker._ratings[home_id] = e_home + change
    elo_tracker._ratings[away_id] = e_away - change

    return change, -change


def parse_args():
    parser = argparse.ArgumentParser(
        description="Update playoff state with completed NBA playoff games from ESPN."
    )
    parser.add_argument(
        "--date",
        type=str,
        default=None,
        help="Date to process (YYYY-MM-DD). Default: today",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be processed without making changes",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Process even if date was already processed",
    )
    parser.add_argument(
        "--state-dir",
        type=str,
        default=None,
        help="State directory path. Default: ./state",
    )
    parser.add_argument(
        "--season",
        type=int,
        default=2026,
        help="NBA season year (e.g. 2026). Default: 2026",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    if args.date:
        target_date = datetime.strptime(args.date, "%Y-%m-%d").date()
    else:
        target_date = date.today()

    print(f"{'=' * 60}")
    print(f"NBA Playoff State Update - {target_date}")
    print(f"{'=' * 60}")

    # Initialize components
    state_dir = Path(args.state_dir) if args.state_dir else None
    state_manager = PlayoffStateManager(state_dir, season=args.season)
    team_mapper = TeamMapper()
    espn_client = PlayoffESPNClient(team_mapper)

    # Check if already processed
    last_processed = state_manager.get_last_processed_date()
    if last_processed and last_processed >= target_date and not args.force:
        print(f"\nDate {target_date} already processed (last: {last_processed})")
        print("Use --force to re-process")
        return

    # Load current state
    print("\nLoading playoff state...")
    elo_tracker, stats_tracker, series_tracker = state_manager.load()
    print(f"  Loaded {elo_tracker}")
    print(f"  Loaded {stats_tracker}")
    print(f"  Loaded {series_tracker}")

    # Fetch completed playoff games from ESPN
    print(f"\nFetching playoff games for {target_date} from ESPN...")
    try:
        completed_games = espn_client.get_completed_playoff_games(target_date)
    except Exception as e:
        print(f"Error fetching games: {e}")
        return

    print(f"  Completed playoff games: {len(completed_games)}")

    if not completed_games:
        print("\nNo completed playoff games to process.")
        return

    # Dry run mode
    if args.dry_run:
        print("\n" + "-" * 60)
        print("DRY RUN - No changes will be made")
        print("-" * 60)
        for game in completed_games:
            winner = game.home_team if game.home_score > game.away_score else game.away_team
            print(f"\n  {game.away_team} @ {game.home_team}: {game.away_score}-{game.home_score}")
            print(f"    Winner: {winner}")
            if game.series_id:
                print(f"    Series: {game.series_id} (Game {game.game_number})")
        print(f"\nWould process {len(completed_games)} playoff games")
        return

    # Process games
    print("\nProcessing playoff games...")
    processed_count = 0

    for game in completed_games:
        if game.home_team_id is None or game.away_team_id is None:
            print(f"  ⚠ Skipping {game.away_team} @ {game.home_team}: Could not map team IDs")
            continue

        home_id = game.home_team_id
        away_id = game.away_team_id
        home_won = game.home_score > game.away_score
        winner = game.home_team if home_won else game.away_team

        # Update playoff Elo (K=30)
        elo_change_home, elo_change_away = update_playoff_elo(
            elo_tracker, home_id, away_id, home_won
        )

        # Update rolling stats (playoff games flow into the shared rolling window)
        stats_tracker.record_game(
            team_id=home_id,
            pf=game.home_score,
            pa=game.away_score,
            won=home_won,
            game_date=game.game_date,
        )
        stats_tracker.record_game(
            team_id=away_id,
            pf=game.away_score,
            pa=game.home_score,
            won=not home_won,
            game_date=game.game_date,
        )

        # Update series tracker
        if game.series_id:
            series = series_tracker.get_series(game.series_id)
            if series:
                series.record_game(
                    game_date=game.game_date,
                    home_score=game.home_score,
                    away_score=game.away_score,
                    home_team_id=home_id,
                    away_team_id=away_id,
                )
                print(
                    f"  ✓ {game.away_team} @ {game.home_team}: {game.away_score}-{game.home_score} "
                    f"(W: {winner}) | Series: {series.higher_seed_wins}-{series.lower_seed_wins} | "
                    f"Elo: {elo_change_home:+.1f}/{elo_change_away:+.1f}"
                )
            else:
                print(f"  ✓ {game.away_team} @ {game.home_team}: {game.away_score}-{game.home_score} (series not tracked)")
        else:
            print(f"  ✓ {game.away_team} @ {game.home_team}: {game.away_score}-{game.home_score} (no series ID)")

        processed_count += 1

    if processed_count == 0:
        print("\nNo playoff games were processed.")
        return

    # Save updated state
    print(f"\nSaving playoff state...")
    state_manager.save(elo_tracker, stats_tracker, series_tracker)
    state_manager.set_last_processed_date(target_date)
    total = state_manager.increment_games_processed(processed_count)

    print(f"  Processed {processed_count} playoff games")
    print(f"  Total playoff games processed: {total}")
    print(f"\n✓ Playoff state update complete!")


if __name__ == "__main__":
    main()
