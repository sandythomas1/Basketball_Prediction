# 🏀 NBA Game Prediction Model

An XGBoost-based machine learning system for predicting NBA game outcomes, featuring Elo ratings, rolling team statistics, and rest day analysis.

---

## Model Overview

This project implements a **binary classification model** using XGBoost to predict the probability that the home team wins an NBA game. The model combines historical Elo ratings with rolling performance metrics and rest/fatigue indicators to generate calibrated win probabilities.

### Key Highlights

- **Algorithm**: XGBoost (Gradient Boosted Trees)
- **Task**: Binary classification (home win vs. away win)
- **Features**: 23 engineered features
- **Calibration**: Platt scaling via logistic regression
- **Data Span**: NBA seasons 2004–2025

---

## Features

The model uses **23 carefully engineered features** organized into four categories:

### 1. Elo Rating Features (4)

| Feature | Description |
|---------|-------------|
| `elo_home` | Current Elo rating of home team |
| `elo_away` | Current Elo rating of away team |
| `elo_diff` | Elo difference (home − away) |
| `elo_prob` | Elo-based win probability with 70-point home court advantage |

**Elo System Parameters:**
- Base rating: 1500
- K-factor: 20
- Home court advantage: 70 points
- Season carryover: 70% (30% regression to mean)

### 2. Rolling Offensive Stats (6)

| Feature | Description |
|---------|-------------|
| `pf_roll_home` | Home team avg points scored (last 10 games) |
| `pf_roll_away` | Away team avg points scored (last 10 games) |
| `pf_roll_diff` | Points for differential |
| `pa_roll_home` | Home team avg points allowed (last 10 games) |
| `pa_roll_away` | Away team avg points allowed (last 10 games) |
| `pa_roll_diff` | Points against differential |

### 3. Rolling Performance Stats (6)

| Feature | Description |
|---------|-------------|
| `win_roll_home` | Home team win % (last 10 games) |
| `win_roll_away` | Away team win % (last 10 games) |
| `win_roll_diff` | Win rate differential |
| `margin_roll_home` | Home team avg margin (last 10 games) |
| `margin_roll_away` | Away team avg margin (last 10 games) |
| `margin_roll_diff` | Margin differential |

### 4. Schedule & Rest Features (7)

| Feature | Description |
|---------|-------------|
| `games_in_window_home` | Games played by home team in window |
| `games_in_window_away` | Games played by away team in window |
| `home_rest_days` | Days since home team's last game |
| `away_rest_days` | Days since away team's last game |
| `home_b2b` | Home team on back-to-back (1/0) |
| `away_b2b` | Away team on back-to-back (1/0) |
| `rest_diff` | Rest advantage (home − away) |

---

## Model Architecture

### XGBoost Configuration

```python
XGBClassifier(
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
    random_state=42
)
```

### Calibration

Raw model probabilities are calibrated using **Platt scaling** (logistic regression) trained on the validation set. This ensures predicted probabilities align with observed win rates.

---

## Training Methodology

### Data Split Strategy

The model uses a **temporal split** to prevent data leakage:

| Split | Seasons | Purpose |
|-------|---------|---------|
| **Train** | 2004–2018 | Model training |
| **Validation** | 2019–2020 | Early stopping & calibration |
| **Test** | 2022+ | Final evaluation |

### Why Temporal Splits?

- Prevents future data from leaking into training
- Simulates real-world deployment conditions
- Ensures model generalizes to unseen seasons

---

## Performance Metrics

The model is evaluated on multiple metrics:

| Metric | Description |
|--------|-------------|
| **Log Loss** | Measures probability calibration |
| **Accuracy** | Classification accuracy at 50% threshold |
| **ROC-AUC** | Discrimination ability |
| **Brier Score** | Probability accuracy |

### Calibration Analysis

The model's predictions are compared against actual win rates across probability bins to verify calibration quality.

---

## Confidence Tiers

Predictions are mapped to interpretable confidence tiers:

| Probability Range | Tier |
|-------------------|------|
| ≥ 75% | Heavy Favorite |
| 65% – 74% | Moderate Favorite |
| 55% – 64% | Lean Favorite |
| 45% – 54% | Toss-Up |
| 35% – 44% | Lean Underdog |
| < 35% | Strong Underdog |

---

## Project Structure

```
Basketball_Prediction/
├── models/
│   ├── xgb_v2_modern.json    # Trained XGBoost model
│   └── calibrator.pkl        # Platt scaling calibrator
├── data/
│   ├── raw/
│   │   └── nba_2008-2025.csv # Raw game data
│   └── processed/
│       ├── features_3.csv    # Engineered features
│       ├── games_with_elo_rest.csv
│       └── model_predictions.csv
├── src/
│   ├── xgb_boost_model.py    # Model training script
│   ├── benchmark.py          # Evaluation & benchmarking
│   ├── core/
│   │   ├── predictor.py      # Inference class
│   │   ├── feature_builder.py# Feature construction
│   │   ├── elo_tracker.py    # Elo rating system
│   │   └── stats_tracker.py  # Rolling statistics
│   └── api/
│       └── main.py           # FastAPI endpoints
├── state/
│   ├── elo.json              # Current Elo ratings
│   └── stats.json            # Team game histories
└── app/                      # Flutter mobile app
```

---

## Usage

### Making Predictions

```python
from src.core.predictor import Predictor
from src.core.feature_builder import FeatureBuilder
from src.core.elo_tracker import EloTracker
from src.core.stats_tracker import StatsTracker
from pathlib import Path

# Load model and calibrator
predictor = Predictor(
    model_path=Path("models/xgb_v2_modern.json"),
    calibrator_path=Path("models/calibrator.pkl")
)

# Load current state
elo_tracker = EloTracker.from_file(Path("state/elo.json"))
stats_tracker = StatsTracker.from_file(Path("state/stats.json"))
feature_builder = FeatureBuilder(elo_tracker, stats_tracker)

# Predict a game
result = predictor.predict_game(
    home_id=1610612747,  # Lakers
    away_id=1610612738,  # Celtics
    game_date="2026-01-15",
    feature_builder=feature_builder
)

print(result)
# {
#     "prob_home_win": 0.5234,
#     "prob_away_win": 0.4766,
#     "confidence_tier": "Toss-Up",
#     "is_calibrated": True,
#     "home_team_id": 1610612747,
#     "away_team_id": 1610612738,
#     "game_date": "2026-01-15"
# }
```

### Training the Model

```bash
python src/xgb_boost_model.py
```

### Running the API

```bash
uvicorn src.api.main:app --reload
```

---

## Dependencies

```
pandas>=2.0.0
numpy>=1.24.0
scikit-learn>=1.3.0
xgboost>=2.0.0
joblib>=1.3.0
fastapi>=0.109.0
uvicorn>=0.27.0
```

Install all dependencies:

```bash
pip install -r requirements.txt
```

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/predictions/today` | GET | Today's game predictions |
| `/predictions/game` | POST | Predict specific game |
| `/games` | GET | List upcoming games |

---

## Future Improvements

- [ ] Incorporate player-level features (injuries, rest)
- [ ] Add advanced metrics (offensive/defensive ratings)
- [ ] Implement ensemble methods
- [ ] Real-time odds integration for edge detection
- [ ] Historical backtesting framework

---

## License

MIT License

---

*Built with XGBoost, FastAPI, and Flutter*

