$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root    = "C:\fh"
$Secrets = "$Root\secrets"
$DataDir = "C:\fh-data"
$ZipPath = "C:\fh.zip"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Family Health System Windows Setup" -ForegroundColor Cyan
Write-Host " install dir: $Root" -ForegroundColor Gray
Write-Host " data dir   : $DataDir" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/7] Killing stale processes ..." -ForegroundColor Yellow
$procNames = @("postgres","redis-server","qdrant","cloudflared","python","celery","uvicorn","node","npx","wrangler")
foreach ($n in $procNames) {
    Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if ($_.Path -and ($_.Path -like "$Root\*" -or $_.Path -like "$DataDir\*")) {
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
}
Start-Sleep -Seconds 2

Write-Host "[2/7] Removing old folders ..." -ForegroundColor Yellow
foreach ($p in @($Root, $DataDir, $ZipPath, "C:\jiating-jiankang")) {
    if (Test-Path $p) {
        try { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}

Write-Host "[3/7] Downloading zip ..." -ForegroundColor Yellow
$nocache = Get-Random
$ZipUrl  = "https://raw.githubusercontent.com/AIBlockBrain/fh-portable-download/main/%E5%AE%B6%E5%BA%AD%E5%81%A5%E5%BA%B7Windows%E4%BE%BF%E6%90%BA%E7%89%88.zip?n=$nocache"
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
} catch {
    Write-Host "[FAIL] Download failed: $_" -ForegroundColor Red
    Write-Host "Try: curl.exe -L -o C:\fh.zip $ZipUrl" -ForegroundColor Yellow
    exit 1
}
$zipSize = (Get-Item $ZipPath).Length
Write-Host "       zip = $zipSize bytes" -ForegroundColor Gray

Write-Host "[4/7] Extracting to $Root ..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $Root -Force | Out-Null
Expand-Archive -Path $ZipPath -DestinationPath $Root -Force

Write-Host "[5/7] Verifying _common.ps1 ..." -ForegroundColor Yellow
$commonPath = Join-Path $Root "scripts\_common.ps1"
if (-not (Test-Path $commonPath)) {
    Write-Host "[FAIL] _common.ps1 not found at $commonPath" -ForegroundColor Red
    exit 1
}
$commonContent = Get-Content $commonPath -Raw
if ($commonContent.Contains("C:\fh-data")) {
    Write-Host "       [OK] _common.ps1 has C:\fh-data" -ForegroundColor Green
} else {
    Write-Host "[WARN] _common.ps1 does not contain C:\fh-data string" -ForegroundColor Yellow
}

Write-Host "[6/7] Setup secrets ..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $Secrets -Force | Out-Null
$tokenFile = Join-Path $Secrets "github_token.txt"
if (-not (Test-Path $tokenFile)) {
    Write-Host ""
    Write-Host "Paste GitHub fine-grained PAT (starts with github_pat_ or gho_)" -ForegroundColor Cyan
    Write-Host "On Mac run: gh auth token" -ForegroundColor Gray
    $tok = Read-Host "Token"
    if ($tok -and $tok.Trim().Length -gt 10) {
        [System.IO.File]::WriteAllText($tokenFile, $tok.Trim(), [System.Text.Encoding]::ASCII)
        Write-Host "       [OK] token saved" -ForegroundColor Green
    } else {
        Write-Host "[WARN] token empty, you must edit $tokenFile manually before start.cmd" -ForegroundColor Yellow
    }
} else {
    Write-Host "       [OK] token already exists" -ForegroundColor Green
}

$envFile = Join-Path $Secrets "backend.env"
if (-not (Test-Path $envFile)) {
    Write-Host ""
    Write-Host "Opening notepad for backend.env. Paste content, save, close." -ForegroundColor Cyan
    Set-Content -Path $envFile -Value "" -Encoding UTF8
    Start-Process notepad.exe -ArgumentList $envFile -Wait
    if ((Get-Item $envFile).Length -lt 50) {
        Write-Host "[WARN] backend.env seems empty (<50 bytes). Edit before running start.cmd." -ForegroundColor Yellow
    } else {
        Write-Host "       [OK] backend.env saved" -ForegroundColor Green
    }
} else {
    Write-Host "       [OK] backend.env already exists" -ForegroundColor Green
}

Write-Host "[7/7] Done." -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation complete." -ForegroundColor Cyan
Write-Host "  Next: open $Root and double-click 启动.cmd" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try { Start-Process explorer.exe -ArgumentList $Root } catch {}
