"""
Recruit Radar — Men's College Basketball Transfer Portal Intelligence
Cloud Run Job: scrapes On3 portal list + X (via Nitter), processes with
Gemini Flash Lite, and writes structured entries to Firebase RTDB.

Run schedule: every 30 minutes via Cloud Scheduler.

RTDB structure:
  recruit_radar/
    last_updated: "2026-04-13T12:00:00+00:00"
    entries/
      {player-slug}/
        player_name, school_from, summary, lead_schools[],
        visit_dates[], sentiment_score, source_snippets[], timestamp
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
import sys

# ── Bootstrap path ────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

import requests
from bs4 import BeautifulSoup
from pydantic import BaseModel, Field, field_validator
import firebase_admin
from firebase_admin import credentials, db as rtdb
from google import genai
from google.genai import types as genai_types

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────────────────────
GEMINI_MODEL = "gemini-2.0-flash-lite"
MAX_PLAYERS = int(os.getenv("RADAR_ON3_MAX_PLAYERS", "50"))
NITTER_BASES = [
    os.getenv("RADAR_NITTER_BASE", "https://nitter.privacydev.net"),
    "https://nitter.poast.org",
    "https://nitter.1d4.us",
]
ON3_PORTAL_URL = "https://www.on3.com/transfer-portal/industry/basketball/"
REQUEST_TIMEOUT = 15
DELAY_BETWEEN_PLAYERS = 2.0  # seconds — respect free-tier sources

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# ── Data schema ───────────────────────────────────────────────────────────────

class RadarEntry(BaseModel):
    player_name: str
    school_from: str = ""
    summary: str
    lead_schools: list[str] = Field(default_factory=list)
    visit_dates: list[str] = Field(default_factory=list)
    sentiment_score: float = Field(5.0, ge=1.0, le=10.0)
    source_snippets: list[str] = Field(default_factory=list)
    timestamp: str

    @field_validator("lead_schools")
    @classmethod
    def cap_schools(cls, v: list[str]) -> list[str]:
        return v[:5]

    @field_validator("source_snippets")
    @classmethod
    def cap_snippets(cls, v: list[str]) -> list[str]:
        return [s[:500] for s in v[:5]]

    @field_validator("summary")
    @classmethod
    def cap_summary(cls, v: str) -> str:
        words = v.split()
        return " ".join(words[:20]) if len(words) > 20 else v


# ── Firebase init ─────────────────────────────────────────────────────────────

def _init_firebase() -> None:
    """Initialize Firebase Admin SDK (idempotent)."""
    if firebase_admin._apps:
        return
    db_url = os.getenv("FIREBASE_DATABASE_URL", "")
    if not db_url:
        raise RuntimeError("FIREBASE_DATABASE_URL environment variable is required")
    # On Cloud Run, Application Default Credentials are provided automatically.
    # Locally, set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON.
    cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred, {"databaseURL": db_url})
    log.info("Firebase initialized (database: %s)", db_url)


# ── Gemini client ─────────────────────────────────────────────────────────────

def _get_gemini_client() -> genai.Client:
    """Build Gemini client: API key if set, otherwise Vertex AI ADC."""
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if api_key:
        return genai.Client(api_key=api_key)
    project = os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("GCP_PROJECT")
    location = os.getenv("VERTEX_LOCATION", "us-central1")
    return genai.Client(vertexai=True, project=project, location=location)


# ── On3 portal scraping ───────────────────────────────────────────────────────

def _fetch_html(url: str) -> Optional[BeautifulSoup]:
    """GET a URL and return a BeautifulSoup, or None on failure."""
    try:
        resp = requests.get(url, headers=_HEADERS, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml")
    except requests.RequestException as e:
        log.warning("HTTP error fetching %s: %s", url, e)
        return None


def _is_player_record(obj: dict) -> bool:
    """Return True if a dict looks like a portal player entry."""
    name_keys = {"firstName", "lastName", "name", "athleteName", "fullName", "displayName"}
    school_keys = {"school", "team", "currentTeam", "previousSchool", "fromSchool"}
    has_name = bool(name_keys & obj.keys())
    has_school = bool(school_keys & obj.keys())
    return has_name and has_school


def _extract_name_school(obj: dict) -> tuple[str, str]:
    """Pull player name and school from a player-record dict."""
    name = (
        obj.get("fullName")
        or obj.get("displayName")
        or obj.get("name")
        or obj.get("athleteName")
        or f"{obj.get('firstName', '')} {obj.get('lastName', '')}".strip()
    )
    school_raw = (
        obj.get("previousSchool")
        or obj.get("fromSchool")
        or obj.get("currentTeam")
        or obj.get("school")
        or obj.get("team")
        or ""
    )
    school = (
        school_raw.get("name", "") if isinstance(school_raw, dict) else str(school_raw)
    )
    return name.strip(), school.strip()


def _walk_json(
    node: object,
    seen: set[str],
    results: list[dict],
    depth: int = 0,
) -> None:
    """Recursively walk arbitrary JSON to collect player-record dicts."""
    if depth > 12 or len(results) >= MAX_PLAYERS:
        return
    if isinstance(node, dict):
        if _is_player_record(node):
            name, school = _extract_name_school(node)
            if name and len(name.split()) >= 2 and name not in seen:
                seen.add(name)
                results.append({"name": name, "school_from": school})
        else:
            for v in node.values():
                _walk_json(v, seen, results, depth + 1)
    elif isinstance(node, list):
        for item in node:
            _walk_json(item, seen, results, depth + 1)


def _try_next_data(soup: BeautifulSoup) -> list[dict]:
    """
    Extract player records from Next.js __NEXT_DATA__ JSON embedded in the page.
    On3 is a Next.js app — SSR props are serialised into this script tag even
    when the visible table is client-side rendered.
    """
    tag = soup.find("script", id="__NEXT_DATA__")
    if not tag or not tag.string:
        log.info("No __NEXT_DATA__ tag found")
        return []
    try:
        data = json.loads(tag.string)
    except json.JSONDecodeError as e:
        log.warning("__NEXT_DATA__ JSON parse error: %s", e)
        return []

    results: list[dict] = []
    _walk_json(data, set(), results)
    log.info("__NEXT_DATA__ yielded %d players", len(results))
    return results


def _try_on3_next_api(soup: BeautifulSoup) -> list[dict]:
    """
    Attempt On3's /_next/data/ endpoint — Next.js exposes a JSON version of
    every page at /_next/data/{buildId}/{path}.json.
    We read the buildId from __NEXT_DATA__ and construct the URL.
    """
    tag = soup.find("script", id="__NEXT_DATA__")
    if not tag or not tag.string:
        return []
    try:
        meta = json.loads(tag.string)
        build_id = meta.get("buildId", "")
    except (json.JSONDecodeError, AttributeError):
        return []

    if not build_id:
        return []

    api_url = (
        f"https://www.on3.com/_next/data/{build_id}"
        "/transfer-portal/industry/basketball.json"
    )
    log.info("Trying On3 Next.js data API: %s", api_url)
    try:
        resp = requests.get(api_url, headers=_HEADERS, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        log.warning("On3 Next.js API failed: %s", e)
        return []

    results: list[dict] = []
    _walk_json(data, set(), results)
    log.info("On3 Next.js API yielded %d players", len(results))
    return results


def _try_player_links(soup: BeautifulSoup) -> list[dict]:
    """
    Fall back to scraping /players/{slug}/{id}/ href patterns from whatever
    HTML did arrive (works if On3 partially SSRs the list).
    """
    results: list[dict] = []
    seen: set[str] = set()
    for a_tag in soup.find_all("a", href=re.compile(r"/players/[^/]+/\d+/")):
        if len(results) >= MAX_PLAYERS:
            break
        match = re.search(r"/players/([a-z0-9-]+)/\d+/", a_tag.get("href", ""))
        if not match:
            continue
        name = " ".join(w.capitalize() for w in match.group(1).split("-") if w)
        if name and len(name.split()) >= 2 and name not in seen:
            seen.add(name)
            results.append({"name": name, "school_from": ""})
    log.info("Player-link scrape yielded %d players", len(results))
    return results


def _try_google_news_rss() -> list[dict]:
    """
    Query Google News RSS for Men's CBB transfer portal player names.
    Requires a portal-action verb directly adjacent to the name so we collect
    actual players rather than schools, coaches, or generic phrases.
    """
    rss_url = (
        "https://news.google.com/rss/search"
        "?q=%22transfer+portal%22+%22men%27s+basketball%22"
        "+%28enters+OR+commits+OR+transfers+OR+decommits%29"
        "&hl=en-US&gl=US&ceid=US:en"
    )
    log.info("Trying Google News RSS as discovery fallback")
    try:
        resp = requests.get(rss_url, headers=_HEADERS, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
    except requests.RequestException as e:
        log.warning("Google News RSS failed: %s", e)
        return []

    soup = BeautifulSoup(resp.text, "lxml-xml")
    results: list[dict] = []
    seen: set[str] = set()

    # Only match a capitalised name immediately BEFORE a portal-action verb.
    # This rejects schools, coaches, and generic phrases that lack a verb.
    portal_verb = (
        r"enters?|entered|commits?|committed|transfers?|transferred|"
        r"decommits?|decommitted|announces?|announced|withdraws?|withdrew"
    )
    name_before_verb_re = re.compile(
        rf"\b([A-Z][a-z]{{2,}}(?:\s+[A-Z][a-z]{{2,}}){{1,2}})\s+(?:{portal_verb})\b",
        re.IGNORECASE,
    )
    school_re = re.compile(
        r"(?:from|leaves?|exits?|departs?|out of)\s+([A-Z][A-Za-z\s&]+?)(?:\s*[,|\-]|\s+to\s|$)"
    )

    # Words that appear in capitalised phrases but are never part of a player name
    _non_name_words = {
        "transfer", "portal", "basketball", "college", "university",
        "the", "and", "from", "with", "this", "that",
        "north", "south", "east", "west", "iowa", "ohio", "michigan",
        "florida", "texas", "arizona", "kansas", "kentucky", "indiana",
    }

    for item in soup.find_all("item")[:80]:
        title_tag = item.find("title")
        if not title_tag:
            continue
        title = title_tag.get_text(strip=True)

        # Skip women's basketball headlines entirely
        if re.search(r"\bwomen'?s\b|\bwnba\b|\bwbb\b", title, re.I):
            continue
        # Must be about men's basketball
        if not re.search(r"\bmen'?s\s+basketball\b|\bCBB\b", title, re.I):
            continue

        for match in name_before_verb_re.finditer(title):
            name = match.group(1).strip()
            parts = name.split()
            # Must be 2+ words, none of which are non-name words
            if len(parts) < 2:
                continue
            if any(p.lower() in _non_name_words for p in parts):
                continue
            # Skip all-caps abbreviations (e.g. "NCAA Commits")
            if any(p.isupper() and len(p) > 2 for p in parts):
                continue

            if name not in seen:
                seen.add(name)
                school_match = school_re.search(title)
                school = school_match.group(1).strip() if school_match else ""
                results.append({"name": name, "school_from": school})
                log.info("RSS player: '%s' (school: '%s')", name, school or "unknown")
                if len(results) >= MAX_PLAYERS:
                    break
        if len(results) >= MAX_PLAYERS:
            break

    log.info("Google News RSS yielded %d candidate players", len(results))
    return results


def _scrape_on3_portal() -> list[dict]:
    """
    Discover Men's CBB transfer portal players via a layered strategy:
      1. On3 __NEXT_DATA__ JSON (Next.js SSR props embedded in HTML)
      2. On3 /_next/data/{buildId}/… JSON API
      3. On3 player profile link hrefs (works if partial SSR)
      4. Google News RSS headline parsing (reliable free fallback)
    Returns list of {"name": str, "school_from": str}.
    """
    log.info("Fetching On3 portal: %s", ON3_PORTAL_URL)
    soup = _fetch_html(ON3_PORTAL_URL)

    if soup is not None:
        players = _try_next_data(soup)
        if players:
            return players[:MAX_PLAYERS]

        players = _try_on3_next_api(soup)
        if players:
            return players[:MAX_PLAYERS]

        players = _try_player_links(soup)
        if players:
            return players[:MAX_PLAYERS]

    # All On3 strategies failed — fall back to Google News RSS
    players = _try_google_news_rss()
    log.info("Total players discovered: %d", len(players))
    return players[:MAX_PLAYERS]


# ── X / Nitter scraping ───────────────────────────────────────────────────────

def _scrape_nitter(player_name: str) -> list[str]:
    """
    Search Nitter instances for recent X posts about the player.
    Tries each instance in order, returns up to 3 cleaned tweet texts.
    Falls back to On3 search snippets if all Nitter instances fail.
    """
    query = urllib.parse.quote_plus(
        f'"{player_name}" transfer portal college basketball'
    )
    snippets: list[str] = []

    for base_url in NITTER_BASES:
        url = f"{base_url}/search?q={query}&f=tweets"
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=REQUEST_TIMEOUT)
            if resp.status_code != 200:
                continue
            soup = BeautifulSoup(resp.text, "lxml")
            # Nitter renders tweet text in divs with class "tweet-content" or "tweet-text"
            for div in soup.find_all(
                "div",
                class_=re.compile(r"tweet-content|tweet-text|timeline-item"),
            ):
                text = div.get_text(separator=" ", strip=True)
                if (
                    text
                    and len(text) > 30
                    and player_name.split()[0].lower() in text.lower()
                ):
                    snippets.append(text[:500])
                    if len(snippets) >= 3:
                        break
            if snippets:
                log.info(
                    "Got %d X snippets for '%s' via %s",
                    len(snippets),
                    player_name,
                    base_url,
                )
                return snippets
        except requests.RequestException:
            continue

    # Fallback: On3 search for the player
    try:
        on3_search = (
            f"https://www.on3.com/search/?q={urllib.parse.quote_plus(player_name)}"
        )
        resp = requests.get(on3_search, headers=_HEADERS, timeout=REQUEST_TIMEOUT)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "lxml")
            first_name = player_name.split()[0].lower()
            for tag in soup.find_all(["p", "span", "h3", "h4"], limit=20):
                text = tag.get_text(strip=True)
                if first_name in text.lower() and len(text) > 40:
                    snippets.append(text[:500])
                    if len(snippets) >= 2:
                        break
    except requests.RequestException:
        pass

    if not snippets:
        log.info("No social snippets found for '%s'", player_name)
    return snippets


# ── Gemini analysis ───────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """You are a Men's College Basketball transfer portal analyst for Signal Sports.

SCOPE: Men's NCAA Division I basketball transfer portal ONLY.
IGNORE: NBA drafts, women's basketball, high school recruiting, non-CBB content.

Your output is ALWAYS a single valid JSON object matching this exact schema:
{
  "player_name": "Full Player Name",
  "school_from": "School they are leaving (empty string if unknown)",
  "summary": "20 words or fewer, present tense — e.g. 'John Smith enters portal from Duke; Power 5 programs showing heavy interest'",
  "lead_schools": ["School A", "School B"],
  "visit_dates": ["YYYY-MM-DD"],
  "sentiment_score": 5.5
}

sentiment_score: 1.0 = very negative buzz, 5.0 = neutral/no data, 10.0 = elite buzz with top programs.
lead_schools: up to 5 schools. Empty array if none mentioned.
visit_dates: ISO dates only. Empty array if none mentioned.
Return ONLY the JSON with no markdown, no commentary."""


def _analyze_player(
    client: genai.Client,
    player_name: str,
    school_from: str,
    snippets: list[str],
) -> Optional[RadarEntry]:
    """Send player data to Gemini Flash Lite and return a validated RadarEntry."""
    snippet_block = (
        "\n".join(f"- {s}" for s in snippets)
        if snippets
        else "(no social or news data found for this player)"
    )

    prompt = f"""Analyze this Men's CBB transfer portal player entry:

Player: {player_name}
School leaving: {school_from or "Unknown"}
Social/news snippets:
{snippet_block}

Return the JSON schema only."""

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                system_instruction=_SYSTEM_PROMPT,
                temperature=0.2,
                max_output_tokens=512,
                response_mime_type="application/json",
            ),
        )
        raw = response.text.strip()
        # Strip any accidental markdown fences
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)

        data = json.loads(raw)
        data["timestamp"] = datetime.now(timezone.utc).isoformat()
        data["source_snippets"] = snippets

        # Guard: ensure player_name is never blank
        if not data.get("player_name"):
            data["player_name"] = player_name
        if not data.get("school_from"):
            data["school_from"] = school_from

        return RadarEntry(**data)

    except json.JSONDecodeError as e:
        log.warning("JSON parse error for '%s': %s | raw=%s", player_name, e, raw[:200])
    except Exception as e:
        log.warning("Gemini error for '%s': %s", player_name, e)

    return None


# ── RTDB write ────────────────────────────────────────────────────────────────

def _player_slug(name: str) -> str:
    """'John Smith Jr.' → 'john-smith-jr' (safe RTDB key)."""
    slug = re.sub(r"[^a-z0-9\s]", "", name.lower())
    return re.sub(r"\s+", "-", slug.strip())


def _write_entry(entry: RadarEntry) -> None:
    """Upsert entry to RTDB (one doc per player, always latest data)."""
    slug = _player_slug(entry.player_name)
    ref = rtdb.reference(f"recruit_radar/entries/{slug}")
    ref.set(entry.model_dump())
    log.info("Written: recruit_radar/entries/%s", slug)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    log.info("=== Recruit Radar job starting (model: %s) ===", GEMINI_MODEL)

    _init_firebase()
    gemini_client = _get_gemini_client()

    players = _scrape_on3_portal()
    if not players:
        log.warning("No players discovered — updating last_updated and exiting")
        rtdb.reference("recruit_radar/last_updated").set(
            datetime.now(timezone.utc).isoformat()
        )
        return

    processed = 0
    errors = 0

    for i, player in enumerate(players[:MAX_PLAYERS], start=1):
        name = player["name"]
        school_from = player.get("school_from", "")
        log.info("[%d/%d] Processing: %s", i, min(len(players), MAX_PLAYERS), name)

        snippets = _scrape_nitter(name)
        entry = _analyze_player(gemini_client, name, school_from, snippets)

        if entry is None:
            errors += 1
        else:
            try:
                _write_entry(entry)
                processed += 1
            except Exception as e:
                log.error("RTDB write failed for '%s': %s", name, e)
                errors += 1

        time.sleep(DELAY_BETWEEN_PLAYERS)

    rtdb.reference("recruit_radar/last_updated").set(
        datetime.now(timezone.utc).isoformat()
    )

    log.info(
        "=== Recruit Radar job done: %d written, %d errors ===",
        processed,
        errors,
    )


if __name__ == "__main__":
    main()
