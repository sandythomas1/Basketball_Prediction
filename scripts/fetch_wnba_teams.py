import requests
import csv
from pathlib import Path

def fetch_wnba_teams():
    url = "https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/teams"
    response = requests.get(url, params={"limit": 50})
    response.raise_for_status()
    data = response.json()
    
    teams_data = []
    
    # Navigation to teams list
    try:
        teams = data["sports"][0]["leagues"][0]["teams"]
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
        
    # Add Golden State Valkyries manually if they are not in ESPN API yet
    # Assuming standard abbreviation GSV, nickname Valkyries, city Golden State/San Francisco
    has_gsv = any(t["nickname"] == "Valkyries" for t in teams_data)
    if not has_gsv:
        teams_data.append({
            "team_id": "9999", # placeholder ID, hoping ESPN uses a real one eventually
            "full_name": "Golden State Valkyries",
            "abbreviation": "GSV",
            "nickname": "Valkyries",
            "city": "Golden State",
        })

    # Write to CSV
    out_dir = Path(__file__).parent.parent / "data" / "processed"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "wnba_team_lookup.csv"
    
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["team_id", "full_name", "abbreviation", "nickname", "city"])
        writer.writeheader()
        writer.writerows(teams_data)
        
    print(f"Successfully wrote {len(teams_data)} teams to {out_path}")

if __name__ == "__main__":
    fetch_wnba_teams()
