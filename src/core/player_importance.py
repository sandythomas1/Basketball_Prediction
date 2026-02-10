"""
Player Importance Classification for Injury Impact Assessment.

Classifies NBA players into tiers to apply appropriate Elo adjustments
when they are injured.
"""

from typing import Optional
from enum import Enum


class PlayerTier(Enum):
    """Player importance tiers."""
    ALL_STAR = "all_star"  # 2.5x multiplier
    STARTER = "starter"     # 1.5x multiplier
    BENCH = "bench"         # 1.0x multiplier


# =============================================================================
# All-Star Players List (2025-2026 Season)
# =============================================================================
# Update this list at the start of each season based on:
# - Previous season All-Star selections
# - All-NBA teams
# - MVP candidates
# - Impact metrics (PER, Win Shares, etc.)

ALL_STAR_PLAYERS = {
    # Eastern Conference
    "Giannis Antetokounmpo",
    "Joel Embiid",
    "Jayson Tatum",
    "Jaylen Brown",
    "Damian Lillard",
    "Donovan Mitchell",
    "Darius Garland",
    "Trae Young",
    "Jimmy Butler",
    "Bam Adebayo",
    "Tyrese Haliburton",
    "Paolo Banchero",
    "Franz Wagner",
    "Jalen Brunson",
    "Julius Randle",
    "Scottie Barnes",
    "DeMar DeRozan",
    "LaMelo Ball",
    "Cade Cunningham",
    
    # Western Conference
    "Nikola Jokic",
    "Luka Doncic",
    "Shai Gilgeous-Alexander",
    "Kevin Durant",
    "Devin Booker",
    "Stephen Curry",
    "LeBron James",
    "Anthony Davis",
    "Kawhi Leonard",
    "Paul George",
    "Anthony Edwards",
    "Karl-Anthony Towns",
    "Ja Morant",
    "Zion Williamson",
    "Brandon Ingram",
    "Domantas Sabonis",
    "De'Aaron Fox",
    "Victor Wembanyama",
    "Alperen Sengun",
    "Lauri Markkanen",
    
    # Rising Stars / Consistent All-Stars
    "Tyrese Maxey",
    "Desmond Bane",
    "Jaren Jackson Jr.",
    "Evan Mobley",
    "Jalen Williams",
    "Mikal Bridges",
    "OG Anunoby",
    "Kristaps Porzingis",
}

# Normalize names for matching (lowercase, no special chars)
ALL_STAR_PLAYERS_NORMALIZED = {
    name.lower().replace("'", "").replace(".", "").strip() 
    for name in ALL_STAR_PLAYERS
}


def normalize_player_name(name: str) -> str:
    """
    Normalize player name for matching.
    
    Args:
        name: Player name as it appears in injury reports
    
    Returns:
        Normalized name (lowercase, no special characters)
    """
    import re
    # Remove special characters and convert to lowercase
    normalized = name.lower().replace("'", "").replace(".", "").strip()
    # Collapse multiple spaces into one
    normalized = re.sub(r'\s+', ' ', normalized)
    return normalized


def get_player_tier(player_name: str) -> PlayerTier:
    """
    Determine player importance tier.
    
    Args:
        player_name: Player's full name
    
    Returns:
        PlayerTier enum value
    """
    normalized = normalize_player_name(player_name)
    
    if normalized in ALL_STAR_PLAYERS_NORMALIZED:
        return PlayerTier.ALL_STAR
    
    # Default to STARTER tier (conservative approach)
    # Better to overestimate impact than underestimate
    return PlayerTier.STARTER


def get_tier_multiplier(tier: PlayerTier) -> float:
    """
    Get Elo adjustment multiplier for a player tier.
    
    Args:
        tier: Player tier
    
    Returns:
        Multiplier value (1.0 to 2.5)
    """
    multipliers = {
        PlayerTier.ALL_STAR: 2.5,
        PlayerTier.STARTER: 1.5,
        PlayerTier.BENCH: 1.0,
    }
    return multipliers[tier]


def get_player_importance_multiplier(player_name: str) -> float:
    """
    Get importance multiplier for a player (convenience function).
    
    Args:
        player_name: Player's full name
    
    Returns:
        Multiplier value (1.0 to 2.5)
    """
    tier = get_player_tier(player_name)
    return get_tier_multiplier(tier)


def is_all_star(player_name: str) -> bool:
    """
    Check if a player is in the All-Star tier.
    
    Args:
        player_name: Player's full name
    
    Returns:
        True if player is All-Star tier
    """
    return get_player_tier(player_name) == PlayerTier.ALL_STAR


# =============================================================================
# Testing & Debugging
# =============================================================================

if __name__ == "__main__":
    print("NBA Player Importance Classifier")
    print("=" * 60)
    
    # Test some known players
    test_players = [
        "LeBron James",
        "Stephen Curry",
        "Nikola Jokic",
        "Giannis Antetokounmpo",
        "Random Role Player",  # Not in list
        "Victor Wembanyama",
    ]
    
    print("\nTesting player classifications:\n")
    for player in test_players:
        tier = get_player_tier(player)
        multiplier = get_player_importance_multiplier(player)
        print(f"{player:30s} -> {tier.value:10s} (x{multiplier})")
    
    print(f"\nTotal All-Star players tracked: {len(ALL_STAR_PLAYERS)}")
    print(f"Ready for injury impact calculations")
