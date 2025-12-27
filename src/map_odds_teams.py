import pandas as pd
import re
from pathlib import Path

odds_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/raw/nba_odds_2008-2025.csv")
team_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/team_lookup.csv")
out_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/odds_with_team_ids.csv")

def normalize(s):
    if pd.isna(s):
        return None
    s = s.lower()
    s = re.sub(r'[^a-z]', "", s)
    s = s.strip()
    return s

def main():
    pass