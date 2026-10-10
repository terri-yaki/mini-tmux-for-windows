@echo off
setlocal

:: Resolve MiniTmux root
set "MINITMUX_ROOT=%~dp0.."
for %%i in ("%MINITMUX_ROOT%") do set "MINITMUX_ROOT=%%~fi"

:: Call powershell script with execution policy bypass and all arguments forwarded
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MINITMUX_ROOT%\bin\mtmux.ps1" %*
set "_EXIT_CODE=%ERRORLEVEL%"

exit /b %_EXIT_CODE%
