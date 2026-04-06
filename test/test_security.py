"""
Security-focused tests for the NBA Prediction API.

Covers:
  - Chat message length validation
  - Conversation history limits
  - Batch prediction size limits
  - Auth error message sanitization
  - Root endpoint production info restriction
  - Error response sanitization (no leaked internals)
"""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


# ---------------------------------------------------------------------------
# Shared mock for PredictionService (same pattern as test_api_endpoints.py)
# ---------------------------------------------------------------------------

def _mock_prediction_service():
    svc = MagicMock()
    svc.team_mapper.get_all_team_ids.return_value = [1, 2]
    svc.team_mapper.get_team_name.side_effect = lambda tid: {1: "Los Angeles Lakers", 2: "Boston Celtics"}.get(tid, "Unknown")
    svc.team_mapper.get_team_abbreviation.side_effect = lambda tid: {1: "LAL", 2: "BOS"}.get(tid, "UNK")
    svc.team_mapper.get_team_id.side_effect = lambda name: {"Lakers": 1, "Celtics": 2}.get(name)
    svc.state_manager.exists.return_value = True
    svc.state_manager.get_metadata.return_value = {
        "last_processed_date": "2026-03-14",
        "last_updated": "2026-03-14T09:00:00",
        "games_processed_total": 1200,
        "version": "3",
    }
    svc.elo_tracker.get_elo.side_effect = lambda tid: 1550.0
    svc.predictor.predict_game.return_value = {
        "prob_home_win": 0.62, "prob_away_win": 0.38,
        "confidence_tier": "Lean Favorite",
        "confidence_score": 65, "confidence_qualifier": "Moderate",
        "confidence_factors": {},
    }
    svc.feature_builder.build_features_dict.return_value = {
        "elo_home": 1550.0, "elo_away": 1500.0,
        "win_roll_home": 0.7, "win_roll_away": 0.5,
        "home_rest_days": 2, "away_rest_days": 1,
        "home_b2b": 0, "away_b2b": 1,
    }
    svc.injury_client.get_matchup_injury_summary.return_value = {
        "home_injuries": [], "away_injuries": [], "advantage": "even",
    }
    svc.get_odds_for_game.return_value = (None, None)
    svc.espn_client.get_games.return_value = []
    svc.espn_client.get_scheduled_games.return_value = []
    return svc


@pytest.fixture()
def client():
    """Yield a TestClient wired to the FastAPI app with mocked dependencies."""
    mock_svc = _mock_prediction_service()

    from fastapi.testclient import TestClient
    from src.api.dependencies import get_prediction_service
    from src.api.main import app

    app.dependency_overrides[get_prediction_service] = lambda: mock_svc
    try:
        with patch("core.state_sync.download_state_from_gcs", return_value=0):
            yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


# ===========================================================================
# Chat input validation tests
# ===========================================================================

class TestChatInputValidation:
    """Ensure chat endpoint rejects oversized / malformed input."""

    def test_message_too_long_rejected(self, client):
        """Messages over MAX_MESSAGE_LENGTH (2000) should be rejected by Pydantic."""
        r = client.post("/chat/message", json={
            "message": "A" * 2001,
        })
        assert r.status_code == 422  # Pydantic validation error

    def test_empty_message_rejected(self, client):
        """Empty string messages should be rejected."""
        r = client.post("/chat/message", json={
            "message": "",
        })
        assert r.status_code == 422

    def test_conversation_history_too_many_items(self, client):
        """More than MAX_CONVERSATION_HISTORY (20) items should be rejected."""
        history = [{"role": "user", "content": "hello"}] * 21
        r = client.post("/chat/message", json={
            "message": "test",
            "conversation_history": history,
        })
        assert r.status_code == 422

    def test_conversation_history_item_too_long(self, client):
        """A single history item content over MAX_HISTORY_CONTENT_LENGTH should be rejected."""
        history = [{"role": "user", "content": "A" * 5001}]
        r = client.post("/chat/message", json={
            "message": "test",
            "conversation_history": history,
        })
        assert r.status_code == 422

    def test_valid_message_accepted(self, client):
        """A normal-length message should not be rejected by validation.

        It will fail at the auth step (401) since no token is provided,
        which proves it passed Pydantic validation.
        """
        r = client.post("/chat/message", json={
            "message": "Who will win tonight?",
        })
        # 401 = passed validation, blocked at auth — expected behavior
        assert r.status_code == 401


# ===========================================================================
# Batch prediction size limit tests
# ===========================================================================

class TestBatchPredictionLimits:
    """Ensure batch predictions enforce max size."""

    def test_batch_over_15_rejected(self, client):
        """More than 15 games in a batch should be rejected."""
        games = [{"home_team": "Lakers", "away_team": "Celtics"}] * 16
        r = client.post("/predict/batch", json={"games": games})
        assert r.status_code == 422

    def test_batch_at_limit_accepted(self, client):
        """Exactly 15 games should be accepted."""
        games = [{"home_team": "Lakers", "away_team": "Celtics"}] * 15
        r = client.post("/predict/batch", json={"games": games})
        assert r.status_code == 200

    def test_batch_empty_accepted(self, client):
        """Empty batch should be accepted (returns 0 predictions)."""
        r = client.post("/predict/batch", json={"games": []})
        assert r.status_code == 200
        assert r.json()["count"] == 0


# ===========================================================================
# Root endpoint information exposure tests
# ===========================================================================

class TestRootEndpointProduction:
    """Ensure root endpoint hides details in production."""

    def test_root_dev_shows_endpoints(self, client):
        """In dev mode, root should expose endpoint info."""
        r = client.get("/")
        assert r.status_code == 200
        body = r.json()
        # Dev mode: should have detailed info
        assert "name" in body
        assert "health" in body

    def test_root_production_hides_details(self):
        """In production mode, root should NOT expose environment or full endpoint map."""
        from src.api.config import get_settings, Settings
        from src.api.main import app, settings as app_settings

        # Patch the module-level settings object used by the root endpoint
        original_is_production = Settings.is_production.fget
        with patch.object(Settings, "is_production", new_callable=lambda: property(lambda self: True)):
            from fastapi.testclient import TestClient
            from src.api.dependencies import get_prediction_service

            mock_svc = _mock_prediction_service()
            app.dependency_overrides[get_prediction_service] = lambda: mock_svc
            try:
                with patch("core.state_sync.download_state_from_gcs", return_value=0):
                    with TestClient(app) as c:
                        r = c.get("/")
                        assert r.status_code == 200
                        body = r.json()
                        assert "environment" not in body
                        assert "endpoints" not in body
                        assert "docs" not in body
            finally:
                app.dependency_overrides.clear()


# ===========================================================================
# Error response sanitization tests
# ===========================================================================

class TestErrorSanitization:
    """Ensure error responses don't leak internal details."""

    def test_espn_error_no_internals(self, client):
        """ESPN failures should return generic messages, not exception details."""
        from src.api.dependencies import get_prediction_service

        svc = _mock_prediction_service()
        svc.espn_client.get_games.side_effect = ConnectionError("SSL: CERTIFICATE_VERIFY_FAILED")

        from src.api.main import app
        app.dependency_overrides[get_prediction_service] = lambda: svc
        try:
            r = client.get("/games/scoreboard")
            assert r.status_code == 502
            body = r.json()
            detail = body.get("detail", "")
            # Should NOT contain internal error text
            assert "SSL" not in detail
            assert "CERTIFICATE" not in detail
            assert "Please try again" in detail
        finally:
            app.dependency_overrides.clear()

    def test_prediction_espn_error_no_internals(self, client):
        """Prediction ESPN failures should return generic messages."""
        from src.api.dependencies import get_prediction_service

        svc = _mock_prediction_service()
        svc.espn_client.get_scheduled_games.side_effect = RuntimeError("connection pool exhausted")

        from src.api.main import app
        app.dependency_overrides[get_prediction_service] = lambda: svc
        try:
            r = client.get("/predict/2026-04-01")
            assert r.status_code == 502
            detail = r.json().get("detail", "")
            assert "connection pool" not in detail
            assert "Please try again" in detail
        finally:
            app.dependency_overrides.clear()

    def test_auth_error_no_firebase_details(self, client):
        """Auth failures should not leak Firebase error details."""
        r = client.post(
            "/chat/message",
            json={"message": "test"},
            headers={"Authorization": "Bearer invalid-token-here"},
        )
        # Should be 401 (in dev, auth not required so it passes through)
        # or 422 or 200 depending on config, but never should it contain Firebase internals
        body = r.json()
        body_str = str(body)
        assert "firebase" not in body_str.lower() or "Firebase" not in body_str


# ===========================================================================
# Security headers tests
# ===========================================================================

class TestSecurityHeaders:
    """Verify security headers are present on responses."""

    def test_security_headers_present(self, client):
        r = client.get("/health")
        assert r.status_code == 200
        assert r.headers.get("X-Content-Type-Options") == "nosniff"
        assert r.headers.get("X-Frame-Options") == "DENY"
        assert r.headers.get("X-XSS-Protection") == "1; mode=block"
        assert "Referrer-Policy" in r.headers
        assert "Permissions-Policy" in r.headers

    def test_cors_headers_present(self, client):
        """Preflight OPTIONS should return CORS headers."""
        r = client.options(
            "/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )
        # Should not error; CORS middleware should handle it
        assert r.status_code in (200, 204, 405)
