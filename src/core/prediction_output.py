"""
PredictionOutput: Formats and exports predictions for app consumption.
"""

import json
import csv
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import List, Optional


@dataclass
class GamePrediction:
    """A single game prediction with all relevant data."""
    
    # Game identification
    game_date: str
    game_time: Optional[str]
    home_team: str
    away_team: str
    home_team_id: int
    away_team_id: int
    
    # Predictions
    prob_home_win: float
    prob_away_win: float
    confidence_tier: str
    
    # Current state
    home_elo: float
    away_elo: float
    elo_diff: float
    
    # Rolling stats
    home_win_pct: float
    away_win_pct: float
    home_margin: float
    away_margin: float
    
    # Rest info
    home_rest_days: int
    away_rest_days: int
    home_b2b: bool
    away_b2b: bool
    
    def to_dict(self) -> dict:
        """Convert to dictionary."""
        return asdict(self)

    def to_app_format(self) -> dict:
        """
        Convert to simplified format for app consumption.
        
        Returns a dict with only the fields needed by the Flutter app.
        """
        return {
            "game_date": self.game_date,
            "game_time": self.game_time,
            "home_team": self.home_team,
            "away_team": self.away_team,
            "home_team_id": self.home_team_id,
            "away_team_id": self.away_team_id,
            "prediction": {
                "home_win_prob": round(self.prob_home_win, 3),
                "away_win_prob": round(self.prob_away_win, 3),
                "confidence": self.confidence_tier,
                "favored": "home" if self.prob_home_win > 0.5 else "away",
            },
            "context": {
                "home_elo": round(self.home_elo, 1),
                "away_elo": round(self.away_elo, 1),
                "home_recent_wins": round(self.home_win_pct, 2),
                "away_recent_wins": round(self.away_win_pct, 2),
                "home_rest_days": self.home_rest_days,
                "away_rest_days": self.away_rest_days,
                "home_b2b": self.home_b2b,
                "away_b2b": self.away_b2b,
            },
        }


class PredictionOutput:
    """
    Handles formatting and exporting predictions.
    
    Supports multiple output formats for different consumers.
    """

    def __init__(self, predictions: List[GamePrediction]):
        """
        Initialize with predictions.

        Args:
            predictions: List of GamePrediction objects
        """
        self.predictions = predictions
        self.generated_at = datetime.now().isoformat()

    def to_json(self, pretty: bool = True) -> str:
        """
        Convert predictions to JSON string.

        Args:
            pretty: Whether to format with indentation

        Returns:
            JSON string
        """
        data = {
            "generated_at": self.generated_at,
            "count": len(self.predictions),
            "predictions": [p.to_dict() for p in self.predictions],
        }
        if pretty:
            return json.dumps(data, indent=2)
        return json.dumps(data)

    def to_app_json(self, pretty: bool = True) -> str:
        """
        Convert to simplified JSON format for app consumption.

        Args:
            pretty: Whether to format with indentation

        Returns:
            JSON string in app format
        """
        data = {
            "generated_at": self.generated_at,
            "count": len(self.predictions),
            "games": [p.to_app_format() for p in self.predictions],
        }
        if pretty:
            return json.dumps(data, indent=2)
        return json.dumps(data)

    def save_json(self, path: Path, app_format: bool = False) -> None:
        """
        Save predictions to JSON file.

        Args:
            path: Output file path
            app_format: Whether to use simplified app format
        """
        path.parent.mkdir(parents=True, exist_ok=True)
        content = self.to_app_json() if app_format else self.to_json()
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

    def to_csv(self) -> str:
        """
        Convert predictions to CSV string.

        Returns:
            CSV formatted string
        """
        if not self.predictions:
            return ""

        import io
        output = io.StringIO()
        
        # Get field names from first prediction
        fieldnames = list(self.predictions[0].to_dict().keys())
        
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        for pred in self.predictions:
            writer.writerow(pred.to_dict())
        
        return output.getvalue()

    def save_csv(self, path: Path) -> None:
        """
        Save predictions to CSV file.

        Args:
            path: Output file path
        """
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(self.to_csv())

    def print_summary(self) -> None:
        """Print a human-readable summary of predictions."""
        print(f"\n{'=' * 70}")
        print(f"Game Predictions - Generated {self.generated_at[:19]}")
        print(f"{'=' * 70}")
        
        if not self.predictions:
            print("\nNo predictions to display.")
            return

        for pred in self.predictions:
            time_str = f" @ {pred.game_time}" if pred.game_time else ""
            print(f"\n{pred.away_team} @ {pred.home_team}{time_str}")
            print(f"  Prediction: {pred.confidence_tier}")
            
            if pred.prob_home_win > pred.prob_away_win:
                favored = pred.home_team
                prob = pred.prob_home_win
            else:
                favored = pred.away_team
                prob = pred.prob_away_win
            
            print(f"  Favored: {favored} ({prob:.1%})")
            print(f"  Elo: {pred.home_team[:3].upper()} {pred.home_elo:.0f} vs {pred.away_team[:3].upper()} {pred.away_elo:.0f}")
            
            # Rest situation
            rest_notes = []
            if pred.home_b2b:
                rest_notes.append(f"{pred.home_team[:3].upper()} on B2B")
            if pred.away_b2b:
                rest_notes.append(f"{pred.away_team[:3].upper()} on B2B")
            if rest_notes:
                print(f"  Note: {', '.join(rest_notes)}")

        print(f"\n{'=' * 70}")
        print(f"Total: {len(self.predictions)} games")

    def __len__(self) -> int:
        return len(self.predictions)

    def __repr__(self) -> str:
        return f"PredictionOutput({len(self.predictions)} predictions)"

