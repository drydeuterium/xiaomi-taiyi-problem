# HyperOS: AI resource files (`.taiyi`) re-download forever and fill storage

**Status:** reported to Xiaomi Japan customer service (2026-11-15) — bounced back to the carrier.
No fix available. Reproduces on stock firmware, unrooted.

| | |
|---|---|
| Device | Xiaomi 14T Pro (`A402XM` / `rothko_jp`, SoftBank JP carrier model) |
| ROM | HyperOS `OS3.0.4.0.WNNJPSB` / Android 16 (SDK 36) |
| Downloader | `com.xiaomi.aiservice` `3.1.7_65de523_260111_exp` (310067) |
| Renamer | `com.android.providers.downloads` `25.02.07.109` |
| Observed waste | **~11.7 GB** across two incidents |

[日本語の説明はこちら](#日本語)

---

## TL;DR

`com.xiaomi.aiservice` (the Taiyi on-device AI framework) re-enqueues the **same** resource
filename to Android's `DownloadManager` over and over. When the destination already exists,
the HyperOS DownloadProvider does not overwrite or fail — it appends `-1`, `-2`, … and saves a
copy. On a successful install the staged file *is* deleted (confirmed on another resource), but
for `tag`, `wps` and `ai_search` that cleanup never happens, so every retry leaves another
78 MB duplicate behind.

Turning **Settings → Model management → "Wi-Fi auto update" OFF does not stop it**, and there is
no UI to delete or reset a failed resource.

---

## Where the files go

```
/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/<resource>/<version>/
```

This is app-private external storage: invisible to the normal Files app and to
`find /sdcard` (FUSE does not descend into `Android/data`).

## Observed

| Date | Directory | Files | Size |
|---|---|---|---|
| 2026-09-30 | `plugin/tag/7/` | 81 (up to `tag_new-162.taiyi`) | 5.9 GB |
| 2026-09-30 | `plugin/tag/5/` | 176 (up to `tag2-316.taiyi`) | 4.9 GB |
| 2026-11-15 | `plugin/wps/4/` | 56 (`plugin-wps-wps-1-1` … `-1-55`) | 851 MB |
| 2026-11-15 | `plugin/ai_search_mtk/7/` | 106 (`plugin-aisearch-aisearch_mtk-3-1` … `-105`) | 1.3 MB |

- Every copy inside a directory is **byte-identical**
  (`md5 27605b3ab7ee8a2910c281e9c74efa33` for the 78,552,271 B files)
- ~100 copies of a 78 MB file were created within ~2 minutes
- Bursts: 2026-08-07/08/18/22/24/26/28/29/30/31, 09-07, 09-10, 09-19, 09-20, 09-24,
  10-19, 10-24, 10-30

Raw `ls -la` output: [`evidence/2026-09-30-file-list.txt`](evidence/2026-09-30-file-list.txt)

## Root cause (from logcat)

```
Taiyi-Service(aiservice:main)-AIConfigurations: statisticsResource framework_f3 7 required but not found!
Taiyi-Download-TaiyiDownloader: downloadFileInner start:
   DownloadFile(id=framework_f3:7, name=plugin-framework-framework_f3-7.taiyi, ...)
Taiyi-Download-MIDownloadManager: start framework_f3:7 enqueue = 16054
DownloadManager_Job: use xunlei (false) , id=16054,tid=260 frompackage=com.xiaomi.aiservice,
   uri=https://ai-model-cdn-intl.engine.miui.com/ai-taiyi-platform-bucket/deploy/plugin/<uuid>/...
DownloadManager: Deleting .../framework_f3/7/plugin-framework-framework_f3-7.taiyi via provider delete
```

1. `com.xiaomi.aiservice` calls `DownloadManager.enqueue()` with a **fixed destination URI**
   (the resource name never changes).
2. If that path exists, the HyperOS DownloadProvider generates an available filename
   (`generateAvailableFilenameLocked` / `isFilenameAvailableLocked`, Xunlei-based
   `FileDownloader$DownloadFilenameCreateListener`) → `-1`, `-2`, …
3. The happy path *does* exist — on `framework_f3` the staged file is deleted right after
   `installSync`. It does **not** run for `tag` / `wps` / `ai_search`.
4. `wps` is not installed at all (`/data/user_de/0/com.xiaomi.aiservice/taiyi/plugin/` has no
   `wps` directory), so `statisticsResource wps 4 required but not found!` never resolves and the
   download repeats forever.

Full excerpt: [`evidence/log-excerpt.txt`](evidence/log-excerpt.txt)

## Why the user cannot stop it

- `Settings → Model management → モデルを管理 → Wi-Fiで自動アップデート` (key
  `ai_llm_wlan_auto_download_status`) is **OFF**, and downloads still happen
  ([UI dump](evidence/2026-11-15-model-settings-off.txt),
  [screenshot](evidence/2026-11-15-model-settings-off.png))
- No UI entry exists to delete/reset a failed AI resource
- The trigger is a background job: `JOB #u0a428/2001` (`AIJobService`, PERSISTED,
  charging + idle + WIFI) — see [`evidence/jobscheduler-job-2001.txt`](evidence/jobscheduler-job-2001.txt)

## Check your own device

```sh
adb shell "du -sh /sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi"
adb shell "find /sdcard/Android/data/com.xiaomi.aiservice/files/download -name '*.taiyi' | wc -l"
adb shell "logcat -d -b all -v threadtime | grep -E 'Taiyi-Download|statisticsResource' | tail -40"
```

The bundled [`scripts/capture_evidence.ps1`](scripts/capture_evidence.ps1) collects a full bundle
(file list, md5s, `dumpsys`, logcat, screenshot) in one run — do it **before** deleting anything.

## Workaround

Delete only the numbered duplicates, keep the base file
(`X.taiyi` stays, `X-N.taiyi` goes; orphan groups with no base are removed entirely):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\cleanup_taiyi.ps1           # dry run
powershell -ExecutionPolicy Bypass -File .\scripts\cleanup_taiyi.ps1 -Execute  # delete
```

On-device (toybox sh) version: [`scripts/taiyi_clean.sh`](scripts/taiyi_clean.sh) —
`sh taiyi_clean.sh list|delete`.

A watchdog that deletes duplicates as they appear and records evidence first:
[`scripts/taiyi_guard.sh`](scripts/taiyi_guard.sh). It dies on reboot and must be re-armed.

## Suggested fix (for Xiaomi)

1. Always delete the staged `.taiyi` after install **and on failure**.
2. If the destination exists, reuse or overwrite it instead of creating `-N` copies.
3. Cap retries / add backoff for a resource that keeps failing to install.
4. Expose a way for users to delete or reset a failed AI resource.

## Timeline

- 2026-09-30 — first identified; ~11 GB of duplicates removed; root cause traced in logcat
- 2026-11-15 — recurrence on other resources (`wps`, `ai_search_mtk`); 160 files / ~900 MB removed
- 2026-11-15 — reported to Xiaomi Japan CS; reply: "carrier model, contact SoftBank"
  ([reply](docs/xiaomi-jp-reply-2026-11-15.md)). The affected components are Xiaomi's own
  system apps, so the carrier cannot fix this.

## Repository contents

```
docs/       PDF report (JA), investigation notes, complaint drafts, Xiaomi JP reply
evidence/   raw ls -la, logcat excerpt, UI dump + screenshot, dumpsys, jobscheduler
scripts/    evidence capture, duplicate cleanup (PowerShell + sh), watchdog
outreach/   ready-to-send texts for Xiaomi / SoftBank / Community / X
```

No Xiaomi binaries (APK/DEX/models) are included — only text evidence and my own scripts.

---

## 日本語

**症状**: `com.xiaomi.aiservice`（HyperOS の AI リソース管理）が同じファイル名で
`DownloadManager` に再登録し続け、HyperOS の DownloadProvider が既存名を避けて `-1` `-2` … と
別名保存する。正常時はインストール後にステージ済みファイルを削除する実装があるが、
`tag` / `wps` / `ai_search` では走らず、リトライのたびに複製が増える。

- 場所: `/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/<リソース>/<版>/`
- 実測: 2 回で合計 **約 11.7 GB**（1 ファイル 78 MB の複製が 2 分間に 100 個以上）
- 同一ディレクトリ内のファイルはすべてバイト単位で同一（md5 一致）
- 設定「モデルを管理」→「Wi-Fiで自動アップデート」を OFF にしても止まらない
- ユーザー側に削除・停止の手段が無い。端末を初期化しても再発する

**対処**: `scripts/cleanup_taiyi.ps1` で連番の重複だけを削除（基準名は残す）。
`scripts/capture_evidence.ps1` で証拠一式を保存できる（削除前に実行する）。

**報告の状況**: Xiaomi Japan CS へ報告済み（受付番号 X26111541474）。
「キャリアモデルなので販売元へ」との回答。ただし不具合の本体は Xiaomi 製の
システムコンポーネントであり、販売元では修正できない。

詳細レポート: [`docs/taiyi-report-ja.pdf`](docs/taiyi-report-ja.pdf)（4 ページ）
