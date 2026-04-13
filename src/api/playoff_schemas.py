"""
Pydantic schemas for NBA Playoffs API request/response models.

Completely separate from schemas.py — no modifications to existing schemas.
"""

from typing import Optional, List
from pydantic import BaseModel, Field


# =============================================================================
# Shared Sub-Models
# =============================================================================

class PlayoffGameContext(BaseModel):
    """Contextual matchup info for a playoff game."""
    home_elo: float
    away_elo: float
    home_recent_wins: float
    away_recent_wins: float
    home_rest_days: int
    away_rest_days: int
    home_b2b: bool
    away_b2b: bool
    home_injuries: Optional[List[str]] = None
    away_injuries: Optional[List[str]] = None
    injury_advantage: Optional[str] = None


class PlayoffPredictionInfo(BaseModel):
    """Game prediction enriched with series context."""
    home_win_prob: float = Field(..., description="Probability home team wins this game (0-1)")
    away_win_prob: float = Field(..., description="Probability away team wins this game (0-1)")
    confidence: str = Field(..., description="Confidence tier label")
    favored: str = Field(..., description="'home' or 'away'")
    confidence_score: Optional[int] = Field(None, description="0-100 confidence score")
    confidence_qualifier: Optional[str] = None
    confidence_factors: Optional[dict] = None

    # Series-level probabilities (Markov chain DP)
    series_win_prob_home: float = Field(..., description="Probability home team wins the series (0-1)")
    series_win_prob_away: float = Field(..., description="Probability away team wins the series (0-1)")

    # Human-readable context
    series_context: str = Field(..., description="e.g. 'Boston leads 3-1, needs 1 more win (Game 5)'")
    game_number: int = Field(..., description="Game number within the series (1-7)")


# =============================================================================
# Series Models
# =============================================================================

class SeriesGameResult(BaseModel):
    """One completed or scheduled game within a series."""
    game_number: int
    game_date: str
    home_team_id: int
    away_team_id: int
    home_score: Optional[int] = None
    away_score: Optional[int] = None
    winner_id: Optional[int] = None
    status: str  # "scheduled" | "final"


class SeriesInfo(BaseModel):
    """Summary info for a single playoff series (for bracket view)."""
    series_id: str
    round_name: str
    conference: str
    higher_seed_id: int
    lower_seed_id: int
    higher_seed_name: str
    lower_seed_name: str
    higher_seed_wins: int
    lower_seed_wins: int
    games_played: int
    status: str  # "upcoming" | "in_progress" | "complete"
    winner_id: Optional[int] = None
    series_context: str


class PlayoffSeriesResponse(BaseModel):
    """Detailed response for a single series, including next game prediction."""
    series_id: str
    round_name: str
    conference: str
    higher_seed_id: int
    lower_seed_id: int
    higher_seed_name: str
    lower_seed_name: str
    higher_seed_wins: int
    lower_seed_wins: int
    games_played: int
    status: str
    winner_id: Optional[int] = None
    series_context: str
    game_history: List[SeriesGameResult]
    next_game_prediction: Optional["PlayoffGameWithPrediction"] = None


# =============================================================================
# Game Models
# =============================================================================

class PlayoffGameWithPrediction(BaseModel):
    """A scheduled playoff game with prediction and series context."""
    series_id: Optional[str] = None
    round_name: Optional[str] = None
    conference: Optional[str] = None
    is_play_in: bool = False
    game_date: str
    game_time: Optional[str] = None
    game_number: int
    home_team: str
    away_team: str
    home_team_id: int
    away_team_id: int
    home_series_wins: int
    away_series_wins: int
    prediction: Optional[PlayoffPredictionInfo] = None
    context: Optional[PlayoffGameContext] = None


# =============================================================================
# List/Bracket Responses
# =============================================================================

class PlayoffBracketResponse(BaseModel):
    """Full bracket with all series states."""
    season: int
    current_round: str
    fetched_at: str
    east: List[SeriesInfo]
    west: List[SeriesInfo]
    finals: Optional[SeriesInfo] = None
    playoffs_active: bool = True
    play_in_active: bool = False
    play_in: List["PlayInMatchupInfo"] = []


class PlayoffPredictionsListResponse(BaseModel):
    """Response for GET /playoff/predict/today or /playoff/predict/{date}."""
    date: str
    generated_at: str
    round_name: Optional[str] = None
    count: int
    games: List[PlayoffGameWithPrediction]


# =============================================================================
# Status Models
# =============================================================================

class PlayInMatchupInfo(BaseModel):
    """Summary of a single play-in tournament matchup."""
    matchup_id: str
    conference: str
    team1_id: int
    team2_id: int
    team1_name: str
    team2_name: str
    game_date: Optional[str] = None
    home_team_id: Optional[int] = None
    team1_score: Optional[int] = None
    team2_score: Optional[int] = None
    winner_id: Optional[int] = None
    status: str  # "upcoming" | "final"
    context: str


class PlayoffStatusResponse(BaseModel):
    """Whether playoffs are currently active."""
    playoffs_active: bool
    play_in_active: bool = False
    current_round: Optional[str] = None
    season: int
    last_updated: Optional[str] = None


class PlayoffStateReloadResponse(BaseModel):
    """Response for POST /playoff/state/reload."""
    status: str = "ok"
    reloaded_at: str
