"""
NBA Prediction API - FastAPI Application

Production-grade API with security headers, rate limiting, and CORS.

Run with:
    Development:  uvicorn src.api.main:app --reload --port 8000
    Production:   uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --workers 4

Environment Variables (see .env.example):
    ENVIRONMENT=production|development
    ALLOWED_ORIGINS=https://your-domain.com
    RATE_LIMIT_PER_MINUTE=60
"""

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .config import get_settings
from .routes import predictions, games, health
from .middleware import RateLimiter, SecurityHeadersMiddleware


# =============================================================================
# Configuration
# =============================================================================

settings = get_settings()


# =============================================================================
# Application Setup
# =============================================================================

app = FastAPI(
    title=settings.api_title,
    description="""
    REST API for NBA game predictions.
    
    ## Features
    
    - **Predictions**: Get win probability predictions for upcoming games
    - **Games**: Fetch game schedules from ESPN with optional predictions
    - **Teams**: List all NBA teams with current Elo ratings
    
    ## Rate Limiting
    
    API requests are rate-limited to prevent abuse:
    - Default: 60 requests per minute per IP
    - Burst: 10 requests per second max
    
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
    """,
    version=settings.api_version,
    docs_url="/docs" if settings.should_show_docs else None,
    redoc_url="/redoc" if settings.should_show_docs else None,
)


# =============================================================================
# Middleware Stack (order matters - last added = first executed)
# =============================================================================

# 1. Security Headers Middleware
app.add_middleware(
    SecurityHeadersMiddleware,
    is_production=settings.is_production,
)

# 2. CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],  # Restrict to needed methods
    allow_headers=["Accept", "Content-Type", "Authorization"],
    max_age=600,  # Cache preflight requests for 10 minutes
)


# =============================================================================
# Rate Limiting
# =============================================================================

# Register rate limiter with app
limiter = RateLimiter.get_limiter()
app.state.limiter = limiter

# Custom rate limit exceeded handler
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


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
@limiter.limit("30/minute")
async def root(request):  # request param required for rate limiting
    """
    API root - basic info and links.
    """
    return {
        "name": settings.api_title,
        "version": settings.api_version,
        "environment": settings.environment,
        "docs": "/docs" if settings.should_show_docs else None,
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
    
    print(f"🚀 Starting {settings.api_title} v{settings.api_version}")
    print(f"📍 Environment: {settings.environment}")
    print(f"🌐 CORS Origins: {settings.cors_origins}")
    print(f"⏱️  Rate Limit: {settings.rate_limit_per_minute}/minute")
    
    try:
        service = get_prediction_service()
        print(f"✓ Loaded predictor: {service.predictor}")
        print(f"✓ Loaded state: {service.elo_tracker}")
        print("✓ API ready to serve predictions")
    except Exception as e:
        print(f"⚠ Warning: Could not load prediction service: {e}")
        print("  Run bootstrap_state.py and xgb_boost_model.py first")


# =============================================================================
# Shutdown Event
# =============================================================================

@app.on_event("shutdown")
async def shutdown_event():
    """
    Cleanup on shutdown.
    """
    print("👋 Shutting down NBA Prediction API")
