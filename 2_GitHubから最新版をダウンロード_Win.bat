@echo off
chcp 932 > nul
setlocal

set "REPO_USER=hayakawa0708"
set "REPO_NAME=drone-photography"
set "BRANCH=main"
set "FILE=drone_checker.html"
set "RAW_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/%FILE%"
set "TARGET=%~dp0%FILE%"
set "BACKUP=%~dp0%FILE%.bak"

echo.
echo  ============================================
echo   ドローン飛行条件チェッカー アップデーター
echo   GitHub: %REPO_USER%/%REPO_NAME%
echo  ============================================
echo.

echo  [1/4] 現在のファイルをバックアップ中...
if exist "%TARGET%" (
    copy /Y "%TARGET%" "%BACKUP%" > nul
    echo        バックアップ完了: %FILE%.bak
) else (
    echo        既存ファイルなし。新規ダウンロードします。
)

echo  [2/4] GitHubから最新版をダウンロード中...
powershell -Command "& { try { Invoke-WebRequest -Uri '%RAW_URL%' -OutFile '%TARGET%' -UseBasicParsing -ErrorAction Stop; Write-Host '       ダウンロード完了' } catch { Write-Host ('       エラー: ' + $_.Exception.Message); exit 1 } }"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  [エラー] ダウンロードに失敗しました。
    echo  インターネット接続を確認してください。
    if exist "%BACKUP%" (
        echo  バックアップから復元します...
        copy /Y "%BACKUP%" "%TARGET%" > nul
    )
    pause
    exit /b 1
)

echo  [3/4] ファイルサイズを確認中...
for %%A in ("%TARGET%") do (
    if %%~zA LSS 10000 (
        echo  [エラー] ファイルが小さすぎます。ダウンロードが不完全な可能性があります。
        if exist "%BACKUP%" (
            echo  バックアップから復元します...
            copy /Y "%BACKUP%" "%TARGET%" > nul
        )
        pause
        exit /b 1
    )
    echo        ファイルサイズ: %%~zA bytes
)

echo  [4/4] ブラウザで起動中...
start "" "%TARGET%"

echo.
echo  ============================================
echo   アップデート完了！
echo   旧バージョン: %FILE%.bak に保存済み
echo  ============================================
echo.
timeout /t 3 /nobreak > nul
exit /b 0
