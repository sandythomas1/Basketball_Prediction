"""
Bootstrap script to extract initial state for EloTracker and StatsTracker.

Reads historical game data and computes:
1. Final Elo ratings for each team
2. Last 10 games for each team (for rolling stats)

Saves state to JSON files for tracker initialization.
"""

import json
import pandas as pd
from pathlib import Path
from collections import deque

# ==========================
# Paths
# ==========================
GAMES_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_elo_rest.csv"
)

STATE_DIR = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/state"
)

ELO_STATE_PATH = STATE_DIR / "elo.json"
STATS_STATE_PATH = STATE_DIR / "stats.json"

# ==========================
# Elo constants (from build_elo.py)
# ==========================
DEFAULT_ELO = 1500
K_FACTOR = 20
HOME_COURT_ADVANTAGE = 70
SEASON_CARRYOVER = 0.7


def expected_home_win(e_home: float, e_away: float) -> float:
    """Calculate expected probability that home team wins."""
    exponent = -(e_home - e_away + HOME_COURT_ADVANTAGE) / 400
    return 1 / (1 + 10 ** exponent)


def compute_final_elo(games: pd.DataFrame) -> dict[int, float]:
    """
    Replay all games to compute final Elo ratings.
    
    Args:
        games: DataFrame with game_date, team_id_home, team_id_away, home_win, season_id
        
    Returns:
        Dict mapping team_id -> final Elo rating
    """
    # Sort chronologically
    games = games.sort_values("game_date").reset_index(drop=True)
    
    # Get all teams
    teams = set(games["team_id_home"].unique()) | set(games["team_id_away"].unique())
    elo = {team: DEFAULT_ELO for team in teams}
    
    current_season = None
    
    for _, row in games.iterrows():
        season = row["season_id"]
        
        # Season regression
        if current_season is not None and season != current_season:
            for team in elo:
                elo[team] = SEASON_CARRYOVER * elo[team] + (1 - SEASON_CARRYOVER) * DEFAULT_ELO
        current_season = season
        
        home = row["team_id_home"]
        away = row["team_id_away"]
        
        e_home = elo[home]
        e_away = elo[away]
        p_home = expected_home_win(e_home, e_away)
        
        result = 1.0 if row["home_win"] else 0.0
        
        # Update
        elo[home] = e_home + K_FACTOR * (result - p_home)
        elo[away] = e_away - K_FACTOR * (result - p_home)
    
    return elo


def compute_team_stats(games: pd.DataFrame, window: int = 10) -> dict[int, list[dict]]:
    """
    Extract last N games for each team.
    
    Args:
        games: DataFrame with game data
        window: Number of recent games to keep
        
    Returns:
        Dict mapping team_id -> list of recent games
    """
    # Sort chronologically
    games = games.sort_values("game_date").reset_index(drop=True)
    
    # Get all teams
    teams = set(games["team_id_home"].unique()) | set(games["team_id_away"].unique())
    team_games = {team: deque(maxlen=window) for team in teams}
    
    for _, row in games.iterrows():
        game_date = str(row["game_date"])[:10]  # YYYY-MM-DD
        
        home = row["team_id_home"]
        away = row["team_id_away"]
        pts_home = row["pts_home"]
        pts_away = row["pts_away"]
        home_won = bool(row["home_win"])
        
        # Home team game
        team_games[home].append({
            "pf": int(pts_home),
            "pa": int(pts_away),
            "won": home_won,
            "date": game_date,
        })
        
        # Away team game
        team_games[away].append({
            "pf": int(pts_away),
            "pa": int(pts_home),
            "won": not home_won,
            "date": game_date,
        })
    
    # Convert deques to lists
    return {team: list(games) for team, games in team_games.items()}


def main():
    print("Loading games data...")
    games = pd.read_csv(GAMES_PATH, parse_dates=["game_date"])
    games["season_id"] = games["season_id"].astype(int)
    
    print(f"Total games: {len(games)}")
    print(f"Date range: {games['game_date'].min()} to {games['game_date'].max()}")
    
    # Compute Elo
    print("\nComputing final Elo ratings...")
    elo_state = compute_final_elo(games)
    print(f"Teams tracked: {len(elo_state)}")
    
    # Show some ratings
    sorted_elo = sorted(elo_state.items(), key=lambda x: x[1], reverse=True)
    print("\nTop 5 Elo ratings:")
    for team_id, rating in sorted_elo[:5]:
        print(f"  {team_id}: {rating:.1f}")
    
    print("\nBottom 5 Elo ratings:")
    for team_id, rating in sorted_elo[-5:]:
        print(f"  {team_id}: {rating:.1f}")
    
    # Compute stats
    print("\nExtracting team game history...")
    stats_state = compute_team_stats(games)
    
    # Show sample
    sample_team = list(stats_state.keys())[0]
    print(f"\nSample team {sample_team} last game:")
    print(f"  {stats_state[sample_team][-1]}")
    
    # Save state
    print("\nSaving state files...")
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    
    # Elo state (convert int keys to strings for JSON)
    elo_json = {str(k): v for k, v in elo_state.items()}
    with open(ELO_STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(elo_json, f, indent=2)
    print(f"  Saved Elo state to: {ELO_STATE_PATH}")
    
    # Stats state (convert int keys to strings for JSON)
    stats_json = {str(k): v for k, v in stats_state.items()}
    with open(STATS_STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(stats_json, f, indent=2)
    print(f"  Saved stats state to: {STATS_STATE_PATH}")
    
    print("\nBootstrap complete!")


if __name__ == "__main__":
    main()

