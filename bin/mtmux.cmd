@echo off
setlocal enabledelayedexpansion

:: Resolve MiniTmux root
set "MINITMUX_ROOT=%~dp0.."
for %%i in ("%MINITMUX_ROOT%") do set "MINITMUX_ROOT=%%~fi"

if not exist "%MINITMUX_ROOT%\tmp" mkdir "%MINITMUX_ROOT%\tmp" >nul 2>&1

:: High-performance runtime environment flags
set "MSYS=noglob disable_pcon winsymlinks:nativestrict"
set "LANG=en_US.UTF-8"
set "LC_ALL=en_US.UTF-8"
chcp 65001 >nul 2>&1

set "TMUX_EXE=%MINITMUX_ROOT%\usr\bin\tmux.exe"

set "SUBCMD=%~1"

:: Fast-path 1: No arguments -> attach to main or create main
if "%SUBCMD%"=="" (
    "%TMUX_EXE%" -u has-session -t main >nul 2>&1
    if errorlevel 1 (
        "%TMUX_EXE%" -u new-session -s main
    ) else (
        "%TMUX_EXE%" -u attach-session -t main
    )
    exit /b %ERRORLEVEL%
)

:: Fast-path 2: list / ls
if /i "%SUBCMD%"=="ls" goto :do_list
if /i "%SUBCMD%"=="list" goto :do_list
goto :check_attach

:do_list
"%TMUX_EXE%" -u list-sessions -F "#{session_name}: #{session_windows} windows (created #{session_created_string}) #{?session_attached,[attached],[detached]}" 2>nul
if errorlevel 1 (
    echo No active MiniTmux sessions running.
)
exit /b 0

:check_attach
:: Fast-path 3: attach / a
if /i "%SUBCMD%"=="attach" goto :do_attach
if /i "%SUBCMD%"=="a" goto :do_attach
goto :check_kill

:do_attach
set "SESS=%~2"
if "!SESS!"=="" set "SESS=main"
"%TMUX_EXE%" -u attach-session -t "!SESS!"
exit /b %ERRORLEVEL%

:check_kill
:: Fast-path 4: kill
if /i "%SUBCMD%"=="kill" (
    if "%~2"=="--all" (
        "%TMUX_EXE%" -u kill-server
        echo MiniTmux server and all sessions terminated.
        exit /b 0
    )
    if "%~2"=="-a" (
        "%TMUX_EXE%" -u kill-server
        echo MiniTmux server and all sessions terminated.
        exit /b 0
    )
    set "SESS=%~2"
    if "!SESS!"=="" set "SESS=main"
    "%TMUX_EXE%" -u kill-session -t "!SESS!"
    echo Killed session '!SESS!'.
    exit /b 0
)

:: Fast-path 5: run <target> <command>
if /i "%SUBCMD%"=="run" (
    set "TARGET=%~2"
    shift
    shift
    set "CMD_TEXT="
    :run_loop
    if "%~1"=="" goto :run_exec
    if "!CMD_TEXT!"=="" (
        set "CMD_TEXT=%~1"
    ) else (
        set "CMD_TEXT=!CMD_TEXT! %~1"
    )
    shift
    goto :run_loop
    :run_exec
    "%TMUX_EXE%" -u send-keys -t "!TARGET!" -l "!CMD_TEXT!"
    "%TMUX_EXE%" -u send-keys -t "!TARGET!" Enter
    exit /b 0
)

:: Fast-path 6: capture <target>
if /i "%SUBCMD%"=="capture" (
    set "TARGET=%~2"
    set "LINES=50"
    if "%~3"=="-n" set "LINES=%~4"
    "%TMUX_EXE%" -u capture-pane -p -t "!TARGET!" -S "-!LINES!"
    exit /b %ERRORLEVEL%
)

:: Fast-path 7: raw forwarding '--'
if "%SUBCMD%"=="--" (
    shift
    "%TMUX_EXE%" -u %1 %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

:: Fall back to PowerShell for rich features (doctor, setup, layout presets, complex new-session parsing)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MINITMUX_ROOT%\bin\mtmux.ps1" %*
exit /b %ERRORLEVEL%
