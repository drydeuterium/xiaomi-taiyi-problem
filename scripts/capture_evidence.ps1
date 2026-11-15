# capture_evidence.ps1 -- collect a support-ready evidence bundle for the .taiyi issue
#
#   Usage:
#     powershell -ExecutionPolicy Bypass -File .\capture_evidence.ps1
#     (creates .\evidence\<timestamp>\ with file list, md5s, dumps, logcat, screenshots)
#
#   Run this while the .taiyi files are still there (before cleanup).
#
param([string]$OutDir = (Join-Path $PSScriptRoot 'evidence'))

$ErrorActionPreference = 'Continue'

$online = adb devices 2>&1 | Where-Object { $_ -match '\sdevice\s*$' }
if (-not $online) {
    Write-Host 'No adb device connected.'
    exit 1
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dir = Join-Path $OutDir $stamp
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$root = '/sdcard/Android/data/com.xiaomi.aiservice/files/download'

function Save-Text([string]$name, [string]$cmd) {
    $out = adb shell $cmd 2>&1
    Set-Content -Path (Join-Path $dir $name) -Value ($out -join "`r`n") -Encoding UTF8
    Write-Host "  wrote $name"
}

Write-Host "Collecting into $dir"

# 1. file listing (the money shot)
Save-Text '01_file_list.txt' "find $root -name '*.taiyi' -exec ls -la {} \;" 
Save-Text '02_counts.txt' "find $root -name '*.taiyi' | sed 's|/[^/]*$||' | sort | uniq -c; du -sh $root; df -h /sdcard | tail -1"

# 2. md5 (proves all copies are identical)
Save-Text '03_md5_sample.txt' "find $root -name '*.taiyi' | head -20 | xargs md5sum"

# 3. DownloadManager + package state
Save-Text '04_downloadprovider.txt' "dumpsys activity provider com.android.providers.downloads"
Save-Text '05_installed_plugins.txt' "dumpsys package com.xiaomi.aiservice | grep -oE '/data/user_de/0/com.xiaomi.aiservice/taiyi/plugin/[a-z0-9_]+/[0-9]+/[^ ]*' | sort -u"

# 4. logcat
Save-Text '06_logcat_taiyi.txt' "logcat -d -b all -v threadtime | grep -i -E 'taiyi|aiservice' | tail -800"

# 5. settings screen (screenshot + UI dump)
adb shell "am start -n com.xiaomi.aicr/.common.download.ModelActivity" | Out-Null
Start-Sleep -Seconds 3
$png = Join-Path $dir '07_model_settings.png'
cmd /c "adb exec-out screencap -p > `"$png`""
adb shell "uiautomator dump /sdcard/ui.xml" | Out-Null
adb pull /sdcard/ui.xml (Join-Path $dir '08_ui_dump.xml') 2>&1 | Out-Null
Write-Host "  wrote 07_model_settings.png / 08_ui_dump.xml"

Write-Host ''
Write-Host "Done. Attach 01/03/06 plus 07 to the support report."
Get-ChildItem $dir | ForEach-Object { Write-Host ("  {0}  {1:N0} B" -f $_.Name, $_.Length) }
