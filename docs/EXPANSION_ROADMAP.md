# Signal Sports — Expansion Roadmap
**Post-NBA Playoffs Transition Plan**
*Generated: April 24, 2026*

---

## Table of Contents

1. [Strategic Overview](#1-strategic-overview)
2. [Season Calendar & Dead Zone Coverage](#2-season-calendar--dead-zone-coverage)
3. [Data Sources by Segment](#3-data-sources-by-segment)
4. [Existing Pipeline Reusability](#4-existing-pipeline-reusability)
5. [WNBA Expansion Plan](#5-wnba-expansion-plan)
6. [College Basketball Expansion Plan](#6-college-basketball-expansion-plan)
7. [NBA Draft & Free Agency Features](#7-nba-draft--free-agency-features)
8. [High School & Recruiting](#8-high-school--recruiting)
9. [International Basketball](#9-international-basketball)
10. [Revenue Strategy by Segment](#10-revenue-strategy-by-segment)
11. [Recommended Build Order](#11-recommended-build-order)
12. [Technical Implementation Notes](#12-technical-implementation-notes)

---

## 1. Strategic Overview

The NBA playoffs end mid-June. Without action, the app has no content from June through mid-October — roughly **4 dead months**. The goal is to eliminate that dead zone while staying true to the core product (AI-driven basketball predictions) and the brand (Signal Sports).

### Target Segments (Priority Order)

| Segment | Season Window | Market Size | Effort | Revenue Potential |
|---------|--------------|-------------|--------|-------------------|
| **WNBA** | May – October | Growing fast, underserved | Low | Medium |
| **NBA Draft** | Late May – June | Massive annual spike | Very Low | Medium |
| **NBA Free Agency** | July | Massive annual spike | Very Low | Medium |
| **College Basketball** | November – April | Huge, best monetization window | High | High |
| **NBA Summer League** | July | Niche, engaged | Very Low | Low |
| **High School / Recruiting** | Year-round | Niche but loyal | Medium | Low-Medium |
| **International (EuroLeague/FIBA)** | September – May | Smaller US market | Medium | Low |

### Dead Zone Coverage Map

```
Jan  Feb  Mar  Apr  May  Jun  Jul  Aug  Sep  Oct  Nov  Dec
 NBA Regular Season ───────────────────────▶│
                               Playoffs ─────▶│
                                              │← Dead Zone →│ NBA starts
 WNBA                              ┌──────────────────┐
                                   May                 Oct
 NCAA                 ┌────────────┐                        ┌──────────────
                      Jan  Tourney-▶                        Nov
 Draft                                   ┌─┐
                                         Jun
 Free Agency                                 ┌──┐
                                             Jul
 Summer League                               ┌─┐
                                             Jul
 International        ┌──────────────────────────────────────────────────
                       EuroLeague / FIBA runs October – May
```

WNBA alone eliminates the entire June–October dead zone.

---

## 2. Season Calendar & Dead Zone Coverage

### Month-by-Month Content Plan

| Month | Primary Content | Secondary |
|-------|----------------|-----------|
| **May** | NBA Playoffs + WNBA season opens | Draft content |
| **June** | NBA Finals + Draft predictions | WNBA |
| **July** | WNBA predictions | Free Agency tracker, Summer League |
| **August** | WNBA predictions | International (EuroLeague preseason) |
| **September** | WNBA Playoffs | Fantasy prep content |
| **October** | WNBA Finals + NBA preseason | College basketball previews |
| **November** | NBA season + College Basketball opens | WNBA off-season recruiting |
| **December** | NBA + College Basketball | |
| **January** | NBA + College Basketball | International |
| **February** | NBA + College Basketball | All-Star, recruiting signing day |
| **March** | NBA + March Madness | |
| **April** | NBA Playoffs begin + College finals | |

---

## 3. Data Sources by Segment

### 3.1 ESPN Unofficial API (Core Source — Free, No Auth)

The most important finding: **ESPN's public API already supports WNBA and College Basketball with the same endpoint structure as NBA.** This means your existing `ESPNClient` is ~90% ready.

**Just swap the league slug:**

```
# NBA (current)
https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard

# WNBA
https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard

# Men's College Basketball
https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard

# Women's College Basketball
https://site.api.espn.com/apis/site/v2/sports/basketball/womens-college-basketball/scoreboard

# NBA Summer League
https://site.api.espn.com/apis/site/v2/sports/basketball/nba-summer-league/scoreboard
```

**Additional ESPN endpoints (same pattern for all leagues):**
```
/teams           → All teams with IDs
/teams/{id}      → Team detail + roster
/teams/{id}/injuries → Team injury report
/standings       → League standings
/news            → League news
```

**Query parameters:**
- `dates=YYYYMMDD` — specific date
- `groups=100` — return more games (important for college; 50-80 games/day)
- `limit=365` — result limit for standings/teams

**Rate limits:** No official limits. Recommended: 1 request/second or 30–60 second cooldowns for batch jobs.

**Reference:** https://github.com/pseudo-r/Public-ESPN-API

---

### 3.2 BALLDONTLIE API

**URL:** https://www.balldontlie.io  
**Auth:** Free API key (app.balldontlie.io)  
**Format:** JSON

Covers NBA, WNBA, NCAAB, NCAAW, NFL, MLB, NHL, EPL.

| Tier | Price | What You Get |
|------|-------|-------------|
| Free | $0 | Teams, players, games (basic) |
| ALL-STAR | $9.99/mo | Stats, injuries, standings |
| GOAT | $39.99/mo | Advanced stats, box scores, odds |

**Endpoints:**
```
GET https://api.balldontlie.io/v1/teams?api_key={key}
GET https://api.balldontlie.io/v1/players?api_key={key}
GET https://api.balldontlie.io/v1/games?seasons[]=2025&api_key={key}
GET https://api.balldontlie.io/v1/standings?api_key={key}  # ALL-STAR
```

**Best use case:** Injury data ($9.99/mo tier) and advanced stats if ESPN doesn't provide enough.

---

### 3.3 stats.nba.com / stats.wnba.com

**URL:** https://stats.nba.com / https://stats.wnba.com  
**Auth:** None required  
**Format:** JSON  
**Rate limit:** ~1–2 second delays recommended

WNBA uses the exact same endpoint structure — just swap the host.

**NBA Draft Combine Endpoints:**
```
GET https://stats.nba.com/stats/draftcombinedrillresults
GET https://stats.nba.com/stats/draftcombineplayeranthro
GET https://stats.nba.com/stats/draftcombinestats
```

**Python wrapper (recommended):** https://github.com/swar/nba_api  
**WNBA-focused wrapper:** https://github.com/basketballrelativity/py_ball

---

### 3.4 Basketball Reference

**URL:** https://www.basketball-reference.com  
**Auth:** None  
**Rate limit:** 20 requests/minute (strictly enforced)  
**Format:** HTML scraping

**Python scrapers:**
- https://github.com/jaebradley/basketball_reference_web_scraper
- https://github.com/vishaalagartha/basketball_reference_scraper
- https://github.com/GabrielPastorello/BRScraper (includes international)

**Best use case:** Historical data backfill for WNBA and college basketball model training. Not for real-time.

---

### 3.5 Sportradar (Paid — Best Quality)

**URL:** https://developer.sportradar.com  
**Auth:** API key (30-day free trial)  
**Format:** JSON/XML  
**Note:** B2B service; requires commercial agreement for production

**Available leagues:**
- NBA v5
- WNBA v3
- NCAAMB (NCAA Men's)
- NCAAW (NCAA Women's)
- Global Basketball v2 (international)

**Trial endpoints:**
```
GET https://api.sportradar.us/basketball/trial/v5/en/schedules/{year}/{season_type}/schedule.json
GET https://api.sportradar.us/basketball/trial/v5/en/games/{game_id}/summary.json
```

**Best use case:** If/when the app scales to paid data tier. Start with ESPN free, upgrade selectively.

---

### 3.6 NCAA Community APIs

No official public API from NCAA. Use ESPN endpoint or:

**Community API (reverse-engineered):**
```
GET https://api.ncaa.org/site/v2/sports/basketball/mens-college-basketball/teams
GET https://api.ncaa.org/site/v2/sports/basketball/mens-college-basketball/scoreboard
```

**SportsDataIO (paid):**
```
GET https://api.sportsdata.io/v3/cbb/scores/json/teams?key={key}
GET https://api.sportsdata.io/v3/cbb/scores/json/games/{year}/{season}?key={key}
```

---

### 3.7 Odds API

**URL:** https://the-odds-api.com  
**Free tier:** 500 requests/month  
**Sport keys:**
```
basketball_nba          → NBA
basketball_wnba         → WNBA
basketball_ncaab        → NCAA Men's Basketball
basketball_euroleague   → EuroLeague
```

College basketball odds coverage is limited on the free tier; only top programs have regular markets.

---

### 3.8 EuroLeague Official API

**Swagger UI:** https://api-live.euroleague.net/swagger/index.html  
**Status:** Official API, auth may be required  

**Community Python wrapper:**
- https://github.com/giasemidis/euroleague_api

**Basketball Reference (international):**
- https://www.basketball-reference.com/international/euroleague/

---

### 3.9 FIBA

**Portal:** https://gdap-portal.fiba.basketball/documentation  
**Status:** Official; requires registration  
**Includes:** International competitions, FIBA LiveStats (real-time), rankings

---

### 3.10 High School Basketball

No official public API exists. Options:

| Platform | What's Available | Method |
|----------|-----------------|--------|
| MaxPreps (maxpreps.com) | Schedules, scores, rosters | Scraping |
| 247Sports | Recruiting rankings, commitments | Scraping (may violate ToS) |
| ESPN Recruiting | Player rankings, star ratings | Scraping |
| On3 | Rankings, NIL data | Scraping |

**Apify scraper** (paid SaaS) for 247Sports/On3/ESPN recruiting: https://apify.com/erikhiggy96/on3-recruit-scraper/api

**Recommendation:** Skip high school data automation initially. Use it for editorial content (rankings highlights, commit news) rather than automated predictions.

---

### 3.11 Data Source Summary Table

| Source | NBA | WNBA | NCAA | Draft | EuroLeague | Free | Auth |
|--------|-----|------|------|-------|------------|------|------|
| ESPN API | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | None |
| BALLDONTLIE | ✅ | ✅ | ✅ | Partial | ❌ | Free tier | Key |
| stats.nba.com | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | None |
| Basketball Ref | ✅ | ✅ | ✅ | Partial | ✅ | ✅ | None |
| Sportradar | ✅ | ✅ | ✅ | ✅ | ✅ | Trial | Key |
| NCAA Community | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | None |
| The Odds API | ✅ | ✅ | Limited | ❌ | ✅ | 500/mo | Key |
| EuroLeague API | ❌ | ❌ | ❌ | ❌ | ✅ | TBD | TBD |
| FIBA | ❌ | ❌ | ❌ | ❌ | ❌ | Registration | Key |

---

## 4. Existing Pipeline Reusability

Based on a full audit of the codebase, here is how much of the existing NBA infrastructure carries over to each new segment.

### 4.1 Component Reusability Matrix

| Component | File | WNBA | College | Notes |
|-----------|------|------|---------|-------|
| `ESPNClient` | `src/core/espn_client.py` | 90% | 85% | Swap endpoint URL |
| `TeamMapper` | `src/core/team_mapper.py` | 100% | 100% | New lookup CSV only |
| `EloTracker` | `src/core/elo_tracker.py` | 100% | 100% | Fully league-agnostic |
| `StatsTracker` | `src/core/stats_tracker.py` | 100% | 100% | Fully league-agnostic |
| `InjuryClient` | `src/core/injury_client.py` | 90% | 10% | No ESPN college injury data |
| `InjuryCache` | `src/core/injury_cache.py` | 100% | 100% | Fully generic |
| `FeatureBuilder` | `src/core/feature_builder.py` | 100% | 100% | Pluggable components |
| `GameProcessor` | `src/core/game_processor.py` | 100% | 100% | Fully generic |
| `Predictor` | `src/core/predictor.py` | 95% | 95% | Swap model file path |
| `ConfidenceScorer` | `src/core/confidence_scorer.py` | 100% | 100% | Fully generic |
| `OddsClient` | `src/core/odds_client.py` | 90% | 30% | Swap sport key; limited college odds |
| `build_elo.py` | `src/build_elo.py` | 95% | 95% | Fix paths, same logic |
| `daily_predictions.py` | `src/daily_predictions.py` | 90% | 90% | Swap config |
| `XGBoost model` | `models/xgb_v3_*.json` | Retrain | Retrain | Same architecture |
| Cloud Functions | `functions/index.js` | 85% | 85% | Swap ESPN endpoints |
| FastAPI routes | `src/api/routes/` | 95% | 90% | Swap dependency injection |
| Flutter app | `app/lib/` | 95% | 95% | Swap API base URL |

### 4.2 Key Insight: League Config Pattern

The cleanest implementation path is a **`league_config.py`** that makes components pluggable:

```python
# src/core/league_config.py

@dataclass
class LeagueConfig:
    league_name: str
    team_count: int
    espn_slug: str              # "nba", "wnba", "mens-college-basketball"
    default_elo: float = 1500.0
    home_court_advantage: float = 70.0  # NBA: 70; tune per league
    k_factor: float = 20.0
    season_carryover: float = 0.7
    injury_source: str = "espn"          # "espn", "none"
    odds_sport_key: str = ""             # The Odds API key
    team_lookup_csv: str = ""
    model_path: str = ""
    calibrator_path: str = ""
    state_dir: str = ""

NBA_CONFIG = LeagueConfig(
    league_name="NBA",
    team_count=30,
    espn_slug="nba",
    home_court_advantage=70.0,
    injury_source="espn",
    odds_sport_key="basketball_nba",
    team_lookup_csv="data/processed/team_lookup.csv",
    model_path="models/xgb_v3_with_injuries.json",
    calibrator_path="models/calibrator_v3.pkl",
    state_dir="state/nba/",
)

WNBA_CONFIG = LeagueConfig(
    league_name="WNBA",
    team_count=13,
    espn_slug="wnba",
    home_court_advantage=55.0,  # Tune empirically
    injury_source="espn",
    odds_sport_key="basketball_wnba",
    team_lookup_csv="data/processed/wnba_team_lookup.csv",
    model_path="models/xgb_wnba_v1.json",
    calibrator_path="models/calibrator_wnba_v1.pkl",
    state_dir="state/wnba/",
)

CBB_CONFIG = LeagueConfig(
    league_name="NCAA Men's Basketball",
    team_count=352,  # D-I only
    espn_slug="mens-college-basketball",
    home_court_advantage=80.0,  # Tune empirically; likely higher than NBA
    injury_source="none",        # No ESPN college injury data
    odds_sport_key="basketball_ncaab",
    team_lookup_csv="data/processed/cbb_team_lookup.csv",
    model_path="models/xgb_cbb_v1.json",
    calibrator_path="models/calibrator_cbb_v1.pkl",
    state_dir="state/cbb/",
)
```

### 4.3 What Needs to Be Built vs. Reused

**Zero new code needed (reuse as-is):**
- EloTracker, StatsTracker, FeatureBuilder, GameProcessor, InjuryCache, ConfidenceScorer

**Minimal changes (1–2 hours each):**
- ESPNClient → parameterize the `BASE_URL`
- InjuryClient → parameterize the league slug
- OddsClient → parameterize the sport key
- `daily_predictions.py` → accept `--league` flag

**New data needed (the real work):**
- WNBA team lookup CSV
- College basketball team lookup CSV
- Historical game data for WNBA model training
- Historical game data for CBB model training
- Retrain XGBoost model per league

---

## 5. WNBA Expansion Plan

### Why WNBA First

- **Fastest growing basketball market in the US** — viewership records broken each season since 2023
- **Underserved by prediction apps** — no dominant AI-prediction product exists for WNBA
- **Your pipeline ports at 90%** — ESPN has the same API structure
- **Authenticity** — building for WNBA signals you're a real basketball product, not just an NBA side-hustle
- **Timing** — WNBA season opens in May, directly bridging NBA Finals

### WNBA Season Structure

```
Early May:    Regular season begins
Mid-May:      Full slate of games (12–13 games/week)
August:       Playoff push
September:    WNBA Playoffs (12 teams)
October:      WNBA Finals
```

### Teams (13 teams as of 2026)

| Team | Abbreviation | ESPN ID (to verify) |
|------|-------------|---------------------|
| Atlanta Dream | ATL | — |
| Chicago Sky | CHI | — |
| Connecticut Sun | CON | — |
| Dallas Wings | DAL | — |
| Golden State Valkyries | GSV | — |
| Indiana Fever | IND | — |
| Las Vegas Aces | LV | — |
| Los Angeles Sparks | LA | — |
| Minnesota Lynx | MIN | — |
| New York Liberty | NY | — |
| Phoenix Mercury | PHX | — |
| Seattle Storm | SEA | — |
| Washington Mystics | WSH | — |

*Pull actual ESPN team IDs from: `https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/teams`*

### Data Sources for WNBA

| Data Type | Source | Endpoint/URL |
|-----------|--------|-------------|
| Scores / Schedule | ESPN | `.../wnba/scoreboard` |
| Team info | ESPN | `.../wnba/teams` |
| Injuries | ESPN | `.../wnba/teams/{id}/injuries` |
| Historical games | Basketball Reference | basketball-reference.com/wnba |
| Stats | stats.wnba.com | Same structure as stats.nba.com |
| Odds | The Odds API | `basketball_wnba` sport key |
| Advanced stats | BALLDONTLIE $9.99/mo | WNBA endpoint |

### WNBA Build Steps

**Phase 1 — Data (1 week)**
1. Fetch team list from ESPN WNBA endpoint; build `data/processed/wnba_team_lookup.csv`
2. Download historical WNBA games (2010–2025) from Basketball Reference scraper
3. Parse into same format as `games_with_labels.csv`
4. Run `build_elo.py` on WNBA data to generate Elo features

**Phase 2 — Model (3–5 days)**
1. Compute rolling stats features for all historical WNBA games
2. Use same 31-feature set (drop injury features initially; add zeros)
3. Retrain XGBoost (same hyperparameters as starting point, tune from there)
4. Calibrate with LogisticRegression
5. Save as `models/xgb_wnba_v1.json` and `models/calibrator_wnba_v1.pkl`

**Phase 3 — Pipeline (2–3 days)**
1. Add `WNBA_CONFIG` to `league_config.py`
2. Parameterize `ESPNClient` to accept league slug
3. Parameterize `InjuryClient` to accept league slug
4. Parameterize `OddsClient` to accept sport key
5. Add `--league` flag to `daily_predictions.py`
6. Create `state/wnba/` directory; initialize `elo.json` and `stats.json`

**Phase 4 — API (1 day)**
1. Add `/wnba/predict/today` and `/wnba/games/{date}` routes
2. Update `dependencies.py` to inject WNBA service instances
3. Test end-to-end

**Phase 5 — App (2 days)**
1. Add WNBA league toggle in Flutter app
2. Add WNBA team logos/colors (ESPN provides these)
3. Test on device

**Total estimated effort: 2–2.5 weeks**

### WNBA Home Court Advantage Note

NBA HCA is ~70 Elo. WNBA likely lower (smaller arenas, less travel fatigue). Start at 55–60 and tune empirically. A rough test: in historical data, home teams should win ~55–57% of games; adjust HCA until predicted home win rate matches observed rate.

---

## 6. College Basketball Expansion Plan

### Why College Basketball

- **350+ Division I teams** = massive prediction surface
- **March Madness bracket** = the single best known sports monetization event in the US
- **Long season** (November – April) = covers your other dead zone
- **High school recruiting feeds into this** naturally
- **Underserved by AI-prediction apps** at the individual-game level

### NCAA Season Structure

```
Mid-October:  Preseason tips ("Midnight Madness")
November:     Regular season begins
November-February: Conference play
Early March:  Conference tournaments
Mid-March:    NCAA Tournament (Selection Sunday → Elite 8 → Final Four)
First week April: Final Four + National Championship
```

### CBB Challenges vs. NBA/WNBA

| Challenge | Impact | Mitigation |
|-----------|--------|-----------|
| 350+ teams | Large state files, more data | Filter to D-I only; use ESPN team IDs |
| No injury data from ESPN | Missing injury features | Zero-impute injury features (model works without) |
| Limited odds for most games | Can't use market probability feature | Default to 0.5 for non-marquee games |
| Travel imbalance (home court is huge) | HCA likely 80–100 Elo | Tune HCA empirically per conference |
| Transfer portal chaos | Players move teams constantly | Roster data is less reliable; focus on team-level Elo |
| More variance than NBA | Lower model accuracy | Be transparent; confidence scoring more important |

### Data Sources for College Basketball

| Data Type | Source | Endpoint/URL |
|-----------|--------|-------------|
| Scores / Schedule | ESPN | `.../mens-college-basketball/scoreboard?groups=100` |
| Team info | ESPN | `.../mens-college-basketball/teams` |
| Historical games | Sports Reference | sports-reference.com/cbb |
| Rankings (AP/Coaches) | ESPN | `.../mens-college-basketball/rankings` |
| Conference standings | ESPN | `.../mens-college-basketball/standings` |
| Odds (top 25 games) | The Odds API | `basketball_ncaab` |
| Recruiting | 247Sports / On3 | Scraping or Apify |

### College Basketball Build Steps

**Phase 1 — Data (1–1.5 weeks)**
1. Fetch D-I team list from ESPN; filter to Division I (ESPN `groups` param helps)
2. Build `data/processed/cbb_team_lookup.csv` (~352 teams)
3. Download historical CBB games from Basketball Reference (2010–2025)
4. Parse into `games_with_labels.csv` format
5. Note: volume is ~5,000 games/season vs ~1,230 for NBA

**Phase 2 — Model (3–5 days)**
1. Compute Elo and rolling stats for all historical games
2. Zero-impute injury and market odds features (not available)
3. Retrain XGBoost on CBB data
4. Consider separate models by conference or by game type (regular season vs. tournament)
5. Calibrate and save as `models/xgb_cbb_v1.json`

**Phase 3 — Pipeline (2–3 days)**
Same as WNBA Phase 3, using `CBB_CONFIG`.

**Phase 4 — March Madness Mode (1 week, separate)**
1. Build bracket data ingestion from ESPN tournament endpoint
2. Track series/round context (similar to existing `playoff_espn_client.py`)
3. Add bracket simulation feature: simulate full tournament N times, output each team's probability of reaching each round
4. This is the core of the March Madness paywall feature

**Total estimated effort: 3–4 weeks (not counting March Madness bracket)**

### March Madness Bracket Simulator (Revenue Feature)

This is the highest-value college feature. Before March Madness:
- Run 10,000 Monte Carlo simulations of the 68-team bracket
- Output: probability each team reaches Sweet 16, Elite 8, Final Four, Championship
- Show users "who Signal Sports thinks will cut down the nets"
- **Paywall:** Free users see top 25 teams; premium users see full bracket probabilities + upset alerts

---

## 7. NBA Draft & Free Agency Features

### 7.1 NBA Draft (Late June)

**Content type:** Analysis and predictions, not game predictions.

**Data available:**
```
# Draft combine (stats.nba.com)
GET https://stats.nba.com/stats/draftcombinedrillresults
GET https://stats.nba.com/stats/draftcombineplayeranthro
GET https://stats.nba.com/stats/draftcombinestats

# Team needs (can derive from current rosters + standings)
GET https://stats.nba.com/stats/commonteamroster?TeamID={id}&Season=2025-26

# Mock draft data (no public API — manual curation or web display)
```

**Feature ideas:**
- "Signal Sports Draft Board" — AI-ranked top 60 prospects based on combine stats
- Team fit scores: for each prospect, rank best/worst team fits
- Draft grade predictions: predict how each team's haul grades out post-draft
- "Who did your team pick?" reaction content

**Build effort:** 1 week (mostly data curation + display, not prediction model)

### 7.2 NBA Free Agency (July 1)

**Content type:** Prediction and tracking.

**Data available:**
- Player contract info: spotrac.com (scraping) or SportsReference
- Cap space: basketball-reference.com/contracts
- Team needs: derivable from roster analysis

**Feature ideas:**
- "Where will [player] sign?" prediction with probability breakdown
- Cap space tracker per team
- "Value contract" alerts — flag players who sign for below-market value
- Push notifications when major signings happen (Firebase + ESPN news API)

**ESPN news endpoint:**
```
GET https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news
```

**Build effort:** 1 week

---

## 8. High School & Recruiting

### Strategic Position

Don't try to scrape recruiting databases — it's legally gray and technically fragile. Instead:

**Approach: Curated + Community**
- Partner with local coaches or AAU programs to get game data
- Build a manual submission tool: coaches can submit game scores
- Focus on top programs in states where you have users (check Firebase analytics)
- Use recruiting news from ESPN's API as editorial content in the feed

**MaxPreps (maxpreps.com):**
- Has game scores and schedules
- No public API
- Scraping possible but fragile; check ToS

**Long-term opportunity:**
High school basketball is genuinely underserved. A simple, clean prediction app for high school games in specific states (Texas, California, Kentucky, Indiana) would fill a real gap. This is a future phase, not Phase 1.

---

## 9. International Basketball

### EuroLeague

**Season:** October – May  
**Official API:** https://api-live.euroleague.net/swagger/index.html  
**Python wrapper:** https://github.com/giasemidis/euroleague_api

```python
# Install
pip install euroleague-api

# Usage
from euroleague_api import EuroLeagueData
el = EuroLeagueData()
games = el.get_game_stats(season_code='E2025', gamecode=1)
```

**Available data:** Schedules, scores, box scores, play-by-play, standings, player stats.

### FIBA

**Portal:** https://gdap-portal.fiba.basketball  
**Requires registration.** Best for FIBA World Cup / Olympic qualifiers.

### Build Recommendation

International basketball is a lower priority for US market. Consider it a Phase 3 feature to fill September (EuroLeague preseason) and add international flavor to the app. The EuroLeague Python wrapper makes it low-effort to prototype.

---

## 10. Revenue Strategy by Segment

### Freemium Model (Current + Expanded)

| Feature | Free | Premium |
|---------|------|---------|
| Today's NBA/WNBA predictions | ✅ Basic | ✅ + injury context |
| Confidence scores | Limited | Full |
| College Basketball predictions | Top 25 games | All D-I games |
| March Madness bracket | Top 16 teams | Full 68-team bracket |
| Push notifications | None | Game-day alerts |
| Historical accuracy stats | None | Full model record |
| AI chat agent | 3 messages/session | Unlimited |
| Draft analysis | Headlines | Deep profiles |
| Free Agency tracker | Major moves | All signings + predictions |

### RevenueCat Subscription Tiers (Suggested)

```
Free:      Game predictions for top matchups; basic confidence
Signal+:   $4.99/mo — Full predictions all leagues, push notifications
Signal Pro: $9.99/mo — Everything + March Madness bracket + AI agent unlimited
```

### Revenue Drivers by Season

| Season | Revenue Driver | Tier |
|--------|---------------|------|
| May-June | WNBA season opens → subscription push | Signal+ |
| June | Draft analysis (content marketing → sign-ups) | Signal Pro |
| October | NBA season + app store push | All |
| November | CBB opens → new audience | Signal+ |
| March | March Madness bracket (biggest spike) | Signal Pro |

---

## 11. Recommended Build Order

### Phase 0 — Foundation (Now, 1 week)
- [ ] Create `src/core/league_config.py` with `LeagueConfig` dataclass
- [ ] Parameterize `ESPNClient` to accept league slug from config
- [ ] Parameterize `InjuryClient` to accept league slug
- [ ] Parameterize `OddsClient` to accept sport key
- [ ] Add `--league` flag to `daily_predictions.py`
- [ ] Create `state/{league}/` directory structure

This makes every subsequent phase cheaper and cleaner.

### Phase 1 — WNBA (June, 2 weeks)
- [ ] WNBA team lookup CSV
- [ ] Historical WNBA data download + parsing
- [ ] Elo backfill for WNBA
- [ ] XGBoost model training for WNBA
- [ ] Add WNBA league config and wire up pipeline
- [ ] Add WNBA routes to FastAPI
- [ ] Add WNBA league toggle to Flutter app
- [ ] Announce: "Signal Sports now covers WNBA"

**Goal:** Live predictions for WNBA opening day in May.

### Phase 2 — Draft & Free Agency Content (June–July, 1 week)
- [ ] Draft combine data display in app
- [ ] "Top Prospects" screen powered by stats.nba.com
- [ ] ESPN news feed integration (news carousel in app)
- [ ] Free Agency tracker with team cap space display
- [ ] Push notifications for major signings

### Phase 3 — College Basketball (October launch, 3 weeks)
- [ ] CBB team lookup CSV (352 teams)
- [ ] Historical CBB data download + parsing
- [ ] XGBoost model training for CBB
- [ ] Add CBB league config and wire up pipeline
- [ ] Add CBB routes to FastAPI
- [ ] Add CBB toggle to Flutter app
- [ ] College rankings display (AP Top 25)

### Phase 4 — March Madness (February, separate sprint)
- [ ] NCAA Tournament bracket ingestion
- [ ] Monte Carlo bracket simulator
- [ ] "Signal Sports Final Four Prediction" screen
- [ ] Paywall for full bracket probabilities

### Phase 5 — International & High School (Future)
- [ ] EuroLeague integration (Python wrapper)
- [ ] High school game submission tool

---

## 12. Technical Implementation Notes

### Directory Structure for Multi-League

```
Basketball_Prediction/
├── src/
│   ├── core/
│   │   ├── league_config.py         ← NEW: League configuration registry
│   │   ├── espn_client.py           ← MODIFY: Accept slug from config
│   │   ├── injury_client.py         ← MODIFY: Accept slug from config
│   │   ├── odds_client.py           ← MODIFY: Accept sport key from config
│   │   ├── elo_tracker.py           ← No changes needed
│   │   ├── stats_tracker.py         ← No changes needed
│   │   ├── feature_builder.py       ← No changes needed
│   │   ├── predictor.py             ← No changes needed
│   │   └── game_processor.py        ← No changes needed
│   ├── daily_predictions.py         ← MODIFY: Add --league flag
│   ├── build_elo.py                 ← MODIFY: Accept league config path
│   └── ...
│
├── state/
│   ├── nba/
│   │   ├── elo.json
│   │   ├── stats.json
│   │   └── metadata.json
│   ├── wnba/                        ← NEW
│   │   ├── elo.json
│   │   ├── stats.json
│   │   └── metadata.json
│   └── cbb/                         ← NEW
│       ├── elo.json
│       ├── stats.json
│       └── metadata.json
│
├── models/
│   ├── xgb_v3_with_injuries.json    ← NBA
│   ├── calibrator_v3.pkl
│   ├── xgb_wnba_v1.json             ← NEW
│   ├── calibrator_wnba_v1.pkl
│   ├── xgb_cbb_v1.json              ← NEW
│   └── calibrator_cbb_v1.pkl
│
├── data/
│   └── processed/
│       ├── team_lookup.csv           ← NBA (existing)
│       ├── wnba_team_lookup.csv      ← NEW
│       └── cbb_team_lookup.csv       ← NEW
│
└── docs/
    └── EXPANSION_ROADMAP.md          ← This file
```

### ESPN Client Refactor Sketch

```python
# src/core/espn_client.py — minimal change to support multi-league

class ESPNClient:
    BASE_TEMPLATE = "https://site.api.espn.com/apis/site/v2/sports/basketball/{slug}/{endpoint}"
    
    def __init__(self, team_mapper: TeamMapper, league_slug: str = "nba"):
        self.team_mapper = team_mapper
        self.league_slug = league_slug
    
    def _url(self, endpoint: str) -> str:
        return self.BASE_TEMPLATE.format(slug=self.league_slug, endpoint=endpoint)
    
    def get_games(self, date: str) -> List[GameResult]:
        url = self._url("scoreboard")
        # ... rest of implementation unchanged ...
```

### Multi-League Daily Job

```bash
# Run all leagues each morning
python src/update_state.py --league nba
python src/update_state.py --league wnba      # when in season
python src/update_state.py --league cbb       # when in season

# Generate predictions for all active leagues
python src/daily_predictions.py --league nba --output predictions/nba.json
python src/daily_predictions.py --league wnba --output predictions/wnba.json
python src/daily_predictions.py --league cbb --output predictions/cbb.json
```

### Flutter League Toggle

```dart
// app/lib/Services/app_config.dart

enum League { nba, wnba, cbb }

extension LeagueExtension on League {
  String get apiSlug => ['nba', 'wnba', 'cbb'][index];
  String get displayName => ['NBA', 'WNBA', 'College Basketball'][index];
  String get espnSlug => ['nba', 'wnba', 'mens-college-basketball'][index];
}
```

---

## Appendix: Key URLs Quick Reference

### ESPN API Base
```
https://site.api.espn.com/apis/site/v2/sports/basketball/{league}/scoreboard
https://site.api.espn.com/apis/site/v2/sports/basketball/{league}/teams
https://site.api.espn.com/apis/site/v2/sports/basketball/{league}/standings
https://site.api.espn.com/apis/site/v2/sports/basketball/{league}/news
```

### League Slugs for ESPN
```
nba
wnba
mens-college-basketball
womens-college-basketball
nba-summer-league
```

### External Docs
- ESPN API guide: https://github.com/pseudo-r/Public-ESPN-API
- BALLDONTLIE: https://www.balldontlie.io/docs
- nba_api Python: https://github.com/swar/nba_api
- Basketball Ref scraper: https://github.com/jaebradley/basketball_reference_web_scraper
- EuroLeague API Python: https://github.com/giasemidis/euroleague_api
- Sportradar trial: https://developer.sportradar.com
- The Odds API: https://the-odds-api.com
- FIBA GDAP: https://gdap-portal.fiba.basketball/documentation
