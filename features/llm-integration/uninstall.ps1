<#
.SYNOPSIS
  Remove the WezTerm LLM integration. Idempotent.
#>

[CmdletBinding()]
param(
  [string]$WezTermConfig = (Join-Path $HOME ".wezterm.lua"),
  [string]$VenvDir       = (Join-Path $HOME ".venv\wezterm-llm"),
  [string]$BinDir        = (Join-Path $HOME ".local\bin"),
  [string]$WezConfigDir  = (Join-Path $HOME ".config\wezterm"),
  [switch]$KeepVenv
)

$ErrorActionPreference = "Stop"
$BeginMarker = "-- >>> bootstrap-dev-setup: llm-integration >>>"
$EndMarker   = "-- <<< bootstrap-dev-setup: llm-integration <<<"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }

# --- 1. Strip marked block from ~/.wezterm.lua -------------------------------
if (Test-Path $WezTermConfig) {
  Write-Step "Stripping marked block from $WezTermConfig"
  $current = Get-Content -Raw $WezTermConfig
  $pattern = "(?ms)\r?\n?" + [regex]::Escape($BeginMarker) + ".*?" + [regex]::Escape($EndMarker) + "\r?\n?"
  if ($current -match $pattern) {
    $backup = "$WezTermConfig.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $WezTermConfig $backup
    Write-Info "Backed up to $backup"
    $cleaned = [regex]::Replace($current, $pattern, "`r`n")
    Set-Content -Path $WezTermConfig -Value $cleaned -Encoding UTF8
    Write-Info "Removed."
  } else {
    Write-Info "Marker not found; nothing to remove."
  }
} else {
  Write-Info "$WezTermConfig not found; skipping."
}

# --- 2. Remove deployed files ------------------------------------------------
$luaDst    = Join-Path $WezConfigDir "llm-integration.lua"
$clientDst = Join-Path $BinDir       "llm-client.py"

foreach ($p in @($luaDst, $clientDst)) {
  if (Test-Path $p) {
    Write-Step "Removing $p"
    Remove-Item -Force $p
  } else {
    Write-Info "Already absent: $p"
  }
}

# --- 3. Remove venv ----------------------------------------------------------
if ($KeepVenv) {
  Write-Info "Keeping venv at $VenvDir (-KeepVenv)."
} elseif (Test-Path $VenvDir) {
  Write-Step "Removing venv $VenvDir"
  Remove-Item -Recurse -Force $VenvDir
} else {
  Write-Info "Venv already absent: $VenvDir"
}

Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
Write-Host "API keys (ANTHROPIC_API_KEY / OPENAI_API_KEY / GOOGLE_API_KEY) were NOT touched."
