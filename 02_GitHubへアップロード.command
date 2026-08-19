#!/bin/bash
cd "$(dirname "$0")"

echo ""
echo "====================================="
echo "  GitHub へアップロード"
echo "====================================="
echo ""

if ! command -v git &>/dev/null; then
    echo "[エラー] Git が見つかりません。Gitをインストールしてから再実行してください。"
    read -p "Enterキーで閉じます..."
    exit 1
fi

if [ ! -d ".git" ]; then
    echo "[初回設定] このフォルダをGit管理にします..."
    if ! git init -b main; then
        echo "[エラー] Gitの初期化に失敗しました。"
        read -p "Enterキーで閉じます..."
        exit 1
    fi
fi

GIT_SAFE_OPTION="safe.directory=$PWD"

if ! git -c "$GIT_SAFE_OPTION" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "[エラー] Gitがこのリポジトリを開けません。アップロードを中止します。"
    echo "[詳細]"
    git -c "$GIT_SAFE_OPTION" rev-parse --is-inside-work-tree
    read -p "Enterキーで閉じます..."
    exit 1
fi

if ! git -c "$GIT_SAFE_OPTION" check-ignore -q .env; then
    echo "[警告] .env が .gitignore に含まれていません！アップロードを中止します。"
    read -p "Enterキーで閉じます..."
    exit 1
fi

if ! git -c "$GIT_SAFE_OPTION" remote get-url origin &>/dev/null; then
    echo "[初回設定] 最初のアップロードにはGitHub側のリポジトリが必要です。"
    echo "1. これから開く画面で drone-photography という空のリポジトリを作成してください（このプロジェクトは意図的にPUBLICです）。"
    echo "2. README・.gitignore・ライセンスはGitHub側で追加しないでください。"
    echo "3. 作成後、HTTPS URLをコピーしてここへ貼り付けてください。"
    echo ""
    open "https://github.com/new"

    while true; do
        read -p "リポジトリURL（中止は Q）: " REMOTE_URL
        [ "$REMOTE_URL" = "Q" ] || [ "$REMOTE_URL" = "q" ] && exit 0
        if [ -z "$REMOTE_URL" ]; then
            echo "[エラー] URLは空にできません。"
            continue
        fi
        echo "[確認] URLとGitHubへのログイン状態を確認しています..."
        if git -c "$GIT_SAFE_OPTION" ls-remote "$REMOTE_URL" &>/dev/null; then
            break
        fi
        echo "[エラー] リポジトリを開けません。作成済みか、ログイン済みか確認してください。"
    done

    if ! git -c "$GIT_SAFE_OPTION" remote add origin "$REMOTE_URL"; then
        echo "[エラー] GitHubのURLを保存できませんでした。"
        read -p "Enterキーで閉じます..."
        exit 1
    fi
fi

echo "[変更ファイル]"
if ! git -c "$GIT_SAFE_OPTION" status --short; then
    echo "[エラー] Gitの状態を確認できませんでした。"
    read -p "Enterキーで閉じます..."
    exit 1
fi
echo ""

if ! git -c "$GIT_SAFE_OPTION" add .; then
    echo "[エラー] アップロードするファイルを準備できませんでした。"
    read -p "Enterキーで閉じます..."
    exit 1
fi

if git -c "$GIT_SAFE_OPTION" diff --cached --name-only | grep -Eiq '(^|/)\.env$|credentials\.json$|_token\.json$|\.key$|api_key\.txt$|auth_config\.yaml$'; then
    echo "[安全停止] 秘密ファイルがアップロード対象に含まれています。"
    echo ".gitignoreを確認し、Gitの対象から外してから再実行してください。"
    read -p "Enterキーで閉じます..."
    exit 1
fi

if ! git -c "$GIT_SAFE_OPTION" diff --cached --quiet; then
    read -p "コミットメッセージ（空でEnter）: " MSG
    if [ -z "$MSG" ]; then
        if git -c "$GIT_SAFE_OPTION" rev-parse --verify HEAD &>/dev/null; then
            MSG="update"
        else
            MSG="initial commit"
        fi
    fi
    if ! git -c "$GIT_SAFE_OPTION" commit -m "$MSG"; then
        echo "[エラー] コミットに失敗しました。上のメッセージを確認してください。"
        read -p "Enterキーで閉じます..."
        exit 1
    fi
elif ! git -c "$GIT_SAFE_OPTION" rev-parse --verify HEAD &>/dev/null; then
    echo "[エラー] 最初のコミットに入れるファイルがありません。"
    read -p "Enterキーで閉じます..."
    exit 1
else
    echo "[スキップ] コミットする変更はありません。"
fi

BRANCH=$(git -c "$GIT_SAFE_OPTION" branch --show-current)
if [ -z "$BRANCH" ]; then
    echo "[エラー] 現在のGitブランチを確認できませんでした。"
    read -p "Enterキーで閉じます..."
    exit 1
fi

if ! git -c "$GIT_SAFE_OPTION" push -u origin "$BRANCH"; then
    echo "[エラー] アップロードに失敗しました。"
    echo "GitHubのURL、ログイン状態、アクセス権限を確認してください。"
    read -p "Enterキーで閉じます..."
    exit 1
fi

echo ""
echo "===================================== 完了 ====================================="
read -p "Enterキーで閉じます..."
