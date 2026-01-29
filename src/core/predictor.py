"""
Predictor: Main inference class for NBA game predictions.
"""

from datetime import datetime, date
from pathlib import Path
from typing import Optional, Union

import joblib
import numpy as np
from xgboost import XGBClassifier

from .elo_tracker import EloTracker
from .stats_tracker import StatsTracker
from .feature_builder import FeatureBuilder


def confidence_tier(prob: float) -> str:
    """
    Map probability to interpretable confidence tier.
    
    From game_tiers.py - non-betting confidence buckets.
    """
    if prob >= 0.75:
        return "Heavy Favorite"
    elif prob >= 0.65:
        return "Moderate Favorite"
    elif prob >= 0.55:
        return "Lean Favorite"
    elif prob >= 0.45:
        return "Toss-Up"
    elif prob >= 0.35:
        return "Lean Underdog"
    else:
        return "Strong Underdog"


class Predictor:
    """
    Main inference class for NBA game predictions.
    
    Loads XGBoost model and optional calibrator for generating
    win probability predictions.
    """

    def __init__(
        self,
        model_path: Union[str, Path],
        calibrator_path: Optional[Union[str, Path]] = None,
    ):
        """
        Initialize Predictor with model artifacts.

        Args:
            model_path: Path to XGBoost model JSON file
            calibrator_path: Optional path to calibrator pickle file.
                            If provided, predictions are calibrated.
        """
        self.model_path = Path(model_path)
        self.calibrator_path = Path(calibrator_path) if calibrator_path else None

        # Load XGBoost model
        self._model = XGBClassifier()
        self._model.load_model(str(self.model_path))

        # Load calibrator if provided
        self._calibrator = None
        if self.calibrator_path and self.calibrator_path.exists():
            self._calibrator = joblib.load(self.calibrator_path)

    def predict_proba(self, features: np.ndarray) -> float:
        """
        Get raw probability prediction for features.

        Args:
            features: Feature vector of shape (23,) or (n, 23)

        Returns:
            Probability of home win (single float or array)
        """
        # Ensure 2D input
        if features.ndim == 1:
            features = features.reshape(1, -1)

        # Get raw prediction
        proba = self._model.predict_proba(features)[:, 1]

        # Apply calibration if available
        if self._calibrator is not None:
            proba = self._calibrator.predict_proba(proba.reshape(-1, 1))[:, 1]

        # Return single value if single input
        if len(proba) == 1:
            return float(proba[0])
        return proba

    def predict(self, features: np.ndarray) -> dict:
        """
        Generate prediction with confidence tier.

        Args:
            features: Feature vector of shape (23,)

        Returns:
            Dict with:
                - prob_home_win: float
                - prob_away_win: float
                - confidence_tier: str
                - is_calibrated: bool
        """
        prob_home = self.predict_proba(features)
        prob_away = 1.0 - prob_home

        return {
            "prob_home_win": round(prob_home, 4),
            "prob_away_win": round(prob_away, 4),
            "confidence_tier": confidence_tier(prob_home),
            "is_calibrated": self._calibrator is not None,
        }

    def predict_game(
        self,
        home_id: int,
        away_id: int,
        game_date: Union[str, date, datetime],
        feature_builder: FeatureBuilder,
        ml_home: Optional[float] = None,
        ml_away: Optional[float] = None,
    ) -> dict:
        """
        End-to-end prediction for a game.

        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID
            game_date: Date of the game
            feature_builder: FeatureBuilder instance with current state
            ml_home: Home team moneyline odds (e.g., -150). Optional.
            ml_away: Away team moneyline odds (e.g., +130). Optional.

        Returns:
            Dict with prediction results and metadata
        """
        # Build features (with optional market odds)
        features = feature_builder.build_features(
            home_id, away_id, game_date,
            ml_home=ml_home, ml_away=ml_away
        )

        # Get prediction
        result = self.predict(features)

        # Add metadata
        result["home_team_id"] = home_id
        result["away_team_id"] = away_id
        result["game_date"] = (
            game_date if isinstance(game_date, str) 
            else game_date.isoformat()[:10]
        )

        return result

    def predict_batch(
        self,
        games: list[dict],
        feature_builder: FeatureBuilder,
        odds_dict: Optional[dict[tuple[int, int], tuple[Optional[float], Optional[float]]]] = None,
    ) -> list[dict]:
        """
        Predict multiple games at once.

        Args:
            games: List of dicts with keys: home_id, away_id, game_date
            feature_builder: FeatureBuilder instance
            odds_dict: Optional dict mapping (home_id, away_id) to (ml_home, ml_away).
                      If provided, odds are used as features when available.

        Returns:
            List of prediction results
        """
        results = []
        for game in games:
            # Look up odds if available
            ml_home, ml_away = None, None
            if odds_dict:
                key = (game["home_id"], game["away_id"])
                if key in odds_dict:
                    ml_home, ml_away = odds_dict[key]

            result = self.predict_game(
                home_id=game["home_id"],
                away_id=game["away_id"],
                game_date=game["game_date"],
                feature_builder=feature_builder,
                ml_home=ml_home,
                ml_away=ml_away,
            )
            results.append(result)
        return results

    @property
    def is_calibrated(self) -> bool:
        """Whether predictions are calibrated."""
        return self._calibrator is not None

    def __repr__(self) -> str:
        cal_status = "calibrated" if self.is_calibrated else "uncalibrated"
        return f"Predictor({self.model_path.name}, {cal_status})"

