@echo off
chcp 65001 > nul
cd /d "%~dp0"

echo.
echo =====================================
echo   Download latest from GitHub
echo =====================================
echo.

if not exist ".git" (
    echo [ERROR] Not a git repository. Run 02 first.
    pause & exit /b 1
)

echo [Local changes]
git status --short
echo.

for /f %%i in ('git status --porcelain') do goto :has_changes
goto :do_pull

:has_changes
echo [WARNING] You have unsaved local changes. They may be overwritten.
set /p CONFIRM="Continue? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo Cancelled.
    pause & exit /b 0
)

:do_pull
git pull origin main
if errorlevel 1 (
    echo [ERROR] Pull failed. Check connection and URL.
    pause & exit /b 1
)

echo.
echo ===================== DONE =====================
pause
