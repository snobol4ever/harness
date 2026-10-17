#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
SAME=0; DIFF=0; SKIP=0
DIFFLIST=""
for f in $(find "$HERE/../../corpus/tests/scrip_test/snobol4" -name "*.sno" | sort); do
  rel="${f#$HERE/../../SCRIP/}"
  old_raw=$(SCRIP_NL=0 timeout -k 5 15s "$SCRIP" --run "$f" < /dev/null 2>&1); old_rc=$?
  new_raw=$(SCRIP_NL=1 timeout -k 5 15s "$SCRIP" --run "$f" < /dev/null 2>&1); new_rc=$?
  old_out=$(printf '%s' "$old_raw" | grep -v '^\[lower\]')
  new_out=$(printf '%s' "$new_raw" | grep -v '^\[lower\]')
  if [ $old_rc -ge 124 ] && [ $new_rc -ge 124 ]; then SKIP=$((SKIP+1)); continue; fi
  if [ "$old_out" = "$new_out" ] && [ "$old_rc" = "$new_rc" ]; then
    SAME=$((SAME+1))
  else
    DIFF=$((DIFF+1)); DIFFLIST="$DIFFLIST $rel"
    echo "DIFF  $rel  (old_rc=$old_rc new_rc=$new_rc)"
  fi
done
echo "----"
echo "SNO m2 cross-check: SAME=$SAME DIFF=$DIFF SKIP=$SKIP"
[ -n "$DIFFLIST" ] && echo "DIFFS:$DIFFLIST"
