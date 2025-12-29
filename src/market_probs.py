import pandas as pd
from pathlib import Path

# ===============================
# Paths (adjust ONLY if needed)
# ===============================
ODDS_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/odds_with_team_ids.csv"
)

# This file must contain model predictions per game
# Required columns:
# game_date, team_id_home, team_id_away, home_win, model_prob_home
MODEL_PREDS_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/model_predictions.csv"
)

OUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/market_edges.csv"
)


# ===============================
# Moneyline → Probability
# ===============================
def moneyline_to_prob(ml):
    if pd.isna(ml):
        return None
    ml = float(ml)
    if ml < 0:
        return (-ml) / (-ml + 100)
    else:
        return 100 / (ml + 100)


def main():
    # -------------------------------
    # Load data
    # -------------------------------
    odds = pd.read_csv(ODDS_PATH, parse_dates=["date"])
    preds = pd.read_csv(MODEL_PREDS_PATH, parse_dates=["game_date"])

    # Rename for consistency
    odds = odds.rename(columns={"date": "game_date"})

    # -------------------------------
    # Convert moneylines to probs
    # -------------------------------
    odds["market_prob_home"] = odds["moneyline_home"].apply(moneyline_to_prob)
    odds["market_prob_away"] = odds["moneyline_away"].apply(moneyline_to_prob)

    # Drop rows with missing market prices
    odds = odds.dropna(subset=["market_prob_home"])

    # -------------------------------
    # Merge odds + model predictions
    # -------------------------------
    merged = odds.merge(
        preds[
            [
                "game_date",
                "team_id_home",
                "team_id_away",
                "home_win",
                "model_prob_home",
            ]
        ],
        on=["game_date", "team_id_home", "team_id_away"],
        how="inner",
    )

    print(f"Merged rows: {len(merged)}")

    # -------------------------------
    # Compute model edge
    # -------------------------------
    merged["model_edge"] = (
        merged["model_prob_home"] - merged["market_prob_home"]
    )

    # -------------------------------
    # Tier-2 Sanity Checks
    # -------------------------------
    print("\n--- Sanity Checks ---")

    print(
        "Market prob mean:",
        round(merged["market_prob_home"].mean(), 4),
    )
    print(
        "True home win rate:",
        round(merged["home_win"].mean(), 4),
    )

    print(
        "Model edge mean:",
        round(merged["model_edge"].mean(), 5),
    )
    print(
        "Model edge std:",
        round(merged["model_edge"].std(), 5),
    )

    print("\nEdge distribution:")
    print(
        merged["model_edge"].describe(
            percentiles=[0.01, 0.05, 0.95, 0.99]
        )
    )

    # -------------------------------
    # Show extreme edges (inspection)
    # -------------------------------
    print("\nTop positive edges:")
    print(
        merged.sort_values("model_edge", ascending=False)
        .head(5)[
            [
                "game_date",
                "team_id_home",
                "team_id_away",
                "market_prob_home",
                "model_prob_home",
                "model_edge",
            ]
        ]
    )

    print("\nTop negative edges:")
    print(
        merged.sort_values("model_edge")
        .head(5)[
            [
                "game_date",
                "team_id_home",
                "team_id_away",
                "market_prob_home",
                "model_prob_home",
                "model_edge",
            ]
        ]
    )

    # -------------------------------
    # Save output
    # -------------------------------
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    merged.to_csv(OUT_PATH, index=False)
    print(f"\nSaved market edges to: {OUT_PATH}")


if __name__ == "__main__":
    main()
