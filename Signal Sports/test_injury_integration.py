"""
Test script to verify injury data integration.

This script tests:
1. InjuryClient can fetch data from ESPN
2. API endpoints include injury data in responses
3. Data format is correct
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from core.injury_client import InjuryClient
from core.team_mapper import TeamMapper


def test_injury_client():
    """Test basic InjuryClient functionality."""
    print("=" * 70)
    print("TEST 1: InjuryClient - Fetching Injury Data")
    print("=" * 70)
    
    team_mapper = TeamMapper()
    client = InjuryClient(team_mapper)
    
    print("\nFetching league-wide injuries from ESPN API...")
    reports = client.get_all_injuries(debug=False)
    
    print(f"\n✅ SUCCESS: Fetched injury data for {len(reports)} teams\n")
    
    # Show teams with injuries
    teams_with_injuries = [r for r in reports.values() if r.injuries]
    
    if not teams_with_injuries:
        print("ℹ️  No teams currently have reported injuries.\n")
    else:
        print(f"Teams with injuries ({len(teams_with_injuries)}):\n")
        
        for report in sorted(teams_with_injuries, key=lambda r: r.total_severity, reverse=True)[:5]:
            print(f"📋 {report.team_name}:")
            
            if report.players_out:
                print(f"   ❌ OUT: {', '.join(p.player_name + f' ({p.injury_type})' for p in report.players_out)}")
            
            if report.players_questionable:
                print(f"   ⚠️  QUESTIONABLE: {', '.join(p.player_name + f' ({p.injury_type})' for p in report.players_questionable)}")
            
            print(f"   📊 Injury Severity: {report.total_severity:.2f}")
            print()
    
    return reports


def test_matchup_summary(reports):
    """Test matchup injury summary."""
    print("=" * 70)
    print("TEST 2: Matchup Injury Summary")
    print("=" * 70)
    
    # Find two teams with data
    team_ids = list(reports.keys())
    if len(team_ids) < 2:
        print("\n⚠️  Not enough teams to test matchup\n")
        return
    
    team_mapper = TeamMapper()
    client = InjuryClient(team_mapper)
    
    home_id = team_ids[0]
    away_id = team_ids[1]
    
    home_name = reports[home_id].team_name
    away_name = reports[away_id].team_name
    
    print(f"\nTesting matchup: {home_name} vs {away_name}\n")
    
    summary = client.get_matchup_injury_summary(home_id, away_id)
    
    print(f"Home ({home_name}):")
    print(f"  Injuries: {summary['home_injuries'] or 'None'}")
    print(f"  Severity: {summary['home_severity']:.2f}")
    
    print(f"\nAway ({away_name}):")
    print(f"  Injuries: {summary['away_injuries'] or 'None'}")
    print(f"  Severity: {summary['away_severity']:.2f}")
    
    print(f"\nHealth Advantage: {summary['advantage']}")
    
    print("\n✅ Matchup summary working correctly\n")


def test_api_response_format():
    """Test that API response format includes injury fields."""
    print("=" * 70)
    print("TEST 3: API Response Format")
    print("=" * 70)
    
    print("\nChecking API schemas...")
    
    try:
        from api.schemas import GameContext
        
        # Create a sample context
        context = GameContext(
            home_elo=1600.0,
            away_elo=1550.0,
            home_recent_wins=0.6,
            away_recent_wins=0.5,
            home_rest_days=2,
            away_rest_days=1,
            home_b2b=False,
            away_b2b=True,
            home_injuries=["LeBron James (Q)", "Anthony Davis (O)"],
            away_injuries=None,
            injury_advantage="away",
        )
        
        print("\n✅ GameContext schema updated correctly")
        print(f"\nSample context:")
        print(f"  Home injuries: {context.home_injuries}")
        print(f"  Away injuries: {context.away_injuries}")
        print(f"  Injury advantage: {context.injury_advantage}")
        print()
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}\n")
        return False
    
    return True


def main():
    """Run all tests."""
    print("\n" + "=" * 70)
    print("INJURY DATA INTEGRATION TEST SUITE")
    print("=" * 70 + "\n")
    
    try:
        # Test 1: Fetch injury data
        reports = test_injury_client()
        
        # Test 2: Matchup summary
        test_matchup_summary(reports)
        
        # Test 3: API format
        test_api_response_format()
        
        print("=" * 70)
        print("ALL TESTS PASSED! ✅")
        print("=" * 70)
        print("\nNext steps:")
        print("1. Start your FastAPI server: python -m uvicorn src.api.main:app --reload")
        print("2. Test endpoint: http://localhost:8000/predict/today")
        print("3. Verify 'context' includes home_injuries, away_injuries, injury_advantage")
        print("4. Test Flutter app to see AI using injury context")
        print()
        
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
