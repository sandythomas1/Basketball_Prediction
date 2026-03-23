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
        data is available.

        Args:
            game_date: Date to fetch (YYYY-MM-DD or date). Default: today.

        Returns:
            List of PlayoffGameResult objects. Falls back to plain GameResult
            data if bracket data is unavailable.
        """
        # Get raw games from the regular scoreboard (playoff games appear here)
        raw_games = self._base_client.get_games(game_date)

        # Try to enrich with bracket context
        bracket = self.get_playoff_bracket()
        series_lookup = self._build_series_lookup(bracket)

        results: List[PlayoffGameResult] = []
        for game in raw_games:
            playoff_game = self._enrich_with_series(game, series_lookup)
            results.append(playoff_game)

        return results

    def get_completed_playoff_games(
        self, game_date: Optional[str | date] = None
    ) -> List[PlayoffGameResult]:
        """Fetch only completed playoff games for a date."""
        all_games = self.get_playoff_games(game_date)
        return [g for g in all_games if g.is_final]

    def get_scheduled_playoff_games(
        self, game_date: Optional[str | date] = None
    ) -> List[PlayoffGameResult]:
        """Fetch only scheduled (upcoming) playoff games for a date."""
        all_games = self.get_playoff_games(game_date)
        return [g for g in all_games if g.is_scheduled]

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
        self, game: GameResult, series_lookup: Dict[tuple, dict]
    ) -> PlayoffGameResult:
        """
        Convert a GameResult to a PlayoffGameResult, enriching with series info.
        """
        series_id = None
        game_number = None
        higher_seed_wins = 0
        lower_seed_wins = 0
        round_name = None
        conference = None

        if game.home_team_id and game.away_team_id:
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
        )

    def __repr__(self) -> str:
        return "PlayoffESPNClient()"
