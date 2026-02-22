"""
Generate context files for Vertex AI Agent.

This script generates JSON files with current NBA data that can be uploaded
to Google Cloud Storage and used as grounding data for Vertex AI agents.

Generates (7 files):
  injury_report.json        — live ESPN injury data per team
  team_info.json            — current Elo ratings + rolling stats
  standings.json            — current NBA standings (ESPN)
  recent_results.json       — last-7-days game results per team
  head_to_head.json         — season H2H records for every matchup
  daily_predictions.json    — today's predictions (injury-enriched, market divergence)
  model_context.json        — v3 model documentation

Usage:
    # From WSL project root:
    python src/generate_ai_context.py --output-dir ai_context/
    python src/generate_ai_context.py --output-dir ai_context/ --upload-to-gcs
"""

import argparse
import json
import shutil
from datetime import datetime, date, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import requests

from core import (
    TeamMapper,
    StateManager,
    InjuryClient,
)
from core.injury_client import calculate_injury_adjustment


# ---------------------------------------------------------------------------
# ESPN helpers
# ---------------------------------------------------------------------------

ESPN_BASE = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba"
_SESSION = requests.Session()
_SESSION.headers.update({"Accept": "application/json", "User-Agent": "NBA-Predictor/1.0"})


def _get(url: str, timeout: int = 12) -> dict:
    """Fetch JSON from ESPN with a reasonable timeout."""
    resp = _SESSION.get(url, timeout=timeout)
    resp.raise_for_status()
    return resp.json()


def _date_str(days_ago: int = 0) -> str:
    """Return YYYYMMDD string offset from today."""
    d = date.today() - timedelta(days=days_ago)
    return d.strftime("%Y%m%d")


# ---------------------------------------------------------------------------
# 1. Injury Report
# ---------------------------------------------------------------------------

def generate_injury_report(
    injury_client: InjuryClient,
    output_path: Optional[Path] = None,
) -> Dict:
    """
    Generate comprehensive injury report for all teams.

    Args:
        injury_client: InjuryClient instance
        output_path: If provided, save to this JSON file

    Returns:
        Dictionary with injury report data
    """
    print("Fetching current injury data from ESPN...")
    reports = injury_client.get_all_injuries()

    injury_data = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S ET"),
        "league": "NBA",
        "total_teams": len(reports),
        "teams": [],
    }

    for team_id, report in sorted(reports.items(), key=lambda x: x[1].team_name):
        adjustment = calculate_injury_adjustment(report, debug=False)

        team_data = {
            "team_id": team_id,
            "team_name": report.team_name,
            "injury_count": len(report.injuries),
            "players_out": len(report.players_out),
            "players_questionable": len(report.players_questionable),
            "severity_score": round(report.total_severity, 2),
            "has_significant_injuries": report.has_significant_injuries,
            "elo_adjustment": round(adjustment, 1),
            "injuries": [],
        }

        for injury in report.injuries:
            team_data["injuries"].append({
                "player_name": injury.player_name,
                "player_id": injury.player_id,
                "status": injury.status,
                "injury_type": injury.injury_type,
                "details": injury.details,
                "severity_score": injury.severity_score,
            })

        injury_data["teams"].append(team_data)

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(injury_data, f, indent=2)
        print(f"✓ Saved injury report to {output_path}")

    return injury_data


# ---------------------------------------------------------------------------
# 2. Team Info (Elo + rolling stats)
# ---------------------------------------------------------------------------

def generate_team_info(
    team_mapper: TeamMapper,
    state_manager: StateManager,
    output_path: Optional[Path] = None,
) -> Dict:
    """
    Generate team information with current Elo ratings and rolling stats.
    """
    print("Loading team data and Elo ratings...")
    elo_tracker, stats_tracker = state_manager.load()

    team_data = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S ET"),
        "league": "NBA",
        "teams": [],
    }

    team_ids = team_mapper.get_all_team_ids()

    for team_id in sorted(team_ids, key=lambda tid: team_mapper.get_team_name(tid) or ''):
        team_name = team_mapper.get_team_name(team_id) or str(team_id)
        elo   = elo_tracker.get_elo(team_id)
        stats = stats_tracker.get_rolling_stats(team_id)

        team_data["teams"].append({
            "team_id": team_id,
            "team_name": team_name,
            "current_elo": round(elo, 1),
            "recent_win_pct": round(stats.get("win_roll", 0.5), 3),
            "recent_margin": round(stats.get("margin_roll", 0.0), 1),
            "recent_pts_for": round(stats.get("pf_roll", 0.0), 1),
            "recent_pts_against": round(stats.get("pa_roll", 0.0), 1),
        })

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(team_data, f, indent=2)
        print(f"✓ Saved team info to {output_path}")

    return team_data


# ---------------------------------------------------------------------------
# 3. Standings
# ---------------------------------------------------------------------------

def generate_standings(output_path: Optional[Path] = None) -> Dict:
    """
    Fetch current NBA standings from ESPN and structure them.
    """
    print("Fetching NBA standings from ESPN...")
    data = _get(f"{ESPN_BASE}/standings")

    standings = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S ET"),
        "season": date.today().year,
        "conferences": [],
    }

    for conf in data.get("children", []):
        conf_name = conf.get("name", "")
        teams = []

        for rank, entry in enumerate(conf.get("standings", {}).get("entries", []), start=1):
            team  = entry.get("team", {})
            stats = {s["name"]: s["value"] for s in entry.get("stats", [])}

            teams.append({
                "conf_rank":   rank,
                "team_name":   team.get("displayName", ""),
                "abbreviation": team.get("abbreviation", ""),
                "wins":        int(stats.get("wins", stats.get("W", 0))),
                "losses":      int(stats.get("losses", stats.get("L", 0))),
                "win_pct":     round(float(stats.get("winPercent", 0)), 3),
                "games_back":  float(stats.get("gamesBehind", stats.get("GB", 0))),
                "home_record": stats.get("Home", ""),
                "away_record": stats.get("Road", stats.get("Away", "")),
                "last_10":     stats.get("Last Ten", stats.get("L10", "")),
                "streak":      stats.get("streak", stats.get("strk", "")),
            })

        standings["conferences"].append({"conference": conf_name, "teams": teams})

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(standings, f, indent=2)
        print(f"✓ Saved standings to {output_path}")

    return standings


# ---------------------------------------------------------------------------
# 4. Recent Results
# ---------------------------------------------------------------------------

def generate_recent_results(days: int = 7, output_path: Optional[Path] = None) -> Dict:
    """
    Fetch game results from the past `days` days and build per-team last-5 summaries.
    """
    print(f"Fetching recent results (last {days} days) from ESPN...")
    team_results: Dict[str, List[dict]] = {}

    for i in range(1, days + 1):
        ds = _date_str(i)
        try:
            data = _get(f"{ESPN_BASE}/scoreboard?dates={ds}")
        except Exception:
            continue

        for event in data.get("events", []):
            comp       = (event.get("competitions") or [{}])[0]
            status_desc = event.get("status", {}).get("type", {}).get("description", "")
            if status_desc.lower() != "final":
                continue

            competitors = comp.get("competitors", [])
            if len(competitors) < 2:
                continue

            home = away = None
            for c in competitors:
                obj = {
                    "name":   c.get("team", {}).get("displayName", ""),
                    "score":  int(c.get("score", 0) or 0),
                    "winner": c.get("winner", False),
                }
                if c.get("homeAway") == "home":
                    home = obj
                else:
                    away = obj

            if not home or not away:
                continue

            game_date = event.get("date", "")[:10]

            home_entry = {
                "date": game_date, "opponent": away["name"], "location": "home",
                "team_score": home["score"], "opp_score": away["score"],
                "result": "W" if home["winner"] else "L",
                "label": f"{'W' if home['winner'] else 'L'} {home['score']}-{away['score']} vs {away['name']}",
            }
            away_entry = {
                "date": game_date, "opponent": home["name"], "location": "away",
                "team_score": away["score"], "opp_score": home["score"],
                "result": "W" if away["winner"] else "L",
                "label": f"{'W' if away['winner'] else 'L'} {away['score']}-{home['score']} @ {home['name']}",
            }

            team_results.setdefault(home["name"], []).insert(0, home_entry)
            team_results.setdefault(away["name"], []).insert(0, away_entry)

    teams_out = []
    for team_name, results in sorted(team_results.items()):
        last5 = results[:5]
        wins  = sum(1 for r in last5 if r["result"] == "W")
        teams_out.append({
            "team_name":    team_name,
            "last_5_record": f"{wins}-{len(last5) - wins}",
            "games":        last5,
        })

    result = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S ET"),
        "days_covered": days,
        "teams":        teams_out,
    }

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
        print(f"✓ Saved recent results to {output_path}")

    return result


# ---------------------------------------------------------------------------
# 5. Head-to-Head Records
# ---------------------------------------------------------------------------

def generate_head_to_head(days: int = 120, output_path: Optional[Path] = None) -> Dict:
    """
    Build season head-to-head records by scanning the last `days` days of scoreboards.
    """
    print(f"Building head-to-head records (last {days} days from ESPN)...")
    matchups: Dict[str, dict] = {}

    for i in range(1, days + 1):
        ds = _date_str(i)
        try:
            data = _get(f"{ESPN_BASE}/scoreboard?dates={ds}")
        except Exception:
            continue

        for event in data.get("events", []):
            comp       = (event.get("competitions") or [{}])[0]
            status_desc = event.get("status", {}).get("type", {}).get("description", "")
            if status_desc.lower() != "final":
                continue

            competitors = comp.get("competitors", [])
            if len(competitors) < 2:
                continue

            home = away = None
            for c in competitors:
                obj = {"name": c.get("team", {}).get("displayName", ""), "score": int(c.get("score", 0) or 0), "winner": c.get("winner", False)}
                if c.get("homeAway") == "home":
                    home = obj
                else:
                    away = obj

            if not home or not away:
                continue

            team_a, team_b = sorted([home["name"], away["name"]])
            key = f"{team_a} vs {team_b}"
            if key not in matchups:
                matchups[key] = {"team_a": team_a, "team_b": team_b, "team_a_wins": 0, "team_b_wins": 0, "games": []}

            winner = home["name"] if home["winner"] else away["name"]
            if winner == team_a:
                matchups[key]["team_a_wins"] += 1
            else:
                matchups[key]["team_b_wins"] += 1

            matchups[key]["games"].append({
                "date":   event.get("date", "")[:10],
                "home":   home["name"],
                "away":   away["name"],
                "score":  f"{home['score']}-{away['score']}",
                "winner": winner,
            })

    result = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S ET"),
        "days_covered": days,
        "matchups":     list(matchups.values()),
    }

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
        print(f"✓ Saved head-to-head records to {output_path}")

    return result


# ---------------------------------------------------------------------------
# 6. Daily Predictions (injury-enriched + market divergence)
# ---------------------------------------------------------------------------

def _build_injury_lookup(injury_report: Dict) -> Dict[str, dict]:
    """Build a lowercase-name → team-injury-info lookup."""
    return {t["team_name"].lower(): t for t in injury_report.get("teams", [])}


def generate_daily_predictions(
    injury_report: Dict,
    project_root: Path,
    output_path: Optional[Path] = None,
) -> Dict:
    """
    Load today's raw predictions from predictions/daily.json and enrich them
    with live injury data and market-vs-model divergence.
    """
    daily_pred_path = project_root / "predictions" / "daily.json"
    if not daily_pred_path.exists():
        print("⚠  predictions/daily.json not found — skipping daily_predictions.json")
        return {}

    print("Enriching daily predictions with injury data and market divergence...")
    with open(daily_pred_path, encoding="utf-8") as f:
        raw = json.load(f)

    injury_lookup = _build_injury_lookup(injury_report)
    games_out = []

    for game in raw.get("games", []):
        ctx  = game.get("context") or {}
        pred = game.get("prediction") or {}

        home_name = game.get("home_team", "")
        away_name = game.get("away_team", "")

        home_inj = injury_lookup.get(home_name.lower(), {})
        away_inj = injury_lookup.get(away_name.lower(), {})

        home_injuries = [i["player_name"] + f" ({i['status']})" for i in home_inj.get("injuries", [])] \
                        or ctx.get("home_injuries", [])
        away_injuries = [i["player_name"] + f" ({i['status']})" for i in away_inj.get("injuries", [])] \
                        or ctx.get("away_injuries", [])

        home_severity = home_inj.get("severity_score", 0.0)
        away_severity = away_inj.get("severity_score", 0.0)

        model_prob   = pred.get("home_win_prob", 0.5)
        market_prob  = ctx.get("market_prob_home")
        divergence   = round(abs(model_prob - market_prob), 4) if market_prob is not None else None
        divergence_pct = round(divergence * 100, 1) if divergence is not None else None

        games_out.append({
            "game_date":    game.get("game_date"),
            "game_time":    game.get("game_time"),
            "home_team":    home_name,
            "away_team":    away_name,
            "home_team_id": game.get("home_team_id"),
            "away_team_id": game.get("away_team_id"),
            "prediction": {
                "home_win_prob":         pred.get("home_win_prob"),
                "away_win_prob":         pred.get("away_win_prob"),
                "confidence":            pred.get("confidence"),
                "favored":               "home" if (pred.get("home_win_prob") or 0) > 0.5 else "away",
                "confidence_score":      pred.get("confidence_score"),
                "confidence_qualifier":  pred.get("confidence_qualifier"),
            },
            "context": {
                "home_elo":         ctx.get("home_elo"),
                "away_elo":         ctx.get("away_elo"),
                "home_recent_wins": ctx.get("home_recent_wins"),
                "away_recent_wins": ctx.get("away_recent_wins"),
                "home_rest_days":   ctx.get("home_rest_days"),
                "away_rest_days":   ctx.get("away_rest_days"),
                "home_b2b":         ctx.get("home_b2b"),
                "away_b2b":         ctx.get("away_b2b"),
            },
            "injuries": {
                "home":           home_injuries,
                "away":           away_injuries,
                "home_severity":  home_severity,
                "away_severity":  away_severity,
                "home_elo_adj":   home_inj.get("elo_adjustment", 0.0),
                "away_elo_adj":   away_inj.get("elo_adjustment", 0.0),
                "advantage":      "away" if home_severity > away_severity
                                  else ("home" if away_severity > home_severity else "even"),
            },
            "market_vs_model": {
                "model_prob_home":  model_prob,
                "market_prob_home": market_prob,
                "divergence":       divergence,
                "divergence_pct":   divergence_pct,
                "note": (
                    f"Model and market disagree by {divergence_pct}% — "
                    "possible late injury news or sharp-money signal"
                    if divergence_pct and divergence_pct > 5
                    else "Model and market roughly agree"
                ),
            },
        })

    result = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S ET"),
        "date":  date.today().isoformat(),
        "count": len(games_out),
        "games": games_out,
    }

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
        print(f"✓ Saved enriched daily predictions to {output_path}")

    return result


# ---------------------------------------------------------------------------
# 7. Model Context (v3 — 31 features with injuries)
# ---------------------------------------------------------------------------

def generate_model_context(output_path: Optional[Path] = None) -> Dict:
    """
    Generate context document explaining how the v3 prediction model works.
    """
    print("Generating model context documentation (v3)...")

    context = {
        "generated_at":  datetime.now().isoformat(),
        "model_name":    "NBA Game Prediction Model v3",
        "model_type":    "XGBoost with Logistic Regression Calibration",
        "model_file":    "xgb_v3_with_injuries.json",
        "calibrator_file": "calibrator_v3.pkl",
        "description":   (
            "XGBoost model trained on NBA games from 2004–2022. "
            "Expanded from 25 to 31 features in v3 by adding explicit injury columns. "
            "Probabilities are isotonically calibrated for accuracy."
        ),

        "features_used": {
            "elo_ratings": {
                "description": (
                    "Team strength ratings derived from the entire NBA historical record. "
                    "Ratings are adjusted downward for injured players before prediction."
                ),
                "features": ["elo_home", "elo_away", "elo_diff", "elo_prob"],
                "typical_range": "1200–1650 (average ~1500; higher = stronger team)",
            },
            "rolling_stats": {
                "description": "Team performance metrics averaged over last 10 games (pre-game window).",
                "features": [
                    "pf_roll_home", "pf_roll_away", "pf_roll_diff",
                    "pa_roll_home", "pa_roll_away", "pa_roll_diff",
                    "win_roll_home", "win_roll_away", "win_roll_diff",
                    "margin_roll_home", "margin_roll_away", "margin_roll_diff",
                ],
            },
            "game_window": {
                "description": "Number of games played in the rolling window (handles early-season small samples).",
                "features": ["games_in_window_home", "games_in_window_away"],
            },
            "rest_factors": {
                "description": "Days since last game and back-to-back indicators.",
                "features": ["home_rest_days", "away_rest_days", "home_b2b", "away_b2b", "rest_diff"],
                "impact": "Back-to-back teams typically see 2–5% decrease in win probability.",
            },
            "betting_markets": {
                "description": (
                    "Implied win probability from the betting market moneyline. "
                    "Markets incorporate late-breaking information (trades, injury news) rapidly."
                ),
                "features": ["market_prob_home", "market_prob_away"],
            },
            "injury_features": {
                "description": (
                    "NEW IN v3 — Explicit injury columns. "
                    "Zero for all historical training rows (no historical injury data). "
                    "Populated from live ESPN API at inference time."
                ),
                "features": [
                    "home_players_out            — integer count of home players ruled out",
                    "away_players_out            — integer count of away players ruled out",
                    "home_players_questionable   — integer count of questionable home players",
                    "away_players_questionable   — integer count of questionable away players",
                    "home_injury_severity        — weighted severity (Out=1.0, Doubtful=0.75, Questionable=0.5, DTD=0.25)",
                    "away_injury_severity        — weighted severity score for away team",
                ],
                "double_encoding_note": (
                    "Injuries are encoded twice for robustness: "
                    "(1) as explicit feature columns above, AND "
                    "(2) as Elo rating adjustments before prediction. "
                    "Example: LeBron James (Out) → Lakers Elo drops ~50 pts → ~8–12% swing in win prob."
                ),
            },
        },

        "total_features": 31,

        "output": {
            "home_win_probability": "Calibrated probability that home team wins (0.0–1.0)",
            "away_win_probability": "1 minus home win probability",
            "confidence_tier":      "Human-readable confidence category",
        },

        "confidence_tiers": {
            "Heavy Favorite":    "> 75% win probability",
            "Moderate Favorite": "65–75%",
            "Lean Favorite":     "60–65%",
            "Toss-Up":           "45–55%",
            "Lean Underdog":     "40–45%",
            "Moderate Underdog": "35–40%",
            "Heavy Underdog":    "< 35%",
        },

        "important_notes": {
            "injury_double_encoding": (
                "Injuries affect predictions in two complementary ways: "
                "feature columns AND Elo adjustments. This means injury information "
                "is reflected even if one channel is unavailable."
            ),
            "training_injury_zeros": (
                "All injury feature columns were 0 in training rows. The model learns "
                "injury impact implicitly through Elo and rolling stats for historical games. "
                "At inference time the columns are populated with live ESPN values, "
                "giving the model an additional explicit signal."
            ),
            "market_incorporation": (
                "When betting odds are available they are included as features. "
                "Markets often price in injuries within minutes of announcement."
            ),
            "calibration": (
                "Isotonic regression calibration is applied — a 70% prediction "
                "should win ~70% of the time over a large sample."
            ),
            "model_limitations": {
                "no_confirmed_lineups": "Model does not see confirmed starting lineups until tip-off.",
                "lag_on_trades": "Major roster moves take 5–10 games to be fully reflected in Elo.",
                "situational_context": "No awareness of playoff seeding urgency, load management, or tanking.",
                "injury_timing": "If a player is ruled out after predictions are generated, the model won't reflect it unless re-run.",
            },
        },

        "interpretation_guide": {
            "injury_impact_examples": {
                "all_star_player_out":       "−40 to −60 Elo → 8–15% win-prob shift",
                "starting_player_out":       "−20 to −30 Elo → 3–7% shift",
                "bench_player_out":          "Minimal, usually < 2%",
                "multiple_starters_out":     "Can compound to 15–25% shift",
                "questionable_player":       "50% weight applied — about half the Out impact",
            },
            "back_to_backs":  "2–5% decrease in win probability for the tired team.",
            "home_court":     "Built into Elo and rolling stats (~2–3% average advantage).",
            "market_vs_model": (
                "Large divergence (> 5%) usually signals: "
                "late injury news the model hasn't seen, "
                "sharp-money information, or a genuine model edge."
            ),
        },
    }

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(context, f, indent=2)
        print(f"✓ Saved model context to {output_path}")

    return context


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

def generate_all_context_files(output_dir: Path) -> None:
    """
    Generate all 7 context files for the Vertex AI agent.
    """
    print(f"\n{'=' * 70}")
    print("  NBA Prediction — AI Context File Generator (v3)")
    print(f"{'=' * 70}\n")

    project_root = Path(__file__).parent.parent
    state_dir    = project_root / "state"

    team_mapper   = TeamMapper()
    state_manager = StateManager(state_dir)
    injury_client = InjuryClient(team_mapper)

    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Injuries (needed first — used by daily predictions enrichment)
    injury_report = generate_injury_report(
        injury_client,
        output_path=output_dir / "injury_report.json",
    )

    # 2. Team info (Elo + rolling stats)
    generate_team_info(
        team_mapper,
        state_manager,
        output_path=output_dir / "team_info.json",
    )

    # 3. Standings
    try:
        generate_standings(output_path=output_dir / "standings.json")
    except Exception as e:
        print(f"⚠  Standings fetch failed: {e}")

    # 4. Recent results (last 7 days)
    try:
        generate_recent_results(days=7, output_path=output_dir / "recent_results.json")
    except Exception as e:
        print(f"⚠  Recent results fetch failed: {e}")

    # 5. Head-to-head (season — last 120 days)
    try:
        generate_head_to_head(days=120, output_path=output_dir / "head_to_head.json")
    except Exception as e:
        print(f"⚠  Head-to-head fetch failed: {e}")

    # 6. Daily predictions (injury-enriched)
    generate_daily_predictions(
        injury_report,
        project_root,
        output_path=output_dir / "daily_predictions.json",
    )

    # 7. Model context
    generate_model_context(output_path=output_dir / "model_context.json")

    print(f"\n{'=' * 70}")
    print(f"  ✓ All context files generated in: {output_dir}")
    print(f"{'=' * 70}\n")

    print("Files created:")
    for file in sorted(output_dir.glob("*.json")):
        size_kb = file.stat().st_size / 1024
        print(f"  - {file.name:35s} ({size_kb:.1f} KB)")

    print("\nNext steps:")
    print("  python src/generate_ai_context.py --upload-to-gcs")
    print("  — or —")
    print("  firebase deploy --only functions   (refreshDailyContext auto-uploads every 9 AM ET)")


# ---------------------------------------------------------------------------
# GCS Upload
# ---------------------------------------------------------------------------

def upload_to_gcs(output_dir: Path, bucket_name: str) -> None:
    """
    Upload all JSON files in output_dir to gs://<bucket_name>/ai_context/.
    """
    try:
        from google.cloud import storage as gcs
    except ImportError:
        print("Error: google-cloud-storage not installed.")
        print("  pip install google-cloud-storage")
        return

    print(f"\nUploading files to gs://{bucket_name}/ai_context/...")
    client = gcs.Client()
    bucket = client.bucket(bucket_name)

    for file in sorted(output_dir.glob("*.json")):
        blob = bucket.blob(f"ai_context/{file.name}")
        blob.upload_from_filename(str(file))
        print(f"  ✓ Uploaded {file.name}")

    print(f"\n✓ All files uploaded to gs://{bucket_name}/ai_context/")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate AI context files for the Vertex AI NBA agent"
    )
    parser.add_argument(
        "--output-dir", type=str, default="ai_context",
        help="Output directory (default: ai_context/)",
    )
    parser.add_argument(
        "--upload-to-gcs", action="store_true",
        help="Upload to GCS after generation",
    )
    parser.add_argument(
        "--bucket", type=str, default="nba-prediction-data-metadata",
        help="GCS bucket name (default: nba-prediction-data-metadata)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)

    generate_all_context_files(output_dir)

    if args.upload_to_gcs:
        upload_to_gcs(output_dir, args.bucket)
    else:
        print(f"\nTo upload to GCS, run:")
        print(f"  python src/generate_ai_context.py --upload-to-gcs")


if __name__ == "__main__":
    main()
