# AI Context Files for Vertex AI Agent

This directory contains structured data files that provide context to your Vertex AI agent for better NBA predictions and explanations.

## 📁 Files in This Directory

### 1. **model_context.json** (Essential) ✅
**Purpose:** Explains how the prediction model works, what features it uses, and how to interpret predictions.

**Contents:**
- Model architecture and features
- Confidence tier explanations
- Injury impact guidelines
- Common user questions and answers
- Model limitations and interpretation guide

**Usage:** Upload this to give your AI agent deep understanding of the prediction system.

---

### 2. **injury_report.json** (Generate Daily) 📋
**Purpose:** Current NBA injury report with all teams and their injured players.

**How to Generate:**
```bash
python src/export_injury_report.py
```

**Contents:**
- All NBA teams and their current injuries
- Player status (Out, Questionable, Doubtful)
- Injury severity scores
- Estimated Elo adjustments per team
- Detailed injury descriptions

**Update Frequency:** Daily (injuries change frequently)

**Why Important:** This is the MOST CRITICAL missing piece. Your AI can now answer questions like:
- "Are the Lakers dealing with any injuries?"
- "Why is the prediction different from yesterday?"
- "Should I be concerned about this game given injuries?"

---

### 3. **daily_predictions.json** (Auto-generated) 🎯
**Purpose:** Today's game predictions with probabilities and context.

**How to Generate:**
```bash
python src/daily_predictions.py --output predictions/daily.json --app-format
cp predictions/daily.json ai_context/daily_predictions.json
```

**Contents:**
- All scheduled games for today
- Win probabilities for each team
- Confidence tiers
- Elo ratings, recent form, rest days

**Update Frequency:** Daily

---

### 4. **team_lookup.csv** (Static Reference) 📊
**Purpose:** Mapping of team IDs to team names.

**Contents:**
- NBA team IDs (e.g., 1610612747 = Lakers)
- Full team names
- Useful for AI to translate between IDs and names

**Update Frequency:** Rarely (only when teams change)

---

## 🚀 How to Upload to Google Cloud Storage

### Option 1: Using GCP Console (Easiest)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **Cloud Storage > Buckets**
3. Click on your bucket (e.g., `nba-prediction-data-metadata`)
4. Click **Create Folder** → Name it `ai_context`
5. Click on the `ai_context` folder
6. Click **Upload Files**
7. Select all JSON files from this directory
8. Wait for upload to complete ✅

### Option 2: Using gsutil (Command Line)

```bash
# Upload all files at once
gsutil -m cp ai_context/*.json gs://nba-prediction-data-metadata/ai_context/

# Or upload one by one
gsutil cp ai_context/model_context.json gs://nba-prediction-data-metadata/ai_context/
gsutil cp ai_context/injury_report.json gs://nba-prediction-data-metadata/ai_context/
gsutil cp ai_context/daily_predictions.json gs://nba-prediction-data-metadata/ai_context/
```

### Option 3: Using Python Script

```python
from google.cloud import storage

client = storage.Client()
bucket = client.bucket('nba-prediction-data-metadata')

files = [
    'model_context.json',
    'injury_report.json',
    'daily_predictions.json',
]

for filename in files:
    blob = bucket.blob(f'ai_context/{filename}')
    blob.upload_from_filename(f'ai_context/{filename}')
    print(f'✓ Uploaded {filename}')
```

---

## 🤖 How to Add to Vertex AI Agent (GCP Console Walkthrough)

### Step 1: Navigate to Vertex AI Agent Builder

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. In the search bar at top, type **"Vertex AI Agent Builder"**
3. Click on **Vertex AI Agent Builder** in the results
4. Select your project (NBA Predictions)

### Step 2: Select Your Agent

1. Click on **Apps** in the left sidebar
2. Find and click on your NBA Predictions agent
3. This opens your agent's configuration page

### Step 3: Add Data Stores (Grounding Data)

#### Option A: Create New Data Store from Cloud Storage

1. In your agent configuration, look for **"Grounding"** or **"Data Stores"** section
2. Click **"Add Data Store"** or **"Create Data Store"**
3. Choose **"Cloud Storage"** as the source
4. Configure:
   - **Name:** `NBA Injury Reports`
   - **Data type:** Structured data
   - **Bucket path:** `gs://nba-prediction-data-metadata/ai_context/`
   - **File types:** JSON
5. Click **Create**
6. Repeat for each category of data if you want separate data stores

#### Option B: Upload Files Directly

1. In your agent configuration, find **"Grounding"** section
2. Click **"Upload Documents"**
3. Select your JSON files:
   - `model_context.json`
   - `injury_report.json`
   - `daily_predictions.json`
4. Click **Upload**

### Step 4: Configure Agent to Use the Data

1. In agent settings, find **"Instructions"** or **"System Instructions"**
2. Add instructions like:

```
You are an NBA game prediction assistant with access to:
- Current injury reports for all NBA teams
- Daily game predictions with probabilities
- Model context explaining how predictions are made

When users ask about games:
1. Check the daily predictions for win probabilities
2. Check the injury report for relevant team injuries
3. Use the model context to explain predictions accurately

Always mention significant injuries when discussing games.
Always explain confidence levels (Heavy Favorite, Toss-Up, etc.)
```

3. Enable **"Use grounding"** or **"Search data stores"** option
4. Select your uploaded data stores
5. Click **Save**

### Step 5: Test the Agent

1. In the **"Test"** tab or panel, ask:
   - "Are there any injuries I should know about for tonight's games?"
   - "What injuries are the Lakers dealing with?"
   - "Why is team X favored in tonight's game?"
   
2. Verify the agent references the uploaded data

---

## ⚙️ Automation: Daily Updates

### Automated Pipeline (Recommended)

Create a Cloud Function or Cloud Run job that runs daily:

```bash
#!/bin/bash
# daily_update_ai_context.sh

# Generate fresh injury report
python src/export_injury_report.py

# Generate today's predictions
python src/daily_predictions.py --output ai_context/daily_predictions.json --app-format

# Upload to GCS
gsutil -m cp ai_context/*.json gs://nba-prediction-data-metadata/ai_context/

echo "✓ AI context updated"
```

### Manual Daily Update

Run these commands each morning:

```bash
cd ~/development/Basketball_Prediction

# Update injury report
python src/export_injury_report.py

# Update predictions
python src/daily_predictions.py --output ai_context/daily_predictions.json --app-format

# Upload to GCS
gsutil -m cp ai_context/*.json gs://nba-prediction-data-metadata/ai_context/
```

---

## 📋 What to Add (Priority Order)

### High Priority (Add Immediately)
1. ✅ **model_context.json** - Already created, upload now
2. 🔄 **injury_report.json** - Generate and upload daily
3. 🔄 **daily_predictions.json** - Already being generated, just upload

### Medium Priority (Nice to Have)
4. **team_lookup.csv** - Static reference (upload once)
5. **elo_history.json** - Team Elo rating history (optional)
6. **prediction_accuracy.json** - Model performance stats (if available)

### Low Priority (Future Enhancement)
7. **player_importance.json** - List of All-Stars and key players
8. **matchup_history.json** - Head-to-head records
9. **betting_edges.json** - Games where model disagrees with markets

---

## 🎯 Expected Impact

### Before Adding Context
**User:** "Why is Lakers vs Celtics a toss-up?"  
**AI:** "Based on the prediction model, both teams have similar win probabilities around 50%."

### After Adding Context
**User:** "Why is Lakers vs Celtics a toss-up?"  
**AI:** "The model shows Lakers at 51% vs Celtics at 49% - essentially a toss-up. However, the Lakers are dealing with significant injuries: LeBron James (Out - ankle) and Anthony Davis (Questionable - knee). This injury situation drops the Lakers' Elo by approximately 65 points. If AD also sits, this could shift to favor the Celtics by 10-15%."

---

## 📞 Troubleshooting

### "AI doesn't seem to use the uploaded data"
- Check that data stores are enabled in agent configuration
- Verify grounding is turned on
- Make sure file formats are valid JSON
- Check file permissions in GCS (should be readable)

### "Injury data is outdated"
- Set up daily automation to regenerate injury_report.json
- Injuries change daily, manual updates needed

### "File upload fails"
- Check file size limits (usually 10MB per file)
- Verify JSON is valid: `python -m json.tool < file.json`
- Check GCS bucket permissions

---

## 📚 Additional Resources

- [Vertex AI Agent Builder Documentation](https://cloud.google.com/generative-ai-app-builder/docs)
- [Cloud Storage Documentation](https://cloud.google.com/storage/docs)
- [Grounding in Vertex AI](https://cloud.google.com/vertex-ai/docs/generative-ai/grounding/overview)

---

**Last Updated:** 2026-02-11  
**Maintained By:** Basketball Prediction System
