<#
.SYNOPSIS
    MiniTmux (mtmux) - The Native Windows tmux Manager & Orchestrator.
.DESCRIPTION
    Provides an ergonomic Windows-first CLI for tmux: automatic MSYS=noglob handling,
    session lifecycle management, multi-agent layouts, diagnostics (doctor),
    Windows Terminal integration, and path translation.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$TmuxExe = Join-Path $RootDir 'usr\bin\tmux.exe'
$TmpDir = Join-Path $RootDir 'tmp'

# Ensure socket parent directory exists
if (-not (Test-Path -Path $TmpDir)) {
    [void](New-Item -ItemType Directory -Path $TmpDir -Force)
}

$env:MSYS = 'noglob disable_pcon winsymlinks:nativestrict'
$env:LANG = 'en_US.UTF-8'
$env:LC_ALL = 'en_US.UTF-8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Invoke-TmuxDirect {
    param([string[]]$ArgsList)
    & $TmuxExe -u @ArgsList
    $script:LastTmuxExitCode = $LASTEXITCODE
}

function Invoke-TmuxCapture {
    param([string[]]$ArgsList)
    $output = & $TmuxExe -u @ArgsList
    return $output
}

function Convert-ToPosixPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $resolved = [System.IO.Path]::GetFullPath($Path)
    if ($resolved -match '^([a-zA-Z]):\\(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest = $Matches[2].Replace('\', '/')
        return "/cygdrive/$drive/$rest"
    }
    return $resolved.Replace('\', '/')
}

function Show-Help {
    Write-Host @"
MiniTmux (mtmux) - Native Windows tmux Manager (v3.7b)

USAGE:
    mtmux                     Attach to 'main' session, or create it if not running
    mtmux new [name] [-d]     Create a new session (default: 'main')
    mtmux attach [name]       Attach to an existing session
    mtmux list | ls           List running sessions with detailed status
    mtmux kill [name|--all]   Terminate a session or kill the entire server
    mtmux layout <preset>     Launch or configure a structured layout (dev, split, quad, agents)
    mtmux run <target> <cmd>  Send a command to a pane and execute it (auto Enter; -n for raw keys)
    mtmux capture <target>    Capture and print visible pane content
    mtmux save [file]         Export running sessions, windows & layouts to snapshot file
    mtmux restore [file]      Restore sessions, windows & pane layouts from snapshot file
    mtmux theme [name|list]   List or switch visual color theme (catppuccin-mocha, tokyo-night, nord, etc.)
    mtmux doctor              Run comprehensive health, runtime, and collision diagnostics
    mtmux setup               Add MiniTmux to User PATH and register Windows Terminal profile
    mtmux wt [session]        Launch MiniTmux in a new tab inside Windows Terminal
    mtmux -- <tmux-args...>   Forward raw arguments directly to tmux

LAYOUT PRESETS:
    dev      Left 70% editor/main pane, Right 30% split into build and test panes
    split    Two side-by-side horizontal panes (50/50)
    vsplit   Two stacked vertical panes (50/50)
    quad     Balanced 2x2 grid (4 panes)
    agents   3-pane multi-agent orchestration layout (Coordinator + 2 Worker panes)

THEMES:
    catppuccin-mocha, tokyo-night, nord, gruvbox-dark, dracula, one-dark

EXAMPLES:
    mtmux
    mtmux new dev-session
    mtmux save
    mtmux restore
    mtmux theme tokyo-night
    mtmux layout agents -Name ai-team
    mtmux run ai-team:0.0 "git status"
    mtmux capture ai-team:0.0
    mtmux doctor
"@ -ForegroundColor Cyan
}

function Show-Doctor {
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host "                MiniTmux System Diagnostics & Health            " -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor DarkCyan

    $allPassed = $true

    # 1. Environment & Architecture
    Write-Host "[1/7] Environment & Host Architecture" -ForegroundColor Yellow
    $is64 = [Environment]::Is64BitOperatingSystem
    $osVersion = [Environment]::OSVersion.VersionString
    if ($is64) {
        Write-Host "  PASS  OS Architecture: 64-bit ($osVersion)" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  OS Architecture: 32-bit (MiniTmux requires 64-bit Windows)" -ForegroundColor Red
        $allPassed = $false
    }

    # 2. Binary Integrity
    Write-Host "`n[2/7] Core Binaries & Portable Root" -ForegroundColor Yellow
    Write-Host "  INFO  MiniTmux Root: $RootDir" -ForegroundColor Gray
    $binaries = @(
        'usr\bin\tmux.exe',
        'usr\bin\bash.exe',
        'usr\bin\msys-2.0.dll',
        'usr\bin\msys-event_core-2-1-7.dll',
        'usr\bin\msys-ncursesw6.dll',
        'etc\tmux.conf'
    )
    $binMissing = $false
    foreach ($bin in $binaries) {
        $p = Join-Path $RootDir $bin
        if (Test-Path -Path $p) {
            Write-Host "  PASS  Found $bin" -ForegroundColor Green
        } else {
            Write-Host "  FAIL  Missing $bin" -ForegroundColor Red
            $binMissing = $true
            $allPassed = $false
        }
    }

    # 3. Socket & Temp Directory
    Write-Host "`n[3/7] Socket Directory & Relocatability" -ForegroundColor Yellow
    if (Test-Path -Path $TmpDir) {
        $testFile = Join-Path $TmpDir ".write-test-$([System.Guid]::NewGuid())"
        try {
            [System.IO.File]::WriteAllText($testFile, "test")
            [System.IO.File]::Delete($testFile)
            Write-Host "  PASS  Socket directory $TmpDir exists and is writable" -ForegroundColor Green
        } catch {
            Write-Host "  FAIL  Socket directory $TmpDir is not writable ($($_.Exception.Message))" -ForegroundColor Red
            $allPassed = $false
        }
    } else {
        Write-Host "  FAIL  Socket directory $TmpDir does not exist" -ForegroundColor Red
        $allPassed = $false
    }

    # 4. Runtime Isolation & PATH Collision Check
    Write-Host "`n[4/7] Runtime Isolation & PATH Hygiene" -ForegroundColor Yellow
    $pathDirs = ($env:PATH -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $gitCollisions = $pathDirs | Where-Object {
        (Test-Path (Join-Path $_ "msys-2.0.dll")) -and
        (-not ($_.StartsWith($RootDir, [System.StringComparison]::OrdinalIgnoreCase)))
    }
    if ($gitCollisions) {
        Write-Host "  WARN  Found conflicting MSYS runtime(s) on host PATH:" -ForegroundColor Yellow
        foreach ($c in $gitCollisions) {
            Write-Host "        -> $c" -ForegroundColor DarkYellow
        }
        Write-Host "        (MiniTmux isolates its own runtime via .exe.local files and rebased DLLs)" -ForegroundColor Gray
    } else {
        Write-Host "  PASS  No colliding external msys-2.0.dll found before MiniTmux" -ForegroundColor Green
    }

    # 5. Encoding & Format Preserving
    Write-Host "`n[5/7] Console Encoding & Argument Handling" -ForegroundColor Yellow
    $testFormatOut = & $TmuxExe -L mtmux_diag new-session -d -s diag_test 2>&1
    $formatResult = (& $TmuxExe -L mtmux_diag list-sessions -F "#{session_name}" 2>&1) | Out-String
    & $TmuxExe -L mtmux_diag kill-server 2>&1 | Out-Null
    if ($formatResult -match 'diag_test') {
        Write-Host "  PASS  MSYS=noglob correctly preserves #{format} braces" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  Format braces were mangled (Output: $formatResult)" -ForegroundColor Red
        $allPassed = $false
    }

    # 6. Windows Clipboard Integration
    Write-Host "`n[6/7] Windows Clipboard Bridge" -ForegroundColor Yellow
    $clipExe = Join-Path $env:SystemRoot "System32\clip.exe"
    if (Test-Path $clipExe) {
        Write-Host "  PASS  Windows clip.exe detected at $clipExe" -ForegroundColor Green
    } else {
        Write-Host "  WARN  clip.exe not found in System32" -ForegroundColor Yellow
    }
    $winpasteExe = Join-Path $RootDir "usr\bin\winpaste.exe"
    if (Test-Path $winpasteExe) {
        Write-Host "  PASS  Native fast-paste winpaste.exe detected at $winpasteExe" -ForegroundColor Green
    } else {
        Write-Host "  WARN  winpaste.exe not found in usr\bin" -ForegroundColor Yellow
    }

    # 7. Windows Terminal & Shell Integration
    Write-Host "`n[7/7] Windows Terminal & Profile Integration" -ForegroundColor Yellow
    $wtCmd = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($wtCmd) {
        Write-Host "  PASS  Windows Terminal (wt.exe) detected" -ForegroundColor Green
    } else {
        Write-Host "  INFO  Windows Terminal not detected in PATH (optional)" -ForegroundColor Gray
    }

    $binInPath = ($pathDirs | Where-Object { $_.TrimEnd('\') -eq (Join-Path $RootDir 'bin').TrimEnd('\') })
    if ($binInPath) {
        Write-Host "  PASS  MiniTmux bin is registered in user PATH" -ForegroundColor Green
    } else {
        Write-Host "  INFO  MiniTmux bin is not yet in PATH (run 'mtmux setup' to add)" -ForegroundColor Cyan
    }

    Write-Host "`n================================================================" -ForegroundColor DarkCyan
    if ($allPassed) {
        Write-Host "RESULT: MiniTmux is healthy and fully operational on this system." -ForegroundColor Green
    } else {
        Write-Host "RESULT: Some checks failed. Review recommendations above." -ForegroundColor Red
    }
    Write-Host "================================================================`n" -ForegroundColor DarkCyan
}

function Show-Sessions {
    $sessions = & $TmuxExe list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}|#{session_created_string}" 2>$null
    if (-not $sessions) {
        Write-Host "No active tmux sessions running." -ForegroundColor Yellow
        Write-Host "Tip: Run 'mtmux new' to start a session." -ForegroundColor Gray
        return
    }

    Write-Host "`nActive MiniTmux Sessions:" -ForegroundColor Cyan
    Write-Host ("{0,-20} {1,-10} {2,-12} {3}" -f "SESSION", "WINDOWS", "STATUS", "CREATED") -ForegroundColor DarkGray
    Write-Host ("{0,-20} {1,-10} {2,-12} {3}" -f ("-"*19), ("-"*9), ("-"*11), ("-"*20)) -ForegroundColor DarkGray

    foreach ($s in $sessions) {
        $parts = $s -split '\|'
        $name = $parts[0]
        $windows = "$($parts[1]) windows"
        $attached = if ($parts[2] -eq "1") { "[attached]" } else { "detached" }
        $created = if ($parts.Count -gt 3) { $parts[3] } else { "" }
        $color = if ($parts[2] -eq "1") { "Green" } else { "White" }

        Write-Host ("{0,-20} {1,-10} {2,-12} {3}" -f $name, $windows, $attached, $created) -ForegroundColor $color
    }
    Write-Host ""
}

function Setup-Layout {
    param(
        [string]$Preset,
        [string]$SessionName = "main"
    )

    $hasSession = (& $TmuxExe -u has-session -t $SessionName 2>&1)
    if ($LASTEXITCODE -ne 0) {
        # Create detached session first
        Invoke-TmuxDirect @("new-session", "-d", "-s", $SessionName, "-x", "220", "-y", "55")
    }

    switch ($Preset.ToLower()) {
        'dev' {
            # 70% left, 30% right top and bottom
            Invoke-TmuxDirect @("split-window", "-h", "-t", "$($SessionName):0", "-p", "30")
            Invoke-TmuxDirect @("split-window", "-v", "-t", "$($SessionName):0.1", "-p", "50")
            Invoke-TmuxDirect @("select-pane", "-t", "$($SessionName):0.0")
            Write-Host "Created 'dev' layout in session '$SessionName' (editor + build/test panes)" -ForegroundColor Green
        }
        'split' {
            Invoke-TmuxDirect @("split-window", "-h", "-t", "$($SessionName):0", "-p", "50")
            Invoke-TmuxDirect @("select-pane", "-t", "$($SessionName):0.0")
            Write-Host "Created 'split' layout in session '$SessionName' (50/50 horizontal)" -ForegroundColor Green
        }
        'vsplit' {
            Invoke-TmuxDirect @("split-window", "-v", "-t", "$($SessionName):0", "-p", "50")
            Invoke-TmuxDirect @("select-pane", "-t", "$($SessionName):0.0")
            Write-Host "Created 'vsplit' layout in session '$SessionName' (50/50 vertical)" -ForegroundColor Green
        }
        'quad' {
            Invoke-TmuxDirect @("split-window", "-h", "-t", "$($SessionName):0", "-p", "50")
            Invoke-TmuxDirect @("split-window", "-v", "-t", "$($SessionName):0.0", "-p", "50")
            Invoke-TmuxDirect @("split-window", "-v", "-t", "$($SessionName):0.2", "-p", "50")
            Invoke-TmuxDirect @("select-pane", "-t", "$($SessionName):0.0")
            Write-Host "Created 'quad' 2x2 layout in session '$SessionName'" -ForegroundColor Green
        }
        'agents' {
            # Orchestrator left (55%), two agent panes stacked on right (45%)
            Invoke-TmuxDirect @("split-window", "-h", "-t", "$($SessionName):0", "-p", "45")
            Invoke-TmuxDirect @("split-window", "-v", "-t", "$($SessionName):0.1", "-p", "50")
            Invoke-TmuxDirect @("set-option", "-p", "-t", "$($SessionName):0.0", "@role", "coordinator")
            Invoke-TmuxDirect @("set-option", "-p", "-t", "$($SessionName):0.1", "@role", "worker-1")
            Invoke-TmuxDirect @("set-option", "-p", "-t", "$($SessionName):0.2", "@role", "worker-2")
            Invoke-TmuxDirect @("select-pane", "-t", "$($SessionName):0.0")
            Write-Host "Created 'agents' multi-agent layout in session '$SessionName'" -ForegroundColor Green
            Write-Host "  Pane 0: Coordinator [left]" -ForegroundColor Gray
            Write-Host "  Pane 1: Worker 1    [top right]" -ForegroundColor Gray
            Write-Host "  Pane 2: Worker 2    [bottom right]" -ForegroundColor Gray
        }
        default {
            Write-Error "Unknown layout preset: '$Preset'. Supported presets: dev, split, vsplit, quad, agents"
            return
        }
    }
}

function Setup-PathAndTerminal {
    Write-Host "Configuring MiniTmux environment..." -ForegroundColor Cyan

    $binDir = Join-Path $RootDir 'bin'
    $usrBinDir = Join-Path $RootDir 'usr\bin'

    # Add to User PATH via registry
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = ($userPath -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $changed = $false

    if ($entries -notcontains $binDir) {
        $entries = @($binDir) + $entries
        $changed = $true
    }
    if ($entries -notcontains $usrBinDir) {
        $entries = $entries + @($usrBinDir)
        $changed = $true
    }

    if ($changed) {
        $newPath = $entries -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:PATH = "$binDir;$usrBinDir;$env:PATH"
        Write-Host "  PASS  Added $binDir and $usrBinDir to User PATH" -ForegroundColor Green
        Write-Host "        (New terminals will have 'mtmux' and 'tmux' available globally)" -ForegroundColor Gray
    } else {
        Write-Host "  INFO  MiniTmux directories are already present in User PATH" -ForegroundColor Green
    }

    # Install Windows Terminal Profile if script exists
    $wtScript = Join-Path $RootDir 'scripts\Install-WindowsTerminalProfile.ps1'
    if (Test-Path $wtScript) {
        & $wtScript
    }
}

function Save-Sessions {
    param([string]$FilePath)

    $targetFile = if ($FilePath) { $FilePath } else { Join-Path $TmpDir 'saved_sessions.json' }
    
    # Query all sessions, windows, and panes
    $raw = & $TmuxExe list-panes -a -F "#{session_name}|#{window_index}|#{window_name}|#{window_layout}|#{pane_index}|#{pane_current_path}|#{pane_pid}" 2>$null
    if (-not $raw) {
        Write-Host "No active sessions found to save." -ForegroundColor Yellow
        return
    }

    $sessionsHash = @{}
    foreach ($line in $raw) {
        $parts = $line -split '\|'
        if ($parts.Count -lt 6) { continue }
        $sName = $parts[0]
        $wIdx  = [int]$parts[1]
        $wName = $parts[2]
        $wLayout = $parts[3]
        $pIdx  = [int]$parts[4]
        $pPath = $parts[5]

        if (-not $sessionsHash.ContainsKey($sName)) {
            $sessionsHash[$sName] = @{
                Name = $sName
                Windows = @{}
            }
        }
        $sess = $sessionsHash[$sName]
        if (-not $sess.Windows.ContainsKey($wIdx)) {
            $sess.Windows[$wIdx] = @{
                Index = $wIdx
                Name = $wName
                Layout = $wLayout
                Panes = @()
            }
        }
        $sess.Windows[$wIdx].Panes += @{
            Index = $pIdx
            Path = $pPath
        }
    }

    $sessionList = @()
    foreach ($sKey in $sessionsHash.Keys) {
        $sess = $sessionsHash[$sKey]
        $winList = @()
        foreach ($wKey in ($sess.Windows.Keys | Sort-Object)) {
            $w = $sess.Windows[$wKey]
            $winList += [PSCustomObject]@{
                Index = $w.Index
                Name = $w.Name
                Layout = $w.Layout
                Panes = $w.Panes
            }
        }
        $sessionList += [PSCustomObject]@{
            Name = $sess.Name
            Windows = $winList
        }
    }

    $exportData = [PSCustomObject]@{
        Version = 1
        SavedAt = (Get-Date).ToString("o")
        Sessions = $sessionList
    }

    $json = $exportData | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($targetFile, $json, [System.Text.Encoding]::UTF8)

    Write-Host "  PASS  Saved $(@($sessionList).Count) session(s) snapshot to: $targetFile" -ForegroundColor Green
}

function Restore-Sessions {
    param([string]$FilePath)

    $targetFile = if ($FilePath) { $FilePath } else { Join-Path $TmpDir 'saved_sessions.json' }
    if (-not (Test-Path $targetFile)) {
        Write-Host "Snapshot file not found: $targetFile" -ForegroundColor Red
        return
    }

    $content = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
    $data = $content | ConvertFrom-Json

    if (-not $data.Sessions) {
        Write-Host "No sessions found in snapshot." -ForegroundColor Yellow
        return
    }

    $restoredCount = 0
    foreach ($sess in $data.Sessions) {
        $sName = $sess.Name
        Write-Host "Restoring session '$sName'..." -ForegroundColor Cyan

        & $TmuxExe has-session -t $sName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  WARN  Session '$sName' already running. Skipping." -ForegroundColor Yellow
            continue
        }

        $firstWin = $sess.Windows[0]
        $firstPath = if ($firstWin.Panes.Count -gt 0) { $firstWin.Panes[0].Path } else { "" }
        
        $newArgs = @("new-session", "-d", "-s", $sName, "-n", $firstWin.Name)
        if ($firstPath) { $newArgs += @("-c", $firstPath) }
        & $TmuxExe @newArgs

        # Restore first window's additional panes and layout
        if ($firstWin.Panes.Count -gt 1) {
            for ($p = 1; $p -lt $firstWin.Panes.Count; $p++) {
                $panePath = $firstWin.Panes[$p].Path
                $splitArgs = @("split-window", "-t", "$($sName):$($firstWin.Index)")
                if ($panePath) { $splitArgs += @("-c", $panePath) }
                & $TmuxExe @splitArgs
            }
        }
        if ($firstWin.Layout) {
            & $TmuxExe select-layout -t "$($sName):$($firstWin.Index)" $firstWin.Layout 2>$null
        }

        # Restore subsequent windows
        for ($w = 1; $w -lt $sess.Windows.Count; $w++) {
            $win = $sess.Windows[$w]
            $wPath = if ($win.Panes.Count -gt 0) { $win.Panes[0].Path } else { "" }
            $winArgs = @("new-window", "-d", "-t", "$($sName):$($win.Index)", "-n", $win.Name)
            if ($wPath) { $winArgs += @("-c", $wPath) }
            & $TmuxExe @winArgs

            if ($win.Panes.Count -gt 1) {
                for ($p = 1; $p -lt $win.Panes.Count; $p++) {
                    $panePath = $win.Panes[$p].Path
                    $splitArgs = @("split-window", "-t", "$($sName):$($win.Index)")
                    if ($panePath) { $splitArgs += @("-c", $panePath) }
                    & $TmuxExe @splitArgs
                }
            }
            if ($win.Layout) {
                & $TmuxExe select-layout -t "$($sName):$($win.Index)" $win.Layout 2>$null
            }
        }
        $restoredCount++
        Write-Host "  PASS  Restored session '$sName' ($($sess.Windows.Count) windows)" -ForegroundColor Green
    }
    Write-Host "Successfully restored $restoredCount session(s)." -ForegroundColor Green
}

function Get-AvailableThemes {
    $themeDir = Join-Path $RootDir 'etc\themes'
    if (-not (Test-Path $themeDir)) { return @() }
    $files = Get-ChildItem -Path $themeDir -Filter "*.conf" | Where-Object { $_.BaseName -ne 'current' }
    return ($files | ForEach-Object { $_.BaseName })
}

function Show-Themes {
    $themes = Get-AvailableThemes
    $currentFile = Join-Path $RootDir 'etc\themes\current.conf'
    $currentHash = if (Test-Path $currentFile) { (Get-FileHash $currentFile -Algorithm SHA256).Hash } else { "" }

    Write-Host "`nMiniTmux Available Visual Themes:" -ForegroundColor Cyan
    foreach ($th in $themes) {
        $thFile = Join-Path $RootDir "etc\themes\$th.conf"
        $thHash = (Get-FileHash $thFile -Algorithm SHA256).Hash
        if ($thHash -eq $currentHash) {
            Write-Host "  * $th  (active)" -ForegroundColor Green
        } else {
            Write-Host "    $th" -ForegroundColor Gray
        }
    }
    Write-Host "`nTo switch theme: mtmux theme <name>`n" -ForegroundColor DarkCyan
}

function Set-Theme {
    param([string]$ThemeName)

    if ([string]::IsNullOrWhiteSpace($ThemeName) -or $ThemeName -eq "list") {
        Show-Themes
        return
    }

    $themeFile = Join-Path $RootDir "etc\themes\$ThemeName.conf"
    if (-not (Test-Path $themeFile)) {
        Write-Host "Unknown theme '$ThemeName'." -ForegroundColor Red
        Show-Themes
        return
    }

    $currentFile = Join-Path $RootDir 'etc\themes\current.conf'
    Copy-Item -Path $themeFile -Destination $currentFile -Force
    
    # Reload tmux live if server is running
    & $TmuxExe has-session 2>$null
    if ($LASTEXITCODE -eq 0) {
        & $TmuxExe source-file (Convert-ToPosixPath $currentFile) 2>$null
    }
    Write-Host "  PASS  Applied theme '$ThemeName'." -ForegroundColor Green
}

# --- Main Dispatcher ---

$action = if ($args.Count -gt 0) { $args[0].ToLower() } else { "default" }

switch ($action) {
    'help' {
        Show-Help
    }
    '-h' {
        Show-Help
    }
    '--help' {
        Show-Help
    }
    'doctor' {
        Show-Doctor
    }
    'diag' {
        Show-Doctor
    }
    'setup' {
        Setup-PathAndTerminal
    }
    'install' {
        Setup-PathAndTerminal
    }
    'list' {
        Show-Sessions
    }
    'ls' {
        Show-Sessions
    }
    'new' {
        $sessionName = "main"
        $detached = $false
        $dir = $null

        for ($i = 1; $i -lt $args.Count; $i++) {
            $arg = $args[$i]
            if ($arg -eq "-d" -or $arg -eq "--detached") {
                $detached = $true
            } elseif ($arg -eq "-c" -and ($i + 1) -lt $args.Count) {
                $dir = Convert-ToPosixPath $args[++$i]
            } elseif (-not $arg.StartsWith("-")) {
                $sessionName = $arg
            }
        }

        $cmdArgs = @("new-session")
        if ($detached) { $cmdArgs += "-d" }
        $cmdArgs += @("-s", $sessionName)
        if ($dir) { $cmdArgs += @("-c", $dir) }

        Invoke-TmuxDirect $cmdArgs
    }
    'attach' {
        $sessionName = if ($args.Count -gt 1) { $args[1] } else { "main" }
        Invoke-TmuxDirect @("attach-session", "-t", $sessionName)
    }
    'a' {
        $sessionName = if ($args.Count -gt 1) { $args[1] } else { "main" }
        Invoke-TmuxDirect @("attach-session", "-t", $sessionName)
    }
    'kill' {
        if ($args.Count -gt 1 -and ($args[1] -eq '--all' -or $args[1] -eq '-a')) {
            Invoke-TmuxDirect @("kill-server")
            Write-Host "MiniTmux server and all sessions terminated." -ForegroundColor Yellow
        } elseif ($args.Count -gt 1) {
            Invoke-TmuxDirect @("kill-session", "-t", $args[1])
            Write-Host "Killed session '$($args[1])'." -ForegroundColor Yellow
        } else {
            Invoke-TmuxDirect @("kill-session", "-t", "main")
            Write-Host "Killed session 'main'." -ForegroundColor Yellow
        }
    }
    'layout' {
        if ($args.Count -lt 2) {
            Write-Host "Usage: mtmux layout <dev|split|vsplit|quad|agents> [-Name session]" -ForegroundColor Yellow
            return
        }
        $preset = $args[1]
        $sess = "main"
        for ($i = 2; $i -lt $args.Count; $i++) {
            if (($args[$i] -eq "-Name" -or $args[$i] -eq "-s" -or $args[$i] -eq "-t") -and ($i + 1) -lt $args.Count) {
                $sess = $args[$i + 1]
            }
        }
        Setup-Layout -Preset $preset -SessionName $sess
    }
    'save' {
        $file = if ($args.Count -gt 1) { $args[1] } else { $null }
        Save-Sessions -FilePath $file
    }
    'restore' {
        $file = if ($args.Count -gt 1) { $args[1] } else { $null }
        Restore-Sessions -FilePath $file
    }
    'theme' {
        $th = if ($args.Count -gt 1) { $args[1] } else { "list" }
        Set-Theme -ThemeName $th
    }
    'themes' {
        Show-Themes
    }
    'agent' {
        $agentName = ""
        $dir = "-h"
        $target = ""
        for ($i = 1; $i -lt $args.Count; $i++) {
            if ($args[$i] -eq "-v" -or $args[$i] -eq "--vertical") { $dir = "-v" }
            elseif ($args[$i] -eq "-h" -or $args[$i] -eq "--horizontal") { $dir = "-h" }
            elseif ($args[$i] -eq "-t" -and ($i + 1) -lt $args.Count) { $target = $args[$i + 1]; $i++ }
            elseif (-not $agentName) { $agentName = $args[$i] }
        }
        $cmd = if ($agentName) { "agy --agent $agentName" } else { "agy" }
        $splitArgs = @("split-window", $dir)
        if ($target) { $splitArgs += @("-t", $target) }
        $splitArgs += "$cmd; exec bash"
        Invoke-TmuxDirect $splitArgs
        Write-Host "Spawned agent panel with '$cmd'" -ForegroundColor Green
    }
    'split' {
        $dir = "-h"
        $target = ""
        $customCmd = ""
        for ($i = 1; $i -lt $args.Count; $i++) {
            if ($args[$i] -eq "-v" -or $args[$i] -eq "--vertical") { $dir = "-v" }
            elseif ($args[$i] -eq "-h" -or $args[$i] -eq "--horizontal") { $dir = "-h" }
            elseif ($args[$i] -eq "-t" -and ($i + 1) -lt $args.Count) { $target = $args[$i + 1]; $i++ }
            else { $customCmd = ($args[$i..($args.Count - 1)]) -join ' '; break }
        }
        $splitArgs = @("split-window", $dir)
        if ($target) { $splitArgs += @("-t", $target) }
        if ($customCmd) { $splitArgs += "$customCmd; exec bash" }
        Invoke-TmuxDirect $splitArgs
        Write-Host "Added pane ($dir)" -ForegroundColor Green
    }
    'run' {
        if ($args.Count -lt 2) {
            Write-Host "Usage: mtmux run [target] [--no-enter|-n] <command>" -ForegroundColor Yellow
            return
        }

        # Ensure server/session exists
        $hasSess = (& $TmuxExe list-sessions 2>&1)
        if ($LASTEXITCODE -ne 0) {
            & $TmuxExe new-session -d -s main
        }

        $target = ""
        $noEnter = $false
        $cmdIndex = 1

        if ($args[1] -eq "--no-enter" -or $args[1] -eq "-n") {
            $noEnter = $true
            $cmdIndex = 2
        } else {
            $isTarget = $false
            if ($args.Count -ge 3) {
                if ($args[1] -match '^[a-zA-Z0-9_.-]+:[0-9]' -or $args[1] -match '^%[0-9]+') {
                    $isTarget = $true
                } else {
                    [void](& $TmuxExe has-session -t $args[1] 2>&1)
                    if ($LASTEXITCODE -eq 0) { $isTarget = $true }
                }
            }

            if ($isTarget) {
                $target = $args[1]
                $cmdIndex = 2
                if ($args.Count -gt 2 -and ($args[2] -eq "--no-enter" -or $args[2] -eq "-n")) {
                    $noEnter = $true
                    $cmdIndex = 3
                }
            }
        }

        $command = ($args[$cmdIndex..($args.Count - 1)]) -join ' '
        if ([string]::IsNullOrWhiteSpace($command)) {
            Write-Host "Usage: mtmux run [target] [--no-enter|-n] <command>" -ForegroundColor Yellow
            return
        }

        if ($target) {
            & $TmuxExe send-keys -t $target -l $command
            if (-not $noEnter) {
                & $TmuxExe send-keys -t $target Enter
            }
        } else {
            & $TmuxExe send-keys -l $command
            if (-not $noEnter) {
                & $TmuxExe send-keys Enter
            }
        }
    }
    'capture' {
        if ($args.Count -lt 2) {
            Write-Host "Usage: mtmux capture <target> [-n lines]" -ForegroundColor Yellow
            return
        }
        $target = $args[1]
        $lines = 50
        for ($i = 2; $i -lt $args.Count; $i++) {
            if ($args[$i] -eq "-n" -and ($i + 1) -lt $args.Count) {
                $lines = [int]$args[$i + 1]
            }
        }
        & $TmuxExe capture-pane -p -t $target -S "-$lines"
    }
    'wt' {
        $sess = if ($args.Count -gt 1) { $args[1] } else { "main" }
        $cmdPath = Join-Path $RootDir 'bin\mtmux.cmd'
        Start-Process wt.exe -ArgumentList "new-tab", "-p", "MiniTmux", "cmd.exe", "/c", "`"$cmdPath`" attach $sess"
    }
    '--' {
        $rawArgs = $args[1..($args.Count - 1)]
        Invoke-TmuxDirect $rawArgs
    }
    'default' {
        # Check if 'main' exists
        $hasMain = (& $TmuxExe has-session -t main 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Invoke-TmuxDirect @("attach-session", "-t", "main")
        } else {
            Invoke-TmuxDirect @("new-session", "-s", "main")
        }
    }
    default {
        # Forward any unhandled subcommands/flags to tmux directly
        Invoke-TmuxDirect $args
    }
}
