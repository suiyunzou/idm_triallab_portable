@echo off
setlocal EnableExtensions
set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "TL=%%~fI"
set "STATE=%TL%\state"
if not exist "%STATE%" mkdir "%STATE%" >nul 2>&1
set "N=%~1"
if not defined N set "N=20"
> "%STATE%\consumed.txt" echo %N%
exit /b 0
