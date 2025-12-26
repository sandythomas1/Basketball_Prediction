import pandas as pd
from pathlib import Path

IN_PATH  = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_elo_rest.csv")
OUT_PATH = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/features_3.csv")

# rolling window
N = 10

def make_team_game_rows(df):
    home = df[[
        "game_id","game_date","season_id",
        "team_id_home","team_id_away",
        "pts_home","pts_away","home_win"
    ]].copy()
    home.rename(columns={
        "team_id_home":"team_id",
        "team_id_away":"opp_id",
        "pts_home":"pf",
        "pts_away":"pa",
    }, inplace=True)
    home["is_home"] = 1
    home["win"] = home["home_win"]

    away = df[[
        "game_id","game_date","season_id",
        "team_id_away","team_id_home",
        "pts_away","pts_home","home_win"
    ]].copy()
    away.rename(columns={
        "team_id_away":"team_id",
        "team_id_home":"opp_id",
        "pts_away":"pf",
        "pts_home":"pa",
    }, inplace=True)
    away["is_home"] = 0
    away["win"] = 1 - away["home_win"]

    tg = pd.concat([home, away], ignore_index=True)
    tg = tg.sort_values(["team_id","game_date","game_id"]).reset_index(drop=True)
    return tg

def add_rolling(tg, n=N):
    g = tg.groupby("team_id", group_keys=False)

    tg["pf_roll"] = g["pf"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    tg["pa_roll"] = g["pa"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    tg["win_roll"] = g["win"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    tg["margin_roll"] = tg["pf_roll"] - tg["pa_roll"]
    tg["games_in_window"] = g["win"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).count())
    return tg

def merge_back(df, tg):
    home = tg[tg["is_home"] == 1][[
        "game_id","team_id","pf_roll","pa_roll","win_roll","margin_roll","games_in_window"
    ]].copy()
    home.rename(columns={
        "team_id":"team_id_home",
        "pf_roll":"pf_roll_home",
        "pa_roll":"pa_roll_home",
        "win_roll":"win_roll_home",
        "margin_roll":"margin_roll_home",
        "games_in_window":"games_in_window_home"
    }, inplace=True)

    away = tg[tg["is_home"] == 0][[
        "game_id","team_id","pf_roll","pa_roll","win_roll","margin_roll","games_in_window"
    ]].copy()
    away.rename(columns={
        "team_id":"team_id_away",
        "pf_roll":"pf_roll_away",
        "pa_roll":"pa_roll_away",
        "win_roll":"win_roll_away",
        "margin_roll":"margin_roll_away",
        "games_in_window":"games_in_window_away"
    }, inplace=True)

    out = df.merge(home, on=["game_id","team_id_home"], how="left") \
            .merge(away, on=["game_id","team_id_away"], how="left")
    return out

def main():
    df = pd.read_csv(IN_PATH, parse_dates=["game_date"])
    df["season_id"] = df["season_id"].astype(int)

    # Elo diff
    df["elo_diff"] = df["elo_home"] - df["elo_away"]

    tg = make_team_game_rows(df)
    tg = add_rolling(tg)

    feat = merge_back(df, tg)

    # diffs
    feat["pf_roll_diff"] = feat["pf_roll_home"] - feat["pf_roll_away"]
    feat["pa_roll_diff"] = feat["pa_roll_home"] - feat["pa_roll_away"]
    feat["win_roll_diff"] = feat["win_roll_home"] - feat["win_roll_away"]
    feat["margin_roll_diff"] = feat["margin_roll_home"] - feat["margin_roll_away"]

    feature_cols = [
        "elo_home","elo_away","elo_diff","elo_prob",
        "pf_roll_home","pf_roll_away","pf_roll_diff",
        "pa_roll_home","pa_roll_away","pa_roll_diff",
        "win_roll_home","win_roll_away","win_roll_diff",
        "margin_roll_home","margin_roll_away","margin_roll_diff",
        "games_in_window_home","games_in_window_away",
        "home_rest_days","away_rest_days","home_b2b","away_b2b","rest_diff",
    ]

    model_df = feat[["game_date","season_id"] + feature_cols + ["home_win"]].copy()

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    model_df.to_csv(OUT_PATH, index=False)

    print("Saved:", OUT_PATH)
    print("Shape:", model_df.shape)
    print(model_df.head())

if __name__ == "__main__":
    main()
