import pandas as pd
import joblib
from pathlib import Path
import argparse
import sys
from sklearn.metrics import log_loss, accuracy_score, roc_auc_score
from sklearn.linear_model import LogisticRegression
from xgboost import XGBClassifier

# Add core path to import LeagueConfig
sys.path.insert(0, str(Path(__file__).parent))
from core.league_config import NBA_CONFIG, WNBA_CONFIG, CBB_CONFIG

# ==========================
# Feature columns
# ==========================
FEATURE_COLS = [
    # Elo ratings
    "elo_home", "elo_away", "elo_diff", "elo_prob",
    # Rolling scoring stats
    "pf_roll_home", "pf_roll_away", "pf_roll_diff",
    "pa_roll_home", "pa_roll_away", "pa_roll_diff",
    # Rolling win/margin stats
    "win_roll_home", "win_roll_away", "win_roll_diff",
    "margin_roll_home", "margin_roll_away", "margin_roll_diff",
    # Game-window context
    "games_in_window_home", "games_in_window_away",
    # Rest / fatigue
    "home_rest_days", "away_rest_days",
    "home_b2b", "away_b2b", "rest_diff",
    # Betting market probabilities
    "market_prob_home", "market_prob_away",
    # Injury features (zero-imputed for training; live ESPN data at inference)
    "home_players_out", "away_players_out",
    "home_players_questionable", "away_players_questionable",
    "home_injury_severity", "away_injury_severity",
]

TARGET_COL = "home_win"


# ==========================
# Helpers
# ==========================
def split_by_season(df, league="nba"):
    if league == "wnba":
        train = df[df["season_id"] <= 22023]
        val   = df[df["season_id"] == 22024]
        test  = df[df["season_id"] >= 22025]
    elif league == "cbb":
        train = df[df["season_id"] <= 22023]
        val   = df[df["season_id"] == 22024]
        test  = df[df["season_id"] >= 22025]
    else:
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--league", default="nba", choices=["nba", "wnba", "cbb"])
    args = parser.parse_args()
    
    if args.league == "wnba":
        features_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_features_with_injuries.csv"
        games_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_games_with_elo_rest.csv"
        model_out_path = Path(__file__).parent.parent / "models" / "xgb_wnba_v1.json"
        calibrator_out_path = Path(__file__).parent.parent / "models" / "calibrator_wnba_v1.pkl"
        preds_out_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_model_predictions.csv"
    elif args.league == "cbb":
        features_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_features_with_injuries.csv"
        games_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_games_with_elo_rest.csv"
        model_out_path = Path(__file__).parent.parent / "models" / "xgb_cbb_v1.json"
        calibrator_out_path = Path(__file__).parent.parent / "models" / "calibrator_cbb_v1.pkl"
        preds_out_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_model_predictions.csv"
    else:
        features_path = Path(__file__).parent.parent / "data" / "processed" / "features_with_injuries.csv"
        games_path = Path(__file__).parent.parent / "data" / "processed" / "games_with_elo_rest.csv"
        model_out_path = Path(__file__).parent.parent / "models" / "xgb_v3_with_injuries.json"
        calibrator_out_path = Path(__file__).parent.parent / "models" / "calibrator_v3.pkl"
        preds_out_path = Path(__file__).parent.parent / "data" / "processed" / "model_predictions.csv"

    # ----------------------
    # Load features
    # ----------------------
    df = pd.read_csv(features_path, parse_dates=["game_date"])
    df["season_id"] = df["season_id"].astype(int)

    train, val, test = split_by_season(df, league=args.league)

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
    calibrator_out_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(calibrator, calibrator_out_path)
    print(f"\nSaved calibrator to: {calibrator_out_path}")

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
    model_out_path.parent.mkdir(parents=True, exist_ok=True)
    model.get_booster().save_model(str(model_out_path))
    print(f"\nSaved model to: {model_out_path}")

    # ----------------------
    # EXPORT DEPLOYABLE PREDICTIONS
    # ----------------------
    games = pd.read_csv(games_path, parse_dates=["game_date"])
    
    if args.league == "wnba" or args.league == "cbb":
        games_test = games[games["season_id"] >= 22025].copy()
    else:
        games_test = games[games["season_id"] >= 22022].copy()

    assert len(games_test) == len(p_test_cal), "Prediction length mismatch!"

    pred_out = games_test[
        ["game_date", "team_id_home", "team_id_away", "home_win"]
    ].copy()

    pred_out["model_prob_home"] = p_test_cal

    preds_out_path.parent.mkdir(parents=True, exist_ok=True)
    pred_out.to_csv(preds_out_path, index=False)

    print(f"\nSaved model predictions to: {preds_out_path}")
    print(pred_out.head())


if __name__ == "__main__":
    main()
