"""
Integration tests for the FastAPI endpoints.

Uses FastAPI's TestClient (backed by httpx) so no running server is needed.
The PredictionService is mocked to avoid requiring model files and state.
"""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


# ---------------------------------------------------------------------------
# Build a lightweight mock PredictionService
# ---------------------------------------------------------------------------

def _mock_prediction_service():
    svc = MagicMock()

    # team_mapper
    svc.team_mapper.get_all_team_ids.return_value = [1, 2]
    svc.team_mapper.get_team_name.side_effect = lambda tid: {1: "Los Angeles Lakers", 2: "Boston Celtics"}.get(tid, "Unknown")
    svc.team_mapper.get_team_abbreviation.side_effect = lambda tid: {1: "LAL", 2: "BOS"}.get(tid, "UNK")
    svc.team_mapper.get_team_id.side_effect = lambda name: {"Lakers": 1, "Celtics": 2, "Los Angeles Lakers": 1, "Boston Celtics": 2}.get(name)

    # state_manager
    svc.state_manager.exists.return_value = True
    svc.state_manager.get_metadata.return_value = {
        "last_processed_date": "2026-03-14",
        "last_updated": "2026-03-14T09:00:00",
        "games_processed_total": 1200,
        "version": "3",
    }

    # elo_tracker
    svc.elo_tracker.get_elo.side_effect = lambda tid: 1550.0 if tid == 1 else 1500.0

    # predictor
    svc.predictor.predict_game.return_value = {
        "prob_home_win": 0.62,
        "prob_away_win": 0.38,
        "confidence_tier": "Lean Favorite",
        "confidence_score": 65,
        "confidence_qualifier": "Moderate",
        "confidence_factors": {
            "consensus_agreement": 20,
            "feature_alignment": 18,
            "form_stability": 12,
            "schedule_context": 8,
            "matchup_history": 7,
        },
    }

    # feature_builder
    svc.feature_builder.build_features_dict.return_value = {
        "elo_home": 1550.0,
        "elo_away": 1500.0,
        "win_roll_home": 0.7,
        "win_roll_away": 0.5,
        "home_rest_days": 2,
        "away_rest_days": 1,
        "home_b2b": 0,
        "away_b2b": 1,
    }

    # injury_client
    svc.injury_client.get_matchup_injury_summary.return_value = {
        "home_injuries": ["Anthony Davis (Q)"],
        "away_injuries": [],
        "advantage": "away",
    }

    # odds
    svc.get_odds_for_game.return_value = (None, None)

    # espn_client
    svc.espn_client.get_games.return_value = []
    svc.espn_client.get_scheduled_games.return_value = []

    # reload
    svc.reload_state.return_value = None

    return svc


# ---------------------------------------------------------------------------
# Fixture: build the test client with the mock service injected
# ---------------------------------------------------------------------------

@pytest.fixture()
def client():
    """Yield a TestClient wired to the FastAPI app with mocked dependencies."""
    mock_svc = _mock_prediction_service()

    from fastapi.testclient import TestClient
    from src.api.dependencies import get_prediction_service
    from src.api.main import app

    def override_get_prediction_service():
        return mock_svc

    app.dependency_overrides[get_prediction_service] = override_get_prediction_service
    try:
        with patch("core.state_sync.download_state_from_gcs", return_value=0):
            yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestHealthEndpoints:
    def test_health(self, client):
        r = client.get("/health")
        assert r.status_code == 200
        body = r.json()
        assert body["status"] == "ok"
        assert "timestamp" in body

    def test_root(self, client):
        r = client.get("/")
        assert r.status_code == 200
        body = r.json()
        assert "endpoints" in body
        assert body["name"] == "NBA Game Prediction API"

    def test_state_info(self, client):
        r = client.get("/state/info")
        assert r.status_code == 200
        body = r.json()
        assert body["state_exists"] is True
        assert body["games_processed_total"] == 1200

    def test_teams_list(self, client):
        r = client.get("/teams")
        assert r.status_code == 200
        body = r.json()
        assert body["count"] == 2
        assert any(t["abbreviation"] == "LAL" for t in body["teams"])


class TestPredictionEndpoints:
    def test_predict_game(self, client):
        r = client.post("/predict/game", json={
            "home_team": "Lakers",
            "away_team": "Celtics",
        })
        assert r.status_code == 200
        body = r.json()
        assert 0 < body["home_win_prob"] < 1
        assert body["confidence"] == "Lean Favorite"
        assert body["confidence_score"] == 65

    def test_predict_game_unknown_team(self, client):
        r = client.post("/predict/game", json={
            "home_team": "Nonexistent Team",
            "away_team": "Celtics",
        })
        assert r.status_code == 400

    def test_predict_date_invalid(self, client):
        r = client.get("/predict/not-a-date")
        assert r.status_code == 400


class TestGamesEndpoints:
    def test_scoreboard(self, client):
        r = client.get("/games/scoreboard")
        assert r.status_code == 200
        body = r.json()
        assert "games" in body
        assert "count" in body

    def test_games_today(self, client):
        r = client.get("/games/today")
        assert r.status_code == 200

    def test_games_date_invalid(self, client):
        r = client.get("/games/bad-date")
        assert r.status_code == 400


class TestStateReload:
    def test_reload(self, client):
        r = client.post("/state/reload")
        assert r.status_code == 200
        assert r.json()["status"] == "ok"
