import pandas as pd
from pathlib import Path

elo_games = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_elo.csv")
out_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/features_2.csv")

#rolling windows
n = 10

def make_team_game_rows(df):

    home = df[["game_id", "game_date", "season_id", "team_id_home", "team_id_away", "pts_home", "pts_away", "home_win"]].copy()
    home.rename(columns={
        "team_id_home": "team_id",
        "team_id_away": "opp_id",
        "pts_home": "pf",
        "pts_away": "pa",
    }, inplace=True)
    home["is_home"] = 1
    home["win"] = home["home_win"]

    away = df[["game_id", "game_date", "season_id", "team_id_away", "team_id_home", "pts_away", "pts_home", "home_win"]].copy()
    away.rename(columns={
        "team_id_away": "team_id",
        "team_id_home": "opp_id",
        "pts_away": "pf",
        "pts_home": "pa",
    }, inplace=True)
    away["is_home"] = 0
    away["win"] = ~away["home_win"]

    team_games = pd.concat([home, away], ignore_index=True)
    team_games = team_games.sort_values(["team_id", "game_date"]).reset_index(drop=True)
    return team_games

def add_rolling_features(team_games, n):
    pass