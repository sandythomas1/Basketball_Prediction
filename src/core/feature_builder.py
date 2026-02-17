"""
FeatureBuilder: Constructs feature vectors for model prediction.
"""

from datetime import datetime, date
from typing import Optional, Union

import numpy as np

from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker

# Import injury-related components (optional dependencies)
try:
    from .injury_client import InjuryClient, calculate_injury_adjustment
    from .injury_cache import InjuryCache, get_global_cache
    from .config import (
        INJURY_ADJUSTMENTS_ENABLED,
        LOG_INJURY_ADJUSTMENTS,
        INJURY_FALLBACK_ON_ERROR,
        INJURY_USE_STALE_CACHE,
    )
    INJURY_SUPPORT_AVAILABLE = True
except ImportError:
    INJURY_SUPPORT_AVAILABLE = False
    INJURY_ADJUSTMENTS_ENABLED = False
    LOG_INJURY_ADJUSTMENTS = False
    INJURY_FALLBACK_ON_ERROR = True
    INJURY_USE_STALE_CACHE = True


# Feature columns in exact order expected by the model (from xgb_boost_model.py)
FEATURE_COLS = [
    # Elo ratings
    "elo_home", "elo_away", "elo_diff", "elo_prob",
    # Rolling scoring stats
    "pf_roll_home", "pf_roll_away", "pf_roll_diff",
    "pa_roll_home", "pa_roll_away", "pa_roll_diff",
    # Rolling win/margin stats
    "win_roll_home", "win_roll_away", "win_roll_diff",
    "margin_roll_home", "margin_roll_away", "margin_roll_diff",
    # Game-window context
    "games_in_window_home", "games_in_window_away",
    # Rest / fatigue
    "home_rest_days", "away_rest_days",
    "home_b2b", "away_b2b", "rest_diff",
    # Betting market probabilities
    "market_prob_home", "market_prob_away",
    # Injury features (zero-imputed when unavailable; live ESPN data at inference)
    "home_players_out", "away_players_out",
    "home_players_questionable", "away_players_questionable",
    "home_injury_severity", "away_injury_severity",
]


class FeatureBuilder:
    """
    Builds feature vectors for NBA game predictions.
    
    Combines Elo ratings, rolling statistics, injury features, and optional
    market odds to produce the 31-feature vector expected by the XGBoost model.
    """

    def __init__(
        self, 
        elo_tracker: EloTracker, 
        stats_tracker: StatsTracker,
        injury_client: Optional['InjuryClient'] = None,
        injury_cache: Optional['InjuryCache'] = None,
    ):
        """
        Initialize FeatureBuilder with trackers.

        Args:
            elo_tracker: EloTracker instance with current ratings
            stats_tracker: StatsTracker instance with game history
            injury_client: Optional InjuryClient for injury adjustments
            injury_cache: Optional InjuryCache for caching adjustments
        """
        self.elo_tracker = elo_tracker
        self.stats_tracker = stats_tracker
        self.injury_client = injury_client
        self.injury_cache = injury_cache or (get_global_cache() if INJURY_SUPPORT_AVAILABLE else None)

        # Track whether injury adjustments are enabled
        self._injury_adjustments_enabled = (
            INJURY_SUPPORT_AVAILABLE and
            INJURY_ADJUSTMENTS_ENABLED and
            self.injury_client is not None
        )

    def prefetch_all_injuries(self) -> int:
        """
        Fetch all 30 teams' injury data in a single ESPN API call and populate
        the in-memory cache.

        Call this ONCE before a batch of predictions (e.g. a daily slate) so
        that every subsequent _get_injury_features() call is served from cache
        with zero additional HTTP requests.

        Returns:
            Number of teams whose injury data was cached.
        """
        if not self._injury_adjustments_enabled:
            return 0

        try:
            all_reports = self.injury_client.get_all_injuries()

            for team_id, report in all_reports.items():
                adjustment = calculate_injury_adjustment(report)
                if self.injury_cache:
                    self.injury_cache.set(
                        team_id=team_id,
                        team_name=report.team_name,
                        adjustment=adjustment,
                        severity=report.total_severity,
                        injuries_count=len(report.injuries),
                        injuries_summary=[
                            f"{inj.player_name} ({inj.status})"
                            for inj in report.injuries
                        ]
                    )

            if LOG_INJURY_ADJUSTMENTS:
                print(f"⚕️  Pre-fetched injuries for {len(all_reports)} teams "
                      f"(1 ESPN API call, cached {INJURY_CACHE_TTL // 3600}h)")

            return len(all_reports)

        except Exception as e:
            if LOG_INJURY_ADJUSTMENTS:
                print(f"⚠️  prefetch_all_injuries failed: {e}")
            return 0

    def build_features(
        self,
        home_id: int,
        away_id: int,
        game_date: Union[str, date, datetime],
        ml_home: Optional[float] = None,
        ml_away: Optional[float] = None
    ) -> np.ndarray:
        """
        Build feature vector for a matchup.

        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID
            game_date: Date of the game
            ml_home: Home team moneyline odds (optional)
            ml_away: Away team moneyline odds (optional)

        Returns:
            numpy array of shape (31,) with features in FEATURE_COLS order
        """
        # Get base Elo ratings
        elo_home = self.elo_tracker.get_elo(home_id)
        elo_away = self.elo_tracker.get_elo(away_id)

        # Default injury feature values (used when ESPN is unavailable)
        home_players_out        = 0.0
        away_players_out        = 0.0
        home_players_questionable = 0.0
        away_players_questionable = 0.0
        home_injury_severity    = 0.0
        away_injury_severity    = 0.0

        # Apply injury adjustments and extract explicit injury features
        if self._injury_adjustments_enabled:
            home_adj, home_players_out, home_players_questionable, home_injury_severity = \
                self._get_injury_features(home_id)
            away_adj, away_players_out, away_players_questionable, away_injury_severity = \
                self._get_injury_features(away_id)

            elo_home += home_adj
            elo_away += away_adj

            if LOG_INJURY_ADJUSTMENTS and (home_adj != 0 or away_adj != 0):
                print(f"⚕️  Injury adjustments: Home {home_adj:+.1f}, Away {away_adj:+.1f} Elo")
        
        # Calculate derived Elo features
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

        # Build feature vector in correct order (31 features)
        features = np.array([
            # Elo ratings (4)
            elo_home,
            elo_away,
            elo_diff,
            elo_prob,
            # Rolling scoring stats (6)
            pf_roll_home,
            pf_roll_away,
            pf_roll_diff,
            pa_roll_home,
            pa_roll_away,
            pa_roll_diff,
            # Rolling win/margin stats (6)
            win_roll_home,
            win_roll_away,
            win_roll_diff,
            margin_roll_home,
            margin_roll_away,
            margin_roll_diff,
            # Game-window context (2)
            games_in_window_home,
            games_in_window_away,
            # Rest / fatigue (5)
            home_rest_days,
            away_rest_days,
            int(home_b2b),
            int(away_b2b),
            rest_diff,
            # Betting market probabilities (2)
            market_prob_home,
            market_prob_away,
            # Injury features (6) — live ESPN data; 0.0 when unavailable
            home_players_out,
            away_players_out,
            home_players_questionable,
            away_players_questionable,
            home_injury_severity,
            away_injury_severity,
        ], dtype=np.float64)

        return features
    
    def _get_injury_features(self, team_id: int) -> tuple:
        """
        Fetch injury data for a team and return all relevant features.

        Args:
            team_id: NBA team ID

        Returns:
            Tuple of (elo_adjustment, players_out, players_questionable, injury_severity)
            All values are 0.0 when injury data is unavailable.
        """
        _zero = (0.0, 0.0, 0.0, 0.0)

        if not self._injury_adjustments_enabled:
            return _zero

        # Try cache first
        if self.injury_cache:
            cached = self.injury_cache.get(team_id, allow_stale=False)
            if cached:
                # Cache stores the Elo adjustment; raw counts are not cached.
                # Return adjustment from cache with zero counts (safe fallback).
                return (cached.adjustment, 0.0, 0.0, cached.severity
                        if hasattr(cached, "severity") else 0.0)

        # Fetch fresh injury data from ESPN
        try:
            injury_report = self.injury_client.get_team_injuries(team_id)
            if injury_report:
                adjustment  = calculate_injury_adjustment(injury_report)
                players_out = float(len(injury_report.players_out))
                players_q   = float(len(injury_report.players_questionable))
                severity    = float(injury_report.total_severity)

                # Cache the result
                if self.injury_cache:
                    self.injury_cache.set(
                        team_id=team_id,
                        team_name=injury_report.team_name,
                        adjustment=adjustment,
                        severity=severity,
                        injuries_count=len(injury_report.injuries),
                        injuries_summary=[
                            f"{inj.player_name} ({inj.status})"
                            for inj in injury_report.injuries
                        ]
                    )

                return (adjustment, players_out, players_q, severity)
            else:
                # No injuries reported for this team
                return _zero

        except Exception:
            # Handle fetch failure
            if INJURY_FALLBACK_ON_ERROR:
                # Try stale cache
                if self.injury_cache and INJURY_USE_STALE_CACHE:
                    cached = self.injury_cache.get(team_id, allow_stale=True)
                    if cached:
                        if LOG_INJURY_ADJUSTMENTS:
                            print(f"⚠️  Using stale injury cache for team {team_id}")
                        severity = cached.severity if hasattr(cached, "severity") else 0.0
                        return (cached.adjustment, 0.0, 0.0, severity)

                # Fall back to no adjustment
                if LOG_INJURY_ADJUSTMENTS:
                    print(f"⚠️  Injury fetch failed for team {team_id}, using unadjusted Elo")
                return _zero
            else:
                raise

    def _get_injury_adjustment(self, team_id: int) -> float:
        """
        Backward-compatible wrapper around _get_injury_features().

        Returns only the Elo adjustment component.
        """
        return self._get_injury_features(team_id)[0]

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
            Dictionary mapping feature names to values (31 keys)
        """
        features = self.build_features(home_id, away_id, game_date)
        return dict(zip(FEATURE_COLS, features))

    @staticmethod
    def get_feature_names() -> list[str]:
        """Return list of feature names in order."""
        return list(FEATURE_COLS)

