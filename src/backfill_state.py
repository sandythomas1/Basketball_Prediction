"""
Backfill script to update state with historical games from ESPN.

Fetches completed games from ESPN API starting from the last known date
in your state files up to yesterday, updating Elo ratings and rolling stats.

Usage:
    # Backfill from last known date to yesterday
    python src/backfill_state.py

    # Backfill specific date range
    python src/backfill_state.py --start 2023-04-10 --end 2024-01-01

    # Dry run (show what would be processed)
    python src/backfill_state.py --dry-run

    # Adjust checkpoint interval (default: every 50 games)
    python src/backfill_state.py --checkpoint-interval 100
"""

import argparse
import time
from datetime import datetime, date, timedelta
from pathlib import Path

from core.team_mapper import TeamMapper
from core.state_manager import StateManager
from core.espn_client import ESPNClient
from core.game_processor import GameProcessor
from core.elo_tracker import EloTracker
from core.stats_tracker import StatsTracker


# API delay to be respectful to ESPN servers
API_DELAY_SECONDS = 2.0

# NBA season typically starts in October
NBA_SEASON_START_MONTH = 10


def parse_args():
    parser = argparse.ArgumentParser(
        description="Backfill state with historical NBA games from ESPN."
    )
    parser.add_argument(
        "--start",
        type=str,
        default=None,
        help="Start date (YYYY-MM-DD). Default: auto-detect from state",
    )
    parser.add_argument(
        "--end",
        type=str,
        default=None,
        help="End date (YYYY-MM-DD). Default: yesterday",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be processed without making changes",
    )
    parser.add_argument(
        "--checkpoint-interval",
        type=int,
        default=50,
        help="Save state every N games (default: 50)",
    )
    parser.add_argument(
        "--state-dir",
        type=str,
        default=None,
        help="State directory path. Default: ./state",
    )
    return parser.parse_args()


def detect_last_date_from_stats(stats_tracker: StatsTracker) -> date | None:
    """
    Detect the most recent game date from stats tracker.
    
    Args:
        stats_tracker: StatsTracker instance
        
    Returns:
        Most recent date found, or None if no games
    """
    latest_date = None
    state = stats_tracker.to_dict()
    
    for team_id, games in state.items():
        for game in games:
            game_date_str = game.get("date")
            if game_date_str:
                try:
                    game_date = datetime.fromisoformat(game_date_str).date()
                    if latest_date is None or game_date > latest_date:
                        latest_date = game_date
                except ValueError:
                    continue
    
    return latest_date


def is_new_season(current_date: date, previous_date: date | None) -> bool:
    """
    Check if we've crossed into a new NBA season.
    
    NBA seasons start in October. We detect a new season if:
    - Previous date was before October and current is October or later
    - Or there's a large gap and we're now in October
    
    Args:
        current_date: Current date being processed
        previous_date: Previous date processed (or None)
        
    Returns:
        True if this is the start of a new season
    """
    if previous_date is None:
        return False
    
    # Check if we crossed from before October to October or later
    # in the same year or into the next year's October
    curr_month = current_date.month
    prev_month = previous_date.month
    
    # New season: previous was before October, current is October or later
    # and we're in a new "season year" (Oct onwards)
    if curr_month >= NBA_SEASON_START_MONTH and prev_month < NBA_SEASON_START_MONTH:
        return True
    
    # Also check for year boundary with October
    if current_date.year > previous_date.year and curr_month >= NBA_SEASON_START_MONTH:
        # If previous year ended (April playoffs) and now it's October of next year
        if prev_month < NBA_SEASON_START_MONTH:
            return True
    
    return False


def main():
    args = parse_args()
    
    print("=" * 70)
    print("NBA State Backfill")
    print("=" * 70)
    
    # Initialize components
    state_dir = Path(args.state_dir) if args.state_dir else None
    state_manager = StateManager(state_dir)
    team_mapper = TeamMapper()
    espn_client = ESPNClient(team_mapper)
    
    # Load current state
    print("\nLoading current state...")
    if not state_manager.exists():
        print("Error: No state files found. Run bootstrap_state.py first.")
        return
    
    elo_tracker, stats_tracker = state_manager.load()
    print(f"  Loaded {elo_tracker}")
    print(f"  Loaded {stats_tracker}")
    
    # Determine date range
    if args.start:
        start_date = datetime.strptime(args.start, "%Y-%m-%d").date()
    else:
        # Auto-detect from stats
        last_date = detect_last_date_from_stats(stats_tracker)
        if last_date:
            start_date = last_date + timedelta(days=1)
            print(f"\n  Auto-detected last game date: {last_date}")
        else:
            print("Error: Could not detect last date. Use --start to specify.")
            return
    
    if args.end:
        end_date = datetime.strptime(args.end, "%Y-%m-%d").date()
    else:
        end_date = date.today() - timedelta(days=1)  # Yesterday
    
    print(f"\nDate range: {start_date} to {end_date}")
    
    if start_date > end_date:
        print("\nNothing to backfill - state is up to date!")
        return
    
    total_days = (end_date - start_date).days + 1
    print(f"Total days to process: {total_days}")
    
    if args.dry_run:
        print("\n" + "-" * 70)
        print("DRY RUN - No changes will be made")
        print("-" * 70)
    
    # Create processor
    processor = GameProcessor(elo_tracker, stats_tracker, team_mapper)
    
    # Track progress
    total_games_processed = 0
    games_since_checkpoint = 0
    days_with_games = 0
    days_without_games = 0
    previous_date = start_date - timedelta(days=1)
    
    # Iterate through dates
    current_date = start_date
    
    try:
        while current_date <= end_date:
            # Check for new season (apply Elo regression)
            if is_new_season(current_date, previous_date):
                print(f"\n  >>> New NBA season detected at {current_date}")
                if not args.dry_run:
                    elo_tracker.apply_season_regression()
                    print("      Applied Elo regression to mean")
            
            # Progress indicator
            days_elapsed = (current_date - start_date).days + 1
            progress_pct = (days_elapsed / total_days) * 100
            
            # Fetch games for this date
            try:
                completed_games = espn_client.get_completed_games(current_date)
            except Exception as e:
                print(f"\n  Warning: Failed to fetch {current_date}: {e}")
                current_date += timedelta(days=1)
                time.sleep(API_DELAY_SECONDS)
                continue
            
            if completed_games:
                days_with_games += 1
                
                if args.dry_run:
                    print(f"\n[{progress_pct:5.1f}%] {current_date}: {len(completed_games)} games")
                    for game in completed_games:
                        print(f"         {game.away_team} @ {game.home_team}: "
                              f"{game.away_score}-{game.home_score}")
                else:
                    # Process games
                    processed = 0
                    for game in completed_games:
                        if processor.process_game(game):
                            processed += 1
                    
                    total_games_processed += processed
                    games_since_checkpoint += processed
                    
                    print(f"[{progress_pct:5.1f}%] {current_date}: "
                          f"{processed}/{len(completed_games)} games processed "
                          f"(total: {total_games_processed})")
                    
                    # Checkpoint save
                    if games_since_checkpoint >= args.checkpoint_interval:
                        print(f"         Checkpoint: saving state...")
                        state_manager.save(elo_tracker, stats_tracker)
                        games_since_checkpoint = 0
            else:
                days_without_games += 1
                # Only print every 10 empty days to reduce noise
                if days_without_games % 10 == 0:
                    print(f"[{progress_pct:5.1f}%] {current_date}: No games (skipped {days_without_games} empty days)")
            
            previous_date = current_date
            current_date += timedelta(days=1)
            
            # Rate limiting
            time.sleep(API_DELAY_SECONDS)
            
    except KeyboardInterrupt:
        print("\n\nInterrupted! Saving current progress...")
        if not args.dry_run:
            state_manager.save(elo_tracker, stats_tracker)
            state_manager.set_last_processed_date(previous_date)
            print(f"  State saved up to {previous_date}")
        return
    
    # Final save
    if not args.dry_run and total_games_processed > 0:
        print("\n" + "-" * 70)
        print("Saving final state...")
        state_manager.save(elo_tracker, stats_tracker)
        state_manager.set_last_processed_date(end_date)
        
        # Update total games processed
        current_total = state_manager.get_games_processed_total()
        state_manager.increment_games_processed(total_games_processed)
    
    # Summary
    print("\n" + "=" * 70)
    print("Backfill Complete!")
    print("=" * 70)
    print(f"  Date range: {start_date} to {end_date}")
    print(f"  Days processed: {total_days}")
    print(f"  Days with games: {days_with_games}")
    print(f"  Total games processed: {total_games_processed}")
    
    if not args.dry_run and total_games_processed > 0:
        # Show some top Elo ratings
        print("\nCurrent Top 5 Elo Ratings:")
        all_ratings = elo_tracker.get_all_ratings()
        sorted_ratings = sorted(all_ratings.items(), key=lambda x: x[1], reverse=True)
        
        for team_id, rating in sorted_ratings[:5]:
            team_name = team_mapper.get_team_name(team_id) or f"Team {team_id}"
            print(f"  {team_name}: {rating:.1f}")


if __name__ == "__main__":
    main()

