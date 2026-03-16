#!/usr/bin/env bash

set -euo pipefail

# Helper script to create a Cloud Scheduler job that triggers the
# nba-predictions-daily-job Cloud Run Job at 8:50 AM ET daily.
# Usage:
#   PROJECT_ID=your-project REGION=us-west1 SERVICE_ACCOUNT=sa@project.iam.gserviceaccount.com ./scripts/create_cloud_scheduler_job.sh

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-west1}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "ERROR: PROJECT_ID env var is required."
  exit 1
fi

if [[ -z "$SERVICE_ACCOUNT" ]]; then
  echo "ERROR: SERVICE_ACCOUNT env var is required."
  exit 1
fi

SCHEDULER_LOCATION="${SCHEDULER_LOCATION:-us-west1}"

JOB_NAME="nba-predictions-daily-schedule"
CRON_SCHEDULE="${CRON_SCHEDULE:-50 8 * * *}" # 8:50 AM ET

RUN_URI="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/nba-predictions-daily-job:run"

echo "Creating/updating Cloud Scheduler job: ${JOB_NAME}"

gcloud scheduler jobs describe "${JOB_NAME}" \
  --project "${PROJECT_ID}" \
  --location "${SCHEDULER_LOCATION}" >/dev/null 2>&1 && \
  JOB_EXISTS=1 || JOB_EXISTS=0

if [[ "$JOB_EXISTS" -eq 0 ]]; then
  gcloud scheduler jobs create http "${JOB_NAME}" \
    --project "${PROJECT_ID}" \
    --location="${SCHEDULER_LOCATION}" \
    --schedule="${CRON_SCHEDULE}" \
    --time-zone="America/New_York" \
    --uri="${RUN_URI}" \
    --http-method=POST \
    --oauth-service-account-email="${SERVICE_ACCOUNT}"
else
  gcloud scheduler jobs update http "${JOB_NAME}" \
    --project "${PROJECT_ID}" \
    --location="${SCHEDULER_LOCATION}" \
    --schedule="${CRON_SCHEDULE}" \
    --time-zone="America/New_York" \
    --uri="${RUN_URI}" \
    --http-method=POST \
    --oauth-service-account-email="${SERVICE_ACCOUNT}"
fi

echo "Cloud Scheduler job ${JOB_NAME} is configured to run nba-predictions-daily-job daily at 8:50 AM ET."

