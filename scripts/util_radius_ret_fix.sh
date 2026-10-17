#!/usr/bin/env bash
# util_radius_ret_fix.sh — COMPILE-TIME MD5 BLAST RADIUS for SCRIP_RET_FIX (s112).
# Emits each program twice (RET_FIX=1 default, RET_FIX=0 killswitch) and reports
# how many differ.  Per GOAL-SNOBOL4-100 LAWS: never grade a codegen change on a
# single board run — measure the radius over the corpus first.
#
# Usage: bash ../harness/scripts/util_radius_ret_fix.sh [DIR ...]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
OUT=${OUT:-/tmp/radius_retfix}
rm -rf "$OUT"; mkdir -p "$OUT"
# library/probe_reference/bb's loose .sno files converted to suite format 2026-08-28 (probe-consolidate-bb, LON-20260828
# total conversion) -- this DIR now contributes 0 by construction. EXPECTED, not a regression.
DIRS=${*:-"$S4E/corpus/library/probe_reference/bb $S4E/corpus/tests/snobol4 $S4E/corpus/crosscheck"}
tot=0; diffn=0; failn=0
for d in $DIRS; do
    [ -d "$d" ] || continue
    for f in $(find "$d" -name '*.sno' | sort); do
        b=$(echo "$f" | md5sum | cut -c1-12)
        SCRIP_RET_FIX=1 timeout -k 5 25 "$SCRIP" --compile "$f" < /dev/null > "$OUT/$b.on.s"  2>/dev/null
        SCRIP_RET_FIX=0 timeout -k 5 25 "$SCRIP" --compile "$f" < /dev/null > "$OUT/$b.off.s" 2>/dev/null
        if [ ! -s "$OUT/$b.on.s" ] || [ ! -s "$OUT/$b.off.s" ]; then failn=$((failn+1)); continue; fi
        tot=$((tot+1))
        a=$(md5sum < "$OUT/$b.on.s" | cut -d' ' -f1)
        c=$(md5sum < "$OUT/$b.off.s" | cut -d' ' -f1)
        if [ "$a" != "$c" ]; then diffn=$((diffn+1)); echo "MOVED  $f"; fi
        rm -f "$OUT/$b.on.s" "$OUT/$b.off.s"
    done
done
echo "----"
echo "RADIUS: compared=$tot  differing=$diffn  emit-failed=$failn"
