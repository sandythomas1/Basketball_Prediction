"""
features_with_injuries.py

Extends the features_3.py pipeline by appending 6 explicit injury feature
columns to the output CSV. Since the ESPN API only provides live/current
injury data (no historical records), all injury columns are zero-imputed
for historical training rows.

At inference time, feature_builder.py populates these columns using the
live ESPN injury API.

Output: data/processed/features_with_injuries.csv  (31 features)
"""

import pandas as pd
from pathlib import Path
import argparse
import sys

# Add core path to import LeagueConfig
sys.path.insert(0, str(Path(__file__).parent))
from core.league_config import NBA_CONFIG, WNBA_CONFIG, CBB_CONFIG

# rolling window (same as features_3.py)
N = 10


# ==========================
# Helpers  (copied from features_3.py)
# ==========================

def moneyline_to_prob(ml):
    """Convert American moneyline to implied probability."""
    if pd.isna(ml):
        return None
    ml = float(ml)
    if ml < 0:
        return (-ml) / (-ml + 100)
    else:
        return 100 / (ml + 100)


def make_team_game_rows(df):
    home = df[[
        "game_id", "game_date", "season_id",
        "team_id_home", "team_id_away",
        "pts_home", "pts_away", "home_win"
    ]].copy()
    home.rename(columns={
        "team_id_home": "team_id",
        "team_id_away": "opp_id",
        "pts_home": "pf",
        "pts_away": "pa",
    }, inplace=True)
    home["is_home"] = 1
    home["win"] = home["home_win"]

    away = df[[
        "game_id", "game_date", "season_id",
        "team_id_away", "team_id_home",
        "pts_away", "pts_home", "home_win"
    ]].copy()
    away.rename(columns={
        "team_id_away": "team_id",
        "team_id_home": "opp_id",
        "pts_away": "pf",
        "pts_home": "pa",
    }, inplace=True)
    away["is_home"] = 0
    away["win"] = 1 - away["home_win"]

    tg = pd.concat([home, away], ignore_index=True)
    tg = tg.sort_values(["team_id", "game_date", "game_id"]).reset_index(drop=True)
    return tg


def add_rolling(tg, n=N):
    g = tg.groupby("team_id", group_keys=False)
    tg["pf_roll"]          = g["pf"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    tg["pa_roll"]          = g["pa"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    tg["win_roll"]         = g["win"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).mean())
    tg["margin_roll"]      = tg["pf_roll"] - tg["pa_roll"]
    tg["games_in_window"]  = g["win"].apply(lambda s: s.shift(1).rolling(n, min_periods=1).count())
    return tg


def merge_back(df, tg):
    home = tg[tg["is_home"] == 1][[
        "game_id", "team_id", "pf_roll", "pa_roll",
        "win_roll", "margin_roll", "games_in_window"
    ]].copy()
    home.rename(columns={
        "team_id": "team_id_home",
        "pf_roll": "pf_roll_home",
        "pa_roll": "pa_roll_home",
        "win_roll": "win_roll_home",
        "margin_roll": "margin_roll_home",
        "games_in_window": "games_in_window_home"
    }, inplace=True)

    away = tg[tg["is_home"] == 0][[
        "game_id", "team_id", "pf_roll", "pa_roll",
        "win_roll", "margin_roll", "games_in_window"
    ]].copy()
    away.rename(columns={
        "team_id": "team_id_away",
        "pf_roll": "pf_roll_away",
        "pa_roll": "pa_roll_away",
        "win_roll": "win_roll_away",
        "margin_roll": "margin_roll_away",
        "games_in_window": "games_in_window_away"
    }, inplace=True)

    out = df.merge(home, on=["game_id", "team_id_home"], how="left") \
            .merge(away, on=["game_id", "team_id_away"], how="left")
    return out


# ==========================
# Main
# ==========================

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--league", default="nba", choices=["nba", "wnba", "cbb"])
    args = parser.parse_args()
    
    if args.league == "wnba":
        in_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_games_with_elo_rest.csv"
        odds_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_odds_with_team_ids.csv"
        out_path = Path(__file__).parent.parent / "data" / "processed" / "wnba_features_with_injuries.csv"
    elif args.league == "cbb":
        in_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_games_with_elo_rest.csv"
        odds_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_odds_with_team_ids.csv"
        out_path = Path(__file__).parent.parent / "data" / "processed" / "cbb_features_with_injuries.csv"
    else:
        in_path = Path(__file__).parent.parent / "data" / "processed" / "games_with_elo_rest.csv"
        odds_path = Path(__file__).parent.parent / "data" / "processed" / "odds_with_team_ids.csv"
        out_path = Path(__file__).parent.parent / "data" / "processed" / "features_with_injuries.csv"

    df = pd.read_csv(in_path, parse_dates=["game_date"])
    df["season_id"] = df["season_id"].astype(int)

    # Elo diff
    df["elo_diff"] = df["elo_home"] - df["elo_away"]

    tg = make_team_game_rows(df)
    tg = add_rolling(tg)

    feat = merge_back(df, tg)

    # Diff features
    feat["pf_roll_diff"]     = feat["pf_roll_home"]    - feat["pf_roll_away"]
    feat["pa_roll_diff"]     = feat["pa_roll_home"]    - feat["pa_roll_away"]
    feat["win_roll_diff"]    = feat["win_roll_home"]   - feat["win_roll_away"]
    feat["margin_roll_diff"] = feat["margin_roll_home"] - feat["margin_roll_away"]

    # =========================================================================
    # MERGE BETTING ODDS (market implied probabilities)
    # =========================================================================
    print("\nMerging betting odds...")

    if odds_path.exists():
        odds = pd.read_csv(odds_path, parse_dates=["date"])
        odds = odds.rename(columns={"date": "game_date"})

        odds["market_prob_home"] = odds["moneyline_home"].apply(moneyline_to_prob)
        odds["market_prob_away"] = odds["moneyline_away"].apply(moneyline_to_prob)

        odds_slim = odds[[
            "game_date", "team_id_home", "team_id_away",
            "market_prob_home", "market_prob_away"
        ]].copy()

        feat = feat.merge(
            odds_slim,
            on=["game_date", "team_id_home", "team_id_away"],
            how="left"
        )

        matched = feat["market_prob_home"].notna().sum()
        missing = feat["market_prob_home"].isna().sum()
        print(f"  Matched {matched} games with odds data")
        print(f"  Games without odds (using 0.5): {missing}")

        feat["market_prob_home"] = feat["market_prob_home"].fillna(0.5)
        feat["market_prob_away"] = feat["market_prob_away"].fillna(0.5)
    else:
        print(f"  Warning: Odds file not found at {odds_path}")
        print("  Using neutral 0.5 for all market probabilities")
        feat["market_prob_home"] = 0.5
        feat["market_prob_away"] = 0.5

    # =========================================================================
    # INJURY FEATURES — zero-imputed for all historical rows
    #
    # Historical injury data is not available via the ESPN API.
    # These columns are set to 0.0 for training; at inference time
    # feature_builder.py populates them with live ESPN injury data.
    # =========================================================================
    print("\nAdding injury feature columns (zero-imputed for historical data)...")

    feat["home_players_out"]        = 0.0
    feat["away_players_out"]        = 0.0
    feat["home_players_questionable"] = 0.0
    feat["away_players_questionable"] = 0.0
    feat["home_injury_severity"]    = 0.0
    feat["away_injury_severity"]    = 0.0

    print("  Added: home_players_out, away_players_out")
    print("  Added: home_players_questionable, away_players_questionable")
    print("  Added: home_injury_severity, away_injury_severity")

    # =========================================================================
    # Final feature columns (31 features: 25 original + 6 injury)
    # =========================================================================
    feature_cols = [
        # Elo ratings
        "elo_home", "elo_away", "elo_diff", "elo_prob",
        # Rolling scoring stats
        "pf_roll_home", "pf_roll_away", "pf_roll_diff",
        "pa_roll_home", "pa_roll_away", "pa_roll_diff",
        # Rolling win/margin stats
        "win_roll_home", "win_roll_away", "win_roll_diff",
        "margin_roll_home", "margin_roll_away", "margin_roll_diff",
        # Game-window context
        "games_in_window_home", "games_in_window_away",
        # Rest / fatigue
        "home_rest_days", "away_rest_days", "home_b2b", "away_b2b", "rest_diff",
        # Betting market probabilities
        "market_prob_home", "market_prob_away",
        # Injury features (zero-imputed for training; live at inference)
        "home_players_out", "away_players_out",
        "home_players_questionable", "away_players_questionable",
        "home_injury_severity", "away_injury_severity",
    ]

    model_df = feat[["game_date", "season_id"] + feature_cols + ["home_win"]].copy()

    out_path.parent.mkdir(parents=True, exist_ok=True)
    model_df.to_csv(out_path, index=False)

    print(f"\nSaved: {out_path}")
    print(f"Shape: {model_df.shape}")
    print(f"\nFeature columns ({len(feature_cols)} total):")
    for i, col in enumerate(feature_cols, 1):
        print(f"  {i:2d}. {col}")
    print(f"\nSample data:")
    print(model_df.head())


if __name__ == "__main__":
    main()
