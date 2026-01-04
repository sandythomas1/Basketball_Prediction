"""
StateManager: Unified state load/save for all tracker state.
"""

import json
import shutil
from datetime import datetime, date
from pathlib import Path
from typing import Optional, Tuple

from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker


class StateManager:
    """
    Manages all state files for the prediction system.
    
    Provides atomic load/save operations with backup support
    and metadata tracking.
    """

    VERSION = "1.0"

    def __init__(self, state_dir: Optional[Path] = None):
        """
        Initialize StateManager.

        Args:
            state_dir: Directory for state files. If None, uses default location.
        """
        if state_dir is None:
            state_dir = Path(__file__).parent.parent.parent / "state"
        
        self.state_dir = Path(state_dir)
        self.elo_path = self.state_dir / "elo.json"
        self.stats_path = self.state_dir / "stats.json"
        self.metadata_path = self.state_dir / "metadata.json"

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
        """Check if state files exist."""
        return self.elo_path.exists() and self.stats_path.exists()

    def load(self) -> Tuple[EloTracker, StatsTracker]:
        """
        Load all tracker state from files.

        Returns:
            Tuple of (EloTracker, StatsTracker) instances.
            Returns fresh trackers if files don't exist.
        """
        if self.elo_path.exists():
            elo_tracker = EloTracker.from_file(self.elo_path)
        else:
            elo_tracker = EloTracker()

        if self.stats_path.exists():
            stats_tracker = StatsTracker.from_file(self.stats_path)
        else:
            stats_tracker = StatsTracker()

        return elo_tracker, stats_tracker

    def save(
        self,
        elo_tracker: EloTracker,
        stats_tracker: StatsTracker,
        create_backup: bool = True,
    ) -> None:
        """
        Save all tracker state to files.

        Args:
            elo_tracker: EloTracker instance to save
            stats_tracker: StatsTracker instance to save
            create_backup: Whether to create .bak files before saving
        """
        self._ensure_dir()

        # Create backups if requested
        if create_backup:
            self._create_backup(self.elo_path)
            self._create_backup(self.stats_path)

        # Save tracker states
        elo_tracker.save(self.elo_path)
        stats_tracker.save(self.stats_path)

        # Update metadata
        metadata = self._load_metadata()
        metadata["last_updated"] = datetime.now().isoformat()
        self._save_metadata(metadata)

    def get_last_processed_date(self) -> Optional[date]:
        """
        Get the last date for which games were processed.

        Returns:
            date object or None if never processed
        """
        metadata = self._load_metadata()
        date_str = metadata.get("last_processed_date")
        if date_str:
            return datetime.fromisoformat(date_str).date()
        return None

    def set_last_processed_date(self, processed_date: date | str) -> None:
        """
        Set the last processed date.

        Args:
            processed_date: Date that was just processed
        """
        if isinstance(processed_date, date):
            processed_date = processed_date.isoformat()

        metadata = self._load_metadata()
        metadata["last_processed_date"] = processed_date
        metadata["last_updated"] = datetime.now().isoformat()
        self._save_metadata(metadata)

    def increment_games_processed(self, count: int = 1) -> int:
        """
        Increment the total games processed counter.

        Args:
            count: Number of games to add

        Returns:
            New total count
        """
        metadata = self._load_metadata()
        metadata["games_processed_total"] = metadata.get("games_processed_total", 0) + count
        self._save_metadata(metadata)
        return metadata["games_processed_total"]

    def get_games_processed_total(self) -> int:
        """Get total number of games processed."""
        metadata = self._load_metadata()
        return metadata.get("games_processed_total", 0)

    def get_metadata(self) -> dict:
        """Get all metadata."""
        return self._load_metadata()

    def restore_backup(self) -> bool:
        """
        Restore state from backup files.

        Returns:
            True if backup was restored, False if no backup exists
        """
        elo_backup = self.elo_path.with_suffix(".json.bak")
        stats_backup = self.stats_path.with_suffix(".json.bak")

        if not (elo_backup.exists() and stats_backup.exists()):
            return False

        shutil.copy2(elo_backup, self.elo_path)
        shutil.copy2(stats_backup, self.stats_path)
        return True

    def __repr__(self) -> str:
        exists = "exists" if self.exists() else "missing"
        return f"StateManager({self.state_dir}, {exists})"

