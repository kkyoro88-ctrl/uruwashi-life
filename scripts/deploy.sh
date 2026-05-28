#!/bin/bash
# uruwashi-life デプロイスクリプト
# 使い方:
#   bash scripts/deploy.sh              → 全記事チェック → デプロイ
#   bash scripts/deploy.sh [ファイル]   → 指定ファイルのみチェック → デプロイ
#   bash scripts/deploy.sh --skip-check → チェックをスキップ（緊急時のみ）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/predeploy-check.sh"
TARGET="${1:-}"
SKIP_CHECK=false

red()   { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
bold()  { echo -e "\033[1m$*\033[0m"; }

# --skip-check フラグ処理
if [ "$TARGET" = "--skip-check" ]; then
  SKIP_CHECK=true
  TARGET=""
  red "⚠️  --skip-check が指定されました。チェックをスキップします（緊急時のみ使用）"
fi

bold "============================================"
bold "  uruwashi-life デプロイ"
bold "============================================"

# -----------------------------------------------
# Step 1: デプロイ前チェック（自動）
# -----------------------------------------------
if [ "$SKIP_CHECK" = false ]; then
  bold ""
  bold "🔍 Step 1: デプロイ前チェック..."
  if [ -n "$TARGET" ]; then
    bash "$CHECK_SCRIPT" "$TARGET"
  else
    bash "$CHECK_SCRIPT"
  fi
  green "✅ チェック通過"
else
  bold ""
  bold "⏭  Step 1: チェックスキップ"
fi

# -----------------------------------------------
# Step 2: Hugo ビルド
# -----------------------------------------------
bold ""
bold "🔨 Step 2: Hugo ビルド中..."
hugo --minify
green "✅ ビルド完了"

# -----------------------------------------------
# Step 3: Cloudflare Pages デプロイ
# -----------------------------------------------
bold ""
bold "🚀 Step 3: Cloudflare Pages にデプロイ中..."
npx wrangler pages deploy public --project-name uruwashi-life
green "✅ デプロイ完了"

bold ""
bold "============================================"
green "  ✨ 全工程完了"
bold "============================================"
