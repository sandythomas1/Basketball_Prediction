import sys
import csv
from pathlib import Path
from fastapi.testclient import TestClient

# Add src to path
sys.path.insert(0, str(Path("src").absolute()))

from api.main import app

client = TestClient(app)

# 1. Get 64 team IDs from our mock CBB state or CSV
cbb_team_csv = Path("data/processed/cbb_team_lookup.csv")
teams = []
with open(cbb_team_csv, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        teams.append(int(row["team_id"]))
        if len(teams) == 64:
            break

print(f"Loaded {len(teams)} teams for bracket simulation.")

# 2. Call the API endpoint
payload = {
    "team_ids": teams,
    "iterations": 1000,
    "game_date": "2026-03-15"
}

print("Running Monte Carlo simulation (1000 iterations)...")
response = client.post("/cbb/bracket/simulate", json=payload)

if response.status_code != 200:
    print(f"Error {response.status_code}: {response.text}")
    sys.exit(1)

data = response.json()
print("Simulation complete!")

results = data["results"]

# 3. Verify math
winner_sum = 0.0
f4_sum = 0.0

for team_id, probs in results.items():
    winner_sum += probs["W"]
    f4_sum += probs["F4"]

print(f"Sum of 'W' (Champion) probabilities: {winner_sum:.4f} (Expected: ~1.0)")
print(f"Sum of 'F4' (Final Four) probabilities: {f4_sum:.4f} (Expected: ~4.0)")

# Show top 5 most likely champions
sorted_teams = sorted(results.items(), key=lambda x: x[1]["W"], reverse=True)
print("\nTop 5 Most Likely Champions:")
for team_id, probs in sorted_teams[:5]:
    print(f"Team {team_id}: {probs['W']*100:.1f}%")

if abs(winner_sum - 1.0) < 0.01 and abs(f4_sum - 4.0) < 0.01:
    print("\n✅ Verification PASSED: Probabilities sum correctly!")
else:
    print("\n❌ Verification FAILED: Probabilities do not sum correctly.")
