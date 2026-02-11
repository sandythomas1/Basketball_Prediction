#!/bin/bash
# Update AI Context Files and Upload to GCS
# Usage: ./update_ai_context.sh

set -e  # Exit on error

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "========================================================================"
echo "NBA Predictions - AI Context Update"
echo "========================================================================"
echo ""

# Check if gsutil is installed
if ! command -v gsutil &> /dev/null; then
    echo "⚠️  Warning: gsutil not found. Install Google Cloud SDK to enable auto-upload."
    echo "   Visit: https://cloud.google.com/sdk/docs/install"
    UPLOAD=false
else
    UPLOAD=true
fi

# Generate injury report
echo "📋 Generating injury report..."
if python3 src/export_injury_report.py; then
    echo "✅ Injury report generated"
else
    echo "❌ Failed to generate injury report"
    exit 1
fi

# Check if daily predictions exist, if not generate them
if [ ! -f "predictions/daily.json" ]; then
    echo ""
    echo "📊 Generating daily predictions..."
    python3 src/daily_predictions.py --output predictions/daily.json --app-format
fi

# Copy daily predictions to ai_context
echo ""
echo "📁 Copying daily predictions..."
cp predictions/daily.json ai_context/daily_predictions.json
echo "✅ Daily predictions copied"

# Upload to GCS if gsutil is available
if [ "$UPLOAD" = true ]; then
    echo ""
    echo "☁️  Uploading to Google Cloud Storage..."
    
    BUCKET="nba-prediction-data-metadata"
    
    # Upload all context files
    gsutil -m cp \
        ai_context/model_context.json \
        ai_context/injury_report.json \
        ai_context/daily_predictions.json \
        ai_context/team_lookup.csv \
        "gs://${BUCKET}/ai_context/" 2>/dev/null || {
        
        echo ""
        echo "⚠️  Upload failed. You may need to:"
        echo "   1. Authenticate: gcloud auth login"
        echo "   2. Set project: gcloud config set project YOUR_PROJECT_ID"
        echo "   3. Or upload manually through GCP Console"
        echo ""
        echo "Files are ready in: $PROJECT_ROOT/ai_context/"
        exit 1
    }
    
    echo "✅ All files uploaded to gs://${BUCKET}/ai_context/"
else
    echo ""
    echo "⚠️  Skipping upload (gsutil not available)"
    echo "📁 Files generated in: $PROJECT_ROOT/ai_context/"
    echo ""
    echo "To upload manually:"
    echo "  1. Go to: https://console.cloud.google.com/storage"
    echo "  2. Open bucket: nba-prediction-data-metadata"
    echo "  3. Upload files from: $PROJECT_ROOT/ai_context/"
fi

echo ""
echo "========================================================================"
echo "✅ AI Context Update Complete"
echo "========================================================================"
echo ""
echo "Files ready:"
ls -lh ai_context/*.json ai_context/*.csv 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'
echo ""
echo "Last updated: $(date)"
echo ""
