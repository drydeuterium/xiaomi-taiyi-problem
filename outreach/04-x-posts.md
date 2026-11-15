X / Twitter 用の投稿セット

※ 1 投目に URL を入れると 280 字を超えるので、リンクは 2 投目（返信）に置く。
   URL は長さ 23 字として数えられる点に注意。

======================================================================
A. 英語 1 投目（@XiaomiSupport 向け）
======================================================================

HyperOS bug: com.xiaomi.aiservice re-downloads the same AI model over and over.
DownloadProvider appends -1,-2… and never cleans up, so .taiyi files pile up —
11.7 GB of identical copies on a stock 14T Pro. "Wi-Fi auto update" OFF does not
stop it. @XiaomiSupport @XiaomiJapan where do I send the logs?

======================================================================
A2. 英語 2 投目（返信・リンク）
======================================================================

Full evidence (logs, ls -la, screenshot, cleanup script):
github.com/drydeuterium/xiaomi-taiyi-problem

======================================================================
B. 日本語 1 投目（@XiaomiJapan 向け）
======================================================================

HyperOS の不具合報告です。com.xiaomi.aiservice が同じ AI モデルを延々と再ダウンロードし、
DownloadProvider が -1, -2… と別名保存、後始末もされないため .taiyi が 11.7 GB 蓄積
（純正 14T Pro・未改造）。設定の「Wi-Fiで自動アップデート」を OFF にしても止まりません。
@XiaomiSupport @XiaomiJapan ログの送付先を教えていただけませんか。

======================================================================
B2. 日本語 2 投目（返信・リンク）
======================================================================

証拠（ログ・ls -la・スクショ・掃除スクリプト）はこちらにまとめました。
github.com/drydeuterium/xiaomi-taiyi-problem

======================================================================
C. スレッド 3 投目（英語・証拠の要点）
======================================================================

What happens (logcat, stock ROM):

Taiyi-Download-MIDownloadManager: start framework_f3:7 enqueue = 16054
DownloadManager_Job: frompackage=com.xiaomi.aiservice,
  uri=https://ai-model-cdn-intl.engine.miui.com/...
DownloadManager: Deleting .../framework_f3/7/...taiyi via provider delete  ← happy path OK

The delete step never runs for tag / wps / ai_search, so every retry creates
tag_new-1.taiyi, tag_new-2.taiyi, ... (all byte-identical, md5 27605b3a…).

======================================================================
D. スレッド 4 投目（英語・再現と依頼）
======================================================================

Repro: Wi-Fi on + charging + idle (JobScheduler AIJobService#2001), or just using
Gallery AI search/tagging. The resource check reports
"statisticsResource wps 4 required but not found!" and the download loops.

Fix I'd suggest: delete the staged .taiyi after install *and on failure*, reuse
the existing file instead of appending -N, and cap retries.

======================================================================
E. 添付する画像
======================================================================

  evidence/2026-11-15-model-settings-off.png
    「モデルを管理」で「Wi-Fiで自動アップデート」が OFF の実機画面（1220x2712）
    → 「設定で止められない」ことを一目で示せる

  ※ 2 投目に貼るなら、ls -la の文字列を画像化するより、
     「81 files / 5.9 GB / max tag_new-162」のような数字を本文に書く方が伝わる

======================================================================
F. 投稿のコツ
======================================================================

 ・1 投目は「症状 + 数字 + 止められない事実 + 送付先の質問」だけ。リンクと技術詳細は返信に分割
 ・@XiaomiSupport（英語）と @XiaomiJapan（日本語）を両方メンション
 ・DM は基本返らないので「公開リプライ → 相手が DM を求めてくる」形を狙う
 ・同じ内容を Xiaomi Community にも投稿しておくと、リプライで誘導しやすい
