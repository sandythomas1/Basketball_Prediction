"""
Cloud Storage sync helpers for prediction state files.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable

from google.cloud import storage


DEFAULT_STATE_FILES = ("elo.json", "stats.json", "metadata.json")


def _state_prefix() -> str:
    return os.getenv("STATE_PREFIX", "state").strip("/")


def _state_bucket(required: bool = False) -> str | None:
    bucket = os.getenv("STATE_BUCKET")
    if required and not bucket:
        raise RuntimeError("STATE_BUCKET is required but was not provided.")
    return bucket


def _blob_name(prefix: str, file_name: str) -> str:
    return f"{prefix}/{file_name}" if prefix else file_name


def download_state_from_gcs(
    state_dir: Path,
    *,
    files: Iterable[str] = DEFAULT_STATE_FILES,
    required: bool = False,
) -> int:
    """
    Download state files from GCS into state_dir.

    Returns number of downloaded files.
    """
    bucket_name = _state_bucket(required=required)
    if not bucket_name:
        return 0

    prefix = _state_prefix()
    client = storage.Client()
    bucket = client.bucket(bucket_name)

    state_dir.mkdir(parents=True, exist_ok=True)

    downloaded = 0
    for file_name in files:
        blob = bucket.blob(_blob_name(prefix, file_name))
        if not blob.exists(client=client):
            continue
        blob.download_to_filename(str(state_dir / file_name))
        downloaded += 1

    return downloaded


def upload_state_to_gcs(
    state_dir: Path,
    *,
    files: Iterable[str] = DEFAULT_STATE_FILES,
    required: bool = False,
) -> int:
    """
    Upload state files from state_dir to GCS.

    Returns number of uploaded files.
    """
    bucket_name = _state_bucket(required=required)
    if not bucket_name:
        return 0

    prefix = _state_prefix()
    client = storage.Client()
    bucket = client.bucket(bucket_name)

    uploaded = 0
    for file_name in files:
        file_path = state_dir / file_name
        if not file_path.exists():
            continue
        blob = bucket.blob(_blob_name(prefix, file_name))
        blob.upload_from_filename(str(file_path), content_type="application/json")
        uploaded += 1

    return uploaded
