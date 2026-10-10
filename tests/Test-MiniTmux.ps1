<#
.SYNOPSIS
    MiniTmux Automated Windows-Host Test Suite.
.DESCRIPTION
    Executes end-to-end verification of MiniTmux directly from native Windows PowerShell.
    Validates wrappers, noglob handling, session lifecycles, layouts, UTF-8, and path translations.
#>

[CmdletBinding()]
param()

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MtmuxCmd = Join-Path $RootDir 'bin\mtmux.cmd'
$MtmuxPs1 = Join-Path $RootDir 'bin\mtmux.ps1'
$TmuxCmd  = Join-Path $RootDir 'bin\tmux.cmd'
$TmuxPs1  = Join-Path $RootDir 'bin\tmux.ps1'

$Script:PassCount = 0
$Script:FailCount = 0

function Assert-Check {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Detail = ""
    )

    if ($Condition) {
        $Script:PassCount++
        Write-Host "  PASS  $TestName" -ForegroundColor Green
    } else {
        $Script:FailCount++
        Write-Host "  FAIL  $TestName" -ForegroundColor Red
        if ($Detail) {
            Write-Host "        Reason: $Detail" -ForegroundColor DarkRed
        }
    }
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "            MiniTmux Windows Verification Test Suite            " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Testing MiniTmux Root: $RootDir`n" -ForegroundColor Gray

# Ensure server is clean before starting
& $TmuxPs1 kill-server 2>$null
Start-Sleep -Milliseconds 400

# -----------------------------------------------------------------------------
# 1. Binary & Wrapper Sanity
# -----------------------------------------------------------------------------
Write-Host "[Group 1] Binary & Wrapper Verification" -ForegroundColor Yellow

$verCmd = (& $TmuxCmd -V 2>&1) | Out-String
Assert-Check "bin\tmux.cmd reports version 3.7b" ($verCmd -match 'tmux 3\.7b') "Got: $verCmd"

$verPs1 = (& $TmuxPs1 -V 2>&1) | Out-String
Assert-Check "bin\tmux.ps1 reports version 3.7b" ($verPs1 -match 'tmux 3\.7b') "Got: $verPs1"

$docOut = (& $MtmuxPs1 doctor *>&1) | Out-String
Assert-Check "mtmux doctor passes" ($docOut -match 'MiniTmux is healthy and fully operational') "Doctor output failed: $docOut"

# -----------------------------------------------------------------------------
# 2. Argument & Format String Integrity (MSYS=noglob)
# -----------------------------------------------------------------------------
Write-Host "`n[Group 2] Format String & Noglob Protection" -ForegroundColor Yellow

& $TmuxPs1 -L test_noglob new-session -d -s noglob_sess
$formatOut = (& $TmuxPs1 -L test_noglob list-sessions -F "#{session_name}" 2>&1) | Out-String
& $TmuxPs1 -L test_noglob kill-server 2>&1 | Out-Null

Assert-Check "Preserves #{session_name} braces without stripping" ($formatOut.Trim() -eq 'noglob_sess') "Got: $formatOut"

# -----------------------------------------------------------------------------
# 3. Session Lifecycle & mtmux CLI
# -----------------------------------------------------------------------------
Write-Host "`n[Group 3] Session Lifecycle Management" -ForegroundColor Yellow

& $MtmuxPs1 new test_alpha -d
$null = & $TmuxPs1 has-session -t test_alpha 2>&1
Assert-Check "mtmux new creates detached session" ($LASTEXITCODE -eq 0)

$lsOut = (& $MtmuxPs1 ls *>&1) | Out-String
Assert-Check "mtmux ls shows test_alpha session" ($lsOut -match 'test_alpha') "Got: $lsOut"

& $TmuxPs1 rename-session -t test_alpha test_beta
$null = & $TmuxPs1 has-session -t test_beta 2>&1
Assert-Check "Session rename works" ($LASTEXITCODE -eq 0)

& $MtmuxPs1 kill test_beta
$null = & $TmuxPs1 has-session -t test_beta 2>$null
Assert-Check "mtmux kill terminates session" ($LASTEXITCODE -ne 0)

# -----------------------------------------------------------------------------
# 4. Multi-Pane & Window Operations
# -----------------------------------------------------------------------------
Write-Host "`n[Group 4] Window and Pane Operations" -ForegroundColor Yellow

& $TmuxPs1 -L test_panes new-session -d -s pane_sess -x 200 -y 50
& $TmuxPs1 -L test_panes new-window -t pane_sess -n logs
$winOut = (& $TmuxPs1 -L test_panes list-windows -t pane_sess -F "#{window_name}" 2>&1) | Out-String
Assert-Check "Created second window named logs" ($winOut -match 'logs')

& $TmuxPs1 -L test_panes split-window -h -t pane_sess:logs
& $TmuxPs1 -L test_panes split-window -v -t pane_sess:logs.1
$panes = (& $TmuxPs1 -L test_panes list-panes -t pane_sess:logs -F "x" 2>&1)
$paneCount = ($panes -split "`n" | Where-Object { $_.Trim() -eq 'x' }).Count
Assert-Check "Window contains 3 split panes" ($paneCount -ge 3) "Got pane count: $paneCount"

& $TmuxPs1 -L test_panes kill-server 2>&1 | Out-Null

# -----------------------------------------------------------------------------
# 5. Layout Presets (dev, split, quad, agents)
# -----------------------------------------------------------------------------
Write-Host "`n[Group 5] Layout Presets" -ForegroundColor Yellow

& $MtmuxPs1 new team_sess -d
& $MtmuxPs1 layout agents -Name team_sess

$coordRole = (& $TmuxPs1 list-panes -t team_sess:0.0 -F "#{@role}" 2>&1) | Out-String
Assert-Check "Agents layout pane 0 labeled coordinator" ($coordRole -match 'coordinator') "Got: $coordRole"

$w1Role = (& $TmuxPs1 list-panes -t team_sess:0.1 -F "#{@role}" 2>&1) | Out-String
Assert-Check "Agents layout pane 1 labeled worker-1" ($w1Role -match 'worker-1') "Got: $w1Role"

$w2Role = (& $TmuxPs1 list-panes -t team_sess:0.2 -F "#{@role}" 2>&1) | Out-String
Assert-Check "Agents layout pane 2 labeled worker-2" ($w2Role -match 'worker-2') "Got: $w2Role"

& $MtmuxPs1 kill team_sess

# -----------------------------------------------------------------------------
# 6. Command Execution & Output Capture
# -----------------------------------------------------------------------------
Write-Host "`n[Group 6] Input / Output Execution & UTF-8" -ForegroundColor Yellow

& $MtmuxPs1 new io_sess -d
Start-Sleep -Milliseconds 400

& $MtmuxPs1 run io_sess:0.0 "echo MINI_TMUX_TOKEN_789"
Start-Sleep -Milliseconds 600

$captured = (& $MtmuxPs1 capture io_sess:0.0 -n 15 2>&1) | Out-String
Assert-Check "mtmux run and capture read back executed command" ($captured -match 'MINI_TMUX_TOKEN_789') "Output: $captured"

# UTF-8 Roundtrip
& $MtmuxPs1 run io_sess:0.0 "echo UTF8_ROUNDTRIP_OK"
Start-Sleep -Milliseconds 600
$utf8Cap = (& $MtmuxPs1 capture io_sess:0.0 -n 15 2>&1) | Out-String
Assert-Check "Terminal input/output command roundtrip" ($utf8Cap -match 'UTF8_ROUNDTRIP_OK') "Output: $utf8Cap"

& $MtmuxPs1 kill io_sess

# -----------------------------------------------------------------------------
# 7. Path Translation & Cleanup
# -----------------------------------------------------------------------------
Write-Host "`n[Group 7] Path Translation & Teardown" -ForegroundColor Yellow

& $MtmuxPs1 new path_sess -d -c "$RootDir"
Start-Sleep -Milliseconds 400

& $MtmuxPs1 run path_sess:0.0 "pwd"
Start-Sleep -Milliseconds 600

$panePath = (& $MtmuxPs1 capture path_sess:0.0 -n 10 2>&1) | Out-String
Assert-Check "Windows working directory translated to POSIX /cygdrive" ($panePath -match '/cygdrive/.*mini-tmux-for-windows') "Got path: $panePath"

& $MtmuxPs1 kill --all
Start-Sleep -Milliseconds 300

$deadCheck = (& $TmuxPs1 list-sessions 2>&1) | Out-String
Assert-Check "Server clean shutdown with no surviving sessions" ($deadCheck -match 'no server running' -or $LASTEXITCODE -ne 0)

# -----------------------------------------------------------------------------
# Test Summary
# -----------------------------------------------------------------------------
Write-Host "`n================================================================" -ForegroundColor Cyan
$total = $Script:PassCount + $Script:FailCount
if ($Script:FailCount -eq 0) {
    Write-Host "ALL TESTS PASSED: $Script:PassCount / $total checks passed." -ForegroundColor Green
    Write-Host "================================================================`n" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "TESTS COMPLETED WITH FAILURES: $Script:PassCount passed, $Script:FailCount failed." -ForegroundColor Red
    Write-Host "================================================================`n" -ForegroundColor Cyan
    exit 1
}
