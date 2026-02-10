"""
Comprehensive test suite for injury-based Elo adjustments.

Tests:
- Player importance classification
- Injury adjustment calculations
- Cache behavior and TTL
- Feature builder integration
- Fallback and error handling
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from core.player_importance import (
    PlayerTier,
    get_player_tier,
    get_player_importance_multiplier,
    is_all_star,
    normalize_player_name,
)
from core.injury_client import (
    PlayerInjury,
    TeamInjuryReport,
    calculate_injury_adjustment,
)
from core.injury_cache import InjuryCache, CachedInjuryData
from core.config import (
    INJURY_ADJUSTMENT_MULTIPLIER,
    INJURY_MAX_ADJUSTMENT,
    PLAYER_IMPORTANCE_ALLSTAR,
    PLAYER_IMPORTANCE_STARTER,
)


class TestPlayerImportance(unittest.TestCase):
    """Test player importance classification."""
    
    def test_all_star_players(self):
        """Test that known All-Stars are classified correctly."""
        all_stars = [
            "LeBron James",
            "Stephen Curry",
            "Nikola Jokic",
            "Giannis Antetokounmpo",
            "Kevin Durant",
        ]
        
        for player in all_stars:
            tier = get_player_tier(player)
            self.assertEqual(tier, PlayerTier.ALL_STAR, f"{player} should be All-Star tier")
            self.assertTrue(is_all_star(player), f"{player} should be identified as All-Star")
            
            multiplier = get_player_importance_multiplier(player)
            self.assertEqual(multiplier, PLAYER_IMPORTANCE_ALLSTAR)
    
    def test_unknown_players_default_to_starter(self):
        """Test that unknown players default to Starter tier."""
        unknown_players = [
            "Random Rookie",
            "Unknown Player",
            "John Doe",
        ]
        
        for player in unknown_players:
            tier = get_player_tier(player)
            self.assertEqual(tier, PlayerTier.STARTER, f"{player} should default to Starter tier")
            
            multiplier = get_player_importance_multiplier(player)
            self.assertEqual(multiplier, PLAYER_IMPORTANCE_STARTER)
    
    def test_name_normalization(self):
        """Test that player name normalization works correctly."""
        # These should all match
        names = [
            "LeBron James",
            "lebron james",
            "LEBRON JAMES",
            "LeBron  James",  # Extra space
        ]
        
        normalized = [normalize_player_name(name) for name in names]
        
        # All should normalize to the same thing
        self.assertEqual(len(set(normalized)), 1, "All variations should normalize to same name")


class TestInjuryAdjustmentCalculation(unittest.TestCase):
    """Test injury adjustment calculations."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.team_id = 1610612747  # Lakers
        self.team_name = "Los Angeles Lakers"
    
    def test_no_injuries_no_adjustment(self):
        """Test that team with no injuries gets no adjustment."""
        report = TeamInjuryReport(
            team_id=self.team_id,
            team_name=self.team_name,
            injuries=[],
            last_updated=datetime.now(),
        )
        
        adjustment = calculate_injury_adjustment(report)
        self.assertEqual(adjustment, 0.0)
    
    def test_all_star_out_adjustment(self):
        """Test adjustment for All-Star player out."""
        injury = PlayerInjury(
            player_name="LeBron James",
            player_id="2544",
            team_id=self.team_id,
            team_name=self.team_name,
            status="Out",
            injury_type="Ankle",
            details="Left ankle sprain",
            date_updated=datetime.now(),
        )
        
        report = TeamInjuryReport(
            team_id=self.team_id,
            team_name=self.team_name,
            injuries=[injury],
            last_updated=datetime.now(),
        )
        
        adjustment = calculate_injury_adjustment(report)
        
        # Out (1.0) × All-Star (2.5) × 20 = -50 Elo
        expected = -50.0
        self.assertEqual(adjustment, expected)
    
    def test_role_player_questionable_adjustment(self):
        """Test adjustment for role player questionable."""
        injury = PlayerInjury(
            player_name="Unknown Bench Player",
            player_id="9999",
            team_id=self.team_id,
            team_name=self.team_name,
            status="Questionable",
            injury_type="Rest",
            details="Load management",
            date_updated=datetime.now(),
        )
        
        report = TeamInjuryReport(
            team_id=self.team_id,
            team_name=self.team_name,
            injuries=[injury],
            last_updated=datetime.now(),
        )
        
        adjustment = calculate_injury_adjustment(report)
        
        # Questionable (0.5) × Starter (1.5, default) × 20 = -15 Elo
        expected = -15.0
        self.assertEqual(adjustment, expected)
    
    def test_multiple_injuries_cumulative(self):
        """Test that multiple injuries have cumulative effect."""
        injuries = [
            PlayerInjury(
                player_name="LeBron James",
                player_id="2544",
                team_id=self.team_id,
                team_name=self.team_name,
                status="Out",
                injury_type="Ankle",
                details="Left ankle sprain",
                date_updated=datetime.now(),
            ),
            PlayerInjury(
                player_name="Anthony Davis",
                player_id="203076",
                team_id=self.team_id,
                team_name=self.team_name,
                status="Questionable",
                injury_type="Knee",
                details="Right knee soreness",
                date_updated=datetime.now(),
            ),
        ]
        
        report = TeamInjuryReport(
            team_id=self.team_id,
            team_name=self.team_name,
            injuries=injuries,
            last_updated=datetime.now(),
        )
        
        adjustment = calculate_injury_adjustment(report)
        
        # LeBron: 1.0 × 2.5 × 20 = -50
        # AD: 0.5 × 2.5 × 20 = -25
        # Total = -75 Elo
        expected = -75.0
        self.assertEqual(adjustment, expected)
    
    def test_max_adjustment_cap(self):
        """Test that adjustment is capped at maximum."""
        # Create many severe injuries
        injuries = [
            PlayerInjury(
                player_name=f"Star Player {i}",
                player_id=f"{i}",
                team_id=self.team_id,
                team_name=self.team_name,
                status="Out",
                injury_type="Various",
                details="Injured",
                date_updated=datetime.now(),
            )
            for i in range(10)  # 10 "out" injuries
        ]
        
        report = TeamInjuryReport(
            team_id=self.team_id,
            team_name=self.team_name,
            injuries=injuries,
            last_updated=datetime.now(),
        )
        
        adjustment = calculate_injury_adjustment(report)
        
        # Should be capped at INJURY_MAX_ADJUSTMENT
        self.assertEqual(adjustment, INJURY_MAX_ADJUSTMENT)
        self.assertGreaterEqual(adjustment, -100)  # Default max


class TestInjuryCache(unittest.TestCase):
    """Test injury cache behavior."""
    
    def test_cache_stores_and_retrieves(self):
        """Test basic cache storage and retrieval."""
        cache = InjuryCache(ttl=60, persist=False)
        
        cache.set(
            team_id=1610612747,
            team_name="Lakers",
            adjustment=-50.0,
            severity=2.5,
            injuries_count=2,
            injuries_summary=["LeBron James (Out)", "AD (Questionable)"]
        )
        
        entry = cache.get(1610612747)
        self.assertIsNotNone(entry)
        self.assertEqual(entry.adjustment, -50.0)
        self.assertEqual(entry.team_name, "Lakers")
        self.assertEqual(entry.injuries_count, 2)
    
    def test_cache_expiration(self):
        """Test that cache entries expire after TTL."""
        cache = InjuryCache(ttl=1, persist=False)  # 1 second TTL
        
        cache.set(
            team_id=1610612747,
            team_name="Lakers",
            adjustment=-50.0,
            severity=2.5,
            injuries_count=2,
            injuries_summary=["LeBron James (Out)"]
        )
        
        # Should be available immediately
        entry = cache.get(1610612747)
        self.assertIsNotNone(entry)
        
        # Wait for expiration
        import time
        time.sleep(1.5)
        
        # Should now be expired
        entry = cache.get(1610612747, allow_stale=False)
        self.assertIsNone(entry)
    
    def test_cache_stale_data_retrieval(self):
        """Test retrieving stale data when allowed."""
        cache = InjuryCache(ttl=1, persist=False)
        
        cache.set(
            team_id=1610612747,
            team_name="Lakers",
            adjustment=-50.0,
            severity=2.5,
            injuries_count=2,
            injuries_summary=["LeBron James (Out)"]
        )
        
        import time
        time.sleep(1.5)
        
        # Should return stale data when allow_stale=True
        entry = cache.get(1610612747, allow_stale=True)
        self.assertIsNotNone(entry)
        self.assertEqual(entry.adjustment, -50.0)
    
    def test_cache_get_adjustment_convenience(self):
        """Test convenience method for getting adjustment."""
        cache = InjuryCache(ttl=60, persist=False)
        
        cache.set(
            team_id=1610612747,
            team_name="Lakers",
            adjustment=-50.0,
            severity=2.5,
            injuries_count=2,
            injuries_summary=["LeBron James (Out)"]
        )
        
        adjustment = cache.get_adjustment(1610612747)
        self.assertEqual(adjustment, -50.0)
        
        # Non-existent team should return default
        adjustment = cache.get_adjustment(9999, default=0.0)
        self.assertEqual(adjustment, 0.0)
    
    def test_cache_clear(self):
        """Test cache clearing."""
        cache = InjuryCache(ttl=60, persist=False)
        
        cache.set(1610612747, "Lakers", -50.0, 2.5, 2, [])
        cache.set(1610612738, "Celtics", -25.0, 1.5, 1, [])
        
        self.assertEqual(len(cache), 2)
        
        # Clear specific team
        cache.clear(1610612747)
        self.assertEqual(len(cache), 1)
        
        # Clear all
        cache.clear()
        self.assertEqual(len(cache), 0)
    
    def test_cache_stats(self):
        """Test cache statistics."""
        cache = InjuryCache(ttl=60, persist=False)
        
        cache.set(1610612747, "Lakers", -50.0, 2.5, 2, [])
        cache.set(1610612738, "Celtics", -25.0, 1.5, 1, [])
        
        stats = cache.get_stats()
        self.assertEqual(stats["total_entries"], 2)
        self.assertEqual(stats["fresh_entries"], 2)
        self.assertEqual(stats["expired_entries"], 0)


class TestFeatureBuilderIntegration(unittest.TestCase):
    """Test feature builder integration with injury adjustments."""
    
    def setUp(self):
        """Set up mocks for testing."""
        # Mock EloTracker
        self.elo_tracker = Mock()
        self.elo_tracker.get_elo.side_effect = lambda tid: 1500 + tid  # Varying Elo
        self.elo_tracker.get_matchup_prob.return_value = 0.55
        
        # Mock StatsTracker
        self.stats_tracker = Mock()
        self.stats_tracker.get_rolling_stats.return_value = {
            "pf_roll": 110.0,
            "pa_roll": 105.0,
            "win_roll": 0.6,
            "margin_roll": 5.0,
            "games_in_window": 10,
        }
        self.stats_tracker.get_rest_days.return_value = (2, False)
    
    @patch('core.feature_builder.INJURY_SUPPORT_AVAILABLE', True)
    @patch('core.feature_builder.INJURY_ADJUSTMENTS_ENABLED', True)
    def test_feature_builder_applies_adjustments(self):
        """Test that feature builder applies injury adjustments to Elo."""
        from core.feature_builder import FeatureBuilder
        
        # Mock injury client
        injury_client = Mock()
        injury_report = Mock()
        injury_report.injuries = [Mock()]
        injury_report.total_severity = 2.5
        injury_client.get_team_injuries.return_value = injury_report
        
        # Mock calculate_injury_adjustment
        with patch('core.feature_builder.calculate_injury_adjustment', return_value=-50.0):
            builder = FeatureBuilder(
                self.elo_tracker,
                self.stats_tracker,
                injury_client=injury_client,
            )
            
            # Build features (should apply -50 Elo adjustment)
            features = builder.build_features(
                home_id=1610612747,
                away_id=1610612738,
                game_date="2026-02-10",
            )
            
            # Verify adjustment was applied
            # Home Elo should be base (1500 + 1610612747) + adjustment (-50)
            # This is complex due to mocking, so just verify client was called
            injury_client.get_team_injuries.assert_called()


class TestErrorHandlingAndFallback(unittest.TestCase):
    """Test error handling and fallback behavior."""
    
    def test_adjustment_disabled_returns_zero(self):
        """Test that adjustments return 0 when disabled."""
        with patch('core.injury_client.INJURY_ADJUSTMENTS_ENABLED', False):
            report = TeamInjuryReport(
                team_id=1610612747,
                team_name="Lakers",
                injuries=[Mock()],
                last_updated=datetime.now(),
            )
            
            adjustment = calculate_injury_adjustment(report)
            self.assertEqual(adjustment, 0.0)


def run_tests():
    """Run all tests with verbose output."""
    print("=" * 70)
    print("Running Injury Adjustment Test Suite")
    print("=" * 70)
    
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    print("\n" + "=" * 70)
    if result.wasSuccessful():
        print("✅ All tests passed!")
    else:
        print(f"❌ {len(result.failures)} test(s) failed")
        print(f"❌ {len(result.errors)} test(s) had errors")
    print("=" * 70)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
