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

:: Fast-path 2: new
if /i "%SUBCMD%"=="new" goto :do_new

:: Fast-path 3: list / ls
if /i "%SUBCMD%"=="ls" goto :do_list
if /i "%SUBCMD%"=="list" goto :do_list

:: Fast-path 4: attach / a
if /i "%SUBCMD%"=="attach" goto :do_attach
if /i "%SUBCMD%"=="a" goto :do_attach

:: Fast-path 5: kill
if /i "%SUBCMD%"=="kill" goto :do_kill

:: Fast-path 6: theme (fast-path switcher)
if /i "%SUBCMD%"=="theme" goto :do_theme

:: Fast-path 7: run <target> [--no-enter|-n] <command>
if /i "%SUBCMD%"=="run" goto :do_run

:: Fast-path 8: capture <target>
if /i "%SUBCMD%"=="capture" goto :do_capture

:: Fast-path 9: raw forwarding '--'
if "%SUBCMD%"=="--" (
    shift
    "%TMUX_EXE%" -u %1 %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

:: Fall back to PowerShell for rich features (doctor, setup, layout presets, save/restore, etc.)
:fallback_ps
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MINITMUX_ROOT%\bin\mtmux.ps1" %*
exit /b %ERRORLEVEL%

:do_new
set "NEW_SESS=%~2"
set "NEW_DETACHED=0"
if "%NEW_SESS%"=="" set "NEW_SESS=main"
if "%NEW_SESS%"=="-d" (
    set "NEW_DETACHED=1"
    set "NEW_SESS=%~3"
    if "!NEW_SESS!"=="" set "NEW_SESS=main"
) else if "%NEW_SESS%"=="--detached" (
    set "NEW_DETACHED=1"
    set "NEW_SESS=%~3"
    if "!NEW_SESS!"=="" set "NEW_SESS=main"
) else if "%~3"=="-d" (
    set "NEW_DETACHED=1"
) else if "%~3"=="--detached" (
    set "NEW_DETACHED=1"
)
:: If caller supplied custom directory flags (-c), defer to PowerShell for path translation
if "%~2"=="-c" goto :fallback_ps
if "%~3"=="-c" goto :fallback_ps
if "%~4"=="-c" goto :fallback_ps

if "!NEW_DETACHED!"=="1" (
    "%TMUX_EXE%" -u new-session -d -s "!NEW_SESS!"
    echo Created detached session '!NEW_SESS!'.
    exit /b 0
)
"%TMUX_EXE%" -u has-session -t "!NEW_SESS!" >nul 2>&1
if not errorlevel 1 (
    echo Session '!NEW_SESS!' already exists. Attaching...
    "%TMUX_EXE%" -u attach-session -t "!NEW_SESS!"
    exit /b %ERRORLEVEL%
)
"%TMUX_EXE%" -u new-session -s "!NEW_SESS!"
exit /b %ERRORLEVEL%

:do_list
"%TMUX_EXE%" -u list-sessions -F "#{session_name}: #{session_windows} windows (created #{session_created_string}) #{?session_attached,[attached],[detached]}" 2>nul
if errorlevel 1 (
    echo No active MiniTmux sessions running.
)
exit /b 0

:do_attach
set "SESS=%~2"
if "!SESS!"=="" set "SESS=main"
"%TMUX_EXE%" -u attach-session -t "!SESS!"
exit /b %ERRORLEVEL%

:do_kill
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

:do_theme
set "THEME_NAME=%~2"
if "!THEME_NAME!"=="" goto :fallback_ps
if /i "!THEME_NAME!"=="list" goto :fallback_ps
set "THEME_FILE=%MINITMUX_ROOT%\etc\themes\!THEME_NAME!.conf"
if not exist "!THEME_FILE!" (
    echo Unknown theme '!THEME_NAME!'. Available themes:
    for %%f in ("%MINITMUX_ROOT%\etc\themes\*.conf") do (
        if not "%%~nf"=="current" echo   - %%~nf
    )
    exit /b 1
)
copy /y "!THEME_FILE!" "%MINITMUX_ROOT%\etc\themes\current.conf" >nul
"%TMUX_EXE%" -u has-session >nul 2>&1
if not errorlevel 1 (
    "%TMUX_EXE%" -u source-file "%MINITMUX_ROOT%\etc\themes\current.conf" 2>nul
)
echo Applied theme '!THEME_NAME!'.
exit /b 0

:do_run
shift
set "TARGET="
set "NO_ENTER=0"
if "%~1"=="--no-enter" (
    set "NO_ENTER=1"
    shift
)
if "%~1"=="-n" (
    set "NO_ENTER=1"
    shift
)

:: If at least two arguments remain, check if %~1 is a target (has colon, %, or known session)
if not "%~2"=="" (
    echo %~1 | findstr /R /C:":[0-9]" /C:"^%%[0-9]" >nul 2>&1
    if not errorlevel 1 (
        set "TARGET=%~1"
        shift
    )
)

if "%~1"=="--no-enter" (
    set "NO_ENTER=1"
    shift
)
if "%~1"=="-n" (
    set "NO_ENTER=1"
    shift
)

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
if "!CMD_TEXT!"=="" (
    echo Usage: mtmux run [target] [-n] ^<command^>
    exit /b 1
)

:: Ensure session exists
"%TMUX_EXE%" -u has-session >nul 2>&1
if errorlevel 1 (
    "%TMUX_EXE%" -u new-session -d -s main
)

if not "!TARGET!"=="" (
    "%TMUX_EXE%" -u send-keys -t "!TARGET!" -l "!CMD_TEXT!"
    if "!NO_ENTER!"=="0" (
        "%TMUX_EXE%" -u send-keys -t "!TARGET!" Enter
    )
) else (
    "%TMUX_EXE%" -u send-keys -l "!CMD_TEXT!"
    if "!NO_ENTER!"=="0" (
        "%TMUX_EXE%" -u send-keys Enter
    )
)
exit /b 0

:do_capture
set "TARGET=%~2"
set "LINES=50"
if "%~3"=="-n" set "LINES=%~4"
"%TMUX_EXE%" -u capture-pane -p -t "!TARGET!" -S "-!LINES!"
exit /b %ERRORLEVEL%
