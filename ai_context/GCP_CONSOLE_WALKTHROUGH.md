# Step-by-Step: Adding Context Files to Vertex AI Agent

This guide walks you through uploading your context files to Google Cloud Storage and configuring your Vertex AI agent to use them.

---

## 📋 Quick Summary

**What we're doing:**
1. Upload 4 files to Google Cloud Storage
2. Configure Vertex AI agent to use these files as grounding data
3. Test that the agent can answer questions using the new context

**Time required:** 10-15 minutes

---

## Part 1: Upload Files to Google Cloud Storage

### Step 1.1: Navigate to Cloud Storage

1. Open [Google Cloud Console](https://console.cloud.google.com)
2. Make sure you're in the **NBA Predictions** project (check top bar)
3. Click the **☰ menu** (hamburger menu) in top-left corner
4. Scroll down to **"Cloud Storage"**
5. Click **"Buckets"**

You should see your buckets list. Based on your screenshot, you have:
- `nba-prediction-data-metadata` ✅ (We'll use this one)
- `gcf-sources-...`
- `nba-predictions-29e45.firebasestorage...`

### Step 1.2: Open Your Bucket

1. Click on **`nba-prediction-data-metadata`** bucket
2. You should see the current contents (if any)

### Step 1.3: Create ai_context Folder

1. Click the **"CREATE FOLDER"** button (near top of page)
2. In the popup:
   - **Folder name:** `ai_context`
3. Click **"CREATE"**

### Step 1.4: Upload Files

1. Click on the **`ai_context`** folder you just created
2. Click the **"UPLOAD FILES"** button
3. In the file picker, navigate to your project:
   ```
   /Users/sandythomas/development/Basketball_Prediction/ai_context/
   ```
4. Select these files:
   - ✅ `model_context.json`
   - ✅ `daily_predictions.json`
   - ✅ `team_lookup.csv`
   
5. Click **"Open"** to start upload
6. Wait for the upload to complete (progress bar at bottom)
7. You should see ✅ **"Upload complete"** notification

### Step 1.5: Verify Upload

Your bucket should now show:
```
gs://nba-prediction-data-metadata/ai_context/
  ├── model_context.json
  ├── daily_predictions.json
  └── team_lookup.csv
```

**✅ Part 1 Complete!** Files are now in Cloud Storage.

---

## Part 2: Generate and Upload Injury Report

### Step 2.1: Generate Injury Report Locally

Open your terminal and run:

```bash
cd ~/development/Basketball_Prediction

# Generate current injury report
python3 src/export_injury_report.py
```

You should see output like:
```
======================================================================
NBA Injury Report Generator
======================================================================

Initializing...
Fetching current injury data from ESPN API...
✓ Found injury data for 29 teams

✓ Saved injury report to ai_context/injury_report.json

📋 Teams with significant injuries (8):
  • Washington Wizards: 3 injuries (Elo -80)
  • Portland Trail Blazers: 2 injuries (Elo -55)
  ...
```

### Step 2.2: Upload Injury Report to GCS

#### Option A: Using GCP Console (Easiest)

1. Go back to Cloud Console → Cloud Storage → `nba-prediction-data-metadata` → `ai_context`
2. Click **"UPLOAD FILES"**
3. Select `ai_context/injury_report.json`
4. Click **"Open"**

#### Option B: Using gsutil Command (Faster)

```bash
gsutil cp ai_context/injury_report.json gs://nba-prediction-data-metadata/ai_context/
```

**✅ Part 2 Complete!** Injury data is now uploaded.

---

## Part 3: Configure Vertex AI Agent

### Step 3.1: Navigate to Vertex AI Agent Builder

1. In Google Cloud Console, use the **search bar at the very top**
2. Type: `Vertex AI Agent Builder`
3. Click on **"Vertex AI Agent Builder"** in the results
4. Or navigate: **☰ Menu → Artificial Intelligence → Vertex AI Agent Builder**

### Step 3.2: Find Your Agent/App

1. In the left sidebar, click **"Apps"**
2. You should see your NBA Predictions agent listed
3. Click on your agent name to open it

### Step 3.3: Add Data Store

Now we need to tell the agent about the files we uploaded.

#### Option A: Create Data Store from Cloud Storage (Recommended)

1. In your agent view, look for **"Data"** or **"Grounding"** tab
   - Location varies by interface version
   - Look for tabs at top or left sidebar
   
2. Click **"Create Data Store"** or **"Add Data Store"**

3. In the creation dialog:
   - **Data store name:** `NBA_Context_Data`
   - **Data type:** Select **"Unstructured data"** or **"Files"**
   - **Source:** Select **"Cloud Storage"**
   
4. Configure source:
   - **Bucket:** `nba-prediction-data-metadata`
   - **Folder:** `ai_context/`
   - OR **Full path:** `gs://nba-prediction-data-metadata/ai_context/*`
   
5. Click **"Create"**

6. Wait for indexing to complete (may take 1-5 minutes)

#### Option B: Upload Files Directly (Alternative)

If you can't find Cloud Storage option:

1. Look for **"Upload documents"** or **"Add documents"**
2. Click **"Upload from Computer"**
3. Select all 4 JSON/CSV files from `ai_context/`
4. Click **"Upload"**

### Step 3.4: Configure Agent Instructions

1. In your agent configuration, find **"Agent Instructions"** or **"System Instructions"**
   - Usually in **"Configure"** or **"Settings"** tab
   
2. Add or update the system instructions to include:

```
You are an NBA game prediction assistant with access to real-time data including:

DATA SOURCES:
- Current injury reports for all 30 NBA teams (updated daily)
- Today's game predictions with win probabilities and confidence levels
- Detailed model context explaining how predictions are calculated
- Team information including Elo ratings and recent performance

INSTRUCTIONS:
1. When users ask about specific games, always check:
   - The daily predictions for win probabilities
   - The injury report for both teams involved
   - The confidence tier to explain prediction reliability

2. When discussing injuries:
   - Mention significant injuries (Out, Doubtful, Questionable)
   - Explain the expected impact on win probability
   - Reference the Elo adjustment from the injury report

3. When explaining predictions:
   - Use the model context to explain WHY a team is favored
   - Mention key factors: Elo ratings, recent form, rest, injuries
   - Always explain the confidence tier (Heavy Favorite, Toss-Up, etc.)

4. Be transparent about uncertainty:
   - Toss-up games (near 50/50) are genuinely uncertain
   - Even heavy favorites can lose
   - Acknowledge model limitations

5. Always cite your sources:
   - "According to the injury report..."
   - "The model predicts..."
   - "Based on current Elo ratings..."

IMPORTANT: Always check injury data FIRST before discussing any game, as injuries can significantly impact predictions.
```

3. Click **"Save"** or **"Update"**

### Step 3.5: Enable Grounding

1. Look for **"Grounding"** settings in agent configuration
2. Make sure these are enabled:
   - ✅ **"Use grounding"** or **"Search data stores"**
   - ✅ **"Search enterprise data"** (if available)
   
3. Select your data store:
   - Check the box next to `NBA_Context_Data` (or whatever you named it)
   
4. Configure grounding settings (if available):
   - **Search depth:** Medium or High
   - **Max sources:** 5-10
   - **Citation style:** Show sources
   
5. Click **"Save"**

**✅ Part 3 Complete!** Agent is now configured to use your data.

---

## Part 4: Test Your Agent

### Step 4.1: Open Test Panel

1. Look for a **"Test"** tab or **"Preview"** button
2. Click to open the test chat interface

### Step 4.2: Run Test Queries

Try these questions to verify the agent can access your data:

#### Test 1: Injury Data
```
User: "What injuries are affecting the Los Angeles Lakers right now?"
```

**Expected:** Agent should list current Lakers injuries from `injury_report.json`

#### Test 2: Game Predictions
```
User: "What are the predictions for tonight's games?"
```

**Expected:** Agent should reference `daily_predictions.json` and list games with probabilities

#### Test 3: Model Context
```
User: "How does the prediction model work?"
```

**Expected:** Agent should explain features, Elo ratings, etc. from `model_context.json`

#### Test 4: Integrated Response
```
User: "Should I be worried about the Celtics game tonight given their injury situation?"
```

**Expected:** Agent should:
- Check daily predictions for any Celtics game
- Check injury report for Celtics
- Explain impact on win probability
- Reference confidence tier

### Step 4.3: Verify Citations

When the agent answers:
- Look for **footnotes** or **citations** like `[1]`, `[2]`
- These should reference your uploaded files
- Click to verify it's pulling from the right source

**✅ Part 4 Complete!** Agent is working with your context data.

---

## 🔄 Daily Maintenance

To keep your agent current, run this **every morning**:

```bash
#!/bin/bash
# File: update_ai_context.sh

cd ~/development/Basketball_Prediction

# Generate fresh injury report
python3 src/export_injury_report.py

# Generate today's predictions (if not already done)
python3 src/daily_predictions.py --output ai_context/daily_predictions.json --app-format

# Upload to GCS
gsutil -m cp ai_context/injury_report.json gs://nba-prediction-data-metadata/ai_context/
gsutil -m cp ai_context/daily_predictions.json gs://nba-prediction-data-metadata/ai_context/

echo "✅ AI context updated for $(date)"
```

Make it executable:
```bash
chmod +x update_ai_context.sh
```

Run it:
```bash
./update_ai_context.sh
```

Or set up a cron job:
```bash
crontab -e

# Add this line to run every day at 8 AM
0 8 * * * cd ~/development/Basketball_Prediction && ./update_ai_context.sh
```

---

## 🐛 Troubleshooting

### Problem: "Agent doesn't seem to use the uploaded data"

**Solutions:**
1. Check that grounding is **enabled** in agent settings
2. Verify data store is **selected** in grounding configuration
3. Check that files are actually in GCS bucket (browse to verify)
4. Try asking more specific questions: "According to the injury report, what injuries do the Lakers have?"
5. Wait a few minutes after upload for indexing to complete

### Problem: "Upload to GCS fails"

**Solutions:**
1. Check you're logged in: `gcloud auth login`
2. Set correct project: `gcloud config set project YOUR_PROJECT_ID`
3. Verify bucket exists: `gsutil ls gs://nba-prediction-data-metadata/`
4. Check file size (should be under 10MB)

### Problem: "Injury report script fails"

**Solutions:**
1. Check internet connection (needs to fetch from ESPN API)
2. Install dependencies: `pip install requests`
3. Verify Python path: `python3 --version` (should be 3.8+)
4. Run with full path: `python3 /Users/sandythomas/development/Basketball_Prediction/src/export_injury_report.py`

### Problem: "Agent gives outdated injury information"

**Solutions:**
1. Regenerate injury report: `python3 src/export_injury_report.py`
2. Re-upload to GCS
3. Wait 2-5 minutes for Vertex AI to re-index
4. Try asking: "What's in the latest injury report?"

---

## 📊 What You've Achieved

After completing this guide, your Vertex AI agent now has:

✅ **Real-time injury data** - Knows about all current NBA injuries  
✅ **Daily predictions** - Can discuss today's games with probabilities  
✅ **Model context** - Understands how predictions are made  
✅ **Team reference data** - Can translate team IDs to names  

This means your agent can now:
- ✅ Answer "Why is this team favored?" with actual data
- ✅ Warn users about injury impacts on predictions
- ✅ Explain confidence levels accurately
- ✅ Provide context-aware, data-grounded responses

---

## 🎯 Next Steps (Optional Enhancements)

1. **Add historical data:** Upload past injury reports to show trends
2. **Add betting edges:** Upload games where model disagrees with markets
3. **Add team trends:** Upload recent performance streaks
4. **Automate updates:** Set up Cloud Function to regenerate daily
5. **Add more sources:** Include news articles, analyst opinions, etc.

---

## 📞 Need Help?

- Vertex AI docs: https://cloud.google.com/vertex-ai/docs/generative-ai/grounding/overview
- Cloud Storage docs: https://cloud.google.com/storage/docs
- Your project: https://console.cloud.google.com

---

**Created:** 2026-02-11  
**Last Updated:** 2026-02-11  
**Status:** ✅ Ready to use
