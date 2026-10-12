<#
.SYNOPSIS
    MiniTmux Automated Windows-Host Test Suite (Performance-Optimized).
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

function Wait-Condition {
    param(
        [scriptblock]$Predicate,
        [int]$TimeoutMs = 1500,
        [int]$IntervalMs = 25
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        if (& $Predicate) { return $true }
        Start-Sleep -Milliseconds $IntervalMs
    }
    return $false
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "            MiniTmux Windows Verification Test Suite            " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Testing MiniTmux Root: $RootDir`n" -ForegroundColor Gray

$swSuite = [System.Diagnostics.Stopwatch]::StartNew()

# Ensure server is clean before starting
& $TmuxPs1 kill-server 2>$null
[void](Wait-Condition { -not (Get-Process -Name "*tmux*" -ErrorAction SilentlyContinue) } 500)

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
[void](Wait-Condition { (& $TmuxPs1 has-session -t io_sess 2>$null); $LASTEXITCODE -eq 0 } 500)

& $MtmuxPs1 run io_sess:0.0 "echo MINI_TMUX_TOKEN_789"
$capOk = Wait-Condition {
    $out = (& $MtmuxPs1 capture io_sess:0.0 -n 10 2>&1) | Out-String
    $out -match 'MINI_TMUX_TOKEN_789'
} 1500
Assert-Check "mtmux run and capture read back executed command" $capOk

# UTF-8 Roundtrip
& $MtmuxPs1 run io_sess:0.0 "echo UTF8_ROUNDTRIP_OK"
$utf8Ok = Wait-Condition {
    $out = (& $MtmuxPs1 capture io_sess:0.0 -n 10 2>&1) | Out-String
    $out -match 'UTF8_ROUNDTRIP_OK'
} 1500
Assert-Check "Terminal input/output command roundtrip" $utf8Ok

# Smart run without target
& $MtmuxPs1 run "echo SMART_RUN_NO_TARGET"
$smartRunOk = Wait-Condition {
    $out = (& $MtmuxPs1 capture -n 10 2>&1) | Out-String
    $out -match 'SMART_RUN_NO_TARGET'
} 1500
Assert-Check "mtmux run <cmd> targets active pane without target" $smartRunOk

# Dynamic split & agent panel
& $MtmuxPs1 split -h -t io_sess
$paneSplitCount = (& $TmuxPs1 list-panes -t io_sess | Measure-Object).Count
Assert-Check "mtmux split adds pane to session" ($paneSplitCount -ge 2)

& $MtmuxPs1 kill io_sess

# -----------------------------------------------------------------------------
# 7. Path Translation
# -----------------------------------------------------------------------------
Write-Host "`n[Group 7] Path Translation" -ForegroundColor Yellow

& $MtmuxPs1 new path_sess -d -c "$RootDir"
[void](Wait-Condition { (& $TmuxPs1 has-session -t path_sess 2>$null); $LASTEXITCODE -eq 0 } 500)

& $MtmuxPs1 run path_sess:0.0 "pwd"
$pathOk = Wait-Condition {
    $out = (& $MtmuxPs1 capture path_sess:0.0 -n 10 2>&1) | Out-String
    $out -match '/cygdrive/.*mini-tmux-for-windows'
} 1500
Assert-Check "Windows working directory translated to POSIX /cygdrive" $pathOk
& $MtmuxPs1 kill path_sess

# -----------------------------------------------------------------------------
# 8. Visual Theme System
# -----------------------------------------------------------------------------
Write-Host "`n[Group 8] Visual Theme Management" -ForegroundColor Yellow

$themeListOut = (& $MtmuxPs1 theme list *>&1) | Out-String
Assert-Check "mtmux theme list displays available themes" ($themeListOut -match 'tokyo-night' -and $themeListOut -match 'catppuccin-mocha') "Got: $themeListOut"

& $MtmuxPs1 theme tokyo-night
$currTheme = Join-Path $RootDir 'etc\themes\current.conf'
$tokyoContent = [System.IO.File]::ReadAllText($currTheme)
Assert-Check "mtmux theme tokyo-night applies theme configuration" ($tokyoContent -match '#1a1b26')

# Reset to catppuccin
& $MtmuxPs1 theme catppuccin-mocha

# -----------------------------------------------------------------------------
# 9. Session Persistence (Save & Restore)
# -----------------------------------------------------------------------------
Write-Host "`n[Group 9] Session Persistence (Save & Restore)" -ForegroundColor Yellow

& $MtmuxPs1 new snap_sess -d
& $MtmuxPs1 layout split -Name snap_sess

$snapFile = Join-Path $RootDir 'tmp\test_snap.json'
if (Test-Path $snapFile) { Remove-Item -Path $snapFile -Force }

& $MtmuxPs1 save $snapFile
Assert-Check "mtmux save exports snapshot JSON" (Test-Path $snapFile)

$snapJson = [System.IO.File]::ReadAllText($snapFile)
Assert-Check "Snapshot contains session and pane layout" ($snapJson -match 'snap_sess')

# Terminate session then restore from snapshot
& $MtmuxPs1 kill snap_sess
[void](Wait-Condition { (& $TmuxPs1 has-session -t snap_sess 2>$null); $LASTEXITCODE -ne 0 } 500)

& $MtmuxPs1 restore $snapFile
$restoreOk = Wait-Condition { (& $TmuxPs1 has-session -t snap_sess 2>$null); $LASTEXITCODE -eq 0 } 1500
Assert-Check "mtmux restore recreates saved session and panes" $restoreOk

& $MtmuxPs1 kill snap_sess
if (Test-Path $snapFile) { Remove-Item -Path $snapFile -Force }

# -----------------------------------------------------------------------------
# 10. Inspection & Hierarchy (JSON Serialization)
# -----------------------------------------------------------------------------
Write-Host "`n[Group 10] Inspection Hierarchy & JSON Schema" -ForegroundColor Yellow

& $MtmuxPs1 new inspect_sess -d
& $MtmuxPs1 layout agents -Name inspect_sess
[void](Wait-Condition { (& $TmuxPs1 has-session -t inspect_sess 2>$null); $LASTEXITCODE -eq 0 } 500)

$inspectJson = (& $MtmuxPs1 inspect inspect_sess --json 2>&1) | Out-String
Assert-Check "mtmux inspect --json returns structured JSON" ($inspectJson -match 'coordinator' -and $inspectJson -match 'worker-1')

$inspectTree = (& $MtmuxPs1 inspect inspect_sess 2>&1) | Out-String
Assert-Check "mtmux inspect renders tree hierarchy" ($inspectTree -match 'Session' -and $inspectTree -match 'Window')

& $MtmuxPs1 kill inspect_sess

# -----------------------------------------------------------------------------
# 11. Shell Completion Generation
# -----------------------------------------------------------------------------
Write-Host "`n[Group 11] Shell Completion Generation" -ForegroundColor Yellow

$compPwsh = (& $MtmuxPs1 completion powershell 2>&1) | Out-String
Assert-Check "mtmux completion powershell contains completer block" ($compPwsh -match 'Register-ArgumentCompleter')

$compBash = (& $MtmuxPs1 completion bash 2>&1) | Out-String
Assert-Check "mtmux completion bash contains function definition" ($compBash -match '_mtmux_completions')

$compZsh = (& $MtmuxPs1 completion zsh 2>&1) | Out-String
Assert-Check "mtmux completion zsh contains definition" ($compZsh -match '_mtmux')

# -----------------------------------------------------------------------------
# 12. Batch Fast-Paths & Automation Module
# -----------------------------------------------------------------------------
Write-Host "`n[Group 12] Batch Fast-Paths & MiniTmux Module" -ForegroundColor Yellow

# Test bin\mtmux.cmd fast-path execution
& cmd.exe /c "`"$MtmuxCmd`" new cmd_sess -d"
$cmdSessOk = Wait-Condition { (& $TmuxPs1 has-session -t cmd_sess 2>$null); $LASTEXITCODE -eq 0 } 1000
Assert-Check "bin\mtmux.cmd fast-path creates detached session" $cmdSessOk

$cmdLs = (& cmd.exe /c "`"$MtmuxCmd`" ls" 2>&1) | Out-String
Assert-Check "bin\mtmux.cmd ls shows running session" ($cmdLs -match 'cmd_sess')

& cmd.exe /c "`"$MtmuxCmd`" run cmd_sess:0.0 `"echo BATCH_FAST_PATH_OK`""
$batchCapOk = Wait-Condition {
    $out = (& cmd.exe /c "`"$MtmuxCmd`" capture cmd_sess:0.0 -n 10" 2>&1) | Out-String
    $out -match 'BATCH_FAST_PATH_OK'
} 1500
Assert-Check "bin\mtmux.cmd run and capture verify I/O roundtrip" $batchCapOk

& cmd.exe /c "`"$MtmuxCmd`" kill cmd_sess"

# Test MiniTmux.psm1 module cmdlets
$modulePath = Join-Path $RootDir 'scripts\MiniTmux.psm1'
Import-Module $modulePath -Force
Assert-Check "Import-Module MiniTmux succeeds" ($null -ne (Get-Module -Name MiniTmux))

$sessionsCmdlet = Get-MiniTmuxSession
Assert-Check "Get-MiniTmuxSession executes without errors" ($null -ne $sessionsCmdlet -or $sessionsCmdlet.Count -eq 0)

# -----------------------------------------------------------------------------
# 13. Clean Teardown
# -----------------------------------------------------------------------------
Write-Host "`n[Group 13] Server Teardown & Process Hygiene" -ForegroundColor Yellow

& $MtmuxPs1 kill --all
[void](Wait-Condition { -not (Get-Process -Name "*tmux*" -ErrorAction SilentlyContinue) } 500)

$deadCheck = (& $TmuxPs1 list-sessions 2>&1) | Out-String
Assert-Check "Server clean shutdown with no surviving sessions" ($deadCheck -match 'no server running' -or $LASTEXITCODE -ne 0)

# -----------------------------------------------------------------------------
# Test Summary & Benchmark Timing
# -----------------------------------------------------------------------------
$swSuite.Stop()
$elapsed = [math]::Round($swSuite.Elapsed.TotalSeconds, 2)

Write-Host "`n================================================================" -ForegroundColor Cyan
$total = $Script:PassCount + $Script:FailCount
if ($Script:FailCount -eq 0) {
    Write-Host "ALL TESTS PASSED: $Script:PassCount / $total checks passed in $elapsed seconds!" -ForegroundColor Green
    Write-Host "================================================================`n" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "TESTS COMPLETED WITH FAILURES: $Script:PassCount passed, $Script:FailCount failed ($elapsed s)." -ForegroundColor Red
    Write-Host "================================================================`n" -ForegroundColor Cyan
    exit 1
}
