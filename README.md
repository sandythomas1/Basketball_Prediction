# Signal Sports — NBA Game Prediction Platform

A full-stack NBA prediction platform powered by an XGBoost ML model, served via FastAPI on Google Cloud Run, and consumed by a Flutter mobile app with AI chat, social features, and in-app subscriptions.

---

## Architecture

| Layer | Technology | Hosting |
|-------|-----------|---------|
| ML Backend | Python 3.11 · FastAPI · XGBoost | Google Cloud Run |
| Daily Pipeline | Cloud Run Job · Cloud Scheduler | GCP |
| AI Chat | Dialogflow CX via Firebase Cloud Functions | Firebase |
| Mobile App | Flutter · Riverpod · Firebase Auth | Android (Play Store) |
| State Storage | JSON files synced to GCS bucket | Google Cloud Storage |

---

## Model Overview

- **Algorithm**: XGBoost (Gradient Boosted Trees) — binary classification
- **Model file**: `models/xgb_v3_with_injuries.json`
- **Calibration**: Isotonic regression (`calibrator_v3.pkl`)
- **Features**: **31 engineered features** across 6 categories
- **Data Span**: NBA seasons 2004–2025
- **Temporal split**: Train 2004–2018 · Validation 2019–2020 · Test 2022+

### Feature Vector (31 features)

| Category | Count | Features |
|----------|-------|----------|
| Elo Ratings | 4 | `elo_home`, `elo_away`, `elo_diff`, `elo_prob` |
| Rolling Offense | 6 | `pf_roll_home/away/diff`, `pa_roll_home/away/diff` |
| Rolling Performance | 6 | `win_roll_home/away/diff`, `margin_roll_home/away/diff` |
| Schedule & Rest | 7 | `games_in_window_home/away`, `home/away_rest_days`, `home/away_b2b`, `rest_diff` |
| Market Odds | 2 | `market_prob_home`, `market_prob_away` |
| Injury Impact | 6 | `injury_adj_home/away`, `injury_severity_home/away`, `injury_count_home/away` |

### Elo System

- Base: 1500 · K-factor: 20 · Home-court advantage: 70 pts
- Season carryover: 70% (30% regression to mean)

### Confidence Scoring

Each prediction includes a 0–100 **confidence score** built from five factors:

| Factor | Max | Description |
|--------|-----|-------------|
| Consensus Agreement | 25 | Model ↔ market probability alignment |
| Feature Alignment | 25 | All stat signals pointing the same direction |
| Form Stability | 20 | Low volatility in recent margin/win trends |
| Schedule Context | 15 | Rest advantage, no back-to-back |
| Matchup History | 15 | Elo gap and head-to-head signals |

### Confidence Tiers

| Probability Range | Tier |
|-------------------|------|
| ≥ 75% | Strong Favorite |
| 65–74% | Moderate Favorite |
| 55–64% | Lean Favorite |
| 45–54% | Toss-Up |
| 35–44% | Lean Underdog |
| < 35% | Strong Underdog |

---

## Project Structure

```
Basketball_Prediction/
├── models/
│   ├── xgb_v3_with_injuries.json   # Trained XGBoost model (v3, 31 features)
│   └── calibrator_v3.pkl           # Isotonic calibrator
├── state/
│   ├── elo.json                    # Current team Elo ratings
│   ├── stats.json                  # Rolling 10-game windows
│   └── metadata.json               # Pipeline metadata
├── src/
│   ├── core/
│   │   ├── predictor.py            # XGBoost inference + calibration
│   │   ├── feature_builder.py      # 31-feature vector construction
│   │   ├── elo_tracker.py          # Elo rating system
│   │   ├── stats_tracker.py        # Rolling statistics
│   │   ├── confidence_scorer.py    # 0-100 confidence scoring
│   │   ├── injury_client.py        # ESPN injury reports
│   │   ├── injury_cache.py         # Thread-safe TTL cache
│   │   ├── player_importance.py    # All-Star / starter tier weighting
│   │   ├── odds_client.py          # The Odds API integration
│   │   ├── espn_client.py          # ESPN scoreboard API
│   │   ├── team_mapper.py          # ESPN ↔ NBA ID mapping
│   │   ├── state_manager.py        # Atomic state load/save
│   │   ├── state_sync.py           # GCS bucket sync
│   │   └── game_processor.py       # Process completed games
│   ├── api/
│   │   ├── main.py                 # FastAPI application
│   │   ├── config.py               # Environment-based settings
│   │   ├── schemas.py              # Pydantic v2 request/response models
│   │   ├── dependencies.py         # Singleton service wiring
│   │   ├── middleware/
│   │   │   ├── firebase_auth.py    # Firebase ID token verification
│   │   │   ├── security.py         # Security headers
│   │   │   └── rate_limiter.py     # slowapi rate limiting
│   │   └── routes/
│   │       ├── health.py           # /health, /state/info, /teams
│   │       ├── predictions.py      # /predict/today, /predict/game, /predict/batch
│   │       └── games.py            # /games/today, /games/scoreboard, with-predictions
│   ├── jobs/
│   │   └── daily_cloud_run_job.py  # Daily state update + prediction generation
│   ├── daily_predictions.py        # Generate daily prediction JSON
│   └── update_state.py             # Process yesterday's games into state
├── functions/
│   └── index.js                    # Firebase Cloud Functions (AI chat, context refresh)
├── app/                            # Flutter mobile app (Signal Sports)
│   ├── lib/
│   │   ├── Screens/                # 17 screens (auth, games, profile, forums, etc.)
│   │   ├── Providers/              # Riverpod providers (games, AI chat, subscriptions)
│   │   ├── Services/               # Config, auth, cache, subscriptions
│   │   ├── Widgets/                # AI chat, team logos, pro overlays
│   │   └── Models/                 # Game data model
│   └── pubspec.yaml
├── test/                           # Python test suite (pytest)
├── Dockerfile.api                  # Cloud Run API image
├── Dockerfile.job                  # Cloud Run Job image
├── cloudbuild.api.yaml             # Cloud Build — API (tests → build → push)
├── cloudbuild.job.yaml             # Cloud Build — Job (tests → build → push)
└── requirements.txt
```

---

## API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/health` | GET | No | Health check |
| `/state/info` | GET | No | Pipeline metadata |
| `/state/reload` | POST | Yes | Reload state from GCS |
| `/teams` | GET | No | All teams with Elo ratings |
| `/predict/today` | GET | Yes | Today's game predictions |
| `/predict/{date}` | GET | Yes | Predictions for a specific date |
| `/predict/game` | POST | Yes | Predict a single matchup |
| `/predict/batch` | POST | Yes | Predict multiple matchups |
| `/games/today` | GET | No | Today's ESPN games |
| `/games/scoreboard` | GET | No | ESPN scoreboard proxy |
| `/games/today/with-predictions` | GET | Yes | Games + predictions combined |
| `/games/{date}` | GET | No | Games for a specific date |
| `/games/{date}/with-predictions` | GET | Yes | Games + predictions for a date |

**Authentication**: When `FIREBASE_AUTH_REQUIRED=true`, protected endpoints require a valid Firebase ID token in the `Authorization: Bearer <token>` header. In development mode (default), auth is optional.

---

## Quick Start

### Backend (Local Development)

```bash
pip install -r requirements.txt

# Bootstrap state (first time only)
python src/bootstrap_state.py

# Run the API
uvicorn src.api.main:app --reload --port 8000
```

### Flutter App

```bash
cd app
flutter pub get
flutter run --dart-define=PRODUCTION=false
```

### Run Tests

```bash
pytest test/ -v
```

---

## Deployment

### Cloud Run API

```bash
gcloud builds submit --config cloudbuild.api.yaml \
  --substitutions=_IMAGE=us-west1-docker.pkg.dev/PROJECT/repo/nba-api:latest
```

### Cloud Run Job (Daily Pipeline)

```bash
gcloud builds submit --config cloudbuild.job.yaml \
  --substitutions=_IMAGE=us-west1-docker.pkg.dev/PROJECT/repo/nba-job:latest
```

### Environment Variables (Production)

```env
ENVIRONMENT=production
ALLOWED_ORIGINS=https://your-domain.com
RATE_LIMIT_PER_MINUTE=30
FIREBASE_AUTH_REQUIRED=true
ODDS_API_KEY=your_key
STATE_BUCKET=nba-prediction-data-metadata
MODEL_BUCKET=nba-prediction-data-metadata
```

---

## Flutter App (Signal Sports)

### Key Features

- Firebase Auth (email + Google sign-in)
- Real-time game predictions with confidence scores
- AI-powered chat assistant (Dialogflow CX via Firebase Functions)
- Injury impact analysis (Pro-gated)
- Social features: user profiles, forums, follow system
- RevenueCat subscription paywall (Pro tier)
- Offline caching with automatic fallback
- Share predictions via native share sheet
- Dark/light theme support

### App Environment

Set `PRODUCTION=true` via `--dart-define` for production builds. The app reads additional keys from `app/.env`:

```env
PRODUCTION_API_URL=https://your-cloud-run-url.run.app
REVENUECAT_ANDROID_KEY=your_rc_key
RECAPTCHA_SITE_KEY=your_recaptcha_key
```

---

## Dependencies

### Python

```
xgboost · scikit-learn · fastapi · uvicorn · pydantic · slowapi
firebase-admin · google-cloud-storage · requests · numpy · pandas
```

### Flutter

```
flutter_riverpod · firebase_core · firebase_auth · firebase_app_check
http · cached_network_image · pie_chart · share_plus · google_fonts
purchases_flutter · flutter_markdown · flutter_dotenv · flutter_secure_storage
```

---

## License

MIT License

---

*Built with XGBoost, FastAPI, Flutter, Firebase, and Google Cloud*
