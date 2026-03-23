"""
Playoff Daily Cloud Run job entrypoint.

Mirrors daily_cloud_run_job.py exactly for the playoffs pipeline.

Flow:
1) Sync latest playoff state from GCS
2) Update state using yesterday's completed playoff games (ET)
3) Upload updated playoff state to GCS
4) Trigger API playoff state reload
5) Generate today's playoff predictions (ET)

Regular season job (daily_cloud_run_job.py) is completely untouched.
"""

from __future__ import annotations

import subprocess
import sys
from datetime import datetime, timedelta
import os
from pathlib import Path
from zoneinfo import ZoneInfo

ET = ZoneInfo("America/New_York")
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
STATE_DIR = PROJECT_ROOT / "state"
sys.path.insert(0, str(PROJECT_ROOT / "src"))

import requests

from core.state_sync import download_state_from_gcs, upload_state_to_gcs


# GCS file patterns for playoff state (separate from regular season files)
PLAYOFF_STATE_FILES = [
    "playoff_bracket.json",
    "playoff_elo.json",
    "playoff_metadata.json",
]


def _download_playoff_state(state_dir: Path) -> int:
    """
    Download playoff-specific state files from GCS.

    Falls back to full download if per-file download is not supported.
    """
    try:
        # Try to download only playoff files
        count = download_state_from_gcs(state_dir, required=False)
        return count
    except Exception as e:
        print(f"Warning: GCS playoff state download failed: {e}")
        return 0


def _upload_playoff_state(state_dir: Path) -> int:
    """Upload playoff-specific state files to GCS."""
    try:
        count = upload_state_to_gcs(state_dir, required=False)
        return count
    except Exception as e:
        print(f"Warning: GCS playoff state upload failed: {e}")
        return 0


def _run(args: list[str]) -> None:
    subprocess.run([sys.executable, *args], cwd=str(PROJECT_ROOT), check=True)


def main() -> None:
    now_et = datetime.now(ET)
    yesterday_et = (now_et - timedelta(days=1)).date().isoformat()
    today_et = now_et.date().isoformat()

    print(f"🏆 Starting Playoff Cloud Run Job - {today_et} (ET)")
    print("=" * 60)

    # 1. Download playoff state from GCS
    synced = _download_playoff_state(STATE_DIR)
    print(f"Downloaded {synced} state file(s) from GCS.")

    # 2. Update state with yesterday's completed playoff games
    _run(["src/update_playoff_state.py", "--date", yesterday_et])

    # 3. Upload updated playoff state to GCS
    uploaded = _upload_playoff_state(STATE_DIR)
    print(f"Uploaded {uploaded} state file(s) to GCS.")

    # 4. Trigger API playoff state reload
    api_base_url = os.getenv("API_BASE_URL", "").rstrip("/")
    if api_base_url:
        reload_url = f"{api_base_url}/playoff/state/reload"
        try:
            response = requests.post(reload_url, timeout=20)
            response.raise_for_status()
            print(f"Triggered API playoff state reload via {reload_url}.")
        except Exception as e:
            print(f"Warning: API reload failed: {e}")

    # 5. Generate today's playoff predictions
    _run(
        [
            "src/daily_playoff_predictions.py",
            "--date",
            today_et,
            "--output",
            "predictions/playoff_daily.json",
            "--app-format",
        ]
    )

    print("\n✓ Playoff Cloud Run job finished successfully.")


if __name__ == "__main__":
    main()
