# Shared helpers for the Windows bootstrap scripts.
# Dot-sourced by bootstrap-full.ps1 and bootstrap-wezterm-only.ps1

if (-not $ts) { $ts = Get-Date -Format 'yyyyMMdd-HHmmss' }

function Write-Step  { param($m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "    [!]  $m" -ForegroundColor Yellow }

function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from the Microsoft Store first."
    }
}

function Backup-IfExists {
    param([string]$Path)
    if (Test-Path $Path) {
        $bak = "$Path.bak-$ts"
        Copy-Item $Path $bak -Force
        Write-Warn2 "Backed up $Path -> $bak"
    }
}

function Install-WingetPkg {
    param([string]$Id)
    $installed = winget list --id $Id -e 2>$null | Select-String $Id
    if ($installed) { Write-Ok "$Id already installed"; return }
    Write-Host "    Installing $Id ..." -ForegroundColor DarkGray
    winget install --id $Id -e --accept-source-agreements --accept-package-agreements --silent | Out-Null
    Write-Ok "$Id installed"
}

function Resolve-Exe {
    param([string]$Name, [string[]]$Candidates)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($c in $Candidates) { if (Test-Path $c) { return $c } }
    return $null
}

function Add-ToolchainsToPath {
    $extra = @(
        "$env:ProgramFiles\Go\bin",
        "$env:ProgramFiles\nodejs",
        (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter '*WinLibs*' -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'mingw64\bin' } | Select-Object -First 1)
    ) | Where-Object { $_ -and (Test-Path $_) }
    if ($extra) { $env:PATH = ($extra -join ';') + ';' + $env:PATH }
}

function Get-AnimeBackground {
    param([string]$SourceImage)   # pinned image shipped with the repo (optional)
    Write-Step "Installing WezTerm background image"
    $dir = Join-Path $env:USERPROFILE '.config\wezterm\backgrounds'
    $img = Join-Path $dir 'waifu.png'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (Test-Path $img) { Write-Ok "Background already present"; return }
    # Prefer the pinned image bundled in the repo for a consistent look
    if ($SourceImage -and (Test-Path $SourceImage)) {
        Copy-Item $SourceImage $img -Force
        Write-Ok "Installed pinned background -> $img"
        return
    }
    # Fallback: download a random SFW anime image
    try {
        $api = Invoke-RestMethod -Uri 'https://nekos.best/api/v2/neko' -TimeoutSec 20
        Invoke-WebRequest -Uri $api.results[0].url -OutFile $img -TimeoutSec 60
        Write-Ok "Downloaded background -> $img"
    } catch {
        Write-Warn2 "Could not obtain background ($($_.Exception.Message)). WezTerm runs without one."
    }
}

function Copy-NvimConfig {
    param([string]$ConfigDir, [string]$NvimCfg)
    $src = Join-Path $ConfigDir 'nvim\lua'
    $cfgDir = Join-Path $NvimCfg 'lua\configs'
    $plgDir = Join-Path $NvimCfg 'lua\plugins'
    New-Item -ItemType Directory -Force -Path $cfgDir, $plgDir | Out-Null
    $map = @{
        (Join-Path $src 'chadrc.lua')           = (Join-Path $NvimCfg 'lua\chadrc.lua')
        (Join-Path $src 'configs\lspconfig.lua') = (Join-Path $cfgDir 'lspconfig.lua')
        (Join-Path $src 'configs\conform.lua')   = (Join-Path $cfgDir 'conform.lua')
        (Join-Path $src 'plugins\init.lua')      = (Join-Path $plgDir 'init.lua')
    }
    foreach ($e in $map.GetEnumerator()) {
        Backup-IfExists $e.Value
        Copy-Item $e.Key $e.Value -Force
    }
}
