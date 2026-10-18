#!/usr/bin/env bash
# test_gate_gc_aggregate_interiors_are_marked_not_only_slotted.sh -- a LIVE array or record survives collection: rt_gc_visit_descr MARKS every block it walks into (the ARBLK and its data vector and proto, the DATINST and its type block and field vector), instead of only registering their slots (hq_V, GC-5 rung 2 groundwork, on Lon's "we do not allow pinning in our heap since we slide").
#
# MEASURED 2026-09-13 on 202d8bfff: `A = ARRAY(4); A<1> = 'alpha'` held in one variable across 60000 collections
# died with SIGSEGV in rt_gc_visit_descr (gc_heap.c:458, the DT_A element loop) reading a->data at 0x70001000 whose
# bytes had been reused as a string. Cause: the DT_A and DT_DATA arms of rt_gc_visit_descr called gc_slot_reg on
# &a->data, &u->fields and the aggregate handle but NEVER gc_mark_blk on the blocks themselves, so the vector a live
# array points at was swept while the array stayed reachable. Before CEO-661 rung 1 the four HB_WS/HB_WSS/HB_DINST/
# HB_ARR types were force-marked live at every regeneration, which hid the missing mark completely; rung 1 removed
# the force-mark and exposed it. This is the same class the ceo cured for the name-value table in rung 1 -- a root
# walk that VISITS without MARKING -- and every one of these blocks must be marked before it can be made to slide.
# ARMS: (1) SNOBOL4 ARRAY live across heavy collection, both modes, byte-identical to sbl -bf; (2) SNOBOL4 DATA
# record the same, both modes, byte-identical to sbl -bf; (3) an Icon record the same, mode 3, byte-identical to
# icont; (4) the instrument arm -- the witness must actually collect, so the gate REFUSES(2) if telemetry reports
# zero regenerations, because then it is measuring nothing.
# FAIL_ONCE cannot be an env knob here: SCRIP_GC_PIN_AGGREGATES=1 restores the immortal policy and therefore makes
# the witness PASS. The fail-once was proven by reverting the two rt_gc_visit_descr arms on this tree and rebuilding:
# arms 1 and 2 die with SIGSEGV. Recorded in FINDING-2026-09-13-hq_V-aggregate-interiors-visited-without-marking.md.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the SNOBOL4 refs are CUT FROM THE ORACLE"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT -- the Icon ref is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
STRESS="${GATE_GC_STRESS:-500}"
printf "        A = ARRAY(4)\n        A[1] = 'alpha'\n        A[2] = 'beta'\n        I = 0\nLOOP    I = LT(I,60000) I + 1                     :F(SHOW)\n        X = ARRAY(50)\n        Y = 'junk' I 'more'                       :(LOOP)\nSHOW    OUTPUT = A[1] ' ' A[2]\nEND\n" > "$T/arr.sno"
printf "        DATA('NODE(VAL,NXT)')\n        P = NODE('alpha','beta')\n        I = 0\nLOOP    I = LT(I,60000) I + 1                     :F(SHOW)\n        X = ARRAY(50)\n        Y = 'junk' I 'more'                       :(LOOP)\nSHOW    OUTPUT = VAL(P) ' ' NXT(P)\nEND\n" > "$T/dat.sno"
printf 'record pt(x, y)\nprocedure main();\n   local r, i, junk;\n   r := pt("alpha", "beta");\n   every i := 1 to 300000 do junk := [i, i+1, i+2];\n   write(r.x, " ", r.y);\nend\n' > "$T/rec.icn"
( cd "$T" && "$SBL" -bf arr.sno ) >"$T/arr.ref" 2>&1
( cd "$T" && "$SBL" -bf dat.sno ) >"$T/dat.ref" 2>&1
( cd "$T" && "$ICONT" -s rec.icn -x ) >"$T/rec.ref" 2>&1
for W in arr dat; do
    ( cd "$T" && SCRIP_GC_STRESS="$STRESS" timeout -k 5 300 "$SCRIP" "$W.sno" </dev/null ) >"$T/$W.m3" 2>&1
    if diff -q "$T/$W.ref" "$T/$W.m3" >/dev/null; then echo "  $W m3 PASS (live aggregate held across $STRESS-allocation-spaced collections, byte-identical to sbl -bf: $(cat "$T/$W.ref"))"
    else echo "  $W m3 FAIL (rc=$? got \"$(head -2 "$T/$W.m3" | tr '\n' '|')\" sbl \"$(cat "$T/$W.ref")\" -- a live aggregate's interior was swept)"; RC=1; fi
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o "$W.s" "$W.sno" </dev/null && gcc "$W.s" -o "$W.bin" -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 witness $W did not build"; exit 2; }
    ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" SCRIP_GC_STRESS="$STRESS" timeout -k 5 300 "./$W.bin" </dev/null ) >"$T/$W.m4" 2>&1
    if diff -q "$T/$W.ref" "$T/$W.m4" >/dev/null; then echo "  $W m4 PASS (same witness compiled, byte-identical to sbl -bf: $(cat "$T/$W.ref"))"
    else echo "  $W m4 FAIL (got \"$(head -2 "$T/$W.m4" | tr '\n' '|')\" sbl \"$(cat "$T/$W.ref")\" -- a live aggregate's interior was swept)"; RC=1; fi
done
( cd "$T" && SCRIP_GC_STRESS="$STRESS" timeout -k 5 300 "$SCRIP" rec.icn </dev/null ) >"$T/rec.m3" 2>&1
if diff -q "$T/rec.ref" "$T/rec.m3" >/dev/null; then echo "  rec m3 PASS (Icon record held across heavy collection, byte-identical to icont: $(cat "$T/rec.ref"))"
else echo "  rec m3 FAIL (got \"$(head -2 "$T/rec.m3" | tr '\n' '|')\" icont \"$(cat "$T/rec.ref")\")"; RC=1; fi
( cd "$T" && SCRIP_GC_STRESS="$STRESS" SCRIP_ZETA_TELEM=1 timeout -k 5 300 "$SCRIP" arr.sno </dev/null ) >/dev/null 2>"$T/telem"; trc=$?
REGENS=$(grep -c '^\[ZGC\] regeneration' "$T/telem" 2>/dev/null || echo 0)
if [ "$trc" = 0 ] && [ "${REGENS:-0}" -lt 2 ]; then echo "⛔ GATE REFUSE(2) [$G]: the witness ran clean and reported $REGENS regenerations -- it never collected, so this gate is measuring nothing"; exit 2; fi
if [ "$trc" != 0 ]; then echo "  instrument PASS ($REGENS regenerations before the witness died at rc=$trc -- the collector ran, and the arms above already carry the red)"
else echo "  instrument PASS ($REGENS regenerations ran under the witness, so the live aggregate really was walked by the collector)"; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: rt_gc_visit_descr marks the ARBLK and DATINST interiors it walks, so a live array or record survives collection in both modes"
else echo "GATE FAIL(1) [$G]: a live aggregate's interior block was visited but not marked, and the sweep took it (examined 5 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracles: $SBL, $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
