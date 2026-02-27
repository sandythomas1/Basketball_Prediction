/**
 * Firebase Cloud Functions for NBA Predictions app
 * 
 * Functions:
 *  - chatWithAgent          HTTP  — secure Dialogflow CX proxy
 *  - cleanupOldForumMessages  Scheduled — nightly forum cleanup
 *  - refreshDailyContext      Scheduled — daily GCS data refresh (9 AM ET)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { SessionsClient } = require('@google-cloud/dialogflow-cx');
const { Storage } = require('@google-cloud/storage');
const axios = require('axios');

admin.initializeApp();

const db = admin.database();
const storage = new Storage();

// =============================================================================
// Constants
// =============================================================================

const DAILY_FREE_CHAT_LIMIT = 3;

// =============================================================================
// Configuration
// =============================================================================

// All config now lives in functions/.env (no more deprecated functions.config())
// NOTE: No hardcoded fallbacks — missing env vars will cause a startup error
// so secrets are never accidentally baked into source code.
const AGENT_CONFIG = {
  projectId:    process.env.GCP_PROJECT_ID,
  location:     process.env.GCP_LOCATION   || 'global',
  agentId:      process.env.GCP_AGENT_ID,
  languageCode: 'en',
};

const RENDER_API_URL = process.env.RENDER_API_URL;

// Deploy region — us-west1 keeps latency low for US West Coast users
const REGION = 'us-west1';

// ---------------------------------------------------------------------------
// Startup validation — fail fast if required env vars are missing
// ---------------------------------------------------------------------------
const REQUIRED_ENV_VARS = ['GCP_PROJECT_ID', 'GCP_AGENT_ID', 'RENDER_API_URL'];
for (const key of REQUIRED_ENV_VARS) {
  if (!process.env[key]) {
    throw new Error(
      `Missing required environment variable: ${key}. ` +
      'Add it to functions/.env (local) or Cloud Function environment settings (deployed).'
    );
  }
}

// GCS bucket that the Vertex AI agent data store reads from
const GCS_BUCKET = 'nba-prediction-data-metadata';

// ESPN public API base
const ESPN_BASE = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba';

// Initialize Dialogflow CX client
const sessionsClient = new SessionsClient({
  apiEndpoint: `${AGENT_CONFIG.location}-dialogflow.googleapis.com`,
});

// =============================================================================
// Helpers
// =============================================================================

/**
 * Upload a JS object as a JSON file to GCS.
 */
async function uploadToGCS(fileName, data) {
  const bucket = storage.bucket(GCS_BUCKET);
  const file = bucket.file(`ai_context/${fileName}`);
  const json = JSON.stringify(data, null, 2);
  await file.save(json, { contentType: 'application/json', resumable: false });
  console.log(`✓ Uploaded ai_context/${fileName} (${Math.round(json.length / 1024)} KB)`);
}

/**
 * Fetch JSON from a URL with a timeout.
 */
async function fetchJSON(url, timeoutMs = 10000) {
  const res = await axios.get(url, { timeout: timeoutMs });
  return res.data;
}

/**
 * Return YYYYMMDD string for a Date offset by `daysAgo`.
 */
function dateString(daysAgo = 0) {
  const d = new Date();
  d.setDate(d.getDate() - daysAgo);
  return d.toISOString().slice(0, 10).replace(/-/g, '');
}

/**
 * Return YYYY-MM-DD string for today.
 */
function isoToday() {
  return new Date().toISOString().slice(0, 10);
}

// =============================================================================
// Data Fetchers
// =============================================================================

/**
 * Fetch league-wide injury report from ESPN and structure it.
 */
async function fetchInjuryReport() {
  const data = await fetchJSON(`${ESPN_BASE}/injuries`);
  const teams = [];

  for (const teamObj of (data.injuries || [])) {
    const teamName = teamObj.displayName || '';
    const injuries = [];
    let totalSeverity = 0;

    for (const inj of (teamObj.injuries || [])) {
      const athlete = inj.athlete || {};
      const status   = inj.status || 'Unknown';
      const details  = inj.details || {};

      // Severity weights matching Python injury_client.py
      const severityMap = { out: 1.0, o: 1.0, doubtful: 0.75, d: 0.75,
                            questionable: 0.5, q: 0.5, 'day-to-day': 0.25, dtd: 0.25 };
      const severity = severityMap[status.toLowerCase()] || 0.0;
      totalSeverity += severity;

      injuries.push({
        player_name:   athlete.displayName || 'Unknown',
        status,
        injury_type:   details.type || 'Unknown',
        details:       inj.longComment || inj.shortComment || '',
        severity_score: severity,
      });
    }

    teams.push({
      team_name:               teamName,
      injury_count:            injuries.length,
      severity_score:          Math.round(totalSeverity * 100) / 100,
      has_significant_injuries: injuries.some(i => i.status.toLowerCase() === 'out')
                                || injuries.filter(i => i.status.toLowerCase() === 'questionable').length >= 2,
      injuries,
    });
  }

  return {
    generated_at: new Date().toISOString(),
    last_updated: new Date().toLocaleString('en-US', { timeZone: 'America/New_York' }) + ' ET',
    league: 'NBA',
    total_teams: teams.length,
    teams,
  };
}

/**
 * Build a lookup of teamName → injury info for fast per-game enrichment.
 */
function buildInjuryLookup(injuryReport) {
  const lookup = {};
  for (const team of injuryReport.teams) {
    lookup[team.team_name.toLowerCase()] = team;
  }
  return lookup;
}

/**
 * Fetch current NBA standings from ESPN.
 */
async function fetchStandings() {
  const data = await fetchJSON(`${ESPN_BASE}/standings`);
  const conferences = [];

  for (const conf of (data.children || [])) {
    const confName = conf.name || '';
    const teams = [];

    for (const entry of (conf.standings?.entries || [])) {
      const team = entry.team || {};
      const stats = {};
      for (const s of (entry.stats || [])) {
        stats[s.name] = s.value;
      }

      teams.push({
        team_name:     team.displayName || '',
        abbreviation:  team.abbreviation || '',
        wins:          stats.wins          ?? stats.W          ?? 0,
        losses:        stats.losses        ?? stats.L          ?? 0,
        win_pct:       Math.round((stats.winPercent ?? 0) * 1000) / 1000,
        games_back:    stats.gamesBehind   ?? stats.GB         ?? 0,
        home_record:   stats.Home          ?? '',
        away_record:   stats.Road          ?? stats.Away       ?? '',
        last_10:       stats['Last Ten']   ?? stats.L10        ?? '',
        streak:        stats.streak        ?? stats.strk       ?? '',
        conf_rank:     teams.length + 1,
      });
    }

    conferences.push({ conference: confName, teams });
  }

  return {
    generated_at: new Date().toISOString(),
    last_updated: new Date().toLocaleString('en-US', { timeZone: 'America/New_York' }) + ' ET',
    season: new Date().getFullYear(),
    conferences,
  };
}

/**
 * Fetch recent game results (last `days` days) and build a per-team
 * "last 5 results" summary.
 */
async function fetchRecentResults(days = 7) {
  const teamResults = {}; // teamName → array of results

  for (let i = 1; i <= days; i++) {
    const ds = dateString(i);
    let data;
    try {
      data = await fetchJSON(`${ESPN_BASE}/scoreboard?dates=${ds}`);
    } catch (_) {
      continue;
    }

    for (const event of (data.events || [])) {
      const competition = event.competitions?.[0];
      if (!competition) continue;
      const statusDesc = event.status?.type?.description || '';
      if (statusDesc.toLowerCase() !== 'final') continue;

      const competitors = competition.competitors || [];
      if (competitors.length < 2) continue;

      let home = null, away = null;
      for (const c of competitors) {
        const obj = {
          name:  c.team?.displayName || '',
          score: parseInt(c.score || 0, 10),
          winner: c.winner === true,
        };
        if (c.homeAway === 'home') home = obj;
        else away = obj;
      }
      if (!home || !away) continue;

      const gameDate = event.date ? event.date.slice(0, 10) : '';

      const homeEntry = {
        date: gameDate, opponent: away.name, location: 'home',
        team_score: home.score, opp_score: away.score,
        result: home.winner ? 'W' : 'L',
        label: `${home.winner ? 'W' : 'L'} ${home.score}-${away.score} vs ${away.name}`,
      };
      const awayEntry = {
        date: gameDate, opponent: home.name, location: 'away',
        team_score: away.score, opp_score: home.score,
        result: away.winner ? 'W' : 'L',
        label: `${away.winner ? 'W' : 'L'} ${away.score}-${home.score} @ ${home.name}`,
      };

      if (!teamResults[home.name]) teamResults[home.name] = [];
      if (!teamResults[away.name]) teamResults[away.name] = [];
      teamResults[home.name].unshift(homeEntry);
      teamResults[away.name].unshift(awayEntry);
    }
  }

  // Trim to last 5 per team and compute record
  const teams = [];
  for (const [teamName, results] of Object.entries(teamResults)) {
    const last5 = results.slice(0, 5);
    const wins  = last5.filter(r => r.result === 'W').length;
    teams.push({
      team_name: teamName,
      last_5_record: `${wins}-${last5.length - wins}`,
      games: last5,
    });
  }

  return {
    generated_at: new Date().toISOString(),
    last_updated: new Date().toLocaleString('en-US', { timeZone: 'America/New_York' }) + ' ET',
    days_covered: days,
    teams,
  };
}

/**
 * Build season head-to-head records from recent results data.
 * Also searches the last `days` days of scoreboards for H2H.
 */
async function fetchHeadToHead(days = 120) {
  const matchups = {}; // "TeamA vs TeamB" → { teamA wins, teamB wins, games[] }

  for (let i = 1; i <= days; i++) {
    const ds = dateString(i);
    let data;
    try {
      data = await fetchJSON(`${ESPN_BASE}/scoreboard?dates=${ds}`);
    } catch (_) {
      continue;
    }

    for (const event of (data.events || [])) {
      const competition = event.competitions?.[0];
      if (!competition) continue;
      const statusDesc = event.status?.type?.description || '';
      if (statusDesc.toLowerCase() !== 'final') continue;

      const competitors = competition.competitors || [];
      if (competitors.length < 2) continue;

      let home = null, away = null;
      for (const c of competitors) {
        if (c.homeAway === 'home') home = { name: c.team?.displayName || '', score: parseInt(c.score || 0, 10), winner: c.winner === true };
        else away = { name: c.team?.displayName || '', score: parseInt(c.score || 0, 10), winner: c.winner === true };
      }
      if (!home || !away) continue;

      // Canonical key — alphabetical so lookups are consistent
      const [teamA, teamB] = [home.name, away.name].sort();
      const key = `${teamA} vs ${teamB}`;
      if (!matchups[key]) matchups[key] = { team_a: teamA, team_b: teamB, team_a_wins: 0, team_b_wins: 0, games: [] };

      const winner = home.winner ? home.name : away.name;
      if (winner === teamA) matchups[key].team_a_wins++;
      else matchups[key].team_b_wins++;

      matchups[key].games.push({
        date:  event.date?.slice(0, 10) || '',
        home:  home.name, away: away.name,
        score: `${home.score}-${away.score}`,
        winner,
      });
    }
  }

  return {
    generated_at: new Date().toISOString(),
    last_updated: new Date().toLocaleString('en-US', { timeZone: 'America/New_York' }) + ' ET',
    days_covered: days,
    matchups: Object.values(matchups),
  };
}

/**
 * Fetch today's predictions from the Render API, enriched with injury data.
 * Falls back to an empty list if the API is unreachable.
 */
async function fetchTodayPredictions(injuryLookup) {
  let apiGames = [];
  try {
    const data = await fetchJSON(`${RENDER_API_URL}/predict/today`, 20000);
    apiGames = data.games || [];
  } catch (err) {
    console.warn(`⚠ Could not reach Render API (${err.message}). Predictions will be empty.`);
  }

  const games = apiGames.map(game => {
    const ctx = game.context || {};
    const pred = game.prediction || {};

    // Enrich with injury data from our ESPN fetch
    const homeInj = injuryLookup[(game.home_team || '').toLowerCase()];
    const awayInj = injuryLookup[(game.away_team || '').toLowerCase()];

    const homeInjuries = homeInj?.injuries.map(i => `${i.player_name} (${i.status})`) || ctx.home_injuries || [];
    const awayInjuries = awayInj?.injuries.map(i => `${i.player_name} (${i.status})`) || ctx.away_injuries || [];
    const homeSeverity = homeInj?.severity_score ?? 0;
    const awaySeverity = awayInj?.severity_score ?? 0;

    // Market vs model divergence
    const modelProb   = pred.home_win_prob ?? 0.5;
    const marketProb  = ctx.market_prob_home ?? null;
    const divergence  = marketProb !== null
      ? Math.round(Math.abs(modelProb - marketProb) * 100) / 100
      : null;

    return {
      game_date:    game.game_date,
      game_time:    game.game_time,
      home_team:    game.home_team,
      away_team:    game.away_team,
      home_team_id: game.home_team_id,
      away_team_id: game.away_team_id,
      prediction: {
        home_win_prob:  pred.home_win_prob,
        away_win_prob:  pred.away_win_prob,
        confidence:     pred.confidence,
        favored:        pred.favored,
      },
      context: {
        home_elo:        ctx.home_elo,
        away_elo:        ctx.away_elo,
        home_recent_wins: ctx.home_recent_wins,
        away_recent_wins: ctx.away_recent_wins,
        home_rest_days:  ctx.home_rest_days,
        away_rest_days:  ctx.away_rest_days,
        home_b2b:        ctx.home_b2b,
        away_b2b:        ctx.away_b2b,
      },
      injuries: {
        home:             homeInjuries,
        away:             awayInjuries,
        home_severity:    homeSeverity,
        away_severity:    awaySeverity,
        advantage:        homeSeverity > awaySeverity ? 'away'
                        : awaySeverity > homeSeverity ? 'home' : 'even',
      },
      market_vs_model: {
        model_prob_home:  modelProb,
        market_prob_home: marketProb,
        divergence,
        note: divergence !== null && divergence > 0.05
          ? `Model and market disagree by ${Math.round(divergence * 100)}%`
          : 'Model and market roughly agree',
      },
    };
  });

  return {
    generated_at: new Date().toISOString(),
    last_updated: new Date().toLocaleString('en-US', { timeZone: 'America/New_York' }) + ' ET',
    date: isoToday(),
    count: games.length,
    games,
  };
}

/**
 * Generate the model context document (v3).
 */
function buildModelContext() {
  return {
    generated_at: new Date().toISOString(),
    model_name: 'NBA Game Prediction Model v3',
    model_type: 'XGBoost with Probability Calibration',
    model_file: 'xgb_v3_with_injuries.json',
    description: 'XGBoost model trained on NBA games from 2004–2022 with 31 features including injury columns.',

    features_used: {
      elo_ratings: {
        description: 'Team strength ratings based on historical performance (Elo system). Adjusted downward before prediction when players are injured.',
        features: ['elo_home', 'elo_away', 'elo_diff', 'elo_prob'],
        typical_range: '1200–1650 (higher = stronger)',
      },
      rolling_stats: {
        description: 'Team performance metrics averaged over last 10 games (shifted so they are pre-game).',
        features: ['win_roll_home/away', 'margin_roll_home/away', 'pf_roll_home/away', 'pa_roll_home/away'],
      },
      rest_factors: {
        description: 'Days since last game and back-to-back indicators.',
        features: ['home_rest_days', 'away_rest_days', 'home_b2b', 'away_b2b', 'rest_diff'],
        impact: 'Back-to-back teams typically see 2–5% decrease in win probability.',
      },
      betting_markets: {
        description: 'Implied win probability from the betting market (when available).',
        features: ['market_prob_home', 'market_prob_away'],
        note: 'Markets often price in late-breaking injury news quickly.',
      },
      injury_features: {
        description: 'Explicit injury features added in v3. For historical training rows these are 0; at inference time they are populated from the live ESPN injury API.',
        features: [
          'home_players_out    — number of home players ruled out',
          'away_players_out    — number of away players ruled out',
          'home_players_questionable — number of questionable home players',
          'away_players_questionable — number of questionable away players',
          'home_injury_severity — weighted severity score (Out=1.0, Doubtful=0.75, Questionable=0.5)',
          'away_injury_severity — weighted severity score',
        ],
        how_elo_is_also_adjusted: 'On top of the explicit feature columns, Elo ratings are adjusted before prediction. Example: LeBron James (Out) = -50 Elo for the Lakers. This double-encodes injury signal for robustness.',
      },
    },

    output: {
      home_win_probability: 'Probability that home team wins (0.0–1.0, calibrated)',
      away_win_probability: '1 minus home win probability',
      confidence_tier: 'Human-readable confidence bucket',
    },

    confidence_tiers: {
      'Heavy Favorite':    '> 75% win probability',
      'Moderate Favorite': '65–75%',
      'Lean Favorite':     '60–65%',
      'Toss-Up':           '45–55%',
      'Lean Underdog':     '40–45%',
      'Moderate Underdog': '35–40%',
      'Heavy Underdog':    '< 35%',
    },

    important_notes: {
      injury_double_encoding: 'Injuries are reflected both as explicit feature columns AND as Elo adjustments. This means an injury report will affect the prediction even before the model sees it as a column value.',
      market_incorporation: 'When betting odds are available they are included as features. Markets often react within minutes to injury news.',
      calibration: 'Probabilities are isotonically calibrated — a 70% prediction should win ~70% of the time over a large sample.',
      model_limitations: {
        no_lineups: 'Model does not know confirmed starting lineups until tip-off.',
        training_injury_zeros: 'Injury feature columns were zero in all training rows (no historical data). The model learns from Elo and rolling stats for injury impact during training; injury columns only supplement at inference time.',
        lag_on_trades: 'Major roster moves take 5–10 games to be fully reflected in Elo.',
        situational_context: 'No awareness of playoff seeding races, load management, or tanking strategies.',
      },
    },

    interpretation_guide: {
      injury_impact: {
        all_star_out: 'Typically −40 to −60 Elo → 5–15% shift in win probability',
        starter_out: 'Typically −20 to −30 Elo → 2–5% shift',
        bench_player: 'Minimal, usually < 2%',
        multiple_starters_out: 'Can compound to 15–25% shift',
      },
      back_to_backs: '2–5% decrease in win probability for the tired team.',
      home_court: 'Built into historical Elo and rolling stats; ~2–3% average advantage.',
      market_vs_model: 'Large divergence (> 5%) usually means: late injury news, sharp-money information, or a genuine model edge.',
    },
  };
}

// =============================================================================
// refreshDailyContext — Scheduled Cloud Function
// =============================================================================

/**
 * Runs daily at 9 AM Eastern Time (14:00 UTC).
 * Fetches all data from ESPN + Render API, builds JSON context files,
 * and uploads them to GCS for the Vertex AI agent data store.
 *
 * Files written to gs://nba-prediction-data-metadata/ai_context/:
 *   - daily_predictions.json   (injury-enriched, with market divergence)
 *   - injury_report.json
 *   - standings.json
 *   - recent_results.json
 *   - head_to_head.json
 *   - model_context.json
 */
exports.refreshDailyContext = functions
  .region(REGION)
  .pubsub
  .schedule('0 14 * * *')   // 9 AM ET (UTC-5 winter / UTC-4 summer — 14:00 UTC is safe)
  .timeZone('America/New_York')
  .onRun(async (_context) => {
    console.log('=== refreshDailyContext started ===');

    try {
      // Step 1: Injuries (used both as standalone file and to enrich predictions)
      console.log('[1/6] Fetching injury report...');
      const injuryReport = await fetchInjuryReport();
      const injuryLookup = buildInjuryLookup(injuryReport);
      await uploadToGCS('injury_report.json', injuryReport);

      // Step 2: Standings
      console.log('[2/6] Fetching standings...');
      const standings = await fetchStandings();
      await uploadToGCS('standings.json', standings);

      // Step 3: Recent results (last 7 days)
      console.log('[3/6] Fetching recent results (last 7 days)...');
      const recentResults = await fetchRecentResults(7);
      await uploadToGCS('recent_results.json', recentResults);

      // Step 4: Head-to-head (season — last 120 days)
      console.log('[4/6] Fetching head-to-head records (last 120 days)...');
      const headToHead = await fetchHeadToHead(120);
      await uploadToGCS('head_to_head.json', headToHead);

      // Step 5: Today's predictions (injury-enriched + market divergence)
      console.log('[5/6] Fetching today\'s predictions from Render API...');
      const predictions = await fetchTodayPredictions(injuryLookup);
      await uploadToGCS('daily_predictions.json', predictions);

      // Step 6: Model context (static but versioned — update when model changes)
      console.log('[6/6] Writing model context (v3)...');
      await uploadToGCS('model_context.json', buildModelContext());

      console.log('=== refreshDailyContext complete ===');
      console.log(`Uploaded 6 files to gs://${GCS_BUCKET}/ai_context/`);

    } catch (err) {
      console.error('refreshDailyContext failed:', err);
      throw err;  // Re-throw so Cloud Functions marks the execution as failed
    }

    return null;
  });

// =============================================================================
// chatWithAgent — HTTP Cloud Function
// =============================================================================

/**
 * Proxy requests to the Dialogflow CX / Vertex AI agent.
 * Requires Firebase Authentication.
 * 
 * Accepts expanded gameContext:
 * {
 *   "message": "...",
 *   "sessionId": "optional",
 *   "gameContext": {
 *     "homeTeam":        "Los Angeles Lakers",
 *     "awayTeam":        "Boston Celtics",
 *     "homeElo":         1580,
 *     "awayElo":         1620,
 *     "homeWinProb":     0.46,
 *     "confidenceTier":  "Toss-Up",
 *     "homeInjuries":    ["LeBron James (Questionable)", "AD (Out)"],
 *     "awayInjuries":    [],
 *     "injuryAdvantage": "away",
 *     "homeRestDays":    2,
 *     "awayRestDays":    1,
 *     "homeB2b":         false,
 *     "awayB2b":         true,
 *     "marketProbHome":  0.52,
 *     "homeRecentWins":  0.4,
 *     "awayRecentWins":  0.6
 *   }
 * }
 */
exports.chatWithAgent = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to chat with the AI assistant.'
    );
  }

  const { message, sessionId, gameContext } = data;

  if (!message || typeof message !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Message is required and must be a string.'
    );
  }

  // ── Daily chat rate limit ──────────────────────────────────────────────────
  const uid   = context.auth.uid;
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
  const usageRef = db.ref(`usage/${uid}/${today}`);

  // Read current count
  const usageSnap   = await usageRef.once('value');
  const currentCount = (usageSnap.val() || 0);

  if (currentCount >= DAILY_FREE_CHAT_LIMIT) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `You've used all ${DAILY_FREE_CHAT_LIMIT} free AI chats for today. Upgrade to Pro for unlimited access.`,
      {
        chatsUsedToday: currentCount,
        chatsRemaining: 0,
        limit: DAILY_FREE_CHAT_LIMIT,
      }
    );
  }

  // Increment atomically (create or increment)
  await usageRef.transaction((current) => (current || 0) + 1);
  const newCount       = currentCount + 1;
  const chatsRemaining = DAILY_FREE_CHAT_LIMIT - newCount;
  // ── End rate limit ──────────────────────────────────────────────────────────

  const finalSessionId = sessionId || `user-${uid}-${Date.now()}`;

  const sessionPath = sessionsClient.projectLocationAgentSessionPath(
    AGENT_CONFIG.projectId,
    AGENT_CONFIG.location,
    AGENT_CONFIG.agentId,
    finalSessionId
  );

  // Build rich context block when game data is available
  let fullMessage = message;
  if (gameContext) {
    const homeWinPct = ((gameContext.homeWinProb || 0.5) * 100).toFixed(1);
    const awayWinPct = (100 - parseFloat(homeWinPct)).toFixed(1);

    // Injury section
    const homeInjLines = (gameContext.homeInjuries || []).length > 0
      ? gameContext.homeInjuries.join(', ')
      : 'None reported';
    const awayInjLines = (gameContext.awayInjuries || []).length > 0
      ? gameContext.awayInjuries.join(', ')
      : 'None reported';
    const injAdvantage = gameContext.injuryAdvantage === 'home'
      ? `${gameContext.homeTeam} (away team more injured)`
      : gameContext.injuryAdvantage === 'away'
        ? `${gameContext.awayTeam} (home team more injured)`
        : 'Even (both teams similarly healthy)';

    // Rest section
    const homeRestNote = gameContext.homeB2b ? ' (BACK-TO-BACK)' : '';
    const awayRestNote = gameContext.awayB2b ? ' (BACK-TO-BACK)' : '';

    // Market vs model
    let marketNote = '';
    if (gameContext.marketProbHome != null) {
      const diff = Math.abs(gameContext.homeWinProb - gameContext.marketProbHome);
      const modelHigher = gameContext.homeWinProb > gameContext.marketProbHome;
      if (diff > 0.04) {
        marketNote = `\n- Market implies ${(gameContext.marketProbHome * 100).toFixed(1)}% for ${gameContext.homeTeam} — model is ${diff > 0 && modelHigher ? 'HIGHER' : 'LOWER'} by ${(diff * 100).toFixed(1)}% (possible late injury news or sharp-money signal)`;
      } else {
        marketNote = `\n- Market implies ${(gameContext.marketProbHome * 100).toFixed(1)}% — model and market roughly agree`;
      }
    }

    fullMessage = `[GAME CONTEXT]
Home: ${gameContext.homeTeam} | Away: ${gameContext.awayTeam}

MODEL PREDICTION:
- ${gameContext.homeTeam} win probability: ${homeWinPct}%
- ${gameContext.awayTeam} win probability: ${awayWinPct}%
- Confidence tier: ${gameContext.confidenceTier || 'Moderate'}${marketNote}

ELO RATINGS:
- ${gameContext.homeTeam}: ${gameContext.homeElo || 1500} Elo
- ${gameContext.awayTeam}: ${gameContext.awayElo || 1500} Elo

RECENT FORM (last 10 games):
- ${gameContext.homeTeam}: ${Math.round((gameContext.homeRecentWins || 0.5) * 10)}/10 wins
- ${gameContext.awayTeam}: ${Math.round((gameContext.awayRecentWins || 0.5) * 10)}/10 wins

REST / FATIGUE:
- ${gameContext.homeTeam}: ${gameContext.homeRestDays ?? '?'} days rest${homeRestNote}
- ${gameContext.awayTeam}: ${gameContext.awayRestDays ?? '?'} days rest${awayRestNote}

INJURY REPORT:
- ${gameContext.homeTeam}: ${homeInjLines}
- ${gameContext.awayTeam}: ${awayInjLines}
- Health advantage: ${injAdvantage}

[USER QUESTION]
${message}`;
  }

  try {
    const request = {
      session: sessionPath,
      queryInput: {
        text: { text: fullMessage },
        languageCode: AGENT_CONFIG.languageCode,
      },
    };

    const [response] = await sessionsClient.detectIntent(request);
    const responseMessages = response.queryResult.responseMessages || [];
    let agentResponse = '';
    
    for (const msg of responseMessages) {
      if (msg.text && msg.text.text) {
        agentResponse += msg.text.text.join('\n');
      }
    }

    return {
      success: true,
      response: agentResponse || 'I could not generate a response. Please try again.',
      sessionId: finalSessionId,
      confidence: response.queryResult.intentDetectionConfidence,
      chatsUsedToday: newCount,
      chatsRemaining,
      limit: DAILY_FREE_CHAT_LIMIT,
    };

  } catch (error) {
    console.error('Dialogflow CX error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get response from AI assistant. Please try again.'
    );
  }
});

// =============================================================================
// cleanupOldForumMessages — Scheduled (unchanged)
// =============================================================================

exports.cleanupOldForumMessages = functions
  .region(REGION)
  .pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async (_context) => {
    const cutoffTime = Date.now() - (24 * 60 * 60 * 1000);
    console.log(`Forum cleanup: deleting messages older than ${new Date(cutoffTime).toISOString()}`);
    
    const messagesRef = db.ref('forums/general/messages');
    
    try {
      const snapshot = await messagesRef
        .orderByChild('timestamp')
        .endAt(cutoffTime)
        .once('value');
      
      if (!snapshot.exists()) {
        console.log('No old messages to delete.');
        return null;
      }
      
      const updates = {};
      let deleteCount = 0;
      snapshot.forEach((child) => {
        updates[child.key] = null;
        deleteCount++;
      });
      
      await messagesRef.update(updates);
      console.log(`Deleted ${deleteCount} old forum messages.`);
      return null;
      
    } catch (error) {
      console.error('Error cleaning up forum messages:', error);
      throw error;
    }
  });
