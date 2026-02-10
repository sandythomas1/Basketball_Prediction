"""
Configuration for NBA Prediction System.

Centralized configuration for injury adjustments, caching, and other
system parameters.
"""

import os
from typing import Optional


# =============================================================================
# Injury Adjustment Settings
# =============================================================================

# Enable/disable injury-based Elo adjustments
INJURY_ADJUSTMENTS_ENABLED = os.getenv(
    "INJURY_ADJUSTMENTS_ENABLED", 
    "true"
).lower() in ("true", "1", "yes")

# Elo points deducted per severity point
# Severity calculation: status_weight * player_importance_multiplier
# Example: Out (1.0) × All-Star (2.5) = 2.5 severity → 2.5 × 20 = -50 Elo
INJURY_ADJUSTMENT_MULTIPLIER = int(os.getenv(
    "INJURY_ADJUSTMENT_MULTIPLIER",
    "20"  # Aggressive setting
))

# Maximum Elo penalty per team (prevent extreme swings)
INJURY_MAX_ADJUSTMENT = int(os.getenv(
    "INJURY_MAX_ADJUSTMENT",
    "-100"
))

# Minimum Elo penalty (prevent tiny adjustments from minor injuries)
INJURY_MIN_ADJUSTMENT = int(os.getenv(
    "INJURY_MIN_ADJUSTMENT",
    "-5"
))


# =============================================================================
# Player Importance Multipliers
# =============================================================================

# All-Star tier (MVP candidates, All-NBA players)
PLAYER_IMPORTANCE_ALLSTAR = float(os.getenv(
    "PLAYER_IMPORTANCE_ALLSTAR",
    "2.5"
))

# Starter tier (quality starters, default for unknown players)
PLAYER_IMPORTANCE_STARTER = float(os.getenv(
    "PLAYER_IMPORTANCE_STARTER",
    "1.5"
))

# Bench tier (role players, minimal impact)
PLAYER_IMPORTANCE_BENCH = float(os.getenv(
    "PLAYER_IMPORTANCE_BENCH",
    "1.0"
))


# =============================================================================
# Injury Cache Settings
# =============================================================================

# Time-to-live for cached injury data (in seconds)
# Default: 4 hours (14400 seconds)
# ESPN updates injury reports infrequently, so 4 hours is reasonable
INJURY_CACHE_TTL = int(os.getenv(
    "INJURY_CACHE_TTL",
    "14400"
))

# Enable disk persistence for injury cache (useful for CLI scripts)
INJURY_CACHE_PERSIST = os.getenv(
    "INJURY_CACHE_PERSIST",
    "false"
).lower() in ("true", "1", "yes")

# Path for cache persistence
INJURY_CACHE_FILE = os.getenv(
    "INJURY_CACHE_FILE",
    ".cache/injury_cache.json"
)


# =============================================================================
# Logging & Debugging
# =============================================================================

# Log when injury adjustments are applied
LOG_INJURY_ADJUSTMENTS = os.getenv(
    "LOG_INJURY_ADJUSTMENTS",
    "true"
).lower() in ("true", "1", "yes")

# Debug mode: print detailed injury calculation info
DEBUG_INJURY_CALCULATIONS = os.getenv(
    "DEBUG_INJURY_CALCULATIONS",
    "false"
).lower() in ("true", "1", "yes")


# =============================================================================
# Feature Flags
# =============================================================================

# Fallback to unadjusted Elo if injury fetch fails
INJURY_FALLBACK_ON_ERROR = os.getenv(
    "INJURY_FALLBACK_ON_ERROR",
    "true"
).lower() in ("true", "1", "yes")

# Use cached data even if stale (when ESPN API is down)
INJURY_USE_STALE_CACHE = os.getenv(
    "INJURY_USE_STALE_CACHE",
    "true"
).lower() in ("true", "1", "yes")


# =============================================================================
# Helper Functions
# =============================================================================

def get_config_summary() -> dict:
    """
    Get current configuration as a dictionary.
    
    Returns:
        Dict with all configuration values
    """
    return {
        "injury_adjustments_enabled": INJURY_ADJUSTMENTS_ENABLED,
        "injury_adjustment_multiplier": INJURY_ADJUSTMENT_MULTIPLIER,
        "injury_max_adjustment": INJURY_MAX_ADJUSTMENT,
        "injury_min_adjustment": INJURY_MIN_ADJUSTMENT,
        "player_importance_allstar": PLAYER_IMPORTANCE_ALLSTAR,
        "player_importance_starter": PLAYER_IMPORTANCE_STARTER,
        "player_importance_bench": PLAYER_IMPORTANCE_BENCH,
        "injury_cache_ttl": INJURY_CACHE_TTL,
        "injury_cache_persist": INJURY_CACHE_PERSIST,
        "log_injury_adjustments": LOG_INJURY_ADJUSTMENTS,
        "debug_injury_calculations": DEBUG_INJURY_CALCULATIONS,
        "injury_fallback_on_error": INJURY_FALLBACK_ON_ERROR,
        "injury_use_stale_cache": INJURY_USE_STALE_CACHE,
    }


def print_config():
    """Print current configuration (for debugging)."""
    print("NBA Prediction System Configuration")
    print("=" * 60)
    
    config = get_config_summary()
    
    print("\nInjury Adjustment Settings:")
    print(f"  Enabled: {config['injury_adjustments_enabled']}")
    print(f"  Multiplier: {config['injury_adjustment_multiplier']} Elo per severity point")
    print(f"  Max Adjustment: {config['injury_max_adjustment']} Elo")
    print(f"  Min Adjustment: {config['injury_min_adjustment']} Elo")
    
    print("\nPlayer Importance Multipliers:")
    print(f"  All-Star: x{config['player_importance_allstar']}")
    print(f"  Starter: x{config['player_importance_starter']}")
    print(f"  Bench: x{config['player_importance_bench']}")
    
    print("\nCache Settings:")
    print(f"  TTL: {config['injury_cache_ttl']}s ({config['injury_cache_ttl'] / 3600:.1f} hours)")
    print(f"  Persist to Disk: {config['injury_cache_persist']}")
    
    print("\nFeature Flags:")
    print(f"  Log Adjustments: {config['log_injury_adjustments']}")
    print(f"  Debug Mode: {config['debug_injury_calculations']}")
    print(f"  Fallback on Error: {config['injury_fallback_on_error']}")
    print(f"  Use Stale Cache: {config['injury_use_stale_cache']}")


if __name__ == "__main__":
    print_config()
