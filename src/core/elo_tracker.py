"""
EloTracker: Stateful Elo rating management for NBA teams.
"""

import json
from pathlib import Path
from typing import Optional


class EloTracker:
    """
    Manages Elo ratings for all NBA teams.
    
    Elo formula:
        P_home = 1 / (1 + 10^((E_away - E_home - HCA) / 400))
    
    Update after game:
        E_new = E_old + K * (result - expected)
    """

    # Constants from build_elo.py
    DEFAULT_ELO = 1500
    K_FACTOR = 20
    HOME_COURT_ADVANTAGE = 70
    SEASON_CARRYOVER = 0.7  # 70% carry-over, 30% regression to mean

    def __init__(self, initial_ratings: Optional[dict[int, float]] = None):
        """
        Initialize EloTracker with optional starting ratings.

        Args:
            initial_ratings: Dict mapping team_id -> Elo rating.
                             If None, all teams start at DEFAULT_ELO.
        """
        self._ratings: dict[int, float] = {}
        if initial_ratings:
            self._ratings = {int(k): float(v) for k, v in initial_ratings.items()}

    def get_elo(self, team_id: int) -> float:
        """
        Get current Elo rating for a team.

        Args:
            team_id: NBA team ID

        Returns:
            Current Elo rating (defaults to 1500 if team not tracked)
        """
        return self._ratings.get(team_id, self.DEFAULT_ELO)

    def set_elo(self, team_id: int, rating: float) -> None:
        """
        Set Elo rating for a team.

        Args:
            team_id: NBA team ID
            rating: New Elo rating
        """
        self._ratings[team_id] = rating

    def get_matchup_prob(self, home_id: int, away_id: int) -> float:
        """
        Calculate expected probability that home team wins.

        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID

        Returns:
            Probability of home win (0.0 to 1.0)
        """
        e_home = self.get_elo(home_id)
        e_away = self.get_elo(away_id)

        # P_home = 1 / (1 + 10^((E_away - E_home - HCA) / 400))
        exponent = -(e_home - e_away + self.HOME_COURT_ADVANTAGE) / 400
        return 1 / (1 + 10 ** exponent)

    def update(self, home_id: int, away_id: int, home_won: bool) -> tuple[float, float]:
        """
        Update Elo ratings after a game result.

        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID
            home_won: True if home team won

        Returns:
            Tuple of (new_home_elo, new_away_elo)
        """
        e_home = self.get_elo(home_id)
        e_away = self.get_elo(away_id)
        p_home = self.get_matchup_prob(home_id, away_id)

        result = 1.0 if home_won else 0.0

        # Update ratings
        e_home_new = e_home + self.K_FACTOR * (result - p_home)
        e_away_new = e_away - self.K_FACTOR * (result - p_home)

        self._ratings[home_id] = e_home_new
        self._ratings[away_id] = e_away_new

        return e_home_new, e_away_new

    def apply_season_regression(self) -> None:
        """
        Apply season-start regression toward mean.
        
        Should be called at the start of each new season.
        Regresses all teams: 70% current + 30% mean (1500).
        """
        for team_id in list(self._ratings.keys()):
            current = self._ratings[team_id]
            regressed = (self.SEASON_CARRYOVER * current + 
                        (1 - self.SEASON_CARRYOVER) * self.DEFAULT_ELO)
            self._ratings[team_id] = regressed

    def to_dict(self) -> dict[int, float]:
        """
        Serialize ratings to dictionary.

        Returns:
            Dict mapping team_id -> Elo rating
        """
        return dict(self._ratings)

    @classmethod
    def from_dict(cls, data: dict) -> "EloTracker":
        """
        Create EloTracker from dictionary.

        Args:
            data: Dict mapping team_id -> Elo rating

        Returns:
            New EloTracker instance
        """
        return cls(initial_ratings=data)

    def save(self, path: Path) -> None:
        """
        Save ratings to JSON file.

        Args:
            path: Output file path
        """
        path.parent.mkdir(parents=True, exist_ok=True)
        # Convert int keys to strings for JSON compatibility
        data = {str(k): v for k, v in self._ratings.items()}
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    @classmethod
    def from_file(cls, path: Path) -> "EloTracker":
        """
        Load ratings from JSON file.

        Args:
            path: Input file path

        Returns:
            New EloTracker instance
        """
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Convert string keys back to int
        ratings = {int(k): v for k, v in data.items()}
        return cls(initial_ratings=ratings)

    def get_all_ratings(self) -> dict[int, float]:
        """Return all current ratings."""
        return dict(self._ratings)

    def __repr__(self) -> str:
        return f"EloTracker({len(self._ratings)} teams)"

