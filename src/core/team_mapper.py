"""
TeamMapper: Maps ESPN team names to NBA team IDs.
"""

import csv
from pathlib import Path
from typing import Optional


class TeamMapper:
    """
    Maps team names (from ESPN API or other sources) to NBA team IDs.
    Uses the team_lookup.csv file for mapping.
    """

    def __init__(self, lookup_path: Optional[Path] = None):
        """
        Initialize the TeamMapper with lookup data.

        Args:
            lookup_path: Path to team_lookup.csv. If None, uses default location.
        """
        if lookup_path is None:
            # Default path relative to project root
            lookup_path = Path(__file__).parent.parent.parent / "data" / "processed" / "team_lookup.csv"

        self._teams = {}
        self._load_lookup(lookup_path)

    def _load_lookup(self, path: Path) -> None:
        """Load team lookup data from CSV."""
        with open(path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                team_id = int(row["team_id"])
                self._teams[team_id] = {
                    "full_name": row["full_name"],
                    "abbreviation": row["abbreviation"],
                    "nickname": row["nickname"],
                    "city": row["city"],
                }

    def _normalize(self, name: str) -> str:
        """Normalize a team name for matching."""
        return name.lower().strip()

    def get_team_id(self, name: str) -> Optional[int]:
        """
        Get NBA team ID from a team name.

        Matches against full_name, abbreviation, nickname, or city.
        Handles common variations like "LA Clippers" vs "Los Angeles Clippers".

        Args:
            name: Team name to look up (e.g., "Los Angeles Lakers", "LAL", "Lakers")

        Returns:
            NBA team ID (e.g., 1610612747) or None if not found.
        """
        normalized = self._normalize(name)

        # Handle common ESPN variations
        name_aliases = {
            "la clippers": "los angeles clippers",
            "la lakers": "los angeles lakers",
        }
        if normalized in name_aliases:
            normalized = name_aliases[normalized]

        for team_id, info in self._teams.items():
            # Check exact matches first
            if normalized == self._normalize(info["full_name"]):
                return team_id
            if normalized == self._normalize(info["abbreviation"]):
                return team_id
            if normalized == self._normalize(info["nickname"]):
                return team_id
            if normalized == self._normalize(info["city"]):
                return team_id

            # Check if name contains the full name or vice versa
            if normalized in self._normalize(info["full_name"]):
                return team_id
            if self._normalize(info["full_name"]) in normalized:
                return team_id

        return None

    def get_team_name(self, team_id: int) -> Optional[str]:
        """
        Get team full name from NBA team ID.

        Args:
            team_id: NBA team ID

        Returns:
            Team full name or None if not found.
        """
        if team_id in self._teams:
            return self._teams[team_id]["full_name"]
        return None

    def get_team_abbreviation(self, team_id: int) -> Optional[str]:
        """
        Get team abbreviation from NBA team ID.

        Args:
            team_id: NBA team ID

        Returns:
            Team abbreviation (e.g., "LAL") or None if not found.
        """
        if team_id in self._teams:
            return self._teams[team_id]["abbreviation"]
        return None

    def get_all_team_ids(self) -> list[int]:
        """Return all NBA team IDs."""
        return list(self._teams.keys())

