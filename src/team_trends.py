import pandas as pd
from pathlib import Path

INPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/features_2.csv"
)

OUTPUT_PATH = Path(
    "/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/app_team_trends.csv"
)

MIN_GAMES = 5


def classify_trend(margin, win_rate):
    if margin >= 5 and win_rate >= 0.60:
        return "Hot", "green"
    if margin <= -5 and win_rate <= 0.40:
        return "Cold", "red"
    return "Stable", "gray"


def strength_score(margin, win_rate):
    score = 50 + (margin * 2) + ((win_rate - 0.5) * 100)
    return int(max(0, min(100, score)))


def main():
    df = pd.read_csv(INPUT_PATH, parse_dates=["game_date"])

    # -----------------------
    # HOME TEAM VIEW
    # -----------------------
    home = df[[
        "game_id",
        "game_date",
        "team_id_home",
        "margin_roll_home",
        "win_roll_home",
        "games_in_window_home"
    ]].copy()

    home.rename(columns={
        "team_id_home": "team_id",
        "margin_roll_home": "margin_roll",
        "win_roll_home": "win_roll",
        "games_in_window_home": "games_in_window"
    }, inplace=True)

    home["side"] = "home"

    # -----------------------
    # AWAY TEAM VIEW
    # -----------------------
    away = df[[
        "game_id",
        "game_date",
        "team_id_away",
        "margin_roll_away",
        "win_roll_away",
        "games_in_window_away"
    ]].copy()

    away.rename(columns={
        "team_id_away": "team_id",
        "margin_roll_away": "margin_roll",
        "win_roll_away": "win_roll",
        "games_in_window_away": "games_in_window"
    }, inplace=True)

    away["side"] = "away"

    teams = pd.concat([home, away], ignore_index=True)

    # Remove early-season noise
    teams = teams[teams["games_in_window"] >= MIN_GAMES].copy()

    # Trend classification
    meta = teams.apply(
        lambda r: classify_trend(r["margin_roll"], r["win_roll"]),
        axis=1,
        result_type="expand"
    )

    teams["trend_label"] = meta[0]
    teams["trend_color"] = meta[1]

    teams["trend_strength"] = teams.apply(
        lambda r: strength_score(r["margin_roll"], r["win_roll"]),
        axis=1
    )

    teams["trend_summary"] = teams.apply(
        lambda r: (
            f"{r['trend_label']} trend — "
            f"{r['margin_roll']:+.1f} avg margin, "
            f"{r['win_roll']:.0%} win rate"
        ),
        axis=1
    )

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    teams.to_csv(OUTPUT_PATH, index=False)

    print(f"Saved team trend cards to: {OUTPUT_PATH}")
    print("\nSample rows:")
    print(
        teams.head(10)[[
            "game_date",
            "team_id",
            "side",
            "trend_label",
            "trend_strength",
            "trend_summary"
        ]]
    )


if __name__ == "__main__":
    main()
