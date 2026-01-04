"""
ESPNClient: Fetches game data from ESPN's public API.
"""

from dataclasses import dataclass
from datetime import datetime, date
from typing import Optional, List
import requests

from .team_mapper import TeamMapper


@dataclass
class GameResult:
    """Represents a game result from ESPN."""
    game_date: str          # YYYY-MM-DD
    home_team: str          # ESPN display name
    away_team: str          # ESPN display name
    home_score: int
    away_score: int
    status: str             # "Final", "In Progress", "Scheduled", etc.
    home_team_id: Optional[int] = None  # NBA team ID
    away_team_id: Optional[int] = None  # NBA team ID
    game_time: Optional[str] = None     # HH:MM format (local time)
    game_datetime: Optional[datetime] = None  # Full datetime

    @property
    def is_final(self) -> bool:
        """Check if game is completed."""
        return self.status.lower() == "final"

    @property
    def is_scheduled(self) -> bool:
        """Check if game is upcoming/scheduled."""
        return self.status.lower() == "scheduled"

    @property
    def is_in_progress(self) -> bool:
        """Check if game is currently being played."""
        status_lower = self.status.lower()
        return "progress" in status_lower or "halftime" in status_lower

    @property
    def home_won(self) -> bool:
        """Check if home team won."""
        return self.home_score > self.away_score

    def __repr__(self) -> str:
        if self.is_scheduled and self.game_time:
            return f"{self.away_team} @ {self.home_team} ({self.game_time}, {self.status})"
        return f"{self.away_team} @ {self.home_team} ({self.home_score}-{self.away_score}, {self.status})"


class ESPNClient:
    """
    Client for fetching NBA game data from ESPN's public API.
    
    Uses the same endpoint as the Flutter app.
    """

    BASE_URL = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard"
    TIMEOUT = 10  # seconds

    def __init__(self, team_mapper: Optional[TeamMapper] = None):
        """
        Initialize ESPN client.

        Args:
            team_mapper: TeamMapper for converting ESPN names to NBA IDs.
                        If None, a new one will be created.
        """
        self.team_mapper = team_mapper or TeamMapper()
        self._session = requests.Session()
        self._session.headers.update({
            "Accept": "application/json",
            "User-Agent": "NBA-Predictor/1.0",
        })

    def get_scoreboard(self, game_date: Optional[str | date] = None) -> dict:
        """
        Fetch raw scoreboard data from ESPN.

        Args:
            game_date: Date to fetch (YYYY-MM-DD or date object).
                      If None, fetches today's scoreboard.

        Returns:
            Raw JSON response from ESPN API
        """
        params = {}
        if game_date:
            if isinstance(game_date, date):
                game_date = game_date.strftime("%Y%m%d")
            else:
                # Convert YYYY-MM-DD to YYYYMMDD
                game_date = game_date.replace("-", "")
            params["dates"] = game_date

        response = self._session.get(
            self.BASE_URL,
            params=params,
            timeout=self.TIMEOUT,
        )
        response.raise_for_status()
        return response.json()

    def get_games(self, game_date: Optional[str | date] = None) -> List[GameResult]:
        """
        Fetch all games for a date.

        Args:
            game_date: Date to fetch (YYYY-MM-DD or date object).
                      If None, fetches today's games.

        Returns:
            List of GameResult objects
        """
        data = self.get_scoreboard(game_date)
        events = data.get("events", [])
        
        results = []
        for event in events:
            try:
                result = self._parse_event(event)
                if result:
                    results.append(result)
            except Exception as e:
                # Log but don't fail on individual game parse errors
                print(f"Warning: Failed to parse game: {e}")
                continue

        return results

    def get_completed_games(self, game_date: Optional[str | date] = None) -> List[GameResult]:
        """
        Fetch only completed games for a date.

        Args:
            game_date: Date to fetch (YYYY-MM-DD or date object).
                      If None, fetches today's completed games.

        Returns:
            List of GameResult objects with status "Final"
        """
        all_games = self.get_games(game_date)
        return [g for g in all_games if g.is_final]

    def get_scheduled_games(self, game_date: Optional[str | date] = None) -> List[GameResult]:
        """
        Fetch only scheduled (upcoming) games for a date.

        Args:
            game_date: Date to fetch (YYYY-MM-DD or date object).
                      If None, fetches today's scheduled games.

        Returns:
            List of GameResult objects with status "Scheduled"
        """
        all_games = self.get_games(game_date)
        return [g for g in all_games if g.is_scheduled]

    def get_upcoming_games(self, game_date: Optional[str | date] = None) -> List[GameResult]:
        """
        Fetch games that haven't finished yet (scheduled or in progress).

        Args:
            game_date: Date to fetch (YYYY-MM-DD or date object).
                      If None, fetches today's upcoming games.

        Returns:
            List of GameResult objects that are not final
        """
        all_games = self.get_games(game_date)
        return [g for g in all_games if not g.is_final]

    def _parse_event(self, event: dict) -> Optional[GameResult]:
        """
        Parse a single event from ESPN API response.

        Args:
            event: Raw event dict from ESPN

        Returns:
            GameResult or None if parsing fails
        """
        competitions = event.get("competitions", [])
        if not competitions:
            return None

        competition = competitions[0]
        competitors = competition.get("competitors", [])
        if len(competitors) < 2:
            return None

        # Extract date and time
        date_str = event.get("date", "")
        game_datetime = None
        game_time = None
        try:
            game_datetime = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
            game_date = game_datetime.strftime("%Y-%m-%d")
            # Convert to local time for display
            local_dt = game_datetime.astimezone()
            game_time = local_dt.strftime("%H:%M")
        except ValueError:
            game_date = date_str[:10] if len(date_str) >= 10 else ""

        # Extract status
        status = event.get("status", {}).get("type", {}).get("description", "Unknown")

        # Extract team info
        home_team = ""
        away_team = ""
        home_score = 0
        away_score = 0

        for competitor in competitors:
            team = competitor.get("team", {})
            team_name = team.get("displayName", "Unknown")
            score_str = competitor.get("score", "0")
            
            try:
                score = int(score_str) if score_str else 0
            except ValueError:
                score = 0

            if competitor.get("homeAway") == "home":
                home_team = team_name
                home_score = score
            else:
                away_team = team_name
                away_score = score

        # Map to NBA team IDs
        home_team_id = self.team_mapper.get_team_id(home_team)
        away_team_id = self.team_mapper.get_team_id(away_team)

        return GameResult(
            game_date=game_date,
            home_team=home_team,
            away_team=away_team,
            home_score=home_score,
            away_score=away_score,
            status=status,
            home_team_id=home_team_id,
            away_team_id=away_team_id,
            game_time=game_time,
            game_datetime=game_datetime,
        )

    def __repr__(self) -> str:
        return f"ESPNClient()"

