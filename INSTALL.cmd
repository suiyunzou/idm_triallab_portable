@echo off
REM One-time setup. Place this whole folder next to IDMan.exe, then run INSTALL.cmd
REM No path arguments. UAC once. Lifetime: just open IDMan.exe.
setlocal EnableExtensions
cd /d "%~dp0"

set "PKG=%~dp0"
if "%PKG:~-1%"=="\" set "PKG=%PKG:~0,-1%"
for %%I in ("%PKG%\..") do set "IDM_HOME=%%~fI"

if not exist "%IDM_HOME%\IDMan.exe" (
  echo.
  echo [ERROR] IDMan.exe not found in parent folder.
  echo Place this package next to IDMan.exe, e.g.:
  echo   ...\Internet Download Manager\IDMan.exe
  echo   ...\Internet Download Manager\%~nx0\
  echo.
  echo Parent resolved as: "%IDM_HOME%"
  pause
  exit /b 2
)

echo ============================================
echo TrialLab one-shot install (sibling mode)
echo IDM_HOME = %IDM_HOME%
echo PKG      = %PKG%
echo ============================================
echo Steps: unlock CLSID ACL -^> hardlink -^> IFEO
echo UAC: click OK / 确定
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%PKG%\scripts\setup_once.cmd\" & echo. & pause\"' -Verb RunAs -Wait"

echo.
echo Done. Open IDMan.exe normally afterwards.
echo Optional: SELFTEST.cmd
echo.
pause
exit /b 0
