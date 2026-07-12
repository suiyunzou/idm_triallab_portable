@echo off
REM Rebuild bin\*.exe from src\ using .NET Framework csc (no Visual Studio required).
setlocal EnableExtensions
set "PKG=%~dp0.."
for %%I in ("%PKG%") do set "PKG=%%~fI"
set "CSC="
if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC (
  echo FAIL: csc.exe not found
  exit /b 2
)
if not exist "%PKG%\bin" mkdir "%PKG%\bin"

echo Building IdmTrayMenu.exe ...
"%CSC%" /nologo /optimize+ /target:winexe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /out:"%PKG%\bin\IdmTrayMenu.exe" "%PKG%\src\IdmTrayMenu.cs"
if errorlevel 1 exit /b 1

echo Building PopupShield.exe ...
"%CSC%" /nologo /optimize+ /target:winexe /out:"%PKG%\bin\PopupShield.exe" "%PKG%\src\PopupShield.cs"
if errorlevel 1 exit /b 1

echo Building PopupProbe.exe ...
"%CSC%" /nologo /optimize+ /target:winexe /out:"%PKG%\bin\PopupProbe.exe" "%PKG%\src\PopupProbe.cs"
if errorlevel 1 exit /b 1

echo Building ClickReset.exe ...
"%CSC%" /nologo /optimize+ /out:"%PKG%\bin\ClickReset.exe" "%PKG%\src\ClickReset.cs"
if errorlevel 1 exit /b 1

echo BUILD OK
dir /b "%PKG%\bin\*.exe"
exit /b 0
