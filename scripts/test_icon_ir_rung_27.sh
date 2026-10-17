#!/bin/bash
# run_rung27.sh — rung27_read corpus runner (M-IJ-READ)
cd "$(dirname "$0")/../../.."
PASS=0; FAIL=0; XFAIL=0
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RUNG_DIR="${CORPUS_REPO:-$(cd "$SCRIPT_DIR/../../.." && pwd)/corpus}/icon"
for icn in "$RUNG_DIR"/rung27_read_*.icn; do
  base="${icn%.icn}"; exp="$base.ref"; [ -f "$exp" ] || continue
  [ -f "$base.xfail" ] && { XFAIL=$((XFAIL+1)); echo "XFAIL: $(basename $icn)"; continue; }
  ${1:-/tmp/scrip-cc} -jvm "$icn" -o /tmp/t27.j 2>/dev/null
  timeout -k 5 30 java -jar miscellaneous/jasmin.jar /tmp/t27.j -d /tmp/ 2>/dev/null
  cls=$(grep -m1 '\.class' /tmp/t27.j | awk '{print $NF}')
  stdin_f="$base.stdin"; [ -f "$stdin_f" ] || stdin_f="$(dirname "$base")/config/$(basename "$base").stdin"
  if [ -f "$stdin_f" ]; then
    got=$(timeout -k 5 5 java -cp /tmp/ "$cls" < "$stdin_f" 2>/dev/null)
  else
    got=$(timeout -k 5 5 java -cp /tmp/ "$cls" 2>/dev/null)
  fi
  want=$(cat "$exp")
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); echo "PASS: $(basename $icn)"
  else FAIL=$((FAIL+1)); echo "FAIL: $(basename $icn)"; echo "  want: $(echo "$want"|tr '\n' '|')"; echo "  got:  $(echo "$got"|tr '\n' '|')"; fi
done
echo "--- rung27: $PASS pass, $FAIL fail, $XFAIL xfail ---"
[ $FAIL -eq 0 ]
