"""
API Configuration - Environment-based settings for production/development.
"""

import os
from typing import List
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.

    Environment Variables:
        - ENVIRONMENT: "production" or "development" (default: "development")
        - ALLOWED_ORIGINS: Comma-separated list of allowed CORS origins
        - RATE_LIMIT_PER_MINUTE: API rate limit per minute per IP (default: 60)
        - DEBUG: Enable debug mode (default: False in production)
        - ODDS_API_KEY: API key for The Odds API (free tier: 500 req/month)
        - STATE_BUCKET: GCS bucket for shared state sync (Cloud Run)
        - STATE_PREFIX: GCS prefix for state files (default: state)
        - FIREBASE_AUTH_REQUIRED: Require Firebase token on protected routes (default: false)
        - SHOW_DOCS: Force-enable API docs regardless of environment (default: false)
    """

    # Environment mode
    environment: str = "development"

    # CORS settings — locked to specific origins in production.
    # Set ALLOWED_ORIGINS=https://your-domain.com in prod .env.
    # Development defaults to "*" for convenience.
    allowed_origins: str = ""

    # Rate limiting
    rate_limit_per_minute: int = 60
    rate_limit_per_second: int = 10

    # Debug mode
    debug: bool = True

    # API metadata
    api_title: str = "NBA Game Prediction API"
    api_version: str = "2.0.0"

    # External API keys
    odds_api_key: str = ""

    # Shared Cloud Run state sync
    state_bucket: str = ""
    state_prefix: str = "state"

    # Auth
    firebase_auth_required: bool = False

    # Docs override
    show_docs: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @property
    def is_production(self) -> bool:
        """Check if running in production mode."""
        return self.environment.lower() == "production"

    @property
    def cors_origins(self) -> List[str]:
        """
        Parse ALLOWED_ORIGINS into a list.

        Production with no explicit value → empty list (blocks all cross-origin).
        Development with no explicit value → ["*"] for convenience.
        """
        raw = self.allowed_origins.strip()
        if not raw:
            return ["*"] if not self.is_production else []
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]

    @property
    def should_show_docs(self) -> bool:
        """Expose /docs and /redoc only in development (or when SHOW_DOCS=true)."""
        if self.show_docs:
            return True
        return not self.is_production


@lru_cache()
def get_settings() -> Settings:
    """
    Get cached settings instance.

    Uses lru_cache to ensure settings are loaded only once.
    """
    return Settings()


# Production configuration recommendations:
#
# Create a .env file for production with:
#
# ENVIRONMENT=production
# ALLOWED_ORIGINS=https://your-app-domain.com,https://your-flutter-web.com
# RATE_LIMIT_PER_MINUTE=30
# RATE_LIMIT_PER_SECOND=5
# DEBUG=False
# ODDS_API_KEY=your_key_from_the_odds_api_com
# FIREBASE_AUTH_REQUIRED=true
# STATE_BUCKET=nba-prediction-data-metadata
