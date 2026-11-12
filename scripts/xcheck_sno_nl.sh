#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
SAME=0; DIFF=0; SKIP=0
DIFFLIST=""
# ⭐ THE POPULATION IS THE SNOBOL4 MASTER'S scrip_test_snobol4_* ENTRIES, extracted (the cfo 2026-11-12, corpus/tests/scrip_test consolidated: its loose corpus/tests/scrip_test/snobol4
# programs were each byte for byte one of them); none extracted REFUSES, never a clean SAME=0 DIFF=0.
XD="$(mktemp -d)"; trap 'rm -rf "$XD"' EXIT
RUNGS_LANG=snobol4 . "$HERE/lib_rungs_extract.sh" || exit 2
rungs_extract_origin_prefix scrip_test_snobol4_ "$XD" || { echo "REFUSE(2): the scrip_test_snobol4_ entries did not extract"; exit 2; }
[ -n "$(find "$XD" -name '*.sno' | head -1)" ] || { echo "REFUSE(2): no scrip_test_snobol4_ entry in the snobol4 master"; exit 2; }
for f in $(find "$XD" -name "*.sno" | sort); do
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
