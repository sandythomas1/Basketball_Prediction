import asyncio
import aiohttp
import csv
from datetime import datetime, date, timedelta
from pathlib import Path
import sys

# Add core path to import TeamMapper
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))
from core.team_mapper import TeamMapper
from core.league_config import CBB_CONFIG

async def fetch_day(session, date_str):
    url = f"https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard?dates={date_str}&groups=50&limit=1000"
    try:
        async with session.get(url, timeout=10) as response:
            if response.status == 200:
                data = await response.json()
                return data.get("events", [])
    except Exception as e:
        print(f"Failed {date_str}: {e}")
    return []

async def fetch_cbb_history():
    out_dir = Path(__file__).parent.parent / "data" / "processed"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "cbb_games_with_labels.csv"
    
    team_mapper = TeamMapper(lookup_path=Path(__file__).parent.parent / CBB_CONFIG.team_lookup_csv)
    
    # We will fetch 2023, 2024, 2025 seasons
    # College basketball seasons usually run from early November to early April
    seasons = [
        {"year": 2023, "start": date(2022, 11, 7), "end": date(2023, 4, 10)},
        {"year": 2024, "start": date(2023, 11, 6), "end": date(2024, 4, 10)},
        {"year": 2025, "start": date(2024, 11, 4), "end": date(2025, 4, 10)},
    ]
    
    dates_to_fetch = []
    for s in seasons:
        current_date = s["start"]
        while current_date <= s["end"]:
            dates_to_fetch.append((s["year"], current_date.strftime("%Y%m%d")))
            current_date += timedelta(days=1)
            
    print(f"Fetching {len(dates_to_fetch)} days of CBB games concurrently...")
    
    games_data = []
    
    season_type_map = {
        1: "Preseason",
        2: "Regular Season",
        3: "Playoffs"
    }
    
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_day(session, d[1]) for d in dates_to_fetch]
        results = await asyncio.gather(*tasks)
        
    print(f"Finished fetching data. Parsing events...")
    
    for (season_year, date_str), events in zip(dates_to_fetch, results):
        for event in events:
            # Only process final games
            status = event.get("status", {}).get("type", {}).get("description", "Unknown")
            if status != "Final":
                continue
                
            game_id = event.get("id")
            event_date_str = event.get("date", "")
            
            try:
                game_datetime = datetime.fromisoformat(event_date_str.replace("Z", "+00:00"))
                game_date = game_datetime.astimezone().strftime("%Y-%m-%d")
            except ValueError:
                game_date = event_date_str[:10]
                
            season_info = event.get("season", {})
            season_id = f"2{season_year}" # standard format
            season_type_num = season_info.get("type", 2)
            season_type = season_type_map.get(season_type_num, "Regular Season")
            
            competitions = event.get("competitions", [])
            if not competitions: continue
            competitors = competitions[0].get("competitors", [])
            
            home_team, away_team = None, None
            pts_home, pts_away = 0, 0
            
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

    games_data.sort(key=lambda x: x["game_date"])

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "game_id", "game_date", "season_id", "season_type", 
            "team_id_home", "team_id_away", "wl_home", "pts_home", "pts_away", "home_win"
        ])
        writer.writeheader()
        writer.writerows(games_data)
        
    print(f"Successfully wrote {len(games_data)} historical CBB games to {out_path}")

if __name__ == "__main__":
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(fetch_cbb_history())
