@echo off
setlocal
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=csc.exe"

"%CSC%" /nologo /optimize+ /platform:x64 /target:exe /out:"%~dp0..\usr\bin\winpaste.exe" "%~dp0winpaste.cs"
copy /y "%~dp0..\usr\bin\winpaste.exe" "%~dp0..\bin\winpaste.exe" >nul
echo Built winpaste.exe successfully.
