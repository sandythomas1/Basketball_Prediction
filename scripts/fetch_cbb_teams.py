import requests
import csv
from pathlib import Path

def fetch_cbb_teams():
    url = "https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/teams"
    # limit=400 ensures we get all teams
    # groups=50 limits to NCAA Division I
    response = requests.get(url, params={"limit": 400, "groups": 50})
    response.raise_for_status()
    data = response.json()
    
    teams_data = []
    
    # Navigation to teams list
    try:
        teams = data.get("sports", [])[0].get("leagues", [])[0].get("teams", [])
    except (KeyError, IndexError) as e:
        print(f"Error parsing ESPN response: {e}")
        return
        
    for t in teams:
        team = t.get("team", {})
        team_id = team.get("id")
        full_name = team.get("displayName")
        abbreviation = team.get("abbreviation")
        nickname = team.get("nickname", "")
        city = team.get("location", "")
        
        teams_data.append({
            "team_id": team_id,
            "full_name": full_name,
            "abbreviation": abbreviation,
            "nickname": nickname,
            "city": city,
        })
        
    # Write to CSV
    out_dir = Path(__file__).parent.parent / "data" / "processed"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "cbb_team_lookup.csv"
    
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["team_id", "full_name", "abbreviation", "nickname", "city"])
        writer.writeheader()
        writer.writerows(teams_data)
        
    print(f"Successfully wrote {len(teams_data)} teams to {out_path}")

if __name__ == "__main__":
    fetch_cbb_teams()
