@echo off
REM Zero-arg uninstall. Package must sit next to IDMan.exe.
setlocal EnableExtensions
cd /d "%~dp0"
set "PKG=%~dp0"
if "%PKG:~-1%"=="\" set "PKG=%PKG:~0,-1%"
for %%I in ("%PKG%\..") do set "IDM_HOME=%%~fI"

echo ��ж�� IFEO����ɾ�� IDMan_run.exe Ӳ����
echo IDM_HOME=%IDM_HOME%
echo ��ѡ: UNINSTALL.cmd /purge  ͬʱ��ɾ���ļ��У�����ҹ���
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%PKG%\scripts\teardown_once.cmd\" %1 & echo. & pause\"' -Verb RunAs -Wait"
exit /b %ERRORLEVEL%
