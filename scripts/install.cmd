@echo off
REM Install TrialLab into an IDM DEMO folder and register IFEO (needs Admin).
REM Usage:
REM   install.cmd "D:\ProgramFile\Internet Download Manager"
setlocal EnableExtensions EnableDelayedExpansion

set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "PKG=%%~fI"

set "TARGET=%~1"
if not defined TARGET set "TARGET=%IDM_HOME%"
if not defined TARGET (
  echo Usage: install.cmd "C:\Path\To\Internet Download Manager"
  exit /b 2
)
if not exist "%TARGET%\IDMan.exe" (
  echo FAIL: IDMan.exe not found in "%TARGET%"
  exit /b 2
)
if not exist "%PKG%\bin\IdmTrayMenu.exe" (
  echo FAIL: package incomplete: "%PKG%\bin\IdmTrayMenu.exe"
  exit /b 2
)
if not exist "%PKG%\scripts\ifeo_prelaunch.cmd" (
  echo FAIL: package incomplete: "%PKG%\scripts\ifeo_prelaunch.cmd"
  exit /b 2
)

echo PKG=%PKG%
echo TARGET=%TARGET%

echo [0/4] Stop running IDM helpers...
taskkill /F /IM IDMan.exe /IM IDMan_run.exe /IM IdmTrayMenu.exe /IM PopupShield.exe /IM ResetButton.exe /IM TrayReset.exe /IM IDManLauncher.exe >nul 2>&1
ping 127.0.0.1 -n 2 >nul

echo [1/4] Deploy TrialLab...
if exist "%TARGET%\TrialLab\state" (
  if not exist "%TEMP%\idm_tl_state_bak" mkdir "%TEMP%\idm_tl_state_bak" >nul 2>&1
  xcopy "%TARGET%\TrialLab\state\*" "%TEMP%\idm_tl_state_bak\" /E /I /Y >nul 2>&1
)
if exist "%TARGET%\TrialLab" rmdir /S /Q "%TARGET%\TrialLab" >nul 2>&1
mkdir "%TARGET%\TrialLab" >nul 2>&1
mkdir "%TARGET%\TrialLab\bin" >nul 2>&1
mkdir "%TARGET%\TrialLab\scripts" >nul 2>&1
mkdir "%TARGET%\TrialLab\docs" >nul 2>&1
mkdir "%TARGET%\TrialLab\state" >nul 2>&1
xcopy "%PKG%\bin\*.*" "%TARGET%\TrialLab\bin\" /Y >nul
xcopy "%PKG%\scripts\*.*" "%TARGET%\TrialLab\scripts\" /Y >nul
xcopy "%PKG%\docs\*.*" "%TARGET%\TrialLab\docs\" /Y >nul
REM Root stub so old/new IFEO paths both work
copy /Y "%PKG%\scripts\ifeo_prelaunch_root_stub.cmd" "%TARGET%\TrialLab\ifeo_prelaunch.cmd" >nul
if exist "%TEMP%\idm_tl_state_bak" xcopy "%TEMP%\idm_tl_state_bak\*.*" "%TARGET%\TrialLab\state\" /E /I /Y >nul 2>&1

> "%TARGET%\TrialLab\state\popup_shield.enabled" echo 1
> "%TARGET%\TrialLab\state\tray_menu_reset.enabled" echo 1
if not exist "%TARGET%\TrialLab\state\consumed.txt" > "%TARGET%\TrialLab\state\consumed.txt" echo 0

if not exist "%TARGET%\TrialLab\scripts\ifeo_prelaunch.cmd" (
  echo FAIL deploy scripts
  exit /b 3
)
if not exist "%TARGET%\TrialLab\ifeo_prelaunch.cmd" (
  echo FAIL deploy root stub
  exit /b 3
)
if not exist "%TARGET%\TrialLab\bin\IdmTrayMenu.exe" (
  echo FAIL deploy bin
  exit /b 3
)
echo deploy OK

echo [2/4] Ensure hardlink IDMan_run.exe...
if exist "%TARGET%\IDMan_run.exe" del /f /q "%TARGET%\IDMan_run.exe" >nul 2>&1
mklink /H "%TARGET%\IDMan_run.exe" "%TARGET%\IDMan.exe"
if not exist "%TARGET%\IDMan_run.exe" (
  echo FAIL hardlink
  exit /b 3
)

echo [3/4] Register IFEO...
set "PRE=%TARGET%\TrialLab\scripts\ifeo_prelaunch.cmd"
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\IDMan.exe" /v Debugger /t REG_SZ /d "\"%PRE%\"" /f
if errorlevel 1 (
  echo FAIL IFEO write - need Administrator
  exit /b 1
)

echo [4/4] Verify...
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\IDMan.exe" /v Debugger
dir /b "%TARGET%\TrialLab\bin"
dir /b "%TARGET%\TrialLab\scripts\ifeo_prelaunch.cmd"
echo.
echo INSTALL OK
exit /b 0
