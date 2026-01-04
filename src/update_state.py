"""
CLI script to update state with completed games from ESPN.

Usage:
    # Process today's games
    python src/update_state.py

    # Process specific date
    python src/update_state.py --date 2026-01-02

    # Dry run (show what would be processed)
    python src/update_state.py --dry-run

    # Force re-process even if date was already processed
    python src/update_state.py --force
"""

import argparse
from datetime import datetime, date
from pathlib import Path

from core import (
    TeamMapper,
    StateManager,
    ESPNClient,
    GameProcessor,
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Update state with completed NBA games from ESPN."
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
    return parser.parse_args()


def main():
    args = parse_args()

    # Determine target date
    if args.date:
        target_date = datetime.strptime(args.date, "%Y-%m-%d").date()
    else:
        target_date = date.today()

    print(f"=" * 60)
    print(f"NBA State Update - {target_date}")
    print(f"=" * 60)

    # Initialize components
    state_dir = Path(args.state_dir) if args.state_dir else None
    state_manager = StateManager(state_dir)
    team_mapper = TeamMapper()
    espn_client = ESPNClient(team_mapper)

    # Check if already processed
    last_processed = state_manager.get_last_processed_date()
    if last_processed and last_processed >= target_date and not args.force:
        print(f"\nDate {target_date} already processed (last: {last_processed})")
        print("Use --force to re-process")
        return

    # Load current state
    print("\nLoading state...")
    if state_manager.exists():
        elo_tracker, stats_tracker = state_manager.load()
        print(f"  Loaded {elo_tracker}")
        print(f"  Loaded {stats_tracker}")
    else:
        print("  No existing state found. Run bootstrap_state.py first.")
        return

    # Fetch games from ESPN
    print(f"\nFetching games for {target_date} from ESPN...")
    try:
        all_games = espn_client.get_games(target_date)
        completed_games = [g for g in all_games if g.is_final]
    except Exception as e:
        print(f"Error fetching games: {e}")
        return

    print(f"  Total games: {len(all_games)}")
    print(f"  Completed: {len(completed_games)}")

    if not completed_games:
        print("\nNo completed games to process.")
        return

    # Create processor
    processor = GameProcessor(elo_tracker, stats_tracker, team_mapper)

    # Dry run mode
    if args.dry_run:
        print("\n" + "-" * 60)
        print("DRY RUN - No changes will be made")
        print("-" * 60)
        
        previews = processor.preview_games(completed_games)
        for preview in previews:
            if preview["would_process"]:
                print(f"\n{preview['away_team']} @ {preview['home_team']}")
                print(f"  Score: {preview['score']} (Winner: {preview['winner']})")
                print(f"  Home Elo: {preview['current_home_elo']} → {preview['new_home_elo']} ({preview['elo_change_home']:+.1f})")
                print(f"  Away Elo: {preview['current_away_elo']} → {preview['new_away_elo']} ({preview['elo_change_away']:+.1f})")
            else:
                print(f"\n[SKIP] {preview.get('reason', 'Unknown reason')}")
        
        print(f"\nWould process {len([p for p in previews if p['would_process']])} games")
        return

    # Process games
    print("\nProcessing games...")
    processed_count = 0
    
    for game in completed_games:
        preview = processor.preview_game(game)
        if preview["would_process"]:
            success = processor.process_game(game)
            if success:
                processed_count += 1
                print(f"  ✓ {game.away_team} @ {game.home_team}: {game.home_score}-{game.away_score}")
                print(f"    Elo: {preview['current_home_elo']} → {preview['new_home_elo']} (home), "
                      f"{preview['current_away_elo']} → {preview['new_away_elo']} (away)")
        else:
            print(f"  ✗ Skipped: {game} - {preview.get('reason', '')}")

    if processed_count == 0:
        print("\nNo games were processed.")
        return

    # Save updated state
    print(f"\nSaving state...")
    state_manager.save(elo_tracker, stats_tracker)
    state_manager.set_last_processed_date(target_date)
    total = state_manager.increment_games_processed(processed_count)

    print(f"  Processed {processed_count} games")
    print(f"  Total games processed: {total}")
    print(f"  Last processed date: {target_date}")

    # Show updated Elo for recently played teams
    print("\n" + "-" * 60)
    print("Updated Elo Ratings (teams that played today)")
    print("-" * 60)
    
    played_teams = set()
    for game in completed_games:
        if game.home_team_id:
            played_teams.add((game.home_team_id, game.home_team))
        if game.away_team_id:
            played_teams.add((game.away_team_id, game.away_team))

    for team_id, team_name in sorted(played_teams, key=lambda x: elo_tracker.get_elo(x[0]), reverse=True):
        elo = elo_tracker.get_elo(team_id)
        print(f"  {team_name}: {elo:.1f}")

    print(f"\n✓ State update complete!")


if __name__ == "__main__":
    main()

