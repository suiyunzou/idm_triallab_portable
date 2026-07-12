@echo off
REM Ask for UAC, then uninstall.
setlocal EnableExtensions
set "HERE=%~dp0"
set "TARGET=%~1"
if not defined TARGET set "TARGET=%IDM_HOME%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%HERE%uninstall.cmd\" \"%TARGET%\" %2 & pause\"' -Verb RunAs -Wait"
exit /b %ERRORLEVEL%
