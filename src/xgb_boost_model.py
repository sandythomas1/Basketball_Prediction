import pandas as pd
import joblib
from pathlib import Path
from sklearn.metrics import log_loss, accuracy_score, roc_auc_score
from sklearn.linear_model import LogisticRegression
from xgboost import XGBClassifier

# ==========================
# Paths
# ==========================
FEATURES_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/features_3.csv"
)

GAMES_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_elo_rest.csv"
)

MODEL_OUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/models/xgb_v2_modern.json"
)

CALIBRATOR_OUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/models/calibrator.pkl"
)

PREDS_OUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/model_predictions.csv"
)

# ==========================
# Feature columns
# ==========================
FEATURE_COLS = [
    "elo_home","elo_away","elo_diff","elo_prob",
    "pf_roll_home","pf_roll_away","pf_roll_diff",
    "pa_roll_home","pa_roll_away","pa_roll_diff",
    "win_roll_home","win_roll_away","win_roll_diff",
    "margin_roll_home","margin_roll_away","margin_roll_diff",
    "games_in_window_home","games_in_window_away",
    "home_rest_days","away_rest_days",
    "home_b2b","away_b2b","rest_diff",
]

TARGET_COL = "home_win"


# ==========================
# Helpers
# ==========================
def split_by_season(df):
    df = df[df["season_id"] >= 22004].copy()

    train = df[(df["season_id"] >= 22004) & (df["season_id"] <= 22018)]
    val   = df[(df["season_id"] >= 22019) & (df["season_id"] <= 22020)]
    test  = df[df["season_id"] >= 22022]

    return train, val, test


def eval_split(name, y_true, p_pred):
    y_hat = (p_pred >= 0.5).astype(int)
    return {
        "split": name,
        "log_loss": log_loss(y_true, p_pred),
        "accuracy": accuracy_score(y_true, y_hat),
        "roc_auc": roc_auc_score(y_true, p_pred),
        "avg_pred": float(p_pred.mean()),
        "base_rate": float(y_true.mean()),
    }


# ==========================
# Main
# ==========================
def main():
    # ----------------------
    # Load features
    # ----------------------
    df = pd.read_csv(FEATURES_PATH, parse_dates=["game_date"])
    df["season_id"] = df["season_id"].astype(int)

    train, val, test = split_by_season(df)

    print("Split sizes:", {
        "train": len(train),
        "val": len(val),
        "test": len(test),
    })

    print("Season ranges:", {
        "train": (train["season_id"].min(), train["season_id"].max()),
        "val": (val["season_id"].min(), val["season_id"].max()),
        "test": (test["season_id"].min(), test["season_id"].max()),
    })

    X_train, y_train = train[FEATURE_COLS], train[TARGET_COL]
    X_val,   y_val   = val[FEATURE_COLS],   val[TARGET_COL]
    X_test,  y_test  = test[FEATURE_COLS],  test[TARGET_COL]

    # ----------------------
    # Train model
    # ----------------------
    model = XGBClassifier(
        n_estimators=800,
        learning_rate=0.03,
        max_depth=3,
        subsample=0.9,
        colsample_bytree=0.9,
        min_child_weight=5,
        reg_lambda=1.0,
        reg_alpha=0.0,
        objective="binary:logistic",
        eval_metric="logloss",
        random_state=42,
        n_jobs=-1,
    )

    model.fit(
        X_train,
        y_train,
        eval_set=[(X_val, y_val)],
        verbose=False,
    )

    # ----------------------
    # Raw predictions
    # ----------------------
    p_train = model.predict_proba(X_train)[:, 1]
    p_val   = model.predict_proba(X_val)[:, 1]
    p_test  = model.predict_proba(X_test)[:, 1]

    # ----------------------
    # Calibration (VAL → TEST)
    # ----------------------
    calibrator = LogisticRegression(solver="lbfgs")
    calibrator.fit(p_val.reshape(-1, 1), y_val)

    p_val_cal  = calibrator.predict_proba(p_val.reshape(-1, 1))[:, 1]
    p_test_cal = calibrator.predict_proba(p_test.reshape(-1, 1))[:, 1]

    # ----------------------
    # Save calibrator
    # ----------------------
    CALIBRATOR_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(calibrator, CALIBRATOR_OUT_PATH)
    print(f"\nSaved calibrator to: {CALIBRATOR_OUT_PATH}")

    # ----------------------
    # Evaluation
    # ----------------------
    results = [
        eval_split("train", y_train, p_train),
        eval_split("val", y_val, p_val),
        eval_split("test", y_test, p_test),
        eval_split("val_cal", y_val, p_val_cal),
        eval_split("test_cal", y_test, p_test_cal),
    ]

    print("\nPerformance:")
    print(pd.DataFrame(results))

    # ----------------------
    # Feature importance
    # ----------------------
    importances = model.get_booster().get_score(importance_type="gain")
    imp_df = (
        pd.DataFrame([{"feature": k, "gain": v} for k, v in importances.items()])
        .sort_values("gain", ascending=False)
    )

    print("\nFeature importance (gain):")
    print(imp_df)

    # ----------------------
    # Save model
    # ----------------------
    MODEL_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    model.get_booster().save_model(str(MODEL_OUT_PATH))
    print(f"\nSaved model to: {MODEL_OUT_PATH}")

    # ----------------------
    # EXPORT DEPLOYABLE PREDICTIONS
    # ----------------------
    games = pd.read_csv(GAMES_PATH, parse_dates=["game_date"])
    games_test = games[games["season_id"] >= 22022].copy()

    assert len(games_test) == len(p_test_cal), "Prediction length mismatch!"

    pred_out = games_test[
        ["game_date", "team_id_home", "team_id_away", "home_win"]
    ].copy()

    pred_out["model_prob_home"] = p_test_cal

    PREDS_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    pred_out.to_csv(PREDS_OUT_PATH, index=False)

    print(f"\nSaved model predictions to: {PREDS_OUT_PATH}")
    print(pred_out.head())


if __name__ == "__main__":
    main()
