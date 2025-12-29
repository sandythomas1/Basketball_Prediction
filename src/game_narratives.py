import pandas as pd
from pathlib import Path

INPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_game_cards.csv"
)

OUTPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_game_narratives.csv"
)

def build_narrative(row):
    """
    Generates an app-safe, human-readable explanation for each game.
    """

    if row["upset_alert"]:
        return (
            "This matchup shows unusual instability. Performance patterns "
            "suggest the outcome may defy expectations."
        )

    if row["high_uncertainty"]:
        return (
            "Both teams enter this game with volatile recent trends, "
            "making the result harder to anticipate."
        )

    if row["high_disagreement"]:
        return (
            "Analytical models and external consensus differ on this matchup, "
            "highlighting contrasting performance signals."
        )

    prob = row["model_prob_home"]

    if prob >= 0.65:
        return (
            "Recent performance indicators point to a clear advantage for the home team."
        )

    if prob >= 0.57:
        return (
            "The home team holds a slight performance edge, though the matchup remains competitive."
        )

    return (
        "This game profiles as evenly matched, with no strong advantage on either side."
    )


def main():
    df = pd.read_csv(INPUT_PATH, parse_dates=["game_date"])

    df["game_summary"] = df.apply(build_narrative, axis=1)

    # Optional: short tag for compact UI elements
    df["summary_tag"] = df["game_summary"].str.split(".").str[0]

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUTPUT_PATH, index=False)

    print(f"Saved narrative-enhanced game data to: {OUTPUT_PATH}")
    print("\nSample rows:")
    print(df.head(10)[[
        "game_date",
        "team_id_home",
        "team_id_away",
        "ui_label",
        "game_summary"
    ]])


if __name__ == "__main__":
    main()
