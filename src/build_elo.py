'''
elo builder
Phome = 1 / (1 + 10**((Ehome - Eaway + HCA) / 400))

home wins:
Ehome_new = Ehome + K * (1 - Phome)
Eaway_new = Eaway - K * (1 - Phome)

away wins:
Ehome_new = Ehome + K * (0 - Phome)
Eaway_new = Eaway - K * (0 - Phome)
'''
import pandas as pd 
from pathlib import Path

Base_games = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_labels.csv")

def initilaze_elo(teams):
    #starting every team at 1500 elo 

    return {team: 1500 for team in teams}

def expected_home_win(Ehome, Eaway, hca=70):
    #calculate expected probability that home team wins
    return 1 / (1 + 10 ** (-(Eaway - Ehome + hca) / 400))

def update_elo(Ehome, Eaway, home_win, k=20):
    Phome = expected_home_win(Ehome, Eaway)

    if home_win == 1:
        Ehome_new = Ehome + k * (1 - Phome)
        Eaway_new = Eaway - k * (1 - Phome)
    else:
        Ehome_new = Ehome + k * (0 - Phome)
        Eaway_new = Eaway - k * (0 - Phome)

    return Ehome_new, Eaway_new, Phome

def main():
    df = pd.read_csv(Base_games, parse_dates=['game_date'])

    #chronological order
    df = df.sort_values('game_date').reset_index(drop=True)

    teams = pd.concat([df['team_id_home'], df['team_id_away']]).unique()

    elo = initilaze_elo(teams)

    #storage columns
    df["elo_home"] = 0.0
    df["elo_away"] = 0.0
    df["elo_prob"] = 0.0

    for i, row in df.iterrows():
        home = row['team_id_home']
        away = row['team_id_away']

        Ehome = elo[home]
        Eaway = elo[away]

        df.at[i, 'elo_home'] = Ehome
        df.at[i, 'elo_away'] = Eaway

        #update elo after game
        Ehome_new, Eaway_new, Phome = update_elo(Ehome, Eaway, row['home_win'])

        df.at[i, 'elo_prob'] = Phome

        elo[home] = Ehome_new
        elo[away] = Eaway_new

    #save
    out_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/games_with_elo.csv")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_path, index=False)
    print(f"Saved elo data to {out_path}")

if __name__ == "__main__":
    main()