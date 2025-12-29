import pandas as pd
from pathlib import Path

# =========================
# Paths
# =========================
INPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_game_signals.csv"
)

OUTPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_game_cards.csv"
)

# =========================
# Confidence tier logic
# =========================
def confidence_tier(p):
    """
    Interpretable, non-betting confidence buckets.
    """
    if p >= 0.75:
        return "Heavy Favorite"
    elif p >= 0.65:
        return "Moderate Favorite"
    elif p >= 0.55:
        return "Lean Favorite"
    elif p >= 0.45:
        return "Toss-Up"
    elif p >= 0.35:
        return "Lean Underdog"
    else:
        return "Strong Underdog"

# =========================
# Explanation builder
# =========================
def build_explanation(row):
    """
    Human-readable explanation strings for app display.
    Multiple signals can stack.
    """
    reasons = []

    # Rest advantage
    if row.get("rest_diff", 0) >= 2:
        reasons.append("Home team more rested")
    elif row.get("rest_diff", 0) <= -2:
        reasons.append("Away team more rested")

    # Back-to-back
    if row.get("home_b2b", False):
        reasons.append("Home team on back-to-back")
    if row.get("away_b2b", False):
        reasons.append("Away team on back-to-back")

    # Disagreement / uncertainty flags
    if row.get("high_disagreement", False):
        reasons.append("Model and consensus disagree")

    if row.get("high_uncertainty", False):
        reasons.append("High-variance matchup")

    if row.get("upset_alert", False):
        reasons.append("Upset potential")

    # Confidence framing
    if row.get("high_confidence", False):
        reasons.append("Strong model confidence")

    if not reasons:
        reasons.append("Balanced matchup")

    return " • ".join(reasons)

# =========================
# Main pipeline
# =========================
def main():
    df = pd.read_csv(INPUT_PATH, parse_dates=["game_date"])

    # Basic validation
    required_cols = {
        "game_date",
        "team_id_home",
        "team_id_away",
        "model_prob_home",
    }
    missing = required_cols - set(df.columns)
    if missing:
        raise ValueError(f"Missing required columns: {missing}")

    # Confidence tiers
    df["confidence_tier"] = df["model_prob_home"].apply(confidence_tier)

    # Explanation text
    df["summary_label"] = df.apply(build_explanation, axis=1)

    # Sort for app consumption (most interesting first)
    df = df.sort_values(
        by=["high_uncertainty", "high_disagreement", "model_prob_home"],
        ascending=[False, False, False],
    )

    # Select app-facing columns only
    app_cols = [
        "game_date",
        "team_id_home",
        "team_id_away",
        "model_prob_home",
        "confidence_tier",
        "summary_label",
        "high_confidence",
        "high_uncertainty",
        "high_disagreement",
        "upset_alert",
    ]

    df_out = df[app_cols].copy()

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    df_out.to_csv(OUTPUT_PATH, index=False)

    print(f"Saved app game cards to: {OUTPUT_PATH}")
    print("\nSample rows:")
    print(df_out.head(10))


if __name__ == "__main__":
    main()
