@echo off
REM Compatibility stub: forward to scripts\ifeo_prelaunch.cmd
call "%~dp0scripts\ifeo_prelaunch.cmd" %*
exit /b %ERRORLEVEL%
