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

# -----------------------------------------------
# 3c. Amazon 検索URL（/s?k=）内のダブルエンコード
#     /dp/ASIN が推奨。やむを得ず /s?k= を使う場合も
#     キーワードはシングルエンコード（%E3%83...）であること
#     NG: url=...%2Fs%3Fk%3D%25E3... （%25E3 = ダブルエンコード）
# -----------------------------------------------
BAD=$(grep -rn 'amazon\.co\.jp%2Fs%3Fk%3D%25E[3-9]' $TARGET 2>/dev/null | grep 'af\.moshimo' || true)
if [ -n "$BAD" ]; then
  red "Amazon 検索URLがダブルエンコード（%25E3等）— 商品ページに到達しません"
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
# 7. Yahoo search URL（shopping.yahoo.co.jp/search）→ もしもで「無効な広告リンク」
# -----------------------------------------------
FILES=$(grep -rl 'shopping\.yahoo\.co\.jp%2Fsearch' $TARGET 2>/dev/null || true)
if [ -n "$FILES" ]; then
  COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
  red "shopping.yahoo.co.jp/search が ${COUNT}ファイルに存在（もしもで無効な広告リンク）— yahoo= パラメータから削除してください"
  echo "$FILES"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 8. カバー画像ファイル存在確認
# -----------------------------------------------
BAD=$(python3 - "$TARGET" <<'PYEOF' 2>/dev/null
import re, os, sys, glob

target = sys.argv[1]
files = []
if os.path.isfile(target):
    files = [target]
elif os.path.isdir(target):
    for f in sorted(glob.glob(os.path.join(target, '*.md'))):
        files.append(f)

issues = []
for fpath in files:
    with open(fpath) as f:
        content = f.read()
    m = re.search(r'image:\s*"(/images/[^"]+)"', content)
    if m:
        img_path = os.path.join('/Users/boa/uruwashi-life/static', m.group(1).lstrip('/'))
        if not os.path.exists(img_path):
            issues.append(f'{os.path.basename(fpath)}: {m.group(1)} が見つかりません')
if issues:
    print('\n'.join(issues))
PYEOF
)
if [ -n "$BAD" ]; then
  red "カバー画像ファイルが存在しません:"
  echo "$BAD"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 9. rawhtml内のYahooボタン色が正しいか（#720096 以外はNG）
# -----------------------------------------------
BAD=$(grep -rn 'Yahooショッピング' $TARGET 2>/dev/null | grep 'style=' | grep -v '#720096' || true)
if [ -n "$BAD" ]; then
  red "rawhtml内のYahooボタン色が不正（#720096 以外が使われています）"
  echo "$BAD" | head -5
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 10. rawhtml内でAmazonボタンが楽天ボタンより前にある（順番逆転）
# -----------------------------------------------
BAD=$(python3 - "$TARGET" <<'PYEOF' 2>/dev/null
import re, os, sys, glob

target = sys.argv[1]
files = []
if os.path.isfile(target):
    files = [target]
elif os.path.isdir(target):
    for f in sorted(glob.glob(os.path.join(target, '*.md'))):
        files.append(f)

issues = []
for fpath in files:
    with open(fpath) as f:
        content = f.read()
    blocks = re.findall(r'{{<\s*rawhtml\s*>}}(.*?){{<\s*/rawhtml\s*>}}', content, re.DOTALL)
    for block in blocks:
        if '>Amazon<' in block and '>楽天市場<' in block:
            if block.index('>Amazon<') < block.index('>楽天市場<'):
                issues.append(os.path.basename(fpath))
                break
if issues:
    print('\n'.join(sorted(set(issues))))
PYEOF
)
if [ -n "$BAD" ]; then
  red "rawhtml内でAmazonボタンが楽天より前にあります（正しい順：楽天→Amazon→Yahoo）"
  echo "$BAD"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 11. price_checked フィールド（商品リンクあり記事）
#     - フィールド未設定 → エラー
#     - 90日以上経過 → 警告
# -----------------------------------------------
BAD=$(python3 - "$TARGET" <<'PYEOF' 2>/dev/null
import re, os, sys, glob
from datetime import date, datetime

target = sys.argv[1]
files = []
if os.path.isfile(target):
    files = [target]
elif os.path.isdir(target):
    for f in sorted(glob.glob(os.path.join(target, '*.md'))):
        files.append(f)

missing = []
stale = []
today = date.today()

for fpath in files:
    with open(fpath) as f:
        content = f.read()
    if 'af.moshimo.com' not in content:
        continue
    m = re.search(r'^price_checked:\s*"?(\d{4}-\d{2}-\d{2})"?', content, re.MULTILINE)
    if not m:
        missing.append(os.path.basename(fpath))
    else:
        checked = datetime.strptime(m.group(1), '%Y-%m-%d').date()
        days = (today - checked).days
        if days > 90:
            stale.append(f'{os.path.basename(fpath)}: {m.group(1)}（{days}日経過）')

if missing:
    print('MISSING:' + ','.join(missing))
if stale:
    print('STALE:' + ','.join(stale))
PYEOF
)
if echo "$BAD" | grep -q '^MISSING:'; then
  MISSING_FILES=$(echo "$BAD" | grep '^MISSING:' | sed 's/^MISSING://' | tr ',' '\n')
  red "price_checked フィールドがありません（商品リンクのある記事には必須）:"
  echo "$MISSING_FILES"
  ERRORS=$((ERRORS+1))
fi
if echo "$BAD" | grep -q '^STALE:'; then
  STALE_FILES=$(echo "$BAD" | grep '^STALE:' | sed 's/^STALE://' | tr ',' '\n')
  yellow "price_checked が90日以上前 — 価格を目視確認してください:"
  echo "$STALE_FILES"
fi

# -----------------------------------------------
# 12. images/P/ 形式の Amazon 画像 URL（非推奨・43バイト問題）
#     images/P/{ASIN}.XX._SL500_.jpg は多くのASINで壊れる
#     正しい形式: images/I/{imageID}._AC_SL500_.jpg
# -----------------------------------------------
FILES=$(grep -rl 'images/P/[A-Z0-9]\{10\}\.' $TARGET 2>/dev/null || true)
if [ -n "$FILES" ]; then
  COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
  red "images/P/ 形式の Amazon 画像 URL が ${COUNT}ファイルに存在（43バイト問題 → images/I/ 形式に修正が必要）"
  echo "$FILES"
  ERRORS=$((ERRORS+1))
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
