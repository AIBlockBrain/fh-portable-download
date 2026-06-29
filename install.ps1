# 家庭健康系统 · Windows 一键安装脚本
# 用法 (在 PowerShell 里):
#   iwr -useb "https://raw.githubusercontent.com/AIBlockBrain/fh-portable-download/main/install.ps1?n=$(Get-Random)" | iex

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " 家庭健康系统 . Windows 一键安装" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 1. 杀掉残留进程 ----------
Write-Host "[1/7] 清理旧进程..." -ForegroundColor Yellow
$names = @("cmd","postgres","redis-server","qdrant","cloudflared")
foreach ($n in $names) {
    Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Path -and ($_.Path -like "C:\家庭健康\*" -or $_.Path -like "C:\fh-data\*")) {
            try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}
# python 单独处理 (避免杀掉用户自己的 python)
Get-Process -Name python -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Path -like "C:\家庭健康\*") {
        try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}

# ---------- 2. 清理旧脚本/代码/数据 (runtime 保留以避免重下 350MB) ----------
Write-Host "[2/7] 清理旧 scripts / repo / data ..." -ForegroundColor Yellow
Remove-Item -Recurse -Force C:\家庭健康\scripts -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force C:\家庭健康\repo    -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force C:\家庭健康\logs    -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force C:\家庭健康\pids    -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force C:\家庭健康\data    -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force C:\fh-data           -ErrorAction SilentlyContinue
Remove-Item -Force C:\家庭健康\*.cmd            -ErrorAction SilentlyContinue
Remove-Item -Force C:\家庭健康\.bootstrapped     -ErrorAction SilentlyContinue

# ---------- 3. 下载最新 zip (cache buster 强制不走 CDN 缓存) ----------
Write-Host "[3/7] 下载最新 zip ..." -ForegroundColor Yellow
Remove-Item -Force C:\fh.zip -ErrorAction SilentlyContinue
$nocache = Get-Random
$zipUrl = "https://github.com/AIBlockBrain/fh-portable-download/raw/main/%E5%AE%B6%E5%BA%AD%E5%81%A5%E5%BA%B7Windows%E4%BE%BF%E6%90%BA%E7%89%88.zip?n=$nocache"
Invoke-WebRequest -Uri $zipUrl -OutFile C:\fh.zip -UseBasicParsing
$zipSize = (Get-Item C:\fh.zip).Length
Write-Host "      zip = $zipSize bytes" -ForegroundColor Gray

# ---------- 4. 解压 ----------
Write-Host "[4/7] 解压到 C:\家庭健康 ..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path C:\家庭健康 -Force | Out-Null
Expand-Archive -Path C:\fh.zip -DestinationPath C:\家庭健康 -Force
New-Item -ItemType Directory -Path C:\家庭健康\secrets -Force | Out-Null

# ---------- 5. 自检版本 (用 Contains, 不用 -match, 更稳) ----------
Write-Host "[5/7] 自检脚本版本 ..." -ForegroundColor Yellow
$commonPath = "C:\家庭健康\scripts\_common.ps1"
if (-not (Test-Path $commonPath)) {
    Write-Host "[FAIL] $commonPath 不存在! 解压失败" -ForegroundColor Red
    return
}
$cm = Get-Content $commonPath -Raw -Encoding UTF8
if (-not ($cm.Contains('C:\fh-data'))) {
    Write-Host "[FAIL] _common.ps1 不是 v1.5+ (没找到 C:\fh-data)" -ForegroundColor Red
    Write-Host "       请截图给开发者" -ForegroundColor Yellow
    return
}
Write-Host "      _common.ps1 = v1.5+ (DATA -> C:\fh-data)" -ForegroundColor Green

# ---------- 6. GitHub Token ----------
$tokenPath = "C:\家庭健康\secrets\github_token.txt"
if (-not (Test-Path $tokenPath)) {
    Write-Host ""
    Write-Host "[6/7] 缺少 GitHub Token" -ForegroundColor Yellow
    Write-Host "      在 Mac 上跑: gh auth token   (复制输出的字符串)" -ForegroundColor Gray
    $token = Read-Host "      在这里粘贴 token (开头 gho_ 或 github_pat_), 按回车"
    $token = $token.Trim()
    if (-not $token) {
        Write-Host "[FAIL] token 为空，安装中止" -ForegroundColor Red
        return
    }
    Set-Content -Path $tokenPath -Value $token -NoNewline -Encoding ASCII
    Write-Host "      [OK] token 已保存 (长度 $($token.Length))" -ForegroundColor Green
} else {
    $t = (Get-Content $tokenPath -Raw).Trim()
    if ($t.Length -lt 20) {
        Write-Host "[6/7] [FAIL] token 文件存在但内容异常 (长度 $($t.Length))" -ForegroundColor Red
        return
    }
    Write-Host "[6/7] [OK] token 已存在 (长度 $($t.Length), 开头 $($t.Substring(0,4))...)" -ForegroundColor Green
}

# ---------- 7. backend.env ----------
$beEnv = "C:\家庭健康\secrets\backend.env"
if (-not (Test-Path $beEnv)) {
    Write-Host ""
    Write-Host "[7/7] [FAIL] 缺少 $beEnv" -ForegroundColor Red
    Write-Host "      把 Mac 上 backend/.env 的内容贴进这个文件:" -ForegroundColor Yellow
    Write-Host "      notepad $beEnv" -ForegroundColor Cyan
    Write-Host "      然后双击 C:\家庭健康\启动.cmd" -ForegroundColor Cyan
    explorer C:\家庭健康\secrets
    return
}
$beSize = (Get-Item $beEnv).Length
if ($beSize -lt 50) {
    Write-Host "[7/7] [WARN] backend.env 太小 ($beSize bytes), 内容可能不完整" -ForegroundColor Yellow
} else {
    Write-Host "[7/7] [OK] backend.env 存在 ($beSize bytes)" -ForegroundColor Green
}

# ---------- 完成 ----------
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  全部就绪, 接下来做一件事:" -ForegroundColor Green
Write-Host "  双击 C:\家庭健康\启动.cmd" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
explorer C:\家庭健康
