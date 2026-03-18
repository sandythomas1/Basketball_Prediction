#!/usr/bin/env bash

set -euo pipefail

# Helper script to build and deploy the FastAPI service and daily job to Cloud Run.
# Usage:
#   PROJECT_ID=your-project STATE_BUCKET=your-state-bucket ./scripts/deploy_cloud_run.sh

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-west1}"
STATE_BUCKET="${STATE_BUCKET:-}"
STATE_PREFIX="${STATE_PREFIX:-state}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "ERROR: PROJECT_ID env var is required."
  exit 1
fi
if [[ -z "$STATE_BUCKET" ]]; then
  echo "ERROR: STATE_BUCKET env var is required."
  exit 1
fi

API_IMAGE="gcr.io/${PROJECT_ID}/nba-predictions-api:latest"
JOB_IMAGE="gcr.io/${PROJECT_ID}/nba-predictions-job:latest"
SERVICE_ENV_VARS="ENVIRONMENT=production,STATE_BUCKET=${STATE_BUCKET},STATE_PREFIX=${STATE_PREFIX}"

echo "Building API image: ${API_IMAGE}"
gcloud builds submit \
  --project "${PROJECT_ID}" \
  --config cloudbuild.api.yaml \
  --substitutions "_IMAGE=${API_IMAGE}" \
  .

echo "Deploying Cloud Run service: nba-predictions-api"
gcloud run deploy nba-predictions-api \
  --project "${PROJECT_ID}" \
  --image "${API_IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "${SERVICE_ENV_VARS}" \
  --cpu 0.25 \
  --memory 512Mi \
  --min-instances 1 \
  --max-instances 2

SERVICE_URL="$(gcloud run services describe nba-predictions-api \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --format='value(status.url)')"
JOB_ENV_VARS="${SERVICE_ENV_VARS},API_BASE_URL=${SERVICE_URL}"

echo "Building job image: ${JOB_IMAGE}"
gcloud builds submit \
  --project "${PROJECT_ID}" \
  --config cloudbuild.job.yaml \
  --substitutions "_IMAGE=${JOB_IMAGE}" \
  .

echo "Creating/updating Cloud Run job: nba-predictions-daily-job"
gcloud run jobs describe nba-predictions-daily-job \
  --project "${PROJECT_ID}" \
  --region "${REGION}" >/dev/null 2>&1 && \
  JOB_EXISTS=1 || JOB_EXISTS=0

if [[ "$JOB_EXISTS" -eq 0 ]]; then
  gcloud run jobs create nba-predictions-daily-job \
    --project "${PROJECT_ID}" \
    --image "${JOB_IMAGE}" \
    --region "${REGION}" \
    --set-env-vars "${JOB_ENV_VARS}" \
    --tasks 1 \
    --max-retries 1
else
  gcloud run jobs update nba-predictions-daily-job \
    --project "${PROJECT_ID}" \
    --image "${JOB_IMAGE}" \
    --region "${REGION}" \
    --set-env-vars "${JOB_ENV_VARS}"
fi

echo "Cloud Run API URL: ${SERVICE_URL}"
echo "Update functions/.env: RENDER_API_URL=${SERVICE_URL}"
echo "Update app API URL to: ${SERVICE_URL}"

echo "To execute the job once for testing:"
echo "  gcloud run jobs execute nba-predictions-daily-job --project ${PROJECT_ID} --region ${REGION}"
