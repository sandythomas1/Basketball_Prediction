"""
Games endpoints - ESPN proxy with optional predictions.
"""

from datetime import datetime, date
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends

from ..schemas import (
    GameInfo,
    GameWithPrediction,
    GamesListResponse,
    GamesWithPredictionsResponse,
    PredictionInfo,
    GameContext,
)
from ..dependencies import get_prediction_service, PredictionService


router = APIRouter(prefix="/games", tags=["games"])


def game_result_to_info(game) -> GameInfo:
    """Convert ESPN GameResult to GameInfo schema."""
    return GameInfo(
        game_date=game.game_date,
        game_time=game.game_time,
        home_team=game.home_team,
        away_team=game.away_team,
        home_team_id=game.home_team_id,
        away_team_id=game.away_team_id,
        home_score=game.home_score,
        away_score=game.away_score,
        status=game.status,
    )


def build_game_with_prediction(
    game,
    service: PredictionService,
) -> GameWithPrediction:
    """Build a GameWithPrediction from an ESPN game result."""
    prediction = None
    context = None
    
    # Only add prediction if we can map both teams and game is upcoming
    if (game.home_team_id is not None and 
        game.away_team_id is not None and 
        not game.is_final):
        
        try:
            result = service.predictor.predict_game(
                game.home_team_id,
                game.away_team_id,
                game.game_date,
                service.feature_builder,
            )
            
            prediction = PredictionInfo(
                home_win_prob=round(result["prob_home_win"], 3),
                away_win_prob=round(result["prob_away_win"], 3),
                confidence=result["confidence_tier"],
                favored="home" if result["prob_home_win"] > 0.5 else "away",
                confidence_score=result.get("confidence_score"),
                confidence_qualifier=result.get("confidence_qualifier"),
                confidence_factors=result.get("confidence_factors"),
            )
            
            # Get context
            features = service.feature_builder.build_features_dict(
                game.home_team_id,
                game.away_team_id,
                game.game_date,
            )
            
            # NEW: Fetch injury data
            injury_summary = service.injury_client.get_matchup_injury_summary(
                game.home_team_id,
                game.away_team_id
            )
            
            context = GameContext(
                home_elo=round(features["elo_home"], 1),
                away_elo=round(features["elo_away"], 1),
                home_recent_wins=round(features["win_roll_home"], 2),
                away_recent_wins=round(features["win_roll_away"], 2),
                home_rest_days=int(features["home_rest_days"]),
                away_rest_days=int(features["away_rest_days"]),
                home_b2b=bool(features["home_b2b"]),
                away_b2b=bool(features["away_b2b"]),
                # NEW: Injury data
                home_injuries=injury_summary.get("home_injuries"),
                away_injuries=injury_summary.get("away_injuries"),
                injury_advantage=injury_summary.get("advantage"),
            )
        except Exception:
            # If prediction fails, just skip it
            pass
    
    return GameWithPrediction(
        game_date=game.game_date,
        game_time=game.game_time,
        home_team=game.home_team,
        away_team=game.away_team,
        home_team_id=game.home_team_id,
        away_team_id=game.away_team_id,
        home_score=game.home_score,
        away_score=game.away_score,
        status=game.status,
        prediction=prediction,
        context=context,
    )


@router.get("/today", response_model=GamesListResponse)
async def get_today_games(
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Get today's games from ESPN.
    """
    return await get_games_by_date(date.today().isoformat(), service)


@router.get("/today/with-predictions", response_model=GamesWithPredictionsResponse)
async def get_today_games_with_predictions(
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Get today's games from ESPN with predictions included.
    
    Predictions are only included for upcoming games (not final).
    """
    return await get_games_with_predictions_by_date(date.today().isoformat(), service)


@router.get("/{game_date}", response_model=GamesListResponse)
async def get_games_by_date(
    game_date: str,
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Get games for a specific date from ESPN.
    """
    try:
        parsed_date = datetime.strptime(game_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid date format: {game_date}. Use YYYY-MM-DD."
        )
    
    try:
        games = service.espn_client.get_games(parsed_date)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to fetch games from ESPN: {str(e)}"
        )
    
    return GamesListResponse(
        date=game_date,
        fetched_at=datetime.now().isoformat(),
        count=len(games),
        games=[game_result_to_info(g) for g in games],
    )


@router.get("/{game_date}/with-predictions", response_model=GamesWithPredictionsResponse)
async def get_games_with_predictions_by_date(
    game_date: str,
    service: PredictionService = Depends(get_prediction_service),
):
    """
    Get games for a specific date from ESPN with predictions included.
    
    Predictions are only included for upcoming games (not final).
    """
    try:
        parsed_date = datetime.strptime(game_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid date format: {game_date}. Use YYYY-MM-DD."
        )
    
    try:
        games = service.espn_client.get_games(parsed_date)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to fetch games from ESPN: {str(e)}"
        )
    
    games_with_preds = [build_game_with_prediction(g, service) for g in games]
    
    return GamesWithPredictionsResponse(
        date=game_date,
        fetched_at=datetime.now().isoformat(),
        count=len(games_with_preds),
        games=games_with_preds,
    )

