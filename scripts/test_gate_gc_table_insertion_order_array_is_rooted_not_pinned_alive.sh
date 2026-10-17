#!/usr/bin/env bash
# test_gate_gc_table_insertion_order_array_is_rooted_not_pinned_alive.sh -- A TABLE'S INSERTION-ORDER ARRAY IS A ROOT,
# NOT A PINNED ALIBI (cfo 2026-09-16, THE COLLECTOR, found on rung 2's first sliding measurement).
#
# MECHANISM, measured and not inferred: table_set_descr_d (aggregates.c) keeps every table's insertion order in
# tbl->ord, a DESCR_t array it rt_pinned_alloc's INTO THE COLLECTED HEAP as HB_WS, and gc_visit_tbblk (gc_heap.c)
# visited dflt, buckets and every pair but NEVER ord. Pinned means DOES NOT MOVE, not IS NOT RECLAIMED: the ord
# block is unmarked at every collection, so it is reclaimed under a live table, a live movable block slides into
# its bytes, and the NEXT INSERT writes a 16-byte key descriptor into whatever lives there now. On origin the
# conservative C-stack scan hides it most of the time (a stale stack word keeps the dead block alive by luck);
# under SCRIP_GC_STRESS the collection is precise and the corruption is deterministic: the witness below HANGS
# (rc=124) at stress 20 and 50 and ABORTS at 200 and 1000 with "[ZHP] heap verify FAILED ... (corrupt title)",
# both modes. On a SLIDING build (rung 2's probe) it is the Arizona gc2 SIGSEGV in rt_gc_visit_descr: a record
# instance slid into the dead ord's bytes and the next insert overwrote its type pointer with 0x100000002 -- the
# integer key descriptor itself. Caught by a hardware watchpoint on the corrupted word, writer table_set_descr_d:341.
# CURE: gc_visit_tbblk visits &t->ord (marks + registers the slot) and every t->ord[i] descriptor.
#
# ARMS: the witness (20 integer keys, six live 100-byte strings, COLLECT(), 40 more keys, print the strings and two
# lookups) in mode 3 and mode 4 at SCRIP_GC_STRESS=20 and =200, each byte-identical to the oracle's output and rc=0
# -- the two stress values are the two failure shapes (hang, corrupt-title abort); plus a STRUCTURAL arm that
# gc_visit_tbblk names t->ord, so removing the walk reds even when the behavioural arm is lucky.
# FAIL-ONCE / PASS-ONCE, 2026-09-16, two libraries distinct by sha256 (origin 699314447f17cf19, cure 669b670cba9c4e0b):
# origin, this gate verbatim: m3 AND m4 at stress 20 rc=124 (hang) -- the stress-200 arm happened to pass on origin in the gate's
# run and aborted rc=134 (corrupt title) in the hand run with SCRIP_ZETA_TELEM=1, so stress 20 is THE discriminator and 200 is kept
# as the second shape, not relied on. cure: all four behavioural arms rc=0 byte-identical, 1 s; the red run costs 24 s (two hangs).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
n=$(python3 "$ROOT/../harness/scripts/util_c_function_body.py" "$ROOT/src/runtime/rt/gc_heap.c" gc_visit_tbblk | grep -c -- '->ord)')
if [ "$n" -ge 1 ]; then echo "  structural PASS (gc_visit_tbblk visits t->ord)"; else echo "  structural FAIL (gc_visit_tbblk does not visit t->ord -- the insertion-order array has no root)"; RC=1; fi
{ printf '        T = TABLE()\n        I = 0\nL1      I = I + 1\n        T[I] = I\n        LT(I, 20)   :S(L1)\n'
  for c in a b c d e f; do printf "        S%s = DUPL('%s', 100)\n" "$c" "$c"; done
  printf '        COLLECT()\nL2      I = I + 1\n        T[I] = I\n        LT(I, 60)   :S(L2)\n'
  for c in a b c d e f; do printf '        OUTPUT = S%s\n' "$c"; done
  printf '        OUTPUT = T[7] T[33]\nEND\n'; } > "$T/w.sno"
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced an EMPTY ref"; exit 2; }
if "$SCRIP" --compile "$T/w.sno" -o "$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w4" 2>"$T/ld.log"; then :; else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so the m4 arms measured nothing (see $T/ld.log)"; exit 2; fi
for st in 20 200; do
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 10s "$SCRIP" w.sno </dev/null > m3.out 2>&1 ); r=$?
    if [ "$r" -eq 0 ] && cmp -s "$T/m3.out" "$T/w.ref"; then echo "  m3 stress=$st PASS (rc=0, byte-identical to the oracle)"; else echo "  m3 stress=$st FAIL (rc=$r; 124 is the hang shape, 134 the corrupt-title abort, 0-with-diff the overwritten string)"; RC=1; fi
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 10s ./w4 </dev/null > m4.out 2>&1 ); r=$?
    if [ "$r" -eq 0 ] && cmp -s "$T/m4.out" "$T/w.ref"; then echo "  m4 stress=$st PASS (rc=0, byte-identical to the oracle)"; else echo "  m4 stress=$st FAIL (rc=$r)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: the insertion-order array is rooted; 60 inserts across stress collections leave every live string and lookup byte-identical to the oracle in both modes (5 arms)"
else echo "⛔ GATE FAIL(1) [$G]: a table's insertion-order array is reclaimed under a live table (examined 5 arms)"; fi
exit $RC
