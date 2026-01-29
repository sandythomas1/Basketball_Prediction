"""
FeatureBuilder: Constructs feature vectors for model prediction.
"""

from datetime import datetime, date
from typing import Optional, Union

import numpy as np

from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker


# Feature columns in exact order expected by the model (from xgb_boost_model.py)
FEATURE_COLS = [
    "elo_home", "elo_away", "elo_diff", "elo_prob",
    "pf_roll_home", "pf_roll_away", "pf_roll_diff",
    "pa_roll_home", "pa_roll_away", "pa_roll_diff",
    "win_roll_home", "win_roll_away", "win_roll_diff",
    "margin_roll_home", "margin_roll_away", "margin_roll_diff",
    "games_in_window_home", "games_in_window_away",
    "home_rest_days", "away_rest_days",
    "home_b2b", "away_b2b", "rest_diff",
    "market_prob_home", "market_prob_away"  # NEW FEATURES
]


class FeatureBuilder:
    """
    Builds feature vectors for NBA game predictions.
    
    Combines Elo ratings and rolling statistics to produce
    the 23-feature vector expected by the XGBoost model.
    """

    def __init__(self, elo_tracker: EloTracker, stats_tracker: StatsTracker):
        """
        Initialize FeatureBuilder with trackers.

        Args:
            elo_tracker: EloTracker instance with current ratings
            stats_tracker: StatsTracker instance with game history
        """
        self.elo_tracker = elo_tracker
        self.stats_tracker = stats_tracker

    def build_features(
        self,
        home_id: int,
        away_id: int,
        game_date: Union[str, date, datetime],
        ml_home: Optional[float] = None, # New argument
        ml_away: Optional[float] = None  # New argument
) -> np.ndarray:
        """
        Build feature vector for a matchup.

        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID
            game_date: Date of the game

        Returns:
            numpy array of shape (23,) with features in FEATURE_COLS order
        """
        # Elo features
        elo_home = self.elo_tracker.get_elo(home_id)
        elo_away = self.elo_tracker.get_elo(away_id)
        elo_diff = elo_home - elo_away
        elo_prob = self.elo_tracker.get_matchup_prob(home_id, away_id)

        # Rolling stats for home team
        home_stats = self.stats_tracker.get_rolling_stats(home_id)
        pf_roll_home = home_stats["pf_roll"]
        pa_roll_home = home_stats["pa_roll"]
        win_roll_home = home_stats["win_roll"]
        margin_roll_home = home_stats["margin_roll"]
        games_in_window_home = home_stats["games_in_window"]

        # Rolling stats for away team
        away_stats = self.stats_tracker.get_rolling_stats(away_id)
        pf_roll_away = away_stats["pf_roll"]
        pa_roll_away = away_stats["pa_roll"]
        win_roll_away = away_stats["win_roll"]
        margin_roll_away = away_stats["margin_roll"]
        games_in_window_away = away_stats["games_in_window"]

        # Diff features
        pf_roll_diff = pf_roll_home - pf_roll_away
        pa_roll_diff = pa_roll_home - pa_roll_away
        win_roll_diff = win_roll_home - win_roll_away
        margin_roll_diff = margin_roll_home - margin_roll_away

        # Rest features
        home_rest_days, home_b2b = self.stats_tracker.get_rest_days(home_id, game_date)
        away_rest_days, away_b2b = self.stats_tracker.get_rest_days(away_id, game_date)
        rest_diff = home_rest_days - away_rest_days

        # Market probability features
        # New: Market Implied Probabilities logic
        def get_implied_prob(ml):
            if ml is None: return 0.5  # Neutral default if odds are missing
            if ml > 0:
                return 100 / (ml + 100)
            return abs(ml) / (abs(ml) + 100)

        market_prob_home = get_implied_prob(ml_home)
        market_prob_away = get_implied_prob(ml_away)

        # Build feature vector in correct order
        features = np.array([
            elo_home,
            elo_away,
            elo_diff,
            elo_prob,
            pf_roll_home,
            pf_roll_away,
            pf_roll_diff,
            pa_roll_home,
            pa_roll_away,
            pa_roll_diff,
            win_roll_home,
            win_roll_away,
            win_roll_diff,
            margin_roll_home,
            margin_roll_away,
            margin_roll_diff,
            games_in_window_home,
            games_in_window_away,
            home_rest_days,
            away_rest_days,
            int(home_b2b),
            int(away_b2b),
            rest_diff,
            market_prob_home, # New
            market_prob_away  # New
        ], dtype=np.float64)

        return features

    def build_features_dict(
        self,
        home_id: int,
        away_id: int,
        game_date: Union[str, date, datetime],
    ) -> dict[str, float]:
        """
        Build feature dictionary for a matchup.

        Useful for debugging and inspection.

        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID
            game_date: Date of the game

        Returns:
            Dictionary mapping feature names to values
        """
        features = self.build_features(home_id, away_id, game_date)
        return dict(zip(FEATURE_COLS, features))

    @staticmethod
    def get_feature_names() -> list[str]:
        """Return list of feature names in order."""
        return list(FEATURE_COLS)

