#!/usr/bin/env bash
# util_radius_src_reset.sh — COMPILE-TIME MD5 BLAST RADIUS for SCRIP_SRC_RESET (s115).
# The fix resets g_bb_src (the pointer-keyed statement-head table read by zd_plan's
# run formation) at every runtime-compile entry, exactly as fc_tables_reset (s67)
# already does for its pointer-keyed siblings.  g_bb_src is read by EVERY language's
# run walk, so the radius must be measured ACROSS LANGUAGES, not on the SNOBOL4 board
# alone — the s203 ZW-1 lesson named in GOAL-SNOBOL4-100's LAWS.
#
# EXPECTATION: 0 differing.  bb_src_reset fires only from runtime-compile entries
# (eval_build_chain, bb_compile_pat_tree), which do not run during --compile, so
# static emission cannot move.  A non-zero count falsifies that and must be read
# before the killswitch is defaulted on.
#
# Usage: bash ../harness/scripts/util_radius_src_reset.sh [DIR ...]
#   KILLSWITCH=SCRIP_FOO  bash ../harness/scripts/util_radius_src_reset.sh [DIR ...]
# KILLSWITCH names the env var A/B'd (default SCRIP_SRC_RESET, this script's
# original subject).  s116 generalised it rather than mint a near-duplicate
# script: the radius METHOD — compile the same corpus twice on ONE binary and
# md5 the two .s streams — is identical for every killswitch, and a second copy
# would be the "spelled-twice disease" the goal file's ONE AUTHORITY law names.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
OUT=${OUT:-/tmp/radius_src_reset}
KILLSWITCH=${KILLSWITCH:-SCRIP_SRC_RESET}
rm -rf "$OUT"; mkdir -p "$OUT"
# library/probe_reference/bb's loose .sno files converted to suite format 2026-08-28 (probe-consolidate-bb, LON-20260828
# total conversion) -- this DIR now contributes 0 by construction. EXPECTED, not a regression.
DIRS=${*:-"$S4E/corpus/library/probe_reference/bb $S4E/corpus/tests/snobol4 $S4E/corpus/crosscheck $S4E/corpus/probe/eval $S4E/corpus/tests/icon $S4E/corpus/tests/prolog"}
tot=0; diffn=0; failn=0
for d in $DIRS; do
    [ -d "$d" ] || continue
    for f in $(find "$d" \( -name '*.sno' -o -name '*.icn' -o -name '*.pl' \) | sort); do
        b=$(echo "$f" | md5sum | cut -c1-12)
        env "$KILLSWITCH=1" timeout -k 5 25 "$SCRIP" --compile "$f" < /dev/null > "$OUT/$b.on.s"  2>/dev/null
        env "$KILLSWITCH=0" timeout -k 5 25 "$SCRIP" --compile "$f" < /dev/null > "$OUT/$b.off.s" 2>/dev/null
        if [ ! -s "$OUT/$b.on.s" ] || [ ! -s "$OUT/$b.off.s" ]; then failn=$((failn+1)); rm -f "$OUT/$b.on.s" "$OUT/$b.off.s"; continue; fi
        tot=$((tot+1))
        a=$(md5sum < "$OUT/$b.on.s" | cut -d' ' -f1)
        c=$(md5sum < "$OUT/$b.off.s" | cut -d' ' -f1)
        if [ "$a" != "$c" ]; then diffn=$((diffn+1)); echo "MOVED  $f"; fi
        rm -f "$OUT/$b.on.s" "$OUT/$b.off.s"
    done
done
echo "----"
echo "RADIUS: compared=$tot  differing=$diffn  emit-failed=$failn"
