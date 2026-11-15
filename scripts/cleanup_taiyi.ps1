# cleanup_taiyi.ps1 -- delete duplicate .taiyi files (dry run by default)
#
#   Checks all resource dirs under:
#     /sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi
#   and removes only "<stem>-<N>.taiyi" copies, keeping "<stem>.taiyi".
#   A lone "<stem>-<N>.taiyi" (possible version suffix) is never touched.
#
#   Usage:
#     powershell -ExecutionPolicy Bypass -File .\cleanup_taiyi.ps1           # dry run
#     powershell -ExecutionPolicy Bypass -File .\cleanup_taiyi.ps1 -Execute  # delete
#
param([switch]$Execute)

$ErrorActionPreference = 'Continue'
$root = '/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi'
$cleaner = Join-Path $PSScriptRoot 'taiyi_clean.sh'

$online = adb devices 2>&1 | Where-Object { $_ -match '\sdevice\s*$' }
if (-not $online) {
    Write-Host 'No adb device connected.'
    exit 1
}

adb push $cleaner /data/local/tmp/taiyi_clean.sh 2>&1 | Out-Null
adb shell "chmod 755 /data/local/tmp/taiyi_clean.sh" | Out-Null

$mode = if ($Execute) { 'delete' } else { 'list' }
$out = adb shell "sh /data/local/tmp/taiyi_clean.sh $mode" 2>&1
$totalLine = $out | Where-Object { $_ -match '^TOTAL=(\d+)' } | Select-Object -Last 1
$count = if ($totalLine -and ($totalLine -match '^TOTAL=(\d+)')) { $matches[1] } else { '?' }

if ($Execute) {
    Write-Host "Deleted $count duplicate file(s)."
} else {
    Write-Host "Duplicates found: $count (nothing deleted). Use -Execute to delete."
    $out | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
}

Write-Host ''
adb shell "du -sh $root; df -h /sdcard | tail -1" 2>&1 | ForEach-Object { Write-Host $_ }
