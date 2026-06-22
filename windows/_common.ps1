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

function Get-WezTermBackgroundDir {
    $dir = Join-Path $env:USERPROFILE '.config\wezterm\backgrounds'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}

# Robust image lister. NOTE: Get-ChildItem -Include needs -Recurse or a \*
# path to work, so we filter by extension explicitly instead.
function Get-ImageFiles {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path)) { return @() }
    return @(Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.png', '.jpg', '.jpeg', '.webp' })
}

# Touch ~/.wezterm.lua so a RUNNING WezTerm auto-reloads and re-rolls the image.
function Update-WezTermConfigMtime {
    $cfg = Join-Path $env:USERPROFILE '.wezterm.lua'
    if (Test-Path $cfg) {
        (Get-Item $cfg).LastWriteTime = Get-Date
        Write-Ok "Touched $cfg (a running WezTerm will reload)"
    }
}

# Download N fresh random SFW anime images into the backgrounds folder.
# nekos.best's Cloudflare allows curl's default UA but 403s spoofed browser UAs
# AND the default PowerShell UA -- so use curl.exe (default UA), and if it's
# missing, fall back to Invoke-WebRequest with a curl-style UA.
function Get-RandomBackgrounds {
    param([int]$Count = 7)
    $dir = Get-WezTermBackgroundDir
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    $useCurl = Test-Path $curl
    $ok = 0
    for ($i = 1; $i -le $Count; $i++) {
        try {
            if ($useCurl) {
                $json = & $curl -fsSL --max-time 20 'https://nekos.best/api/v2/neko'
                $url = ($json | ConvertFrom-Json).results[0].url
                & $curl -fsSL --max-time 60 -o (Join-Path $dir "waifu-$i.png") $url
                if ($LASTEXITCODE -ne 0) { throw "curl exit $LASTEXITCODE" }
            } else {
                $h = @{ 'User-Agent' = 'curl/8.0' }
                $api = Invoke-RestMethod -Uri 'https://nekos.best/api/v2/neko' -TimeoutSec 20 -Headers $h
                Invoke-WebRequest -Uri $api.results[0].url -OutFile (Join-Path $dir "waifu-$i.png") -TimeoutSec 60 -Headers $h
            }
            $ok++
        } catch { Write-Warn2 "image $i failed ($($_.Exception.Message))" }
    }
    Write-Ok "Downloaded $ok image(s) -> $dir"
}

function Get-AnimeBackground {
    param([string]$SourceDir, [switch]$Force)   # repo folder of pinned images (optional)
    Write-Step "Installing WezTerm background images"
    $dir = Get-WezTermBackgroundDir
    $existing = Get-ImageFiles $dir
    if ($existing.Count -gt 0) {
        if (-not $Force) { Write-Ok "$($existing.Count) background(s) already present"; return }
        $existing | Remove-Item -Force
        Write-Warn2 "Removed $($existing.Count) existing background(s) (refresh)"
    }
    # Prefer the pinned images bundled in the repo for a consistent look
    if ($SourceDir -and (Test-Path $SourceDir)) {
        $imgs = Get-ImageFiles $SourceDir
        if ($imgs.Count -gt 0) {
            $imgs | ForEach-Object { Copy-Item $_.FullName (Join-Path $dir $_.Name) -Force }
            Write-Ok "Installed $($imgs.Count) pinned background(s) -> $dir"
            Update-WezTermConfigMtime
            return
        }
    }
    # Fallback: download a few random SFW anime images
    Get-RandomBackgrounds -Count 7
    Update-WezTermConfigMtime
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
