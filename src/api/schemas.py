"""
Pydantic schemas for API request/response models.
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


# =============================================================================
# Request Models
# =============================================================================

class PredictGameRequest(BaseModel):
    """Request to predict a single game."""
    home_team: str = Field(..., description="Home team name or abbreviation")
    away_team: str = Field(..., description="Away team name or abbreviation")
    game_date: Optional[str] = Field(None, description="Game date (YYYY-MM-DD). Default: today")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "home_team": "Lakers",
                    "away_team": "Celtics",
                    "game_date": "2026-01-03"
                }
            ]
        }
    }


class PredictBatchRequest(BaseModel):
    """Request to predict multiple games."""
    games: List[PredictGameRequest] = Field(..., description="List of games to predict")


# =============================================================================
# Response Models - Predictions
# =============================================================================

class PredictionInfo(BaseModel):
    """Core prediction data."""
    home_win_prob: float = Field(..., description="Probability home team wins (0-1)")
    away_win_prob: float = Field(..., description="Probability away team wins (0-1)")
    confidence: str = Field(..., description="Confidence tier label")
    favored: str = Field(..., description="Which team is favored: 'home' or 'away'")
    
    # Game-specific confidence metrics
    confidence_score: Optional[int] = Field(None, description="0-100 confidence score")
    confidence_qualifier: Optional[str] = Field(None, description="High Certainty | Moderate | Volatile")
    confidence_factors: Optional[dict] = Field(None, description="Factor breakdown")


class GameContext(BaseModel):
    """Contextual information about the matchup."""
    home_elo: float = Field(..., description="Home team Elo rating")
    away_elo: float = Field(..., description="Away team Elo rating")
    home_recent_wins: float = Field(..., description="Home team recent win rate (0-1)")
    away_recent_wins: float = Field(..., description="Away team recent win rate (0-1)")
    home_rest_days: int = Field(..., description="Days since home team's last game")
    away_rest_days: int = Field(..., description="Days since away team's last game")
    home_b2b: bool = Field(..., description="Is home team on back-to-back?")
    away_b2b: bool = Field(..., description="Is away team on back-to-back?")
    
    # NEW: Injury information
    home_injuries: Optional[List[str]] = Field(None, description="List of injured players on home team")
    away_injuries: Optional[List[str]] = Field(None, description="List of injured players on away team")
    injury_advantage: Optional[str] = Field(None, description="Which team has health advantage: 'home', 'away', or 'even'")


class GamePredictionResponse(BaseModel):
    """Full prediction for a single game."""
    game_date: str
    game_time: Optional[str] = None
    home_team: str
    away_team: str
    home_team_id: int
    away_team_id: int
    prediction: PredictionInfo
    context: Optional[GameContext] = None


class SinglePredictionResponse(BaseModel):
    """Response for POST /predict/game."""
    home_team: str
    away_team: str
    home_team_id: int
    away_team_id: int
    game_date: str
    home_win_prob: float
    away_win_prob: float
    confidence: str
    context: Optional[GameContext] = None
    
    # Game-specific confidence metrics
    confidence_score: Optional[int] = None
    confidence_qualifier: Optional[str] = None
    confidence_factors: Optional[dict] = None


class PredictionsListResponse(BaseModel):
    """Response for GET /predict/today or /predict/{date}."""
    date: str
    generated_at: str
    count: int
    games: List[GamePredictionResponse]


class BatchPredictionResponse(BaseModel):
    """Response for POST /predict/batch."""
    generated_at: str
    count: int
    predictions: List[SinglePredictionResponse]


# =============================================================================
# Response Models - Games
# =============================================================================

class GameInfo(BaseModel):
    """Game information from ESPN."""
    game_date: str
    game_time: Optional[str] = None
    home_team: str
    away_team: str
    home_team_id: Optional[int] = None
    away_team_id: Optional[int] = None
    home_score: int
    away_score: int
    status: str


class GameWithPrediction(BaseModel):
    """Game info combined with prediction."""
    game_date: str
    game_time: Optional[str] = None
    home_team: str
    away_team: str
    home_team_id: Optional[int] = None
    away_team_id: Optional[int] = None
    home_score: int
    away_score: int
    status: str
    prediction: Optional[PredictionInfo] = None
    context: Optional[GameContext] = None


class GamesListResponse(BaseModel):
    """Response for GET /games endpoints."""
    date: str
    fetched_at: str
    count: int
    games: List[GameInfo]


class GamesWithPredictionsResponse(BaseModel):
    """Response for GET /games/today/with-predictions."""
    date: str
    fetched_at: str
    count: int
    games: List[GameWithPrediction]


# =============================================================================
# Response Models - System
# =============================================================================

class HealthResponse(BaseModel):
    """Health check response."""
    status: str = "ok"
    version: str = "1.0.0"
    timestamp: str


class StateInfoResponse(BaseModel):
    """State information response."""
    last_processed_date: Optional[str] = None
    last_updated: Optional[str] = None
    games_processed_total: int
    version: str
    state_exists: bool


class TeamInfo(BaseModel):
    """Team information."""
    team_id: int
    full_name: str
    abbreviation: str
    nickname: str
    city: str
    current_elo: Optional[float] = None


class TeamsListResponse(BaseModel):
    """Response for GET /teams."""
    count: int
    teams: List[TeamInfo]


# =============================================================================
# Error Models
# =============================================================================

class ErrorResponse(BaseModel):
    """Standard error response."""
    error: str
    detail: Optional[str] = None

