#!/usr/bin/env bash
# test_gate_gc_a_procedure_value_held_only_in_a_heap_aggregate_survives.sh -- THE DT_E ARM OF gc_visit_one, THE STRESS BAND, BOTH MODES.
# ⛔ THE MEASURED DEFECT (cfo 2026-09-22, CFO-146; routed in by hq_icon as FINDING-2026-09-22-hq_icon-proc-of-an-operator-symbol-string...):
# gc_visit_one's switch had no DT_E case, so a PROCEDURE VALUE fell to `default: return;` and the heap string its .s field names was
# never marked and its holder slot never registered for relocation.  This is the same shape as the DT_BIG hole CEO-952 closed one tag
# over: the axis nothing tested is the HOLDER TAG, and a value whose only holder is a heap aggregate element is reachable ONLY through
# gc_visit_arblk/gc_visit_tbblk -> gc_visit_one.  DT_E is OVERLOADED and the arm must NOT key on the tag alone: slen RT_CONVE_CHAIN_MARK
# carries a FUNCTION POINTER in .ptr and a staged proc carries an INTEGER entry_pc in .i, neither of which is a heap reference.  Only the
# three PROCVAL sentinels (IS_PROCVAL_fn) name a char * in .s, which is why the arm asks that question and not `case DT_E:` alone.
# MEASURED ON ORIGIN d698d3bce: stress 0 green both modes; stress 1, 3, 5, 8 RED both modes (error 106 with the corrupted .s printed as
# the offending image).  With the arm: 10 of 10 green.  Three independent witnesses agreed -- Icon rungs procedure_write_253, jcon
# args.icn at the SHIPPED arena (collections=3, no stress needed), and this one.
# ⛔ COLLECTIONS ARE THE EVIDENCE (ceo, INSTRUMENT LAWS 33rd batch): a run that collected ZERO times has not exercised the collector, so
# this gate reads rt_gc_runs_count out of its own run report and REFUSES rc=2 rather than grading a silence green.
# The .ref is cut from the Arizona oracle (icont -s), never from ./scrip.  A stale binary or a missing witness REFUSES rc=2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=gc_a_procedure_value_held_only_in_a_heap_aggregate_survives
WIT="$HERE/gc_witnesses/hb_procval_in_aggregate.icn"; REF="$HERE/gc_witnesses/hb_procval_in_aggregate.ref"
[ -f "$WIT" ] && [ -f "$REF" ] || { echo "GATE UNPROVEN(2) [$G]: witness or ref missing ($WIT)"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/gc_procagg.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
BAND="${GC_PROCAGG_BAND:-0 1 3 5 8}"
want="$(cat "$REF")"; bad=0; runs=0
( cd "$W" && timeout -k 5 180 "$ROOT/scrip" --compile -o pv.s "$WIT" < /dev/null 2>c.err && gcc pv.s -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o pv 2>l.err ) || { echo "GATE UNPROVEN(2) [$G]: mode-4 compile or link failed: $(head -c 200 "$W/c.err" "$W/l.err" 2>/dev/null | tr '\n' ' ')"; exit 2; }
col="$(SCRIP_GC_EXERCISE=1 SCRIP_GC_STRESS=3 timeout -k 5 180 "$ROOT/scrip" "$WIT" < /dev/null 2>&1 >/dev/null | sed -n 's/.*collections=\([0-9]*\).*/\1/p' | tail -1)"
echo "arena: the compiled-in default (GC_HEAP_KB); collector ran collections=${col:-unknown} at stress=3"
[ -n "$col" ] || { echo "GATE UNPROVEN(2) [$G]: the run printed no collections= field, so nothing states whether the collector ran"; exit 2; }
[ "$col" -gt 0 ] 2>/dev/null || { echo "GATE UNPROVEN(2) [$G]: collections=0 -- this witness did not exercise the collector, and a green from an idle collector is not evidence about rooting"; exit 2; }
for mode in m3 m4; do line="  $mode"
  for s in $BAND; do runs=$((runs+1))
    if [ "$mode" = m3 ]; then got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$ROOT/scrip" "$WIT" < /dev/null 2>/dev/null)"; else got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$W/pv" < /dev/null 2>/dev/null)"; fi
    if [ "$got" = "$want" ]; then line="$line stress=$s:ok"; else line="$line stress=$s:RED"; bad=$((bad+1)); fi
  done; echo "$line"; done
echo "population: 2 modes x $(echo $BAND | wc -w) stress levels = $runs runs against the icont ref (24 procedure values, every holder inside a list or a table, and image() reads .s back out)"
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad of $runs runs lost the heap string a procedure value names through .s -- gc_visit_one has no arm for the DT_E holder tag"; exit 1; fi
echo "GATE PASS(0) [$G]: every procedure value held only inside a heap aggregate survives the stress band in both modes ($runs runs, 0 red, collections=$col)"
