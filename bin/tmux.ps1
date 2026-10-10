<#
.SYNOPSIS
    MiniTmux native PowerShell wrapper for tmux.
.DESCRIPTION
    Wraps tmux.exe with automatic MSYS=noglob environment injection,
    socket directory validation, UTF-8 console encoding, and argument forwarding.
#>

# Resolve root path of MiniTmux
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

# Ensure socket parent directory exists
$TmpDir = Join-Path $RootDir 'tmp'
if (-not (Test-Path -Path $TmpDir)) {
    [void](New-Item -ItemType Directory -Path $TmpDir -Force)
}

# Preserve #{...} format braces across non-MSYS process boundaries & optimize POSIX runtime
$env:MSYS = 'noglob disable_pcon winsymlinks:nativestrict'
$env:LANG = 'en_US.UTF-8'
$env:LC_ALL = 'en_US.UTF-8'

# Ensure console output uses UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$TmuxExe = Join-Path $RootDir 'usr\bin\tmux.exe'
if (-not (Test-Path -Path $TmuxExe)) {
    Write-Error "MiniTmux binary not found at: $TmuxExe"
    exit 1
}

# Execute tmux directly with -u UTF-8 flag and forwarded arguments
& $TmuxExe -u @args
exit $LASTEXITCODE
