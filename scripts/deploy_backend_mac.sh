#!/usr/bin/env bash
# =============================================================================
#  NBA Predictions - Cloud Backend Deployment Script (Mac / Linux)
# =============================================================================
#
#  Builds and deploys:
#    1. nba-predictions-api   (Cloud Run service  - FastAPI)
#    2. nba-predictions-daily-job (Cloud Run job  - daily predictions)
#
#  USAGE:
#    chmod +x scripts/deploy_backend_mac.sh
#    PROJECT_ID=your-project STATE_BUCKET=your-bucket ./scripts/deploy_backend_mac.sh
#
#  ALL OPTIONS:
#    PROJECT_ID=my-project \
#    STATE_BUCKET=my-state-bucket \
#    MODEL_BUCKET=my-model-bucket \
#    REGION=us-west1 \
#    STATE_PREFIX=state \
#    SKIP_TESTS=false \
#    ./scripts/deploy_backend_mac.sh
#
#  PREREQUISITES:
#    - gcloud CLI installed and authenticated (gcloud auth login)
#    - Docker Desktop running
#    - GCP APIs enabled (see CLOUD_BACKEND_DEPLOYMENT.txt section 2)
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()    { echo -e "\n${BOLD}${CYAN}===> $*${RESET}"; }

# ── Configuration (override via env vars) ────────────────────────────────────
PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-west1}"
STATE_BUCKET="${STATE_BUCKET:-}"
MODEL_BUCKET="${MODEL_BUCKET:-}"
STATE_PREFIX="${STATE_PREFIX:-state}"
SKIP_TESTS="${SKIP_TESTS:-false}"

# Injury adjustment settings (optional overrides)
INJURY_ADJUSTMENTS_ENABLED="${INJURY_ADJUSTMENTS_ENABLED:-true}"
INJURY_ADJUSTMENT_MULTIPLIER="${INJURY_ADJUSTMENT_MULTIPLIER:-20}"
INJURY_MAX_ADJUSTMENT="${INJURY_MAX_ADJUSTMENT:--100}"
INJURY_CACHE_TTL="${INJURY_CACHE_TTL:-14400}"
LOG_INJURY_ADJUSTMENTS="${LOG_INJURY_ADJUSTMENTS:-true}"

# ── Validate required inputs ──────────────────────────────────────────────────
log_step "Validating configuration"

ERRORS=0
if [[ -z "$PROJECT_ID" ]]; then
  log_error "PROJECT_ID is required. Set it as an env var: export PROJECT_ID=my-project"
  ERRORS=$((ERRORS + 1))
fi
if [[ -z "$STATE_BUCKET" ]]; then
  log_error "STATE_BUCKET is required. Set it as an env var: export STATE_BUCKET=my-bucket"
  ERRORS=$((ERRORS + 1))
fi
if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "  See CLOUD_BACKEND_DEPLOYMENT.txt for full setup instructions."
  exit 1
fi

log_info "Project ID   : ${PROJECT_ID}"
log_info "Region       : ${REGION}"
log_info "State Bucket : ${STATE_BUCKET}"
log_info "Model Bucket : ${MODEL_BUCKET:-<not set, using STATE_BUCKET>}"
log_info "State Prefix : ${STATE_PREFIX}"

# ── Check dependencies ────────────────────────────────────────────────────────
log_step "Checking required tools"

if ! command -v gcloud &>/dev/null; then
  log_error "gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install"
  exit 1
fi
log_success "gcloud $(gcloud --version 2>&1 | head -1)"

if ! command -v docker &>/dev/null; then
  log_error "Docker not found. Install from https://docs.docker.com/get-docker/"
  exit 1
fi
if ! docker info &>/dev/null; then
  log_error "Docker daemon is not running. Start Docker Desktop first."
  exit 1
fi
log_success "Docker $(docker --version)"

# ── Authenticate & set project ────────────────────────────────────────────────
log_step "Configuring Google Cloud project"

gcloud config set project "${PROJECT_ID}"
gcloud auth configure-docker --quiet
log_success "Active project: ${PROJECT_ID}"

# ── Run local tests (optional) ────────────────────────────────────────────────
if [[ "${SKIP_TESTS}" == "false" ]]; then
  log_step "Running local test suite"
  if command -v python3 &>/dev/null; then
    PYTHON=python3
  elif command -v python &>/dev/null; then
    PYTHON=python
  else
    log_warn "Python not found locally — skipping local tests. Cloud Build will still run them."
    PYTHON=""
  fi

  if [[ -n "$PYTHON" ]]; then
    $PYTHON -m pytest test/ -v --tb=short && \
      log_success "All tests passed" || \
      { log_error "Tests failed. Fix errors before deploying, or set SKIP_TESTS=true to bypass."; exit 1; }
  fi
else
  log_warn "SKIP_TESTS=true — skipping local test suite (Cloud Build will still run tests)"
fi

# ── Build & push container images ─────────────────────────────────────────────
API_IMAGE="gcr.io/${PROJECT_ID}/nba-predictions-api:latest"
JOB_IMAGE="gcr.io/${PROJECT_ID}/nba-predictions-job:latest"

BUCKET_FOR_MODEL="${MODEL_BUCKET:-${STATE_BUCKET}}"
SERVICE_ENV_VARS="ENVIRONMENT=production,STATE_BUCKET=${STATE_BUCKET},STATE_PREFIX=${STATE_PREFIX},MODEL_BUCKET=${BUCKET_FOR_MODEL},INJURY_ADJUSTMENTS_ENABLED=${INJURY_ADJUSTMENTS_ENABLED},INJURY_ADJUSTMENT_MULTIPLIER=${INJURY_ADJUSTMENT_MULTIPLIER},INJURY_MAX_ADJUSTMENT=${INJURY_MAX_ADJUSTMENT},INJURY_CACHE_TTL=${INJURY_CACHE_TTL},LOG_INJURY_ADJUSTMENTS=${LOG_INJURY_ADJUSTMENTS}"

# ── Deploy API ────────────────────────────────────────────────────────────────
log_step "Building API image via Cloud Build: ${API_IMAGE}"

gcloud builds submit \
  --project "${PROJECT_ID}" \
  --config cloudbuild.api.yaml \
  --substitutions "_IMAGE=${API_IMAGE}" \
  .

log_success "API image built and pushed"

log_step "Deploying Cloud Run service: nba-predictions-api"

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

log_success "API deployed: ${SERVICE_URL}"

# ── Deploy Daily Job ──────────────────────────────────────────────────────────
log_step "Building job image via Cloud Build: ${JOB_IMAGE}"

gcloud builds submit \
  --project "${PROJECT_ID}" \
  --config cloudbuild.job.yaml \
  --substitutions "_IMAGE=${JOB_IMAGE}" \
  .

log_success "Job image built and pushed"

JOB_ENV_VARS="${SERVICE_ENV_VARS},API_BASE_URL=${SERVICE_URL}"

log_step "Creating/updating Cloud Run job: nba-predictions-daily-job"

JOB_EXISTS=0
gcloud run jobs describe nba-predictions-daily-job \
  --project "${PROJECT_ID}" \
  --region "${REGION}" >/dev/null 2>&1 && JOB_EXISTS=1 || JOB_EXISTS=0

if [[ "$JOB_EXISTS" -eq 0 ]]; then
  gcloud run jobs create nba-predictions-daily-job \
    --project "${PROJECT_ID}" \
    --image "${JOB_IMAGE}" \
    --region "${REGION}" \
    --set-env-vars "${JOB_ENV_VARS}" \
    --tasks 1 \
    --max-retries 1
  log_success "Daily job created"
else
  gcloud run jobs update nba-predictions-daily-job \
    --project "${PROJECT_ID}" \
    --image "${JOB_IMAGE}" \
    --region "${REGION}" \
    --set-env-vars "${JOB_ENV_VARS}"
  log_success "Daily job updated"
fi

# ── Health check ──────────────────────────────────────────────────────────────
log_step "Running health check"

sleep 3
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/health" || echo "000")

if [[ "$HTTP_STATUS" == "200" ]]; then
  log_success "Health check passed (HTTP ${HTTP_STATUS})"
else
  log_warn "Health check returned HTTP ${HTTP_STATUS} — service may still be starting up"
  log_info "Check manually: curl ${SERVICE_URL}/health"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}============================================================${RESET}"
echo -e "${BOLD}${GREEN}  DEPLOYMENT COMPLETE${RESET}"
echo -e "${BOLD}${GREEN}============================================================${RESET}"
echo ""
echo -e "  ${BOLD}API URL:${RESET}        ${SERVICE_URL}"
echo -e "  ${BOLD}Health:${RESET}         ${SERVICE_URL}/health"
echo -e "  ${BOLD}Predictions:${RESET}    ${SERVICE_URL}/api/v1/predict/today"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo -e "  1. Update app API URL to: ${SERVICE_URL}"
echo -e "  2. Update functions/.env:  RENDER_API_URL=${SERVICE_URL}"
echo -e "  3. Set up Cloud Scheduler (runs daily job at 8:50 AM ET):"
echo -e "     PROJECT_ID=${PROJECT_ID} SERVICE_ACCOUNT=nba-scheduler-sa@${PROJECT_ID}.iam.gserviceaccount.com \\"
echo -e "     ./scripts/create_cloud_scheduler_job.sh"
echo ""
echo -e "  ${BOLD}Test the daily job manually:${RESET}"
echo -e "    gcloud run jobs execute nba-predictions-daily-job --project ${PROJECT_ID} --region ${REGION}"
echo ""
echo -e "  ${BOLD}View logs:${RESET}"
echo -e "    gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=nba-predictions-api' --project=${PROJECT_ID} --limit=50"
echo ""
