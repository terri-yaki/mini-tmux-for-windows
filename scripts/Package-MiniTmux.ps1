<#
.SYNOPSIS
    Builds a clean, production-ready portable ZIP distribution of MiniTmux.
.DESCRIPTION
    Validates runtime binaries, terminfo database, configuration, themes, and
    creates a distributable archive in dist/ with SHA256 checksums.
#>

[CmdletBinding()]
param(
    [string]$Version = "3.7b",
    [string]$OutputDir
)

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DistDir = if ($OutputDir) { $OutputDir } else { Join-Path $RootDir "dist" }

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "              MiniTmux Release Packaging Utility               " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Packaging source: $RootDir" -ForegroundColor Gray
Write-Host "Target version  : $Version" -ForegroundColor Gray

# Ensure output directory
if (-not (Test-Path $DistDir)) {
    [void](New-Item -ItemType Directory -Path $DistDir -Force)
}

# Verify critical components
Write-Host "`n[1/4] Verifying package payload..." -ForegroundColor Yellow
$requiredFiles = @(
    'usr\bin\tmux.exe',
    'usr\bin\bash.exe',
    'usr\bin\winpty.exe',
    'usr\bin\winpaste.exe',
    'usr\bin\msys-2.0.dll',
    'bin\mtmux.cmd',
    'bin\mtmux.ps1',
    'bin\tmux.cmd',
    'bin\tmux.ps1',
    'etc\tmux.conf',
    'etc\themes\catppuccin-mocha.conf',
    'README.md',
    'LICENSE'
)

foreach ($f in $requiredFiles) {
    $fp = Join-Path $RootDir $f
    if (-not (Test-Path $fp)) {
        Write-Error "Missing critical component: $f"
        exit 1
    }
}
Write-Host "  PASS  All critical files verified." -ForegroundColor Green

# Clean ephemeral files before packaging
Write-Host "`n[2/4] Cleaning temporary runtime artifacts..." -ForegroundColor Yellow
$tmpDir = Join-Path $RootDir "tmp"
if (Test-Path $tmpDir) {
    Get-ChildItem -Path $tmpDir -Exclude ".gitkeep" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  PASS  Cleaned tmp/ directory." -ForegroundColor Green
}

# Zip packaging
$zipName = "mini-tmux-for-windows-v$Version-x64.zip"
$zipPath = Join-Path $DistDir $zipName

if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

Write-Host "`n[3/4] Compressing distribution archive..." -ForegroundColor Yellow
Write-Host "  Output -> $zipPath" -ForegroundColor Gray

# Items to include in the portable package
$itemsToCompress = @(
    (Join-Path $RootDir 'bin'),
    (Join-Path $RootDir 'etc'),
    (Join-Path $RootDir 'scripts'),
    (Join-Path $RootDir 'src'),
    (Join-Path $RootDir 'tests'),
    (Join-Path $RootDir 'tmp'),
    (Join-Path $RootDir 'usr'),
    (Join-Path $RootDir 'README.md'),
    (Join-Path $RootDir 'LICENSE'),
    (Join-Path $RootDir 'mtmux.cmd'),
    (Join-Path $RootDir 'mtmux'),
    (Join-Path $RootDir 'tmux.cmd'),
    (Join-Path $RootDir '.gitignore')
)

$existingItems = $itemsToCompress | Where-Object { Test-Path $_ }

# Use .NET System.IO.Compression for fast reliable packaging
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Build staging folder
$stageDir = Join-Path $DistDir "stage-mini-tmux"
if (Test-Path $stageDir) { Remove-Item -Path $stageDir -Recurse -Force }
[void](New-Item -ItemType Directory -Path $stageDir -Force)

foreach ($item in $existingItems) {
    $dest = Join-Path $stageDir (Split-Path -Leaf $item)
    if (Test-Path -Path $item -PathType Container) {
        Copy-Item -Path $item -Destination $dest -Recurse -Force
    } else {
        Copy-Item -Path $item -Destination $dest -Force
    }
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
Remove-Item -Path $stageDir -Recurse -Force

Write-Host "  PASS  ZIP archive generated successfully." -ForegroundColor Green

# Generate SHA256 checksum
Write-Host "`n[4/4] Generating SHA256 checksum..." -ForegroundColor Yellow
$sha256 = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
$shaFile = "$zipPath.sha256"
"$sha256  $zipName" | Out-File -FilePath $shaFile -Encoding UTF8

Write-Host "  PASS  SHA256: $sha256" -ForegroundColor Green
Write-Host "  PASS  Checksum saved to: $shaFile" -ForegroundColor Green

$zipSizeMb = [math]::Round(((Get-Item $zipPath).Length / 1MB), 2)
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "PACKAGING COMPLETE: $zipName ($zipSizeMb MB)" -ForegroundColor Green
Write-Host "================================================================`n" -ForegroundColor Cyan
