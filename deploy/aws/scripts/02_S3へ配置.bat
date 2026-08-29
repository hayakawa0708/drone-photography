@echo off
chcp 65001 > nul
cd /d "%~dp0"
set /p BUCKET_NAME=Enter the S3 bucket name: 
if "%BUCKET_NAME%"=="" (
  echo Bucket name is required.
  pause
  exit /b 1
)
set /p DISTRIBUTION_ID=Enter the CloudFront distribution ID: 
set /p INVALIDATE=Create an invalidation now? This may be billable after current allowances. (y/N): 
if /i "%INVALIDATE%"=="y" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -BucketName "%BUCKET_NAME%" -DistributionId "%DISTRIBUTION_ID%" -Invalidate
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -BucketName "%BUCKET_NAME%" -DistributionId "%DISTRIBUTION_ID%"
)
if errorlevel 1 (
  echo Upload failed.
  pause
  exit /b 1
)
echo Upload completed.
pause
