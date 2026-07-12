@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "SCR=%~dp0"
if "%SCR:~-1%"=="\" set "SCR=%SCR:~0,-1%"
for %%I in ("%SCR%\..") do set "TL=%%~fI"
set "STATE=%TL%\state"
set "CONSUMED=%STATE%\consumed.txt"
set "ENDPOINT=%STATE%\endpoint.txt"
set "TRIAL_DAYS=30"
if not exist "%STATE%" mkdir "%STATE%" >nul 2>&1
if not exist "%ENDPOINT%" (> "%ENDPOINT%" echo official)
set /p EP=<"%ENDPOINT%"
set "EP=!EP: =!"
if /i "!EP!"=="private" (
  > "%CONSUMED%" echo 0
  set "LEFT=%TRIAL_DAYS%"
  set "ISSUER=private"
  goto :out
)
if not exist "%CONSUMED%" (> "%CONSUMED%" echo 0)
set /p USED=<"%CONSUMED%"
set "USED=!USED: =!"
if not defined USED set "USED=0"
set /a LEFT=%TRIAL_DAYS%-USED
if !LEFT! LSS 0 set "LEFT=0"
set "ISSUER=local-file"
:out
set "MARK=NOT_FULL"
if !LEFT! GEQ %TRIAL_DAYS% set "MARK=RESET_OK"
set "FLAG=ACTIVE"
if !LEFT! LEQ 0 set "FLAG=EXPIRED"
echo [!ISSUER!] days_left=!LEFT! status=!FLAG! !MARK! endpoint=!EP!
exit /b 0
