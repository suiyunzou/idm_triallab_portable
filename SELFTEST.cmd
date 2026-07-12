@echo off
REM Zero-arg selftest. Package must sit next to IDMan.exe.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "PKG=%~dp0"
if "%PKG:~-1%"=="\" set "PKG=%PKG:~0,-1%"
for %%I in ("%PKG%\..") do set "IDM_HOME=%%~fI"
set "STATE=%PKG%\state"
set "BIN=%PKG%\bin"
set "SCRIPTS=%PKG%\scripts"

echo ============================================
echo TrialLab SELFTEST (sibling-folder mode)
echo IDM_HOME=%IDM_HOME%
echo PKG=%PKG%
echo ============================================

if not exist "%IDM_HOME%\IDMan.exe" (
  echo FAIL: place this folder next to IDMan.exe
  exit /b 2
)

echo --- ACL hygiene ---
call "%SCRIPTS%\scan_clsid_acl.cmd"
if errorlevel 1 (
  echo FAIL CLSID-ACL
  exit /b 1
)

reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\IDMan.exe" /v Debugger | findstr /i "ifeo_prelaunch.cmd" >nul
if errorlevel 1 (
  echo FAIL: not installed - run INSTALL.cmd first
  exit /b 2
)
echo PASS IFEO

if not exist "%IDM_HOME%\IDMan_run.exe" (
  echo FAIL: missing IDMan_run.exe - run INSTALL.cmd
  exit /b 1
)
echo PASS HARDLINK

if exist "%IDM_HOME%\IDMan.core.exe" (
  echo FAIL: IDMan.core.exe must not exist
  exit /b 1
)
echo PASS NOCORE

call "%SCRIPTS%\age.cmd" 28 >nul
call "%SCRIPTS%\check.cmd" > "%TEMP%\tl_before.txt"
findstr /i "days_left=2" "%TEMP%\tl_before.txt" >nul
if errorlevel 1 (
  echo FAIL age
  type "%TEMP%\tl_before.txt"
  exit /b 1
)

taskkill /F /IM IDMan.exe /IM IDMan_run.exe /IM IdmTrayMenu.exe /IM PopupShield.exe /IM ResetButton.exe /IM TrayReset.exe >nul 2>&1
start "" "%IDM_HOME%\IDMan.exe"
ping 127.0.0.1 -n 4 >nul

call "%SCRIPTS%\check.cmd" > "%TEMP%\tl_after.txt"
type "%TEMP%\tl_after.txt"
findstr /i "days_left=30" "%TEMP%\tl_after.txt" >nul
if errorlevel 1 (
  echo FAIL open auto-reset
  exit /b 1
)
echo PASS OPEN-RESET

tasklist /FI "IMAGENAME eq IDMan_run.exe" | findstr /i "IDMan_run.exe" >nul
if errorlevel 1 (
  echo FAIL process
  exit /b 1
)
echo PASS PROC

tasklist /FI "IMAGENAME eq IdmTrayMenu.exe" | findstr /i "IdmTrayMenu.exe" >nul
if errorlevel 1 (
  echo FAIL tray menu hook
  exit /b 1
)
echo PASS TRAY-MENU-HOOK

tasklist /FI "IMAGENAME eq ResetButton.exe" | findstr /i "ResetButton.exe" >nul
if not errorlevel 1 (
  echo FAIL floating button should not run
  exit /b 1
)
echo PASS NO-FLOAT

taskkill /F /IM IDMan.exe /IM IDMan_run.exe /IM IdmTrayMenu.exe /IM PopupShield.exe >nul 2>&1

echo.
echo ALL SELFTESTS PASSED
echo Manual: tray right-click should show item "reset"
echo Manual: must NOT see "registry keys had been damaged"
exit /b 0
