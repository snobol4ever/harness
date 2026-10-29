#!/usr/bin/env bash
# test_gate_icn_a_spine_opened_plain_procedure_fails_forward_on_redo.sh -- A CALL THROUGH A PROCEDURE VALUE THAT THE SPINE OPENED AND THAT CANNOT SUSPEND
# MUST FAIL FORWARD WHEN THE CALLER BACKTRACKS INTO IT, IN BOTH MODES, AT EVERY ARENA AND STRESS LEVEL.
# ⛔ THE MEASURED DEFECT THIS PINS (ceo 2026-09-19, row gc-the-five-c-to-bb-entries-outside-rt-c-go-to-zero, CEO-929's design behind the open/land pair):
# rt_call_value_spine_prep used to refuse every callee that was not a generator, which sent 26 of the 40 procedure-value calls reaching
# by_name_dispatch.c 1129 over the Icon rungs down rt_call_value_gen_h -- a C frame entering a Byrd box, which is the thing Lon's 13:5x order
# ('ZERO instances of C code calling into a BB') removes. The refusal was not a policy: it was the box's ONLY guard. bb_call_value's beta
# reads callgen.act +0 and resumes on 1, and a plain procedure returns its one result and RELEASES its frame, so opening one on the spine with
# nothing else changed makes every redo jump back into a dead frame. Measured that day on this very witness with the refusal removed and no
# act0 word: `every x := f()` and a failing comparison each looped forever -- 4 of 4 runs timed out at 10 s, both modes, both arenas, while a
# single non-backtracking call was byte-correct. The cure is CVSPINE_t (descr.h): prep hands the box act0 = 2 for a non-resumable callee and the
# box fails forward on it instead of resuming. THIS GATE IS THE FAIL-ONCE ARM MADE PERMANENT -- drop the 2 and it hangs, which is why it runs
# under `timeout` and reads a timeout as RED rather than letting a board hang.
# The ref is cut from the ORACLE (/home/resources/icon-master/bin/icon), not from our own output, so it does not rot on our own improvements.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=icn_a_spine_opened_plain_procedure_fails_forward_on_redo
WIT="$HERE/gc_witnesses/hb_cv_spine_plain_redo.icn"; REF="$HERE/gc_witnesses/hb_cv_spine_plain_redo.ref"
[ -f "$WIT" ] && [ -f "$REF" ] || { echo "GATE UNPROVEN(2) [$G]: witness or ref missing ($WIT)"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/cvspine.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out=cv.s "$WIT" < /dev/null 2>c.err && gcc cv.s -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o cv 2>l.err ) || { echo "GATE UNPROVEN(2) [$G]: mode-4 compile or link failed: $(head -c 200 "$W/c.err" "$W/l.err" 2>/dev/null | tr '\n' ' ')"; exit 2; }
BAND="${CVSPINE_BAND:-0 1 3 5}"
want="$(cat "$REF")"; bad=0; runs=0
for mode in m3 m4; do line="  $mode"
  for s in $BAND; do runs=$((runs+1))
    if [ "$mode" = m3 ]; then got="$(SCRIP_GC_STRESS=$s timeout -k 5 30 "$ROOT/scrip" "$WIT" < /dev/null 2>/dev/null)"; rc=$?; else got="$(SCRIP_GC_STRESS=$s timeout -k 5 30 "$W/cv" < /dev/null 2>/dev/null)"; rc=$?; fi
    if [ "$rc" = 124 ]; then line="$line stress=$s:HUNG"; bad=$((bad+1));
    elif [ "$got" = "$want" ]; then line="$line stress=$s:ok"; else line="$line stress=$s:RED"; bad=$((bad+1)); fi
  done; echo "$line"; done
echo "population: 2 modes x $(echo $BAND | wc -w) stress levels = $runs runs, arena SCRIP_HEAP_MB=${SCRIP_HEAP_MB:-unset}"
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad of $runs runs lost the redo contract -- a spine-opened callee that cannot suspend was resumed (a hang) or answered wrongly; read callgen.act +0 and CVSPINE_t.act0"; exit 1; fi
echo "GATE PASS(0) [$G]: a spine-opened plain procedure fails forward on every redo, and a spine-opened generator still resumes ($runs runs, 0 red)"
