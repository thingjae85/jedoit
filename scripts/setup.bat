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
call flutter create --empty --project-name jeoduit --platforms=android,web .
if errorlevel 1 exit /b 1
call flutter pub get
if errorlevel 1 exit /b 1
call flutter doctor
exit /b %errorlevel%
