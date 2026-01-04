"""
NBA Prediction API - FastAPI Application

Run with:
    uvicorn src.api.main:app --reload --port 8000

Production:
    uvicorn src.api.main:app --host 0.0.0.0 --port 8000
"""

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routes import predictions, games, health


# =============================================================================
# Application Setup
# =============================================================================

app = FastAPI(
    title="NBA Game Prediction API",
    description="""
    REST API for NBA game predictions.
    
    ## Features
    
    - **Predictions**: Get win probability predictions for upcoming games
    - **Games**: Fetch game schedules from ESPN with optional predictions
    - **Teams**: List all NBA teams with current Elo ratings
    
    ## Usage
    
    Get today's predictions:
    ```
    GET /predict/today
    ```
    
    Predict a specific matchup:
    ```
    POST /predict/game
    {
        "home_team": "Lakers",
        "away_team": "Celtics"
    }
    ```
    
    Get games with predictions:
    ```
    GET /games/today/with-predictions
    ```
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)


# =============================================================================
# CORS Middleware
# =============================================================================

# Allow all origins for development
# In production, restrict to your Flutter app's domain
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change to specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# Routes
# =============================================================================

app.include_router(health.router)
app.include_router(predictions.router)
app.include_router(games.router)


# =============================================================================
# Root Endpoint
# =============================================================================

@app.get("/", tags=["root"])
async def root():
    """
    API root - basic info and links.
    """
    return {
        "name": "NBA Game Prediction API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
        "endpoints": {
            "predictions": {
                "today": "/predict/today",
                "by_date": "/predict/{date}",
                "single_game": "POST /predict/game",
                "batch": "POST /predict/batch",
            },
            "games": {
                "today": "/games/today",
                "by_date": "/games/{date}",
                "with_predictions": "/games/today/with-predictions",
            },
            "system": {
                "health": "/health",
                "state_info": "/state/info",
                "teams": "/teams",
                "reload_state": "POST /state/reload",
            },
        },
    }


# =============================================================================
# Startup Event
# =============================================================================

@app.on_event("startup")
async def startup_event():
    """
    Initialize components on startup.
    """
    from .dependencies import get_prediction_service
    
    try:
        service = get_prediction_service()
        print(f"✓ Loaded predictor: {service.predictor}")
        print(f"✓ Loaded state: {service.elo_tracker}")
        print("✓ API ready to serve predictions")
    except Exception as e:
        print(f"⚠ Warning: Could not load prediction service: {e}")
        print("  Run bootstrap_state.py and xgb_boost_model.py first")

