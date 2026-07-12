@echo off
setlocal EnableExtensions
set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "PKG=%%~fI"
for %%I in ("%PKG%\..") do set "IDM_HOME=%%~fI"

echo [1/2] Remove IFEO...
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\IDMan.exe" /f >nul 2>&1

if exist "%IDM_HOME%\IDMan_run.exe" (
  echo [2/2] Remove hardlink...
  del /f /q "%IDM_HOME%\IDMan_run.exe" >nul 2>&1
)

echo TEARDOWN OK
echo �������ļ����Ա�����: %PKG%
exit /b 0
