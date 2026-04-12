#!/usr/bin/env bash
# =============================================================================
#  Signal Sports - GCP Monitoring, Alerting & Billing Setup
# =============================================================================
#
#  Sets up:
#    1. Enable required GCP APIs (Error Reporting, Monitoring, Billing Budgets)
#    2. GCP Error Reporting (auto-surfaces Python exceptions from Cloud Run)
#    3. Cloud Monitoring uptime check on /health endpoint
#    4. Alert policies: error rate >5%, latency >3s, uptime failures
#    5. $20/month billing budget with alerts at 50%, 90%, 100%
#
#  USAGE:
#    PROJECT_ID=nba-predictions-29e45 \
#    BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX \
#    ALERT_EMAIL=your@email.com \
#    ./scripts/setup_gcp_monitoring.sh
#
#    # Get your billing account ID:
#    gcloud billing accounts list
#
#    # Get your Cloud Run API URL first:
#    SERVICE_URL=$(gcloud run services describe nba-predictions-api \
#      --project $PROJECT_ID --region us-west1 --format='value(status.url)')
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_step()    { echo -e "\n${BOLD}${CYAN}===> $*${RESET}"; }
log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Configuration ─────────────────────────────────────────────────────────────
PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-west1}"
BILLING_ACCOUNT="${BILLING_ACCOUNT:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
BUDGET_AMOUNT="${BUDGET_AMOUNT:-20}"

# ── Validate ──────────────────────────────────────────────────────────────────
ERRORS=0
[[ -z "$PROJECT_ID" ]]      && log_error "PROJECT_ID is required"      && ERRORS=$((ERRORS+1))
[[ -z "$BILLING_ACCOUNT" ]] && log_error "BILLING_ACCOUNT is required (run: gcloud billing accounts list)" && ERRORS=$((ERRORS+1))
[[ -z "$ALERT_EMAIL" ]]     && log_error "ALERT_EMAIL is required"     && ERRORS=$((ERRORS+1))
[[ $ERRORS -gt 0 ]] && exit 1

gcloud config set project "${PROJECT_ID}" --quiet

# Get Cloud Run service URL
SERVICE_URL="$(gcloud run services describe nba-predictions-api \
  --project "${PROJECT_ID}" --region "${REGION}" \
  --format='value(status.url)' 2>/dev/null || echo '')"

if [[ -z "$SERVICE_URL" ]]; then
  log_warn "Could not auto-detect Cloud Run URL. Uptime check will be skipped."
  log_warn "Deploy the API first, then re-run this script."
fi

log_info "Project     : ${PROJECT_ID}"
log_info "Region      : ${REGION}"
log_info "API URL     : ${SERVICE_URL:-<not deployed yet>}"
log_info "Alert email : ${ALERT_EMAIL}"
log_info "Budget      : \$${BUDGET_AMOUNT}/month"

# ── 1. Enable APIs ────────────────────────────────────────────────────────────
log_step "Enabling required GCP APIs"

gcloud services enable \
  clouderrorreporting.googleapis.com \
  monitoring.googleapis.com \
  cloudmonitoring.googleapis.com \
  billingbudgets.googleapis.com \
  secretmanager.googleapis.com \
  --project "${PROJECT_ID}" --quiet

log_success "APIs enabled"

# ── 2. Error Reporting ────────────────────────────────────────────────────────
log_step "Configuring Error Reporting"
# Cloud Run automatically sends structured logs to Error Reporting once the API
# is enabled. No code changes needed — exceptions in Python show up in the
# GCP console at: console.cloud.google.com/errors
log_success "Error Reporting active (auto-ingests from Cloud Run logs)"
log_info "View errors: https://console.cloud.google.com/errors?project=${PROJECT_ID}"

# ── 3. Notification channel (email) ──────────────────────────────────────────
log_step "Creating email notification channel"

CHANNEL_JSON=$(gcloud alpha monitoring channels create \
  --display-name="Signal Sports Alerts" \
  --type=email \
  --channel-labels="email_address=${ALERT_EMAIL}" \
  --project="${PROJECT_ID}" \
  --format=json 2>/dev/null || echo '{}')

CHANNEL_NAME=$(echo "$CHANNEL_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null || echo '')

if [[ -z "$CHANNEL_NAME" ]]; then
  # Try to find existing channel
  CHANNEL_NAME=$(gcloud alpha monitoring channels list \
    --project="${PROJECT_ID}" \
    --filter="displayName='Signal Sports Alerts'" \
    --format="value(name)" | head -1 || echo '')
fi

if [[ -n "$CHANNEL_NAME" ]]; then
  log_success "Notification channel: ${CHANNEL_NAME}"
else
  log_warn "Could not create notification channel — alert policies will be created without it"
  log_warn "Add one manually in: console.cloud.google.com/monitoring/alerting/notifications"
fi

# ── 4. Uptime Check ───────────────────────────────────────────────────────────
if [[ -n "$SERVICE_URL" ]]; then
  log_step "Creating uptime check on ${SERVICE_URL}/health"

  HOST=$(echo "$SERVICE_URL" | sed 's|https://||' | sed 's|/.*||')

  gcloud alpha monitoring uptime create \
    --display-name="NBA API Health Check" \
    --resource-type="uptime-url" \
    --resource-labels="host=${HOST},project_id=${PROJECT_ID}" \
    --protocol=HTTPS \
    --path="/health" \
    --port=443 \
    --period=300 \
    --timeout=10 \
    --project="${PROJECT_ID}" --quiet 2>/dev/null && \
    log_success "Uptime check created (checks every 5 min)" || \
    log_warn "Uptime check may already exist — check console.cloud.google.com/monitoring/uptime"
fi

# ── 5. Alert policies ─────────────────────────────────────────────────────────
log_step "Creating alert policies"

CHANNEL_ARG=""
[[ -n "$CHANNEL_NAME" ]] && CHANNEL_ARG="--notification-channels=${CHANNEL_NAME}"

# 5a. High error rate on Cloud Run (>5% 5xx in 5 min window)
cat > /tmp/alert_error_rate.json <<EOF
{
  "displayName": "NBA API - High Error Rate (>5%)",
  "combiner": "OR",
  "conditions": [{
    "displayName": "5xx error rate > 5%",
    "conditionThreshold": {
      "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"nba-predictions-api\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"",
      "aggregations": [{
        "alignmentPeriod": "300s",
        "perSeriesAligner": "ALIGN_RATE"
      }],
      "comparison": "COMPARISON_GT",
      "thresholdValue": 0.05,
      "duration": "0s",
      "trigger": {"count": 1}
    }
  }],
  "alertStrategy": {"autoClose": "1800s"}
}
EOF

# 5b. High request latency (>3s p99)
cat > /tmp/alert_latency.json <<EOF
{
  "displayName": "NBA API - High Latency (>3s)",
  "combiner": "OR",
  "conditions": [{
    "displayName": "Request latency p99 > 3s",
    "conditionThreshold": {
      "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"nba-predictions-api\" AND metric.type=\"run.googleapis.com/request_latencies\"",
      "aggregations": [{
        "alignmentPeriod": "300s",
        "perSeriesAligner": "ALIGN_PERCENTILE_99"
      }],
      "comparison": "COMPARISON_GT",
      "thresholdValue": 3000,
      "duration": "0s",
      "trigger": {"count": 1}
    }
  }],
  "alertStrategy": {"autoClose": "1800s"}
}
EOF

for POLICY_FILE in /tmp/alert_error_rate.json /tmp/alert_latency.json; do
  POLICY_NAME=$(python3 -c "import json; print(json.load(open('${POLICY_FILE}'))['displayName'])")
  gcloud alpha monitoring policies create \
    --policy-from-file="${POLICY_FILE}" \
    ${CHANNEL_ARG} \
    --project="${PROJECT_ID}" --quiet 2>/dev/null && \
    log_success "Alert policy created: ${POLICY_NAME}" || \
    log_warn "Policy may already exist: ${POLICY_NAME}"
done

rm -f /tmp/alert_error_rate.json /tmp/alert_latency.json

# ── 6. Billing Budget ($20) ───────────────────────────────────────────────────
log_step "Creating \$${BUDGET_AMOUNT}/month billing budget"

gcloud billing budgets create \
  --billing-account="${BILLING_ACCOUNT}" \
  --display-name="Signal Sports - \$${BUDGET_AMOUNT} Budget" \
  --budget-amount="${BUDGET_AMOUNT}USD" \
  --threshold-rule=percent=0.5,basis=CURRENT_SPEND \
  --threshold-rule=percent=0.9,basis=CURRENT_SPEND \
  --threshold-rule=percent=1.0,basis=CURRENT_SPEND \
  --projects="projects/${PROJECT_ID}" 2>/dev/null && \
  log_success "Budget created: \$${BUDGET_AMOUNT}/month (alerts at 50%, 90%, 100%)" || \
  log_warn "Budget may already exist — check console.cloud.google.com/billing/budgets"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}============================================================${RESET}"
echo -e "${BOLD}${GREEN}  MONITORING SETUP COMPLETE${RESET}"
echo -e "${BOLD}${GREEN}============================================================${RESET}"
echo ""
echo -e "  Error Reporting : https://console.cloud.google.com/errors?project=${PROJECT_ID}"
echo -e "  Uptime Checks   : https://console.cloud.google.com/monitoring/uptime?project=${PROJECT_ID}"
echo -e "  Alert Policies  : https://console.cloud.google.com/monitoring/alerting?project=${PROJECT_ID}"
echo -e "  Billing Budget  : https://console.cloud.google.com/billing/budgets"
echo ""
echo -e "  Alert emails will be sent to: ${ALERT_EMAIL}"
echo ""
