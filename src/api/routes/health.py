"""
Health and system endpoints.
"""

from datetime import datetime

from fastapi import APIRouter, Depends

from ..schemas import (
    HealthResponse,
    StateInfoResponse,
    TeamsListResponse,
    TeamInfo,
)
from ..dependencies import get_prediction_service, get_state_manager, PredictionService


router = APIRouter(tags=["system"])


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint.
    
    Returns basic status information.
    """
    return HealthResponse(
        status="ok",
        version="1.0.0",
        timestamp=datetime.now().isoformat(),
    )


@router.get("/state/info", response_model=StateInfoResponse)
async def get_state_info(
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Get current state information.
    
    Returns metadata about the prediction state.
    """
    state_manager = service.state_manager
    metadata = state_manager.get_metadata()
    
    return StateInfoResponse(
        last_processed_date=metadata.get("last_processed_date"),
        last_updated=metadata.get("last_updated"),
        games_processed_total=metadata.get("games_processed_total", 0),
        version=metadata.get("version", "unknown"),
        state_exists=state_manager.exists(),
    )


@router.get("/teams", response_model=TeamsListResponse)
async def list_teams(
    service: PredictionService = Depends(get_prediction_service),
):
    """
    List all NBA teams with their IDs and current Elo ratings.
    """
    team_mapper = service.team_mapper
    elo_tracker = service.elo_tracker
    
    teams = []
    for team_id in team_mapper.get_all_team_ids():
        full_name = team_mapper.get_team_name(team_id)
        abbr = team_mapper.get_team_abbreviation(team_id)
        
        # Parse nickname and city from full name
        parts = full_name.rsplit(" ", 1) if full_name else ["Unknown", "Unknown"]
        if len(parts) == 2:
            city, nickname = parts[0], parts[1]
        else:
            city, nickname = full_name, full_name
        
        teams.append(TeamInfo(
            team_id=team_id,
            full_name=full_name or "Unknown",
            abbreviation=abbr or "UNK",
            nickname=nickname,
            city=city,
            current_elo=round(elo_tracker.get_elo(team_id), 1),
        ))
    
    # Sort by Elo rating (highest first)
    teams.sort(key=lambda t: t.current_elo or 0, reverse=True)
    
    return TeamsListResponse(
        count=len(teams),
        teams=teams,
    )


@router.post("/state/reload")
async def reload_state(
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Reload state from disk.
    
    Useful after running update_state.py to pick up new data.
    """
    service.reload_state()
    return {"status": "ok", "message": "State reloaded"}

