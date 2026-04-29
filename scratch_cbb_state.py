import json
import csv
from pathlib import Path

# Load CBB teams
cbb_team_csv = Path("data/processed/cbb_team_lookup.csv")
teams = []
with open(cbb_team_csv, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        teams.append(row["team_id"])

# Mock Elo (1500 for all)
elo_state = {str(t): 1500.0 for t in teams}

# Mock Stats (empty history)
stats_state = {str(t): [] for t in teams}

state_dir = Path("state/cbb")
state_dir.mkdir(parents=True, exist_ok=True)

with open(state_dir / "elo.json", "w") as f:
    json.dump(elo_state, f, indent=2)

with open(state_dir / "stats.json", "w") as f:
    json.dump(stats_state, f, indent=2)

print(f"Bootstrapped mock state for {len(teams)} CBB teams")
