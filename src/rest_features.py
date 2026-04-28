import pandas as pd
from pathlib import Path
import argparse
import sys

# Add core path to import LeagueConfig
sys.path.insert(0, str(Path(__file__).parent))
from core.league_config import NBA_CONFIG, WNBA_CONFIG, CBB_CONFIG

def make_team_schedule_rows(games: pd.DataFrame) -> pd.DataFrame:
    # Create 2 rows per game so we can compute "days since last game" per team
    home = games[["game_id", "game_date", "season_id", "team_id_home"]].copy()
    home.rename(columns={"team_id_home": "team_id"}, inplace=True)

    away = games[["game_id", "game_date", "season_id", "team_id_away"]].copy()
    away.rename(columns={"team_id_away": "team_id"}, inplace=True)

    team_rows = pd.concat([home, away], ignore_index=True)
    team_rows = team_rows.sort_values(["team_id", "game_date", "game_id"]).reset_index(drop=True)
    return team_rows

def compute_rest_days(team_rows: pd.DataFrame) -> pd.DataFrame:
    g = team_rows.groupby("team_id", group_keys=False)

    # previous game date for that team
    team_rows["prev_game_date"] = g["game_date"].shift(1)

    # rest days = difference in days between current game and previous game
    team_rows["rest_days"] = (team_rows["game_date"] - team_rows["prev_game_date"]).dt.days

    # If no previous game, use a neutral rest value (we'll fill later)
    return team_rows

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--league", default="nba", choices=["nba", "wnba", "cbb"])
    args = parser.parse_args()
    
    if args.league == "wnba":
        in_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_games_with_elo.csv"
        out_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_games_with_elo_rest.csv"
    elif args.league == "cbb":
        in_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_games_with_elo.csv"
        out_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_games_with_elo_rest.csv"
    else:
        in_path = Path(__file__).parent.parent / "data" / "processed" / "games_with_elo.csv"
        out_path = Path(__file__).parent.parent / "data" / "processed" / "games_with_elo_rest.csv"

    games = pd.read_csv(in_path, parse_dates=["game_date"])
    games["season_id"] = games["season_id"].astype(int)

    team_rows = make_team_schedule_rows(games)
    team_rows = compute_rest_days(team_rows)

    # Merge rest days back for home/away
    home_rest = team_rows[["game_id", "team_id", "rest_days"]].copy()
    home_rest.rename(columns={"team_id": "team_id_home", "rest_days": "home_rest_days"}, inplace=True)

    away_rest = team_rows[["game_id", "team_id", "rest_days"]].copy()
    away_rest.rename(columns={"team_id": "team_id_away", "rest_days": "away_rest_days"}, inplace=True)

    out = games.merge(home_rest, on=["game_id", "team_id_home"], how="left") \
               .merge(away_rest, on=["game_id", "team_id_away"], how="left")

    # Fill missing rest days (first game of a team in dataset/season)
    # Use 7 as a conservative "fully rested" default
    out["home_rest_days"] = out["home_rest_days"].fillna(7)
    out["away_rest_days"] = out["away_rest_days"].fillna(7)

    # Cap rest days so long breaks don't explode magnitude
    out["home_rest_days"] = out["home_rest_days"].clip(lower=0, upper=14)
    out["away_rest_days"] = out["away_rest_days"].clip(lower=0, upper=14)

    out["home_b2b"] = (out["home_rest_days"] == 1).astype(int)
    out["away_b2b"] = (out["away_rest_days"] == 1).astype(int)
    out["rest_diff"] = out["home_rest_days"] - out["away_rest_days"]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(out_path, index=False)

    print("Saved:", out_path)
    print("Shape:", out.shape)
    print(out[["game_date","season_id","team_id_home","team_id_away","home_rest_days","away_rest_days","home_b2b","away_b2b","rest_diff"]].head())

if __name__ == "__main__":
    main()
