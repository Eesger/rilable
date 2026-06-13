# Rilable Windows Setup Script
# Run this in PowerShell as Administrator
# Usage: .\setup-windows.ps1

$ErrorActionPreference = "Stop"
$InstallDir = "C:\BTN\AI\Lovable-clone"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    ERROR: $msg" -ForegroundColor Red; exit 1 }
function Ask($prompt)     { Read-Host "`n$prompt" }

# ─── Prerequisites ────────────────────────────────────────────────────────────

Write-Step "Checking prerequisites"

# Node.js 18+
try {
    $nodeVer = (node -v).TrimStart('v')
    $nodeMajor = [int]($nodeVer.Split('.')[0])
    if ($nodeMajor -lt 18) { Write-Fail "Node.js 18+ required (found $nodeVer). Install from https://nodejs.org" }
    Write-Ok "Node.js $nodeVer"
} catch {
    Write-Fail "Node.js not found. Install from https://nodejs.org and rerun this script."
}

# Git
try {
    $gitVer = git --version
    Write-Ok $gitVer
} catch {
    Write-Fail "Git not found. Install from https://git-scm.com and rerun this script."
}

# ─── Clone / update repo ──────────────────────────────────────────────────────

Write-Step "Setting up project in $InstallDir"

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$repoDir = Join-Path $InstallDir "rilable"

if (Test-Path (Join-Path $repoDir ".git")) {
    Write-Ok "Repo already exists — pulling latest"
    git -C $repoDir pull --ff-only origin main 2>&1 | Out-Null
} else {
    Write-Ok "Cloning repo"
    git clone https://github.com/eesger/rilable.git $repoDir
}

$backendDir = Join-Path $repoDir "backend"

# ─── Backend dependencies ─────────────────────────────────────────────────────

Write-Step "Installing backend dependencies"
Push-Location $backendDir
npm install
Pop-Location
Write-Ok "npm install complete"

# ─── Convex project setup ─────────────────────────────────────────────────────

Write-Step "Setting up Convex backend"
Write-Host @"

  This will open a browser window for you to log in with GitHub or Google
  (free Convex account). After login it creates a project and writes your
  CONVEX_URL to backend\.env.local.

  Press Enter to continue...
"@
Read-Host | Out-Null

Push-Location $backendDir
npx convex dev --once --configure new
Pop-Location

# Read the generated CONVEX_URL
$envFile = Join-Path $backendDir ".env.local"
if (-not (Test-Path $envFile)) {
    Write-Fail "backend\.env.local was not created. Did the Convex login succeed?"
}
$convexUrl = (Select-String -Path $envFile -Pattern "CONVEX_URL=(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
if (-not $convexUrl) { Write-Fail "Could not read CONVEX_URL from backend\.env.local" }
Write-Ok "CONVEX_URL = $convexUrl"

# ─── API keys ─────────────────────────────────────────────────────────────────

Write-Step "API keys"
Write-Host @"

  You need at minimum:
    - ANTHROPIC_API_KEY  (required — Claude writes your apps)
    - DAYTONA_API_KEY    (required for web builds)

  Optional:
    - OPENAI_API_KEY     (voice input via Whisper)
    - VERCEL_AI_GATEWAY_KEY  (AI features inside generated apps)

  Get them at:
    Anthropic  -> https://console.anthropic.com  -> Settings -> API Keys
    Daytona    -> https://app.daytona.io         -> Settings -> API Keys
    OpenAI     -> https://platform.openai.com    -> API keys
    Vercel     -> https://vercel.com             -> AI Gateway -> API keys
"@

Push-Location $backendDir

$anthropicKey = Ask "Paste your ANTHROPIC_API_KEY (required)"
if ($anthropicKey) {
    npx convex env set ANTHROPIC_API_KEY $anthropicKey
    Write-Ok "ANTHROPIC_API_KEY set"
} else {
    Write-Warn "Skipped ANTHROPIC_API_KEY — app will not work without it"
}

$daytonaKey = Ask "Paste your DAYTONA_API_KEY (required for web builds, leave blank to skip)"
if ($daytonaKey) {
    npx convex env set DAYTONA_API_KEY $daytonaKey
    Write-Ok "DAYTONA_API_KEY set"
} else {
    Write-Warn "Skipped DAYTONA_API_KEY — web builds will not work"
}

$openaiKey = Ask "Paste your OPENAI_API_KEY (optional voice input, leave blank to skip)"
if ($openaiKey) {
    npx convex env set OPENAI_API_KEY $openaiKey
    Write-Ok "OPENAI_API_KEY set"
}

$vercelKey = Ask "Paste your VERCEL_AI_GATEWAY_KEY (optional, leave blank to skip)"
if ($vercelKey) {
    npx convex env set VERCEL_AI_GATEWAY_KEY $vercelKey
    Write-Ok "VERCEL_AI_GATEWAY_KEY set"
}

Pop-Location

# ─── Done ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Rilable backend is ready!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host @"

  Your Convex deployment: $convexUrl

  The backend is now live in the cloud — no need to keep a local server
  running. New apps you build are served via Daytona sandboxes.

  ----------------------------------------------------------------
  NOTE: The iOS app (SwiftUI) requires macOS + Xcode 16.
        If you have a Mac, open $repoDir\ios on that Mac
        and follow the iOS steps in CLAUDE.md.
  ----------------------------------------------------------------

  To run a smoke-test web build right now, open a new PowerShell
  window, cd to $backendDir, then:

    npx convex run projects:create '{\"prompt\":\"a hello world page with one big button\"}'

  It returns a project ID. After ~2 min check the result:

    npx convex run projects:get '{\"id\":\"<ID>\"}'

  Look for a previewUrl in the output — open it in your browser.

"@
