#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
deploy.py — ドローン飛行条件チェッカー GitHubデプロイスクリプト
使い方:
  Windows: deploy.bat をダブルクリック（このファイルを直接実行してもOK）
  macOS:   deploy.command をダブルクリック / python3 deploy.py
"""

import subprocess
import sys
import os
import json
import re
from pathlib import Path
from datetime import datetime

# ============================================================
# 設定
# ============================================================
GITHUB_USER   = "hayakawa0708"
GITHUB_REPO   = "drone-photography"
GITHUB_BRANCH = "main"

# デプロイ対象ファイル（リポジトリルートに置くもの）
DEPLOY_FILES = [
    "drone_checker.html",
    "CHANGELOG.md",
    "README.md",
    "launch.bat",
    "launch.command",
    "update.bat",
    "update.command",
    "deploy.py",
    "deploy.bat",
    "deploy.command",
    ".gitignore",
]

# ============================================================
# ユーティリティ
# ============================================================
def print_step(n, total, msg):
    print(f"\n  [{n}/{total}] {msg}")

def print_ok(msg):
    print(f"        ✓ {msg}")

def print_warn(msg):
    print(f"        ⚠ {msg}")

def print_err(msg):
    print(f"        ✕ {msg}")

def run(cmd, cwd=None, capture=False):
    """コマンドを実行。失敗時は例外を投げる。"""
    result = subprocess.run(
        cmd, cwd=cwd, shell=True,
        capture_output=capture, text=True, encoding="utf-8", errors="replace"
    )
    return result

def run_or_die(cmd, cwd=None, error_msg="コマンド実行に失敗しました"):
    result = run(cmd, cwd=cwd, capture=True)
    if result.returncode != 0:
        print_err(error_msg)
        print(f"        詳細: {result.stderr.strip()}")
        abort()
    return result.stdout.strip()

def abort():
    print("\n  ============================================")
    print("   デプロイを中止しました。")
    print("  ============================================\n")
    input("  Enterキーで終了...")
    sys.exit(1)

def confirm(msg):
    ans = input(f"\n  {msg} [y/N]: ").strip().lower()
    return ans in ("y", "yes")

# ============================================================
# チェック関数
# ============================================================
def check_git_installed():
    result = run("git --version", capture=True)
    if result.returncode != 0:
        print_err("git がインストールされていません。")
        print("        https://git-scm.com/downloads からインストールしてください。")
        abort()
    print_ok("git: " + result.stdout.strip())

def check_git_repo(script_dir):
    result = run("git rev-parse --is-inside-work-tree", cwd=script_dir, capture=True)
    if result.returncode != 0:
        print_warn("このフォルダはgitリポジトリではありません。初期化します。")
        run_or_die("git init", cwd=script_dir, error_msg="git init に失敗しました")
        run_or_die(
            f"git remote add origin https://github.com/{GITHUB_USER}/{GITHUB_REPO}.git",
            cwd=script_dir, error_msg="リモート設定に失敗しました"
        )
        print_ok("git リポジトリを初期化しました")
    else:
        print_ok("git リポジトリを確認しました")

def check_remote(script_dir):
    result = run("git remote get-url origin", cwd=script_dir, capture=True)
    if result.returncode != 0:
        run_or_die(
            f"git remote add origin https://github.com/{GITHUB_USER}/{GITHUB_REPO}.git",
            cwd=script_dir, error_msg="リモート設定に失敗しました"
        )
        print_ok("リモートを設定しました")
    else:
        url = result.stdout.strip()
        print_ok(f"リモート: {url}")

def get_current_version(script_dir):
    """CHANGELOG.md からバージョン番号を取得"""
    changelog = Path(script_dir) / "CHANGELOG.md"
    if not changelog.exists():
        return "不明"
    content = changelog.read_text(encoding="utf-8")
    match = re.search(r"##\s*\[(\d+\.\d+\.\d+)\]", content)
    return match.group(1) if match else "不明"

def check_deploy_files(script_dir):
    """デプロイ対象ファイルの存在確認"""
    missing = []
    for f in DEPLOY_FILES:
        path = Path(script_dir) / f
        if not path.exists():
            missing.append(f)
    if missing:
        print_warn(f"以下のファイルが見つかりません（スキップされます）: {', '.join(missing)}")
    present = [f for f in DEPLOY_FILES if (Path(script_dir) / f).exists()]
    print_ok(f"デプロイ対象: {len(present)} ファイル")
    return present

def get_changed_files(script_dir):
    """git status で変更ファイルを取得"""
    result = run("git status --porcelain", cwd=script_dir, capture=True)
    return result.stdout.strip()

# ============================================================
# メイン処理
# ============================================================
def main():
    script_dir = Path(__file__).parent.resolve()

    print()
    print("  ============================================")
    print("   ドローン飛行条件チェッカー")
    print("   GitHub デプロイスクリプト")
    print(f"   リポジトリ: {GITHUB_USER}/{GITHUB_REPO}")
    print("  ============================================")

    total_steps = 7

    # Step 1: git確認
    print_step(1, total_steps, "git のインストールを確認中...")
    check_git_installed()

    # Step 2: リポジトリ確認
    print_step(2, total_steps, "git リポジトリを確認中...")
    check_git_repo(script_dir)
    check_remote(script_dir)

    # Step 3: ファイル確認
    print_step(3, total_steps, "デプロイ対象ファイルを確認中...")
    present_files = check_deploy_files(script_dir)
    version = get_current_version(script_dir)
    print_ok(f"バージョン: v{version}")

    # Step 4: 変更確認
    print_step(4, total_steps, "変更内容を確認中...")
    status = get_changed_files(script_dir)
    if not status:
        print_ok("変更なし — 最新の状態です")
        if not confirm("変更がありませんが、強制プッシュしますか？"):
            print("\n  デプロイをキャンセルしました。\n")
            input("  Enterキーで終了...")
            return
    else:
        print("        変更ファイル:")
        for line in status.split("\n"):
            print(f"          {line}")

    # Step 5: コミットメッセージ
    print_step(5, total_steps, "コミットメッセージを入力してください")
    default_msg = f"v{version}: アプリを更新 ({datetime.now().strftime('%Y-%m-%d %H:%M')})"
    print(f"        デフォルト: {default_msg}")
    msg_input = input("        メッセージ（Enterでデフォルト使用）: ").strip()
    commit_msg = msg_input if msg_input else default_msg
    print_ok(f"コミットメッセージ: {commit_msg}")

    # Step 6: デプロイ確認
    print()
    print(f"  以下の内容でGitHubにプッシュします:")
    print(f"    リポジトリ : https://github.com/{GITHUB_USER}/{GITHUB_REPO}")
    print(f"    ブランチ   : {GITHUB_BRANCH}")
    print(f"    バージョン : v{version}")
    print(f"    ファイル数 : {len(present_files)}")
    if not confirm("実行しますか？"):
        print("\n  デプロイをキャンセルしました。\n")
        input("  Enterキーで終了...")
        return

    # Step 7: git add / commit / push
    print_step(6, total_steps, "ファイルをステージング中...")
    for f in present_files:
        run_or_die(f'git add "{f}"', cwd=script_dir, error_msg=f"git add {f} に失敗しました")
    print_ok(f"{len(present_files)} ファイルをステージング完了")

    print_step(7, total_steps, "コミット＆プッシュ中...")

    # コミット（変更がない場合もallow-emptyで通す）
    result = run(f'git commit -m "{commit_msg}"', cwd=script_dir, capture=True)
    if result.returncode != 0 and "nothing to commit" in result.stdout + result.stderr:
        print_warn("コミットする変更なし（ファイルは最新）")
    elif result.returncode != 0:
        print_err("コミットに失敗しました")
        print(f"        {result.stderr.strip()}")
        abort()
    else:
        print_ok("コミット完了")

    # ブランチ設定してプッシュ
    run(f"git branch -M {GITHUB_BRANCH}", cwd=script_dir, capture=True)
    result = run(
        f"git push -u origin {GITHUB_BRANCH}",
        cwd=script_dir, capture=True
    )
    if result.returncode != 0:
        stderr = result.stderr.strip()
        print_err("プッシュに失敗しました")
        print(f"        {stderr}")
        if "Authentication" in stderr or "credential" in stderr.lower():
            print()
            print("  認証エラーの可能性があります。以下を確認してください:")
            print("    1. GitHub にログイン済みか確認")
            print("    2. Personal Access Token (PAT) の設定:")
            print("       https://github.com/settings/tokens")
            print("    3. git credential の設定:")
            print("       git config --global credential.helper store")
        abort()

    print_ok("プッシュ完了！")

    print()
    print("  ============================================")
    print(f"   デプロイ完了！ v{version}")
    print(f"   https://github.com/{GITHUB_USER}/{GITHUB_REPO}")
    print("  ============================================")
    print()
    input("  Enterキーで終了...")


if __name__ == "__main__":
    main()
