# =============================================================================
#  NBA Predictions - Cloud Backend Deployment Script (Windows PowerShell)
# =============================================================================
#
#  Builds and deploys:
#    1. nba-predictions-api       (Cloud Run service - FastAPI)
#    2. nba-predictions-daily-job (Cloud Run job    - daily predictions)
#
#  USAGE:
#    $env:PROJECT_ID   = "your-project"
#    $env:STATE_BUCKET = "your-bucket"
#    .\scripts\deploy_backend_windows.ps1
#
#  ALL OPTIONS:
#    $env:PROJECT_ID                  = "my-project"
#    $env:STATE_BUCKET                = "my-state-bucket"
#    $env:MODEL_BUCKET                = "my-model-bucket"
#    $env:REGION                      = "us-west1"
#    $env:STATE_PREFIX                = "state"
#    $env:SKIP_TESTS                  = "false"
#    .\scripts\deploy_backend_windows.ps1
#
#  NOTE: If script execution is blocked, run first:
#    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#
#  PREREQUISITES:
#    - gcloud CLI installed and authenticated (gcloud auth login)
#    - Docker Desktop running
#    - GCP APIs enabled (see CLOUD_BACKEND_DEPLOYMENT.txt section 2)
# =============================================================================

$ErrorActionPreference = "Stop"

# ── Helper functions ──────────────────────────────────────────────────────────
function Write-Step   { param($msg) Write-Host "`n===> $msg" -ForegroundColor Cyan }
function Write-Info   { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok     { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn   { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err    { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ── Configuration (override via env vars) ────────────────────────────────────
$ProjectId    = if ($env:PROJECT_ID)    { $env:PROJECT_ID }    else { "" }
$Region       = if ($env:REGION)        { $env:REGION }        else { "us-west1" }
$StateBucket  = if ($env:STATE_BUCKET)  { $env:STATE_BUCKET }  else { "" }
$ModelBucket  = if ($env:MODEL_BUCKET)  { $env:MODEL_BUCKET }  else { "" }
$StatePrefix  = if ($env:STATE_PREFIX)  { $env:STATE_PREFIX }  else { "state" }
$SkipTests    = if ($env:SKIP_TESTS)    { $env:SKIP_TESTS }    else { "false" }

# Injury adjustment settings
$InjuryEnabled     = if ($env:INJURY_ADJUSTMENTS_ENABLED)   { $env:INJURY_ADJUSTMENTS_ENABLED }   else { "true" }
$InjuryMultiplier  = if ($env:INJURY_ADJUSTMENT_MULTIPLIER) { $env:INJURY_ADJUSTMENT_MULTIPLIER } else { "20" }
$InjuryMaxAdj      = if ($env:INJURY_MAX_ADJUSTMENT)        { $env:INJURY_MAX_ADJUSTMENT }        else { "-100" }
$InjuryCacheTtl    = if ($env:INJURY_CACHE_TTL)             { $env:INJURY_CACHE_TTL }             else { "14400" }
$LogInjuries       = if ($env:LOG_INJURY_ADJUSTMENTS)       { $env:LOG_INJURY_ADJUSTMENTS }       else { "true" }

# ── Validate required inputs ──────────────────────────────────────────────────
Write-Step "Validating configuration"

$HasErrors = $false
if (-not $ProjectId) {
    Write-Err "PROJECT_ID is required. Run: `$env:PROJECT_ID = 'my-project'"
    $HasErrors = $true
}
if (-not $StateBucket) {
    Write-Err "STATE_BUCKET is required. Run: `$env:STATE_BUCKET = 'my-bucket'"
    $HasErrors = $true
}
if ($HasErrors) {
    Write-Host "`n  See CLOUD_BACKEND_DEPLOYMENT.txt for full setup instructions." -ForegroundColor Yellow
    exit 1
}

$BucketForModel = if ($ModelBucket) { $ModelBucket } else { $StateBucket }

Write-Info "Project ID   : $ProjectId"
Write-Info "Region       : $Region"
Write-Info "State Bucket : $StateBucket"
Write-Info "Model Bucket : $BucketForModel"
Write-Info "State Prefix : $StatePrefix"

# ── Check dependencies ────────────────────────────────────────────────────────
Write-Step "Checking required tools"

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Err "gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install"
    exit 1
}
$GcloudVersion = (gcloud --version 2>&1 | Select-Object -First 1)
Write-Ok "gcloud: $GcloudVersion"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err "Docker not found. Install from https://docs.docker.com/get-docker/"
    exit 1
}
$null = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker daemon is not running. Start Docker Desktop first."
    exit 1
}
$DockerVersion = (docker --version)
Write-Ok "Docker: $DockerVersion"

# ── Authenticate & set project ────────────────────────────────────────────────
Write-Step "Configuring Google Cloud project"

gcloud config set project $ProjectId
if ($LASTEXITCODE -ne 0) { Write-Err "Failed to set project"; exit 1 }

gcloud auth configure-docker --quiet
if ($LASTEXITCODE -ne 0) { Write-Err "Failed to configure docker auth"; exit 1 }

Write-Ok "Active project: $ProjectId"

# ── Run local tests (optional) ────────────────────────────────────────────────
if ($SkipTests -ne "true") {
    Write-Step "Running local test suite"

    $PythonCmd = $null
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $PythonCmd = "python"
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        $PythonCmd = "python3"
    }

    if ($PythonCmd) {
        & $PythonCmd -m pytest test/ -v --tb=short
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Tests failed. Fix errors before deploying, or set `$env:SKIP_TESTS='true' to bypass."
            exit 1
        }
        Write-Ok "All tests passed"
    } else {
        Write-Warn "Python not found locally - skipping local tests. Cloud Build will still run them."
    }
} else {
    Write-Warn "SKIP_TESTS=true - skipping local tests (Cloud Build will still run them)"
}

# ── Image names & env vars ────────────────────────────────────────────────────
$ApiImage = "gcr.io/$ProjectId/nba-predictions-api:latest"
$JobImage = "gcr.io/$ProjectId/nba-predictions-job:latest"

$ServiceEnvVars = "ENVIRONMENT=production," +
                  "STATE_BUCKET=$StateBucket," +
                  "STATE_PREFIX=$StatePrefix," +
                  "MODEL_BUCKET=$BucketForModel," +
                  "INJURY_ADJUSTMENTS_ENABLED=$InjuryEnabled," +
                  "INJURY_ADJUSTMENT_MULTIPLIER=$InjuryMultiplier," +
                  "INJURY_MAX_ADJUSTMENT=$InjuryMaxAdj," +
                  "INJURY_CACHE_TTL=$InjuryCacheTtl," +
                  "LOG_INJURY_ADJUSTMENTS=$LogInjuries"

# ── Build & deploy API ────────────────────────────────────────────────────────
Write-Step "Building API image via Cloud Build: $ApiImage"

gcloud builds submit `
  --project $ProjectId `
  --config cloudbuild.api.yaml `
  --substitutions "_IMAGE=$ApiImage" `
  .
if ($LASTEXITCODE -ne 0) { Write-Err "Cloud Build failed for API image"; exit 1 }
Write-Ok "API image built and pushed"

Write-Step "Deploying Cloud Run service: nba-predictions-api"

gcloud run deploy nba-predictions-api `
  --project $ProjectId `
  --image $ApiImage `
  --region $Region `
  --platform managed `
  --allow-unauthenticated `
  --set-env-vars $ServiceEnvVars `
  --cpu 0.25 `
  --memory 512Mi `
  --min-instances 1 `
  --max-instances 2
if ($LASTEXITCODE -ne 0) { Write-Err "Cloud Run deploy failed for API"; exit 1 }

$ServiceUrl = gcloud run services describe nba-predictions-api `
  --project $ProjectId `
  --region $Region `
  --format="value(status.url)"
if ($LASTEXITCODE -ne 0) { Write-Err "Could not retrieve service URL"; exit 1 }

Write-Ok "API deployed: $ServiceUrl"

# ── Build & deploy Daily Job ──────────────────────────────────────────────────
Write-Step "Building job image via Cloud Build: $JobImage"

gcloud builds submit `
  --project $ProjectId `
  --config cloudbuild.job.yaml `
  --substitutions "_IMAGE=$JobImage" `
  .
if ($LASTEXITCODE -ne 0) { Write-Err "Cloud Build failed for job image"; exit 1 }
Write-Ok "Job image built and pushed"

$JobEnvVars = "$ServiceEnvVars,API_BASE_URL=$ServiceUrl"

Write-Step "Creating/updating Cloud Run job: nba-predictions-daily-job"

$null = gcloud run jobs describe nba-predictions-daily-job `
  --project $ProjectId `
  --region $Region 2>&1
$JobExists = ($LASTEXITCODE -eq 0)

if (-not $JobExists) {
    gcloud run jobs create nba-predictions-daily-job `
      --project $ProjectId `
      --image $JobImage `
      --region $Region `
      --set-env-vars $JobEnvVars `
      --tasks 1 `
      --max-retries 1
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create daily job"; exit 1 }
    Write-Ok "Daily job created"
} else {
    gcloud run jobs update nba-predictions-daily-job `
      --project $ProjectId `
      --image $JobImage `
      --region $Region `
      --set-env-vars $JobEnvVars
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to update daily job"; exit 1 }
    Write-Ok "Daily job updated"
}

# ── Health check ──────────────────────────────────────────────────────────────
Write-Step "Running health check"

Start-Sleep -Seconds 3
try {
    $Response = Invoke-WebRequest -Uri "$ServiceUrl/health" -UseBasicParsing -TimeoutSec 15
    if ($Response.StatusCode -eq 200) {
        Write-Ok "Health check passed (HTTP $($Response.StatusCode))"
    } else {
        Write-Warn "Health check returned HTTP $($Response.StatusCode)"
    }
} catch {
    Write-Warn "Health check failed - service may still be starting up"
    Write-Info "Check manually: curl $ServiceUrl/health"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  API URL:        $ServiceUrl" -ForegroundColor White
Write-Host "  Health:         $ServiceUrl/health" -ForegroundColor White
Write-Host "  Predictions:    $ServiceUrl/api/v1/predict/today" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "  1. Update app API URL to: $ServiceUrl"
Write-Host "  2. Update functions\.env:  RENDER_API_URL=$ServiceUrl"
Write-Host "  3. Set up Cloud Scheduler (runs daily job at 8:50 AM ET):"
Write-Host ""
Write-Host "     `$env:PROJECT_ID      = '$ProjectId'"
Write-Host "     `$env:REGION          = '$Region'"
Write-Host "     `$env:SERVICE_ACCOUNT = 'nba-scheduler-sa@$ProjectId.iam.gserviceaccount.com'"
Write-Host "     # Then run the Cloud Scheduler setup below:"
Write-Host ""
Write-Host "     `$RunUri = 'https://$Region-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$ProjectId/jobs/nba-predictions-daily-job:run'"
Write-Host "     gcloud scheduler jobs create http nba-predictions-daily-schedule ``"
Write-Host "       --project $ProjectId ``"
Write-Host "       --location $Region ``"
Write-Host "       --schedule '50 8 * * *' ``"
Write-Host "       --time-zone 'America/New_York' ``"
Write-Host "       --uri `$RunUri ``"
Write-Host "       --http-method POST ``"
Write-Host "       --oauth-service-account-email nba-scheduler-sa@$ProjectId.iam.gserviceaccount.com"
Write-Host ""
Write-Host "  Test the daily job manually:" -ForegroundColor Yellow
Write-Host "    gcloud run jobs execute nba-predictions-daily-job --project $ProjectId --region $Region"
Write-Host ""
Write-Host "  View logs:" -ForegroundColor Yellow
Write-Host "    gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=nba-predictions-api' --project=$ProjectId --limit=50"
Write-Host ""
