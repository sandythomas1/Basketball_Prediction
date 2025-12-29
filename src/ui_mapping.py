import pandas as pd
from pathlib import Path

INPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_game_narratives.csv"
)

OUTPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_game_ui.csv"
)

def map_ui_elements(row):
    """
    Maps analytical signals into UI-safe labels, colors, and icons.
    """

    if row["upset_alert"]:
        return {
            "ui_label": "Upset Watch",
            "ui_color": "orange",
            "ui_icon": "alert-circle",
        }

    if row["high_uncertainty"]:
        return {
            "ui_label": "High Volatility",
            "ui_color": "yellow",
            "ui_icon": "activity",
        }

    if row["high_disagreement"]:
        return {
            "ui_label": "Analysts Split",
            "ui_color": "purple",
            "ui_icon": "shuffle",
        }

    prob = row["model_prob_home"]

    if prob >= 0.65:
        return {
            "ui_label": "Strong Home Trend",
            "ui_color": "green",
            "ui_icon": "trending-up",
        }

    if prob >= 0.57:
        return {
            "ui_label": "Slight Home Edge",
            "ui_color": "blue",
            "ui_icon": "arrow-up",
        }

    return {
        "ui_label": "Even Matchup",
        "ui_color": "gray",
        "ui_icon": "minus",
    }


def main():
    df = pd.read_csv(INPUT_PATH, parse_dates=["game_date"])

    ui_mapped = df.apply(map_ui_elements, axis=1, result_type="expand")

    df = pd.concat([df, ui_mapped], axis=1)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUTPUT_PATH, index=False)

    print(f"Saved UI-ready game cards to: {OUTPUT_PATH}")
    print("\nSample rows:")
    print(df.head(10)[[
        "game_date",
        "team_id_home",
        "team_id_away",
        "ui_label",
        "ui_color",
        "ui_icon",
        "game_summary"
    ]])


if __name__ == "__main__":
    main()
