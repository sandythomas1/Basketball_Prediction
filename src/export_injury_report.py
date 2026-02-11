"""
Export current NBA injury report to JSON for Vertex AI agent.

Usage:
    python src/export_injury_report.py
    python src/export_injury_report.py --output ai_context/injury_report.json
"""

import argparse
import json
from datetime import datetime
from pathlib import Path
import sys

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root / "src"))

from core.injury_client import InjuryClient, calculate_injury_adjustment
from core.team_mapper import TeamMapper


def main():
    parser = argparse.ArgumentParser(description="Export injury report for Vertex AI")
    parser.add_argument(
        "--output", "-o",
        type=str,
        default="ai_context/injury_report.json",
        help="Output JSON file path"
    )
    args = parser.parse_args()
    
    print("=" * 70)
    print("NBA Injury Report Generator")
    print("=" * 70)
    
    # Initialize clients
    print("\nInitializing...")
    team_mapper = TeamMapper()
    injury_client = InjuryClient(team_mapper)
    
    # Fetch injury data
    print("Fetching current injury data from ESPN API...")
    reports = injury_client.get_all_injuries()
    
    if not reports:
        print("⚠️  No injury data available")
        return
    
    print(f"✓ Found injury data for {len(reports)} teams")
    
    # Build structured report
    injury_data = {
        "generated_at": datetime.now().isoformat(),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S EST"),
        "source": "ESPN Injury API",
        "league": "NBA",
        "total_teams": len(reports),
        "teams_with_injuries": sum(1 for r in reports.values() if r.injuries),
        "total_injuries": sum(len(r.injuries) for r in reports.values()),
        "teams": []
    }
    
    # Process each team
    for team_id, report in sorted(reports.items(), key=lambda x: x[1].team_name):
        team_data = {
            "team_id": team_id,
            "team_name": report.team_name,
            "injury_count": len(report.injuries),
            "severity_score": round(report.total_severity, 2),
            "has_significant_injuries": report.has_significant_injuries,
            "players_out": len(report.players_out),
            "players_questionable": len(report.players_questionable),
            "injuries": []
        }
        
        # Add each injury with details
        for injury in report.injuries:
            team_data["injuries"].append({
                "player_name": injury.player_name,
                "status": injury.status,
                "injury_type": injury.injury_type,
                "details": injury.details if injury.details else f"{injury.status} - {injury.injury_type}",
                "severity_score": injury.severity_score,
            })
        
        # Calculate expected Elo adjustment
        adjustment = calculate_injury_adjustment(report, debug=False)
        team_data["elo_adjustment"] = round(adjustment, 1)
        team_data["elo_adjustment_explanation"] = (
            f"Estimated Elo decrease of {abs(adjustment):.0f} points based on injury severity and player importance"
            if adjustment < -5 else "Minimal Elo impact from current injuries"
        )
        
        injury_data["teams"].append(team_data)
    
    # Save to file
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(injury_data, f, indent=2)
    
    print(f"\n✓ Saved injury report to {output_path}")
    
    # Show summary
    teams_with_significant = [t for t in injury_data["teams"] if t["has_significant_injuries"]]
    if teams_with_significant:
        print(f"\n📋 Teams with significant injuries ({len(teams_with_significant)}):")
        for team in teams_with_significant[:5]:  # Show top 5
            print(f"  • {team['team_name']}: {team['injury_count']} injuries (Elo {team['elo_adjustment']:.0f})")
        if len(teams_with_significant) > 5:
            print(f"  ... and {len(teams_with_significant) - 5} more")
    
    print(f"\nFile size: {output_path.stat().st_size / 1024:.1f} KB")
    print("\n" + "=" * 70)


if __name__ == "__main__":
    main()
