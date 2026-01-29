"""
Shared dependencies for API endpoints.

Provides singleton instances of predictor, state manager, etc.
"""

import sys
from functools import lru_cache
from pathlib import Path
from typing import Tuple

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from core import (
    TeamMapper,
    EloTracker,
    StatsTracker,
    StateManager,
    FeatureBuilder,
    Predictor,
    ESPNClient,
    OddsClient,
)


# =============================================================================
# Configuration
# =============================================================================

def get_project_root() -> Path:
    """Get the project root directory."""
    return Path(__file__).parent.parent.parent


def get_state_dir() -> Path:
    """Get the state directory path."""
    return get_project_root() / "state"


def get_models_dir() -> Path:
    """Get the models directory path."""
    return get_project_root() / "models"


# =============================================================================
# Singleton Dependencies
# =============================================================================

@lru_cache()
def get_team_mapper() -> TeamMapper:
    """Get singleton TeamMapper instance."""
    return TeamMapper()


@lru_cache()
def get_state_manager() -> StateManager:
    """Get singleton StateManager instance."""
    return StateManager(get_state_dir())


@lru_cache()
def get_espn_client() -> ESPNClient:
    """Get singleton ESPNClient instance."""
    return ESPNClient(get_team_mapper())


@lru_cache()
def get_odds_client() -> OddsClient:
    """Get singleton OddsClient instance."""
    return OddsClient(team_mapper=get_team_mapper())


def get_trackers() -> Tuple[EloTracker, StatsTracker]:
    """
    Load Elo and Stats trackers from state.
    
    Not cached - always loads fresh from disk.
    """
    state_manager = get_state_manager()
    if not state_manager.exists():
        raise RuntimeError("State files not found. Run bootstrap_state.py first.")
    return state_manager.load()


@lru_cache()
def get_predictor() -> Predictor:
    """Get singleton Predictor instance."""
    models_dir = get_models_dir()
    model_path = models_dir / "xgb_v2_modern.json"
    calibrator_path = models_dir / "calibrator.pkl"
    
    if not model_path.exists():
        raise RuntimeError(f"Model not found at {model_path}")
    
    return Predictor(
        model_path,
        calibrator_path if calibrator_path.exists() else None,
    )


# =============================================================================
# Composite Dependencies
# =============================================================================

class PredictionService:
    """
    High-level service for making predictions.
    
    Combines all necessary components.
    """
    
    def __init__(self):
        self.team_mapper = get_team_mapper()
        self.state_manager = get_state_manager()
        self.espn_client = get_espn_client()
        self.odds_client = get_odds_client()
        self.predictor = get_predictor()
        self._elo_tracker = None
        self._stats_tracker = None
        self._feature_builder = None
        self._odds_dict = None
    
    def _ensure_trackers(self):
        """Ensure trackers are loaded."""
        if self._elo_tracker is None or self._stats_tracker is None:
            self._elo_tracker, self._stats_tracker = get_trackers()
            self._feature_builder = FeatureBuilder(self._elo_tracker, self._stats_tracker)
    
    @property
    def elo_tracker(self) -> EloTracker:
        self._ensure_trackers()
        return self._elo_tracker
    
    @property
    def stats_tracker(self) -> StatsTracker:
        self._ensure_trackers()
        return self._stats_tracker
    
    @property
    def feature_builder(self) -> FeatureBuilder:
        self._ensure_trackers()
        return self._feature_builder
    
    @property
    def odds_dict(self) -> dict:
        """Get cached odds dictionary (fetched once per day)."""
        if self._odds_dict is None:
            self._odds_dict = self.odds_client.get_odds_dict()
        return self._odds_dict
    
    def get_odds_for_game(self, home_id: int, away_id: int) -> tuple:
        """Get moneylines for a specific matchup."""
        key = (home_id, away_id)
        if key in self.odds_dict:
            return self.odds_dict[key]
        return None, None
    
    def reload_state(self):
        """Reload state from disk."""
        self._elo_tracker = None
        self._stats_tracker = None
        self._feature_builder = None
        self._odds_dict = None
        self._ensure_trackers()


# Singleton prediction service
_prediction_service = None


def get_prediction_service() -> PredictionService:
    """Get singleton PredictionService instance."""
    global _prediction_service
    if _prediction_service is None:
        _prediction_service = PredictionService()
    return _prediction_service

