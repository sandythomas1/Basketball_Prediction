"""
OddsClient: Fetches betting odds from The Odds API.

Free tier: 500 requests/month
API Docs: https://the-odds-api.com/liveapi/guides/v4/
"""

import os
import time
from dataclasses import dataclass
from datetime import datetime, date
from typing import Optional, Dict, List

import requests

from .team_mapper import TeamMapper


@dataclass
class GameOdds:
    """Represents moneyline odds for a game."""
    home_team: str          # Team name from API
    away_team: str          # Team name from API
    home_team_id: Optional[int] = None  # NBA team ID
    away_team_id: Optional[int] = None  # NBA team ID
    ml_home: Optional[float] = None     # Home moneyline (e.g., -150)
    ml_away: Optional[float] = None     # Away moneyline (e.g., +130)
    commence_time: Optional[datetime] = None  # Game start time
    bookmaker: str = ""     # Source bookmaker

    @property
    def implied_prob_home(self) -> float:
        """Convert home moneyline to implied probability."""
        return self._ml_to_prob(self.ml_home)

    @property
    def implied_prob_away(self) -> float:
        """Convert away moneyline to implied probability."""
        return self._ml_to_prob(self.ml_away)

    @staticmethod
    def _ml_to_prob(ml: Optional[float]) -> float:
        """Convert American moneyline to implied probability."""
        if ml is None:
            return 0.5  # Neutral default
        if ml > 0:
            return 100 / (ml + 100)
        return abs(ml) / (abs(ml) + 100)

    def __repr__(self) -> str:
        return f"{self.away_team} @ {self.home_team} (ML: {self.ml_home}/{self.ml_away})"


class OddsClient:
    """
    Client for fetching NBA betting odds from The Odds API.
    
    Features:
    - Rate limiting (minimum 10 seconds between API calls)
    - In-memory caching for the session
    - Team ID mapping via TeamMapper
    - Graceful fallback on errors
    
    Usage:
        client = OddsClient(api_key="your_key")
        odds = client.get_odds()  # Returns list of GameOdds
        
        # Get odds for a specific matchup
        ml_home, ml_away = client.get_odds_for_game(home_team_id, away_team_id)
    """

    BASE_URL = "https://api.the-odds-api.com/v4/sports/basketball_nba/odds"
    SPORT_KEY = "basketball_nba"
    MARKET = "h2h"  # Moneyline
    
    # Rate limiting: minimum seconds between API calls
    MIN_REQUEST_INTERVAL = 10
    
    # Preferred bookmakers in priority order (consensus/average odds)
    PREFERRED_BOOKMAKERS = [
        "fanduel",
        "draftkings", 
        "betmgm",
        "caesars",
        "pointsbetus",
    ]

    def __init__(
        self, 
        api_key: Optional[str] = None,
        team_mapper: Optional[TeamMapper] = None,
    ):
        """
        Initialize OddsClient.

        Args:
            api_key: The Odds API key. If None, reads from ODDS_API_KEY env var.
            team_mapper: TeamMapper for converting names to NBA IDs.
        """
        self.api_key = api_key or os.environ.get("ODDS_API_KEY", "")
        self.team_mapper = team_mapper or TeamMapper()
        
        self._session = requests.Session()
        self._session.headers.update({
            "Accept": "application/json",
        })
        
        # Rate limiting state
        self._last_request_time: float = 0
        
        # Cache: date string -> list of GameOdds
        self._cache: Dict[str, List[GameOdds]] = {}
        
        # API usage tracking (from response headers)
        self.requests_remaining: Optional[int] = None
        self.requests_used: Optional[int] = None

    def _wait_for_rate_limit(self) -> None:
        """Wait if necessary to respect rate limit."""
        if self._last_request_time > 0:
            elapsed = time.time() - self._last_request_time
            if elapsed < self.MIN_REQUEST_INTERVAL:
                wait_time = self.MIN_REQUEST_INTERVAL - elapsed
                time.sleep(wait_time)
        self._last_request_time = time.time()

    def _update_usage_from_headers(self, headers: dict) -> None:
        """Update API usage stats from response headers."""
        if "x-requests-remaining" in headers:
            self.requests_remaining = int(headers["x-requests-remaining"])
        if "x-requests-used" in headers:
            self.requests_used = int(headers["x-requests-used"])

    def get_odds(self, force_refresh: bool = False) -> List[GameOdds]:
        """
        Fetch current NBA odds from The Odds API.

        Args:
            force_refresh: If True, bypass cache and fetch fresh data.

        Returns:
            List of GameOdds objects for upcoming games.
            Returns empty list if API key is missing or request fails.
        """
        # Check cache first
        cache_key = date.today().isoformat()
        if not force_refresh and cache_key in self._cache:
            return self._cache[cache_key]

        # Check API key
        if not self.api_key:
            print("Warning: ODDS_API_KEY not set. Using neutral odds (0.5).")
            return []

        # Rate limit
        self._wait_for_rate_limit()

        try:
            params = {
                "apiKey": self.api_key,
                "regions": "us",
                "markets": self.MARKET,
                "oddsFormat": "american",
            }

            response = self._session.get(
                self.BASE_URL,
                params=params,
                timeout=15,
            )
            
            # Update usage stats
            self._update_usage_from_headers(response.headers)
            
            if response.status_code == 401:
                print("Error: Invalid ODDS_API_KEY.")
                return []
            
            if response.status_code == 429:
                print("Error: Odds API rate limit exceeded.")
                return []
                
            response.raise_for_status()
            data = response.json()

            # Parse response
            odds_list = self._parse_response(data)
            
            # Cache results
            self._cache[cache_key] = odds_list
            
            if self.requests_remaining is not None:
                print(f"  Odds API: {len(odds_list)} games fetched, {self.requests_remaining} requests remaining this month")
            
            return odds_list

        except requests.RequestException as e:
            print(f"Warning: Failed to fetch odds: {e}")
            return []

    def _parse_response(self, data: List[dict]) -> List[GameOdds]:
        """Parse API response into GameOdds objects."""
        odds_list = []

        for event in data:
            try:
                game_odds = self._parse_event(event)
                if game_odds:
                    odds_list.append(game_odds)
            except Exception as e:
                print(f"Warning: Failed to parse odds event: {e}")
                continue

        return odds_list

    def _parse_event(self, event: dict) -> Optional[GameOdds]:
        """Parse a single event from the API response."""
        home_team = event.get("home_team", "")
        away_team = event.get("away_team", "")
        
        if not home_team or not away_team:
            return None

        # Parse commence time
        commence_time = None
        commence_str = event.get("commence_time", "")
        if commence_str:
            try:
                commence_time = datetime.fromisoformat(commence_str.replace("Z", "+00:00"))
            except ValueError:
                pass

        # Get moneylines from bookmakers
        ml_home, ml_away, bookmaker = self._extract_moneylines(event, home_team, away_team)

        # Map to NBA team IDs
        home_team_id = self.team_mapper.get_team_id(home_team)
        away_team_id = self.team_mapper.get_team_id(away_team)

        return GameOdds(
            home_team=home_team,
            away_team=away_team,
            home_team_id=home_team_id,
            away_team_id=away_team_id,
            ml_home=ml_home,
            ml_away=ml_away,
            commence_time=commence_time,
            bookmaker=bookmaker,
        )

    def _extract_moneylines(
        self, 
        event: dict, 
        home_team: str, 
        away_team: str
    ) -> tuple[Optional[float], Optional[float], str]:
        """
        Extract moneyline odds from event bookmakers.
        
        Tries preferred bookmakers first, then falls back to first available.
        """
        bookmakers = event.get("bookmakers", [])
        if not bookmakers:
            return None, None, ""

        # Build lookup by bookmaker key
        bookmaker_odds = {}
        for bm in bookmakers:
            key = bm.get("key", "")
            markets = bm.get("markets", [])
            for market in markets:
                if market.get("key") == self.MARKET:
                    outcomes = market.get("outcomes", [])
                    ml_home = None
                    ml_away = None
                    for outcome in outcomes:
                        name = outcome.get("name", "")
                        price = outcome.get("price")
                        if name == home_team:
                            ml_home = price
                        elif name == away_team:
                            ml_away = price
                    if ml_home is not None and ml_away is not None:
                        bookmaker_odds[key] = (ml_home, ml_away)

        if not bookmaker_odds:
            return None, None, ""

        # Try preferred bookmakers first
        for preferred in self.PREFERRED_BOOKMAKERS:
            if preferred in bookmaker_odds:
                ml_home, ml_away = bookmaker_odds[preferred]
                return ml_home, ml_away, preferred

        # Fall back to first available
        first_key = next(iter(bookmaker_odds))
        ml_home, ml_away = bookmaker_odds[first_key]
        return ml_home, ml_away, first_key

    def get_odds_for_game(
        self, 
        home_team_id: int, 
        away_team_id: int,
    ) -> tuple[Optional[float], Optional[float]]:
        """
        Get moneyline odds for a specific matchup.

        Args:
            home_team_id: NBA team ID for home team
            away_team_id: NBA team ID for away team

        Returns:
            Tuple of (ml_home, ml_away). Returns (None, None) if not found.
        """
        odds_list = self.get_odds()
        
        for odds in odds_list:
            if odds.home_team_id == home_team_id and odds.away_team_id == away_team_id:
                return odds.ml_home, odds.ml_away
        
        return None, None

    def get_odds_dict(self) -> Dict[tuple[int, int], tuple[Optional[float], Optional[float]]]:
        """
        Get all odds as a dictionary keyed by (home_team_id, away_team_id).
        
        Useful for batch lookups when predicting multiple games.

        Returns:
            Dict mapping (home_id, away_id) to (ml_home, ml_away)
        """
        odds_list = self.get_odds()
        return {
            (odds.home_team_id, odds.away_team_id): (odds.ml_home, odds.ml_away)
            for odds in odds_list
            if odds.home_team_id is not None and odds.away_team_id is not None
        }

    def clear_cache(self) -> None:
        """Clear the odds cache."""
        self._cache.clear()

    def __repr__(self) -> str:
        status = "configured" if self.api_key else "no API key"
        remaining = f", {self.requests_remaining} remaining" if self.requests_remaining else ""
        return f"OddsClient({status}{remaining})"
