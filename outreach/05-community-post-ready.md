# Xiaomi Community 投稿用（コピペ用）

## 投稿先（ボード）の選び方

候補は 2 つ。**HyperOS の板**が本命、**端末板（Xiaomi 14T Pro）**は補助。

| 板 | 使いどころ |
|---|---|
| **HyperOS**（または HyperOS / Bug & Feedback 系） | 不具合の報告はここ。モデレーターが開発に上げる経路がある |
| 端末板（Xiaomi 14T Pro） | 同じ機種の人に当たりやすい。HyperOS 板と重複投稿になるので片方に絞るか、リンクで誘導 |

※ 板の名前は時期で変わる（"HyperOS" / "HyperOS 3" / "Feedback" など）。
　投稿画面で「HyperOS」で検索して、いちばん人が多い板を選べばよい。

---

## タイトル（どれか 1 つ）

1. `HyperOS bug: AI resource files (.taiyi) keep re-downloading and fill storage (11.7 GB)`
2. `[Bug] com.xiaomi.aiservice re-downloads the same AI model forever — 11.7 GB of duplicates`
3. `[Bug] AI resources pile up in Android/data/com.xiaomi.aiservice — 257 duplicate .taiyi files`

→ 1 が無難。数字が入っていると開かれやすい。

---

## 本文（英語・そのまま貼る）

```
Device: Xiaomi 14T Pro (A402XM / rothko_jp, SoftBank JP carrier model)
ROM: HyperOS OS3.0.4.0.WNNJPSB / Android 16
Stock, not rooted. Affected components: com.xiaomi.aiservice 3.1.7_65de523_260111_exp,
com.android.providers.downloads 25.02.07.109

■ What happens

The Taiyi AI framework (com.xiaomi.aiservice) keeps re-downloading the same resource
package into:

  /sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/<resource>/<version>/

Because the destination filename is always the same and the HyperOS DownloadProvider
never overwrites, each retry is saved as tag_new-1.taiyi, tag_new-2.taiyi, ... and the
staged file is never cleaned up.

■ Measured (two incidents)

  2026-09-30  plugin/tag/7/            81 files   5.9 GB  (up to tag_new-162.taiyi)
  2026-09-30  plugin/tag/5/           176 files   4.9 GB  (up to tag2-316.taiyi)
  2026-11-15  plugin/wps/4/            56 files   851 MB
  2026-11-15  plugin/ai_search_mtk/7/ 106 files   1.3 MB

  Total ~11.7 GB. Every copy is byte-identical (md5 27605b3ab7ee8a2910c281e9c74efa33).
  ~100 copies of a 78 MB file were created within ~2 minutes.

■ Root cause (logcat)

  Taiyi-Download-MIDownloadManager: start framework_f3:7 enqueue = 16054
  DownloadManager_Job: frompackage=com.xiaomi.aiservice, uri=https://ai-model-cdn-intl...
  DownloadManager: Deleting .../framework_f3/7/plugin-framework-framework_f3-7.taiyi via provider delete

The happy path exists: download -> installSync -> delete the staged file (confirmed with
framework_f3). It does not run for tag / wps / ai_search. `wps` is not even installed, so
"statisticsResource wps 4 required but not found!" never resolves and the download loops.

■ The user cannot stop it

"Model management -> Wi-Fi auto update" is OFF and downloads still happen. There is no UI
to delete or reset a failed AI resource.

■ Evidence

Full logs, ls -la, screenshot and a cleanup script:
https://github.com/drydeuterium/xiaomi-taiyi-problem

■ Request

Please confirm whether this is a known issue / already tracked, and route it to the
HyperOS AI service team. Suggested fix: always delete the staged .taiyi after install and
on failure, reuse or overwrite an existing destination instead of appending -N, and cap
retries for resources that fail to install.

Xiaomi Japan support replied that this is a carrier model and cannot be handled there,
but the affected components are Xiaomi system apps shipped in the ROM.
```

---

## タグ

`HyperOS` / `Bug` / `Storage` / `AI`（板のタグ機能がある場合）

---

## 添付

- `docs/taiyi-report-ja.pdf` … Community は PDF 添付ができないことが多いので、
  画像（`evidence/2026-11-15-model-settings-off.png`）を 1 枚だけ添付し、PDF は
  GitHub のリンクで示すのが確実

---

## 投稿できないときのチェック

- Xiaomi アカウントでログインしているか（Community はアカウント必須）
- 板によってはアカウントレベル（投稿数・活動）が必要なことがある
  → まずプロフィールを設定し、既存スレッドに数回返信してから投稿する
- 画像サイズが大きすぎると弾かれる（スクショは 1220x2712 / 290KB なので問題ないはず）

---

## 併用したい公式ルート

Community のモデレーターは「不具合は端末内の
**Services & feedback（サービスとフィードバック）** から送ってください」と必ず案内する。
**Community 投稿と同時に、端末内フィードバックでも送るのが最短**（こちらにはログが付く）。

海外窓口のメールアドレス（Community 上で案内されているもの）:

- `support.global@support.mi.com`
- `xiaomi-feedback@xiaomi.com`

※ どちらも Community の投稿内で案内されていた連絡先。到達性は保証されないが、
　日本窓口で跳ね返された場合は試す価値がある。英文 + PDF 添付で送る。
