"""
PlayoffStateManager: Unified state load/save for playoff tracker state.

Mirrors StateManager but manages playoff-specific files:
  - state/playoff_bracket.json  (PlayoffSeriesTracker)
  - state/playoff_elo.json      (EloTracker, initialized from regular season Elo)
  - state/playoff_metadata.json (round, dates, games processed)
"""

import json
import shutil
from datetime import datetime, date
from pathlib import Path
from typing import Optional, Tuple

from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker
from .playoff_series_tracker import PlayoffSeriesTracker


class PlayoffStateManager:
    """
    Manages all playoff state files.

    Provides atomic load/save operations with backup support
    and metadata tracking. Keeps playoff state completely separate
    from the regular season state.
    """

    VERSION = "1.0"

    def __init__(self, state_dir: Optional[Path] = None, season: int = 2026):
        """
        Initialize PlayoffStateManager.

        Args:
            state_dir: Directory for state files. If None, uses default location.
            season: NBA season year (e.g. 2026 for the 2025-26 season).
        """
        if state_dir is None:
            state_dir = Path(__file__).parent.parent.parent / "state"

        self.state_dir = Path(state_dir)
        self.season = season

        # Playoff-specific file paths — completely separate from regular season
        self.bracket_path = self.state_dir / "playoff_bracket.json"
        self.elo_path = self.state_dir / "playoff_elo.json"
        self.metadata_path = self.state_dir / "playoff_metadata.json"

        # Regular season elo path (read-only, used for initialization)
        self._regular_elo_path = self.state_dir / "elo.json"

    def _ensure_dir(self) -> None:
        """Ensure state directory exists."""
        self.state_dir.mkdir(parents=True, exist_ok=True)

    def _create_backup(self, path: Path) -> None:
        """Create backup of a file before overwriting."""
        if path.exists():
            backup_path = path.with_suffix(path.suffix + ".bak")
            shutil.copy2(path, backup_path)

    def _load_metadata(self) -> dict:
        """Load metadata file or return defaults."""
        if self.metadata_path.exists():
            with open(self.metadata_path, "r", encoding="utf-8") as f:
                return json.load(f)
        return {
            "season": self.season,
            "playoffs_start_date": None,
            "current_round": "first_round",
            "last_processed_date": None,
            "last_updated": None,
            "games_processed_total": 0,
            "version": self.VERSION,
        }

    def _save_metadata(self, metadata: dict) -> None:
        """Save metadata file."""
        self._ensure_dir()
        metadata["version"] = self.VERSION
        with open(self.metadata_path, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2)

    def exists(self) -> bool:
        """Check if playoff state files exist."""
        return self.bracket_path.exists() and self.elo_path.exists()

    def load(self) -> Tuple[EloTracker, StatsTracker, PlayoffSeriesTracker]:
        """
        Load all playoff tracker state from files.

        For playoff Elo: loads from playoff_elo.json if it exists,
        otherwise copies end-of-season Elo from the regular season file.

        Returns:
            Tuple of (EloTracker, StatsTracker, PlayoffSeriesTracker)
        """
        # Load playoff Elo (isolated copy from regular season)
        if self.elo_path.exists():
            elo_tracker = EloTracker.from_file(self.elo_path)
        elif self._regular_elo_path.exists():
            # First run of playoffs — copy regular season Elo as starting point
            elo_tracker = EloTracker.from_file(self._regular_elo_path)
            print(f"  ℹ️  Initialized playoff Elo from regular season state")
        else:
            elo_tracker = EloTracker()

        # Load regular-season rolling stats (used for early playoff predictions)
        # Playoff games get appended to this window naturally over time
        regular_stats_path = self.state_dir / "stats.json"
        if regular_stats_path.exists():
            stats_tracker = StatsTracker.from_file(regular_stats_path)
        else:
            stats_tracker = StatsTracker()

        # Load bracket / series tracker
        if self.bracket_path.exists():
            series_tracker = PlayoffSeriesTracker.from_file(self.bracket_path)
        else:
            series_tracker = PlayoffSeriesTracker(season=self.season)

        return elo_tracker, stats_tracker, series_tracker

    def save(
        self,
        elo_tracker: EloTracker,
        stats_tracker: StatsTracker,
        series_tracker: PlayoffSeriesTracker,
        create_backup: bool = True,
    ) -> None:
        """
        Save all playoff tracker state to files.

        NOTE: This writes to playoff_elo.json and playoff_bracket.json only.
        The regular season stats.json is also updated (playoff games flow
        into the rolling window naturally).

        Args:
            elo_tracker: Playoff EloTracker instance to save
            stats_tracker: StatsTracker instance to save (shared rolling window)
            series_tracker: PlayoffSeriesTracker instance to save
            create_backup: Whether to create .bak files before saving
        """
        self._ensure_dir()

        if create_backup:
            self._create_backup(self.elo_path)
            self._create_backup(self.bracket_path)

        # Save playoff Elo (isolated from regular season)
        elo_tracker.save(self.elo_path)

        # Save series tracker (bracket state)
        series_tracker.save(self.bracket_path)

        # Update shared rolling stats (playoff games extend the regular window)
        regular_stats_path = self.state_dir / "stats.json"
        if create_backup:
            self._create_backup(regular_stats_path)
        stats_tracker.save(regular_stats_path)

        # Update metadata
        metadata = self._load_metadata()
        metadata["last_updated"] = datetime.now().isoformat()
        metadata["current_round"] = series_tracker.current_round
        self._save_metadata(metadata)

    def get_last_processed_date(self) -> Optional[date]:
        """Get the last date for which games were processed."""
        metadata = self._load_metadata()
        date_str = metadata.get("last_processed_date")
        if date_str:
            return datetime.fromisoformat(date_str).date()
        return None

    def set_last_processed_date(self, processed_date: "date | str") -> None:
        """Set the last processed date."""
        if isinstance(processed_date, date):
            processed_date = processed_date.isoformat()
        metadata = self._load_metadata()
        metadata["last_processed_date"] = processed_date
        metadata["last_updated"] = datetime.now().isoformat()
        self._save_metadata(metadata)

    def increment_games_processed(self, count: int = 1) -> int:
        """Increment the total playoff games processed counter."""
        metadata = self._load_metadata()
        metadata["games_processed_total"] = metadata.get("games_processed_total", 0) + count
        self._save_metadata(metadata)
        return metadata["games_processed_total"]

    def get_metadata(self) -> dict:
        """Get all metadata."""
        return self._load_metadata()

    def restore_backup(self) -> bool:
        """Restore state from backup files."""
        elo_backup = self.elo_path.with_suffix(".json.bak")
        bracket_backup = self.bracket_path.with_suffix(".json.bak")

        if not (elo_backup.exists() and bracket_backup.exists()):
            return False

        shutil.copy2(elo_backup, self.elo_path)
        shutil.copy2(bracket_backup, self.bracket_path)
        return True

    def __repr__(self) -> str:
        exists = "exists" if self.exists() else "missing"
        return f"PlayoffStateManager({self.state_dir}, season={self.season}, {exists})"
