import requests
import csv
from datetime import datetime
from pathlib import Path

# Add core path to import TeamMapper
import sys
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))
from core.team_mapper import TeamMapper
from core.league_config import WNBA_CONFIG

def fetch_wnba_history():
    years = [2021, 2022, 2023, 2024, 2025]
    
    out_dir = Path(__file__).parent.parent / "data" / "processed"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "wnba_games_with_labels.csv"
    
    team_mapper = TeamMapper(lookup_path=Path(__file__).parent.parent / WNBA_CONFIG.team_lookup_csv)
    
    games_data = []
    
    season_type_map = {
        1: "Preseason",
        2: "Regular Season",
        3: "Playoffs"
    }

    for year in years:
        url = f"https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard?dates={year}&limit=1000"
        print(f"Fetching {year} season...")
        response = requests.get(url)
        if response.status_code != 200:
            print(f"Warning: Failed to fetch {year}")
            continue
            
        data = response.json()
        events = data.get("events", [])
        print(f"Found {len(events)} games in {year}")
        
        for event in events:
            # Only process final games
            status = event.get("status", {}).get("type", {}).get("description", "Unknown")
            if status != "Final":
                continue
                
            game_id = event.get("id")
            date_str = event.get("date", "")
            
            try:
                game_datetime = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
                game_date = game_datetime.astimezone().strftime("%Y-%m-%d")
            except ValueError:
                game_date = date_str[:10]
                
            season_info = event.get("season", {})
            season_id = f"2{season_info.get('year', year)}" # Prefix with 2 to match NBA regular season ID pattern if needed, or just year
            season_type_num = season_info.get("type", 2)
            season_type = season_type_map.get(season_type_num, "Regular Season")
            
            competitors = event.get("competitions", [])[0].get("competitors", [])
            
            home_team = None
            away_team = None
            pts_home = 0
            pts_away = 0
            
            for competitor in competitors:
                team_name = competitor.get("team", {}).get("displayName", "")
                score = int(competitor.get("score", "0"))
                if competitor.get("homeAway") == "home":
                    home_team = team_name
                    pts_home = score
                else:
                    away_team = team_name
                    pts_away = score
                    
            if not home_team or not away_team:
                continue
                
            team_id_home = team_mapper.get_team_id(home_team)
            team_id_away = team_mapper.get_team_id(away_team)
            
            if not team_id_home or not team_id_away:
                print(f"Skipping {away_team} @ {home_team}: Could not map IDs")
                continue
                
            home_win = 1 if pts_home > pts_away else 0
            wl_home = "W" if home_win else "L"
            
            games_data.append({
                "game_id": game_id,
                "game_date": game_date,
                "season_id": season_id,
                "season_type": season_type,
                "team_id_home": team_id_home,
                "team_id_away": team_id_away,
                "wl_home": wl_home,
                "pts_home": pts_home,
                "pts_away": pts_away,
                "home_win": home_win
            })

    # Sort games by date chronologically
    games_data.sort(key=lambda x: x["game_date"])

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "game_id", "game_date", "season_id", "season_type", 
            "team_id_home", "team_id_away", "wl_home", "pts_home", "pts_away", "home_win"
        ])
        writer.writeheader()
        writer.writerows(games_data)
        
    print(f"\nSuccessfully wrote {len(games_data)} historical WNBA games to {out_path}")

if __name__ == "__main__":
    fetch_wnba_history()
