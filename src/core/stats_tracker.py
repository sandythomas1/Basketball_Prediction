"""
StatsTracker: Maintains rolling game statistics per team.
"""

import json
from collections import deque
from datetime import datetime, date
from pathlib import Path
from typing import Optional, Any


class StatsTracker:
    """
    Tracks rolling statistics for all NBA teams.
    
    Maintains a sliding window of the last N games per team
    to compute rolling averages for points, wins, margins, etc.
    """

    WINDOW_SIZE = 10  # Rolling window from features_3.py
    DEFAULT_REST_DAYS = 7  # Conservative "fully rested" default

    def __init__(self, initial_state: Optional[dict[int, list[dict]]] = None):
        """
        Initialize StatsTracker with optional game history.

        Args:
            initial_state: Dict mapping team_id -> list of recent games.
                          Each game is {pf, pa, won, date}.
        """
        self._team_games: dict[int, deque] = {}
        
        if initial_state:
            for team_id, games in initial_state.items():
                team_id = int(team_id)
                self._team_games[team_id] = deque(maxlen=self.WINDOW_SIZE)
                for game in games[-self.WINDOW_SIZE:]:  # Keep only last N
                    # Ensure date is string format
                    game_copy = dict(game)
                    if isinstance(game_copy.get("date"), (datetime, date)):
                        game_copy["date"] = game_copy["date"].isoformat()[:10]
                    self._team_games[team_id].append(game_copy)

    def _get_team_deque(self, team_id: int) -> deque:
        """Get or create the game deque for a team."""
        if team_id not in self._team_games:
            self._team_games[team_id] = deque(maxlen=self.WINDOW_SIZE)
        return self._team_games[team_id]

    def record_game(
        self,
        team_id: int,
        pf: int,
        pa: int,
        won: bool,
        game_date: str | date | datetime,
    ) -> None:
        """
        Record a game result for a team.

        Args:
            team_id: NBA team ID
            pf: Points for (scored by this team)
            pa: Points against (scored by opponent)
            won: Whether this team won
            game_date: Date of the game (str "YYYY-MM-DD" or date/datetime)
        """
        if isinstance(game_date, (datetime, date)):
            game_date = game_date.isoformat()[:10]

        game = {
            "pf": int(pf),
            "pa": int(pa),
            "won": bool(won),
            "date": game_date,
        }

        self._get_team_deque(team_id).append(game)

    def get_rolling_stats(self, team_id: int) -> dict[str, float]:
        """
        Get rolling statistics for a team.

        Returns averages over the last N games (or fewer if not enough games).

        Args:
            team_id: NBA team ID

        Returns:
            Dict with keys: pf_roll, pa_roll, win_roll, margin_roll, games_in_window
        """
        games = self._get_team_deque(team_id)

        if not games:
            # No history - return neutral defaults
            return {
                "pf_roll": 110.0,  # League average-ish
                "pa_roll": 110.0,
                "win_roll": 0.5,
                "margin_roll": 0.0,
                "games_in_window": 0,
            }

        n = len(games)
        pf_sum = sum(g["pf"] for g in games)
        pa_sum = sum(g["pa"] for g in games)
        win_sum = sum(1 for g in games if g["won"])

        pf_roll = pf_sum / n
        pa_roll = pa_sum / n
        win_roll = win_sum / n
        margin_roll = pf_roll - pa_roll

        return {
            "pf_roll": pf_roll,
            "pa_roll": pa_roll,
            "win_roll": win_roll,
            "margin_roll": margin_roll,
            "games_in_window": n,
        }

    def get_rest_days(
        self, team_id: int, game_date: str | date | datetime
    ) -> tuple[int, bool]:
        """
        Calculate rest days since last game for a team.

        Args:
            team_id: NBA team ID
            game_date: Date of the upcoming game

        Returns:
            Tuple of (rest_days, is_back_to_back)
            - rest_days: Days since last game (capped at 14)
            - is_back_to_back: True if rest_days == 1
        """
        if isinstance(game_date, str):
            game_date = datetime.fromisoformat(game_date).date()
        elif isinstance(game_date, datetime):
            game_date = game_date.date()

        games = self._get_team_deque(team_id)

        if not games:
            # No history - assume fully rested
            return self.DEFAULT_REST_DAYS, False

        # Get most recent game date
        last_game = games[-1]
        last_date_str = last_game["date"]
        last_date = datetime.fromisoformat(last_date_str).date()

        rest_days = (game_date - last_date).days

        # Cap rest days (from rest_features.py)
        rest_days = max(0, min(14, rest_days))

        is_b2b = rest_days == 1

        return rest_days, is_b2b

    def to_dict(self) -> dict[int, list[dict]]:
        """
        Serialize tracker state to dictionary.

        Returns:
            Dict mapping team_id -> list of recent games
        """
        return {
            team_id: list(games)
            for team_id, games in self._team_games.items()
        }

    @classmethod
    def from_dict(cls, data: dict) -> "StatsTracker":
        """
        Create StatsTracker from dictionary.

        Args:
            data: Dict mapping team_id -> list of recent games

        Returns:
            New StatsTracker instance
        """
        return cls(initial_state=data)

    def save(self, path: Path) -> None:
        """
        Save tracker state to JSON file.

        Args:
            path: Output file path
        """
        path.parent.mkdir(parents=True, exist_ok=True)
        # Convert int keys to strings for JSON compatibility
        data = {str(k): list(v) for k, v in self._team_games.items()}
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    @classmethod
    def from_file(cls, path: Path) -> "StatsTracker":
        """
        Load tracker state from JSON file.

        Args:
            path: Input file path

        Returns:
            New StatsTracker instance
        """
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Convert string keys back to int
        state = {int(k): v for k, v in data.items()}
        return cls(initial_state=state)

    def get_team_game_count(self, team_id: int) -> int:
        """Get number of games in history for a team."""
        return len(self._get_team_deque(team_id))

    def __repr__(self) -> str:
        return f"StatsTracker({len(self._team_games)} teams)"

