#!/usr/bin/env bash
# util_radius_sr3_fix.sh — COMPILE-TIME MD5 BLAST RADIUS for SCRIP_SR3_FIX (s113).
# The fix adds the missing UNION TAG CHECK to the emit.cpp IR_SAVE_RESTORE role-3
# wire-adopt shim (IR_LIT is a union; sval aliases ival, so an IR_LIT_INTEGER gamma
# was strncmp'd as a pointer).  Emits each program twice (SR3_FIX=1 default,
# SR3_FIX=0 killswitch) and reports how many differ.  Per GOAL-SNOBOL4-100 LAWS:
# never grade a codegen change on a single board run — measure the radius first.
# Programs that CRASH the emitter under the killswitch are counted separately:
# they are the fix's customers, not radius movers.
#
# Usage: bash ../harness/scripts/util_radius_sr3_fix.sh [DIR ...]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
OUT=${OUT:-/tmp/radius_sr3}
rm -rf "$OUT"; mkdir -p "$OUT"
# library/probe_reference/bb's loose .sno files converted to suite format 2026-08-28 (probe-consolidate-bb, LON-20260828
# total conversion) -- this DIR now contributes 0 by construction. EXPECTED, not a regression.
DIRS=${*:-"$S4E/corpus/library/probe_reference/bb $S4E/corpus/tests/snobol4 $S4E/corpus/crosscheck"}
tot=0; diffn=0; failn=0; curedn=0
for d in $DIRS; do
    [ -d "$d" ] || continue
    for f in $(find "$d" -name '*.sno' | sort); do
        b=$(echo "$f" | md5sum | cut -c1-12)
        SCRIP_SR3_FIX=1 timeout -k 5 25 "$SCRIP" --compile "$f" < /dev/null > "$OUT/$b.on.s"  2>/dev/null
        SCRIP_SR3_FIX=0 timeout -k 5 25 "$SCRIP" --compile "$f" < /dev/null > "$OUT/$b.off.s" 2>/dev/null
        roff=$?
        if [ -s "$OUT/$b.on.s" ] && [ $roff -eq 139 ]; then curedn=$((curedn+1)); echo "CURED  $f"; rm -f "$OUT/$b.on.s" "$OUT/$b.off.s"; continue; fi
        if [ ! -s "$OUT/$b.on.s" ] || [ ! -s "$OUT/$b.off.s" ]; then failn=$((failn+1)); rm -f "$OUT/$b.on.s" "$OUT/$b.off.s"; continue; fi
        tot=$((tot+1))
        a=$(md5sum < "$OUT/$b.on.s" | cut -d' ' -f1)
        c=$(md5sum < "$OUT/$b.off.s" | cut -d' ' -f1)
        if [ "$a" != "$c" ]; then diffn=$((diffn+1)); echo "MOVED  $f"; fi
        rm -f "$OUT/$b.on.s" "$OUT/$b.off.s"
    done
done
echo "----"
echo "RADIUS: compared=$tot  differing=$diffn  cured-emitter-crash=$curedn  emit-failed=$failn"
