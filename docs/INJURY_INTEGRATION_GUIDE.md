# Injury Data Integration Guide

## Overview

This guide explains how to integrate injury data into your NBA prediction system. Currently, your model does **NOT** use injury data explicitly, but this document shows you how to add it.

---

## Current State: No Injury Data ❌

### What Your Model Currently Uses (23 features):

```python
FEATURE_COLS = [
    # Elo ratings
    "elo_home", "elo_away", "elo_diff", "elo_prob",
    
    # Rolling stats (last 10 games)
    "pf_roll_home", "pf_roll_away", "pf_roll_diff",  # Points scored
    "pa_roll_home", "pa_roll_away", "pa_roll_diff",  # Points allowed
    "win_roll_home", "win_roll_away", "win_roll_diff",  # Win rate
    "margin_roll_home", "margin_roll_away", "margin_roll_diff",  # Point margin
    
    # Game context
    "games_in_window_home", "games_in_window_away",
    
    # Rest/fatigue
    "home_rest_days", "away_rest_days",
    "home_b2b", "away_b2b", "rest_diff",
    
    # Betting market
    "market_prob_home", "market_prob_away"
]
```

### How Injuries Are Currently Captured (Indirectly):

1. **Elo Rating Drops**: If Lakers lose 5 games without LeBron, their Elo drops from 1650 → 1590
2. **Rolling Stats Decline**: Win rate and margins reflect recent poor performance
3. **Problem**: This is **LAGGING** - takes 5-10 games to reflect injury impact

---

## Where to Get Injury Data 🏥

### Option 1: ESPN API (Recommended - You're Already Using This!)

**Endpoint:**
```
https://site.api.espn.com/apis/site/v2/sports/basketball/nba/injuries
```

**Response Example:**
```json
{
  "teams": [
    {
      "team": {
        "displayName": "Los Angeles Lakers",
        "id": "13"
      },
      "injuries": [
        {
          "athlete": {
            "id": "1966",
            "displayName": "LeBron James"
          },
          "status": "Questionable",
          "shortComment": "Ankle",
          "longComment": "LeBron James is questionable with left ankle soreness",
          "date": "2024-02-07T18:00:00Z"
        }
      ]
    }
  ]
}
```

**Pros:**
- ✅ Free
- ✅ You're already integrated with ESPN
- ✅ Real-time updates
- ✅ No API key needed

**Cons:**
- ⚠️ No player importance weights (can't distinguish All-Star vs bench player)
- ⚠️ Unofficial API (could change)

---

### Option 2: NBA Official Stats API

**Endpoint:**
```
https://www.nba.com/stats/players/bio/
```

**Pros:**
- Official source
- Most up-to-date

**Cons:**
- Harder to parse
- No structured injury endpoint
- Unofficial/undocumented

---

### Option 3: Paid Sports Data APIs

- **The Odds API** - $10-50/month (you're already using this)
- **SportsDataIO** - $20-100/month
- **RapidAPI** - $10-50/month

**Pros:**
- ✅ Structured data
- ✅ Player importance ratings
- ✅ Documentation and support

**Cons:**
- 💰 Costs money

---

## Implementation: Three Approaches

### Approach 1: Simple Context (Easiest) ⭐ **Recommended First Step**

**What:** Add injury info to AI agent context without changing the model

**Impact:** Users get better explanations, no retraining needed

**Steps:**

1. Use the `InjuryClient` I created (`src/core/injury_client.py`)
2. Fetch injuries when building predictions
3. Add to AI agent context

**Code Changes:**

```python
# In src/api/routes/games.py

from src.core.injury_client import InjuryClient

def build_game_with_prediction(game, service: PredictionService) -> GameWithPrediction:
    # ... existing prediction code ...
    
    # NEW: Add injury data
    injury_client = InjuryClient(service.team_mapper)
    injury_summary = injury_client.get_matchup_injury_summary(
        game.home_team_id,
        game.away_team_id
    )
    
    # Add to context
    context = GameContext(
        home_elo=round(features["elo_home"], 1),
        away_elo=round(features["elo_away"], 1),
        # ... existing fields ...
        
        # NEW FIELDS:
        home_injuries=injury_summary["home_injuries"],
        away_injuries=injury_summary["away_injuries"],
        injury_advantage=injury_summary["advantage"],
    )
```

**Update Flutter Model:**

```dart
// In app/lib/Models/game.dart

class Game {
  // ... existing fields ...
  
  // NEW: Injury information
  final List<String>? homeInjuries;  // ["LeBron James (Q)", "Anthony Davis (O)"]
  final List<String>? awayInjuries;
  final String? injuryAdvantage;  // "home", "away", or "even"
  
  // ... rest of class ...
}
```

**Update AI Context:**

```dart
// In app/lib/Services/ai_chat_service.dart

String _buildGameContext(Game game) {
  return '''
GAME DATA:
- Home Team: ${game.homeTeam}
- Away Team: ${game.awayTeam}

MODEL PREDICTIONS:
- Home Win Probability: $homeWinPct%
- Confidence Tier: ${game.confidenceTier ?? 'Not available'}

ELO RATINGS:
- Home Elo: ${game.homeElo?.toInt() ?? 1500}
- Away Elo: ${game.awayElo?.toInt() ?? 1500}

// 🆕 NEW: INJURY REPORT
INJURY REPORT:
- Home Team Injuries: ${game.homeInjuries?.join(", ") ?? "None reported"}
- Away Team Injuries: ${game.awayInjuries?.join(", ") ?? "None reported"}
- Health Advantage: ${_formatAdvantage(game.injuryAdvantage)}
''';
}

String _formatAdvantage(String? advantage) {
  switch (advantage) {
    case "home":
      return "Home team (away has more injuries)";
    case "away":
      return "Away team (home has more injuries)";
    default:
      return "Even (both teams relatively healthy)";
  }
}
```

**Result:**

Now your AI can say:
> "The Lakers are favored at 65%, but LeBron James is questionable with an ankle injury. If he sits, this becomes a toss-up game. The model doesn't account for this yet since it's based on pre-injury performance."

---

### Approach 2: Elo Adjustment (Medium Complexity)

**What:** Dynamically adjust Elo ratings based on injuries before prediction

**Impact:** Better predictions without retraining model

**Steps:**

```python
# In src/core/feature_builder.py

class FeatureBuilder:
    def __init__(self, elo_tracker, stats_tracker, injury_client=None):
        self.elo_tracker = elo_tracker
        self.stats_tracker = stats_tracker
        self.injury_client = injury_client  # NEW
    
    def build_features(self, home_id, away_id, game_date, ...):
        # Get base Elo ratings
        elo_home = self.elo_tracker.get_elo(home_id)
        elo_away = self.elo_tracker.get_elo(away_id)
        
        # NEW: Apply injury adjustments
        if self.injury_client:
            home_injury_report = self.injury_client.get_team_injuries(home_id)
            away_injury_report = self.injury_client.get_team_injuries(away_id)
            
            elo_home += calculate_injury_adjustment(home_injury_report)
            elo_away += calculate_injury_adjustment(away_injury_report)
        
        elo_diff = elo_home - elo_away
        # ... rest of features ...
```

**Example Impact:**

```
Without injury adjustment:
  Lakers Elo: 1650
  Celtics Elo: 1580
  → Lakers 65% to win

With injury adjustment (LeBron out):
  Lakers Elo: 1650 - 50 = 1600
  Celtics Elo: 1580
  → Lakers 54% to win (more realistic!)
```

---

### Approach 3: Retrain Model with Injury Features (Advanced)

**What:** Add injury features to the model and retrain

**Impact:** Most accurate predictions, but requires retraining

**New Features to Add:**

```python
FEATURE_COLS = [
    # ... existing 23 features ...
    
    # NEW: Injury features (6 total)
    "home_players_out",          # Count of players out
    "away_players_out",
    "home_players_questionable",  # Count of questionable players
    "away_players_questionable",
    "home_injury_severity",      # 0-5 scale
    "away_injury_severity",
]
```

**Required Work:**
1. Collect historical injury data
2. Add features to training pipeline
3. Retrain XGBoost model
4. Re-calibrate probabilities
5. Validate on holdout set

**Timeline:** 2-4 weeks

---

## Recommended Implementation Path 🛣️

### Week 1: Quick Wins (Approach 1)
✅ Implement `InjuryClient`  
✅ Add injuries to AI context  
✅ Update Flutter UI to show injuries  
✅ Test with live games  

**Effort:** 4-6 hours  
**Value:** High (users get better explanations)

### Week 2: Smart Adjustments (Approach 2)
✅ Implement Elo injury adjustments  
✅ Create player importance weights (All-Stars vs bench)  
✅ A/B test adjusted predictions vs baseline  

**Effort:** 1-2 days  
**Value:** Medium (better predictions without retraining)

### Week 3+: Full Integration (Approach 3)
✅ Collect historical injury data  
✅ Build training pipeline with injuries  
✅ Retrain and validate model  

**Effort:** 2-4 weeks  
**Value:** Highest (most accurate predictions)

---

## Code Examples

### Example 1: Fetch and Display Injuries

```python
# Backend: src/daily_predictions.py

from src.core.injury_client import InjuryClient

injury_client = InjuryClient(team_mapper)

for game in games:
    # Get prediction
    prediction = predictor.predict_game(...)
    
    # Get injuries
    injury_summary = injury_client.get_matchup_injury_summary(
        game.home_team_id,
        game.away_team_id
    )
    
    # Add to output
    pred.home_injuries = injury_summary["home_injuries"]
    pred.away_injuries = injury_summary["away_injuries"]
```

### Example 2: UI Display

```dart
// Flutter: Display injury badge
Widget _buildInjuryBadge(Game game) {
  final hasHomeInjuries = game.homeInjuries?.isNotEmpty ?? false;
  final hasAwayInjuries = game.awayInjuries?.isNotEmpty ?? false;
  
  if (!hasHomeInjuries && !hasAwayInjuries) {
    return SizedBox.shrink();
  }
  
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.liveRed.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.local_hospital, size: 12, color: AppColors.liveRed),
        SizedBox(width: 4),
        Text(
          'Injuries',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.liveRed,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
```

---

## Testing the Integration

### Test ESPN Injury Endpoint

```bash
# Fetch current injuries
curl "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/injuries" | jq

# Test your client
cd src
python -m core.injury_client
```

### Expected Output

```
Fetching league-wide injury report...

Found injury data for 18 teams

Los Angeles Lakers:
  Players Out: Anthony Davis
  Questionable: LeBron James, Rui Hachimura
  Total Severity: 1.75
  Suggested Elo Adjustment: -26.2

Golden State Warriors:
  Players Out: None
  Questionable: Stephen Curry
  Total Severity: 0.50
  Suggested Elo Adjustment: -7.5
```

---

## FAQs

### Q: Will adding injuries make predictions worse?
**A:** No. Approach 1 (context only) doesn't change predictions at all—it just helps users understand them. Approach 2 (Elo adjustment) should improve accuracy.

### Q: How often should I fetch injury data?
**A:** Every 4-6 hours is sufficient. Injury reports typically update around game time.

### Q: What about load management / rest days?
**A:** Your model already tracks `rest_days` and `b2b` (back-to-back) games. This captures most rest impacts.

### Q: Can I distinguish between All-Stars and bench players?
**A:** Not automatically from ESPN. You'd need to:
1. Maintain a player importance table (manual or from advanced stats)
2. Apply different Elo adjustments based on player value

---

## Summary

| Approach | Effort | Impact | Retraining Needed? |
|----------|--------|--------|-------------------|
| **1. Context Only** | 4-6 hours | Medium | ❌ No |
| **2. Elo Adjustment** | 1-2 days | Medium-High | ❌ No |
| **3. Model Retraining** | 2-4 weeks | Highest | ✅ Yes |

**Recommendation:** Start with **Approach 1** this week. It's quick, valuable, and doesn't require model changes. Then move to Approach 2 if you see good results.

---

## Next Steps

1. ✅ Review `src/core/injury_client.py` (already created)
2. Test ESPN injuries endpoint
3. Add injuries to API response models
4. Update Flutter Game model
5. Enhance AI context with injury data
6. Deploy and test with live games

Need help implementing any of these? Let me know!
