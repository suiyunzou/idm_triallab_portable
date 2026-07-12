@echo off
REM Uninstall IFEO + optional remove TrialLab from IDM folder.
REM Usage:
REM   uninstall.cmd
REM   uninstall.cmd "D:\ProgramFile\Internet Download Manager"
setlocal EnableExtensions
set "TARGET=%~1"
if not defined TARGET set "TARGET=%IDM_HOME%"

echo [1/3] Remove IFEO...
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\IDMan.exe" /f >nul 2>&1
echo IFEO removed (or was absent)

if defined TARGET if exist "%TARGET%\IDMan_run.exe" (
  echo [2/3] Remove hardlink IDMan_run.exe...
  del /f /q "%TARGET%\IDMan_run.exe" >nul 2>&1
)

if /i "%~2"=="/purge" if defined TARGET if exist "%TARGET%\TrialLab" (
  echo [3/3] Purge TrialLab folder...
  rmdir /S /Q "%TARGET%\TrialLab" >nul 2>&1
) else (
  echo [3/3] Keep TrialLab files (pass /purge to delete)
)

echo UNINSTALL OK
exit /b 0
