#!/bin/bash
# =============================================================================
# retrain_injuries.sh
#
# Retrains the XGBoost model with 6 explicit injury feature columns.
#
# Steps:
#   1. Generate features_with_injuries.csv  (25 original + 6 injury features)
#   2. Retrain XGBoost model on the 31-feature dataset
#   3. Save model  → models/xgb_v3_with_injuries.json
#   4. Save calibrator → models/calibrator_v3.pkl
#
# Run from WSL:
#   bash retrain_injuries.sh
#
# Requirements:
#   - Python environment with xgboost, pandas, scikit-learn, joblib
#   - data/processed/games_with_elo_rest.csv  (input game data)
#   - data/processed/odds_with_team_ids.csv   (optional, for market probs)
# =============================================================================

set -e  # Exit immediately if any command fails

PROJECT_ROOT="/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction"

cd "$PROJECT_ROOT"

echo "============================================================"
echo "  NBA Prediction Model — Retrain with Injury Features"
echo "============================================================"
echo ""

# ── Step 1: Build injury-augmented feature CSV ───────────────────
echo "[1/2] Building injury-augmented features..."
echo "      Input : data/processed/games_with_elo_rest.csv"
echo "      Output: data/processed/features_with_injuries.csv"
echo ""
python src/features_with_injuries.py

echo ""
echo "--------------------------------------------------------------"

# ── Step 2: Retrain XGBoost model ────────────────────────────────
echo "[2/2] Retraining XGBoost model (31 features)..."
echo "      Input : data/processed/features_with_injuries.csv"
echo "      Model : models/xgb_v3_with_injuries.json"
echo "      Calib : models/calibrator_v3.pkl"
echo ""
python src/xgb_boost_model.py

echo ""
echo "============================================================"
echo "  Done!"
echo "  Model saved to: models/xgb_v3_with_injuries.json"
echo "  Calibrator  to: models/calibrator_v3.pkl"
echo "============================================================"
