"""
Rate Limiting Middleware using slowapi.

Protects API endpoints from abuse by limiting requests per IP address.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request
from fastapi.responses import JSONResponse


# Create limiter instance that uses IP address as key
limiter = Limiter(key_func=get_remote_address)


class RateLimiter:
    """
    Rate limiter configuration.
    
    Usage:
        from src.api.middleware import RateLimiter
        
        # Apply to specific endpoint
        @app.get("/endpoint")
        @RateLimiter.limit("10/minute")
        async def endpoint():
            pass
    """
    
    # Default rate limits
    DEFAULT_LIMIT = "60/minute"
    STRICT_LIMIT = "10/minute"
    RELAXED_LIMIT = "120/minute"
    
    @staticmethod
    def limit(limit_string: str):
        """
        Decorator to apply rate limit to an endpoint.
        
        Args:
            limit_string: Rate limit in format "count/period" 
                         e.g., "10/minute", "100/hour", "5/second"
        """
        return limiter.limit(limit_string)
    
    @staticmethod
    def get_limiter() -> Limiter:
        """Get the limiter instance for app configuration."""
        return limiter


async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    """
    Custom handler for rate limit exceeded errors.
    
    Returns a user-friendly JSON response with retry information.
    """
    return JSONResponse(
        status_code=429,
        content={
            "error": "rate_limit_exceeded",
            "message": "Too many requests. Please slow down.",
            "detail": str(exc.detail),
            "retry_after": getattr(exc, "retry_after", 60),
        },
        headers={
            "Retry-After": str(getattr(exc, "retry_after", 60)),
            "X-RateLimit-Limit": str(exc.detail).split()[0] if exc.detail else "60",
        }
    )
