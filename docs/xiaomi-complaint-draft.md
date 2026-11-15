# Xiaomi への不具合報告ドラフト（`.taiyi` 連番増殖）

調査結果にもとづく報告文。窓口ごとに使い分ける。

---

## 1. 窓口一覧（2026-11 時点）

| 窓口 | 連絡先 | 向き |
|---|---|---|
| **アプリ内「サービスとフィードバック」** | 端末内アプリ（設定内 / アプリ一覧） | **本命**。端末ログを添付でき、開発側に直接届く |
| Xiaomi Japan カスタマーサービス | **0120-767-378**（9:00〜18:00 / 年末年始を除く）<br>**service.jp@support.mi.com** | 修理窓口寄りだが不具合報告も受付 |
| 小米技術日本株式会社（特商法表示） | 0120-300-521 / service.jp@support.mi.com | 法人・法務寄り |
| Xiaomi Community | https://c.mi.com/global/ （Feedback 板） | 英語。他ユーザーの賛同が付くと強い |
| X（旧 Twitter） | **@XiaomiJapan**（日本公式）, **@XiaomiSupport**（グローバル） | 公開圧力。DM は基本返らないので公開リプライ向き |

参考:
- https://www.mi.com/jp/service/support/aftersales.html
- https://www.mi.com/jp/service/support/terms_1.html
- https://x.com/XiaomiJapan
- https://c.mi.com/global/

**送る順番の推奨**: ①アプリ内フィードバック（ログ付き）→ ②メール（記録が残る）→ ③X（反応がなければ）

---

## 2. 日本語版（メール / フィードバック本文）

> 題名: 【不具合】AI リソースの `.taiyi` ファイルがアプリ領域に無制限に増え続け、ストレージが圧迫される

Xiaomi A402XM（HyperOS OS3.0.4.0.WNNJPSB / Android 16）を使用しています。
`com.xiaomi.aiservice`（Taiyi フレームワーク）の AI リソース・ダウンロードで、
**同じ内容の `.taiyi` ファイルが連番付きで無制限に増え続ける**現象が発生しています。

### 発生場所

```
/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/<リソース名>/<バージョン>/
```

ユーザーが通常のファイル管理からは辿りにくいアプリ専用領域のため、気付かないまま容量を消費します。

### 実測値（2 回確認）

| 回 | ディレクトリ | ファイル数 | 容量 |
|---|---|---|---|
| 1回目 | `plugin/tag/7/` | `tag_new.taiyi` ほか 81 個（最大 `tag_new-162.taiyi`） | 5.9 GB |
| 1回目 | `plugin/tag/5/` | `tag2.taiyi` ほか 176 個（最大 `tag2-316.taiyi`） | 4.9 GB |
| 2回目 | `plugin/wps/4/` | 56 個（`plugin-wps-wps-1-1` 〜 `-1-55`） | 851 MB |
| 2回目 | `plugin/ai_search_mtk/7/` | 106 個（`plugin-aisearch-aisearch_mtk-3-1` 〜 `-3-105`） | 1.3 MB |

- 同一ディレクトリ内のファイルは **すべてバイト単位で同一**（例: `md5 = 27605b3ab7ee8a2910c281e9c74efa33`）
- 1 ファイル 78 MB の複製が 2 分間に 100 個以上作られた例あり
- 合計 **約 11.7 GB** を消費

### 原因（ログで確認済み）

1. `com.xiaomi.aiservice` が Android の DownloadManager に、**毎回同じファイル名**で再登録している
   ```
   Taiyi-Download-MIDownloadManager: start framework_f3:7 enqueue = 16054
   DownloadManager_Job: frompackage=com.xiaomi.aiservice, uri=https://ai-model-cdn-intl.engine.miui.com/…
   ```
2. HyperOS の DownloadProvider が、宛先が既存の場合に上書きもエラーもせず `-N` を付けて別名保存する
3. 本来はインストール成功後にステージ済みファイルを削除する実装になっている（`framework_f3` では動作を確認）
   が、`tag` / `wps` / `ai_search` では削除されず、**リトライのたびに複製が増える**
   ```
   AIConfigurations: statisticsResource wps 4 required but not found!
   Taiyi-Download-TaiyiDownloader: downloadFileInner start: …
   AIResources: installSync Install[framework_f3, 7] result: (…, 0)
   DownloadManager: Deleting …/framework_f3/7/plugin-framework-framework_f3-7.taiyi via provider delete
   ```
4. `wps` はインストール自体が完了していない（`/data/user_de/0/com.xiaomi.aiservice/taiyi/plugin/` に
   `wps` のディレクトリが存在しない）ため、「required but not found」が解消せず永久にダウンロードが繰り返される

### 設定では止められない

設定アプリ内の **「モデルを管理」→「Wi-Fiで自動アップデート」を OFF** にしても発生しました
（`ai_llm_wlan_auto_download_status`）。ユーザー側で止める手段が実質ありません。

### ご要望

1. ステージ済み `.taiyi` をインストール後に確実に削除する（失敗時も後始末する）
2. 宛先に既存ファイルがある場合は再ダウンロードせず再利用、または上書きする
3. 同一リソースの再試行に回数上限・バックオフを設け、無限ループを防ぐ
4. 失敗したリソースをユーザーが UI から削除・リセットできるようにする
5. 既に蓄積したファイルを掃除する手段（設定のストレージ管理など）を提供する

端末は root 化しておらず純正状態です。再現条件は「Wi-Fi 接続＋充電中＋端末アイドル時」、
および Gallery で AI 機能（検索・タグ付け）を使ったタイミングです。

---

## 3. English version（X / Xiaomi Community 向け・短縮）

> **Same `.taiyi` AI resource file keeps re-downloading forever, filling storage (11.7 GB so far)**
>
> Xiaomi A402XM, HyperOS OS3.0.4.0.WNNJPSB (Android 16), stock/not rooted.
>
> `/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/<res>/<ver>/`
> accumulates identical copies: `tag_new-1.taiyi` … `tag_new-162.taiyi` (78 MB each, all identical
> md5 27605b3a…), plus 55 copies of `plugin-wps-wps-1-*` and 105 of `plugin-aisearch-aisearch_mtk-3-*`.
>
> Cause: `com.xiaomi.aiservice` re-enqueues the same filename to DownloadManager
> (`Taiyi-Download-MIDownloadManager: start … enqueue = 16054`,
> `DownloadManager_Job: frompackage=com.xiaomi.aiservice`). HyperOS DownloadProvider never
> overwrites, so it appends `-1, -2, …`. The staged file is deleted after a successful install
> (confirmed with `framework_f3`), but not for `tag`/`wps`/`ai_search` — `statisticsResource wps 4
> required but not found!` loops forever.
>
> Turning **"Wi-Fi auto update" OFF** in Model management does **not** stop it.
>
> Please: (1) always clean up staged `.taiyi`, (2) reuse/overwrite instead of appending `-N`,
> (3) cap retries, (4) add a UI to delete/reset failed resources.

---

## 4. 添付すると良いもの

- スクリーンショット: 設定 →「モデルを管理」（「Wi-Fiで自動アップデート」OFF の状態）
- できれば `adb` で取得したファイル一覧（`ls -la` の出力）
- フィードバックアプリから送る場合は、**ログ取得（Logs）を有効化**してから送ると調査されやすい
