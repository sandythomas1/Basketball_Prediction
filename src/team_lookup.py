import sqlite3
import pandas as pd 
from pathlib import Path

db_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/nba.sqlite")
out_path = Path("/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/processed/team_lookup.csv")

conn = sqlite3.connect(db_path)

df = pd.read_sql_query("""
SELECT
    id AS team_id,
    full_name,
    abbreviation,
    nickname,
    city
FROM team
""", conn)

conn.close()

df.to_csv(out_path, index=False)
print(f"Team lookup saved to {out_path}")
print(df.head(21))