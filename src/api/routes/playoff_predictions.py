"""
Playoff prediction endpoints.

All routes are under the /playoff prefix.
Regular season endpoints (/predict/*, /games/*) are completely untouched.
"""

from datetime import datetime, date
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..playoff_schemas import (
    PlayoffBracketResponse,
    PlayoffSeriesResponse,
    PlayoffPredictionsListResponse,
    PlayoffGameWithPrediction,
    PlayoffPredictionInfo,
    PlayoffGameContext,
    SeriesInfo,
    SeriesGameResult,
    PlayoffStatusResponse,
    PlayoffStateReloadResponse,
    PlayInMatchupInfo,
)
from ..dependencies import get_prediction_service, PredictionService
from ..middleware import verify_firebase_token, FirebaseUser

# Playoff-specific imports
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from core.playoff_state_manager import PlayoffStateManager
from core.playoff_series_tracker import PlayoffSeriesTracker, PlayoffSeries, PlayInMatchup
from core.playoff_feature_builder import PlayoffFeatureBuilder, compute_series_win_probability
from core.playoff_espn_client import PlayoffESPNClient

limiter = Limiter(key_func=get_remote_address)
router = APIRouter(prefix="/playoff", tags=["playoffs"])

# Singleton playoff state (loaded once, reloaded on POST /playoff/state/reload)
_playoff_state_manager: Optional[PlayoffStateManager] = None
_playoff_service_cache: Optional[dict] = None


def _get_playoff_state_dir() -> Path:
    return Path(__file__).parent.parent.parent.parent / "state"


def _get_playoff_state_manager() -> PlayoffStateManager:
    global _playoff_state_manager
    if _playoff_state_manager is None:
        _playoff_state_manager = PlayoffStateManager(_get_playoff_state_dir())
    return _playoff_state_manager


def _load_playoff_service() -> dict:
    """Load playoff prediction components (Elo, StatsTracker, SeriesTracker)."""
    global _playoff_service_cache
    if _playoff_service_cache is None:
        pm = _get_playoff_state_manager()
        if not pm.exists():
            return {}
        elo_tracker, stats_tracker, series_tracker = pm.load()
        _playoff_service_cache = {
            "elo_tracker": elo_tracker,
            "stats_tracker": stats_tracker,
            "series_tracker": series_tracker,
        }
    return _playoff_service_cache


def _series_to_info(series: PlayoffSeries) -> SeriesInfo:
    """Convert PlayoffSeries to SeriesInfo schema."""
    return SeriesInfo(
        series_id=series.series_id,
        round_name=series.round_name,
        conference=series.conference,
        higher_seed_id=series.higher_seed_id,
        lower_seed_id=series.lower_seed_id,
        higher_seed_name=series.higher_seed_name,
        lower_seed_name=series.lower_seed_name,
        higher_seed_wins=series.higher_seed_wins,
        lower_seed_wins=series.lower_seed_wins,
        games_played=series.games_played,
        status=series.status,
        winner_id=series.winner_id,
        series_context=series.get_series_context_string(),
    )


def _build_playoff_prediction(
    service: PredictionService,
    playoff_svc: dict,
    home_id: int,
    away_id: int,
    home_name: str,
    away_name: str,
    game_date: str,
    game_time: Optional[str],
    home_series_wins: int,
    away_series_wins: int,
    game_number: int,
    series_context: str,
    include_context: bool = True,
) -> PlayoffGameWithPrediction:
    """Build a PlayoffGameWithPrediction response."""
    elo_tracker = playoff_svc.get("elo_tracker")
    stats_tracker = playoff_svc.get("stats_tracker")

    if not elo_tracker or not stats_tracker:
        # No state available — return game without prediction
        return PlayoffGameWithPrediction(
            game_date=game_date,
            game_time=game_time,
            game_number=game_number,
            home_team=home_name,
            away_team=away_name,
            home_team_id=home_id,
            away_team_id=away_id,
            home_series_wins=home_series_wins,
            away_series_wins=away_series_wins,
        )

    # Build feature builder with playoff adjustments
    from core.playoff_feature_builder import PlayoffFeatureBuilder
    feature_builder = PlayoffFeatureBuilder(
        elo_tracker,
        stats_tracker,
        injury_client=service.injury_client,
    )

    # Get odds (reuse regular season odds client)
    ml_home, ml_away = service.get_odds_for_game(home_id, away_id)

    # Build features with series pressure adjustments
    features_array = feature_builder.build_features(
        home_id, away_id, game_date, ml_home, ml_away,
        home_series_wins=home_series_wins,
        away_series_wins=away_series_wins,
    )

    # Get prediction from the same XGBoost model
    from core.predictor import Predictor
    result = service.predictor.predict_game(
        home_id, away_id, game_date, feature_builder,
        ml_home=ml_home, ml_away=ml_away,
    )

    # Compute series win probability using actual model output
    series_win_prob_home, series_win_prob_away = compute_series_win_probability(
        result["prob_home_win"],
        home_series_wins,
        away_series_wins,
    )

    prediction = PlayoffPredictionInfo(
        home_win_prob=round(result["prob_home_win"], 3),
        away_win_prob=round(result["prob_away_win"], 3),
        confidence=result["confidence_tier"],
        favored="home" if result["prob_home_win"] > 0.5 else "away",
        confidence_score=result.get("confidence_score"),
        confidence_qualifier=result.get("confidence_qualifier"),
        confidence_factors=result.get("confidence_factors"),
        series_win_prob_home=series_win_prob_home,
        series_win_prob_away=series_win_prob_away,
        series_context=series_context,
        game_number=game_number,
    )

    context = None
    if include_context:
        from core.feature_builder import FeatureBuilder, FEATURE_COLS
        features_dict = dict(zip(FEATURE_COLS, features_array))
        injury_summary = service.injury_client.get_matchup_injury_summary(home_id, away_id)
        context = PlayoffGameContext(
            home_elo=round(features_dict["elo_home"], 1),
            away_elo=round(features_dict["elo_away"], 1),
            home_recent_wins=round(features_dict["win_roll_home"], 2),
            away_recent_wins=round(features_dict["win_roll_away"], 2),
            home_rest_days=int(features_dict["home_rest_days"]),
            away_rest_days=int(features_dict["away_rest_days"]),
            home_b2b=bool(features_dict["home_b2b"]),
            away_b2b=bool(features_dict["away_b2b"]),
            home_injuries=injury_summary.get("home_injuries"),
            away_injuries=injury_summary.get("away_injuries"),
            injury_advantage=injury_summary.get("advantage"),
        )

    return PlayoffGameWithPrediction(
        game_date=game_date,
        game_time=game_time,
        game_number=game_number,
        home_team=home_name,
        away_team=away_name,
        home_team_id=home_id,
        away_team_id=away_id,
        home_series_wins=home_series_wins,
        away_series_wins=away_series_wins,
        prediction=prediction,
        context=context,
    )


# =============================================================================
# Endpoints
# =============================================================================

@router.get("/status", response_model=PlayoffStatusResponse)
async def playoff_status():
    """Returns whether playoffs or play-in are currently active."""
    pm = _get_playoff_state_manager()
    if not pm.exists():
        return PlayoffStatusResponse(
            playoffs_active=False,
            play_in_active=False,
            current_round=None,
            season=2026,
        )
    metadata = pm.get_metadata()
    current_round = metadata.get("current_round")
    play_in_active = current_round == "play_in"
    return PlayoffStatusResponse(
        playoffs_active=True,
        play_in_active=play_in_active,
        current_round=current_round,
        season=metadata.get("season", 2026),
        last_updated=metadata.get("last_updated"),
    )


@router.get("/bracket", response_model=PlayoffBracketResponse)
@limiter.limit("30/minute")
async def get_bracket(
    request: Request,
    user: FirebaseUser | None = Depends(verify_firebase_token),
):
    """Returns the full playoff bracket with all series states."""
    pm = _get_playoff_state_manager()
    if not pm.exists():
        raise HTTPException(status_code=404, detail="Playoff state not found. Run bootstrap first.")

    _, _, series_tracker = pm.load()
    metadata = pm.get_metadata()

    east_series = []
    west_series = []
    finals_series = None

    for series in series_tracker.get_all_series():
        info = _series_to_info(series)
        if series.conference.lower() == "east":
            east_series.append(info)
        elif series.conference.lower() == "west":
            west_series.append(info)
        else:
            finals_series = info

    # Build play-in matchup info list
    play_in_infos = [
        PlayInMatchupInfo(
            matchup_id=m.matchup_id,
            conference=m.conference,
            team1_id=m.team1_id,
            team2_id=m.team2_id,
            team1_name=m.team1_name,
            team2_name=m.team2_name,
            game_date=m.game_date,
            home_team_id=m.home_team_id,
            team1_score=m.team1_score,
            team2_score=m.team2_score,
            winner_id=m.winner_id,
            status=m.status,
            context=m.get_context_string(),
        )
        for m in series_tracker.get_all_play_in_matchups()
    ]

    return PlayoffBracketResponse(
        season=series_tracker.season,
        current_round=series_tracker.current_round,
        fetched_at=datetime.now().isoformat(),
        east=east_series,
        west=west_series,
        finals=finals_series,
        playoffs_active=True,
        play_in_active=series_tracker.play_in_active,
        play_in=play_in_infos,
    )


@router.get("/series/{series_id}", response_model=PlayoffSeriesResponse)
@limiter.limit("30/minute")
async def get_series(
    series_id: str,
    request: Request,
    service: PredictionService = Depends(get_prediction_service),
    user: FirebaseUser | None = Depends(verify_firebase_token),
):
    """Returns a single series with game history and next game prediction."""
    pm = _get_playoff_state_manager()
    if not pm.exists():
        raise HTTPException(status_code=404, detail="Playoff state not found.")

    _, _, series_tracker = pm.load()
    series = series_tracker.get_series(series_id)
    if series is None:
        raise HTTPException(status_code=404, detail=f"Series '{series_id}' not found.")

    # Build game history
    game_history = [
        SeriesGameResult(
            game_number=g.game_number,
            game_date=g.game_date,
            home_team_id=g.home_team_id,
            away_team_id=g.away_team_id,
            home_score=g.home_score,
            away_score=g.away_score,
            winner_id=g.winner_id,
            status=g.status,
        )
        for g in series.games
    ]

    # Build next game prediction if series is not complete
    next_game_pred = None
    if not series.is_complete:
        try:
            playoff_svc = _load_playoff_service()
            home_id = series.get_next_game_home_team()
            away_id = (
                series.lower_seed_id
                if home_id == series.higher_seed_id
                else series.higher_seed_id
            )
            home_name = (
                series.higher_seed_name
                if home_id == series.higher_seed_id
                else series.lower_seed_name
            )
            away_name = (
                series.lower_seed_name
                if away_id == series.lower_seed_id
                else series.higher_seed_name
            )
            home_series_wins = (
                series.higher_seed_wins
                if home_id == series.higher_seed_id
                else series.lower_seed_wins
            )
            away_series_wins = (
                series.lower_seed_wins
                if away_id == series.lower_seed_id
                else series.higher_seed_wins
            )
            next_game_pred = _build_playoff_prediction(
                service=service,
                playoff_svc=playoff_svc,
                home_id=home_id,
                away_id=away_id,
                home_name=home_name,
                away_name=away_name,
                game_date=date.today().isoformat(),
                game_time=None,
                home_series_wins=home_series_wins,
                away_series_wins=away_series_wins,
                game_number=series.next_game_number,
                series_context=series.get_series_context_string(),
            )
        except Exception as e:
            print(f"Warning: Could not build prediction for series {series_id}: {e}")

    return PlayoffSeriesResponse(
        series_id=series.series_id,
        round_name=series.round_name,
        conference=series.conference,
        higher_seed_id=series.higher_seed_id,
        lower_seed_id=series.lower_seed_id,
        higher_seed_name=series.higher_seed_name,
        lower_seed_name=series.lower_seed_name,
        higher_seed_wins=series.higher_seed_wins,
        lower_seed_wins=series.lower_seed_wins,
        games_played=series.games_played,
        status=series.status,
        winner_id=series.winner_id,
        series_context=series.get_series_context_string(),
        game_history=game_history,
        next_game_prediction=next_game_pred,
    )


@router.get("/predict/today", response_model=PlayoffPredictionsListResponse)
@limiter.limit("30/minute")
async def predict_playoff_today(
    request: Request,
    service: PredictionService = Depends(get_prediction_service),
    user: FirebaseUser | None = Depends(verify_firebase_token),
):
    """Get predictions for today's playoff games."""
    return await predict_playoff_date(date.today().isoformat(), request, service)


@router.get("/predict/{game_date}", response_model=PlayoffPredictionsListResponse)
@limiter.limit("30/minute")
async def predict_playoff_date(
    game_date: str,
    request: Request,
    service: PredictionService = Depends(get_prediction_service),
    user: FirebaseUser | None = Depends(verify_firebase_token),
):
    """Get predictions for playoff games on a specific date."""
    try:
        parsed_date = datetime.strptime(game_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid date format: {game_date}. Use YYYY-MM-DD."
        )

    # Fetch play-in and playoff games
    try:
        espn_client = PlayoffESPNClient(service.team_mapper)
        play_in_games = espn_client.get_scheduled_play_in_games(parsed_date)
        playoff_games = espn_client.get_scheduled_playoff_games(parsed_date)
        games = play_in_games + playoff_games
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch games from ESPN: {e}")

    playoff_svc = _load_playoff_service()
    series_tracker: Optional[PlayoffSeriesTracker] = playoff_svc.get("series_tracker")

    predictions = []
    for game in games:
        if game.home_team_id is None or game.away_team_id is None:
            continue

        is_play_in = getattr(game, "is_play_in", False)

        # Play-in: no series wins or best-of-7 context
        if is_play_in:
            home_short = game.home_team.split()[-1]
            away_short = game.away_team.split()[-1]
            series_context = f"{away_short} @ {home_short} — Play-In"
            try:
                pred = _build_playoff_prediction(
                    service=service,
                    playoff_svc=playoff_svc,
                    home_id=game.home_team_id,
                    away_id=game.away_team_id,
                    home_name=game.home_team,
                    away_name=game.away_team,
                    game_date=game.game_date,
                    game_time=game.game_time,
                    home_series_wins=0,
                    away_series_wins=0,
                    game_number=1,
                    series_context=series_context,
                )
                pred.series_id = game.series_id
                pred.round_name = "play_in"
                pred.conference = game.conference
                pred.is_play_in = True
                predictions.append(pred)
            except Exception as e:
                print(f"Warning: Failed to build play-in prediction for {game}: {e}")
            continue

        # Regular playoff game: look up series context
        home_series_wins = 0
        away_series_wins = 0
        game_number = game.game_number or 1
        series_id = game.series_id
        round_name = game.round_name
        conference = game.conference
        series_context = f"Game {game_number}"

        if series_tracker:
            series = series_tracker.get_series_for_teams(
                game.home_team_id, game.away_team_id
            )
            if series:
                series_id = series.series_id
                round_name = series.round_name
                conference = series.conference
                series_context = series.get_series_context_string()
                if game.home_team_id == series.higher_seed_id:
                    home_series_wins = series.higher_seed_wins
                    away_series_wins = series.lower_seed_wins
                else:
                    home_series_wins = series.lower_seed_wins
                    away_series_wins = series.higher_seed_wins
                game_number = series.next_game_number

        try:
            pred = _build_playoff_prediction(
                service=service,
                playoff_svc=playoff_svc,
                home_id=game.home_team_id,
                away_id=game.away_team_id,
                home_name=game.home_team,
                away_name=game.away_team,
                game_date=game.game_date,
                game_time=game.game_time,
                home_series_wins=home_series_wins,
                away_series_wins=away_series_wins,
                game_number=game_number,
                series_context=series_context,
            )
            pred.series_id = series_id
            pred.round_name = round_name
            pred.conference = conference
            predictions.append(pred)
        except Exception as e:
            print(f"Warning: Failed to build prediction for {game}: {e}")

    pm = _get_playoff_state_manager()
    current_round = pm.get_metadata().get("current_round") if pm.exists() else None

    return PlayoffPredictionsListResponse(
        date=game_date,
        generated_at=datetime.now().isoformat(),
        round_name=current_round,
        count=len(predictions),
        games=predictions,
    )


@router.post("/state/reload", response_model=PlayoffStateReloadResponse)
async def reload_playoff_state():
    """
    Reload playoff state from disk.

    Called by the Cloud Run job after uploading updated state to GCS.
    """
    global _playoff_service_cache
    _playoff_service_cache = None  # Force reload on next request
    return PlayoffStateReloadResponse(
        status="ok",
        reloaded_at=datetime.now().isoformat(),
    )
