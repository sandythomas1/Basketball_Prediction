from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from typing import List, Dict
from datetime import date

from ..dependencies import get_prediction_service, PredictionService
from core.bracket_simulator import BracketSimulator

router = APIRouter(prefix="/bracket", tags=["bracket"])

class BracketRequest(BaseModel):
    team_ids: List[int] = Field(..., min_items=64, max_items=64, description="List of exactly 64 team IDs in standard bracket order")
    iterations: int = Field(1000, ge=1, le=10000, description="Number of Monte Carlo iterations")
    game_date: str | None = None

class BracketResponse(BaseModel):
    game_date: str
    iterations: int
    results: Dict[str, Dict[str, float]]  # JSON keys must be strings, so dict maps str(team_id) -> probs

@router.post("/simulate", response_model=BracketResponse)
async def simulate_bracket(
    request: Request,
    bracket_req: BracketRequest,
    service: PredictionService = Depends(get_prediction_service)
):
    """
    Simulate the NCAA March Madness bracket using the CBB prediction engine.
    """
    if len(bracket_req.team_ids) != 64:
        raise HTTPException(status_code=400, detail="Must provide exactly 64 team IDs")
        
    game_date = bracket_req.game_date or date.today().isoformat()
    
    simulator = BracketSimulator(service.predictor, service.feature_builder)
    
    try:
        raw_results = simulator.simulate(bracket_req.team_ids, game_date, bracket_req.iterations)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Simulation failed: {str(e)}")
        
    # Convert integer keys to strings for JSON compliance
    str_results = {str(k): v for k, v in raw_results.items()}
        
    return BracketResponse(
        game_date=game_date,
        iterations=bracket_req.iterations,
        results=str_results
    )
