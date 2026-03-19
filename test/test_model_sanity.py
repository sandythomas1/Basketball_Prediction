"""
Model sanity / regression tests.

Verifies the XGBoost model file loads correctly, accepts 31 features,
and produces probabilities in [0, 1].
"""

import sys
from pathlib import Path

import pytest
import numpy as np

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

MODEL_PATH = Path(__file__).parent.parent / "models" / "xgb_v3_with_injuries.json"
CALIBRATOR_PATH = Path(__file__).parent.parent / "models" / "calibrator_v3.pkl"

NEED_MODEL = pytest.mark.skipif(
    not MODEL_PATH.exists(),
    reason="Model file not present (CI may download it separately)",
)


@NEED_MODEL
class TestModelLoading:
    def test_model_loads(self):
        from core.predictor import Predictor
        p = Predictor(
            MODEL_PATH,
            CALIBRATOR_PATH if CALIBRATOR_PATH.exists() else None,
        )
        assert p is not None

    def test_predict_returns_valid_probabilities(self):
        from core.predictor import Predictor
        p = Predictor(
            MODEL_PATH,
            CALIBRATOR_PATH if CALIBRATOR_PATH.exists() else None,
        )

        features = np.zeros(31)
        features[0] = 1550  # elo_home
        features[1] = 1450  # elo_away
        features[2] = 100   # elo_diff
        features[3] = 0.6   # elo_prob

        result = p.predict(features)
        prob = result["prob_home_win"]
        assert 0.0 <= prob <= 1.0

    def test_batch_predict(self):
        from core.predictor import Predictor
        from core.feature_builder import FeatureBuilder
        from core import EloTracker, StatsTracker, StateManager
        from pathlib import Path

        p = Predictor(
            MODEL_PATH,
            CALIBRATOR_PATH if CALIBRATOR_PATH.exists() else None,
        )
        state_dir = Path(__file__).parent.parent / "state"
        state_manager = StateManager(state_dir)
        if not state_manager.exists():
            pytest.skip("State files required for batch predict test")
        elo_tracker, stats_tracker = state_manager.load()
        feature_builder = FeatureBuilder(elo_tracker, stats_tracker)

        games = [
            {"home_id": 1610612737, "away_id": 1610612738, "game_date": "2026-03-16"},
            {"home_id": 1610612738, "away_id": 1610612737, "game_date": "2026-03-16"},
        ]
        results = p.predict_batch(games, feature_builder)
        assert len(results) == 2
        for r in results:
            assert 0.0 <= r["prob_home_win"] <= 1.0
