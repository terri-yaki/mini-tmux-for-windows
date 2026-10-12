# ==============================================================================
# MiniTmux Web Bootstrap & Installer for Windows
# Usage:
#   irm https://raw.githubusercontent.com/terri-yaki/mini-tmux-for-windows/main/scripts/install.ps1 | iex
# ==============================================================================

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\MiniTmux"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================================" -ForegroundColor DarkCyan
Write-Host "             MiniTmux Windows Automated Installer              " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor DarkCyan

$repoUrl = "https://github.com/terri-yaki/mini-tmux-for-windows"

# Check if git is available to clone, or download release zip
if (Get-Command git -ErrorAction SilentlyContinue) {
    if (Test-Path "$InstallDir\.git") {
        Write-Host "Updating existing MiniTmux installation in: $InstallDir" -ForegroundColor Cyan
        git -C "$InstallDir" pull --ff-only
    } else {
        Write-Host "Cloning MiniTmux repository to: $InstallDir" -ForegroundColor Cyan
        git clone --depth 1 "$repoUrl.git" "$InstallDir"
    }
} else {
    Write-Host "Git not detected; downloading latest archive from GitHub..." -ForegroundColor Cyan
    $zipUrl = "$repoUrl/archive/refs/heads/main.zip"
    $zipPath = Join-Path $env:TEMP "mini-tmux-main.zip"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
    Write-Host "Extracting MiniTmux to $InstallDir..." -ForegroundColor Cyan
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    $tempExtract = Join-Path $env:TEMP "mini-tmux-extract-$(Get-Random)"
    Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force
    $sourceDir = Join-Path $tempExtract "mini-tmux-for-windows-main"
    Move-Item -Path $sourceDir -Destination $InstallDir -Force
    Remove-Item $zipPath, $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
}

# Run the repository installer
$installerScript = Join-Path $InstallDir 'scripts\Install-MiniTmux.ps1'
if (Test-Path $installerScript) {
    & $installerScript
} else {
    Write-Host "ERROR: installer script not found in $InstallDir" -ForegroundColor Red
    exit 1
}
