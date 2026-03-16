"""
Daily Cloud Run job entrypoint.

Flow:
1) Sync latest state from GCS
2) Update state using yesterday's completed games (ET)
3) Upload updated state to GCS
4) Generate today's predictions (ET)
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


def _run(args: list[str]) -> None:
    subprocess.run([sys.executable, *args], cwd=str(PROJECT_ROOT), check=True)


def main() -> None:
    now_et = datetime.now(ET)
    yesterday_et = (now_et - timedelta(days=1)).date().isoformat()
    today_et = now_et.date().isoformat()

    synced = download_state_from_gcs(STATE_DIR, required=True)
    print(f"Downloaded {synced} state file(s) from GCS.")

    _run(["src/update_state.py", "--date", yesterday_et])

    uploaded = upload_state_to_gcs(STATE_DIR, required=True)
    print(f"Uploaded {uploaded} state file(s) to GCS.")

    api_base_url = os.getenv("API_BASE_URL", "").rstrip("/")
    if api_base_url:
        reload_url = f"{api_base_url}/state/reload"
        response = requests.post(reload_url, timeout=20)
        response.raise_for_status()
        print(f"Triggered API state reload via {reload_url}.")

    _run(
        [
            "src/daily_predictions.py",
            "--date",
            today_et,
            "--output",
            "predictions/daily.json",
            "--app-format",
        ]
    )

    print("Daily Cloud Run job finished successfully.")


if __name__ == "__main__":
    main()
