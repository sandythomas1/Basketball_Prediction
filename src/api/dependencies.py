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
    ConfidenceScorer,
    ESPNClient,
    OddsClient,
)
from core.injury_client import InjuryClient
from core.league_config import NBA_CONFIG, WNBA_CONFIG, CBB_CONFIG, LeagueConfig


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


@lru_cache()
def get_injury_client() -> InjuryClient:
    """Get singleton InjuryClient instance."""
    return InjuryClient(team_mapper=get_team_mapper())


def get_trackers(state_manager: StateManager) -> Tuple[EloTracker, StatsTracker]:
    """
    Load Elo and Stats trackers from state.
    
    Not cached - always loads fresh from disk.
    """
    if not state_manager.exists():
        raise RuntimeError("State files not found.")
    return state_manager.load()


@lru_cache()
def get_predictor() -> Predictor:
    """Get singleton Predictor instance."""
    models_dir = get_models_dir()
    model_path = models_dir / "xgb_v3_with_injuries.json"
    calibrator_path = models_dir / "calibrator_v3.pkl"
    
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
    
    def __init__(self, config: LeagueConfig = NBA_CONFIG):
        self.config = config
        self.team_mapper = TeamMapper(lookup_path=get_project_root() / config.team_lookup_csv) if config.team_lookup_csv else TeamMapper()
        self.state_manager = StateManager(get_project_root() / config.state_dir)
        self.espn_client = ESPNClient(self.team_mapper, league_slug=config.espn_slug)
        self.odds_client = OddsClient(team_mapper=self.team_mapper, sport_key=config.odds_sport_key)
        self.injury_client = None if config.injury_source == "none" else InjuryClient(team_mapper=self.team_mapper, league_slug=config.espn_slug)
        self._predictor_with_confidence = None
        self._elo_tracker = None
        self._stats_tracker = None
        self._feature_builder = None
        self._confidence_scorer = None
        self._odds_dict = None
    
    def _ensure_trackers(self):
        """Ensure trackers are loaded."""
        if self._elo_tracker is None or self._stats_tracker is None:
            self._elo_tracker, self._stats_tracker = get_trackers(self.state_manager)
            
            # Create feature builder with injury support
            self._feature_builder = FeatureBuilder(
                self._elo_tracker, 
                self._stats_tracker,
                injury_client=self.injury_client,  # Pass injury client for adjustments
            )
            self._confidence_scorer = ConfidenceScorer(self._stats_tracker)
            
            # Create predictor with confidence scorer
            model_path = get_project_root() / self.config.model_path
            calibrator_path = get_project_root() / self.config.calibrator_path
            
            self._predictor_with_confidence = Predictor(
                model_path,
                calibrator_path if calibrator_path.exists() else None,
                confidence_scorer=self._confidence_scorer,
            )
    
    @property
    def predictor(self) -> Predictor:
        """Get predictor with confidence scoring."""
        self._ensure_trackers()
        return self._predictor_with_confidence
    
    @property
    def elo_tracker(self) -> EloTracker:
        self._ensure_trackers()
        return self._elo_tracker
    
    @property
    def feature_builder(self) -> 'FeatureBuilder':
        """Get feature builder with injury adjustments."""
        self._ensure_trackers()
        return self._feature_builder
    
    @property
    def stats_tracker(self) -> StatsTracker:
        self._ensure_trackers()
        return self._stats_tracker
    
    @property
    def feature_builder(self) -> FeatureBuilder:
        self._ensure_trackers()
        return self._feature_builder
    
    @property
    def confidence_scorer(self) -> ConfidenceScorer:
        self._ensure_trackers()
        return self._confidence_scorer
    
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
        self._confidence_scorer = None
        self._predictor_with_confidence = None
        self._odds_dict = None
        self._ensure_trackers()


# Singleton prediction service cache
_prediction_services = {}

def get_nba_prediction_service() -> PredictionService:
    if "nba" not in _prediction_services:
        _prediction_services["nba"] = PredictionService(config=NBA_CONFIG)
    return _prediction_services["nba"]

def get_wnba_prediction_service() -> PredictionService:
    if "wnba" not in _prediction_services:
        _prediction_services["wnba"] = PredictionService(config=WNBA_CONFIG)
    return _prediction_services["wnba"]

def get_cbb_prediction_service() -> PredictionService:
    if "cbb" not in _prediction_services:
        _prediction_services["cbb"] = PredictionService(config=CBB_CONFIG)
    return _prediction_services["cbb"]

from fastapi import Request

def get_prediction_service(request: Request) -> PredictionService:
    """Get PredictionService instance dynamically based on the request URL."""
    if request and request.url.path.startswith("/wnba/"):
        return get_wnba_prediction_service()
    if request and request.url.path.startswith("/cbb/"):
        return get_cbb_prediction_service()
    return get_nba_prediction_service()

