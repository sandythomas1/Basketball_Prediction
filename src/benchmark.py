import pandas as pd
from pathlib import Path
from sklearn.metrics import log_loss, brier_score_loss

# =========================
# PATHS
# =========================
MERGED_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/market_edges.csv"
)

OUT_APP_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_game_signals.csv"
)

# =========================
# CONFIG
# =========================
DISAGREE_THRESH = 0.10     # model vs consensus disagreement
UPSET_LOW = 0.45           # consensus says unlikely
UPSET_HIGH = 0.55          # model says likely
CONF_HIGH = 0.70
CONF_LOW = 0.30
UNCERTAINTY_LOW = 0.45
UNCERTAINTY_HIGH = 0.55

# =========================
# CALIBRATION HELPERS
# =========================
def calibration_bins(y_true, probs, bins=10):
    df = pd.DataFrame({
        "y": y_true,
        "p": probs
    })
    df["bin"] = pd.cut(df["p"], bins=bins, labels=False)

    cal = (
        df.groupby("bin")
        .agg(
            mean_pred=("p", "mean"),
            win_rate=("y", "mean"),
            n=("y", "size")
        )
        .reset_index()
    )
    return cal


def main():
    df = pd.read_csv(MERGED_PATH, parse_dates=["game_date"])

    # Rename for semantic clarity (no betting framing)
    df = df.rename(columns={
        "market_prob_home": "consensus_prob_home",
        "model_edge": "prob_delta"
    })

    # =========================
    # GLOBAL METRICS
    # =========================
    model_ll = log_loss(df["home_win"], df["model_prob_home"])
    consensus_ll = log_loss(df["home_win"], df["consensus_prob_home"])

    model_brier = brier_score_loss(df["home_win"], df["model_prob_home"])
    consensus_brier = brier_score_loss(df["home_win"], df["consensus_prob_home"])

    print("\n--- Model vs Consensus (Probability Quality) ---")
    print(f"Model log loss:      {model_ll:.4f}")
    print(f"Consensus log loss:  {consensus_ll:.4f}")
    print(f"Model Brier score:   {model_brier:.4f}")
    print(f"Consensus Brier:     {consensus_brier:.4f}")

    # =========================
    # CALIBRATION
    # =========================
    print("\n--- Calibration (Model) ---")
    cal_model = calibration_bins(df["home_win"], df["model_prob_home"])
    print(cal_model)

    print("\n--- Calibration (Consensus) ---")
    cal_consensus = calibration_bins(df["home_win"], df["consensus_prob_home"])
    print(cal_consensus)

    # =========================
    # APP SIGNALS
    # =========================
    df["high_disagreement"] = df["prob_delta"].abs() >= DISAGREE_THRESH

    df["upset_alert"] = (
        (df["consensus_prob_home"] <= UPSET_LOW) &
        (df["model_prob_home"] >= UPSET_HIGH)
    )

    df["high_confidence"] = (
        (df["model_prob_home"] >= CONF_HIGH) |
        (df["model_prob_home"] <= CONF_LOW)
    )

    df["high_uncertainty"] = (
        (df["model_prob_home"] >= UNCERTAINTY_LOW) &
        (df["model_prob_home"] <= UNCERTAINTY_HIGH)
    )

    # =========================
    # APP OUTPUT
    # =========================
    app_cols = [
        "game_date",
        "team_id_home",
        "team_id_away",
        "model_prob_home",
        "consensus_prob_home",
        "prob_delta",
        "upset_alert",
        "high_disagreement",
        "high_confidence",
        "high_uncertainty",
    ]

    app_df = df[app_cols].copy()

    OUT_APP_PATH.parent.mkdir(parents=True, exist_ok=True)
    app_df.to_csv(OUT_APP_PATH, index=False)

    print(f"\nSaved app-ready signals to: {OUT_APP_PATH}")
    print("\nSample rows:")
    print(app_df.head())


if __name__ == "__main__":
    main()
