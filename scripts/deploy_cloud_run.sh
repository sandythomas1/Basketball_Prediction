#!/usr/bin/env bash

set -euo pipefail

# Simple helper script to build and deploy the FastAPI service and daily job to Cloud Run.
# Usage:
#   PROJECT_ID=your-project REGION=us-central1 ./scripts/deploy_cloud_run.sh

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-central1}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "ERROR: PROJECT_ID env var is required."
  exit 1
fi

API_IMAGE="gcr.io/${PROJECT_ID}/nba-predictions-api:latest"
JOB_IMAGE="gcr.io/${PROJECT_ID}/nba-predictions-job:latest"

echo "Building API image: ${API_IMAGE}"
gcloud builds submit --tag "${API_IMAGE}" .

echo "Deploying Cloud Run service: nba-predictions-api"
gcloud run deploy nba-predictions-api \
  --image "${API_IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --allow-unauthenticated \
  --cpu 0.25 \
  --memory 512Mi \
  --min-instances 1 \
  --max-instances 2

echo "Building job image: ${JOB_IMAGE}"
gcloud builds submit --tag "${JOB_IMAGE}" .

echo "Creating/updating Cloud Run job: nba-predictions-daily-job"
gcloud run jobs describe nba-predictions-daily-job --region "${REGION}" >/dev/null 2>&1 && \
  JOB_EXISTS=1 || JOB_EXISTS=0

if [[ "$JOB_EXISTS" -eq 0 ]]; then
  gcloud run jobs create nba-predictions-daily-job \
    --image "${JOB_IMAGE}" \
    --region "${REGION}" \
    --tasks 1 \
    --max-retries 1
else
  gcloud run jobs update nba-predictions-daily-job \
    --image "${JOB_IMAGE}" \
    --region "${REGION}"
fi

echo "To execute the job once for testing:"
echo "  gcloud run jobs execute nba-predictions-daily-job --region ${REGION}"

