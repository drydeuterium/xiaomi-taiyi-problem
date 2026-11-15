#!/system/bin/sh
# taiyi_clean.sh [list|delete]
#   <stem>-<N>.taiyi 形式の重複だけを対象にする。
#   ・<stem>.taiyi が存在する → その <stem>-<N> 群を削除 (基準名は残す)
#   ・基準名が無く <stem>-<N> が 2 件以上 → 孤児化した重複とみなし全削除
#   ・単独の <stem>-<N>.taiyi は版番号の可能性があるので触らない
MODE=${1:-list}
ROOT=/sdcard/Android/data/com.xiaomi.aiservice/files/download/taiyi
DEL=0

for d in $(find $ROOT -type d 2>/dev/null); do
  ls "$d" 2>/dev/null | grep -q '\.taiyi$' || continue
  for f in $(ls "$d" 2>/dev/null | grep '\.taiyi$'); do
    case "$f" in
      *-[0-9]*.taiyi) ;;
      *) continue ;;
    esac
    stem=$(echo "$f" | sed 's/-[0-9][0-9]*\.taiyi$//')
    cnt=$(ls "$d" 2>/dev/null | grep -c "^$stem-[0-9][0-9]*\.taiyi$")
    if [ -f "$d/$stem.taiyi" ] || [ "$cnt" -ge 2 ]; then
      sz=$(stat -c %s "$d/$f" 2>/dev/null)
      DEL=$((DEL+1))
      [ "$MODE" = delete ] && rm -f "$d/$f"
      echo "$MODE $d/$f ($sz)"
    fi
  done
done
echo "TOTAL=$DEL"
