# Deploy FastAPI service and daily job to Cloud Run
# Usage: .\scripts\deploy_cloud_run.ps1
# Set env vars first: $env:PROJECT_ID = "nba-predictions-29e45"; $env:STATE_BUCKET = "nba-prediction-data-metadata"

$ErrorActionPreference = "Stop"
$ProjectId = if ($env:PROJECT_ID) { $env:PROJECT_ID } else { "" }
$Region = if ($env:REGION) { $env:REGION } else { "us-west1" }
$StateBucket = if ($env:STATE_BUCKET) { $env:STATE_BUCKET } else { "" }
$StatePrefix = if ($env:STATE_PREFIX) { $env:STATE_PREFIX } else { "state" }

if (-not $ProjectId) {
    Write-Error "PROJECT_ID env var is required."
    exit 1
}
if (-not $StateBucket) {
    Write-Error "STATE_BUCKET env var is required."
    exit 1
}

$ApiImage = "gcr.io/$ProjectId/nba-predictions-api:latest"
$JobImage = "gcr.io/$ProjectId/nba-predictions-job:latest"
$ServiceEnvVars = "ENVIRONMENT=production,STATE_BUCKET=$StateBucket,STATE_PREFIX=$StatePrefix"

Write-Host "Building API image: $ApiImage"
gcloud builds submit `
  --project $ProjectId `
  --config cloudbuild.api.yaml `
  --substitutions "_IMAGE=$ApiImage" `
  .

Write-Host "Deploying Cloud Run service: nba-predictions-api"
gcloud run deploy nba-predictions-api `
  --project $ProjectId `
  --image $ApiImage `
  --region $Region `
  --platform managed `
  --allow-unauthenticated `
  --set-env-vars $ServiceEnvVars `
  --cpu 1 `
  --memory 512Mi `
  --min-instances 0 `
  --max-instances 2

$ServiceUrl = gcloud run services describe nba-predictions-api `
  --project $ProjectId `
  --region $Region `
  --format="value(status.url)"
$JobEnvVars = "$ServiceEnvVars,API_BASE_URL=$ServiceUrl"

Write-Host "Building job image: $JobImage"
gcloud builds submit `
  --project $ProjectId `
  --config cloudbuild.job.yaml `
  --substitutions "_IMAGE=$JobImage" `
  .

Write-Host "Creating/updating Cloud Run job: nba-predictions-daily-job"
$null = gcloud run jobs describe nba-predictions-daily-job --project $ProjectId --region $Region 2>&1
$JobExists = $?

if (-not $JobExists) {
    gcloud run jobs create nba-predictions-daily-job `
      --project $ProjectId `
      --image $JobImage `
      --region $Region `
      --set-env-vars $JobEnvVars `
      --tasks 1 `
      --max-retries 1
} else {
    gcloud run jobs update nba-predictions-daily-job `
      --project $ProjectId `
      --image $JobImage `
      --region $Region `
      --set-env-vars $JobEnvVars
}

Write-Host "Cloud Run API URL: $ServiceUrl"
Write-Host "Update app/.env: PRODUCTION_API_URL=$ServiceUrl"
Write-Host ""
Write-Host "To execute the job once for testing:"
Write-Host "  gcloud run jobs execute nba-predictions-daily-job --project $ProjectId --region $Region"
