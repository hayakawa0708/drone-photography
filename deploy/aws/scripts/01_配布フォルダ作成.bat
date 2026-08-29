@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo Creating and verifying the drone release directory...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1"
if errorlevel 1 (
  echo Release directory creation failed.
  pause
  exit /b 1
)
echo Release directory creation completed.
pause
