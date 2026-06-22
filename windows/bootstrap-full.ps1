<#
.SYNOPSIS
    Full Windows bootstrap: WezTerm + Neovim/NvChad with LSP (Python/Lua/Go).

.DESCRIPTION
    Installs WezTerm, Neovim, Git, ripgrep, a C compiler, Go, Node.js and Python
    via winget; copies the cross-platform WezTerm config and the NvChad config
    files from this repo into place; downloads an anime background; bootstraps
    plugins and installs LSP servers + formatters.

    Idempotent: existing config files are backed up (.bak-<timestamp>).

.PARAMETER SkipInstalls
    Skip winget package installation.

.PARAMETER NoBackground
    Skip downloading the anime background image.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\windows\bootstrap-full.ps1
#>
[CmdletBinding()]
param([switch]$SkipInstalls, [switch]$NoBackground)

$ErrorActionPreference = 'Stop'
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ConfigDir  = Join-Path $RepoRoot 'config'

. (Join-Path $PSScriptRoot '_common.ps1')

Write-Host "Full Dev Environment Bootstrap (WezTerm + Neovim)" -ForegroundColor Magenta

# 1. Packages ---------------------------------------------------------------
if (-not $SkipInstalls) {
    Write-Step "Installing packages via winget"
    Assert-Winget
    @(
        'wez.wezterm','Git.Git','Neovim.Neovim','BurntSushi.ripgrep.MSVC',
        'BrechtSanders.WinLibs.POSIX.UCRT','GoLang.Go','OpenJS.NodeJS','Python.Python.3.14'
    ) | ForEach-Object { Install-WingetPkg $_ }
} else { Write-Step "Skipping installs (-SkipInstalls)" }

$nvim = Resolve-Exe 'nvim' @("$env:ProgramFiles\Neovim\bin\nvim.exe")
$wez  = Resolve-Exe 'wezterm' @("$env:ProgramFiles\WezTerm\wezterm.exe")
if (-not $nvim) { throw "nvim.exe not found. Re-run without -SkipInstalls or restart the shell." }
Add-ToolchainsToPath

# 2. WezTerm config ----------------------------------------------------------
Write-Step "Installing WezTerm config"
$wezDst = Join-Path $env:USERPROFILE '.wezterm.lua'
Backup-IfExists $wezDst
Copy-Item (Join-Path $ConfigDir 'wezterm\wezterm.lua') $wezDst -Force
Write-Ok "Wrote $wezDst"

# 3. Background --------------------------------------------------------------
if (-not $NoBackground) { Get-AnimeBackground (Join-Path $ConfigDir 'wezterm\backgrounds\waifu.png') } else { Write-Step "Skipping background (-NoBackground)" }

# 4. NvChad ------------------------------------------------------------------
Write-Step "Installing NvChad"
$nvimCfg = Join-Path $env:LOCALAPPDATA 'nvim'
if (-not (Test-Path (Join-Path $nvimCfg 'init.lua'))) {
    if (Test-Path $nvimCfg) { Rename-Item $nvimCfg "$nvimCfg.bak-$ts" }
    & git clone https://github.com/NvChad/starter $nvimCfg 2>&1 | Out-Null
    Remove-Item -Recurse -Force (Join-Path $nvimCfg '.git') -ErrorAction SilentlyContinue
    Write-Ok "Cloned NvChad starter"
} else { Write-Ok "NvChad already present" }

# 5. Apply our nvim config files --------------------------------------------
Write-Step "Applying Neovim config files"
Copy-NvimConfig -ConfigDir $ConfigDir -NvimCfg $nvimCfg
Write-Ok "Config files applied"

# 6. Plugins + LSP -----------------------------------------------------------
Write-Step "Syncing plugins (lazy.nvim)"
& $nvim --headless "+Lazy! sync" +qa 2>&1 | Out-Null
Write-Ok "Plugins synced"

Write-Step "Installing LSP servers & formatters (Mason)"
& $nvim --headless "+MasonInstall lua-language-server pyright gopls stylua black isort gofumpt goimports" +qa 2>&1 | Out-Null
$masonBin = Join-Path $env:LOCALAPPDATA 'nvim-data\mason\bin'
if (Test-Path $masonBin) { Write-Ok "Mason tools installed ($((Get-ChildItem $masonBin).Count) entries)" }
else { Write-Warn2 "Open nvim and run :Mason to finish tool install." }

# 7. Verify ------------------------------------------------------------------
Write-Step "Verifying"
if ($wez) { & $wez --config-file $wezDst show-keys *> $null; if ($LASTEXITCODE -eq 0) { Write-Ok "WezTerm config parses cleanly" } }
& $nvim --headless "+lua io.write('theme: '..require('chadrc').base46.theme)" +qa 2>&1 |
    ForEach-Object { if ($_ -match 'theme:') { Write-Ok "Neovim/NvChad loads ($_)" } }

Write-Host "`nDone! Restart your terminal. Press F1 in WezTerm for the cheat sheet." -ForegroundColor Magenta
