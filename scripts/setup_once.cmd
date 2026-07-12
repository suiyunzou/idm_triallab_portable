@echo off
REM Called elevated by INSTALL.cmd. Uses only paths derived from this package location.
setlocal EnableExtensions EnableDelayedExpansion

set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "PKG=%%~fI"
for %%I in ("%PKG%\..") do set "IDM_HOME=%%~fI"

echo PKG=%PKG%
echo IDM_HOME=%IDM_HOME%

if not exist "%IDM_HOME%\IDMan.exe" (
  echo FAIL: IDMan.exe missing
  exit /b 2
)
if not exist "%PKG%\scripts\ifeo_prelaunch.cmd" (
  echo FAIL: package incomplete
  exit /b 2
)
if not exist "%PKG%\bin\IdmTrayMenu.exe" (
  echo FAIL: missing bin\IdmTrayMenu.exe - run scripts\build.cmd first
  exit /b 2
)

echo [1/5] Stop helpers...
taskkill /F /IM IDMan.exe /IM IDMan_run.exe /IM IdmTrayMenu.exe /IM PopupShield.exe /IM ResetButton.exe /IM TrayReset.exe /IM IDManLauncher.exe >nul 2>&1
ping 127.0.0.1 -n 2 >nul

echo [2/5] Unlock CLSID ACL residue ^(blue-team fingerprint^)...
if not exist "%PKG%\state" mkdir "%PKG%\state" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%PKG%\scripts\unlock_clsid_acl.ps1" -LogPath "%PKG%\state\clsid_acl.log"
if errorlevel 1 (
  echo FAIL: CLSID ACL unlock incomplete - see state\clsid_acl.log
  exit /b 4
)

echo [3/5] Init state flags...
> "%PKG%\state\popup_shield.enabled" echo 1
> "%PKG%\state\tray_menu_reset.enabled" echo 1
if not exist "%PKG%\state\consumed.txt" > "%PKG%\state\consumed.txt" echo 0

REM Compatibility stub at package root (optional old IFEO targets)
copy /Y "%PKG%\scripts\ifeo_prelaunch_root_stub.cmd" "%PKG%\ifeo_prelaunch.cmd" >nul

echo [4/5] Hardlink IDMan_run.exe (same folder as IDMan.exe)...
if exist "%IDM_HOME%\IDMan_run.exe" del /f /q "%IDM_HOME%\IDMan_run.exe" >nul 2>&1
mklink /H "%IDM_HOME%\IDMan_run.exe" "%IDM_HOME%\IDMan.exe"
if not exist "%IDM_HOME%\IDMan_run.exe" (
  echo FAIL hardlink
  exit /b 3
)

echo [5/5] Register IFEO Debugger (lifetime)...
set "PRE=%PKG%\scripts\ifeo_prelaunch.cmd"
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\IDMan.exe" /v Debugger /t REG_SZ /d "\"%PRE%\"" /f
if errorlevel 1 (
  echo FAIL IFEO write
  exit /b 1
)

reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\IDMan.exe" /v Debugger
echo.
echo SETUP_ONCE OK
exit /b 0
