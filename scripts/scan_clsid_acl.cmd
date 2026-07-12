@echo off
REM Non-elevated quick scan. Exit 0=clean, 2=locks found, 1=error.
setlocal EnableExtensions
set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "PKG=%%~fI"
set "STATE=%PKG%\state"
if not exist "%STATE%" mkdir "%STATE%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCR%\unlock_clsid_acl.ps1" -ScanOnly -LogPath "%STATE%\clsid_acl.log"
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" (
  echo PASS CLSID-ACL clean
  exit /b 0
)
if "%RC%"=="2" (
  echo FAIL CLSID-ACL lock residue detected
  echo Fix: run INSTALL.cmd ^(includes unlock^) or:
  echo   powershell -File "%SCR%\unlock_clsid_acl.ps1"
  exit /b 2
)
echo FAIL CLSID-ACL scan error rc=%RC%
exit /b 1
