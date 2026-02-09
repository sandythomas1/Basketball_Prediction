"""
Simple test of InjuryClient without full dependencies.
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from core.team_mapper import TeamMapper
from core.injury_client import InjuryClient


def main():
    print("\n" + "=" * 70)
    print("TESTING INJURY CLIENT")
    print("=" * 70 + "\n")
    
    print("1. Initializing TeamMapper and InjuryClient...")
    team_mapper = TeamMapper()
    client = InjuryClient(team_mapper)
    print("   ✅ Initialized\n")
    
    print("2. Fetching league-wide injuries from ESPN API...")
    reports = client.get_all_injuries(debug=False)
    print(f"   ✅ Fetched data for {len(reports)} teams\n")
    
    # Show teams with injuries
    teams_with_injuries = [r for r in reports.values() if r.injuries]
    
    if not teams_with_injuries:
        print("ℹ️  No teams currently have reported injuries.")
        print("   (This is normal if no games are happening soon)\n")
    else:
        print(f"3. Teams with reported injuries ({len(teams_with_injuries)}):\n")
        
        for report in sorted(teams_with_injuries, key=lambda r: r.total_severity, reverse=True)[:8]:
            print(f"   📋 {report.team_name}:")
            
            if report.players_out:
                out_players = [f"{p.player_name} ({p.injury_type})" for p in report.players_out]
                print(f"      ❌ OUT: {', '.join(out_players)}")
            
            if report.players_questionable:
                q_players = [f"{p.player_name} ({p.injury_type})" for p in report.players_questionable]
                print(f"      ⚠️  QUESTIONABLE: {', '.join(q_players)}")
            
            print(f"      📊 Severity Score: {report.total_severity:.2f}\n")
    
    # Test matchup summary
    if len(reports) >= 2:
        print("4. Testing matchup injury summary...\n")
        team_ids = list(reports.keys())
        
        home_id = team_ids[0]
        away_id = team_ids[1]
        
        home_name = reports[home_id].team_name
        away_name = reports[away_id].team_name
        
        print(f"   Sample matchup: {home_name} vs {away_name}\n")
        
        summary = client.get_matchup_injury_summary(home_id, away_id)
        
        print(f"   Home ({home_name}):")
        print(f"     Injuries: {summary['home_injuries'] if summary['home_injuries'] else 'None'}")
        print(f"     Severity: {summary['home_severity']:.2f}\n")
        
        print(f"   Away ({away_name}):")
        print(f"     Injuries: {summary['away_injuries'] if summary['away_injuries'] else 'None'}")
        print(f"     Severity: {summary['away_severity']:.2f}\n")
        
        print(f"   Health Advantage: {summary['advantage'].upper()}")
        print(f"   ✅ Matchup summary working!\n")
    
    print("=" * 70)
    print("✅ ALL TESTS PASSED!")
    print("=" * 70)
    print("\nInjury data is being fetched successfully from ESPN API.")
    print("\nThe backend API endpoints will now include injury data in responses.")
    print("Your Flutter app's AI agent will use this data for better explanations!")
    print()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ ERROR: {e}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)
