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

def add_rolling_features(team_games, n=N):
    g = team_games.groupby("team_id", group_keys=False)

    team_games["pf_roll"] = g["pf"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    team_games["pa_roll"] = g["pa"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    
    team_games["win_roll"] = g["win"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    team_games["margin_roll"] = (team_games["pf_roll"] - team_games["pa_roll"])

    team_games["games_in_window"] = g["win"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).count())

    return team_games

def merge_back_to_games(df, team_games):
    home_features = team_games[team_games["is_home"] == 1][[
        "game_id", "pf_roll", "pa_roll", "win_roll", "margin_roll", "games_in_window"
    ]].copy()
    home_features.rename(columns={
        "team_id": "team_id_home",
        "pf_roll": "pf_roll_home",
        "pa_roll": "pa_roll_home",
        "win_roll": "win_roll_home",
        "margin_roll": "margin_roll_home",
        "games_in_window": "games_in_window_home"
    }, inplace=True)

    away_features = team_games[team_games["is_home"] == 0][[
        "game_id", "pf_roll", "pa_roll", "win_roll", "margin_roll", "games_in_window"
    ]].copy()
    away_features.rename(columns={
        "team_id": "team_id_away",
        "pf_roll": "pf_roll_away",
        "pa_roll": "pa_roll_away",
        "win_roll": "win_roll_away",
        "margin_roll": "margin_roll_away",
        "games_in_window": "games_in_window_away"
    }, inplace=True)

    out = games.merge(home_features, on=["game_id", "team_id_home"], how="left") \
        .merge(away_features, on=["game_id", "team_id_away"], how="left")
    
    return out