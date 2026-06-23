<#
.SYNOPSIS
  Add the WezTerm LLM integration to an existing bootstrap-dev-setup install.

.DESCRIPTION
  Idempotent. Re-runnable. Pairs with uninstall.ps1.

  - Creates a dedicated Python venv at $HOME\.venv\wezterm-llm
  - Installs anthropic / openai / google-generativeai into it
  - Copies llm-client.py to $HOME\.local\bin\llm-client.py
  - Copies llm-integration.lua to $HOME\.config\wezterm\llm-integration.lua
    (with the venv python and script paths baked in)
  - Adds a single MARKED block to $HOME\.wezterm.lua that loads the sidecar
#>

[CmdletBinding()]
param(
  [string]$WezTermConfig = (Join-Path $HOME ".wezterm.lua"),
  [string]$VenvDir       = (Join-Path $HOME ".venv\wezterm-llm"),
  [string]$BinDir        = (Join-Path $HOME ".local\bin"),
  [string]$WezConfigDir  = (Join-Path $HOME ".config\wezterm")
)

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

$BeginMarker = "-- >>> bootstrap-dev-setup: llm-integration >>>"
$EndMarker   = "-- <<< bootstrap-dev-setup: llm-integration <<<"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }

# --- 1. Locate Python ---------------------------------------------------------
Write-Step "Locating Python"
$python = $null
foreach ($candidate in @('python', 'python3', 'py')) {
  $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
  if ($cmd) { $python = $cmd; break }
}
if (-not $python) { throw "Python not found in PATH. Install Python 3.9+ first." }
Write-Info "Using $($python.Source)"

# --- 2. Create venv (idempotent) ---------------------------------------------
$venvPy = Join-Path $VenvDir "Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
  Write-Step "Creating venv at $VenvDir"
  & $python.Source -m venv $VenvDir
} else {
  Write-Step "Venv already exists at $VenvDir"
}

Write-Step "Installing/updating Python packages"
& $venvPy -m pip install --quiet --upgrade pip
& $venvPy -m pip install --quiet --upgrade anthropic openai google-generativeai
if ($LASTEXITCODE -ne 0) { throw "pip install failed" }

# --- 3. Deploy llm-client.py --------------------------------------------------
Write-Step "Deploying llm-client.py -> $BinDir"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$clientDst = Join-Path $BinDir "llm-client.py"
Copy-Item -Force (Join-Path $Here "llm-client.py") $clientDst
Write-Info $clientDst

# --- 4. Deploy llm-integration.lua sidecar (with paths baked in) -------------
Write-Step "Deploying llm-integration.lua -> $WezConfigDir"
New-Item -ItemType Directory -Force -Path $WezConfigDir | Out-Null
$luaSrc = Get-Content -Raw (Join-Path $Here "llm-integration.lua")
# Lua strings: forward slashes are fine and portable on Windows
$pyForLua = ($venvPy -replace '\\', '/')
$scriptForLua = ($clientDst -replace '\\', '/')
$luaSrc = $luaSrc `
  -replace "local PYTHON = getenv_or\('WEZTERM_LLM_PYTHON', 'python'\)", "local PYTHON = getenv_or('WEZTERM_LLM_PYTHON', '$pyForLua')" `
  -replace "local SCRIPT = getenv_or\('WEZTERM_LLM_SCRIPT', ''\)",         "local SCRIPT = getenv_or('WEZTERM_LLM_SCRIPT', '$scriptForLua')"
$luaDst = Join-Path $WezConfigDir "llm-integration.lua"
Set-Content -Path $luaDst -Value $luaSrc -Encoding UTF8
Write-Info $luaDst

# --- 5. Patch ~/.wezterm.lua (marked block, idempotent) ----------------------
if (-not (Test-Path $WezTermConfig)) {
  throw "WezTerm config not found at $WezTermConfig. Run the main bootstrap first."
}

Write-Step "Patching $WezTermConfig"
$current = Get-Content -Raw $WezTermConfig
if ($current -match [regex]::Escape($BeginMarker)) {
  Write-Info "Marker already present; skipping (re-run uninstall.ps1 first to refresh)."
} else {
  $wezConfigDirForLua = ($WezConfigDir -replace '\\', '/')
  $block = @"

$BeginMarker
do
  local ok, llm = pcall(function()
    package.path = package.path .. ';$wezConfigDirForLua/?.lua'
    return require('llm-integration')
  end)
  if ok and llm and llm.apply then llm.apply(config) end
end
$EndMarker
"@
  # Insert before the final `return config` if present, else append.
  if ($current -match '(?ms)^(.*?)(\r?\n\s*return\s+config\s*\r?\n?\s*)$') {
    $patched = $matches[1] + $block + $matches[2]
  } else {
    $patched = $current.TrimEnd() + "`r`n" + $block + "`r`n"
  }
  $backup = "$WezTermConfig.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
  Copy-Item $WezTermConfig $backup
  Write-Info "Backed up to $backup"
  Set-Content -Path $WezTermConfig -Value $patched -Encoding UTF8
  Write-Info "Added marked block."
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Set ONE of these env vars (User scope shown):" -ForegroundColor Yellow
Write-Host '  [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","sk-ant-...","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("OPENAI_API_KEY","sk-...","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("GOOGLE_API_KEY","AIza...","User")'
Write-Host "Then restart WezTerm and press LEADER + i (split with LEADER + Shift + I)."
