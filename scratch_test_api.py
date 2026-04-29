import sys
from pathlib import Path
from fastapi.testclient import TestClient

# Add src to path
sys.path.insert(0, str(Path("src").absolute()))

from api.main import app

client = TestClient(app)

response = client.get("/cbb/predict/today")
print(f"Status Code: {response.status_code}")
print(f"Response: {response.json()}")

response = client.get("/cbb/games/today")
print(f"Games Status Code: {response.status_code}")
