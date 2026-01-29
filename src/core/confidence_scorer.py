"""
ConfidenceScorer: Game-specific confidence scoring system.

Calculates a 0-100 confidence score based on multiple contextual factors:
- Model-consensus agreement
- Feature signal alignment
- Form volatility
- Schedule context
- Matchup history variance
"""

from typing import Optional
import numpy as np
from .stats_tracker import StatsTracker
from .feature_builder import FEATURE_COLS


class ConfidenceScorer:
    """
    Calculates game-specific confidence scores for predictions.
    
    Combines multiple factors to provide context-aware confidence metrics
    that go beyond simple probability thresholds.
    """
    
    # Thresholds for consensus agreement factor
    CONSENSUS_PERFECT_THRESH = 0.03  # Difference < 3% = full points
    CONSENSUS_ZERO_THRESH = 0.15     # Difference > 15% = zero points
    
    # Thresholds for form volatility factor
    VOLATILITY_LOW_THRESH = 5.0      # Margin std < 5 = very stable
    VOLATILITY_HIGH_THRESH = 15.0    # Margin std > 15 = very volatile
    
    # Thresholds for matchup history (using probability distance from 0.5)
    HISTORY_DECISIVE_THRESH = 0.25   # |p - 0.5| > 0.25 = clear favorite
    HISTORY_TOSSUP_THRESH = 0.05     # |p - 0.5| < 0.05 = toss-up
    
    def __init__(self, stats_tracker: StatsTracker):
        """
        Initialize confidence scorer.
        
        Args:
            stats_tracker: StatsTracker instance for accessing team history
        """
        self.stats_tracker = stats_tracker
    
    def calculate_confidence_score(
        self,
        prob_home: float,
        features: np.ndarray,
        home_id: int,
        away_id: int,
    ) -> dict:
        """
        Calculate comprehensive confidence score for a game prediction.
        
        Args:
            prob_home: Model's predicted home win probability
            features: Feature vector (23 features in FEATURE_COLS order)
            home_id: Home team NBA ID
            away_id: Away team NBA ID
        
        Returns:
            Dict with:
                - score: Overall confidence score (0-100)
                - factors: Breakdown of individual factor scores
                - qualifier: Textual confidence qualifier
        """
        # Extract relevant features
        feature_dict = dict(zip(FEATURE_COLS, features))
        
        # Calculate individual factors
        consensus = self._score_consensus_agreement(prob_home, feature_dict)
        alignment = self._score_feature_alignment(prob_home, feature_dict)
        volatility = self._score_form_stability(home_id, away_id)
        schedule = self._score_schedule_context(feature_dict)
        history = self._score_matchup_history(prob_home)
        
        # Total score (0-100)
        total_score = consensus + alignment + volatility + schedule + history
        total_score = max(0, min(100, round(total_score)))
        
        # Determine qualifier
        qualifier = self._get_qualifier(total_score)
        
        return {
            "score": total_score,
            "factors": {
                "consensus_agreement": round(consensus, 1),
                "feature_alignment": round(alignment, 1),
                "form_stability": round(volatility, 1),
                "schedule_context": round(schedule, 1),
                "matchup_history": round(history, 1),
            },
            "qualifier": qualifier,
        }
    
    def _score_consensus_agreement(
        self, prob_home: float, features: dict
    ) -> float:
        """
        Score based on model vs market consensus agreement.
        
        Max points: 25
        """
        market_prob_home = features.get("market_prob_home", 0.5)
        
        # If no market data (default 0.5), give neutral score
        if abs(market_prob_home - 0.5) < 0.01:
            return 15.0  # Neutral - no market data
        
        # Calculate disagreement
        disagreement = abs(prob_home - market_prob_home)
        
        # Linear interpolation between thresholds
        if disagreement <= self.CONSENSUS_PERFECT_THRESH:
            return 25.0
        elif disagreement >= self.CONSENSUS_ZERO_THRESH:
            return 0.0
        else:
            # Linear scale
            ratio = (disagreement - self.CONSENSUS_PERFECT_THRESH) / (
                self.CONSENSUS_ZERO_THRESH - self.CONSENSUS_PERFECT_THRESH
            )
            return 25.0 * (1 - ratio)
    
    def _score_feature_alignment(
        self, prob_home: float, features: dict
    ) -> float:
        """
        Score based on alignment of feature signals.
        
        Max points: 25
        """
        # Determine expected direction from model probability
        model_favors_home = prob_home > 0.5
        
        signals_agree = 0
        total_signals = 0
        
        # Signal 1: Elo probability
        elo_prob = features.get("elo_prob", 0.5)
        elo_favors_home = elo_prob > 0.5
        if elo_favors_home == model_favors_home:
            signals_agree += 1
        total_signals += 1
        
        # Signal 2: Win rate differential
        win_diff = features.get("win_roll_diff", 0.0)
        win_favors_home = win_diff > 0
        if win_favors_home == model_favors_home or abs(win_diff) < 0.05:
            signals_agree += 1
        total_signals += 1
        
        # Signal 3: Margin differential
        margin_diff = features.get("margin_roll_diff", 0.0)
        margin_favors_home = margin_diff > 0
        if margin_favors_home == model_favors_home or abs(margin_diff) < 1.0:
            signals_agree += 1
        total_signals += 1
        
        # Signal 4: Rest advantage
        rest_diff = features.get("rest_diff", 0)
        # Only count if significant (>= 2 days)
        if abs(rest_diff) >= 2:
            rest_favors_home = rest_diff > 0
            if rest_favors_home == model_favors_home:
                signals_agree += 1
            total_signals += 1
        
        # Calculate score
        if total_signals == 0:
            return 15.0  # Neutral
        
        agreement_ratio = signals_agree / total_signals
        return 25.0 * agreement_ratio
    
    def _score_form_stability(self, home_id: int, away_id: int) -> float:
        """
        Score based on recent form consistency.
        
        Max points: 20
        """
        home_volatility = self.stats_tracker.get_form_volatility(home_id)
        away_volatility = self.stats_tracker.get_form_volatility(away_id)
        
        home_std = home_volatility["margin_std"]
        away_std = away_volatility["margin_std"]
        
        # Average volatility of both teams
        avg_std = (home_std + away_std) / 2
        
        # Score: lower volatility = higher confidence
        if avg_std <= self.VOLATILITY_LOW_THRESH:
            return 20.0
        elif avg_std >= self.VOLATILITY_HIGH_THRESH:
            return 5.0  # Minimum for highly volatile teams
        else:
            # Linear interpolation
            ratio = (avg_std - self.VOLATILITY_LOW_THRESH) / (
                self.VOLATILITY_HIGH_THRESH - self.VOLATILITY_LOW_THRESH
            )
            return 20.0 - (15.0 * ratio)
    
    def _score_schedule_context(self, features: dict) -> float:
        """
        Score based on schedule factors (rest, back-to-backs).
        
        Max points: 15
        """
        score = 15.0  # Base score
        
        # Penalty for back-to-backs
        home_b2b = bool(features.get("home_b2b", False))
        away_b2b = bool(features.get("away_b2b", False))
        
        if home_b2b:
            score -= 5.0
        if away_b2b:
            score -= 5.0
        
        # Bonus for clear rest advantage
        rest_diff = abs(features.get("rest_diff", 0))
        if rest_diff >= 2:
            score += 5.0
        
        return max(0.0, min(15.0, score))
    
    def _score_matchup_history(self, prob_home: float) -> float:
        """
        Score based on matchup certainty (proxy for history).
        
        For initial implementation, uses probability distance from 0.5
        as a proxy for matchup clarity. More decisive matchups get
        higher confidence.
        
        Max points: 15
        
        TODO: In future, could track actual head-to-head variance.
        """
        # Distance from 0.5 (toss-up)
        distance_from_tossup = abs(prob_home - 0.5)
        
        # Very decisive matchups (clear favorite) = high confidence
        if distance_from_tossup >= self.HISTORY_DECISIVE_THRESH:
            return 15.0
        # Toss-ups = lower confidence
        elif distance_from_tossup <= self.HISTORY_TOSSUP_THRESH:
            return 5.0
        else:
            # Linear interpolation
            ratio = (distance_from_tossup - self.HISTORY_TOSSUP_THRESH) / (
                self.HISTORY_DECISIVE_THRESH - self.HISTORY_TOSSUP_THRESH
            )
            return 5.0 + (10.0 * ratio)
    
    def _get_qualifier(self, score: float) -> str:
        """
        Convert numeric score to textual qualifier.
        
        Args:
            score: Confidence score (0-100)
        
        Returns:
            Qualifier string
        """
        if score >= 75:
            return "High Certainty"
        elif score >= 50:
            return "Moderate"
        else:
            return "Volatile"


def get_confidence_qualifier(score: float) -> str:
    """
    Standalone function to get qualifier from score.
    
    Args:
        score: Confidence score (0-100)
    
    Returns:
        Qualifier string: "High Certainty", "Moderate", or "Volatile"
    """
    if score >= 75:
        return "High Certainty"
    elif score >= 50:
        return "Moderate"
    else:
        return "Volatile"
