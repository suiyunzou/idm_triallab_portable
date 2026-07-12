@echo off
REM Resolve package root from scripts\ or package root.
setlocal EnableExtensions
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"

REM If called as scripts\_env.cmd, root is parent; if somehow at root, use here.
set "ROOT=%HERE%"
if /i "%~nx0"=="_env.cmd" (
  for %%I in ("%HERE%\..") do set "ROOT=%%~fI"
)

REM When deployed under IDM\TrialLab, IDM home is parent of TrialLab root
set "IDM_HOME="
if exist "%ROOT%\..\IDMan.exe" (
  for %%I in ("%ROOT%\..") do set "IDM_HOME=%%~fI"
)

set "BIN=%ROOT%\bin"
set "SCRIPTS=%ROOT%\scripts"
set "STATE=%ROOT%\state"
set "TRIAL_DAYS=30"
set "CONSUMED=%STATE%\consumed.txt"
set "ENDPOINT=%STATE%\endpoint.txt"
set "LOG=%STATE%\silent_reset.log"
if not exist "%STATE%" mkdir "%STATE%" >nul 2>&1

endlocal & (
  set "ROOT=%ROOT%"
  set "IDM_HOME=%IDM_HOME%"
  set "BIN=%BIN%"
  set "SCRIPTS=%SCRIPTS%"
  set "STATE=%STATE%"
  set "TRIAL_DAYS=%TRIAL_DAYS%"
  set "CONSUMED=%CONSUMED%"
  set "ENDPOINT=%ENDPOINT%"
  set "LOG=%LOG%"
)
exit /b 0
