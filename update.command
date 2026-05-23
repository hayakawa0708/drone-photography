#!/bin/bash
# ドローン飛行条件チェッカー アップデータ (macOS)
# 使い方: 右クリック → 開く（初回のみ）、以降はダブルクリック

REPO_USER="hayakawa0708"
REPO_NAME="drone-photography"
BRANCH="main"
FILE="drone_checker.html"
RAW_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}/${FILE}"
DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${DIR}/${FILE}"
BACKUP="${DIR}/${FILE}.bak"

echo ""
echo "============================================"
echo " ドローン飛行条件チェッカー アップデーター"
echo " GitHub: ${REPO_USER}/${REPO_NAME}"
echo "============================================"
echo ""

# Step 1: バックアップ
echo "[1/4] 現在のファイルをバックアップ中..."
if [ -f "$TARGET" ]; then
    cp "$TARGET" "$BACKUP"
    echo "      バックアップ完了: ${FILE}.bak"
else
    echo "      既存ファイルなし。新規ダウンロードします。"
fi

# Step 2: ダウンロード
echo "[2/4] GitHubから最新版をダウンロード中..."
if ! curl -fsSL "$RAW_URL" -o "$TARGET"; then
    echo ""
    echo "[エラー] ダウンロードに失敗しました。"
    echo "インターネット接続を確認してください。"
    if [ -f "$BACKUP" ]; then
        echo "バックアップから復元します..."
        cp "$BACKUP" "$TARGET"
    fi
    read -p "Enterキーで終了..."
    exit 1
fi

# Step 3: ファイルサイズ確認
echo "[3/4] ファイルサイズを確認中..."
SIZE=$(wc -c < "$TARGET" | tr -d ' ')
echo "      ファイルサイズ: ${SIZE} bytes"
if [ "$SIZE" -lt 10000 ]; then
    echo "[エラー] ファイルが小さすぎます。ダウンロードが不完全な可能性があります。"
    if [ -f "$BACKUP" ]; then
        echo "バックアップから復元します..."
        cp "$BACKUP" "$TARGET"
    fi
    read -p "Enterキーで終了..."
    exit 1
fi

# Step 4: ブラウザで起動
echo "[4/4] ブラウザで起動中..."
open "$TARGET"

echo ""
echo "============================================"
echo " アップデート完了！"
echo " 旧バージョン: ${FILE}.bak に保存済み"
echo "============================================"
echo ""
sleep 3
