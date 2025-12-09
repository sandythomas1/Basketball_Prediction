#Predicting probability that the home team wins a given NBA regular-season game
#binary classification, label = 1 if home wins, 0 otherwise

import sqlite3
import pandas as pd
from pathlib import Path

DB_PATH = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/nba.sqlite")

def load_games():
    conn = sqlite3.connect(DB_PATH)

    query = """
    SELECT
        game_id,
        game_date,
        season_id,
        season_type,
        team_id_home,
        team_id_away,
        wl_home,
        pts_home,
        pts_away
    FROM game
    WHERE season_type = 'Regular Season'
    """

    df = pd.read_sql_query(query, conn, parse_dates=['game_date'])
    conn.close()
    return df

def add_home_win_label(df):
    # create binary label: 1 if home team wins, 0 otherwise from 'wl_home' column
    df['home_win'] = df['wl_home'].apply(lambda x: 1 if x == 'W' else 0)

    return df

def main():
    df = load_games()
    print("Raw df shape:", df.shape)

    df = add_home_win_label(df)
    print("with label shape", df.shape)
    print(df.head())

    #save to csv
    out_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_labels.csv")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_path, index=False)
    print(f"Saved processed data to {out_path}")

if __name__ == "__main__":
    main()