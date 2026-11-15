# [Bug] AI resource files (.taiyi) are downloaded over and over and fill storage (11.7 GB observed)

**Device:** Xiaomi 14T Pro (A402XM / rothko_jp, SoftBank JP carrier model) — stock, not rooted
**ROM:** HyperOS OS3.0.4.0.WNNJPSB / Android 16
**Affected:** `com.xiaomi.aiservice` 3.1.7_65de523_260111_exp (310067), `com.android.providers.downloads` 25.02.07.109

## Summary

`com.xiaomi.aiservice` (Taiyi framework) keeps re-downloading the same AI resource package.
Because the destination path already exists, the HyperOS DownloadProvider appends `-1`, `-2`, …
instead of overwriting, and the staged file is never cleaned up. Storage grows without limit.

Location:

```
/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi/plugin/<resource>/<version>/
```

## Observed (two separate incidents)

| Date | Directory | Files | Size |
|---|---|---|---|
| 2026-09-30 | `plugin/tag/7/` | 81 (up to `tag_new-162.taiyi`) | 5.9 GB |
| 2026-09-30 | `plugin/tag/5/` | 176 (up to `tag2-316.taiyi`) | 4.9 GB |
| 2026-11-15 | `plugin/wps/4/` | 56 | 851 MB |
| 2026-11-15 | `plugin/ai_search_mtk/7/` | 106 | 1.3 MB |

- All copies in a directory are **byte-identical** (`md5 27605b3ab7ee8a2910c281e9c74efa33` for the 78 MB files)
- ~100 copies of a 78 MB file were created within ~2 minutes
- Total: **~11.7 GB**

## Cause (verified in logcat)

```
Taiyi-Service(aiservice:main)-AIConfigurations: statisticsResource framework_f3 7 required but not found!
Taiyi-Download-TaiyiDownloader: downloadFileInner start: DownloadFile(id=framework_f3:7, name=plugin-framework-framework_f3-7.taiyi, ...)
Taiyi-Download-MIDownloadManager: start framework_f3:7 enqueue = 16054
DownloadManager_Job: use xunlei (false) , id=16054,tid=260 frompackage=com.xiaomi.aiservice,
  uri=https://ai-model-cdn-intl.engine.miui.com/ai-taiyi-platform-bucket/deploy/plugin/<uuid>/...
DownloadManager: Deleting .../framework_f3/7/plugin-framework-framework_f3-7.taiyi via provider delete
```

The happy path *does* exist: download → `installSync` → delete the staged file
(confirmed with `framework_f3`). It simply does not run for `tag`, `wps` or `ai_search`.
`wps` is not even installed (`/data/user_de/0/com.xiaomi.aiservice/taiyi/plugin/` has no `wps`
directory), so `required but not found` never resolves and the download loops forever.

## The user cannot stop it

Turning **Model management → "Wi-Fi auto update" OFF** does *not* stop it
(`ai_llm_wlan_auto_download_status`; verified via uiautomator dump `checked="false"`).
There is no UI to delete or reset a failed resource.

## Reproduction

Wi-Fi connected + charging + device idle (JobScheduler `AIJobService#2001`), or simply using
Gallery's AI features (search / tagging). Trigger repeats on app launch and network change.

## Proposed fix

1. Always delete the staged `.taiyi` after install **and on failure**
2. If the destination exists, reuse or overwrite it instead of creating `-N` copies
3. Cap retries / add backoff for a resource that keeps failing to install
4. Expose a way for users to delete / reset a failed AI resource

## Request

Please route this to the HyperOS / AI service engineering team.
Happy to provide full logs (`adb logcat`, `dumpsys`) and a step-by-step capture if useful.

Xiaomi Japan support ticket: X26111541474 (they bounced it back to the carrier because it is a
carrier model, although the affected components are Xiaomi system apps).

