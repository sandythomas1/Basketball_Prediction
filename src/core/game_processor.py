"""
GameProcessor: Updates tracker state after games complete.
"""

from typing import List, Set, Tuple

from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker
from .team_mapper import TeamMapper
from .espn_client import GameResult


class GameProcessor:
    """
    Processes completed games and updates tracker state.
    
    Updates both Elo ratings and rolling statistics for each team
    after a game completes.
    """

    def __init__(
        self,
        elo_tracker: EloTracker,
        stats_tracker: StatsTracker,
        team_mapper: TeamMapper,
    ):
        """
        Initialize GameProcessor.

        Args:
            elo_tracker: EloTracker instance to update
            stats_tracker: StatsTracker instance to update
            team_mapper: TeamMapper for name -> ID conversion
        """
        self.elo_tracker = elo_tracker
        self.stats_tracker = stats_tracker
        self.team_mapper = team_mapper
        self._processed_games: Set[Tuple[str, int, int]] = set()

    def _game_key(self, result: GameResult) -> Tuple[str, int, int]:
        """Generate unique key for a game to prevent double-processing."""
        return (result.game_date, result.home_team_id or 0, result.away_team_id or 0)

    def process_game(self, result: GameResult, force: bool = False) -> bool:
        """
        Process a single game result.

        Updates Elo ratings and records stats for both teams.

        Args:
            result: GameResult to process
            force: If True, process even if already processed this session

        Returns:
            True if game was processed, False if skipped
        """
        # Skip non-final games
        if not result.is_final:
            return False

        # Check for valid team IDs
        if result.home_team_id is None or result.away_team_id is None:
            print(f"Warning: Could not map teams for {result}")
            return False

        # Skip if already processed this session
        key = self._game_key(result)
        if not force and key in self._processed_games:
            return False

        home_id = result.home_team_id
        away_id = result.away_team_id
        home_won = result.home_won

        # Update Elo ratings
        self.elo_tracker.update(home_id, away_id, home_won)

        # Record game for home team
        self.stats_tracker.record_game(
            team_id=home_id,
            pf=result.home_score,
            pa=result.away_score,
            won=home_won,
            game_date=result.game_date,
        )

        # Record game for away team
        self.stats_tracker.record_game(
            team_id=away_id,
            pf=result.away_score,
            pa=result.home_score,
            won=not home_won,
            game_date=result.game_date,
        )

        # Mark as processed
        self._processed_games.add(key)

        return True

    def process_games(self, results: List[GameResult], force: bool = False) -> int:
        """
        Process multiple game results.

        Args:
            results: List of GameResult objects
            force: If True, process even if already processed

        Returns:
            Number of games successfully processed
        """
        count = 0
        for result in results:
            if self.process_game(result, force=force):
                count += 1
        return count

    def get_processed_count(self) -> int:
        """Get number of games processed this session."""
        return len(self._processed_games)

    def clear_processed(self) -> None:
        """Clear the set of processed games for this session."""
        self._processed_games.clear()

    def preview_game(self, result: GameResult) -> dict:
        """
        Preview what would happen if a game was processed.

        Useful for dry-run mode.

        Args:
            result: GameResult to preview

        Returns:
            Dict with preview information
        """
        if not result.is_final:
            return {
                "would_process": False,
                "reason": "Game not final",
            }

        if result.home_team_id is None or result.away_team_id is None:
            return {
                "would_process": False,
                "reason": "Could not map team names to IDs",
            }

        home_id = result.home_team_id
        away_id = result.away_team_id

        current_home_elo = self.elo_tracker.get_elo(home_id)
        current_away_elo = self.elo_tracker.get_elo(away_id)

        # Calculate expected changes
        p_home = self.elo_tracker.get_matchup_prob(home_id, away_id)
        actual = 1.0 if result.home_won else 0.0
        elo_change = self.elo_tracker.K_FACTOR * (actual - p_home)

        return {
            "would_process": True,
            "home_team": result.home_team,
            "away_team": result.away_team,
            "score": f"{result.home_score}-{result.away_score}",
            "winner": "home" if result.home_won else "away",
            "current_home_elo": round(current_home_elo, 1),
            "current_away_elo": round(current_away_elo, 1),
            "elo_change_home": round(elo_change, 1),
            "elo_change_away": round(-elo_change, 1),
            "new_home_elo": round(current_home_elo + elo_change, 1),
            "new_away_elo": round(current_away_elo - elo_change, 1),
        }

    def preview_games(self, results: List[GameResult]) -> List[dict]:
        """
        Preview what would happen for multiple games.

        Args:
            results: List of GameResult objects

        Returns:
            List of preview dicts
        """
        return [self.preview_game(r) for r in results]

    def __repr__(self) -> str:
        return f"GameProcessor(processed={self.get_processed_count()})"

