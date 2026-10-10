<#
.SYNOPSIS
    One-click setup & installer for MiniTmux on Windows.
.DESCRIPTION
    Configures User PATH, installs Windows Terminal integration,
    and sets up PowerShell module support.
#>

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$SkipTerminalProfile
)

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BinDir = Join-Path $RootDir 'bin'
$UsrBinDir = Join-Path $RootDir 'usr\bin'

Write-Host "================================================================" -ForegroundColor DarkCyan
Write-Host "                   MiniTmux Installer & Setup                   " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor DarkCyan

if ($Uninstall) {
    Write-Host "Uninstalling MiniTmux from current user environment..." -ForegroundColor Yellow

    # Remove from User PATH
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = ($userPath -split ';') | Where-Object {
        ($_ -ne $BinDir) -and ($_ -ne $UsrBinDir) -and (-not [string]::IsNullOrWhiteSpace($_))
    }
    $newPath = $entries -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "  PASS  Removed MiniTmux from User PATH" -ForegroundColor Green

    # Remove Windows Terminal fragment
    $fragmentFile = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\minitmux\minitmux.json'
    if (Test-Path $fragmentFile) {
        Remove-Item -Path (Split-Path -Parent $fragmentFile) -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  PASS  Removed Windows Terminal profile fragment" -ForegroundColor Green
    }

    Write-Host "`nMiniTmux environment uninstalled successfully." -ForegroundColor Green
    return
}

# --- Install Mode ---

Write-Host "Installing MiniTmux into user environment..." -ForegroundColor Cyan

# 1. Add to User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$entries = ($userPath -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$changed = $false

if ($entries -notcontains $BinDir) {
    $entries = @($BinDir) + $entries
    $changed = $true
}
if ($entries -notcontains $UsrBinDir) {
    $entries = $entries + @($UsrBinDir)
    $changed = $true
}

if ($changed) {
    $newPath = $entries -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:PATH = "$BinDir;$UsrBinDir;$env:PATH"
    Write-Host "  PASS  Added to User PATH: $BinDir" -ForegroundColor Green
} else {
    Write-Host "  PASS  User PATH already contains MiniTmux binaries" -ForegroundColor Green
}

# 2. Windows Terminal Profile
if (-not $SkipTerminalProfile) {
    $wtScript = Join-Path $RootDir 'scripts\Install-WindowsTerminalProfile.ps1'
    if (Test-Path $wtScript) {
        & $wtScript
    }
}

Write-Host "`n================================================================" -ForegroundColor DarkCyan
Write-Host "MiniTmux installation complete!" -ForegroundColor Green
Write-Host "Commands available in new terminal windows:" -ForegroundColor Gray
Write-Host "  - mtmux               (Interactive smart manager)" -ForegroundColor White
Write-Host "  - tmux                (Standard tmux CLI drop-in wrapper)" -ForegroundColor White
Write-Host "  - mtmux doctor        (System health check)" -ForegroundColor White
Write-Host "================================================================`n" -ForegroundColor DarkCyan
