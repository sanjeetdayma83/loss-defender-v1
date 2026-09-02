# LOSS DEFENDER V1 — one-time E2E smoke (PowerShell)
# Usage:
#   $env:API = "http://localhost:3000/api/v1"
#   $env:CLERK_TOKEN = "eyJ..."   # from Clerk session after sign-in
#   $env:ORDER_ID = "..."         # from seed output
#   powershell -ExecutionPolicy Bypass -File .\scripts\e2e-smoke.ps1

$ErrorActionPreference = "Stop"
$Api = if ($env:API) { $env:API } else { "http://localhost:3000/api/v1" }
$Token = $env:CLERK_TOKEN
$OrderId = $env:ORDER_ID

function Invoke-Api($Method, $Path, $Body = $null) {
  $headers = @{ "Content-Type" = "application/json" }
  if ($Token) { $headers["Authorization"] = "Bearer $Token" }
  $uri = "$Api$Path"
  if ($Body -ne $null) {
    $json = $Body | ConvertTo-Json -Depth 10 -Compress
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $json
  }
  return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

Write-Host "API=$Api" -ForegroundColor Cyan

# --- Public ---
$h = Invoke-Api GET "/health"
if (-not $h.success) { throw "health failed" }
Write-Host "[OK] health" -ForegroundColor Green

$p = Invoke-Api GET "/billing/plans"
if (-not $p.success) { throw "plans failed" }
Write-Host "[OK] billing/plans ($($p.data.Count) plans)" -ForegroundColor Green

# --- Auth required ---
if (-not $Token) {
  Write-Host "[SKIP] Set CLERK_TOKEN for protected path tests" -ForegroundColor Yellow
  exit 0
}

$sync = Invoke-Api GET "/auth/sync"
Write-Host "[OK] auth/sync role=$($sync.data.role) company=$($sync.data.companyId)" -ForegroundColor Green

$me = Invoke-Api GET "/companies/me"
Write-Host "[OK] companies/me $($me.data.companyName)" -ForegroundColor Green

$kpis = Invoke-Api GET "/analytics/kpis"
Write-Host "[OK] analytics/kpis ordersTotal=$($kpis.data.ordersTotal)" -ForegroundColor Green

if (-not $OrderId) {
  Write-Host "[SKIP] Set ORDER_ID from seed for packing path" -ForegroundColor Yellow
  exit 0
}

# Scan path (sample SKUs from seed)
foreach ($sku in @("SKU-RED-TEE", "SKU-RED-TEE", "SKU-BLUE-JEANS")) {
  $scan = Invoke-Api POST "/scanner/validate" @{ orderId = $OrderId; barcode = $sku }
  Write-Host "[SCAN] $sku -> $($scan.data.code) allComplete=$($scan.data.allComplete)" -ForegroundColor Green
}

$rec = Invoke-Api POST "/recordings/start" @{ orderId = $OrderId }
$rid = $rec.data.id
Write-Host "[OK] recording start $rid" -ForegroundColor Green

$init = Invoke-Api POST "/upload/init" @{ recordingId = $rid; sequence = 1 }
Write-Host "[OK] upload init key=$($init.data.key) b2=$($init.data.b2Configured)" -ForegroundColor Green

$done = Invoke-Api POST "/upload/complete" @{
  recordingId = $rid
  sequence = 1
  b2Key = $init.data.key
  sizeBytes = 1024
  checksum = "dev-checksum"
}
Write-Host "[OK] upload complete segments=$($done.data.segmentCount)" -ForegroundColor Green

$stop = Invoke-Api POST "/recordings/$rid/stop"
Write-Host "[OK] recording stop evidence=$($stop.data.evidence.id)" -ForegroundColor Green

$disp = Invoke-Api POST "/orders/$OrderId/dispatch" @{ awb = "AWB-DEMO-001"; courier = "Delhivery" }
Write-Host "[OK] dispatch status=$($disp.data.status)" -ForegroundColor Green

Write-Host "`nE2E SMOKE PASSED" -ForegroundColor Green
