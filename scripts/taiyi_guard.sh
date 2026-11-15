#!/system/bin/sh
# taiyi_guard.sh — .taiyi の重複を検知したら証拠を残して自動削除する
#   実体の判定・削除は /data/local/tmp/taiyi_clean.sh に委譲
#   5 件以上たまったら AIService を一時停止してから削除 (帯域の無駄遣いを止める)
ROOT=/sdcard/Android/data/com.xiaomi.aiservice/files/download
OUT=/data/local/tmp/taiyi_guard.log
CLEAN=/data/local/tmp/taiyi_clean.sh
DM="dumpsys activity provider com.android.providers.downloads"

echo "===== guard start $(date) =====" >> $OUT

while true; do
  n=$(sh $CLEAN list 2>/dev/null | tail -1 | sed 's/TOTAL=//')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac

  if [ "$n" -gt 0 ]; then
    {
      echo "===== DUP DETECTED $(date) count=$n ====="
      find $ROOT -name '*.taiyi' -exec ls -la {} \; 2>/dev/null
      echo "--- candidates ---"
      sh $CLEAN list 2>/dev/null
      echo "--- downloadprovider ---"
      $DM
      echo "--- logcat ---"
      logcat -d -b all -v threadtime 2>/dev/null | grep -i -E 'taiyi|aiservice' | tail -200
      echo "===== end ====="
    } >> $OUT 2>&1

    if [ "$n" -ge 5 ]; then
      am force-stop com.xiaomi.aiservice
      {
        echo "force-stop com.xiaomi.aiservice ($(date))"
        echo "NOTE: Gallery 等で AI 機能を使えば再起動する。手動復帰: cmd package unstop com.xiaomi.aiservice"
      } >> $OUT
      sleep 20
    fi

    sh $CLEAN delete >> $OUT 2>&1
  fi
  sleep 15
done
