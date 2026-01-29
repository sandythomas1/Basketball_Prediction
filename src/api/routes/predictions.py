"""
Prediction endpoints with rate limiting.
"""

from datetime import datetime, date
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..schemas import (
    PredictGameRequest,
    PredictBatchRequest,
    SinglePredictionResponse,
    PredictionsListResponse,
    BatchPredictionResponse,
    GamePredictionResponse,
    PredictionInfo,
    GameContext,
)
from ..dependencies import get_prediction_service, PredictionService

# Rate limiter
limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/predict", tags=["predictions"])


def build_prediction_response(
    service: PredictionService,
    home_id: int,
    away_id: int,
    home_name: str,
    away_name: str,
    game_date: str,
    game_time: Optional[str] = None,
    include_context: bool = True,
) -> GamePredictionResponse:
    """Build a prediction response for a game."""
    # Get odds for this matchup (from cached data)
    ml_home, ml_away = service.get_odds_for_game(home_id, away_id)
    
    # Get prediction with odds
    result = service.predictor.predict_game(
        home_id, away_id, game_date, service.feature_builder,
        ml_home=ml_home, ml_away=ml_away
    )
    
    # Get features for context
    features = service.feature_builder.build_features_dict(home_id, away_id, game_date)
    
    prediction = PredictionInfo(
        home_win_prob=round(result["prob_home_win"], 3),
        away_win_prob=round(result["prob_away_win"], 3),
        confidence=result["confidence_tier"],
        favored="home" if result["prob_home_win"] > 0.5 else "away",
        confidence_score=result.get("confidence_score"),
        confidence_qualifier=result.get("confidence_qualifier"),
        confidence_factors=result.get("confidence_factors"),
    )
    
    context = None
    if include_context:
        context = GameContext(
            home_elo=round(features["elo_home"], 1),
            away_elo=round(features["elo_away"], 1),
            home_recent_wins=round(features["win_roll_home"], 2),
            away_recent_wins=round(features["win_roll_away"], 2),
            home_rest_days=int(features["home_rest_days"]),
            away_rest_days=int(features["away_rest_days"]),
            home_b2b=bool(features["home_b2b"]),
            away_b2b=bool(features["away_b2b"]),
        )
    
    return GamePredictionResponse(
        game_date=game_date,
        game_time=game_time,
        home_team=home_name,
        away_team=away_name,
        home_team_id=home_id,
        away_team_id=away_id,
        prediction=prediction,
        context=context,
    )


@router.get("/today", response_model=PredictionsListResponse)
@limiter.limit("30/minute")
async def predict_today(
    request: Request,
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Get predictions for today's scheduled games.
    
    Fetches today's games from ESPN and returns predictions for each.
    """
    return await predict_date(date.today().isoformat(), request, service)


@router.get("/{game_date}", response_model=PredictionsListResponse)
@limiter.limit("30/minute")
async def predict_date(
    game_date: str,
    request: Request,
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Get predictions for games on a specific date.
    
    Fetches games from ESPN for the given date and returns predictions.
    """
    try:
        # Validate date format
        parsed_date = datetime.strptime(game_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid date format: {game_date}. Use YYYY-MM-DD."
        )
    
    # Fetch games from ESPN
    try:
        games = service.espn_client.get_scheduled_games(parsed_date)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to fetch games from ESPN: {str(e)}"
        )
    
    # Generate predictions
    predictions = []
    for game in games:
        if game.home_team_id is None or game.away_team_id is None:
            continue  # Skip games we can't map
        
        pred = build_prediction_response(
            service=service,
            home_id=game.home_team_id,
            away_id=game.away_team_id,
            home_name=game.home_team,
            away_name=game.away_team,
            game_date=game.game_date,
            game_time=game.game_time,
        )
        predictions.append(pred)
    
    return PredictionsListResponse(
        date=game_date,
        generated_at=datetime.now().isoformat(),
        count=len(predictions),
        games=predictions,
    )


@router.post("/game", response_model=SinglePredictionResponse)
@limiter.limit("60/minute")
async def predict_game(
    request: Request,
    game_request: PredictGameRequest,
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Predict a single game matchup.
    
    Provide home and away team names (or abbreviations) and optionally a date.
    """
    # Resolve team IDs
    home_id = service.team_mapper.get_team_id(game_request.home_team)
    away_id = service.team_mapper.get_team_id(game_request.away_team)
    
    if home_id is None:
        raise HTTPException(
            status_code=400,
            detail=f"Could not find team: {game_request.home_team}"
        )
    if away_id is None:
        raise HTTPException(
            status_code=400,
            detail=f"Could not find team: {game_request.away_team}"
        )
    
    # Get full team names
    home_name = service.team_mapper.get_team_name(home_id)
    away_name = service.team_mapper.get_team_name(away_id)
    
    # Determine game date
    game_date = game_request.game_date or date.today().isoformat()
    
    # Get odds for this matchup
    ml_home, ml_away = service.get_odds_for_game(home_id, away_id)
    
    # Get prediction with odds
    result = service.predictor.predict_game(
        home_id, away_id, game_date, service.feature_builder,
        ml_home=ml_home, ml_away=ml_away
    )
    
    # Get features for context
    features = service.feature_builder.build_features_dict(home_id, away_id, game_date)
    
    context = GameContext(
        home_elo=round(features["elo_home"], 1),
        away_elo=round(features["elo_away"], 1),
        home_recent_wins=round(features["win_roll_home"], 2),
        away_recent_wins=round(features["win_roll_away"], 2),
        home_rest_days=int(features["home_rest_days"]),
        away_rest_days=int(features["away_rest_days"]),
        home_b2b=bool(features["home_b2b"]),
        away_b2b=bool(features["away_b2b"]),
    )
    
    return SinglePredictionResponse(
        home_team=home_name,
        away_team=away_name,
        home_team_id=home_id,
        away_team_id=away_id,
        game_date=game_date,
        home_win_prob=round(result["prob_home_win"], 3),
        away_win_prob=round(result["prob_away_win"], 3),
        confidence=result["confidence_tier"],
        context=context,
        confidence_score=result.get("confidence_score"),
        confidence_qualifier=result.get("confidence_qualifier"),
        confidence_factors=result.get("confidence_factors"),
    )


@router.post("/batch", response_model=BatchPredictionResponse)
@limiter.limit("10/minute")
async def predict_batch(
    request: Request,
    batch_request: PredictBatchRequest,
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Predict multiple game matchups at once.
    
    Limited to 10 requests per minute due to computational cost.
    """
    predictions = []
    
    for game in batch_request.games:
        try:
            pred = await predict_game(request, game, service)
            predictions.append(pred)
        except HTTPException:
            # Skip games that fail (e.g., unknown teams)
            continue
    
    return BatchPredictionResponse(
        generated_at=datetime.now().isoformat(),
        count=len(predictions),
        predictions=predictions,
    )

