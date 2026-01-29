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
    """
    
    # Environment mode
    environment: str = "development"
    
    # CORS settings
    allowed_origins: str = "*"
    
    # Rate limiting
    rate_limit_per_minute: int = 60
    rate_limit_per_second: int = 10
    
    # Debug mode
    debug: bool = True
    
    # API metadata
    api_title: str = "NBA Game Prediction API"
    api_version: str = "1.0.0"
    
    # External API keys
    odds_api_key: str = ""  # The Odds API key for fetching betting lines
    
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
        Get list of allowed CORS origins.
        
        In production, parse comma-separated list.
        In development, allow all origins if set to "*".
        """
        if self.allowed_origins == "*":
            return ["*"]
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]
    
    @property
    def should_show_docs(self) -> bool:
        """Determine if API docs should be exposed."""
        # In production, you might want to disable docs
        # For now, we keep them enabled but could be configured
        return True


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