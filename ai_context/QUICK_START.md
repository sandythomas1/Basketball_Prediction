# Quick Start: Adding Injury Data to Your Vertex AI Agent

## ✅ What I Found

**Injury data IS being fetched but NOT saved to files!**

Your system:
- ✅ Fetches injury data from ESPN API in real-time
- ✅ Uses injuries to adjust Elo ratings during predictions
- ❌ **Does NOT save injury reports to files**
- ❌ **Does NOT include injury data in predictions JSON**
- ❌ **Injury data is NOT available to your Vertex AI agent**

## 🎯 The Solution (3 Steps)

### Step 1: Generate Context Files (1 minute)

Run this command in your terminal:

```bash
cd ~/development/Basketball_Prediction
./update_ai_context.sh
```

This creates 4 files in `ai_context/`:
- ✅ `model_context.json` - Explains how your prediction model works
- ✅ `injury_report.json` - **Current NBA injury data** (the missing piece!)
- ✅ `daily_predictions.json` - Today's game predictions
- ✅ `team_lookup.csv` - Team ID to name mapping

### Step 2: Upload to Google Cloud Storage (3 minutes)

#### Option A: Automatic (if gsutil is installed)

The script above already uploaded them! You're done. ✅

#### Option B: Manual via GCP Console

1. Go to https://console.cloud.google.com/storage
2. Click bucket: `nba-prediction-data-metadata`
3. Create folder: `ai_context`
4. Upload all 4 files from your local `ai_context/` directory

### Step 3: Add to Vertex AI Agent (5 minutes)

1. Go to https://console.cloud.google.com
2. Search for "Vertex AI Agent Builder"
3. Open your NBA Predictions agent
4. Go to **Data** or **Grounding** tab
5. Click **"Create Data Store"**
6. Select **Cloud Storage** as source
7. Point to: `gs://nba-prediction-data-metadata/ai_context/`
8. Click **Create** and wait for indexing
9. In agent settings, enable **"Use grounding"**
10. Update system instructions (see detailed guide)

**📖 Detailed walkthrough:** See `GCP_CONSOLE_WALKTHROUGH.md`

## 🔄 Daily Updates

Run this every morning to keep data fresh:

```bash
cd ~/development/Basketball_Prediction
./update_ai_context.sh
```

Or set up a cron job:
```bash
crontab -e
# Add this line:
0 8 * * * cd ~/development/Basketball_Prediction && ./update_ai_context.sh
```

## 🚀 What This Adds to Your Agent

### Before
**User:** "Why is Lakers vs Celtics a toss-up?"  
**Agent:** "Based on the prediction model, both teams have similar probabilities."

### After
**User:** "Why is Lakers vs Celtics a toss-up?"  
**Agent:** "The model shows Lakers at 51% vs Celtics at 49% - essentially a toss-up. However, the Lakers are dealing with significant injuries: LeBron James (Out - ankle) and Anthony Davis (Questionable - knee). This drops the Lakers' Elo by approximately 65 points. If AD also sits, this could shift to favor the Celtics by 10-15%. The model's Toss-Up rating means this game is genuinely uncertain even without injuries."

## 📋 What Each File Provides

### 1. injury_report.json (MOST IMPORTANT)
**What it contains:**
- All 30 NBA teams
- Current injured players and their status (Out, Questionable, Doubtful)
- Injury severity scores
- Expected Elo impact per team

**Why your agent needs it:**
- Answer: "Are there any injuries I should know about?"
- Explain: "Why is the prediction different from yesterday?"
- Warn: "LeBron is out tonight, this shifts the odds by 10%"

### 2. model_context.json
**What it contains:**
- How the prediction model works
- What features are used (Elo, rest, injuries, etc.)
- Confidence tier explanations
- Model limitations and interpretation guide

**Why your agent needs it:**
- Explain: "How does the model work?"
- Clarify: "What does 'Toss-Up' mean?"
- Educate: "Why did the prediction fail?"

### 3. daily_predictions.json
**What it contains:**
- Today's scheduled games
- Win probabilities for each team
- Confidence tiers
- Elo ratings, recent form, rest days

**Why your agent needs it:**
- Answer: "What are the predictions for tonight?"
- Compare: "Which game is the safest bet?"
- Analyze: "Show me all Toss-Up games"

### 4. team_lookup.csv
**What it contains:**
- Team ID to team name mapping
- Example: 1610612747 = Los Angeles Lakers

**Why your agent needs it:**
- Translate between team IDs and names
- Understand references in other files

## 🎯 Expected Impact

Your Vertex AI agent will now be able to:

✅ **Discuss injuries intelligently**
- "The Lakers have 2 key injuries: LeBron (Out) and AD (Questionable)"
- "This injury situation costs them about 65 Elo points"

✅ **Explain predictions accurately**
- "The model uses Elo ratings, recent form, rest days, and injury adjustments"
- "Heavy Favorite means >75% win probability"

✅ **Provide context-aware responses**
- Check injuries before discussing games
- Explain why predictions might be uncertain
- Warn about late-breaking injury news

✅ **Ground responses in real data**
- "According to the injury report updated today..."
- "The model predicts Lakers at 65% with current injuries..."

## 📊 File Sizes & Update Frequency

| File | Size | Update | Command |
|------|------|--------|---------|
| model_context.json | ~8 KB | Rarely | (Static, already created) |
| injury_report.json | ~15-30 KB | **Daily** | `python3 src/export_injury_report.py` |
| daily_predictions.json | ~5-10 KB | **Daily** | `python3 src/daily_predictions.py --app-format` |
| team_lookup.csv | ~2 KB | Rarely | (Already exists) |

## 🐛 Troubleshooting

### "Script fails when generating injury report"
```bash
# Make sure you have internet connection (needs ESPN API)
# Install dependencies if missing:
pip install requests

# Try running directly:
python3 src/export_injury_report.py
```

### "gsutil not found"
```bash
# Install Google Cloud SDK
# Visit: https://cloud.google.com/sdk/docs/install

# Or upload manually via GCP Console (see Step 2 above)
```

### "Agent doesn't use the uploaded data"
- Make sure grounding is **enabled** in agent settings
- Verify data store is **selected**
- Wait 2-5 minutes after upload for indexing
- Try asking: "What's in the injury report?"

## 📁 File Locations

```
Basketball_Prediction/
├── ai_context/                          ← Generated context files
│   ├── model_context.json              ← Model explanation (static)
│   ├── injury_report.json              ← Current injuries (daily)
│   ├── daily_predictions.json          ← Today's games (daily)
│   ├── team_lookup.csv                 ← Team reference (static)
│   ├── README.md                       ← Full documentation
│   ├── GCP_CONSOLE_WALKTHROUGH.md     ← Step-by-step GCP guide
│   └── QUICK_START.md                  ← This file
├── src/
│   └── export_injury_report.py         ← Script to generate injury report
└── update_ai_context.sh                ← One-command update script
```

## 📚 Documentation

- **Quick Start:** `QUICK_START.md` (this file)
- **Full Guide:** `README.md`
- **GCP Console:** `GCP_CONSOLE_WALKTHROUGH.md` (with screenshots-style instructions)
- **Injury Docs:** `docs/INJURY_DATA_SUMMARY.md`

## ⏰ Recommended Workflow

**Every morning (or whenever you update predictions):**
```bash
cd ~/development/Basketball_Prediction
./update_ai_context.sh
```

This will:
1. ✅ Generate fresh injury report from ESPN
2. ✅ Copy latest predictions
3. ✅ Upload everything to GCS
4. ✅ Your Vertex AI agent automatically picks up new data

**That's it!** Your agent now has the latest injury data and predictions.

## 🎉 Success Criteria

You'll know it's working when you can ask your Vertex AI agent:

```
"What injuries are affecting the Lakers right now?"
```

And it responds with actual current injury data, not just:
- ❌ "I don't have access to real-time injury data"
- ❌ "You should check the official NBA injury report"
- ✅ "According to the latest injury report, the Lakers have: LeBron James (Out - ankle), Anthony Davis (Questionable - knee)..."

---

**Created:** 2026-02-11  
**Last Updated:** 2026-02-11  
**Status:** ✅ Ready to use

**Questions?** See `GCP_CONSOLE_WALKTHROUGH.md` for detailed step-by-step instructions.
