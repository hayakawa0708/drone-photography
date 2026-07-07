#!/bin/bash
# ドローン飛行条件チェッカー — macOS デプロイスクリプト
# 使い方: 右クリック→開く（初回）、以降はダブルクリック

DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "Pythonのインストールを確認中..."

if command -v python3 &>/dev/null; then
    echo "Python3 が見つかりました。"
    python3 "$DIR/deploy.py"
elif command -v python &>/dev/null; then
    echo "Python が見つかりました。"
    python "$DIR/deploy.py"
else
    echo ""
    echo "[エラー] Python がインストールされていません。"
    echo ""
    echo "インストール方法:"
    echo "  1. https://www.python.org/downloads/ からダウンロード"
    echo "  または: brew install python3"
    echo ""
    read -p "Enterキーで終了..."
fi
