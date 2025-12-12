import pandas as pd
from pathlib import Path

Elo_games = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_elo.csv"
)

out_path = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/features.csv"
)

def main():
    df = pd.read_csv(Elo_games, parse_dates=['game_date'])

    df['elo_diff'] = df['elo_home'] - df['elo_away']

    feature_cols = [
        "elo_home",
        "elo_away",
        "elo_diff",
        "elo_prob"
    ]

    target_col = "home_win"

    model_df = df[
        ["game_date", "season_id"] + feature_cols + [target_col]
    ].copy()
    

    #save
    out_path.parent.mkdir(parents=True, exist_ok=True)
    model_df.to_csv(out_path, index=False)

    print("Features saved to:", out_path)
    print("Shape:", model_df.shape)
    print("Head:\n", model_df.head(10))
    print("Tail:\n", model_df.tail(10))

if __name__ == "__main__":
    main()