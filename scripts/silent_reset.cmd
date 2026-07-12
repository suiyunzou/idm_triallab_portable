@echo off
REM Silent reset using paths relative to this scripts folder.
setlocal EnableExtensions
set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "TL=%%~fI"
set "STATE=%TL%\state"
if not exist "%STATE%" mkdir "%STATE%" >nul 2>&1
> "%STATE%\consumed.txt" echo 0
>> "%STATE%\silent_reset.log" echo %DATE% %TIME% RESET_OK consumed=0 days_left=30 via=silent_reset
set /p V=<"%STATE%\consumed.txt"
set "V=%V: =%"
if not "%V%"=="0" exit /b 1
exit /b 0
