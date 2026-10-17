#!/usr/bin/env bash
# test_gate_s130_blast.sh -- s130 KILLSWITCH BYTE-IDENTITY BLAST RADIUS (two-phase).
# Phase A installs the BASELINE {scrip, out/libscrip_rt.so} pair and records md5 of every
# emitted mode-4 .s; phase B installs the POST-CHANGE pair in its DEFAULT arm and does the
# same; the tallies are then diffed.  The .so is SWAPPED IN PLACE, never LD_PRELOADed and
# never the driver alone -- the emitter lives in libscrip_rt.so (the s68 vacuous-gate law).
# Usage: test_gate_s130_blast.sh record <tag> <scrip> <rt.so>   |   compare <tagA> <tagB>
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
ROOT=${ROOT:-$S4E/corpus}
SETS=${SETS:-"crosscheck snobol4 probe"}
. "$(dirname "$0")/lib_gate.sh"
# ⭐ V2-5 GATE HONESTY: compare had no existence check -- two nonexistent files reported MOVERS=0, exit 0.
[ $# -ge 1 ] || { echo "GATE UNPROVEN(2) [s130_blast]: no mode given. usage: record <tag> <scrip> <rt.so> | compare <tagA> <tagB>"; exit 2; }
case "$1" in
record)
  tag=$2; S=$3; RT=$4; out=/tmp/s130_$tag.md5; : > "$out"
  cp -f "$S" $S4E/SCRIP/scrip; cp -f "$RT" $S4E/SCRIP/out/libscrip_rt.so
  for s in $SETS; do
    for f in $(find "$ROOT/$s" -name '*.sno' | sort); do
      o=/tmp/s130_one.s
      timeout -k 5 15 $S4E/SCRIP/scrip --compile "$f" > "$o" 2>/dev/null; rc=$?
      echo "$(md5sum < "$o" | cut -d' ' -f1) rc=$rc $f" >> "$out"
    done
  done
  echo "recorded $(wc -l < "$out") programs -> $out"
  gate_floor "$(wc -l < "$out")" 1 "programs recorded" ;;
compare)
  a=/tmp/s130_$2.md5; b=/tmp/s130_$3.md5
  gate_require "$a" "recorded md5 set for tag A ($2)"; gate_require "$b" "recorded md5 set for tag B ($3)"
  n=$(wc -l < "$a"); d=$(diff "$a" "$b" | grep -c '^<')
  gate_floor "$n" 1 "recorded programs in tag A"
  echo "s130 blast radius: TOTAL=$n MOVERS=$d"
  # ⛔ cap announces itself (hq_B 2026-08-29): MOVERS=$d is printed above, so a shorter list must say so.
  [ "$d" -gt 0 ] && { echo "MOVERS:";
    if [ -n "${GATE_LIST_ALL:-}" ]; then diff "$a" "$b" | grep '^<' | awk '{print "  "$NF}';
    else diff "$a" "$b" | grep '^<' | awk '{print "  "$NF}' | head -40
         [ "$d" -gt 40 ] && echo "  ... and $((d - 40)) MORE NOT SHOWN -- capped at 40; $d above is the true count. Full list: GATE_LIST_ALL=1"; fi; }
  [ "$d" -eq 0 ] ;;
*)
  echo "GATE UNPROVEN(2) [s130_blast]: unknown mode '$1'. usage: record <tag> <scrip> <rt.so> | compare <tagA> <tagB>"; exit 2 ;;
esac
