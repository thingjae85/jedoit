@echo off
setlocal
cd /d "%~dp0"
if not exist web\index.html (
  call scripts\setup.bat
  if errorlevel 1 goto failed
)
call scripts\run_web.bat
if errorlevel 1 goto failed
exit /b 0
:failed
echo.
echo Could not start. See the error above and README.md.
pause
exit /b 1
