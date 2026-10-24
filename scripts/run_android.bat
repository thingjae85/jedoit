@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0.."
if errorlevel 1 exit /b 1
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Add Flutter bin to PATH and reopen the terminal.
  exit /b 1
)
call flutter devices
if errorlevel 1 exit /b 1
if "%~1"=="" (
  set /p "JEODUIT_DEVICE_ID=Enter Android device ID shown above: "
) else (
  set "JEODUIT_DEVICE_ID=%~1"
)
if not defined JEODUIT_DEVICE_ID exit /b 1
call flutter run -d "%JEODUIT_DEVICE_ID%"
exit /b %errorlevel%
