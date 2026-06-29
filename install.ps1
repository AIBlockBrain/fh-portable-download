# Family Health System . Windows One-Click Installer (ASCII-only paths)
# Usage in PowerShell:
#   iwr -useb "https://raw.githubusercontent.com/AIBlockBrain/fh-portable-download/main/install.ps1?n=$(Get-Random)" | iex

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root    = "C:\fh"
$Secrets = "$Root\secrets"
$DataDir = "C:\fh-data"
$ZipPath = "C:\fh.zip"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Family Health System - Windows Setup" -ForegroundColor Cyan
Write-Host " (install: $Root , data: $DataDir)" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 1. Kill stale processes ----------
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

# ---------- 2. Clean everything (real fresh start) ----------
Write-Host "[2/7] Removing old $Root and $DataDir ..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $Root    -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $DataDir -ErrorAction SilentlyContinue
Remove-Item -Force $ZipPath          -ErrorAction SilentlyContinue
# Best-effort: clean the legacy chinese-named dir if it still exists from earlier runs
$legacy = "$env:SystemDrive\" + [char]0x5BB6 + [char]0x5EAD + [char]0x5065 + [char]0x5EB7
Remove-Item -Recurse -Force $legacy -ErrorAction SilentlyContinue

# ---------- 3. Download latest zip (cache buster) ----------
Write-Host "[3/7] Downloading latest zip ..." -ForegroundColor Yellow
$nocache = Get-Random
$encoded = "%E5%AE%B6%E5%BA%AD%E5%81%A5%E5%BA%B7Windows%E4%BE%BF%E6%90%BA%E7%89%88.zip"
$zipUrl  = "https://github.com/AIBlockBrain/fh-portable-download/raw/main/$encoded" + "?n=$nocache"
Invoke-WebRequest -Uri $zipUrl -OutFile $ZipPath -UseBasicParsing
$zipSize = (Get-Item $ZipPath).Length
Write-Host "      Downloaded $zipSize bytes" -ForegroundColor Gray

# ---------- 4. Extract ----------
Write-Host "[4/7] Extracting to $Root ..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $Root -Force | Out-Null
Expand-Archive -Path $ZipPath -DestinationPath $Root -Force
New-Item -ItemType Directory -Path $Secrets -Force | Out-Null

# ---------- 5. Verify version ----------
Write-Host "[5/7] Verifying script version ..." -ForegroundColor Yellow
$commonPath = "$Root\scripts\_common.ps1"
if (-not (Test-Path $commonPath)) {
    Write-Host "[FAIL] $commonPath missing - extract failed" -ForegroundColor Red
    return
}
$cm = Get-Content $commonPath -Raw -Encoding UTF8
if (-not ($cm.Contains('C:\fh-data'))) {
    Write-Host "[FAIL] _common.ps1 has no 'C:\fh-data' marker. Old version?" -ForegroundColor Red
    return
}
Write-Host "      _common.ps1 OK" -ForegroundColor Green

# ---------- 6. GitHub token ----------
$tokenPath = "$Secrets\github_token.txt"
if (-not (Test-Path $tokenPath)) {
    Write-Host ""
    Write-Host "[6/7] GitHub Token needed (for cloning private repo)" -ForegroundColor Yellow
    Write-Host "      On Mac: run  gh auth token  and copy the printed string" -ForegroundColor Gray
    $token = Read-Host "      Paste token here (starts with gho_ or github_pat_)"
    $token = $token.Trim()
    if ($token.Length -lt 20) {
        Write-Host "[FAIL] token too short (got $($token.Length) chars). Aborted." -ForegroundColor Red
        return
    }
    Set-Content -Path $tokenPath -Value $token -NoNewline -Encoding ASCII
    Write-Host "      [OK] token saved ($($token.Length) chars)" -ForegroundColor Green
} else {
    $t = (Get-Content $tokenPath -Raw).Trim()
    Write-Host "[6/7] [OK] token already present" -ForegroundColor Green
}

# ---------- 7. backend.env ----------
$beEnv = "$Secrets\backend.env"
if (-not (Test-Path $beEnv)) {
    Write-Host ""
    Write-Host "[7/7] Missing backend.env - opening notepad now" -ForegroundColor Yellow
    Write-Host "      Paste content of Mac's backend/.env, save, close." -ForegroundColor Gray
    Start-Process notepad.exe -ArgumentList $beEnv
    Write-Host "      Waiting for you to save backend.env (Ctrl+S in notepad) ..." -ForegroundColor Gray
    while (-not (Test-Path $beEnv) -or (Get-Item $beEnv).Length -lt 50) {
        Start-Sleep -Seconds 2
    }
    Write-Host "      [OK] backend.env saved ($((Get-Item $beEnv).Length) bytes)" -ForegroundColor Green
} else {
    Write-Host "[7/7] [OK] backend.env present" -ForegroundColor Green
}

# ---------- Done ----------
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " READY." -ForegroundColor Green
Write-Host " Now double-click the start script in" -ForegroundColor Green
Write-Host " the folder that just opened." -ForegroundColor Green
Write-Host " (filename starts with the 2 chinese chars meaning 'start')" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Start-Process explorer.exe -ArgumentList $Root
