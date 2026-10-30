#!/usr/bin/env bash
# test_gate_gc_every_gva_island_cell_is_a_root_a_hidden_compiler_temporary_included.sh -- EVERY CELL OF THE PINNED GVA
# ISLAND IS A ROOT, THE CELLS REGISTERED WITH NO NAME INCLUDED (cfo 2026-09-30, row snobol4-gc-a-nested-unevaluated-
# expression-reference-holds-a-pre-collection-address-and-dies-under-the-flip-plant-with-stress-1; law RULES.md FACT RULE
# THE COLLECTOR GUESSES NOTHING, CEO-812).
#
# MEASURED 2026-09-30 on SCRIP b8a668968: the five-statement witness (P8 = *(X Y), Y = *(X 'q'), 'pq' P8; the cto's find,
# FINDING-snobol4-gc-nested-unevaluated-expression-dies-under-the-flip-plant-with-stress-2026-09-29.md) died rc 139
# [ZGC-STALE] under SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=1 in mode 3 AND mode 4, strcmp in rt_proc_find reading the
# poisoned ground from rt_defer_open_cell(cell=0x70001050). That cell is GVA slot 5, "PATV$0": bake layer 3 (1015e2916)
# gave the compiler's PATV$/SCV$/SNO$VL$ temporaries GVA slots registered with NO name (gva_name_hidden; mode 4 emits
# .quad 0 in __gva_names, mode 3 a null), and the collector reached a GVA cell ONLY through its NV entry's e->cell in
# core_gc_roots, so a nameless cell was never visited: a hardware watchpoint on the cell read ONE store (emitted code,
# the DT_X "EXPR$0" whose name is an HB_WSC block) and no collector relocation through collections #4..#6.
#
# SCRIP 7043c34e8 (the cto's bake layer 10, landed beside this cure) made a DT_X carry its static star record, so those
# two witnesses no longer point into the arena and pass on origin without the cure; they stay as the DT_X road's
# regression. THE DISCRIMINATING WITNESS on 7043c34e8 is the eager call: S ('x' F(I) G(I + 1) 'y') snapshots each call's
# heap string into a nameless PATV$ cell before the match, G's first (the pre-args run last to first), and F's call
# collects before the match reads G's cell -- rc 139 [ZGC-STALE] on 7043c34e8 under the flip plant at stress 1, sbl -bf's
# answer with the cure.
#
# THE CURE: gc_root_gva() in gc_heap.c walks every cell of the island, RT_GVA_VA[0 .. g_sxt_gva_n) (the count
# rt_gva_island records), as a root region at every collection; core_gc_roots no longer visits e->cell's value, so each
# cell is visited exactly once whether it has a name or not.
#
# ARMS: (a) THE PROPERTY: the three witnesses answer their sbl -bf ref, rc 0, no [ZGC-STALE], under the flip plant at stress
# 1 and 3, mode 3 and mode 4 (on b8a668968 the two DT_X witnesses died rc 139 in both modes at stress 1; on 7043c34e8 the eager call dies, the other two pass); (b) THE PLANT APPLIED: every run
# of (a) printed the [GC-FLIP] plant line -- a green under a plant that never ran measures nothing; (c) THE WITNESS
# REACHES A NAMELESS CELL: its mode-4 __gva_names carries a .quad 0 entry and the program resolves a deferred reference
# through rt_defer_open_cell; (d) the source: gc_collect_ex calls gc_root_gva, which hands the asm drain (gc_wl_drain, the root walk in asm
# since 16cddcd71, 10-15) the WHOLE island as one range, rng_p = RT_GVA_VA and rng_n = g_sxt_gva_n (re-cut CEO-2051: the C loop this arm read
# before moved into the drain, so the old grep read red on a correct tree), and the NV walk no longer visits e->cell.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
WD="$ROOT/../harness/scripts/gc_witnesses"
WS="hb_sno_an_eager_call_result_held_in_a_nameless_patv_cell hb_sno_a_hidden_gva_cell_holds_a_nested_unevaluated_expression hb_sno_every_deferred_expression_shape_under_the_flip_plant"
for w in $WS; do [ -s "$WD/$w.sno" ] && [ -s "$WD/$w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: witness or ref $w missing under gc_witnesses"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; band=""; bad=0; noplant=""; reach=""; n=0
for w in $WS; do
  if ! ( cd "$T" && "$SCRIP" --compile "$WD/$w.sno" --out="$w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$w.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$w.4" 2>/dev/null ); then
    echo "  FAIL (a) the mode-4 witness $w did not build"; RC=1; continue; fi
  if awk '/^__gva_names:/{on=1;next} on&&/\.quad[ \t]+0[ \t]*$/{z=1} on&&!/\.quad/{on=0} END{exit z?0:1}' "$T/$w.s" && grep -q 'rt_defer_open_cell' "$T/$w.s"; then reach="$reach $w"; fi
  for st in 1 3; do
    for m in m3 m4; do n=$((n + 1))
      if [ $m = m3 ]; then ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s "$SCRIP" --run "$WD/$w.sno" </dev/null > o.$w.$m.$st 2> e.$w.$m.$st ); r=$?
      else ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s "./$w.4" </dev/null > o.$w.$m.$st 2> e.$w.$m.$st ); r=$?; fi
      grep -q '^\[GC-FLIP\] plant:' "$T/e.$w.$m.$st" || noplant="$noplant $w/$m/s$st"
      if [ $r = 0 ] && cmp -s "$T/o.$w.$m.$st" "$WD/$w.ref" && ! grep -q 'ZGC-STALE' "$T/e.$w.$m.$st"; then band="$band ${w:7:14}/$m/s$st:ok"
      else band="$band ${w:7:14}/$m/s$st:rc$r"; bad=1; fi
    done
  done
done
if [ "$bad" = 0 ]; then echo "  ok   (a) THE PROPERTY: the three witnesses answer their sbl -bf ref under the flip plant at stress 1 and 3 in both modes --$band"
else echo "  FAIL (a) a GVA cell lost its heap block across a collection --$band"; RC=1; fi
if [ -z "$noplant" ]; then echo "  ok   (b) THE PLANT APPLIED: all $n runs printed the [GC-FLIP] plant line"
else echo "  FAIL (b) the plant did not apply in:$noplant -- those runs measured nothing"; RC=1; fi
if [ "$reach" = " ${WS// / }" ]; then echo "  ok   (c) every witness carries a nameless GVA cell (.quad 0 in __gva_names) and resolves a deferred reference through rt_defer_open_cell"
else echo "  FAIL (c) a witness no longer reaches a nameless GVA cell (reached:${reach:- none}) -- it cannot grade the root"; RC=1; fi
GCH_FLAT=$(tr -s ' \t\n' '   ' < "$ROOT/src/runtime/rt/gc_heap.c")
if printf '%s' "$GCH_FLAT" | grep -qF 'gc_root_cas(); gc_root_gva();' && printf '%s' "$GCH_FLAT" | grep -qF 'static void gc_root_gva(void) { g_runtime.abi.gc_mk.rng_p = (DESCR_t *)RT_GVA_VA; g_runtime.abi.gc_mk.rng_n = (long)g_sxt_gva_n; g_runtime.abi.gc_mk.draining = 1; gc_wl_drain();' && ! grep -q 'rt_gc_visit_descr(e->cell)' "$ROOT/src/runtime/core/core.c"; then
  echo "  ok   (d) gc_collect_ex calls gc_root_gva, which hands the asm drain the whole island (RT_GVA_VA, g_sxt_gva_n cells), and the NV walk does not visit e->cell a second time"
else echo "  FAIL (d) the island root walk is gone or the NV walk visits e->cell again"; RC=1; fi
echo "population: 4 arm(s) graded, $n run(s)"
if [ $RC = 0 ]; then echo "✅ GATE PASS(0) [$G]: every GVA island cell is a root, nameless compiler temporaries included"; else echo "⛔ GATE FAIL(1) [$G]: a GVA island cell is not a root (examined 4 arms)"; fi
exit $RC
