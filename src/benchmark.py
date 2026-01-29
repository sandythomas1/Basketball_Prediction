import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.metrics import log_loss, brier_score_loss
from core import StatsTracker, ConfidenceScorer

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
    
    # Load state for confidence scoring
    from pathlib import Path as P
    state_path = P(__file__).parent.parent / "state" / "stats.json"
    stats_tracker = StatsTracker.from_file(state_path)
    confidence_scorer = ConfidenceScorer(stats_tracker)

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
    # CONFIDENCE SCORING
    # =========================
    print("\nCalculating confidence scores...")
    
    # Calculate confidence scores for each game
    confidence_scores = []
    confidence_qualifiers = []
    
    for _, row in df.iterrows():
        # Reconstruct feature vector (simplified - using available columns)
        # Note: Full feature reconstruction would require all 23 features
        features = np.array([
            row.get("elo_home", 1500),
            row.get("elo_away", 1500),
            row.get("elo_diff", 0),
            row.get("elo_prob", 0.5),
            row.get("pf_roll_home", 110),
            row.get("pf_roll_away", 110),
            row.get("pf_roll_diff", 0),
            row.get("pa_roll_home", 110),
            row.get("pa_roll_away", 110),
            row.get("pa_roll_diff", 0),
            row.get("win_roll_home", 0.5),
            row.get("win_roll_away", 0.5),
            row.get("win_roll_diff", 0),
            row.get("margin_roll_home", 0),
            row.get("margin_roll_away", 0),
            row.get("margin_roll_diff", 0),
            row.get("games_in_window_home", 10),
            row.get("games_in_window_away", 10),
            row.get("home_rest_days", 2),
            row.get("away_rest_days", 2),
            row.get("home_b2b", 0),
            row.get("away_b2b", 0),
            row.get("rest_diff", 0),
            row.get("consensus_prob_home", 0.5),
            1 - row.get("consensus_prob_home", 0.5),
        ])
        
        try:
            conf_data = confidence_scorer.calculate_confidence_score(
                prob_home=row["model_prob_home"],
                features=features,
                home_id=int(row["team_id_home"]),
                away_id=int(row["team_id_away"]),
            )
            confidence_scores.append(conf_data["score"])
            confidence_qualifiers.append(conf_data["qualifier"])
        except Exception:
            # If scoring fails, use neutral values
            confidence_scores.append(50)
            confidence_qualifiers.append("Moderate")
    
    df["confidence_score"] = confidence_scores
    df["confidence_qualifier"] = confidence_qualifiers

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
        "confidence_score",
        "confidence_qualifier",
    ]

    app_df = df[app_cols].copy()

    OUT_APP_PATH.parent.mkdir(parents=True, exist_ok=True)
    app_df.to_csv(OUT_APP_PATH, index=False)

    print(f"\nSaved app-ready signals to: {OUT_APP_PATH}")
    print("\nSample rows:")
    print(app_df.head())


if __name__ == "__main__":
    main()
