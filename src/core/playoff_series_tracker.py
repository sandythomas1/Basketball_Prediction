"""
PlayoffSeriesTracker: Tracks the state of NBA playoff best-of-7 series.
"""

import json
from datetime import datetime, date
from pathlib import Path
from typing import Optional, List, Dict


# NBA playoff home court schedule (standard):
# Higher seed hosts: Games 1, 2, 5, 7
# Lower seed hosts:  Games 3, 4, 6
HIGHER_SEED_HOME_GAMES = {1, 2, 5, 7}


def get_home_team_for_game(
    higher_seed_id: int,
    lower_seed_id: int,
    game_number: int,
) -> int:
    """Return the home team ID for a given game number in a series."""
    if game_number in HIGHER_SEED_HOME_GAMES:
        return higher_seed_id
    return lower_seed_id


class SeriesGame:
    """Represents a single game within a playoff series."""

    def __init__(
        self,
        game_number: int,
        game_date: str,
        home_team_id: int,
        away_team_id: int,
        home_score: Optional[int] = None,
        away_score: Optional[int] = None,
        winner_id: Optional[int] = None,
        status: str = "scheduled",
    ):
        self.game_number = game_number
        self.game_date = game_date
        self.home_team_id = home_team_id
        self.away_team_id = away_team_id
        self.home_score = home_score
        self.away_score = away_score
        self.winner_id = winner_id
        self.status = status  # "scheduled" | "final"

    @property
    def is_final(self) -> bool:
        return self.status.lower() == "final"

    def to_dict(self) -> dict:
        return {
            "game_number": self.game_number,
            "game_date": self.game_date,
            "home_team_id": self.home_team_id,
            "away_team_id": self.away_team_id,
            "home_score": self.home_score,
            "away_score": self.away_score,
            "winner_id": self.winner_id,
            "status": self.status,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "SeriesGame":
        return cls(
            game_number=data["game_number"],
            game_date=data["game_date"],
            home_team_id=data["home_team_id"],
            away_team_id=data["away_team_id"],
            home_score=data.get("home_score"),
            away_score=data.get("away_score"),
            winner_id=data.get("winner_id"),
            status=data.get("status", "scheduled"),
        )


class PlayoffSeries:
    """Represents a single best-of-7 playoff series."""

    def __init__(
        self,
        series_id: str,
        round_name: str,
        conference: str,
        higher_seed_id: int,
        lower_seed_id: int,
        higher_seed_name: str,
        lower_seed_name: str,
        games: Optional[List[SeriesGame]] = None,
        status: str = "upcoming",
        winner_id: Optional[int] = None,
    ):
        self.series_id = series_id
        self.round_name = round_name       # "first_round" | "conf_semifinals" | "conf_finals" | "finals"
        self.conference = conference       # "East" | "West" | "Finals"
        self.higher_seed_id = higher_seed_id
        self.lower_seed_id = lower_seed_id
        self.higher_seed_name = higher_seed_name
        self.lower_seed_name = lower_seed_name
        self.games: List[SeriesGame] = games or []
        self.status = status               # "upcoming" | "in_progress" | "complete"
        self.winner_id = winner_id

    @property
    def higher_seed_wins(self) -> int:
        return sum(1 for g in self.games if g.is_final and g.winner_id == self.higher_seed_id)

    @property
    def lower_seed_wins(self) -> int:
        return sum(1 for g in self.games if g.is_final and g.winner_id == self.lower_seed_id)

    @property
    def games_played(self) -> int:
        return sum(1 for g in self.games if g.is_final)

    @property
    def next_game_number(self) -> int:
        return self.games_played + 1

    @property
    def is_complete(self) -> bool:
        return self.higher_seed_wins == 4 or self.lower_seed_wins == 4

    def get_series_leader_id(self) -> Optional[int]:
        """Return the team that is leading or None if tied."""
        hs = self.higher_seed_wins
        ls = self.lower_seed_wins
        if hs > ls:
            return self.higher_seed_id
        if ls > hs:
            return self.lower_seed_id
        return None

    def get_series_context_string(self) -> str:
        """Return a human-readable series context string."""
        hs = self.higher_seed_wins
        ls = self.lower_seed_wins
        hs_name = self.higher_seed_name.split()[-1]  # Last word (e.g. "Celtics")
        ls_name = self.lower_seed_name.split()[-1]

        if self.is_complete:
            if self.winner_id == self.higher_seed_id:
                return f"{hs_name} win series {hs}-{ls}"
            return f"{ls_name} win series {ls}-{hs}"

        if hs == ls == 0:
            return "Series yet to begin"

        game_n = self.next_game_number
        if hs > ls:
            needs = 4 - hs
            return f"{hs_name} leads {hs}-{ls}, needs {needs} more win{'s' if needs > 1 else ''} (Game {game_n})"
        elif ls > hs:
            needs = 4 - ls
            return f"{ls_name} leads {ls}-{hs}, needs {needs} more win{'s' if needs > 1 else ''} (Game {game_n})"
        else:
            return f"Series tied {hs}-{ls} (Game {game_n})"

    def record_game(
        self,
        game_date: str,
        home_score: int,
        away_score: int,
        home_team_id: int,
        away_team_id: int,
    ) -> SeriesGame:
        """
        Record a completed game result into the series.

        Determines winner, updates status, and marks series complete if needed.
        Returns the recorded SeriesGame.
        """
        game_number = self.next_game_number
        winner_id = home_team_id if home_score > away_score else away_team_id

        # Check if this game number already exists (overwrite if re-processing)
        existing = next((g for g in self.games if g.game_number == game_number), None)
        if existing:
            existing.home_score = home_score
            existing.away_score = away_score
            existing.winner_id = winner_id
            existing.status = "final"
            series_game = existing
        else:
            series_game = SeriesGame(
                game_number=game_number,
                game_date=game_date,
                home_team_id=home_team_id,
                away_team_id=away_team_id,
                home_score=home_score,
                away_score=away_score,
                winner_id=winner_id,
                status="final",
            )
            self.games.append(series_game)

        # Update series status
        if self.is_complete:
            self.status = "complete"
            if self.higher_seed_wins == 4:
                self.winner_id = self.higher_seed_id
            else:
                self.winner_id = self.lower_seed_id
        else:
            self.status = "in_progress"

        return series_game

    def get_next_game_home_team(self) -> int:
        """Return the home team ID for the next game in this series."""
        return get_home_team_for_game(
            self.higher_seed_id,
            self.lower_seed_id,
            self.next_game_number,
        )

    def to_dict(self) -> dict:
        return {
            "series_id": self.series_id,
            "round_name": self.round_name,
            "conference": self.conference,
            "higher_seed_id": self.higher_seed_id,
            "lower_seed_id": self.lower_seed_id,
            "higher_seed_name": self.higher_seed_name,
            "lower_seed_name": self.lower_seed_name,
            "games": [g.to_dict() for g in self.games],
            "status": self.status,
            "winner_id": self.winner_id,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "PlayoffSeries":
        games = [SeriesGame.from_dict(g) for g in data.get("games", [])]
        return cls(
            series_id=data["series_id"],
            round_name=data["round_name"],
            conference=data["conference"],
            higher_seed_id=data["higher_seed_id"],
            lower_seed_id=data["lower_seed_id"],
            higher_seed_name=data["higher_seed_name"],
            lower_seed_name=data["lower_seed_name"],
            games=games,
            status=data.get("status", "upcoming"),
            winner_id=data.get("winner_id"),
        )

    def __repr__(self) -> str:
        return (
            f"PlayoffSeries({self.series_id}: "
            f"{self.higher_seed_name} {self.higher_seed_wins}-{self.lower_seed_wins} "
            f"{self.lower_seed_name}, {self.status})"
        )


class PlayoffSeriesTracker:
    """
    Tracks all active playoff series for a given season.

    Manages bracket state: series records, game-by-game history,
    and home court rotation across all rounds.
    """

    def __init__(
        self,
        season: int,
        series: Optional[Dict[str, PlayoffSeries]] = None,
        current_round: str = "first_round",
        playoffs_start_date: Optional[str] = None,
    ):
        self.season = season
        self.series: Dict[str, PlayoffSeries] = series or {}
        self.current_round = current_round
        self.playoffs_start_date = playoffs_start_date

    def add_series(self, series: PlayoffSeries) -> None:
        """Add or replace a series by series_id."""
        self.series[series.series_id] = series

    def get_series(self, series_id: str) -> Optional[PlayoffSeries]:
        """Get a series by ID."""
        return self.series.get(series_id)

    def get_series_for_teams(
        self, team_id_1: int, team_id_2: int
    ) -> Optional[PlayoffSeries]:
        """Find the active series containing both team IDs."""
        for s in self.series.values():
            team_ids = {s.higher_seed_id, s.lower_seed_id}
            if team_id_1 in team_ids and team_id_2 in team_ids:
                return s
        return None

    def get_team_series_wins(self, team_id: int) -> int:
        """Get how many wins a team has in their current active series."""
        s = None
        for series in self.series.values():
            if team_id in {series.higher_seed_id, series.lower_seed_id}:
                if series.status == "in_progress":
                    s = series
                    break
        if s is None:
            return 0
        if team_id == s.higher_seed_id:
            return s.higher_seed_wins
        return s.lower_seed_wins

    def get_active_series(self) -> List[PlayoffSeries]:
        """Return all in-progress or upcoming series."""
        return [s for s in self.series.values() if s.status != "complete"]

    def get_all_series(self) -> List[PlayoffSeries]:
        """Return all series."""
        return list(self.series.values())

    def to_dict(self) -> dict:
        return {
            "season": self.season,
            "current_round": self.current_round,
            "playoffs_start_date": self.playoffs_start_date,
            "series": {sid: s.to_dict() for sid, s in self.series.items()},
        }

    @classmethod
    def from_dict(cls, data: dict) -> "PlayoffSeriesTracker":
        series = {
            sid: PlayoffSeries.from_dict(sdata)
            for sid, sdata in data.get("series", {}).items()
        }
        return cls(
            season=data["season"],
            series=series,
            current_round=data.get("current_round", "first_round"),
            playoffs_start_date=data.get("playoffs_start_date"),
        )

    def save(self, path: Path) -> None:
        """Save tracker state to JSON file."""
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f, indent=2)

    @classmethod
    def from_file(cls, path: Path) -> "PlayoffSeriesTracker":
        """Load tracker state from JSON file."""
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return cls.from_dict(data)

    def __repr__(self) -> str:
        n_active = len(self.get_active_series())
        return f"PlayoffSeriesTracker(season={self.season}, active_series={n_active})"
