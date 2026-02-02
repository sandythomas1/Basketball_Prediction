#!/usr/bin/env python3
"""Quick test to check if Render API returns confidence scores."""

import urllib.request
import json

API_URL = "https://nba-prediction-api-nq5b.onrender.com/api/v1/predict/today"

print("Testing Render Production API...")
print(f"URL: {API_URL}\n")

try:
    with urllib.request.urlopen(API_URL, timeout=10) as response:
        data = json.loads(response.read().decode())
        
    games = data.get('games', [])
    print(f"✓ API responded successfully")
    print(f"✓ Total games: {len(games)}\n")
    
    if games:
        game = games[0]
        pred = game.get('prediction', {})
        
        print("First game prediction:")
        print(f"  Home: {game.get('home_team', 'N/A')}")
        print(f"  Away: {game.get('away_team', 'N/A')}")
        print(f"  Win Probability: {pred.get('home_win_prob', 'N/A')}")
        print(f"  Confidence Tier: {pred.get('confidence', 'N/A')}")
        print()
        print("NEW CONFIDENCE FIELDS:")
        print(f"  confidence_score: {pred.get('confidence_score', 'NULL')}")
        print(f"  confidence_qualifier: {pred.get('confidence_qualifier', 'NULL')}")
        
        if pred.get('confidence_factors'):
            print(f"  confidence_factors: YES ✓")
            factors = pred['confidence_factors']
            print(f"    - consensus_agreement: {factors.get('consensus_agreement', 'N/A')}")
            print(f"    - feature_alignment: {factors.get('feature_alignment', 'N/A')}")
            print(f"    - form_stability: {factors.get('form_stability', 'N/A')}")
            print(f"    - schedule_context: {factors.get('schedule_context', 'N/A')}")
            print(f"    - matchup_history: {factors.get('matchup_history', 'N/A')}")
        else:
            print(f"  confidence_factors: NULL ✗")
        
        print()
        if pred.get('confidence_score') is None:
            print("⚠️  WARNING: Backend is NOT returning confidence scores!")
            print("   The new code may not be deployed yet.")
        else:
            print("✅ SUCCESS: Backend IS returning confidence scores!")
    else:
        print("No games found in response")
        
except Exception as e:
    print(f"❌ Error: {e}")
