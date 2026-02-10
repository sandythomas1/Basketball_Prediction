"""
InjuryClient: Fetches injury reports from ESPN API with player importance.
"""

from dataclasses import dataclass
from typing import List, Optional, Dict
import requests
from datetime import datetime
import sys
from pathlib import Path

# Handle both direct execution and module import
try:
    from .team_mapper import TeamMapper
except ImportError:
    # Add parent directory to path for direct execution
    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core.team_mapper import TeamMapper


@dataclass
class PlayerInjury:
    """Represents a player injury report."""
    player_name: str
    player_id: str
    team_id: int
    team_name: str
    status: str  # "Out", "Questionable", "Doubtful", "Day-To-Day"
    injury_type: str  # "Ankle", "Knee", etc.
    details: str  # Full injury description
    date_updated: datetime
    
    @property
    def is_out(self) -> bool:
        """Check if player is definitely out."""
        return self.status.lower() in ["out", "o"]
    
    @property
    def is_questionable(self) -> bool:
        """Check if player is questionable to play."""
        return self.status.lower() in ["questionable", "q"]
    
    @property
    def severity_score(self) -> float:
        """
        Return a severity score for the injury.
        
        Returns:
            1.0 = Definitely out
            0.5 = Questionable/Doubtful
            0.25 = Day-to-Day
            0.0 = Probable/available
        """
        status_lower = self.status.lower()
        if status_lower in ["out", "o"]:
            return 1.0
        elif status_lower in ["doubtful", "d"]:
            return 0.75
        elif status_lower in ["questionable", "q"]:
            return 0.5
        elif status_lower in ["day-to-day", "dtd"]:
            return 0.25
        else:  # Probable, Available, etc.
            return 0.0


@dataclass
class TeamInjuryReport:
    """Injury report for a team."""
    team_id: int
    team_name: str
    injuries: List[PlayerInjury]
    last_updated: datetime
    
    @property
    def players_out(self) -> List[PlayerInjury]:
        """Get list of players definitely out."""
        return [inj for inj in self.injuries if inj.is_out]
    
    @property
    def players_questionable(self) -> List[PlayerInjury]:
        """Get list of questionable players."""
        return [inj for inj in self.injuries if inj.is_questionable]
    
    @property
    def total_severity(self) -> float:
        """
        Calculate total injury impact for the team.
        
        Simple heuristic: sum of all severity scores.
        Range: 0.0 (no injuries) to N (multiple players out)
        """
        return sum(inj.severity_score for inj in self.injuries)
    
    @property
    def has_significant_injuries(self) -> bool:
        """Check if team has significant injury concerns."""
        return len(self.players_out) > 0 or len(self.players_questionable) >= 2


class InjuryClient:
    """
    Client for fetching NBA injury data from ESPN.
    """
    
    BASE_URL = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba"
    TIMEOUT = 10  # seconds
    
    def __init__(self, team_mapper: Optional[TeamMapper] = None):
        """
        Initialize injury client.
        
        Args:
            team_mapper: TeamMapper for converting ESPN names to NBA IDs
        """
        self.team_mapper = team_mapper or TeamMapper()
        self._session = requests.Session()
        self._session.headers.update({
            "Accept": "application/json",
            "User-Agent": "NBA-Predictor/1.0",
        })
    
    def get_all_injuries(self, debug: bool = False) -> Dict[int, TeamInjuryReport]:
        """
        Fetch current league-wide injury report.
        
        Args:
            debug: If True, print debug information about the API response
        
        Returns:
            Dictionary mapping team_id to TeamInjuryReport
        """
        url = f"{self.BASE_URL}/injuries"
        
        try:
            response = self._session.get(url, timeout=self.TIMEOUT)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as e:
            print(f"Error fetching injuries: {e}")
            return {}
        
        if debug:
            print(f"\n🔍 DEBUG: API Response Keys: {list(data.keys())}")
            injuries_list = data.get("injuries", [])
            print(f"🔍 DEBUG: Found {len(injuries_list)} teams in response")
        
        # Parse injuries by team
        team_injuries: Dict[int, List[PlayerInjury]] = {}
        
        # The structure is: data["injuries"] = array of team objects
        injuries_list = data.get("injuries", [])
        
        if debug and not injuries_list:
            print("🔍 DEBUG: No teams found in data['injuries']")
            # Try to show some of the response structure
            import json
            print(f"🔍 DEBUG: First 500 chars of response:\n{json.dumps(data, indent=2)[:500]}...")
        
        for team_data in injuries_list:
            team_name = team_data.get("displayName", "")
            team_id = self.team_mapper.get_team_id(team_name)
            
            if team_id is None:
                if debug:
                    print(f"⚠️  Could not map team: {team_name}")
                continue
            
            injuries = []
            for idx, injury_data in enumerate(team_data.get("injuries", [])):
                # Debug: print first injury structure for first team
                if debug and idx == 0 and len(injuries) == 0:
                    print(f"\n🔍 DEBUG: Sample injury data keys for {team_name}: {list(injury_data.keys())}")
                
                # Parse athlete information
                athlete = injury_data.get("athlete", {})
                player_name = athlete.get("displayName", "Unknown Player")
                player_id = athlete.get("id", injury_data.get("id", ""))
                
                # Parse injury details
                status = injury_data.get("status", "Unknown")
                details_obj = injury_data.get("details", {})
                injury_type = details_obj.get("type", "Unknown")
                short_comment = injury_data.get("shortComment", "")
                long_comment = injury_data.get("longComment", "")
                
                injury = PlayerInjury(
                    player_name=player_name,
                    player_id=str(player_id),
                    team_id=team_id,
                    team_name=team_name,
                    status=status,
                    injury_type=injury_type,
                    details=long_comment or short_comment,
                    date_updated=datetime.now(),
                )
                injuries.append(injury)
            
            team_injuries[team_id] = injuries
        
        # Convert to TeamInjuryReport objects
        reports = {}
        for team_id, injuries in team_injuries.items():
            team_name = next(
                (inj.team_name for inj in injuries if inj.team_name), 
                f"Team {team_id}"
            )
            reports[team_id] = TeamInjuryReport(
                team_id=team_id,
                team_name=team_name,
                injuries=injuries,
                last_updated=datetime.now(),
            )
        
        return reports
    
    def get_team_injuries(self, team_id: int) -> Optional[TeamInjuryReport]:
        """
        Get injury report for a specific team.
        
        Args:
            team_id: NBA team ID
        
        Returns:
            TeamInjuryReport or None if not found
        """
        all_injuries = self.get_all_injuries()
        return all_injuries.get(team_id)
    
    def get_matchup_injury_summary(
        self, 
        home_id: int, 
        away_id: int
    ) -> Dict[str, any]:
        """
        Get injury summary for a matchup.
        
        Useful for providing context to users or AI agents.
        
        Args:
            home_id: Home team NBA ID
            away_id: Away team NBA ID
        
        Returns:
            Dictionary with injury summaries for both teams
        """
        home_report = self.get_team_injuries(home_id)
        away_report = self.get_team_injuries(away_id)
        
        summary = {
            "home_injuries": [],
            "away_injuries": [],
            "home_severity": 0.0,
            "away_severity": 0.0,
            "advantage": "even",  # "home", "away", or "even"
        }
        
        if home_report:
            summary["home_injuries"] = [
                f"{inj.player_name} ({inj.status})"
                for inj in home_report.injuries
            ]
            summary["home_severity"] = home_report.total_severity
        
        if away_report:
            summary["away_injuries"] = [
                f"{inj.player_name} ({inj.status})"
                for inj in away_report.injuries
            ]
            summary["away_severity"] = away_report.total_severity
        
        # Determine advantage
        severity_diff = summary["away_severity"] - summary["home_severity"]
        if abs(severity_diff) < 0.5:
            summary["advantage"] = "even"
        elif severity_diff > 0:
            summary["advantage"] = "home"  # Away has more injuries
        else:
            summary["advantage"] = "away"  # Home has more injuries
        
        return summary
    
    def __repr__(self) -> str:
        return f"InjuryClient()"


# =============================================================================
# Import Configuration and Player Importance
# =============================================================================

try:
    from .config import (
        INJURY_ADJUSTMENTS_ENABLED,
        INJURY_ADJUSTMENT_MULTIPLIER,
        INJURY_MAX_ADJUSTMENT,
        INJURY_MIN_ADJUSTMENT,
        LOG_INJURY_ADJUSTMENTS,
        DEBUG_INJURY_CALCULATIONS,
    )
    from .player_importance import get_player_importance_multiplier, is_all_star
except ImportError:
    # Fallback for direct execution
    INJURY_ADJUSTMENTS_ENABLED = True
    INJURY_ADJUSTMENT_MULTIPLIER = 20
    INJURY_MAX_ADJUSTMENT = -100
    INJURY_MIN_ADJUSTMENT = -5
    LOG_INJURY_ADJUSTMENTS = True
    DEBUG_INJURY_CALCULATIONS = False
    
    def get_player_importance_multiplier(name: str) -> float:
        return 1.5  # Default to starter tier
    
    def is_all_star(name: str) -> bool:
        return False


# =============================================================================
# Enhanced Injury Impact Calculator with Player Importance
# =============================================================================

def calculate_injury_adjustment(
    injury_report: TeamInjuryReport,
    use_player_importance: bool = True,
    debug: bool = False
) -> float:
    """
    Calculate Elo adjustment based on injury report with player importance.
    
    Uses sophisticated calculation:
    - Player importance multiplier (All-Star: 2.5x, Starter: 1.5x, Bench: 1.0x)
    - Injury status weight (Out: 1.0, Doubtful: 0.75, Questionable: 0.5)
    - Configurable base multiplier (default: 20 Elo per severity point)
    
    Example:
        LeBron James (Out) = 1.0 × 2.5 × 20 = -50 Elo
        Role player (Questionable) = 0.5 × 1.0 × 20 = -10 Elo
    
    Args:
        injury_report: Team's injury report
        use_player_importance: Whether to apply player importance multipliers
        debug: Print debug information
    
    Returns:
        Elo adjustment (negative number = team is weaker)
    """
    if not injury_report or not injury_report.injuries:
        return 0.0
    
    if not INJURY_ADJUSTMENTS_ENABLED:
        return 0.0
    
    total_impact = 0.0
    
    if debug or DEBUG_INJURY_CALCULATIONS:
        print(f"\n🔍 Calculating injury adjustment for {injury_report.team_name}:")
    
    for injury in injury_report.injuries:
        # Get base severity (0.0 to 1.0)
        severity = injury.severity_score
        
        # Apply player importance multiplier
        if use_player_importance:
            importance = get_player_importance_multiplier(injury.player_name)
        else:
            importance = 1.0
        
        # Calculate weighted severity
        weighted_severity = severity * importance
        
        # Convert to Elo adjustment
        player_impact = weighted_severity * INJURY_ADJUSTMENT_MULTIPLIER
        total_impact += player_impact
        
        if debug or DEBUG_INJURY_CALCULATIONS:
            all_star_marker = "⭐" if is_all_star(injury.player_name) else "  "
            print(f"  {all_star_marker} {injury.player_name} ({injury.status}):")
            print(f"     Severity: {severity:.2f} × Importance: {importance:.1f}x "
                  f"× {INJURY_ADJUSTMENT_MULTIPLIER} = {player_impact:.1f} Elo")
    
    # Apply total adjustment (negative)
    adjustment = -total_impact
    
    # Apply bounds
    if adjustment < INJURY_MAX_ADJUSTMENT:
        adjustment = INJURY_MAX_ADJUSTMENT
        if debug or DEBUG_INJURY_CALCULATIONS:
            print(f"  ⚠️  Capped at maximum: {INJURY_MAX_ADJUSTMENT} Elo")
    elif adjustment > INJURY_MIN_ADJUSTMENT:
        # If impact is too small, don't apply it
        adjustment = 0.0
        if debug or DEBUG_INJURY_CALCULATIONS:
            print(f"  ⚠️  Impact too small, ignoring")
    
    if debug or DEBUG_INJURY_CALCULATIONS:
        print(f"  ➡️  Total Adjustment: {adjustment:.1f} Elo")
    
    return adjustment


def calculate_injury_adjustment_simple(
    injury_report: TeamInjuryReport,
    aggressive: bool = False
) -> float:
    """
    Legacy simple adjustment calculation (for backwards compatibility).
    
    Args:
        injury_report: Team's injury report
        aggressive: If True, apply larger adjustments
    
    Returns:
        Elo adjustment (negative number = team is weaker)
    """
    if not injury_report or not injury_report.injuries:
        return 0.0
    
    # Simple approach: each severity point = ~15-20 Elo reduction
    multiplier = 20 if aggressive else 15
    adjustment = -injury_report.total_severity * multiplier
    
    # Cap the adjustment at -80 Elo (prevent extreme swings)
    return max(adjustment, -80.0)


if __name__ == "__main__":
    # Test the client
    print("Testing ESPN Injury Client")
    print("=" * 60)
    
    client = InjuryClient()
    
    print("\nFetching league-wide injury report from ESPN API...")
    reports = client.get_all_injuries(debug=False)  # Set to True for debugging
    
    print(f"\n✅ Successfully fetched injury data for {len(reports)} teams")
    print(f"\nTeams with significant injuries:\n")
    
    # Show teams with significant injuries
    teams_with_injuries = [r for r in reports.values() if r.has_significant_injuries]
    
    if not teams_with_injuries:
        print("  No significant injuries reported at this time.")
    else:
        for report in sorted(teams_with_injuries, key=lambda r: r.total_severity, reverse=True):
            print(f"📋 {report.team_name}:")
            
            if report.players_out:
                print(f"   ❌ OUT: {', '.join(p.player_name + f' ({p.injury_type})' for p in report.players_out)}")
            
            if report.players_questionable:
                print(f"   ⚠️  QUESTIONABLE: {', '.join(p.player_name + f' ({p.injury_type})' for p in report.players_questionable)}")
            
            print(f"   📊 Injury Severity Score: {report.total_severity:.2f}/10")
            print(f"   📉 Suggested Elo Adjustment: {calculate_injury_adjustment(report):.1f} points")
            print()
