# Signal Sports Platform — Production Roadmap & Architecture Plan

**Last Updated:** 2026-04-11  
**Current Model:** Claude Sonnet 4.6  
**Author:** AI/ML Architecture Review

---

## PART 0: MVP AUDIT — WHERE YOU ARE RIGHT NOW

### Overall MVP Completion: **84%**

You are materially closer to launch than you think. One import error is the difference between "stalled" and "live."

---

### Component Breakdown

| Component | Completion | Status |
|---|---|---|
| Data Pipeline | 85% | Working — minor hardening needed |
| ML Model | 95% | Production-grade with injury integration |
| Backend API | 90% | **Broken by one import error** |
| Frontend / Flutter | 80% | Architecture complete; needs API unblocked |
| Deployment / Infra | 75% | Docker + Cloud Run ready; GCS setup needed |
| Testing | 60% | 58 tests exist; blocked by same import error |

**MVP Definition Used:** Users can view NBA predictions, model runs reliably, basic UI exists. No social features, no NFL.

---

### Critical Blockers (In Order)

**BLOCKER 1 — CRITICAL: `src/api/routes/chat.py` import error**

```python
# Line 15 — CURRENT (broken):
from google import genai

# FIX OPTION A — correct import:
from google.genai import client  # verify exact path for google-genai package

# FIX OPTION B — fastest fix for MVP:
# Delete or comment out the entire chat route and remove it from main.py registration
# Add it back in Phase 2 when you harden the AI chat feature
```

This single error prevents FastAPI from starting. Nothing works until this is resolved.

**BLOCKER 2 — GCS Environment Variables Not Configured**

Required for the daily pipeline and model loading:
- `STATE_BUCKET` — GCS bucket name for state (Elo, rolling stats)
- `MODEL_BUCKET` — GCS bucket name for model artifacts
- `API_BASE_URL` — Used by the daily Cloud Run job to trigger `/state/reload`

Fix: Create GCS buckets, copy `.env.example` → `.env`, populate values.

**BLOCKER 3 — No monitoring or alerting**

Not a launch blocker, but if the daily job silently fails, predictions go stale. Add a Cloud Monitoring alert on job success/failure before launch. 15 minutes of setup.

---

### What Is Overbuilt for MVP (Defer These)

| Feature | LOC Estimate | Recommendation |
|---|---|---|
| AI Chat (Gemini 2.0 Flash, SSE streaming) | ~600 | Defer to Phase 2 — fixing this is the fastest path to unblocking launch |
| Playoff mode (separate endpoints, UI screens) | ~500 | Defer — only relevant May–June |
| Social layer (forums, follows, notifications) | ~400 | Defer to Phase 3 |
| RevenueCat / in-app purchases | ~300 | Use Stripe payment link at MVP instead |
| Promo video screen | ~100 | Defer |

Removing these ~1,900 LOC reduces surface area, fixes BLOCKER 1 as a side effect, and ships a tighter product.

---

### Path to MVP Launch in 7 Days

**Day 1 (2 hours)**
- Fix or remove chat route import error
- Run `pytest test/ -v` — all 58 tests should pass
- Smoke test: `curl localhost:8000/health`, `/predict/today`, `/teams`

**Day 2 (3 hours)**
- Create GCS buckets (`signal-sports-state`, `signal-sports-models`)
- Upload model artifacts and current state to GCS
- Run the daily job manually end-to-end
- Verify predictions write to GCS and API serves them

**Day 3 (2 hours)**
- Deploy API to Cloud Run (use existing `cloudbuild.api.yaml`)
- Confirm `API_BASE_URL` in Cloud Scheduler job
- Wire up Cloud Logging alert for daily job failure

**Day 4 (3 hours)**
- Flutter: update `API_BASE_URL` in `.env` to point at Cloud Run URL
- Auth flow: test Firebase signup → login → token → API call end-to-end
- Fix any response schema mismatches between API and Flutter models

**Day 5 (2 hours)**
- End-to-end: open app → see today's games → tap a game → see prediction + confidence
- Fix rendering bugs, loading states, error states

**Day 6 (2 hours)**
- Internal testing with 3–5 friends
- Collect feedback, fix obvious UX issues

**Day 7**
- Soft launch: share with a small audience (Twitter/X, Discord, Reddit r/nba)
- Monitor API logs, error rate, prediction freshness

**Total estimated effort: ~14 focused hours**

---

## PART 1: PHASED ROADMAP

---

### Phase 1 — MVP Launch (Weeks 1–4)
**Goal: Revenue-generating product. NBA predictions, no social features.**

#### What Ships

- NBA daily predictions with confidence tiers (high / medium / low)
- Today's games view with spread, moneyline context (from Odds API)
- Game detail: prediction breakdown, key factors (Elo, rest, injuries)
- Firebase auth (email + password)
- Basic subscription gate: free users see top-3 picks, paid users see all picks + reasoning
- RevenueCat OR Stripe payment link (see Monetization section)

#### What Does NOT Ship

- AI chat
- Playoff mode (add back when playoffs start if you're live before May)
- Social features
- NFL
- Video

#### Monetization at Launch (Fastest Revenue Path)

**Free Tier:** Top 3 picks of the day visible, no reasoning  
**Pro Tier ($7.99/month):** All picks, confidence scores, injury impact, historical accuracy stats

Implementation: Stripe Customer Portal link on the web (no app store fees, immediate). Add RevenueCat for in-app after validation.

#### Infra Stack for Phase 1

```
Cloud Run (API)
Cloud Scheduler → Cloud Run Job (daily pipeline @ 4 AM ET)
GCS (state + models)
Firebase Auth + Firestore (users, subscription status)
Flutter (iOS + Android)
```

---

### Phase 2 — Depth + Stickiness (Weeks 5–12)
**Goal: Reduce churn. Add NFL. Make the product feel alive.**

#### What Ships

- NFL pipeline (same architecture, new team/player data source)
- AI Chat (fix and re-enable Gemini 2.0 Flash endpoint)
- User accounts: saved picks, prediction history, accuracy tracking
- Model accuracy leaderboard (how has Signal Sports performed this week/month/season)
- Push notifications: game start alerts, upset alerts ("Model says underdog is +EV today")
- Playoff mode (re-enable the existing code, hardened)
- A/B model testing infrastructure (canary deployments)

#### Monetization Additions

- Annual plan ($59.99/year = 37% discount)
- "Streak mode": gamified UI for tracking pick streaks
- Referral program: give a friend 7 days free, you get 7 days free

---

### Phase 3 — Social Layer (Months 3–6)
**Goal: Build a defensible community around the prediction product.**

#### What Ships

- User profiles: scouts, creators, fans (role-based)
- Posts: text + image + video (short highlight clips)
- Feed algorithm (v1: reverse chronological with engagement boost)
- Follow system
- Comments + likes
- Notifications
- Moderation: report + review queue (manual at first)

#### Monetization Additions

- Creator tipping (fans can tip scouts/creators)
- Verified scout badge ($9.99/month or invite-only)
- Promoted posts (scouts/programs paying for visibility)

---

### Phase 4 — NCAA + Rankings (Months 6–12)
**Goal: Expand TAM. Add rankings as a content moat.**

#### What Ships

- NCAA Division 1 Men's Basketball predictions
- AI-powered team rankings (see Ranking System section)
- Pre-season, mid-season, post-season ranking snapshots
- Recruitment scouting tools (Phase 4b)

---

### Phase 5 — CIFSS + Scouting Ecosystem (Year 2+)
**Goal: Own the high school basketball analytics space.**

#### What Ships

- CIFSS Southern Section boys basketball AI rankings
- Player profile pages (aggregated stats + video)
- Creator marketplace (scouts sell reports/highlights)
- Program-facing analytics dashboard
- Sponsorship and NIL connection tools (long-term)

---

## PART 2: TECHNICAL ARCHITECTURE

---

### System Design Overview

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│  (iOS + Android — Firebase Auth + REST + SSE)           │
└────────────────────┬────────────────────────────────────┘
                     │
              REST / SSE
                     │
┌────────────────────▼────────────────────────────────────┐
│                   FastAPI (Cloud Run)                    │
│  /predict  /games  /teams  /chat  /rankings             │
│  Middleware: Auth · Rate Limit · CORS · Security Headers │
└──┬──────────────┬──────────────┬───────────────┬────────┘
   │              │              │               │
   ▼              ▼              ▼               ▼
GCS State    XGBoost +      Firebase       Gemini API
(Elo, stats) Calibrator     (Auth +        (Chat)
             (models/)      Firestore)
   ▲
   │  (daily sync)
┌──┴────────────────────────────────────┐
│          Cloud Run Job                │
│  ESPN API → Feature Engineering →    │
│  Predictions → GCS Upload            │
└───────────────────────────────────────┘
   ▲
Cloud Scheduler (4 AM ET daily)
```

---

### Data Ingestion Architecture

**Sources:**
- ESPN API (scores, schedules, injuries) — primary, free
- The Odds API (market odds, spreads) — free tier 500 req/month; upgrade at scale
- Basketball-Reference (historical stats for retraining) — scrape or CSV download
- For NFL: same ESPN API structure; add Pro Football Reference for historical

**Pipeline:**

```
ESPN Scores (yesterday's games)
    ↓
update_state.py
    ├── EloTracker.update()
    ├── StatsTracker.update()
    └── InjuryClient.fetch() [4hr cache]
    ↓
daily_predictions.py
    ├── FeatureBuilder.build() for each game
    ├── Predictor.predict() → calibrated probability
    └── ConfidenceScorer.score() → tier
    ↓
GCS: state/daily.json + state/state.pkl
    ↓
API /predict/today reads from GCS (zero latency on request)
```

**Retry / Hardening (add in Phase 1 hardening):**
```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def fetch_with_retry(url): ...
```

---

### API Structure

```
/health                         GET    → liveness probe
/state/info                     GET    → pipeline metadata
/state/reload                   POST   → force GCS sync (admin)

/predict/today                  GET    → all games + predictions
/predict/{date}                 GET    → predictions for date
/predict/game                   POST   → single game prediction
/predict/batch                  POST   → bulk predictions

/games/today                    GET    → ESPN scoreboard
/games/{date}                   GET    → games by date
/games/today/with-predictions   GET    → combined

/teams                          GET    → teams + Elo ratings

/playoff/bracket                GET    → current bracket
/playoff/games/{date}           GET    → playoff games

/chat/message                   POST   → SSE streaming (Gemini)

# Phase 2+
/nfl/predict/today              GET
/rankings/nba                   GET
/rankings/ncaa                  GET
/rankings/cifss                 GET

# Phase 3+
/posts                          GET/POST
/posts/{id}/comments            GET/POST
/users/{id}/profile             GET
/users/{id}/follow              POST
/feed                           GET
```

---

### Database Schema

**Firestore (primary operational store)**

```
users/{uid}
  ├── email: string
  ├── display_name: string
  ├── role: "fan" | "scout" | "creator"
  ├── subscription_tier: "free" | "pro"
  ├── subscription_expiry: timestamp
  ├── created_at: timestamp
  └── streak: number

predictions/{date}/{game_id}
  ├── home_team: string
  ├── away_team: string
  ├── predicted_winner: string
  ├── win_probability: float
  ├── confidence_tier: "high" | "medium" | "low"
  ├── confidence_score: int (0–100)
  ├── elo_diff: float
  ├── injury_impact: float
  ├── model_version: string
  └── generated_at: timestamp

saved_picks/{uid}/{pick_id}
  ├── game_id: string
  ├── date: string
  ├── picked_team: string
  ├── result: "win" | "loss" | "pending"
  └── saved_at: timestamp

# Phase 3+
posts/{post_id}
  ├── author_uid: string
  ├── content: string
  ├── media_urls: string[]
  ├── post_type: "highlight" | "analysis" | "news"
  ├── tags: string[]
  ├── like_count: int
  ├── comment_count: int
  └── created_at: timestamp

follows/{uid}/following/{target_uid}
  └── followed_at: timestamp

rankings/{sport}/{season}/{rank_id}
  ├── team_name: string
  ├── rank: int
  ├── score: float
  ├── components: map (elo, strength_of_schedule, momentum)
  └── updated_at: timestamp
```

**GCS (blob / binary store)**
```
signal-sports-state/
  ├── state/state.pkl          ← Elo + rolling stats (serialized)
  ├── state/daily.json         ← Today's predictions (cached)
  └── state/elo_history.json   ← Elo time series for UI charts

signal-sports-models/
  ├── xgb_v3_with_injuries.json
  ├── calibrator_v3.pkl
  └── model_registry.json      ← version metadata
```

**Cloud SQL (Phase 2+, for analytics queries)**
```sql
-- model_performance table
CREATE TABLE model_performance (
  id SERIAL PRIMARY KEY,
  date DATE,
  sport VARCHAR(10),
  games_predicted INT,
  correct_predictions INT,
  accuracy FLOAT,
  high_conf_accuracy FLOAT,
  model_version VARCHAR(20),
  created_at TIMESTAMP DEFAULT NOW()
);

-- When you want to power a "Model Accuracy" dashboard in the app
```

---

### Media Storage (Phase 3+)

- **Firebase Storage** for user-uploaded images and short clips (< 60 seconds)
- **Cloud Storage signed URLs** for media CDN delivery
- **Video transcoding**: Cloud Run job triggered on upload using FFmpeg to generate HLS segments
- **Long-form video (future)**: Integrate with Cloudflare Stream or Mux for cost-effective video hosting

---

### Recommended Tech Stack

| Layer | Choice | Justification |
|---|---|---|
| API | FastAPI + Python 3.11 | Already implemented; async support for SSE; Pydantic v2 |
| ML | XGBoost + scikit-learn calibration | Already working; easy to retrain; fast inference |
| Mobile | Flutter | Cross-platform; already built; Firebase first-class |
| Auth | Firebase Auth | Already integrated; handles email, OAuth, App Check |
| Realtime DB | Firestore | Already integrated; scales; good Flutter SDK |
| Blob / State | GCS | Already wired; cheap; reliable |
| Compute | Cloud Run | Serverless; scales to zero; already dockerized |
| Scheduling | Cloud Scheduler + Cloud Run Jobs | Already configured |
| AI / Chat | Gemini 2.0 Flash | Already integrated (fix import and re-enable) |
| Monitoring | Cloud Logging + Cloud Monitoring | Native GCP; add alerting policies |
| Payments | Stripe (Phase 1) → RevenueCat (Phase 2) | Stripe: zero app store fees; RevenueCat: proper mobile sub management |
| CDN | Firebase Hosting (web) / Cloud CDN (API) | Low-latency global delivery |

---

## PART 3: MACHINE LEARNING DESIGN

---

### Current Model: XGBoost v3 with Injuries

**Architecture:** Binary classifier → calibrated with isotonic regression  
**Features (31):**
- Elo ratings: home Elo, away Elo, home advantage, Elo delta
- Rolling offense (6): points per game, offensive rating (10-game window)
- Rolling performance (6): wins, margin of victory (10-game window)
- Schedule / rest (7): days rest home, days rest away, back-to-back flags, travel
- Market odds (2): implied probability from Odds API (home + away)
- Injury features (6): player importance-weighted injury impact per team

**Training data:** 2004–2018 (historical SQLite, 2.2 GB)  
**Validation:** 2019–2020  
**Test:** 2022+

**Accuracy target:** 58–62% (market is 50%; beating market by 8–12pp is excellent)

---

### Model Iteration Strategy

**v3 → v4 (Phase 2):**
- Add opponent-adjusted stats (not just rolling averages)
- Add referee tendencies (pace, foul rate)
- Add Vegas line movement as feature (opening vs. closing)
- Retrain on 2004–2024 full dataset
- Evaluate: log loss, Brier score, calibration curve, ROI simulation

**v4 → v5 (Phase 3):**
- Ensemble: XGBoost + LightGBM + Neural net (small MLP)
- Add player-level contributions (not just injury flags)
- Bayesian model uncertainty for confidence tiers

**NFL Generalization:**
- Same architecture; different feature set
- Replace Elo with team Elo + quarterback rating
- Replace rolling NBA stats with rushing yards, passing yards, turnovers
- Market odds features are identical
- Injury features: same structure, different player importance weights

**NCAA Generalization:**
- KenPom / BartTorvik data as feature inputs
- Conference strength adjustment
- Tournament model: separate model for win-or-go-home games

---

### Evaluation Metrics

| Metric | Why It Matters |
|---|---|
| Accuracy | User-facing: "Signal Sports picks 60% correctly" |
| Log loss | Model calibration quality |
| Brier score | Probability sharpness |
| Expected ROI | Picks are net positive vs. market odds |
| Confidence tier accuracy | High-confidence picks should hit 65%+ |
| Kelly criterion analysis | Bet sizing if users follow picks |

---

### Continuous Retraining (Phase 2)

```
Cloud Scheduler: end of season trigger
  → fetch full season game logs from ESPN / Basketball-Reference
  → run feature_engineering.py on full dataset
  → train_model.py with cross-validation
  → evaluate against holdout test set
  → if accuracy > threshold: upload to GCS model_registry
  → API hot-reloads new model via /state/reload
```

---

## PART 4: SOCIAL PLATFORM DESIGN

---

### User Roles

| Role | Who They Are | Core Actions |
|---|---|---|
| **Fan** | Casual user following predictions and content | View picks, save picks, comment, follow |
| **Creator** | Content producers: highlight editors, journalists | Post video/text, get followers, get tipped |
| **Scout** | Basketball evaluators (high school, college focus) | Post player reports, tag players, get verified |

Role is set at signup and can be upgraded. Scouts require verification (Phase 3b).

---

### Content System

**Post Types:**
- `highlight` — short video clip (< 60s), tagged with team/player/game
- `analysis` — text + optional image; sport analysis or opinion
- `news` — link post with commentary; taggable by topic

**Media Pipeline:**
1. User uploads via Flutter → Firebase Storage (presigned URL upload)
2. Upload triggers Cloud Function → Cloud Run transcoder job (FFmpeg → HLS)
3. Transcoded segments stored in GCS → served via CDN
4. Post record written to Firestore after transcode completes

---

### Feed Algorithm

**v1 (Phase 3 launch): Simple relevance**
```
score = recency_weight * 0.6 + engagement_rate * 0.3 + follow_boost * 0.1

# Recency: exponential decay over 24 hours
# Engagement rate: (likes + comments * 2) / impressions
# Follow boost: +20% if author is followed by user
```

**v2 (Phase 4): Personalization**
- Collaborative filtering on engagement history
- Content-based: tag affinity model
- Diversity injection: prevent feed from becoming echo chamber

---

### Engagement Systems

- Likes (heart): immediate, no notification threshold
- Comments: threaded, real-time via Firestore listeners
- Follows: unidirectional; follower count public
- Reposts: share to own followers with optional commentary
- Tips: Phase 3 — fans send $1–$50 to creators via Stripe Connect

---

### Moderation

**Phase 3 launch:**
- User report → queues to Firestore `moderation_queue`
- Manual review by admin (you) within 24 hours
- Auto-remove posts with 5+ reports (pending review)

**Phase 4:**
- Integrate Google Cloud Vision API for image/video content safety
- Text classification for hate speech / spam
- Trusted creator tier reduces false positive removals

---

## PART 5: RANKING SYSTEM

---

### AI-Driven Rankings Architecture

**Inputs:**
- Team win/loss record, strength of schedule
- Point differential (weighted: recent games more)
- Net efficiency rating (offensive - defensive)
- Elo rating trajectory (momentum)
- Market-implied strength (from betting lines)
- Head-to-head results (direct comparisons)

**Ranking Formula (Phase 4):**

```python
def compute_ranking_score(team_stats, elo, market_data, schedule):
    sos_adjusted_record = team_stats.wins / games_played * schedule.strength_factor
    efficiency = team_stats.off_rating - team_stats.def_rating
    momentum = elo.delta_last_10_games  # positive = improving
    market_signal = 1 / market_data.avg_closing_odds  # inverse of odds = implied strength
    
    raw_score = (
        sos_adjusted_record * 0.35 +
        efficiency * 0.30 +
        elo.current * 0.20 +
        momentum * 0.10 +
        market_signal * 0.05
    )
    return normalize(raw_score)  # 0–100 scale
```

**Output:** Ranked list with component breakdown (why team X is ranked #5)

---

### CIFSS Rankings Framework (Phase 5)

**Data Sources:**
- Box scores from MaxPreps (scraped or API if available)
- CIF official records
- Video signals (Phase 5): per-possession tagging from uploaded highlights
- User input: scout ratings (human-in-the-loop)

**Hybrid Human + AI Model:**

```
AI Score (70%) = stats-based efficiency + SOS + head-to-head
Human Score (30%) = verified scout ratings (averaged, outlier-removed)

Final Ranking Score = AI Score * 0.7 + Human Score * 0.3
```

**Trust layer:** Scout inputs are weighted by scout verification tier. Unverified users cannot influence rankings. Verified scouts (human-reviewed) have 1x weight. Elite scouts (50+ accurate evaluations) have 1.5x weight.

**Why this matters:** MaxPreps rankings are purely record-based. A hybrid AI + scout model produces more predictive, defensible rankings — and scouts have incentive to participate because their reputation score is public.

---

## PART 6: MONETIZATION STRATEGY

---

### Phase 1: Launch Revenue (First 30 Days)

**Primary: Freemium Subscription**

| Tier | Price | What You Get |
|---|---|---|
| Free | $0 | Top 3 picks of the day, no confidence scores, no reasoning |
| Pro | $7.99/month | All picks, confidence tiers, injury impact, model reasoning, historical accuracy |

**Why this converts:**
- Free tier is genuinely useful (3 picks = enough to be interested)
- Pro tier paywall hits at exactly the moment users want depth ("why does it like the Lakers?")
- $7.99 is under the "consider carefully" threshold; impulse-purchasable

**Implementation at launch (no app store fees):**
1. Create Stripe product + monthly plan
2. Subscription screen in Flutter opens Stripe Customer Portal WebView or in-app browser
3. On successful payment, Stripe webhook → Firebase Cloud Function → updates `users/{uid}.subscription_tier = "pro"`
4. API checks subscription tier and gates confidence + reasoning fields

**Estimated Month 1 Revenue:**
- 1,000 free users → 5% conversion → 50 Pro users → $400 MRR
- Conservative. If you get on r/sportsbook or r/nba, 1,000 users is achievable in week 1.

---

### Phase 1 Fast Revenue Alternatives (Parallel)

**Option B: One-time "Season Pass" ($19.99)**
- Pay once, get Pro for rest of current NBA season
- Lower friction than recurring subscription
- Good for users skeptical of subscriptions
- Run in parallel with monthly plan; let Stripe handle both

**Option C: Affiliate / Referral Links**
- Add "View Line at DraftKings" / "Bet on FanDuel" buttons next to each pick
- Use sportsbook affiliate programs (DraftKings: $250 CPA, FanDuel: $200 CPA)
- Each referred depositing user = $200–$250 one-time payout
- Zero marginal cost; zero friction for user
- **This may outperform subscriptions in Month 1 — enable immediately at launch**

**Caution on affiliate links:** Display responsible gambling messaging. Some states restrict affiliate programs; know your geography before adding.

---

### Phase 2: Months 2–6

| Mechanism | Projected MRR at 10k MAU |
|---|---|
| Pro subscriptions | $2,000–$4,000 |
| Annual plan conversion | $500–$1,000 |
| Sportsbook affiliate | $3,000–$8,000 |
| Referral program (7-day free trial) | + user growth, not direct revenue |
| **Total** | **$5,500–$13,000 MRR** |

---

### Phase 3–4: Social + Creator Monetization

| Mechanism | Notes |
|---|---|
| Creator tips (Stripe Connect) | Platform takes 15% fee |
| Verified scout badge | $9.99/month |
| Promoted posts | Scouts/programs pay for feed visibility |
| Program analytics dashboard | B2B: $49–$99/month per program (college + HS) |
| API access tier | Developers, other apps: $49/month for raw prediction API |

---

### Phase 5: Ceiling Revenue Model

At scale, the platform has three distinct revenue engines:

1. **Consumer (B2C):** Subscriptions from fans and bettors
2. **Creator economy:** Tips, marketplace, verified tiers
3. **Institutional (B2B):** School programs, scouts, college programs paying for analytics and rankings visibility

The CIFSS rankings product alone could become a paid tier for CIF programs and recruiting services. This is a $50–$500/month B2B product with near-zero marginal cost to serve.

---

## PART 7: OPEN QUESTIONS + DECISIONS TO MAKE

These are intentionally left for your judgment, not defaulted to an opinionated answer:

1. **Playoff mode at MVP launch?** Playoffs start ~April 19. If you launch within 7 days, re-enabling the existing playoff code adds immediate relevance. Cost: ~4 hours to harden and re-enable. Reward: timely content at launch.

2. **iOS vs. Android first?** Flutter builds both, but app store review timelines differ. Prioritize based on where your early audience lives. Android (Google Play) review is typically faster.

3. **Web app?** No web frontend exists. A lightweight Next.js frontend pointing at the same API could expand reach significantly and removes app store as a distribution gatekeeping layer. Prioritize for Phase 2 if mobile growth stalls.

4. **Sportsbook affiliate legality in your state?** Verify before enabling affiliate links. Not all states allow it; some require disclosure.

5. **RevenueCat vs. Stripe for subscriptions?** RevenueCat handles Apple/Google billing seamlessly but costs 1% of revenue. Stripe avoids app store fees entirely but requires linking out to a browser. Phase 1: use Stripe to validate willingness to pay before investing in native billing. Phase 2: migrate to RevenueCat for better UX.

---

## APPENDIX: KEY FILES REFERENCE

| File | Purpose |
|---|---|
| `src/api/main.py` | FastAPI app entry point, middleware, router registration |
| `src/api/routes/chat.py` | **Fix import error here before launch** |
| `src/core/predictor.py` | XGBoost inference + calibration |
| `src/core/confidence_scorer.py` | 5-factor confidence scoring system |
| `src/core/espn_client.py` | ESPN API integration |
| `src/core/odds_client.py` | The Odds API integration |
| `src/core/injury_client.py` | Injury data with 4-hour cache |
| `src/daily_predictions.py` | Daily prediction generation pipeline |
| `src/jobs/daily_cloud_run_job.py` | Cloud Run daily job entrypoint |
| `models/xgb_v3_with_injuries.json` | Trained XGBoost model (918 KB) |
| `models/calibrator_v3.pkl` | Isotonic calibration |
| `cloudbuild.api.yaml` | Cloud Build pipeline for API image |
| `Dockerfile.api` | API container definition |
| `app/lib/main.dart` | Flutter app entry point |
| `app/lib/providers/` | Riverpod state management layer |
| `.env.example` | All required environment variables |
