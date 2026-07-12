@echo off
REM Ask for UAC, then install into IDM folder.
setlocal EnableExtensions
set "HERE=%~dp0"
set "TARGET=%~1"
if not defined TARGET set "TARGET=%IDM_HOME%"
if not defined TARGET (
  echo Drag-drop an IDM folder onto this script, or:
  echo   request_install.cmd "C:\Path\To\Internet Download Manager"
  exit /b 2
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%HERE%install.cmd\" \"%TARGET%\" & pause\"' -Verb RunAs -Wait"
exit /b %ERRORLEVEL%
