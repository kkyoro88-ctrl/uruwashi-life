#!/bin/bash
# デプロイ前リンク・構造チェック
# 使い方: bash scripts/predeploy-check.sh [ファイルパス]
#   引数なし → content/posts/ 全体をチェック
#   ファイル指定 → そのファイルだけチェック

POSTS_DIR="content/posts"
TARGET="${1:-$POSTS_DIR}"
ERRORS=0

red()    { echo -e "\033[31m[NG] $*\033[0m"; }
yellow() { echo -e "\033[33m[警告] $*\033[0m"; }
green()  { echo -e "\033[32m[OK] $*\033[0m"; }

echo "============================================"
echo "  デプロイ前チェック: $TARGET"
echo "============================================"

# -----------------------------------------------
# 1. search.rakuten.co.jp（もしもで無効なリンク）
# -----------------------------------------------
FILES=$(grep -rl 'search\.rakuten\.co\.jp' $TARGET 2>/dev/null || true)
if [ -n "$FILES" ]; then
  COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
  red "search.rakuten.co.jp が ${COUNT}ファイルに存在（もしもで無効な広告リンク）"
  echo "$FILES"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 2. 楽天リンクのa_id誤り（楽天=5520409 が必須）
# -----------------------------------------------
BAD=$(grep -rn 'item\.rakuten\.co\.jp' $TARGET 2>/dev/null | grep 'af\.moshimo' | grep -v 'a_id=5520409' || true)
if [ -n "$BAD" ]; then
  red "楽天リンクに誤ったa_idが含まれています"
  echo "$BAD"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 3a. Yahoo ASIN形式（YahooではASINで商品に到達しない）
# -----------------------------------------------
BAD=$(grep -rn 'shopping\.yahoo\.co\.jp' $TARGET 2>/dev/null | grep 'af\.moshimo' | grep -E '%3Fp%3DB[A-Z0-9]{9,10}([^A-Z0-9]|$)' || true)
if [ -n "$BAD" ]; then
  red "Yahoo リンクにASIN形式が含まれています（Yahooでは商品に到達しない → キーワード検索形式に変更が必要）"
  echo "$BAD" | head -5
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 3b. Yahoo ダブルエンコード（%25E3 等）
#     正しい形式: シングルエンコード（%E3%83...）
#     NG形式: ダブルエンコード（%25E3%2583...）→ URLが壊れる
# -----------------------------------------------
BAD=$(grep -rn 'shopping\.yahoo\.co\.jp' $TARGET 2>/dev/null | grep 'af\.moshimo' | grep '%25E[3-9]' || true)
if [ -n "$BAD" ]; then
  red "Yahoo リンクがダブルエンコード（%25E3等）— 商品ページに到達しません"
  echo "$BAD" | head -5
  ERRORS=$((ERRORS+1))
fi

# 楽天市場ラベルのボタンが Yahoo a_id (5525312) を使っていないか（rawhtml内）
BAD=$(grep -rn '>楽天市場<' $TARGET 2>/dev/null | grep 'a_id=5525312' || true)
if [ -n "$BAD" ]; then
  red "「楽天市場」ボタンに Yahoo の a_id=5525312 が使われています（誤ラベル）"
  echo "$BAD" | head -5
  ERRORS=$((ERRORS+1))
fi

# shortcode の rakuten= パラメータに Yahoo URL が入っていないか
BAD=$(grep -rn 'rakuten="https://af\.moshimo.*shopping\.yahoo' $TARGET 2>/dev/null || true)
if [ -n "$BAD" ]; then
  red "shortcode の rakuten= パラメータに Yahoo Shopping URL が設定されています"
  echo "$BAD" | head -5
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 4. rawhtml 商品カード: ";display:flex バグ
# -----------------------------------------------
FILES=$(grep -rl '";display:flex' $TARGET 2>/dev/null || true)
if [ -n "$FILES" ]; then
  COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
  red '";display:flex バグが '"${COUNT}"'ファイルに存在（商品カード画像が非表示になります）'
  echo "$FILES"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 5. 商品カードに画像なし（img タグなし rawhtml ブロック）
# -----------------------------------------------
BAD=$(python3 - "$TARGET" <<'PYEOF' 2>/dev/null
import re, os, sys

target = sys.argv[1]
files = []
if os.path.isfile(target):
    files = [target]
elif os.path.isdir(target):
    for f in sorted(os.listdir(target)):
        if f.endswith(".md"):
            files.append(os.path.join(target, f))

pattern = re.compile(r'{{<\s*rawhtml\s*>}}(.*?){{<\s*/rawhtml\s*>}}', re.DOTALL)
issues = []
for fpath in files:
    with open(fpath) as f:
        content = f.read()
    for m in pattern.finditer(content):
        block = m.group(1)
        has_button = re.search(r'af\.moshimo\.com', block)
        has_img = re.search(r'<img\s', block)
        if has_button and not has_img:
            issues.append(os.path.basename(fpath))
if issues:
    print("\n".join(sorted(set(issues))))
PYEOF
)
if [ -n "$BAD" ]; then
  red "商品カードに画像（<img>）がないファイル:"
  echo "$BAD"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 6. Amazon ASIN 形式（10文字英数字でないASIN）
# -----------------------------------------------
BAD=$(grep -rn 'amazon\.co\.jp%2Fdp%2F' $TARGET 2>/dev/null | grep -vE 'dp%2F[A-Z0-9]{10}' || true)
if [ -n "$BAD" ]; then
  yellow "Amazon ASIN 形式が不正の可能性（要目視確認）"
  echo "$BAD" | head -5
fi

# -----------------------------------------------
# 結果サマリ
# -----------------------------------------------
echo ""
echo "============================================"
if [ "$ERRORS" -eq 0 ]; then
  green "チェック全項目クリア — デプロイ可能"
else
  red "エラー ${ERRORS}件 — 修正してからデプロイしてください"
  exit 1
fi
