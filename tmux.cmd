@echo off
setlocal
"%~dp0bin\tmux.cmd" %*
exit /b %ERRORLEVEL%
