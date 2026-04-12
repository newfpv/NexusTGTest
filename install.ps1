$ErrorActionPreference = "Stop"
$InstallDir = "$env:USERPROFILE\NexusTG"
$RepoUrl = "https://github.com/newfpv/NexusTGTest.git"
$TotalSteps = 6

function Wait-And-Exit {
    Write-Host "`nPress ENTER to close this window..." -ForegroundColor DarkGray
    Read-Host
    exit
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

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
Write-Host "Sit back and relax. I'll do all the heavy lifting! 🚀"

try {
    # ---------------------------------------------------------
    # STEP 1: Git
    # ---------------------------------------------------------
    Draw-ProgressBar 1 "Checking Git..."
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git not found. Installing via winget (please wait)..." -ForegroundColor Yellow
        winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements
        
        Refresh-Path
        
        if (!(Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Error: Failed to install Git. Please install it manually." -ForegroundColor Red
            Wait-And-Exit
        }
        Write-Host "✔ Git installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "✔ Git is ready!" -ForegroundColor Green
    }

    # ---------------------------------------------------------
    # STEP 2: Download Files
    # ---------------------------------------------------------
    Draw-ProgressBar 2 "Downloading project files..."
    if (Test-Path $InstallDir) {
        Set-Location $InstallDir
        git pull -q
        Write-Host "✔ Project files updated in $InstallDir!" -ForegroundColor Green
    } else {
        git clone -q $RepoUrl $InstallDir
        Set-Location $InstallDir
        Write-Host "✔ Project downloaded successfully!" -ForegroundColor Green
    }

    # ---------------------------------------------------------
    # STEP 3: Install UV
    # ---------------------------------------------------------
    Draw-ProgressBar 3 "Checking 'uv' (Turbo Python Manager)..."
    if (!(Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host "Installing uv..." -ForegroundColor Yellow
        irm https://astral.sh/uv/install.ps1 | iex
        
        $env:Path += ";$HOME\.cargo\bin"
        Refresh-Path
        
        Write-Host "✔ uv installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "✔ uv is ready!" -ForegroundColor Green
    }

    # ---------------------------------------------------------
    # STEP 4: Bot Configuration
    # ---------------------------------------------------------
    Draw-ProgressBar 4 "Configuring your bot..."

    $LangFiles = Get-ChildItem -Filter "language_*.json" | Select-Object -ExpandProperty Name
    $SelectedLang = "language_EN.json"

    if ($LangFiles.Count -gt 0) {
        Write-Host "`n🌍 Select Language:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $LangFiles.Count; $i++) {
            $Code = $LangFiles[$i] -replace 'language_(.*)\.json', '$1'
            Write-Host "   $($i + 1). $Code"
        }
        $Choice = Read-Host "👉 Enter number (Press Enter for EN)"
        if ($Choice -match '^\d+$' -and [int]$Choice -gt 0 -and [int]$Choice -le $LangFiles.Count) {
            $SelectedLang = $LangFiles[[int]$Choice - 1]
        } elseif ($LangFiles -contains "language_EN.json") {
            $SelectedLang = "language_EN.json"
        } else {
            $SelectedLang = $LangFiles[0]
        }
        Write-Host "✅ Selected language: $SelectedLang" -ForegroundColor Green
    }

    $EnvPath = Join-Path $InstallDir ".env"
    Write-Host "`n🔑 Connecting your Telegram Bot" -ForegroundColor Cyan
    
    Write-Host "====================================================" -ForegroundColor DarkGray
    Write-Host "🤖 How to get your TG_BOT_TOKEN:" -ForegroundColor Green
    Write-Host "1. Open Telegram and search for @BotFather (with a blue tick)."
    Write-Host "2. Send the command: /newbot"
    Write-Host "3. Choose a name and a username for your bot."
    Write-Host "4. BotFather will give you a token (e.g. 1234567890:ABCdef...)."
    Write-Host "====================================================`n" -ForegroundColor DarkGray

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
            Write-Host "❌ Error! Telegram rejected this token. Please check it and try again." -ForegroundColor Red
        }
    }

    # ---------------------------------------------------------
    # STEP 5: Dependencies
    # ---------------------------------------------------------
    Draw-ProgressBar 5 "Building environment with 'uv'..."
    Write-Host "⚡ Installing libraries (this will just take a few seconds)..." -ForegroundColor Yellow
    uv venv
    uv pip install .

    # ---------------------------------------------------------
    # STEP 6: Desktop Shortcuts
    # ---------------------------------------------------------
    Draw-ProgressBar 6 "Creating Desktop shortcuts..."
    
    # Create start.bat
    $BatPath = Join-Path $InstallDir "start.bat"
    $BatContent = "@echo off`r`ntitle NexusTG Bot`r`ncolor 0b`r`ncd /d `"%~dp0`"`r`necho ========================================`r`necho   NexusTG Bot is Starting...`r`necho   Please do NOT close this window!`r`necho ========================================`r`nuv run main.py`r`npause"
    Set-Content -Path $BatPath -Value $BatContent -Encoding UTF8

    # Create Desktop Shortcut
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $DesktopPath = [System.Environment]::GetFolderPath('Desktop')
        $ShortcutPath = Join-Path $DesktopPath "Start NexusTG.lnk"
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = $BatPath
        $Shortcut.WorkingDirectory = $InstallDir
        $Shortcut.IconLocation = "powershell.exe,0" 
        $Shortcut.Save()
        Write-Host "✔ Shortcut created successfully!" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Failed to create a desktop shortcut, but start.bat is in the bot's folder." -ForegroundColor Yellow
    }

    Write-Host "`n====================================================" -ForegroundColor Cyan
    Write-Host " 🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉" -ForegroundColor Green
    Write-Host "====================================================`n" -ForegroundColor Cyan

    Write-Host "⚠️ IMPORTANT RULE:" -ForegroundColor Red
    Write-Host "The bot only runs while the black console window is open." -ForegroundColor Yellow
    Write-Host "If you close it (X), the bot will immediately shut down!`n" -ForegroundColor Yellow

    Write-Host "📌 HOW TO RUN THE BOT NOW:" -ForegroundColor Cyan
    Write-Host "1. Find the shortcut on your Desktop: " -NoNewline; Write-Host "Start NexusTG" -ForegroundColor Green
    Write-Host "2. Double-click it to start." -ForegroundColor Cyan
    Write-Host "3. Open Telegram and send /start to your bot.`n" -ForegroundColor Cyan

    Wait-And-Exit

} catch {
    Write-Host "`n❌ An unexpected error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Wait-And-Exit
}