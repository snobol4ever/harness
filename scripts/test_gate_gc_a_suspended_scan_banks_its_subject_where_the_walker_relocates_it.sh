#!/usr/bin/env bash
# test_gate_gc_a_suspended_scan_banks_its_subject_where_the_walker_relocates_it.sh -- A GENERATOR THAT SUSPENDS INSIDE A
# SCAN BANKS ITS LIVE SUBJECT IN A FRAME WORD THE MAP DECLARES AS A COLLECTED-HEAP POINTER, SO A COLLECTION DURING THE
# SUSPENSION RELOCATES IT -- since hq_collector's chain step 2 (ARCH-GC 13.5) A DT_S CELL WHOSE TAG THE WALKER READS (cto 2026-09-23, CTO-154; law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812; hq_icon's
# IPL finding FINDING-2026-09-23-hq_icon-ipl-unitgenr-mode4-only-error-103-after-five-prior-allocation-cycles-gc-adjacent.md).
#
# MEASURED: unitgenr (corpus/packages/icon/ipl/gprogs, the last red of the IPL package in mode 4) died with error 103 in
# hex2bits("\xdb") at 128 KB -- the argument was a substring of vacated ground.  A gdb trace of rowbits' suspend and resume
# boxes over all 47 suspensions read ONE suspension straddling a collection, and at its resume both banked subject pointers
# (the inner scan's and the outer's) were unchanged while their bytes had become 0xDB.  THE MECHANISM: bb_gen_scan's
# suspend-leave path (op_sb == 2) banked r14 and rt_scan_live_subj()'s pointer at FRQ(op_ival) and FRQ(op_ival + 8), and
# for IR_SCAN zls_off is the RESULT slot, a 16-byte DESCR in the map -- so the delta sat in the tag word and the subject
# pointer was visited only when the delta's low byte happened to be a pointer-bearing tag (delta = 2 reads as DT_S, which is
# why most suspensions survived).  frame_layout.c already granted the node's own fields at result + 16 (the delta bank, RAW)
# and + 24 (declared an unused RAW pad).  THE CURE: the bank moves to + 16 / + 24, and + 24 is declared PTR_GC -- a
# collected-heap pointer, interior to its block, visited by rt_gc_visit_raw and relocated.  ARCH-GC 13.5 (hq_collector, the
# chain's step 2): the bank is a DT_S cell at + 16 {tag, slen = the carried length, s = the subject at + 24} with the delta at
# + 32, so a generator suspended off the chain keeps its subject through the spine sweep, which reads cells by tag.
# SCRIP_GC_PLANT_SCAN_BANK=1 tags the cell DT_I at emission: the walker reads an integer and the subject goes unseen.
#
# ARMS: (a) THE PROPERTY: the witness (a generator suspending inside a nested scan while its caller allocates) answers its
# iconx-cut ref at SCRIP_GC_STRESS=1,3,5 with SCRIP_GC_RELOC 0 and 1 at the compiled default arena, mode 3 and mode 4;
# (b) THE PLANT: SCRIP_GC_PLANT_SCAN_BANK=1 loses the answer at stress 1 in both modes -- the cure is load-bearing;
# (c) THE MAP: --dump-zeta of the witness declares "scan.suspend-leave live subject cell" a DESCR.  FAIL_ONCE=1 grades arm (a)
# against a corrupted copy of the iconx ref and requires it to red (CEO-1680 form (a)).
# ⛔⭐ (b) RETIRED UNDER CEO-1680 (cto 2026-10-17): the SCRIP_GC_PLANT_SCAN_BANK seam left emit.cpp (row emit-the-three-emitter-plants-...);
# its recorded reading is its fail-once: tagging the bank DT_I lost the answer at stress 1 in both modes, the cure load-bearing.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
W="$ROOT/../harness/scripts/gc_witnesses/hb_scan_suspend_bank_across_a_collection"; [ -s "$W.icn" ] && [ -s "$W.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: witness or its iconx ref missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; REF="$W.ref"; if [ "${FAIL_ONCE:-0}" = 1 ]; then { cat "$W.ref"; printf 'corrupted\n'; } > "$T/bad.ref"; REF="$T/bad.ref"; fi
build4() { ( cd "$T" && env $1 "$SCRIP" --compile "$W.icn" --out="$2.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie "$2.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$2" 2>/dev/null ); }
build4 "" w4 || { echo "  FAIL (a) the mode-4 witness did not build"; RC=1; }
band=""; bad=0
for st in 1 3 5; do for rl in 0 1; do
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=$rl SCRIP_GC_STRESS=$st timeout -k 5 60s "$SCRIP" --run "$W.icn" </dev/null > m3.out 2>/dev/null ); r=$?; if [ $r = 0 ] && cmp -s "$T/m3.out" "$REF"; then band="$band m3@$st/$rl:ok"; else band="$band m3@$st/$rl:red"; bad=$((bad+1)); fi
  if [ -x "$T/w4" ]; then ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=$rl SCRIP_GC_STRESS=$st timeout -k 5 60s ./w4 </dev/null > m4.out 2>/dev/null ); r=$?; if [ $r = 0 ] && cmp -s "$T/m4.out" "$REF"; then band="$band m4@$st/$rl:ok"; else band="$band m4@$st/$rl:red"; bad=$((bad+1)); fi; fi
done; done
if [ "$bad" = 0 ] && [ -x "$T/w4" ]; then echo "  ok   (a) THE PROPERTY: the suspended scan's subject survives collections during the suspension, stress 1/3/5 x flip 0/1, both modes --$band"
else echo "  FAIL (a) a suspended scan resumed on a stale subject --$band"; RC=1; fi
( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=1 timeout -k 5 60s "$SCRIP" --run "$W.icn" </dev/null >/dev/null 2>a2.err ); fa=$(grep -c "^\[GC-FLIP\] plant:" "$T/a2.err"); fa=${fa:-0}
if [ "$fa" -ge 1 ]; then echo "  ok   (a2) THE FLIP PLANT APPLIED: $fa banner line(s) at stress 1 -- the flip=1 half of (a) graded forced movement, not an unplanted run"
else echo "  FAIL (a2) the flip plant printed its applied banner $fa time(s) at SCRIP_HEAP_KB=512 stress 1 -- the flip=1 half of (a) may have graded a run nothing moved"; RC=1; fi
echo "  --   (b) RETIRED under CEO-1680: the SCRIP_GC_PLANT_SCAN_BANK seam left emit.cpp; its recorded reading (the witness lost its answer at stress 1 in both modes) is the fail-once (header)"
z=$( cd "$T" && "$SCRIP" --dump-zeta "$W.icn" 2>&1 | grep -c 'DESCR    scan.suspend-leave live subject cell' || true )
if [ "${z:-0}" -ge 1 ]; then echo "  ok   (c) the map declares the banked subject a DESCR cell ($z field(s) in the witness's graphs)"; else echo "  FAIL (c) no DESCR scan.suspend-leave live subject cell in the witness's layout -- the bank is invisible to the walker again"; RC=1; fi
echo "population: 2 arm(s) graded, (b) retired"
if [ $RC = 0 ]; then echo "✅ GATE PASS(0) [$G]: a suspended scan banks its subject where the walker relocates it"; else echo "⛔ GATE FAIL(1) [$G]: a suspended scan's subject is invisible to the collector (examined 3 arms)"; fi
exit $RC
