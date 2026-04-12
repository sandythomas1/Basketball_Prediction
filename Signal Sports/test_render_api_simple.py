#!/usr/bin/env python3
import urllib.request
import json

# Try different endpoint variations
endpoints = [
    "https://nba-prediction-api-nq5b.onrender.com/",
    "https://nba-prediction-api-nq5b.onrender.com/api/v1/predict/today",
    "https://nba-prediction-api-nq5b.onrender.com/predict/today",
]

for url in endpoints:
    try:
        print(f"Testing: {url}")
        with urllib.request.urlopen(url, timeout=10) as response:
            data = json.loads(response.read().decode())
            print(f"  SUCCESS - Status: {response.status}")
            if isinstance(data, dict) and 'games' in data:
                games = data['games']
                if games and 'prediction' in games[0]:
                    pred = games[0]['prediction']
                    print(f"  confidence_score: {pred.get('confidence_score', 'NULL')}")
            print()
    except urllib.error.HTTPError as e:
        print(f"  ERROR {e.code}: {e.reason}")
        print()
    except Exception as e:
        print(f"  ERROR: {str(e)[:100]}")
        print()
