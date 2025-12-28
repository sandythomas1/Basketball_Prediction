import pandas as pd
import re
from pathlib import Path

# Paths
odds_path = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/raw/nba_2008-2025.csv"
)
team_path = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/team_lookup.csv"
)
out_path = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/odds_with_team_ids.csv"
)

# Known aliases (historical + sportsbook quirks)
ALIASES = {
    "la": "losangeles",
    "lakers": "losangeles",
    "clippers": "losangeles",

    "ny": "newyork",
    "nyc": "newyork",
    "knicks": "newyork",
    "nets": "brooklyn",

    "gs": "goldenstate",
    "warriors": "goldenstate",

    "nj": "brooklyn",
    "newjersey": "brooklyn",

    "bobcats": "charlotte",
    "charlottebobcats": "charlotte",

    "hornets": "neworleans",
    "pelicans": "neworleans",
}

ALIASES.update({
    "seattlesupersonics": "oklahomacity",
    "supersonics": "oklahomacity",

    "washingtonbullets": "washington",
    "bullets": "washington",

    "neworleansoklahomacity": "neworleans",
    "noh": "neworleans",
})


def normalize(s):
    if pd.isna(s):
        return None

    s = s.lower()

    # remove parentheses + suffixes
    s = re.sub(r"\(.*?\)", "", s)
    s = re.sub(r"vs.*", "", s)
    s = re.sub(r"game\s*\d+", "", s)

    s = re.sub(r"[^a-z]", "", s)
    s = s.strip()

    return ALIASES.get(s, s)


def main():
    # Load data
    odds = pd.read_csv(odds_path, parse_dates=["date"])
    teams = pd.read_csv(team_path)

    # Normalize odds team strings
    odds["home_norm"] = odds["home"].apply(normalize)
    odds["away_norm"] = odds["away"].apply(normalize)

    # Normalize team lookup
    teams["city_norm"] = teams["city"].apply(normalize)
    teams["nick_norm"] = teams["nickname"].apply(normalize)
    teams["abbr_norm"] = teams["abbreviation"].str.lower()

    # Deduplicate lookup tables
    teams_city = teams.drop_duplicates("city_norm", keep="first")
    teams_nick = teams.drop_duplicates("nick_norm", keep="first")
    teams_abbr = teams.drop_duplicates("abbr_norm", keep="first")

    # Build mapping dictionaries
    city_map = teams_city.set_index("city_norm")["team_id"]
    nick_map = teams_nick.set_index("nick_norm")["team_id"]
    abbr_map = teams_abbr.set_index("abbr_norm")["team_id"]

    # HOME TEAM MAPPING (priority: abbr → city → nickname)
    odds["team_id_home"] = odds["home_norm"].map(abbr_map)
    odds["team_id_home"] = odds["team_id_home"].combine_first(
        odds["home_norm"].map(city_map)
    )
    odds["team_id_home"] = odds["team_id_home"].combine_first(
        odds["home_norm"].map(nick_map)
    )

    # AWAY TEAM MAPPING
    odds["team_id_away"] = odds["away_norm"].map(abbr_map)
    odds["team_id_away"] = odds["team_id_away"].combine_first(
        odds["away_norm"].map(city_map)
    )
    odds["team_id_away"] = odds["team_id_away"].combine_first(
        odds["away_norm"].map(nick_map)
    )

    # drop unmappable games (preseason / exhibitions)
    before = len(odds)
    odds = odds.dropna(subset=["team_id_home", "team_id_away"])
    after = len(odds)

    print(f"Dropped {before - after} unmappable games")

    # Sanity checks
    missing_home = odds["team_id_home"].isna().sum()
    missing_away = odds["team_id_away"].isna().sum()

    print(f"Missing home mappings: {missing_home}")
    print(f"Missing away mappings: {missing_away}")

    # Save
    out_path.parent.mkdir(parents=True, exist_ok=True)
    odds.to_csv(out_path, index=False)
    print(f"Saved: {out_path}")

if __name__ == "__main__":
    main()
