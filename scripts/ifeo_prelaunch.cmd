@echo off
REM IFEO target. Paths from this script only. Never touch IDM trial registry / CLSID ACL.
setlocal EnableExtensions EnableDelayedExpansion

set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "PKG=%%~fI"
set "BIN=%PKG%\bin"
set "STATE=%PKG%\state"
if not exist "%STATE%" mkdir "%STATE%" >nul 2>&1

set "REAL=%~1"
if not defined REAL (
  for %%I in ("%PKG%\..") do set "REAL=%%~fI\IDMan.exe"
)
if not exist "%REAL%" (
  echo FAIL: IDMan.exe not found
  exit /b 2
)
shift

for %%I in ("%REAL%") do set "IDM_HOME=%%~dpI"
if "%IDM_HOME:~-1%"=="\" set "IDM_HOME=%IDM_HOME:~0,-1%"

REM Lab contract only: file-backed consumed counter. Do NOT edit LstCheck/CLSID/ACL.
> "%STATE%\consumed.txt" echo 0
>> "%STATE%\silent_reset.log" echo %DATE% %TIME% RESET_OK consumed=0 days_left=30 via=ifeo_prelaunch

set "RUN=%IDM_HOME%\IDMan_run.exe"
if not exist "%RUN%" mklink /H "%RUN%" "%REAL%" >nul 2>&1
if not exist "%RUN%" (
  echo FAIL hardlink
  exit /b 3
)

start "" /D "%IDM_HOME%" "%RUN%" %1 %2 %3 %4 %5 %6 %7 %8 %9
ping 127.0.0.1 -n 2 >nul

set "PID="
for /f "tokens=2 delims=," %%P in ('tasklist /FI "IMAGENAME eq IDMan_run.exe" /FO CSV /NH 2^>nul') do (
  set "PID=%%~P"
  goto :havepid
)
:havepid

if exist "%STATE%\popup_shield.enabled" if exist "%BIN%\PopupShield.exe" (
  if defined PID (start "" /B "%BIN%\PopupShield.exe" !PID!) else (start "" /B "%BIN%\PopupShield.exe" 0)
)

if not exist "%STATE%\tray_menu_reset.enabled" > "%STATE%\tray_menu_reset.enabled" echo 1
if exist "%STATE%\tray_menu_reset.enabled" if exist "%BIN%\IdmTrayMenu.exe" (
  if defined PID (start "" "%BIN%\IdmTrayMenu.exe" !PID!) else (start "" "%BIN%\IdmTrayMenu.exe" 0)
)

exit /b 0
