@echo off
setlocal
"%~dp0bin\mtmux.cmd" %*
exit /b %ERRORLEVEL%
