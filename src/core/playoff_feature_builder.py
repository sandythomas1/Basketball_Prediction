"""
PlayoffFeatureBuilder: Constructs feature vectors for playoff game predictions.

Extends FeatureBuilder with playoff-specific series context:
  - Series pressure Elo adjustments (elimination games, closeout games, etc.)
  - Home court rotation following NBA playoff seeding rules
  - Series win probability using Markov chain DP

The XGBoost model (31 features) is reused as-is. Series context is injected
as temporary Elo pre-adjustments — never permanently modifying state.
"""

from datetime import datetime, date
from functools import lru_cache
from typing import Optional, Union

import numpy as np

from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker
from .feature_builder import FeatureBuilder


# Elo adjustments for series context (applied temporarily before prediction)
# These numbers are conservative — the model already captures form/strength.
CLOSEOUT_BOOST = 20.0      # Team needs 1 more win to close out
ELIMINATION_PENALTY = -20.0  # Team facing elimination
DOWN_3_0_PENALTY = -25.0    # Down 3-0 (historically almost impossible to come back)
UP_3_0_BOOST = 15.0         # Up 3-0


def series_pressure_elo_adjustment(my_wins: int, opp_wins: int) -> float:
    """
    Calculate temporary Elo adjustment for series context.

    Applied ONLY during prediction — never persisted to state.

    Args:
        my_wins: Number of wins this team has in the series
        opp_wins: Number of wins the opponent has in the series

    Returns:
        Elo point adjustment (positive = boost, negative = penalty)
    """
    wins_needed = 4 - my_wins
    opp_wins_needed = 4 - opp_wins

    # Down 3-0 — historically fatal
    if my_wins == 0 and opp_wins == 3:
        return DOWN_3_0_PENALTY

    # Up 3-0 — near-certain winner
    if my_wins == 3 and opp_wins == 0:
        return UP_3_0_BOOST

    # Closeout opportunity
    if wins_needed == 1 and opp_wins_needed > 1:
        return CLOSEOUT_BOOST

    # Facing elimination
    if opp_wins_needed == 1 and wins_needed > 1:
        return ELIMINATION_PENALTY

    return 0.0


def compute_series_win_probability(
    game_win_prob: float,
    home_wins: int,
    away_wins: int,
) -> tuple[float, float]:
    """
    Compute series win probability using a Markov chain DP.

    Given the win probability for the home team in the NEXT game
    and the current series score, compute the probability that
    each team wins the full best-of-7 series.

    This uses a simplified model where p_game is constant for
    remaining games (it reflects current state, which is the
    best single estimate available).

    Args:
        game_win_prob: Probability home team wins the next game (0.0-1.0)
        home_wins: Number of wins the "home team" has in the series so far
        away_wins: Number of wins the "away team" has in the series so far

    Returns:
        Tuple of (prob_home_wins_series, prob_away_wins_series)
    """
    # Wins still needed for each team to win the series
    home_needs = 4 - home_wins
    away_needs = 4 - away_wins

    # Already won
    if home_needs <= 0:
        return 1.0, 0.0
    if away_needs <= 0:
        return 0.0, 1.0

    p = game_win_prob
    q = 1.0 - p

    # DP: dp[h][a] = probability home team wins series
    # given they still need h wins and away team needs a wins
    # Use a simple 5x5 table (max 4 wins needed each)
    dp = [[0.0] * 5 for _ in range(5)]

    # Base cases
    for a in range(1, 5):
        dp[0][a] = 1.0  # Home already won
    for h in range(1, 5):
        dp[h][0] = 0.0  # Away already won

    # Fill in the rest
    for h in range(1, 5):
        for a in range(1, 5):
            dp[h][a] = p * dp[h - 1][a] + q * dp[h][a - 1]

    prob_home = dp[home_needs][away_needs]
    return round(prob_home, 4), round(1.0 - prob_home, 4)


class PlayoffFeatureBuilder(FeatureBuilder):
    """
    Builds feature vectors for NBA playoff game predictions.

    Extends FeatureBuilder with series context:
    - Applies temporary Elo adjustments for series pressure
    - Exposes series win probability calculation
    - Handles playoff home court logic

    The same XGBoost 31-feature vector is produced — no model retraining needed.
    """

    def build_features(
        self,
        home_id: int,
        away_id: int,
        game_date: Union[str, date, datetime],
        ml_home: Optional[float] = None,
        ml_away: Optional[float] = None,
        home_series_wins: int = 0,
        away_series_wins: int = 0,
    ) -> np.ndarray:
        """
        Build playoff feature vector with series context.

        Series context is injected as temporary Elo pre-adjustments.
        The original Elo ratings are restored after building features
        — state is never permanently modified.

        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID
            game_date: Date of the game
            ml_home: Home team moneyline odds (optional)
            ml_away: Away team moneyline odds (optional)
            home_series_wins: Wins the home team has in this series
            away_series_wins: Wins the away team has in this series

        Returns:
            numpy array of shape (31,) — same format as regular season
        """
        # Calculate series pressure adjustments
        home_pressure = series_pressure_elo_adjustment(home_series_wins, away_series_wins)
        away_pressure = series_pressure_elo_adjustment(away_series_wins, home_series_wins)

        if home_pressure != 0.0 or away_pressure != 0.0:
            # Temporarily adjust Elo for this prediction
            original_home = self.elo_tracker.get_elo(home_id)
            original_away = self.elo_tracker.get_elo(away_id)

            self.elo_tracker._ratings[home_id] = original_home + home_pressure
            self.elo_tracker._ratings[away_id] = original_away + away_pressure

            try:
                features = super().build_features(home_id, away_id, game_date, ml_home, ml_away)
            finally:
                # Always restore original Elo — even if build_features raises
                self.elo_tracker._ratings[home_id] = original_home
                self.elo_tracker._ratings[away_id] = original_away
        else:
            features = super().build_features(home_id, away_id, game_date, ml_home, ml_away)

        return features

    def build_features_with_series(
        self,
        home_id: int,
        away_id: int,
        game_date: Union[str, date, datetime],
        ml_home: Optional[float] = None,
        ml_away: Optional[float] = None,
        home_series_wins: int = 0,
        away_series_wins: int = 0,
    ) -> tuple[np.ndarray, tuple[float, float]]:
        """
        Build features AND compute series win probability in one call.

        Returns:
            Tuple of (feature_array, (series_win_prob_home, series_win_prob_away))
        """
        features = self.build_features(
            home_id, away_id, game_date, ml_home, ml_away,
            home_series_wins=home_series_wins,
            away_series_wins=away_series_wins,
        )

        # We need the raw game win probability to compute series probability.
        # Use the base Elo probability as a proxy here — the predictor will
        # compute the calibrated probability, and compute_series_win_probability
        # will be called again with the actual model output downstream.
        elo_game_prob = self.elo_tracker.get_matchup_prob(home_id, away_id)
        series_probs = compute_series_win_probability(
            elo_game_prob, home_series_wins, away_series_wins
        )

        return features, series_probs
