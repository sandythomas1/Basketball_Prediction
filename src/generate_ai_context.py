"""
Generate context files for Vertex AI Agent.

This script generates JSON files with current NBA data that can be uploaded
to Google Cloud Storage and used as grounding data for Vertex AI agents.

Usage:
    python src/generate_ai_context.py --output-dir ai_context/
    python src/generate_ai_context.py --upload-to-gcs
"""

import argparse
import json
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional

from core import (
    TeamMapper,
    StateManager,
    InjuryClient,
)


def generate_injury_report(
    injury_client: InjuryClient,
    output_path: Optional[Path] = None
) -> Dict:
    """
    Generate comprehensive injury report for all teams.
    
    Args:
        injury_client: InjuryClient instance
        output_path: If provided, save to this JSON file
    
    Returns:
        Dictionary with injury report data
    """
    print("Fetching current injury data from ESPN...")
    reports = injury_client.get_all_injuries()
    
    # Build structured report
    injury_data = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "league": "NBA",
        "total_teams": len(reports),
        "teams": []
    }
    
    for team_id, report in sorted(reports.items(), key=lambda x: x[1].team_name):
        team_data = {
            "team_id": team_id,
            "team_name": report.team_name,
            "injury_count": len(report.injuries),
            "severity_score": round(report.total_severity, 2),
            "has_significant_injuries": report.has_significant_injuries,
            "injuries": []
        }
        
        # Add each injury
        for injury in report.injuries:
            team_data["injuries"].append({
                "player_name": injury.player_name,
                "player_id": injury.player_id,
                "status": injury.status,
                "injury_type": injury.injury_type,
                "details": injury.details,
                "severity_score": injury.severity_score,
            })
        
        # Calculate Elo adjustment
        from core.injury_client import calculate_injury_adjustment
        adjustment = calculate_injury_adjustment(report, debug=False)
        team_data["elo_adjustment"] = round(adjustment, 1)
        
        injury_data["teams"].append(team_data)
    
    # Save to file if requested
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(injury_data, f, indent=2)
        print(f"✓ Saved injury report to {output_path}")
    
    return injury_data


def generate_team_info(
    team_mapper: TeamMapper,
    state_manager: StateManager,
    output_path: Optional[Path] = None
) -> Dict:
    """
    Generate team information with current Elo ratings.
    
    Args:
        team_mapper: TeamMapper instance
        state_manager: StateManager instance
        output_path: If provided, save to this JSON file
    
    Returns:
        Dictionary with team information
    """
    print("Loading team data and Elo ratings...")
    
    # Load state
    elo_tracker, stats_tracker = state_manager.load()
    
    team_data = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "league": "NBA",
        "teams": []
    }
    
    # Get all NBA team IDs and names
    team_lookup = team_mapper.get_all_teams()
    
    for team_id, team_name in sorted(team_lookup.items(), key=lambda x: x[1]):
        elo = elo_tracker.get_elo(team_id)
        
        # Get recent stats if available
        stats = stats_tracker.get_stats(team_id)
        
        team_info = {
            "team_id": team_id,
            "team_name": team_name,
            "current_elo": round(elo, 1),
            "recent_win_pct": round(stats.get("win_roll", 0.5), 3) if stats else 0.5,
            "recent_margin": round(stats.get("margin_roll", 0.0), 1) if stats else 0.0,
        }
        
        team_data["teams"].append(team_info)
    
    # Save to file if requested
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(team_data, f, indent=2)
        print(f"✓ Saved team info to {output_path}")
    
    return team_data


def generate_model_context(output_path: Optional[Path] = None) -> Dict:
    """
    Generate context document explaining how the prediction model works.
    
    Args:
        output_path: If provided, save to this JSON file
    
    Returns:
        Dictionary with model context
    """
    print("Generating model context documentation...")
    
    context = {
        "generated_at": datetime.now().isoformat(),
        "model_name": "NBA Game Prediction Model v2",
        "model_type": "XGBoost with Probability Calibration",
        "description": "Machine learning model for predicting NBA game outcomes",
        
        "features_used": {
            "elo_ratings": {
                "description": "Team strength ratings based on historical performance",
                "features": ["elo_home", "elo_away", "elo_diff"]
            },
            "rolling_stats": {
                "description": "Recent performance metrics (last 10 games)",
                "features": [
                    "win_roll_home", "win_roll_away",
                    "margin_roll_home", "margin_roll_away"
                ]
            },
            "rest_factors": {
                "description": "Days of rest and back-to-back game indicators",
                "features": [
                    "home_rest_days", "away_rest_days",
                    "home_b2b", "away_b2b"
                ]
            },
            "betting_markets": {
                "description": "Implied probabilities from betting markets",
                "features": ["market_prob_home", "market_prob_away"]
            },
            "injury_adjustments": {
                "description": "Elo adjustments based on player injuries",
                "note": "Injuries are used to adjust Elo ratings before prediction"
            }
        },
        
        "output": {
            "home_win_probability": "Probability that home team wins (0.0 to 1.0)",
            "away_win_probability": "Probability that away team wins (0.0 to 1.0)",
            "confidence_tier": "Categorization of prediction confidence"
        },
        
        "confidence_tiers": {
            "Heavy Favorite": "Win probability > 75%",
            "Moderate Favorite": "Win probability 65-75%",
            "Lean Favorite": "Win probability 60-65%",
            "Toss-Up": "Win probability 50-60%",
            "Lean Underdog": "Win probability 40-50%",
            "Moderate Underdog": "Win probability 35-40%",
            "Heavy Underdog": "Win probability < 35%"
        },
        
        "important_notes": {
            "injury_lag": "The model's core features don't include real-time injuries. However, Elo ratings are adjusted based on current injury reports before making predictions.",
            "market_incorporation": "Betting market probabilities are included as features, which often reflect late-breaking information like injuries.",
            "elo_system": "Elo ratings update after each game based on results and margin of victory.",
            "calibration": "Probabilities are calibrated to be well-calibrated (i.e., when model says 70%, the team should win ~70% of the time)."
        },
        
        "interpretation_guide": {
            "high_confidence_games": "Games with clear favorites (>70% win probability) tend to be more predictable",
            "toss_ups": "Games near 50/50 are inherently uncertain - many factors can swing the result",
            "injury_impact": "Major injuries (All-Star players out) can shift win probability by 5-15%",
            "home_court": "Home court advantage is built into the model through historical data",
            "back_to_backs": "Teams on second night of back-to-back typically see 2-5% decrease in win probability"
        }
    }
    
    # Save to file if requested
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(context, f, indent=2)
        print(f"✓ Saved model context to {output_path}")
    
    return context


def generate_all_context_files(output_dir: Path) -> None:
    """
    Generate all context files for Vertex AI agent.
    
    Args:
        output_dir: Directory to save context files
    """
    print(f"\n{'=' * 70}")
    print("Generating AI Context Files")
    print(f"{'=' * 70}\n")
    
    # Initialize components
    project_root = Path(__file__).parent.parent
    state_dir = project_root / "state"
    
    team_mapper = TeamMapper()
    state_manager = StateManager(state_dir)
    injury_client = InjuryClient(team_mapper)
    
    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate each context file
    generate_injury_report(
        injury_client,
        output_path=output_dir / "injury_report.json"
    )
    
    generate_team_info(
        team_mapper,
        state_manager,
        output_path=output_dir / "team_info.json"
    )
    
    generate_model_context(
        output_path=output_dir / "model_context.json"
    )
    
    # Copy daily predictions if they exist
    daily_pred_path = project_root / "predictions" / "daily.json"
    if daily_pred_path.exists():
        import shutil
        shutil.copy(daily_pred_path, output_dir / "daily_predictions.json")
        print(f"✓ Copied daily predictions to {output_dir / 'daily_predictions.json'}")
    
    print(f"\n{'=' * 70}")
    print(f"✓ All context files generated in: {output_dir}")
    print(f"{'=' * 70}\n")
    
    print("Files created:")
    for file in sorted(output_dir.glob("*.json")):
        size_kb = file.stat().st_size / 1024
        print(f"  - {file.name} ({size_kb:.1f} KB)")
    
    print("\nNext steps:")
    print("1. Upload these files to Google Cloud Storage")
    print("2. Add them as grounding data in your Vertex AI agent")
    print("\nSee instructions below for GCP Console walkthrough.")


def upload_to_gcs(output_dir: Path, bucket_name: str) -> None:
    """
    Upload context files to Google Cloud Storage.
    
    Args:
        output_dir: Directory with context files
        bucket_name: GCS bucket name
    """
    try:
        from google.cloud import storage
    except ImportError:
        print("Error: google-cloud-storage package not installed")
        print("Install it with: pip install google-cloud-storage")
        return
    
    print(f"\nUploading files to gs://{bucket_name}/ai_context/...")
    
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    
    for file in output_dir.glob("*.json"):
        blob = bucket.blob(f"ai_context/{file.name}")
        blob.upload_from_filename(str(file))
        print(f"  ✓ Uploaded {file.name}")
    
    print(f"\n✓ All files uploaded to gs://{bucket_name}/ai_context/")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate context files for Vertex AI agent"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="ai_context",
        help="Output directory for context files (default: ai_context/)"
    )
    parser.add_argument(
        "--upload-to-gcs",
        action="store_true",
        help="Upload files to Google Cloud Storage after generation"
    )
    parser.add_argument(
        "--bucket",
        type=str,
        default="nba-prediction-data-metadata",
        help="GCS bucket name for upload (default: nba-prediction-data-metadata)"
    )
    return parser.parse_args()


def main():
    args = parse_args()
    
    output_dir = Path(args.output_dir)
    
    # Generate all context files
    generate_all_context_files(output_dir)
    
    # Upload to GCS if requested
    if args.upload_to_gcs:
        upload_to_gcs(output_dir, args.bucket)
    else:
        print(f"\nTo upload to GCS, run:")
        print(f"  python {__file__} --output-dir {output_dir} --upload-to-gcs")


if __name__ == "__main__":
    main()
