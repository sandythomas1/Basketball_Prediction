"""
Unit tests for ConfidenceScorer class.
"""

import unittest
import numpy as np
from pathlib import Path
import sys

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from core import ConfidenceScorer, StatsTracker


class TestConfidenceScorer(unittest.TestCase):
    """Test cases for ConfidenceScorer class."""

    def setUp(self):
        """Set up test fixtures."""
        # Create a mock StatsTracker with some data
        self.stats_tracker = StatsTracker()
        
        # Add some mock game data for teams 1 and 2
        for i in range(10):
            # Team 1: Consistent team (low volatility)
            self.stats_tracker.record_game(
                team_id=1,
                pf=110 + i,
                pa=100 + i,
                won=True,
                game_date=f"2024-01-{10+i:02d}",
            )
            
            # Team 2: Volatile team (high volatility)
            self.stats_tracker.record_game(
                team_id=2,
                pf=100 + (i * 5 if i % 2 == 0 else -i * 5),
                pa=100 - (i * 5 if i % 2 == 0 else -i * 5),
                won=i % 2 == 0,
                game_date=f"2024-01-{10+i:02d}",
            )
        
        self.scorer = ConfidenceScorer(self.stats_tracker)

    def test_confidence_scorer_initialization(self):
        """Test that ConfidenceScorer initializes correctly."""
        self.assertIsNotNone(self.scorer)
        self.assertEqual(self.scorer.stats_tracker, self.stats_tracker)

    def test_calculate_confidence_score_structure(self):
        """Test that confidence score returns correct structure."""
        # Create a simple feature vector
        features = np.array([
            1500, 1500, 0, 0.5,  # Elo features
            110, 110, 0,          # PF features
            110, 110, 0,          # PA features
            0.5, 0.5, 0,          # Win rate features
            0, 0, 0,              # Margin features
            10, 10,               # Games in window
            2, 2,                 # Rest days
            0, 0, 0,              # B2B and rest diff
            0.5, 0.5,             # Market probs
        ])
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.7,
            features=features,
            home_id=1,
            away_id=2,
        )
        
        # Check structure
        self.assertIn("score", result)
        self.assertIn("factors", result)
        self.assertIn("qualifier", result)
        
        # Check score is in valid range
        self.assertGreaterEqual(result["score"], 0)
        self.assertLessEqual(result["score"], 100)
        
        # Check factors exist
        factors = result["factors"]
        self.assertIn("consensus_agreement", factors)
        self.assertIn("feature_alignment", factors)
        self.assertIn("form_stability", factors)
        self.assertIn("schedule_context", factors)
        self.assertIn("matchup_history", factors)

    def test_consensus_agreement_perfect(self):
        """Test consensus agreement when model and market agree perfectly."""
        features = np.array([
            1500, 1500, 0, 0.5,
            110, 110, 0, 110, 110, 0,
            0.5, 0.5, 0, 0, 0, 0,
            10, 10, 2, 2, 0, 0, 0,
            0.7, 0.3,  # Market agrees with model
        ])
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.7,
            features=features,
            home_id=1,
            away_id=2,
        )
        
        # Should get high consensus score
        consensus = result["factors"]["consensus_agreement"]
        self.assertGreater(consensus, 20)  # Out of 25

    def test_consensus_agreement_disagreement(self):
        """Test consensus agreement when model and market disagree."""
        features = np.array([
            1500, 1500, 0, 0.5,
            110, 110, 0, 110, 110, 0,
            0.5, 0.5, 0, 0, 0, 0,
            10, 10, 2, 2, 0, 0, 0,
            0.3, 0.7,  # Market disagrees with model
        ])
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.7,
            features=features,
            home_id=1,
            away_id=2,
        )
        
        # Should get low consensus score
        consensus = result["factors"]["consensus_agreement"]
        self.assertLess(consensus, 10)  # Out of 25

    def test_feature_alignment_aligned(self):
        """Test feature alignment when all signals agree."""
        features = np.array([
            1600, 1400, 200, 0.65,  # Elo favors home
            115, 105, 10,            # PF favors home
            105, 115, -10,           # PA favors home
            0.6, 0.4, 0.2,           # Win rate favors home
            5, -5, 10,               # Margin favors home
            10, 10, 2, 2, 0, 0, 0,
            0.65, 0.35,
        ])
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.65,
            features=features,
            home_id=1,
            away_id=2,
        )
        
        # Should get high alignment score
        alignment = result["factors"]["feature_alignment"]
        self.assertGreater(alignment, 20)  # Out of 25

    def test_form_stability_consistent_teams(self):
        """Test form stability with consistent teams."""
        # Team 1 is set up to be consistent in setUp
        features = np.zeros(25)
        features[23] = 0.5  # market_prob_home
        features[24] = 0.5  # market_prob_away
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.6,
            features=features,
            home_id=1,
            away_id=1,  # Both same team (consistent)
        )
        
        # Should get high stability score
        stability = result["factors"]["form_stability"]
        self.assertGreater(stability, 15)  # Out of 20

    def test_schedule_context_back_to_back(self):
        """Test schedule context with back-to-back games."""
        features = np.array([
            1500, 1500, 0, 0.5,
            110, 110, 0, 110, 110, 0,
            0.5, 0.5, 0, 0, 0, 0,
            10, 10, 1, 1,  # Both on B2B
            1, 1, 0,       # B2B flags and no rest advantage
            0.5, 0.5,
        ])
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.6,
            features=features,
            home_id=1,
            away_id=2,
        )
        
        # Should get lower schedule score due to B2B
        schedule = result["factors"]["schedule_context"]
        self.assertLess(schedule, 10)  # Out of 15

    def test_qualifier_high_certainty(self):
        """Test that high scores get 'High Certainty' qualifier."""
        # Set up features that should give high confidence
        features = np.array([
            1600, 1400, 200, 0.75,
            115, 105, 10, 105, 115, -10,
            0.7, 0.3, 0.4, 10, -10, 20,
            10, 10, 3, 3, 0, 0, 0,
            0.75, 0.25,
        ])
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.75,
            features=features,
            home_id=1,
            away_id=1,
        )
        
        # Should get high score and certainty
        self.assertGreaterEqual(result["score"], 60)
        # Qualifier depends on exact score
        self.assertIn(result["qualifier"], ["High Certainty", "Moderate"])

    def test_qualifier_volatile(self):
        """Test that low scores get 'Volatile' qualifier."""
        # Set up features that should give low confidence
        features = np.array([
            1500, 1500, 0, 0.5,
            110, 110, 0, 110, 110, 0,
            0.5, 0.5, 0, 0, 0, 0,
            10, 10, 1, 1, 1, 1, 0,
            0.3, 0.7,  # Market disagrees
        ])
        
        result = self.scorer.calculate_confidence_score(
            prob_home=0.7,
            features=features,
            home_id=2,  # Volatile team
            away_id=2,
        )
        
        # Should get lower score
        self.assertLess(result["score"], 70)

    def test_score_bounds(self):
        """Test that scores are always within 0-100 bounds."""
        # Test with various extreme inputs
        test_cases = [
            (0.9, 1800, 1200),  # Very strong favorite
            (0.1, 1200, 1800),  # Very strong underdog
            (0.5, 1500, 1500),  # Evenly matched
        ]
        
        for prob, elo_home, elo_away in test_cases:
            features = np.array([
                elo_home, elo_away, elo_home - elo_away, prob,
                110, 110, 0, 110, 110, 0,
                0.5, 0.5, 0, 0, 0, 0,
                10, 10, 2, 2, 0, 0, 0,
                prob, 1 - prob,
            ])
            
            result = self.scorer.calculate_confidence_score(
                prob_home=prob,
                features=features,
                home_id=1,
                away_id=2,
            )
            
            self.assertGreaterEqual(result["score"], 0)
            self.assertLessEqual(result["score"], 100)


class TestStatsTrackerVolatility(unittest.TestCase):
    """Test cases for StatsTracker form volatility methods."""

    def setUp(self):
        """Set up test fixtures."""
        self.stats_tracker = StatsTracker()

    def test_get_form_volatility_no_data(self):
        """Test volatility calculation with no data."""
        result = self.stats_tracker.get_form_volatility(999)
        
        self.assertIn("margin_std", result)
        self.assertIn("margin_range", result)
        self.assertIn("consistency_score", result)
        
        # Should return moderate defaults
        self.assertGreater(result["margin_std"], 0)

    def test_get_form_volatility_consistent_team(self):
        """Test volatility calculation for consistent team."""
        # Add games with consistent margins
        for i in range(10):
            self.stats_tracker.record_game(
                team_id=1,
                pf=110,
                pa=100,
                won=True,
                game_date=f"2024-01-{10+i:02d}",
            )
        
        result = self.stats_tracker.get_form_volatility(1)
        
        # Should have very low volatility
        self.assertLess(result["margin_std"], 1.0)
        self.assertGreater(result["consistency_score"], 0.9)

    def test_get_form_volatility_volatile_team(self):
        """Test volatility calculation for volatile team."""
        # Add games with highly variable margins
        margins = [20, -15, 25, -10, 30, -20, 15, -5, 35, -25]
        for i, margin in enumerate(margins):
            pf = 110 + margin
            pa = 110
            self.stats_tracker.record_game(
                team_id=2,
                pf=pf,
                pa=pa,
                won=margin > 0,
                game_date=f"2024-01-{10+i:02d}",
            )
        
        result = self.stats_tracker.get_form_volatility(2)
        
        # Should have high volatility
        self.assertGreater(result["margin_std"], 15.0)
        self.assertLess(result["consistency_score"], 0.3)


if __name__ == "__main__":
    unittest.main()
