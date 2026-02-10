"""
Core prediction module for NBA game predictions.
"""

from .team_mapper import TeamMapper
from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker
from .feature_builder import FeatureBuilder
from .predictor import Predictor
from .confidence_scorer import ConfidenceScorer, get_confidence_qualifier
from .state_manager import StateManager
from .espn_client import ESPNClient, GameResult
from .game_processor import GameProcessor
from .prediction_output import GamePrediction, PredictionOutput
from .odds_client import OddsClient, GameOdds
from .injury_client import InjuryClient, PlayerInjury, TeamInjuryReport, calculate_injury_adjustment
from .injury_cache import InjuryCache, get_global_cache
from .player_importance import PlayerTier, get_player_tier, get_player_importance_multiplier

# Configuration module (optional import)
try:
    from . import config
except ImportError:
    config = None

__all__ = [
    "TeamMapper",
    "EloTracker",
    "StatsTracker",
    "FeatureBuilder",
    "Predictor",
    "ConfidenceScorer",
    "get_confidence_qualifier",
    "StateManager",
    "ESPNClient",
    "GameResult",
    "GameProcessor",
    "GamePrediction",
    "PredictionOutput",
    "OddsClient",
    "GameOdds",
    "InjuryClient",
    "PlayerInjury",
    "TeamInjuryReport",
    "calculate_injury_adjustment",
    "InjuryCache",
    "get_global_cache",
    "PlayerTier",
    "get_player_tier",
    "get_player_importance_multiplier",
    "config",
]
