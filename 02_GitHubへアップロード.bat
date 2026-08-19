@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 > nul
cd /d "%~dp0"

echo.
echo =====================================
echo   Upload to GitHub (backup)
echo =====================================
echo.

where git > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is not installed or is not available in PATH.
    pause & exit /b 1
)

if not exist ".git" (
    echo [FIRST SETUP] Initializing this folder as a Git repository...
    git init -b main
    if errorlevel 1 (
        echo [ERROR] Git initialization failed.
        pause & exit /b 1
    )
)

set "GIT_SAFE_OPTION=safe.directory=%CD%"

git -c "%GIT_SAFE_OPTION%" rev-parse --is-inside-work-tree > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git cannot open this repository. Upload aborted.
    echo [DETAILS]
    git -c "%GIT_SAFE_OPTION%" rev-parse --is-inside-work-tree
    pause & exit /b 1
)

git -c "%GIT_SAFE_OPTION%" check-ignore -q .env
if errorlevel 1 (
    echo [WARNING] .env is NOT ignored by .gitignore! Upload aborted.
    pause & exit /b 1
)

git -c "%GIT_SAFE_OPTION%" remote get-url origin > nul 2>&1
if not errorlevel 1 goto :remote_ok

echo [FIRST SETUP] A GitHub repository is required before the first upload.
echo 1. The GitHub new-repository page will open.
echo 2. Create an EMPTY repository named drone-photography (this project is intentionally PUBLIC).
echo 3. Do not add a README, .gitignore, or license on GitHub.
echo 4. Copy the HTTPS repository URL and paste it below.
echo.
start "" "https://github.com/new"

:ask_remote
set "REMOTE_URL="
set /p "REMOTE_URL=Repository URL (Q to cancel): "
if /i "%REMOTE_URL%"=="Q" exit /b 0
if not defined REMOTE_URL (
    echo [ERROR] Repository URL cannot be empty.
    goto :ask_remote
)

echo [CHECK] Confirming the repository URL and GitHub sign-in...
git -c "%GIT_SAFE_OPTION%" ls-remote "%REMOTE_URL%" > nul 2>&1
if errorlevel 1 (
    echo [ERROR] The repository could not be opened.
    echo Confirm that it exists, is empty, and that GitHub sign-in completed.
    goto :ask_remote
)

git -c "%GIT_SAFE_OPTION%" remote add origin "%REMOTE_URL%"
if errorlevel 1 (
    echo [ERROR] The GitHub repository URL could not be saved.
    pause & exit /b 1
)

:remote_ok
echo [Changed files]
git -c "%GIT_SAFE_OPTION%" status --short
if errorlevel 1 (
    echo [ERROR] Git status failed. Upload aborted.
    pause & exit /b 1
)
echo.

git -c "%GIT_SAFE_OPTION%" add .
if errorlevel 1 (
    echo [ERROR] Files could not be prepared for upload.
    pause & exit /b 1
)

git -c "%GIT_SAFE_OPTION%" diff --cached --name-only | findstr /i /r /c:"^\.env$" /c:"credentials\.json$" /c:"_token\.json$" /c:"\.key$" /c:"api_key\.txt$" /c:"auth_config\.yaml$" > nul
if not errorlevel 1 (
    echo [SECURITY] A secret file is selected for upload. Upload aborted.
    echo Remove it from Git and check .gitignore before trying again.
    pause & exit /b 1
)

git -c "%GIT_SAFE_OPTION%" diff --cached --quiet
if not errorlevel 1 goto :no_changes

set "MSG="
set /p "MSG=Commit message (Enter for 'initial commit' or 'update'): "
if defined MSG goto :commit
git -c "%GIT_SAFE_OPTION%" rev-parse --verify HEAD > nul 2>&1
if errorlevel 1 goto :default_initial_message
set "MSG=update"
goto :commit

:default_initial_message
set "MSG=initial commit"

:commit
git -c "%GIT_SAFE_OPTION%" commit -m "%MSG%"
if errorlevel 1 (
    echo [ERROR] Commit failed. Check the message above.
    pause & exit /b 1
)
goto :push

:no_changes
git -c "%GIT_SAFE_OPTION%" rev-parse --verify HEAD > nul 2>&1
if errorlevel 1 (
    echo [ERROR] There are no files available for the first commit.
    pause & exit /b 1
)
echo [SKIP] No changes to commit.

:push
set "BRANCH="
for /f "delims=" %%B in ('git -c "%GIT_SAFE_OPTION%" branch --show-current') do set "BRANCH=%%B"
if not defined BRANCH (
    echo [ERROR] The current Git branch could not be detected.
    pause & exit /b 1
)

echo.
git -c "%GIT_SAFE_OPTION%" push -u origin "%BRANCH%"
if errorlevel 1 (
    echo [ERROR] Upload failed.
    echo Confirm the GitHub repository URL, sign-in, and access permission.
    pause & exit /b 1
)

echo.
echo ===================== DONE =====================
pause
endlocal
