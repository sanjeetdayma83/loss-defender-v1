# LOSS DEFENDER V1 — P0 setup (run from repo root)
# powershell -ExecutionPolicy Bypass -File .\scripts\SETUP-P0.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $Root "backend\package.json"))) { $Root = Get-Location }
Set-Location $Root
Write-Host "Root: $Root" -ForegroundColor Cyan

# 1) gitignore secrets check
if (Test-Path "backend\.env") {
  $tracked = git check-ignore -q backend\.env 2>$null; if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: backend\.env may not be gitignored — check .gitignore" -ForegroundColor Yellow
  } else { Write-Host "[OK] .env is ignored" -ForegroundColor Green }
}

# 2) env file
if (-not (Test-Path "backend\.env")) {
  Copy-Item "backend\.env.example" "backend\.env"
  Write-Host "Created backend\.env — FILL Neon + Clerk (+ optional B2, SEED_ADMIN_CLERK_ID)" -ForegroundColor Yellow
  notepad "backend\.env"
}

# 3) deps + prisma
Set-Location (Join-Path $Root "backend")
if (-not (Test-Path "node_modules")) { npm install --no-audit --no-fund }
npx prisma generate
npx prisma migrate deploy
npm run seed

Write-Host "`nNext:" -ForegroundColor Cyan
Write-Host "  1) npm run start:dev"
Write-Host "  2) Sign in Clerk with SEED admin email (or accept invite)"
Write-Host "  3) Copy session JWT → `$env:CLERK_TOKEN=..."
Write-Host "  4) `$env:ORDER_ID=<from seed> ; powershell -File ..\scripts\e2e-smoke.ps1"
Write-Host "  5) Prod: npm run build ; pm2 start ecosystem.config.cjs"
Write-Host "     Or: docker compose up -d --build  (from repo root)"
