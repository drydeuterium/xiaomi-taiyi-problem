# HyperOS `.taiyi` 連番増殖の調査結果

- 調査日: 2026-09-30
- 端末: Xiaomi A402XM (rothko_jp) / HyperOS OS3.0.4.0.WNNJPSB / Android 16 (SDK 36)
- 接続: `adb` / root なし (`su` 無し, `ro.debuggable=0`, verified boot green)
- 作業ディレクトリ: `C:\Users\user\Documents\adb`

---

## 1. 結論

| 問い | 結論 |
|---|---|
| 誰が `.taiyi` を取得しているか | **`com.xiaomi.aiservice`**（Taiyi フレームワーク、uid `u0_a428` = 10428）。Android の **DownloadManager** に `setDestinationUri()` で自アプリ領域を宛先に指定して enqueue している |
| なぜ `tag_new-94.taiyi` のように連番で増えるか | 要求ファイル名は毎回 `tag_new.taiyi` 固定。システム側 DownloadProvider が「既存ファイルを上書きせず使用可能名を採番」するため `-1`, `-2`, … が付く |
| なぜ既存を再利用しないか | 本来は「ダウンロード → インストール → ステージ済みファイル削除」で完結する。**`tag` はこのインストール／後始末が完了せず**、リトライのたびに同じ宛先へ再ダウンロード → そのたびに別名化 → 蓄積 |
| 増殖の発生条件 | サーバ側の設定更新（`ConfigUpdater` のリソース更新）で新しいリソース版が必要になったとき。Wi-Fi（非従量制）接続かつ充電中＋アイドルで実行される |

**ファイルは `/sdcard/Download` ではなく、AIService のアプリ専用領域にあった。**

---

## 2. 実ファイルの場所・規模（削除前）

```
/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/tag/5/tag2*.taiyi      176 個  4.96 GiB
/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/tag/7/tag_new*.taiyi   81 個  5.85 GiB
--------------------------------------------------------------------------------------------
合計 257 ファイル / 約 11 GiB
```

- 1 ファイル: `tag2*.taiyi` = 30,424,058 B / `tag_new*.taiyi` = 78,552,271 B
- 内容は全ファイル **バイト単位で同一**（`md5 = 27605b3ab7ee8a2910c281e9c74efa33`）
- `/sdcard/Download`（113 エントリ）に `.taiyi` は存在しない
- 参考: `find /sdcard ...` は `/sdcard/Android/data` 配下を暗黙にスキップする

### package 内容（`tag_new-94.taiyi`）

```
11463595  lib/arm64-v8a/video_tag_opset11_static_nchw_mace_v2.0.1_cpu.minn
 8885215  lib/arm64-v8a/shot_type_opset11_static_nchw_mace_v2.0.1_cpu.minn
33757511  lib/arm64-v8a/scene_2k_opset11_static_nchw_mace_v2.0.1_cpu.minn
28238289  lib/arm64-v8a/head_hollywood_yolov5s_640_avgpool_v2.0.1_cpu.minn
  992912  lib/arm64-v8a/libmerge_tag.so
 1244400  lib/arm64-v8a/libvideo_analytic.so
 1853592  lib/arm64-v8a/libmnn_wrapper.so
 5111056  lib/arm64-v8a/libnova.so
 1153680  lib/arm64-v8a/libxplatform_util.so
  266400  lib/arm64-v8a/libmergetag_info.so
 1822720  lib/arm64-v8a/libc++_shared.so
   41945  plugin-tag-tag-2.apk
     145  taiyi_hash.json
```

- `taiyi_hash.json` の sha256 `bbdd3cc3…4da5` と実 APK の sha256 が一致
- その APK のパッケージ名 = **`com.xiaomi.taiyi.plugin.tag`**

---

## 3. 決定的な証拠（ライブキャプチャ 2026-09-30 22:04:15）

`framework_f3` という別プラグインのダウンロードが完全なライフサイクルで記録できた。

```
22:04:15.018 W AIConfigurations: statisticsResource framework_f3 7 required but not found!
22:04:15.030 I Taiyi-Download-TaiyiDownloader: downloadFileInner start:
             DownloadFile(id=framework_f3:7, name=plugin-framework-framework_f3-7.taiyi, url=https://****/…)
22:04:15.057 I Taiyi-Download-MIDownloadManager: start framework_f3:7 enqueue = 16054
22:04:15.062 D DownloadManager_Job: use xunlei (false) , id=16054,tid=260
             frompackage=com.xiaomi.aiservice,
             uri=https://ai-model-cdn-intl.engine.miui.com/ai-taiyi-platform-bucket/deploy/plugin/
                 6c1f63b9-bb4a-4204-bb1a-49610b7577e8/plugin-framework-framework_f3-7.taiyi,filename=null
22:04:15.403 I DownloadThread: [16054] executeDownload responseCode = 200, …/plugin-framework-framework_f3-7.taiyi
22:04:15.573 W DownloadManager: Error updateMediaProvider … _data=/storage/emulated/0/Android/data/
             com.xiaomi.aiservice/files/download/taiyi/plugin/framework_f3/7/plugin-framework-framework_f3-7.taiyi
22:04:16.101 I Taiyi-Download-MIDownloadManager: onReceive 16054
             DownloadEntity(fileId=framework_f3:7, downloadId=16054, state=SUCCESS, code=0,
             fileName=plugin-framework-framework_f3-7.taiyi, totalSize=2252013, offsetSize=2252013,
             sha256=8ef456d3…, createTime=1790773455031, modifyTime=1790773455548, cost=1040, times=1)
22:04:16.130 I Taiyi-Service(aiservice:main)-AIResources: installSync Install[framework_f3, 7] result:
             (AIResource(framework_f3, 7, PLUGIN, SHARED), 0)
22:04:16.131 I Taiyi-Download-TaiyiDownloader: cancelFileInner: framework_f3:7. null
22:04:16.141 V DownloadManager: Deleting /storage/emulated/0/Android/data/com.xiaomi.aiservice/files/
             download/taiyi/plugin/framework_f3/7/plugin-framework-framework_f3-7.taiyi via provider delete
22:04:16.149 I Taiyi-Download-MIDownloadManager: remove framework_f3:7 1 DownloadEntity(…)
```

読み取れること:

1. **登録元は `com.xiaomi.aiservice`**（`frompackage=com.xiaomi.aiservice`、`enqueue = 16054` はシステム DM の
   `downloadId`。同時期の他エントリが `_id=16049〜16053` であることと整合）
2. 宛先は `…/download/taiyi/plugin/<ability>/<version>/<fileName>` という規則的なレイアウト
3. 配信元 CDN は `https://ai-model-cdn-intl.engine.miui.com/ai-taiyi-platform-bucket/deploy/plugin/<uuid>/…`
4. **正常系ではインストール後にステージ済みファイルを削除する**（`Deleting … via provider delete`）
   → `tag` のディレクトリに 257 個も残っているのは、**tag のインストール／後始末が完了していない**ため
5. `statisticsResource <name> <ver> required but not found!` がダウンロード開始のトリガー

---

## 4. 連番の発生機構

1. アプリは `remote_resource.fileName`（= `tag_new.taiyi`）をそのまま宛先に指定
2. システムの DownloadProvider（HyperOS 版 `com.android.providers.downloads` versionName 25.02.07.109、
   pid 24833）は宛先が既存でも上書きもエラーもしない。dex 内に
   `generateAvailableFilenameLocked` / `isFilenameAvailableLocked` /
   `"Failed to generate an available filename"` /
   `com.michael.corelib.filedownload.FileDownloader$DownloadFilenameCreateListener`（Xunlei 系）が存在
3. 結果 `tag_new.taiyi` → `tag_new-1.taiyi` → … → `tag_new-162.taiyi` と無限採番
4. アプリは `sha256` 検証・`installSync` を経て再び「必要」と判断し、同じ要求を再投入する
5. 番号の欠番（tag/7: 1〜162 中 81 個のみ現存）は**ユーザーの手動削除**によるもの（本人確認済み）

---

## 5. 生成元パッケージ

```
com.xiaomi.aiservice
  versionName = 3.1.7_65de523_260111_exp / versionCode = 310067
  codePath    = /product/priv-app/AIService/AIService.apk   (SYSTEM, targetSdk 36)
  uid         = u0_a428 (10428)
```

関連クラス／文字列（APK 内）:

- `com.xiaomi.aiservice.download.{DownloadManager, DownloadService, DownloadProvider, DownloadEngine, DownloadUI, dialog.DownloadDialogActivity}`
- `com.xiaomi.taiyi.download.core.*`、`com.xiaomi.taiyi.sdk.download.{IDownloadManager, IDownloadListener}`
- ログタグ: `Taiyi-Download-TaiyiDownloader` / `Taiyi-Download-MIDownloadManager` / `Taiyi-Service(aiservice:main)-*`
- Room DB `download_table(fileId, **downloadId**, state, code, fileName, fileUrl, filePath, totalSize, offsetSize, sha256, createTime, modifyTime, cost, times)` / `remote_resource` / `local_resource`
- `ERROR_DOWNLOAD_*`（AOSP `DownloadManager.ERROR_*` と 1:1）、`ERROR_WLAN_AUTO_DOWNLOAD_NOT_ALLOW_BY_USER`、
  `ERROR_DOWNLOAD_REJECT_BY_USER_WHEN_METERED`、`METERED_DOWNLOAD_CONFIRM`、`downloadBySilence`、
  `checkCancelSilenceDownload for privacy_reject`

### トリガー

- `AIJobService` の JobScheduler ジョブ `JOB #u0a428/2001`（PERSISTED / **charging + deviceIdle + WIFI**、backoff 30s）
  → 現在は `Unsatisfied constraints: IDLE` のみ
- `DownloadEngine: onSceneComplete app_launch`、`checkDownloadAll for app_launch / network_available …`
- 従量制回線では `skip by wifi or vpn unavailable!` で中止（`dumpsys netpolicy` の `Metered ifaces: {ccmni3}` と整合）

---

## 6. 設定 UI（増殖を抑えるレバー）

`com.xiaomi.aicr` の **「モデルを管理」** 画面（`com.xiaomi.aicr/.common.download.ModelActivity`）に

- **「Wi-Fiで自動アップデート」** トグル（resource-id `com.xiaomi.aicr:id/check_slidingSwitch`）
- 説明: 「温度、システム状態、その他の要因に基づいて適切なタイミングでアップデート」

がある。文字列 `ai_llm_wlan_auto_download_status` は **AIService と aicr の dex にのみ存在**（Gallery / Settings /
MediaEditor には無い）ので、これがその設定キー。

**2026-09-30 22:05 時点の状態は OFF**（`checked="false"`、content-desc「オフ」）。
＝ サイレント自動ダウンロード経路は既に無効。09-24 以降 `.taiyi` が増えていないこととも整合する。

関連パッケージ:

| パッケージ | versionName | 役割 |
|---|---|---|
| com.xiaomi.aiservice | 3.1.7_65de523_260111_exp | Taiyi 本体（ダウンロード実行者） |
| com.xiaomi.aicr | 3.63.3 | AI エンジン / モデル管理 UI・設定の保持 |
| com.miui.gallery | 4.3.1.18-global | クライアント（AI 検索・タグ付け） |
| com.miui.mediaeditor | 2.4.0.5.2-global | クライアント（AI 編集） |
| com.android.providers.downloads | 25.02.07.109 | DownloadManager 本体（別名採番の実装側） |

`com.xiaomi.taiyi.plugin.tag` はインストール済みパッケージとしては存在しない（Taiyi の動的プラグイン）。
実体は `/data/user_de/0/com.xiaomi.aiservice/taiyi/plugin/tag/7/plugin-tag-tag-2.apk`（public、旧 `tag/2` は removed）。

---

## 7. 実施した対処

| 実施 | 内容 | 結果 |
|---|---|---|
| 重複削除 | 連番付き 255 ファイル / **10.81 GiB** を `find … -delete` で削除（基準名は温存） | `/sdcard` 空き **50G → 60G**、当該ディレクトリ **11G → 104M** |
| 常駐ガード | `/data/local/tmp/taiyi_guard.sh`（pid 稼働中） | 15 秒ごとに連番重複を検知 → 証拠（ls / DownloadProvider ダンプ / logcat）を `/data/local/tmp/taiyi_guard.log` に記録してから削除。3 件以上なら AIService を一時停止してから削除。基準名は絶対に消さない |
| logcat 常時記録 | `/data/local/tmp/taiyi_logcat.txt`（+`.1`〜`.3`, 8MB×3 ローテーション） | 再発時に前後のログを保全 |

ガードの検証: ダミーの `tag_new-999.taiyi` を置いて、検知 → 記録 → 削除（基準名は残存）まで確認済み。

- 停止: `adb shell "pkill -f '[t]aiyi_guard'"`
- 再開: `adb shell "nohup sh /data/local/tmp/taiyi_guard.sh > /dev/null 2>&1 &"`（再起動後は要再実行）
- ログ: `adb shell "cat /data/local/tmp/taiyi_guard.log"`
- ガードが AIService を停止した場合の復帰: `adb shell "cmd package unstop com.xiaomi.aiservice"`
  （Gallery 等で AI 機能を使えば自動再起動する）

---

## 8. 残っている選択肢（未実施）

1. **現状維持**（推奨）— 自動アップデートは OFF、ガードが常駐。再発しても増殖は数ファイルで止まり、証拠が残る
2. さらに抑えたい場合
   - `pm disable-user --user 0 com.xiaomi.aiservice` … 増殖は止まるが Gallery の AI タグ付け・検索・OCR 等が使えなくなる
   - `pm uninstall --user 0 com.xiaomi.aiservice` … `cmd package install-existing com.xiaomi.aiservice` で復元可能
   - `pm clear com.xiaomi.aiservice` は**逆効果**（全リソース再ダウンロード＋DB 消去）
3. 根本原因は HyperOS の DownloadProvider が「既存名を避けて別名を作る」実装にある。root が無いため修正不可。
   Xiaomi へフィードバックするなら「`com.xiaomi.aiservice` の AI リソース再ダウンロードで
   `-N` 付きファイルが無制限に増える」という症状がそのまま報告になる

---

## 9. 主要コマンド（再調査用）

```powershell
# 現状確認
adb shell "ls -la /sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/tag/7"
adb shell "du -sh /sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi"

# DownloadManager の登録内容（dumpsys download は本機に存在しない）
adb shell "dumpsys activity provider com.android.providers.downloads"

# Taiyi のログ
adb shell "grep -h -E 'Taiyi-Download|statisticsResource|checkDownloadAll' /data/local/tmp/taiyi_logcat.txt* | tail -40"

# ジョブ状態
adb shell "dumpsys jobscheduler | grep -A14 'JOB #u0a428/2001'"

# 重複削除（基準名は残す）
powershell -ExecutionPolicy Bypass -File .\cleanup_taiyi.ps1 -Execute
```

---

## 10. 2026-11-15 の再発（別リソース・設定では防げないことの確認）

前回（09-30）の掃除後、45 日間で**別のリソース**が同じ機構で増えていた。

| ディレクトリ | 増えていた数 | サイズ | バースト日時 |
|---|---|---|---|
| `plugin/wps/4/` | 56（`plugin-wps-wps-1-1` … `-1-55` と基準名） | 16,288,076 B × 56 = 851 MB | 10-24 16:30〜36 / 10-30 23:34〜50 |
| `plugin/ai_search_mtk/7/` | 106（`plugin-aisearch-aisearch_mtk-3` + `-3-1` …） | 12,621 B × 106 = 1.3 MB | 10-19 00:16 / 10-30 23:34〜37 |
| `plugin/tag/5`, `tag/7` | 各 1（増加なし） | 104 MB | — |

- 合計 **160 ファイル / 約 900 MB** を削除（977 MB → 120 MB）
- 空き容量の減少 13 GB のうち `.taiyi` は 0.9 GB。残りはゲーム（Arknights 16.3 GB /
  Limbus 18.8 GB / Blue Archive 11.8 GB）等で無関係

### 判明した追加事実

1. **`wps` はインストールされていない** — `dumpsys package com.xiaomi.aiservice` に出る
   `/data/user_de/0/com.xiaomi.aiservice/taiyi/plugin/` に `wps` が無い（ai_search_mtk/7,
   framework_compat/5, iqa/1, ocr/1, ocr_plugin_baidu/2, ocr_qnn/1, segment_v3_npu/3, tag/7 は存在）。
   よって `statisticsResource wps 4 required but not found!` が解消せず、ダウンロードだけが繰り返される。
   wps のインストール失敗理由はアプリ内部の問題で root 無しでは修正不可
2. **インストール済みのリソースでも再ダウンロードが起きる**（ai_search_mtk/7, tag/7）。
   本来は成功後にステージ済みファイルを削除する（09-30 の `framework_f3` で確認）が、走らない
3. **「Wi-Fiで自動アップデート」トグル（`ai_llm_wlan_auto_download_status`）は OFF のまま**で
   ダウンロードが発生した → **この設定では今回の経路を止められない**（09-30 時点の見立ては誤り）

### 対策ツール（この日の改修）

- `taiyi_clean.sh` — 全リソース共通の判定・削除。基準名ありなら連番のみ削除、
  基準名なしで 2 件以上の群は孤児として全削除、単独の `<stem>-<N>` は版番号の可能性があるため温存
- `cleanup_taiyi.ps1` — 上記の薄いラッパ。既定ドライラン、`-Execute` で削除
- `taiyi_guard.sh` — 端末常駐ガード v2（`taiyi_clean.sh` に委譲、15 秒間隔、
  検知時に ls / DownloadProvider ダンプ / logcat を `taiyi_guard.log` へ保存、5 件以上で AIService を一時停止）
  - 端末再起動で消えるため、必要なら再アームする:
    `adb push taiyi_guard.sh /data/local/tmp/` → `adb shell "nohup sh /data/local/tmp/taiyi_guard.sh > /dev/null 2>&1 &"`
  - 停止: `adb shell "pkill -f '[t]aiyi_guard'"`
- 自動化（タスクスケジューラ登録）はユーザー判断により**未実施**
