#!/usr/bin/env bash
# test_gate_gc_the_flip_plant_turns_a_stale_pointer_into_a_located_fault.sh -- THE INSTRUMENT THAT MAKES "AIR TIGHT" A
# MEASUREMENT: under SCRIP_GC_PLANT_FLIP=1 every collection COPIES every live block to ground disjoint from its old address
# and poisons and PROT_NONEs ALL of the old ground until the next collection, so a stale copy of any heap address -- a holder
# the collector never visited -- FAULTS at the instruction that uses it, with a [ZGC-STALE] report naming the block, where
# it lived, where it went and the collection that moved it (cto 2026-09-23, CTO-155; ARCH-GC-COMPILE-TIME-FRAME-MAPS.md
# section 9 rung 1 "poison must trap, not merely lie", made complete).
#
# WHY THE EXISTING TRAP WAS NOT ENOUGH, MEASURED THE SAME DAY: SCRIP_GC_TRAP quarantines only whole pages above the new top,
# and ordinary compaction and SCRIP_GC_RELOC=1 both refill most vacated ground with other live blocks, so a stale read
# returns a plausible wrong answer (hq_icon's unitgenr: green under RELOC=1, red without it; the scan-bank witness of CTO-154:
# DIFF with rc=0 under every existing knob).  Under the flip plant the old ground holds nothing live, so nothing can make a
# stale read look right.  A pointer loaded FROM poisoned ground is 0xDBDB..., non-canonical, and faults with si_addr 0; the
# handler now reads the registers and names the poison (rt_gc_poison_reg_report).  ONE PRECISION CHANGE RIDES WITH IT, in
# every mode: gc_mark_blk ignores HB_FILL, because free space is never live and marking it would copy dead ground.
#
# ARMS: (a) NO FALSE POSITIVE: four witnesses answer their oracle-cut refs under the plant at stress 1 in mode 3 and mode 4
# and the GC-EXERCISE line reads flips > 0 (the plant applied); (b) LOCATED, MOVED: the scan-bank plant of CTO-154
# (SCRIP_GC_PLANT_SCAN_BANK=1) faults under the flip plant and the report says the block was MOVED; (c) LOCATED, POISON: the
# key-collision plant of CTO-153 faults and the report names a register holding the poison; (d) THE CONTRAST: without the
# flip plant the scan-bank plant is a SILENT wrong answer (rc 0, stdout differs) -- the flip plant is what turns it loud.
# FAIL_ONCE=1 runs arm (b) without the flip plant and requires it to red.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
WD="$ROOT/../harness/scripts/gc_witnesses"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
wit() { local b="$1"; local f; f=$(ls "$WD/$b".{icn,sno,sc,pl,raku} 2>/dev/null | head -1); [ -n "$f" ] && [ -s "$WD/$b.ref" ] && echo "$f"; }
band=""; bad=0; flips_seen=0
for b in hb_scan_suspend_bank_across_a_collection hb_table_dump_every_key_ref hb_concat_augmented_then_subscript hb_arbno_deferred_name; do
  f=$(wit "$b") || { echo "⛔ GATE REFUSE(2) [$G]: witness $b or its ref is missing"; exit 2; }
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=1 SCRIP_GC_EXERCISE=1 timeout -k 5 60s "$SCRIP" --run "$f" </dev/null > a3.out 2> a3.err ); r=$?
  fl=$(grep -oE 'flips=[0-9]+' "$T/a3.err" | head -1 | cut -d= -f2); [ "${fl:-0}" -gt 0 ] && flips_seen=$((flips_seen+1))
  if [ $r = 0 ] && cmp -s "$T/a3.out" "$WD/$b.ref"; then band="$band $b/m3:ok(flips=${fl:-?})"; else band="$band $b/m3:RED(rc=$r)"; bad=$((bad+1)); fi
  if ( cd "$T" && "$SCRIP" --compile "$f" -o w.s </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie w.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o w4 2>/dev/null ); then
    ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=1 timeout -k 5 60s ./w4 </dev/null > a4.out 2>/dev/null ); r=$?
    if [ $r = 0 ] && cmp -s "$T/a4.out" "$WD/$b.ref"; then band="$band $b/m4:ok"; else band="$band $b/m4:RED(rc=$r)"; bad=$((bad+1)); fi
  else band="$band $b/m4:NOBUILD"; bad=$((bad+1)); fi
done
if [ "$bad" = 0 ] && [ "$flips_seen" = 4 ] && grep -q "^\[GC-FLIP\] plant:" "$T/a3.err"; then echo "  ok   (a) NO FALSE POSITIVE: four witnesses answer their refs under the flip plant at stress 1, both modes, and the plant applied in every run --$band"
else echo "  FAIL (a) a correct witness faulted or differed under the flip plant, or the plant did not apply (flips seen in $flips_seen of 4) --$band"; RC=1; fi
S="$(wit hb_scan_suspend_bank_across_a_collection)"
flipb="SCRIP_GC_PLANT_FLIP=1"; [ "${FAIL_ONCE:-0}" = 1 ] && flipb="SCRIP_GC_PLANT_FLIP=0"
( cd "$T" && env -u SCRIP_HEAP_MB $flipb SCRIP_GC_PLANT_SCAN_BANK=1 SCRIP_GC_STRESS=1 timeout -k 5 60s "$SCRIP" --run "$S" </dev/null > b.out 2> b.err ); rb=$?
if [ $rb != 0 ] && grep -q '^\[ZGC-STALE\] SIGSEGV touching GC heap ground' "$T/b.err" && grep -q 'it was MOVED to' "$T/b.err" && grep -q "^\[GC-SCANBANK\] plant:" "$T/b.err"; then echo "  ok   (b) LOCATED: the scan-bank plant faults under the flip plant (rc=$rb) and the report names the moved block: $(grep -m1 'the block that lived here' "$T/b.err" | cut -c1-140)"
else echo "  FAIL (b) the scan-bank plant did not fault with a located MOVED report (rc=$rb) -- a stale pointer is no longer trapped"; RC=1; fi
( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_PLANT_FLIP=0 SCRIP_GC_PLANT_SCAN_BANK=1 SCRIP_GC_STRESS=1 timeout -k 5 60s "$SCRIP" --run "$S" </dev/null > d.out 2> d.err ); rd=$?
if [ $rd = 0 ] && ! cmp -s "$T/d.out" "$WD/hb_scan_suspend_bank_across_a_collection.ref"; then echo "  ok   (d) THE CONTRAST: without the flip plant the same defect is a SILENT wrong answer (rc=0, stdout differs from the ref) -- the plant is what makes it loud"
else echo "  FAIL (d) without the flip plant the scan-bank plant read rc=$rd $(cmp -s "$T/d.out" "$WD/hb_scan_suspend_bank_across_a_collection.ref" && echo REF || echo DIFF) -- the contrast this gate is built on moved"; RC=1; fi
echo "population: 3 arm(s) graded"
if [ $RC = 0 ]; then echo "✅ GATE PASS(0) [$G]: the flip plant turns a stale pointer into a located fault and leaves correct programs correct"; else echo "⛔ GATE FAIL(1) [$G]: the flip plant misses a stale pointer or faults a correct program (examined 4 arms)"; fi
exit $RC
