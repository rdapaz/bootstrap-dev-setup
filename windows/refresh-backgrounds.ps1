<#
.SYNOPSIS
    Download a fresh set of random WezTerm background images.

.DESCRIPTION
    Replaces the images in ~/.config/wezterm/backgrounds with `Count` freshly
    downloaded random SFW anime images from nekos.best, then touches
    ~/.wezterm.lua so a running WezTerm reloads and re-rolls its background.

.PARAMETER Count
    How many images to fetch (default 7).

.PARAMETER KeepExisting
    Keep the current images and just add `Count` more (default: replace them).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\windows\refresh-backgrounds.ps1
    powershell -ExecutionPolicy Bypass -File .\windows\refresh-backgrounds.ps1 -Count 10
#>
[CmdletBinding()]
param([int]$Count = 7, [switch]$KeepExisting)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

Write-Host "Refresh WezTerm backgrounds" -ForegroundColor Magenta

$dir = Get-WezTermBackgroundDir
if (-not $KeepExisting) {
    $old = Get-ImageFiles $dir
    if ($old.Count -gt 0) { $old | Remove-Item -Force; Write-Warn2 "Removed $($old.Count) existing image(s)" }
}

Write-Step "Downloading $Count fresh image(s)"
Get-RandomBackgrounds -Count $Count
Update-WezTermConfigMtime

Write-Host "`nDone. A running WezTerm will reload; or press Ctrl+a b to reshuffle now." -ForegroundColor Magenta
