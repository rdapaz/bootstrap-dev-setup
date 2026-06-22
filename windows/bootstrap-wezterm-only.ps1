<#
.SYNOPSIS
    Windows bootstrap: WezTerm only (no Neovim).

.DESCRIPTION
    Installs WezTerm (and Git, used to fetch nothing here but handy) via winget,
    copies the cross-platform WezTerm config into place, and downloads an anime
    background. Does NOT install or touch Neovim.

    Idempotent: existing ~/.wezterm.lua is backed up (.bak-<timestamp>).

.PARAMETER SkipInstalls
    Skip winget package installation.

.PARAMETER NoBackground
    Skip downloading the anime background image.

.PARAMETER RefreshBackgrounds
    Force-replace the background images even if some already exist, and touch
    ~/.wezterm.lua so a running WezTerm reloads.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\windows\bootstrap-wezterm-only.ps1
#>
[CmdletBinding()]
param([switch]$SkipInstalls, [switch]$NoBackground, [switch]$RefreshBackgrounds)

$ErrorActionPreference = 'Stop'
$RepoRoot  = Split-Path $PSScriptRoot -Parent
$ConfigDir = Join-Path $RepoRoot 'config'

. (Join-Path $PSScriptRoot '_common.ps1')

Write-Host "WezTerm Bootstrap (terminal only)" -ForegroundColor Magenta

# 1. Packages ---------------------------------------------------------------
if (-not $SkipInstalls) {
    Write-Step "Installing WezTerm via winget"
    Assert-Winget
    Install-WingetPkg 'wez.wezterm'
} else { Write-Step "Skipping installs (-SkipInstalls)" }

$wez = Resolve-Exe 'wezterm' @("$env:ProgramFiles\WezTerm\wezterm.exe")

# 2. WezTerm config ----------------------------------------------------------
Write-Step "Installing WezTerm config"
$wezDst = Join-Path $env:USERPROFILE '.wezterm.lua'
Backup-IfExists $wezDst
Copy-Item (Join-Path $ConfigDir 'wezterm\wezterm.lua') $wezDst -Force
Write-Ok "Wrote $wezDst"

# 3. Background --------------------------------------------------------------
if (-not $NoBackground) { Get-AnimeBackground (Join-Path $ConfigDir 'wezterm\backgrounds') -Force:$RefreshBackgrounds } else { Write-Step "Skipping background (-NoBackground)" }

# 4. Verify ------------------------------------------------------------------
Write-Step "Verifying"
if ($wez) {
    & $wez --config-file $wezDst show-keys *> $null
    if ($LASTEXITCODE -eq 0) { Write-Ok "WezTerm config parses cleanly" }
    else { Write-Warn2 "Run: wezterm --config-file `"$wezDst`" show-keys" }
} else { Write-Warn2 "wezterm not found on PATH yet; restart the shell." }

Write-Host "`nDone! Restart your terminal and launch WezTerm. Press F1 for the cheat sheet." -ForegroundColor Magenta
Write-Host "Tip: install the 'Comic Code Ligatures' font for the intended look (falls back otherwise)." -ForegroundColor Gray
