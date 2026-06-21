# リンク死活チェックレポート 2026-06-21

対象：content/posts/*.md 全122記事 ／ ユニーク685リンク（楽天212・Amazon234・Yahoo199・A8 39 ＋ その他1）
方式：moshimoリダイレクト先（楽天/Amazon/Yahoo）をデコードし、destination URLへ直接curl（-L・UA付き）。非200はブラウザで実在確認。

---

## サマリー

| プラットフォーム | 本数 | 死活（要対応） | 備考 |
|---|---|---|---|
| A8（px.a8.net） | 39 | 0 | 全200 ✅ |
| 楽天 | 212 | **2** | hairbirth-review.md の2本（商品終了） |
| Amazon（/dp/ASIN） | 191 | 0 | 全生存 ✅ |
| Amazon（/s?k= 検索URL） | 43 | 0（要改善） | 生存だが規約/CV観点で/dp化推奨・16記事 |
| Yahoo | 199 | **8** | 売り切れ/販売終了（ブラウザ確認済み） |

curlの一時的な000/503/500は再試行・ブラウザ確認で切り分け済み。

---

## 確定した死活リンク（要差し替え）

### 楽天（2本・ともに hairbirth-review.md）
- `item.rakuten.co.jp/hairborn/hairborn001/` → 404（shortcode商品カード）
- `item.rakuten.co.jp/love-dream/100000401/` → 404（旧rawHTMLカード）
- → ヘアバース（HAIRBIRTH）は楽天で取扱終了の疑い。**記事リライトで対応**

### Yahoo（8本）
| 記事 | 死活リンク（store/item） | 状態 |
|---|---|---|
| hair-oil-recommend.md | kerastase-varie/hu-huilsubn_100 | 404（notfound） |
| hair-oil-recommend.md | cosmecomonline/1000196014 | 500（販売終了） |
| hair-oil-recommend.md | drugkirin/4582521682928 | 500（販売終了） |
| hair-oil-recommend.md | lorealparis/404130 | 500（販売終了・ブラウザ確認済） |
| hair-oil-recommend.md | oshimatsubaki/4970170109161 | 500（販売終了） |
| outbath-treatment-40s-recommend.md | kobe-beauty-labo/bota-oil-01 | 500（販売終了） |
| outbath-treatment-40s-recommend.md | nacre-beaute/101025 | 500（販売終了） |
| fatigue-supplement-40s-women.md | lohaco-yahoo/4946842636907 | 500（販売終了・ブラウザ確認済） |

※ fujifilm-h/16829939（Yahoo）は000で切り分け不能 → 別途ブラウザ確認推奨。

---

## 要改善（死活ではないが規約/CV観点）

### Amazon検索URL（/s?k=）を含む16記事 → /dp/ASIN化推奨
body-cream-recommend-40s / currentbody-led-hair-review / currentbody-led-mask-review / everyfrecious-review / hairbirth-review / mirablezero-review / nmn-15000-white-premium-review / niacinamide-lotion-40s-recommend / orbis-amber-review / numbersIN-5-review / reglage-purt-serum-review / showerhead-recommend / sheet-mask-40s-recommend / tria4x-review / urunon-review / ziip-halo-review

---

## 対応方針（PM承認済み 2026-06-21）

1. **hair-oil-recommend.md** をリライト：Yahoo死活5本を生存商品へ差し替え＋鮮度更新
2. **hairbirth-review.md** をリライト：楽天死活2本＋Amazon検索URL＋Yahoo無しを是正（ヘアバース継続可否を確認）
3. **Yahoo死活差し替え**：outbath-treatment / fatigue-supplement
4. **Amazon /s?k= → /dp化**：16記事を順次
