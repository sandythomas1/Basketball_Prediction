import pandas as pd
from pathlib import Path
from sklearn.metrics import log_loss, accuracy_score, roc_auc_score
from xgboost import XGBClassifier   


features_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/features_2.csv")


features_cols = [
    "elo_home", "elo_away", "elo_diff", "elo_prob",
    "pf_roll_home", "pf_roll_away", "pf_roll_diff",
    "pa_roll_home", "pa_roll_away", "pa_roll_diff",
    "win_roll_home", "win_roll_away", "win_roll_diff",
    "margin_roll_home", "margin_roll_away", "margin_roll_diff",
    "games_in_window_home", "games_in_window_away",
]
target_col = "home_win"

def split_by_season(df):

    train = df[df["season_id"] <= 22018].copy()
    val = df[(df["season_id"] >= 22019) & (df["season_id"] < 22021)].copy()
    test = df[df["season_id"] >= 22022].copy()
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

def main():
    df = pd.read_csv(features_path, parse_dates=['game_date'])

    if "season_id" not in df.columns:
        raise ValueError(f"'season_id' column not found in {features_path}. Columns: {list(df.columns)}")

    df["season_id"] = df["season_id"].astype(int)

    train, val, test = split_by_season(df)

    # Sanity checks (prevents silent empty splits)
    print("Split sizes:", {"train": len(train), "val": len(val), "test": len(test)})
    print("Season ranges:", {
        "train": (train["season_id"].min(), train["season_id"].max()) if len(train) else None,
        "val": (val["season_id"].min(), val["season_id"].max()) if len(val) else None,
        "test": (test["season_id"].min(), test["season_id"].max()) if len(test) else None,
    })

    X_train = train[features_cols]
    y_train = train[target_col]

    X_val = val[features_cols]
    y_val = val[target_col]

    X_test = test[features_cols]
    y_test = test[target_col]

    model = XGBClassifier(
        n_estimators=800,
        learning_rate=0.03,
        max_depth=3,
        subsample=0.9,
        colsample_bytree=0.9,
        reg_lambda=1.0,
        reg_alpha=0.0,
        min_child_weight=5,
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

    #predictions
    p_train = model.predict_proba(X_train)[:, 1]
    p_val   = model.predict_proba(X_val)[:, 1]
    p_test  = model.predict_proba(X_test)[:, 1]

    results = []
    results.append(eval_split("train", y_train, p_train))
    results.append(eval_split("val", y_val, p_val))
    results.append(eval_split("test", y_test, p_test))

    print(pd.DataFrame(results))

    # Feature importance (gain)
    importances = model.get_booster().get_score(importance_type="gain")
    imp_df = pd.DataFrame(
        [{"feature": k, "gain": v} for k, v in importances.items()]
    ).sort_values("gain", ascending=False)
    print("\nFeature importance (gain):")
    print(imp_df)

    # Save model
    out_model = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/models/xgb_v1.json")
    out_model.parent.mkdir(parents=True, exist_ok=True)

    model.get_booster().save_model(str(out_model))
    print("\nSaved model booster to:", out_model)

if __name__ == "__main__":
    main()