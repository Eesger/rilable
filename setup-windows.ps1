# Rilable Windows Setup Script
# Run from PowerShell (Admin recommended):
#   powershell -ExecutionPolicy Bypass -File setup-windows.ps1

$ErrorActionPreference = "Stop"
$InstallDir = "C:\BTN\AI\Lovable-clone"

function Write-Step { param($msg) Write-Host "" ; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "    WARN: $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "    ERROR: $msg" -ForegroundColor Red ; exit 1 }

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

Write-Step "Checking prerequisites"

try {
    $nodeVer = (node -v 2>&1).ToString().TrimStart('v')
    $nodeMajor = [int]($nodeVer.Split('.')[0])
    if ($nodeMajor -lt 18) { Write-Fail "Node.js 18+ required (found $nodeVer). Install from https://nodejs.org" }
    Write-Ok "Node.js $nodeVer"
} catch {
    Write-Fail "Node.js not found. Install from https://nodejs.org then rerun this script."
}

try {
    $gitVer = (git --version 2>&1).ToString()
    Write-Ok $gitVer
} catch {
    Write-Fail "Git not found. Install from https://git-scm.com then rerun this script."
}

# ---------------------------------------------------------------------------
# Clone / update repo
# ---------------------------------------------------------------------------

Write-Step "Setting up project in $InstallDir"

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$repoDir    = Join-Path $InstallDir "rilable"
$backendDir = Join-Path $repoDir    "backend"

if (Test-Path (Join-Path $repoDir ".git")) {
    Write-Ok "Repo already exists - pulling latest"
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    git -C $repoDir pull --ff-only origin main 2>&1 | Out-Null
    $ErrorActionPreference = $prevPref
} else {
    Write-Ok "Cloning repo..."
    git clone https://github.com/eesger/rilable.git $repoDir
}

# ---------------------------------------------------------------------------
# Backend dependencies
# ---------------------------------------------------------------------------

Write-Step "Installing backend Node dependencies"
Set-Location $backendDir
npm install
Write-Ok "npm install complete"

# ---------------------------------------------------------------------------
# Convex project setup
# ---------------------------------------------------------------------------

Write-Step "Setting up Convex backend"
Set-Location $backendDir
$envFile = Join-Path $backendDir ".env.local"
if (Test-Path $envFile) {
    Write-Ok "backend\.env.local already exists - skipping Convex login"
} else {
    Write-Host ""
    Write-Host "  A browser window will open so you can log in with GitHub or Google."
    Write-Host "  Convex is free. After login it creates a project and saves your"
    Write-Host "  CONVEX_URL to backend\.env.local."
    Write-Host ""
    Write-Host "  Press Enter to continue..."
    Read-Host | Out-Null
    npx convex dev --once --configure new
}

# envFile already set above
if (-not (Test-Path $envFile)) {
    Write-Fail "backend\.env.local was not created. Did the Convex login succeed?"
}

$convexUrl = ""
foreach ($line in Get-Content $envFile) {
    if ($line -match "^CONVEX_URL=(.+)$") {
        $convexUrl = $Matches[1].Trim()
    }
}
if (-not $convexUrl) { Write-Fail "Could not read CONVEX_URL from backend\.env.local" }
Write-Ok "CONVEX_URL = $convexUrl"

# ---------------------------------------------------------------------------
# API keys
# ---------------------------------------------------------------------------

Write-Step "API keys"
Write-Host ""
Write-Host "  You need:"
Write-Host "    OPENROUTER_API_KEY  - required (routes AI requests to Claude)"
Write-Host "    DAYTONA_API_KEY     - required for web builds (free account)"
Write-Host ""
Write-Host "  Get them at:"
Write-Host "    OpenRouter -> https://openrouter.ai -> Keys"
Write-Host "    Daytona   -> https://app.daytona.io -> Settings -> API Keys"
Write-Host ""
Write-Host "  Optional:"
Write-Host "    OPENAI_API_KEY          - voice input via Whisper"
Write-Host "    VERCEL_AI_GATEWAY_KEY   - AI features inside generated apps"
Write-Host ""

Set-Location $backendDir

$orKey = Read-Host "Paste your OPENROUTER_API_KEY (required)"
if ($orKey) {
    npx convex env set OPENROUTER_API_KEY $orKey
    Write-Ok "OPENROUTER_API_KEY set"
} else {
    Write-Warn "Skipped - app will not generate code without this key"
}

$daytonaKey = Read-Host "Paste your DAYTONA_API_KEY (required for web previews, leave blank to skip)"
if ($daytonaKey) {
    npx convex env set DAYTONA_API_KEY $daytonaKey
    Write-Ok "DAYTONA_API_KEY set"
} else {
    Write-Warn "Skipped - web previews will not work without this key"
}

$openaiKey = Read-Host "Paste your OPENAI_API_KEY (optional voice input, leave blank to skip)"
if ($openaiKey) {
    npx convex env set OPENAI_API_KEY $openaiKey
    Write-Ok "OPENAI_API_KEY set"
}

$vercelKey = Read-Host "Paste your VERCEL_AI_GATEWAY_KEY (optional, leave blank to skip)"
if ($vercelKey) {
    npx convex env set VERCEL_AI_GATEWAY_KEY $vercelKey
    Write-Ok "VERCEL_AI_GATEWAY_KEY set"
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Rilable backend is ready!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Convex URL: $convexUrl"
Write-Host ""
Write-Host "  The backend runs in the cloud - no local server needed."
Write-Host "  Generated apps are served via Daytona sandbox URLs."
Write-Host ""
Write-Host "  Smoke test (paste into a new PowerShell window):"
Write-Host ""
Write-Host "    cd $backendDir"
Write-Host '    npx convex run projects:create "{\"prompt\":\"a hello world page\"}"'
Write-Host ""
Write-Host "  It returns a project ID. After ~2 min check the result:"
Write-Host ""
Write-Host '    npx convex run projects:get "{\"id\":\"<paste-id-here>\"}"'
Write-Host ""
Write-Host "  Open the previewUrl in your browser to see the generated app."
Write-Host ""
Write-Host "  NOTE: The iOS app (SwiftUI) requires macOS + Xcode 16."
Write-Host "        If you have a Mac, the ios/ folder is ready for it."
Write-Host ""
