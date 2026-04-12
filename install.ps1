$ErrorActionPreference = "Stop"
$InstallDir = "$env:USERPROFILE\NexusTG"
$RepoUrl = "https://github.com/newfpv/NexusTGTest.git"
$TotalSteps = 5

function Draw-ProgressBar {
    param([int]$Step, [string]$Text)
    $Percent = [math]::Round(($Step / $TotalSteps) * 100)
    $Filled = [math]::Round(($Step * 20) / $TotalSteps)
    $Empty = 20 - $Filled
    $BarFilled = "█" * $Filled
    $BarEmpty = "░" * $Empty
    Write-Host "`n[${BarFilled}${BarEmpty}] ${Percent}% | Step ${Step}/${TotalSteps} - $Text" -ForegroundColor Cyan
}

Clear-Host
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  ✨ Welcome to the NexusTG (AI Twin) Installer ✨  " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Super-fast Native Windows Installation using 'uv' 🚀"

# ---------------------------------------------------------
# STEP 1: Git
# ---------------------------------------------------------
Draw-ProgressBar 1 "Checking Git..."
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not found. Installing via winget..." -ForegroundColor Yellow
    winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements
    Write-Host "⚠️ Git installed! Please restart PowerShell and run this script again." -ForegroundColor Red
    exit
} else {
    Write-Host "✔ Git is ready!" -ForegroundColor Green
}

# ---------------------------------------------------------
# STEP 2: Project Files
# ---------------------------------------------------------
Draw-ProgressBar 2 "Downloading project files..."
if (Test-Path $InstallDir) {
    Set-Location $InstallDir
    git pull -q
    Write-Host "✔ Project updated in $InstallDir!" -ForegroundColor Green
} else {
    git clone -q $RepoUrl $InstallDir
    Set-Location $InstallDir
    Write-Host "✔ Project downloaded!" -ForegroundColor Green
}

# ---------------------------------------------------------
# STEP 3: Install UV
# ---------------------------------------------------------
Draw-ProgressBar 3 "Checking 'uv' (Turbo Python Manager)..."
if (!(Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv..." -ForegroundColor Yellow
    irm https://astral.sh/uv/install.ps1 | iex
    # Добавляем uv в PATH текущей сессии, чтобы не перезапускать консоль
    $env:Path += ";$HOME\.cargo\bin" 
    Write-Host "✔ uv installed successfully!" -ForegroundColor Green
} else {
    Write-Host "✔ uv is ready!" -ForegroundColor Green
}

# ---------------------------------------------------------
# STEP 4: Configuration & Token Validation
# ---------------------------------------------------------
Draw-ProgressBar 4 "Bot Configuration..."

# Language Selection
$LangFiles = Get-ChildItem -Filter "language_*.json" | Select-Object -ExpandProperty Name
$SelectedLang = "language_EN.json"

if ($LangFiles.Count -gt 0) {
    Write-Host "`n🌍 Select Language / Выберите язык:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $LangFiles.Count; $i++) {
        $Code = $LangFiles[$i] -replace 'language_(.*)\.json', '$1'
        Write-Host "   $($i + 1). $Code"
    }
    $Choice = Read-Host "👉 Enter number (Enter for EN)"
    if ($Choice -match '^\d+$' -and [int]$Choice -gt 0 -and [int]$Choice -le $LangFiles.Count) {
        $SelectedLang = $LangFiles[[int]$Choice - 1]
    } elseif ($LangFiles -contains "language_EN.json") {
        $SelectedLang = "language_EN.json"
    } else {
        $SelectedLang = $LangFiles[0]
    }
    Write-Host "✅ Language: $SelectedLang" -ForegroundColor Green
}

# Token Loop
$EnvPath = Join-Path $InstallDir ".env"
Write-Host "`n🔑 Connecting Telegram Bot" -ForegroundColor Cyan
while ($true) {
    $Token = Read-Host "👉 Paste your TG_BOT_TOKEN here"
    Write-Host "⏳ Verifying token with Telegram..." -ForegroundColor Yellow
    
    try {
        $Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/getMe" -Method Get -ErrorAction Stop
        if ($Response.ok) {
            $BotName = $Response.result.first_name
            $BotUser = $Response.result.username
            Write-Host "✅ Token is VALID! Connected to: $BotName (@$BotUser)" -ForegroundColor Green
            Set-Content -Path $EnvPath -Value "TG_BOT_TOKEN=$Token`nLANG_FILE=$SelectedLang" -Encoding UTF8
            break
        }
    } catch {
        Write-Host "❌ Invalid token! Telegram rejected it. Please check and try again." -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# STEP 5: Fast Setup & Dependencies
# ---------------------------------------------------------
Draw-ProgressBar 5 "Building environment with 'uv'..."
Write-Host "⚡ Creating virtual environment and installing dependencies in seconds..." -ForegroundColor Yellow
uv venv
uv pip install .

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host " 🎉 INSTALLATION COMPLETE! 🎉" -ForegroundColor Green
Write-Host "====================================================`n" -ForegroundColor Cyan

Write-Host "📌 How to run your bot:" -ForegroundColor Yellow
Write-Host "1. cd $InstallDir" -ForegroundColor Cyan
Write-Host "2. uv run main.py`n" -ForegroundColor Cyan