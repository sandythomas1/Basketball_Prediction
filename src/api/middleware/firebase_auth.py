"""
Firebase Authentication middleware for FastAPI.

Verifies Firebase ID tokens passed in the Authorization header.
Configurable via FIREBASE_AUTH_REQUIRED environment variable.
"""

from __future__ import annotations

import os
from typing import Optional

import firebase_admin
from firebase_admin import auth as firebase_auth, credentials
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

_firebase_initialized = False
_bearer_scheme = HTTPBearer(auto_error=False)


def _ensure_firebase():
    """Lazily initialize the Firebase Admin SDK (once)."""
    global _firebase_initialized
    if _firebase_initialized:
        return

    if not firebase_admin._apps:
        options = {}
        db_url = os.getenv("FIREBASE_DATABASE_URL")
        if db_url:
            options["databaseURL"] = db_url

        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if cred_path:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred, options)
        else:
            firebase_admin.initialize_app(options=options)
    _firebase_initialized = True


def _auth_required() -> bool:
    """Check whether token verification is enforced."""
    return os.getenv("FIREBASE_AUTH_REQUIRED", "false").lower() in ("true", "1", "yes")


class FirebaseUser:
    """Lightweight wrapper around a verified Firebase token."""

    def __init__(self, uid: str, email: Optional[str], token: dict):
        self.uid = uid
        self.email = email
        self.token = token


async def verify_firebase_token(
    request: Request,
    credential: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> Optional[FirebaseUser]:
    """
    FastAPI dependency that verifies the Firebase ID token.

    When FIREBASE_AUTH_REQUIRED=true, unauthenticated requests receive 401.
    When false (default / dev mode), unauthenticated requests pass through
    with user=None so endpoints still work locally without Firebase.
    """
    required = _auth_required()

    if credential is None or not credential.credentials:
        if required:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing authorization token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return None

    try:
        _ensure_firebase()
        decoded = firebase_auth.verify_id_token(credential.credentials)
        return FirebaseUser(
            uid=decoded["uid"],
            email=decoded.get("email"),
            token=decoded,
        )
    except firebase_admin.exceptions.FirebaseError as exc:
        print(f"Firebase auth error: {exc}")
        if required:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return None
    except Exception as exc:
        print(f"Token verification error: {exc}")
        if required:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token verification failed",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return None
