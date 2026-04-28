from dataclasses import dataclass

@dataclass
class LeagueConfig:
    league_name: str
    team_count: int
    espn_slug: str              # "nba", "wnba", "mens-college-basketball"
    default_elo: float = 1500.0
    home_court_advantage: float = 70.0  # NBA: 70; tune per league
    k_factor: float = 20.0
    season_carryover: float = 0.7
    injury_source: str = "espn"          # "espn", "none"
    odds_sport_key: str = ""             # The Odds API key
    team_lookup_csv: str = ""
    model_path: str = ""
    calibrator_path: str = ""
    state_dir: str = ""

NBA_CONFIG = LeagueConfig(
    league_name="NBA",
    team_count=30,
    espn_slug="nba",
    home_court_advantage=70.0,
    injury_source="espn",
    odds_sport_key="basketball_nba",
    team_lookup_csv="data/processed/team_lookup.csv",
    model_path="models/xgb_v3_with_injuries.json",
    calibrator_path="models/calibrator_v3.pkl",
    state_dir="state/nba/",
)

WNBA_CONFIG = LeagueConfig(
    league_name="WNBA",
    team_count=13,
    espn_slug="wnba",
    home_court_advantage=55.0,  # Tune empirically
    injury_source="espn",
    odds_sport_key="basketball_wnba",
    team_lookup_csv="data/processed/wnba_team_lookup.csv",
    model_path="models/xgb_wnba_v1.json",
    calibrator_path="models/calibrator_wnba_v1.pkl",
    state_dir="state/wnba/",
)

CBB_CONFIG = LeagueConfig(
    league_name="NCAA Men's Basketball",
    team_count=352,  # D-I only
    espn_slug="mens-college-basketball",
    home_court_advantage=80.0,  # Tune empirically; likely higher than NBA
    injury_source="none",        # No ESPN college injury data
    odds_sport_key="basketball_ncaab",
    team_lookup_csv="data/processed/cbb_team_lookup.csv",
    model_path="models/xgb_cbb_v1.json",
    calibrator_path="models/calibrator_cbb_v1.pkl",
    state_dir="state/cbb/",
)
