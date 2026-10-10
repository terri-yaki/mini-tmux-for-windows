<#
.SYNOPSIS
    Installs a dedicated "MiniTmux" profile into Windows Terminal.
.DESCRIPTION
    Uses Windows Terminal JSON Fragments (the official Microsoft non-destructive extension mechanism)
    to automatically register MiniTmux as a first-class terminal profile.
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MtmuxCmd = Join-Path $RootDir 'bin\mtmux.cmd'

if (-not (Test-Path $MtmuxCmd)) {
    Write-Error "MiniTmux launcher not found at $MtmuxCmd"
    exit 1
}

$fragmentsBase = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments'
$minitmuxFragmentDir = Join-Path $fragmentsBase 'minitmux'

if (-not (Test-Path $minitmuxFragmentDir)) {
    [void](New-Item -ItemType Directory -Path $minitmuxFragmentDir -Force)
}

$fragmentFile = Join-Path $minitmuxFragmentDir 'minitmux.json'

$escapedCmd = $MtmuxCmd.Replace('\', '\\')

$fragmentContent = @"
{
  "profiles": [
    {
      "name": "MiniTmux",
      "commandline": "cmd.exe /k \"$escapedCmd\"",
      "startingDirectory": "%USERPROFILE%",
      "icon": "ms-appx:///ProfileIcons/{0caa0dad-35be-5f56-a8ff-afceeeaa6101}.png",
      "cursorShape": "bar",
      "font": {
        "face": "Cascadia Code"
      },
      "colorScheme": "Campbell Powershell",
      "closeOnExit": "graceful",
      "tabTitle": "MiniTmux"
    }
  ]
}
"@

[System.IO.File]::WriteAllText($fragmentFile, $fragmentContent, [System.Text.Encoding]::UTF8)

Write-Host "  PASS  Installed Windows Terminal profile fragment at:" -ForegroundColor Green
Write-Host "        $fragmentFile" -ForegroundColor Gray
Write-Host "        You can now open a 'MiniTmux' tab directly from the Windows Terminal '+' menu!" -ForegroundColor Cyan
