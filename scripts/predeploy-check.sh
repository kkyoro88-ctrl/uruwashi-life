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
# 4. rawhtml 商品カード: ";display:flex / ;;display:flex バグ
# -----------------------------------------------
FILES=$(grep -rl '";display:flex\|;;display:flex' $TARGET 2>/dev/null || true)
if [ -n "$FILES" ]; then
  COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
  red ';;display:flex バグが '"${COUNT}"'ファイルに存在（商品カードのflex無効 → ページレイアウト崩壊の原因）'
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
# 13. rawhtml内のdiv開閉バランスチェック
#     <div の数 ≠ </div> の数 → ページレイアウト崩壊の原因
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
        opens = block.count('<div')
        closes = block.count('</div>')
        if opens != closes and 'display:flex' in block:
            issues.append(f'{os.path.basename(fpath)}: <div>={opens} </div>={closes}')
if issues:
    print('\n'.join(sorted(set(issues))))
PYEOF
)
if [ -n "$BAD" ]; then
  red "rawhtml内でdivの開閉が一致しないflex商品カードが存在（ページレイアウト崩壊の原因）:"
  echo "$BAD"
  ERRORS=$((ERRORS+1))
fi

# -----------------------------------------------
# 14. FC（ファクトチェック）リスク表現スキャナー
#     景表法・薬機法でリスクの高い「断定的な順位・統計・権威」主張が
#     出典注記なしで使われていないか検査する。
#     - No.1 / 満足度 / リピート率 / 継続率 / 売上実績 / FDA基準クリア /
#       皮膚科推薦 / 医師推奨 / ランキング1位 など
#     - 同じ行に出典注記（※ / 調べ / 出典 / 機構 / 号 / 受賞 / LDK / n=）が
#       あれば許容（＝根拠が示されている）。なければ警告。
#     ※ ハードエラーにはしない（正当な注記漏れの可能性もあるため）。
#        ただしデプロイのたびに必ず一覧表示し、FC確認を促す。
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

# リスク表現（断定的な統計・権威・No.1主張のみ。サイト独自のランキング
# 見出し「### No.1｜」「第1位」等＝編集上の順位は対象外）
risk_patterns = [
    # 「○○ No.1 / ナンバーワン / 第1位」のように主張の修飾語を伴うNo.1
    r'(医療従事者|医師|皮膚科|売上|販売台数|販売実績|出荷|累計|世界|国内|シェア|人気|楽天|Amazon|アマゾン|満足度|受賞)[^。\n]{0,8}(No\.?\s?1|ナンバーワン|第\s*1\s*位)',
    # 数字を伴う統計主張
    r'(リピート率|継続率|満足度|愛用者|販売実績)\s*[\d０-９]',
    # 根拠が必要な権威・効能の断定
    r'(FDA基準クリア|皮膚科推薦|皮膚科医推奨|医師推奨|医療従事者[がの]?推奨)',
]
risk = re.compile('|'.join(risk_patterns))
# 出典・根拠が示されていれば許容
attal = re.compile(r'(※|調べ|出典|機構|号|受賞|ベストバイ|LDK|n\s*=|当社調査|自社調査|公式サイト調査|モニター)')

issues = []
for fpath in files:
    with open(fpath) as f:
        lines = f.readlines()
    for i, line in enumerate(lines, 1):
        # リンクURL行・画像URL行は除外
        if 'af.moshimo' in line or 'px.a8.net' in line or 'media-amazon' in line:
            continue
        if risk.search(line) and not attal.search(line):
            snippet = line.strip()
            if len(snippet) > 80:
                snippet = snippet[:80] + '…'
            issues.append(f'{os.path.basename(fpath)}:{i}: {snippet}')

if issues:
    print('\n'.join(issues))
PYEOF
)
if [ -n "$BAD" ]; then
  yellow "FC要：出典注記なしの順位・統計・権威表現があります（景表法・薬機法リスク／要確認）:"
  echo "$BAD"
  echo "  → 根拠を確認し「※○○調べ」等を付けるか、表現を緩和してください。"
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
