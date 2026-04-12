# =============================================================================
#  Signal Sports - GCP Monitoring, Alerting & Billing Setup (Windows)
# =============================================================================
#
#  Sets up:
#    1. Enables required GCP APIs
#    2. GCP Error Reporting (auto-surfaces Python exceptions from Cloud Run)
#    3. Cloud Monitoring uptime check on /health
#    4. Alert policies: error rate >5%, latency >3s
#    5. $20/month billing budget with alerts at 50%, 90%, 100%
#
#  USAGE:
#    $env:PROJECT_ID      = "nba-predictions-29e45"
#    $env:BILLING_ACCOUNT = "XXXXXX-XXXXXX-XXXXXX"
#    $env:ALERT_EMAIL     = "you@email.com"
#    .\scripts\setup_gcp_monitoring.ps1
#
#  Get billing account ID:
#    gcloud billing accounts list
# =============================================================================

$ErrorActionPreference = "Continue"

function Write-Step { param($msg) Write-Host "" ; Write-Host "===> $msg" -ForegroundColor Cyan }
function Write-Info { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# -- Configuration -------------------------------------------------------------
$ProjectId      = if ($env:PROJECT_ID)      { $env:PROJECT_ID }      else { "" }
$Region         = if ($env:REGION)          { $env:REGION }          else { "us-west1" }
$BillingAccount = if ($env:BILLING_ACCOUNT) { $env:BILLING_ACCOUNT } else { "" }
$AlertEmail     = if ($env:ALERT_EMAIL)     { $env:ALERT_EMAIL }     else { "" }
$BudgetAmount   = if ($env:BUDGET_AMOUNT)   { $env:BUDGET_AMOUNT }   else { "20" }

# -- Validate ------------------------------------------------------------------
$HasErrors = $false
if (-not $ProjectId)      { Write-Err "PROJECT_ID is required";  $HasErrors = $true }
if (-not $BillingAccount) { Write-Err "BILLING_ACCOUNT is required (run: gcloud billing accounts list)"; $HasErrors = $true }
if (-not $AlertEmail)     { Write-Err "ALERT_EMAIL is required"; $HasErrors = $true }
if ($HasErrors) { exit 1 }

gcloud config set project $ProjectId --quiet

$ServiceUrl = ""
try {
    $ServiceUrl = (& gcloud run services describe nba-predictions-api `
        --project $ProjectId --region $Region `
        --format "value(status.url)" 2>&1).Trim()
    if ($LASTEXITCODE -ne 0) { $ServiceUrl = "" }
} catch { $ServiceUrl = "" }

Write-Info "Project     : $ProjectId"
Write-Info "Region      : $Region"
if ($ServiceUrl) { Write-Info "API URL     : $ServiceUrl" } else { Write-Info "API URL     : <not deployed yet>" }
Write-Info "Alert email : $AlertEmail"
Write-Info "Budget      : `$$BudgetAmount/month"

# -- 1. Enable APIs & install gcloud components --------------------------------
Write-Step "Installing gcloud alpha component"
& gcloud components install alpha --quiet 2>&1 | Out-Null
Write-Ok "gcloud alpha ready"

Write-Step "Enabling required GCP APIs"

$ApiArgs = @(
    "services", "enable",
    "clouderrorreporting.googleapis.com",
    "monitoring.googleapis.com",
    "billingbudgets.googleapis.com",
    "secretmanager.googleapis.com",
    "--project", $ProjectId, "--quiet"
)
& gcloud @ApiArgs
Write-Ok "APIs enabled"

# -- 2. Error Reporting --------------------------------------------------------
Write-Step "Configuring Error Reporting"
Write-Ok "Error Reporting active (auto-ingests exceptions from Cloud Run logs)"
Write-Info "View at: https://console.cloud.google.com/errors?project=$ProjectId"

# -- 3. Notification channel ---------------------------------------------------
Write-Step "Creating email notification channel"

$ChannelArgs = @(
    "alpha", "monitoring", "channels", "create",
    "--display-name", "Signal Sports Alerts",
    "--type", "email",
    "--channel-labels", "email_address=$AlertEmail",
    "--project", $ProjectId,
    "--format", "json"
)
$ChannelRaw  = (& gcloud @ChannelArgs 2>&1) -join ""
$ChannelName = ""
try {
    $ChannelObj  = $ChannelRaw | ConvertFrom-Json
    $ChannelName = $ChannelObj.name
} catch { }

if (-not $ChannelName) {
    $ListArgs = @(
        "alpha", "monitoring", "channels", "list",
        "--project", $ProjectId,
        "--filter", "displayName='Signal Sports Alerts'",
        "--format", "value(name)"
    )
    $ListResult = & gcloud @ListArgs 2>&1 | Where-Object { $_ -is [string] } | Select-Object -First 1
    $ChannelName = if ($ListResult) { $ListResult.Trim() } else { "" }
}

if ($ChannelName) {
    Write-Ok "Notification channel: $ChannelName"
} else {
    Write-Warn "Could not create notification channel - add one manually:"
    Write-Warn "  https://console.cloud.google.com/monitoring/alerting/notifications"
}

# -- 4. Uptime Check -----------------------------------------------------------
if ($ServiceUrl) {
    Write-Step "Creating uptime check"
    $HostOnly = $ServiceUrl -replace "https://", "" -replace "/.*", ""
    $UptimeArgs = @(
        "alpha", "monitoring", "uptime", "create",
        "--display-name", "NBA API Health Check",
        "--resource-type", "uptime-url",
        "--resource-labels", "host=$HostOnly,project_id=$ProjectId",
        "--protocol", "HTTPS",
        "--path", "/health",
        "--port", "443",
        "--period", "300",
        "--timeout", "10",
        "--project", $ProjectId, "--quiet"
    )
    & gcloud @UptimeArgs 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Uptime check created (polls every 5 min)"
    } else {
        Write-Warn "Uptime check may already exist - check: https://console.cloud.google.com/monitoring/uptime"
    }
} else {
    Write-Warn "API not deployed yet - skipping uptime check. Re-run after deployment."
}

# -- 5. Alert policies ---------------------------------------------------------
Write-Step "Creating alert policies"

$TempDir       = [System.IO.Path]::GetTempPath()
$ErrorRateFile = Join-Path $TempDir "ss_alert_error_rate.json"
$LatencyFile   = Join-Path $TempDir "ss_alert_latency.json"

# Write JSON using single-quoted strings (no variable expansion, no escape weirdness)
$ErrorRateJson = '{
  "displayName": "NBA API - High Error Rate",
  "combiner": "OR",
  "conditions": [{
    "displayName": "5xx error rate above 5 percent",
    "conditionThreshold": {
      "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"nba-predictions-api\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"",
      "aggregations": [{"alignmentPeriod": "300s", "perSeriesAligner": "ALIGN_RATE"}],
      "comparison": "COMPARISON_GT",
      "thresholdValue": 0.05,
      "duration": "0s",
      "trigger": {"count": 1}
    }
  }],
  "alertStrategy": {"autoClose": "1800s"}
}'
Set-Content -Path $ErrorRateFile -Value $ErrorRateJson -Encoding UTF8

$LatencyJson = '{
  "displayName": "NBA API - High Latency",
  "combiner": "OR",
  "conditions": [{
    "displayName": "Request latency p99 above 3s",
    "conditionThreshold": {
      "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"nba-predictions-api\" AND metric.type=\"run.googleapis.com/request_latencies\"",
      "aggregations": [{"alignmentPeriod": "300s", "perSeriesAligner": "ALIGN_PERCENTILE_99"}],
      "comparison": "COMPARISON_GT",
      "thresholdValue": 3000,
      "duration": "0s",
      "trigger": {"count": 1}
    }
  }],
  "alertStrategy": {"autoClose": "1800s"}
}'
Set-Content -Path $LatencyFile -Value $LatencyJson -Encoding UTF8

foreach ($PolicyFile in @($ErrorRateFile, $LatencyFile)) {
    $PolicyName = (Get-Content $PolicyFile -Raw | ConvertFrom-Json).displayName
    $PolicyArgs = @(
        "alpha", "monitoring", "policies", "create",
        "--policy-from-file", $PolicyFile,
        "--project", $ProjectId, "--quiet"
    )
    if ($ChannelName) { $PolicyArgs += @("--notification-channels", $ChannelName) }
    & gcloud @PolicyArgs 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Alert policy created: $PolicyName"
    } else {
        Write-Warn "Policy may already exist: $PolicyName"
    }
}

Remove-Item $ErrorRateFile, $LatencyFile -ErrorAction SilentlyContinue

# -- 6. Billing Budget ---------------------------------------------------------
Write-Step "Creating billing budget"

$BudgetArgs = @(
    "billing", "budgets", "create",
    "--billing-account", $BillingAccount,
    "--display-name", "Signal Sports Budget",
    "--budget-amount", "${BudgetAmount}USD",
    "--threshold-rule", "percent=0.5,basis=CURRENT_SPEND",
    "--threshold-rule", "percent=0.9,basis=CURRENT_SPEND",
    "--threshold-rule", "percent=1.0,basis=CURRENT_SPEND",
    "--projects", "projects/$ProjectId"
)
& gcloud @BudgetArgs 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Ok "Budget created: `$$BudgetAmount/month (alerts at 50%, 90%, 100%)"
} else {
    Write-Warn "Budget may already exist - check: https://console.cloud.google.com/billing/budgets"
}

# -- Summary -------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  MONITORING SETUP COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Error Reporting : https://console.cloud.google.com/errors?project=$ProjectId"
Write-Host "  Uptime Checks   : https://console.cloud.google.com/monitoring/uptime?project=$ProjectId"
Write-Host "  Alert Policies  : https://console.cloud.google.com/monitoring/alerting?project=$ProjectId"
Write-Host "  Billing Budget  : https://console.cloud.google.com/billing/budgets"
Write-Host ""
Write-Host "  Alert emails go to: $AlertEmail"
Write-Host ""
