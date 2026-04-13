"""
PlayoffESPNClient: Fetches NBA playoff game data and bracket from ESPN's public API.

Wraps the existing ESPNClient and adds:
  - get_playoff_bracket(): Returns bracket structure from ESPN's playoff endpoint
  - get_playoff_games(date): Tags each GameResult with its series_id
"""

from dataclasses import dataclass, field
from datetime import datetime, date
from typing import Optional, List, Dict
import requests

from .espn_client import ESPNClient, GameResult
from .team_mapper import TeamMapper


# ESPN playoff bracket API endpoint
# Returns current playoff bracket with bracket seedings
PLAYOFF_BRACKET_URL = (
    "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/playoffs"
)

# ESPN scoreboard for specific dates still uses the same scoreboard URL
# The regular scoreboard includes playoff games when they're happening


@dataclass
class PlayoffGameResult(GameResult):
    """Extends GameResult with playoff series context."""
    series_id: Optional[str] = None
    game_number: Optional[int] = None
    higher_seed_wins: int = 0
    lower_seed_wins: int = 0
    round_name: Optional[str] = None
    conference: Optional[str] = None
    is_play_in: bool = False


class PlayoffESPNClient:
    """
    Client for fetching NBA playoff game data from ESPN's public API.

    Wraps the existing ESPNClient — regular season functionality is untouched.
    Adds playoff-specific methods for bracket and series-tagged game results.
    """

    TIMEOUT = 10

    def __init__(self, team_mapper: Optional[TeamMapper] = None):
        """
        Initialize playoff ESPN client.

        Args:
            team_mapper: TeamMapper for converting ESPN names to NBA IDs.
        """
        self._base_client = ESPNClient(team_mapper)
        self.team_mapper = self._base_client.team_mapper
        self._session = requests.Session()
        self._session.headers.update({
            "Accept": "application/json",
            "User-Agent": "NBA-Predictor/1.0",
        })

    def get_playoff_bracket(self) -> dict:
        """
        Fetch the current playoff bracket from ESPN.

        Returns:
            Raw JSON response from ESPN playoff bracket API.
            Falls back to empty dict on failure.
        """
        try:
            response = self._session.get(PLAYOFF_BRACKET_URL, timeout=self.TIMEOUT)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Warning: Failed to fetch playoff bracket from ESPN: {e}")
            return {}

    def get_playoff_games(
        self, game_date: Optional[str | date] = None
    ) -> List[PlayoffGameResult]:
        """
        Fetch playoff games for a given date.

        Uses the regular scoreboard endpoint (playoff games appear here naturally
        during the playoff period). Tags each game with series_id if bracket
        data is available. Play-in games are detected via competition notes and
        tagged with is_play_in=True.

        Args:
            game_date: Date to fetch (YYYY-MM-DD or date). Default: today.

        Returns:
            List of PlayoffGameResult objects. Falls back to plain GameResult
            data if bracket data is unavailable.
        """
        # Fetch raw scoreboard to detect play-in notes alongside game results
        raw_scoreboard = self._base_client.get_scoreboard(game_date)
        play_in_event_ids = self._detect_play_in_event_ids(raw_scoreboard)

        raw_games = self._base_client.get_games(game_date)

        # Try to enrich with bracket context
        bracket = self.get_playoff_bracket()
        series_lookup = self._build_series_lookup(bracket)

        results: List[PlayoffGameResult] = []
        for game, event in zip(raw_games, raw_scoreboard.get("events", [])):
            event_id = event.get("id", "")
            is_play_in = event_id in play_in_event_ids
            playoff_game = self._enrich_with_series(game, series_lookup, is_play_in=is_play_in)
            results.append(playoff_game)

        return results

    def _detect_play_in_event_ids(self, scoreboard: dict) -> set:
        """
        Scan ESPN scoreboard events for play-in tournament notes.

        ESPN tags play-in games with a competition note containing "play-in"
        in the headline. Returns the set of event IDs that are play-in games.
        """
        play_in_ids = set()
        for event in scoreboard.get("events", []):
            competitions = event.get("competitions", [])
            if not competitions:
                continue
            notes = competitions[0].get("notes", [])
            for note in notes:
                headline = note.get("headline", "").lower()
                if "play-in" in headline or "play in" in headline:
                    play_in_ids.add(event.get("id", ""))
                    break
        return play_in_ids

    def get_completed_playoff_games(
        self, game_date: Optional[str | date] = None
    ) -> List[PlayoffGameResult]:
        """Fetch only completed playoff games for a date (excludes play-in)."""
        all_games = self.get_playoff_games(game_date)
        return [g for g in all_games if g.is_final and not g.is_play_in]

    def get_completed_play_in_games(
        self, game_date: Optional[str | date] = None
    ) -> List[PlayoffGameResult]:
        """Fetch only completed play-in tournament games for a date."""
        all_games = self.get_playoff_games(game_date)
        return [g for g in all_games if g.is_final and g.is_play_in]

    def get_scheduled_playoff_games(
        self, game_date: Optional[str | date] = None
    ) -> List[PlayoffGameResult]:
        """Fetch only scheduled (upcoming) playoff games for a date (excludes play-in)."""
        all_games = self.get_playoff_games(game_date)
        return [g for g in all_games if g.is_scheduled and not g.is_play_in]

    def get_scheduled_play_in_games(
        self, game_date: Optional[str | date] = None
    ) -> List[PlayoffGameResult]:
        """Fetch only scheduled play-in tournament games for a date."""
        all_games = self.get_playoff_games(game_date)
        return [g for g in all_games if g.is_scheduled and g.is_play_in]

    def _build_series_lookup(self, bracket: dict) -> Dict[tuple, dict]:
        """
        Build a lookup of (team_id_1, team_id_2) -> series_info
        from the ESPN bracket response.

        Returns empty dict if bracket data is unavailable.
        """
        lookup: Dict[tuple, dict] = {}
        if not bracket:
            return lookup

        try:
            # ESPN bracket structure varies — try both possible structures
            series_list = []

            # Try top-level 'series' array
            if "series" in bracket:
                series_list = bracket["series"]
            # Try nested under bracket structure
            elif "bracket" in bracket:
                for round_data in bracket["bracket"].get("rounds", []):
                    series_list.extend(round_data.get("series", []))

            for s in series_list:
                competitors = s.get("competitors", [])
                if len(competitors) < 2:
                    continue

                team_ids = []
                wins = {}
                for comp in competitors:
                    team = comp.get("team", {})
                    team_name = team.get("displayName", "")
                    tid = self.team_mapper.get_team_id(team_name)
                    if tid:
                        team_ids.append(tid)
                        wins[tid] = comp.get("wins", 0)

                if len(team_ids) == 2:
                    key = tuple(sorted(team_ids))
                    round_name = s.get("type", {}).get("name", "")
                    conference = s.get("conference", {}).get("name", "")
                    uid = s.get("uid", f"series_{key[0]}_{key[1]}")
                    lookup[key] = {
                        "series_id": uid,
                        "round_name": round_name,
                        "conference": conference,
                        "wins": wins,
                    }

        except Exception as e:
            print(f"Warning: Failed to parse playoff bracket: {e}")

        return lookup

    def _enrich_with_series(
        self, game: GameResult, series_lookup: Dict[tuple, dict], is_play_in: bool = False
    ) -> PlayoffGameResult:
        """
        Convert a GameResult to a PlayoffGameResult, enriching with series info.

        Play-in games are tagged with is_play_in=True and round_name="play_in".
        They do not have series context (no best-of-7 tracking).
        """
        series_id = None
        game_number = 1
        higher_seed_wins = 0
        lower_seed_wins = 0
        round_name = None
        conference = None

        if is_play_in:
            round_name = "play_in"
            # Generate a stable series_id for the matchup
            if game.home_team_id and game.away_team_id:
                key = tuple(sorted([game.home_team_id, game.away_team_id]))
                series_id = f"play_in_{key[0]}_{key[1]}"
        elif game.home_team_id and game.away_team_id:
            key = tuple(sorted([game.home_team_id, game.away_team_id]))
            if key in series_lookup:
                info = series_lookup[key]
                series_id = info["series_id"]
                round_name = info["round_name"]
                conference = info["conference"]
                wins = info["wins"]
                higher_seed_wins = wins.get(key[0], 0)
                lower_seed_wins = wins.get(key[1], 0)
                game_number = higher_seed_wins + lower_seed_wins + 1

        return PlayoffGameResult(
            game_date=game.game_date,
            home_team=game.home_team,
            away_team=game.away_team,
            home_score=game.home_score,
            away_score=game.away_score,
            status=game.status,
            home_team_id=game.home_team_id,
            away_team_id=game.away_team_id,
            game_time=game.game_time,
            game_datetime=game.game_datetime,
            series_id=series_id,
            game_number=game_number,
            higher_seed_wins=higher_seed_wins,
            lower_seed_wins=lower_seed_wins,
            round_name=round_name,
            conference=conference,
            is_play_in=is_play_in,
        )

    def __repr__(self) -> str:
        return "PlayoffESPNClient()"
