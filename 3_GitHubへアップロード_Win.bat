@echo off
chcp 932 > nul
setlocal

echo.
echo  Pythonのインストールを確認中...

python --version > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo  Python が見つかりました。
    python "%~dp0deploy.py"
    goto END
)

python3 --version > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo  Python3 が見つかりました。
    python3 "%~dp0deploy.py"
    goto END
)

echo.
echo  [エラー] Python がインストールされていません。
echo.
echo  インストール方法:
echo    1. https://www.python.org/downloads/ からダウンロード
echo    2. インストール時に "Add Python to PATH" にチェック
echo    3. インストール後にこのファイルを再実行
echo.
pause

:END
