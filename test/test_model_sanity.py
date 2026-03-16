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

        prob = p.predict(features)
        assert 0.0 <= prob <= 1.0

    def test_batch_predict(self):
        from core.predictor import Predictor
        p = Predictor(
            MODEL_PATH,
            CALIBRATOR_PATH if CALIBRATOR_PATH.exists() else None,
        )

        batch = np.zeros((5, 31))
        for i in range(5):
            batch[i, 0] = 1500 + i * 20
            batch[i, 1] = 1500 - i * 20
            batch[i, 2] = i * 40
            batch[i, 3] = 0.5 + i * 0.05

        probs = p.predict_batch(batch)
        assert len(probs) == 5
        for prob in probs:
            assert 0.0 <= prob <= 1.0
