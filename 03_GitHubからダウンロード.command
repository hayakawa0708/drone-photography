#!/bin/bash
cd "$(dirname "$0")"

echo ""
echo "====================================="
echo "  GitHub から最新版をダウンロード"
echo "====================================="
echo ""

if [ -n "$(git status --porcelain)" ]; then
    echo "[警告] 未保存の変更があります。上書きされる可能性があります。"
    read -p "続行しますか？ (y/N): " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && echo "キャンセル" && exit 0
fi

git pull origin main
echo ""
echo "===================================== 完了 ====================================="
read -p "Enterキーで閉じます..."
