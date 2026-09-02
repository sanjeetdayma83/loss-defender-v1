# LOSS DEFENDER V1 — Structure fix + verify
# Run from repo root:  powershell -ExecutionPolicy Bypass -File .\scripts\FIX-AND-VERIFY.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $Root "backend\package.json"))) {
  $Root = Get-Location
}
Set-Location $Root
Write-Host "Repo root: $Root" -ForegroundColor Cyan

# 1) Remove accidental root src (backend is the only source)
$rootSrc = Join-Path $Root "src"
if (Test-Path $rootSrc) {
  Remove-Item -Recurse -Force $rootSrc
  Write-Host "Removed root src/ (duplicate)" -ForegroundColor Yellow
}

# 2) Strip UTF-8 BOM from backend text files
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
Get-ChildItem -Path (Join-Path $Root "backend") -Recurse -Include *.ts,*.json,*.prisma,*.md,.env* -File -ErrorAction SilentlyContinue |
  ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
      $text = [System.IO.File]::ReadAllText($_.FullName)
      if ([int][char]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
      [System.IO.File]::WriteAllText($_.FullName, $text, $utf8NoBom)
      Write-Host "BOM stripped: $($_.FullName)" -ForegroundColor Green
    }
  }

# 3) Ensure .env exists
$envPath = Join-Path $Root "backend\.env"
$example = Join-Path $Root "backend\.env.example"
if (-not (Test-Path $envPath) -and (Test-Path $example)) {
  Copy-Item $example $envPath
  Write-Host "Created backend\.env from example — FILL Neon + Clerk keys" -ForegroundColor Yellow
}

# 4) Generate Prisma client
Set-Location (Join-Path $Root "backend")
if (-not (Test-Path "node_modules")) {
  Write-Host "npm install..." -ForegroundColor Cyan
  npm install --no-audit --no-fund
}
npx prisma generate

Write-Host ""
Write-Host "DONE. Next:" -ForegroundColor Green
Write-Host '  cd backend'
Write-Host '  # ensure DATABASE_URL in .env is real Neon URL'
Write-Host '  npx prisma migrate deploy'
Write-Host '  npm run start:dev'
Write-Host ""
Write-Host 'Then test:' -ForegroundColor Cyan
Write-Host '  Invoke-RestMethod http://localhost:3000/api/v1/health'
Write-Host '  Invoke-RestMethod http://localhost:3000/api/v1/billing/plans'
