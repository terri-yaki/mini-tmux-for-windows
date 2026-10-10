@echo off
setlocal

:: Resolve MiniTmux root directory
set "MINITMUX_ROOT=%~dp0.."
for %%i in ("%MINITMUX_ROOT%") do set "MINITMUX_ROOT=%%~fi"

:: Ensure socket directory exists (tmux requires tmp to create socket subdirectory)
if not exist "%MINITMUX_ROOT%\tmp" (
    mkdir "%MINITMUX_ROOT%\tmp" >nul 2>&1
)

:: Prevent MSYS runtime from stripping #{format} braces on Windows command lines
:: and enable optimized POSIX process spawning and symlink handling
set "MSYS=noglob disable_pcon winsymlinks:nativestrict"

:: Ensure UTF-8 locale and code page for console output and CJK/Unicode
set "LANG=en_US.UTF-8"
set "LC_ALL=en_US.UTF-8"
chcp 65001 >nul 2>&1

:: Pass through all arguments to bundled tmux.exe with UTF-8 flag
"%MINITMUX_ROOT%\usr\bin\tmux.exe" -u %*
set "_EXIT_CODE=%ERRORLEVEL%"

exit /b %_EXIT_CODE%
