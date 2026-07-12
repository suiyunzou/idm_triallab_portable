@echo off
REM Fix outdated scripts\selftest.cmd to sibling-package layout.
setlocal EnableExtensions
cd /d "%~dp0.."
call "%~dp0..\SELFTEST.cmd" %*
exit /b %ERRORLEVEL%
