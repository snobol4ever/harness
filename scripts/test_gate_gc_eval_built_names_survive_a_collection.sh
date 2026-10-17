#!/usr/bin/env bash
# test_gate_gc_eval_built_names_survive_a_collection.sh -- THE NAMES RUNTIME-COMPILED CODE BAKES SURVIVE A COLLECTION, BOTH MEDIA, THE STRESS BAND.
# ⛔ THE MEASURED DEFECT (ceo 2026-09-19, CEO-924; handed by the cto as user_function_eval_pos_replace_branch_1 reading error 41 under
# SCRIP_GC_STRESS): eval_build_chain minted the chain's target variable name with rt_heap_strdup_c, the emitter baked that heap string's
# address into the chain's code, and the first collection between the build and the run slid the string away -- NV_SET_fn was then
# called with a garbage name, the chain never assigned EVAL$, and every EVAL whose window held a collection FAILED as a statement
# (an empty string, a null pattern that matched with no captures, a deferred call that never ran). Traced with gdb from the capture
# island's top never moving, through the chain's assign box, to the garbage name. The class: a compile-time string the emitter bakes
# must live in the compile-time arena (ct_alloc, mmap-backed, never moves), never in the collected heap; the SNOBOL4 lowering held five
# more such sites (computed-goto target names and folded literals), converted in the same landing.
# The witness runs at SCRIP_GC_STRESS=0,1,3,5,10 in BOTH modes against a ref cut from sbl -bf; a stale binary or a missing witness REFUSES rc=2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=gc_eval_built_names_survive_a_collection
WIT="$HERE/gc_witnesses/hb_eval_names.sno"; REF="$HERE/gc_witnesses/hb_eval_names.ref"
[ -f "$WIT" ] && [ -f "$REF" ] || { echo "GATE UNPROVEN(2) [$G]: witness or ref missing ($WIT)"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/gc_evalnames.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
BAND="${GC_EVALNAMES_BAND:-0 1 3 5 10}"
want="$(cat "$REF")"; bad=0; runs=0
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile -o ev.s "$WIT" < /dev/null 2>c.err && gcc ev.s -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o ev 2>l.err ) || { echo "GATE UNPROVEN(2) [$G]: mode-4 compile or link failed: $(head -c 200 "$W/c.err" "$W/l.err" 2>/dev/null | tr '\n' ' ')"; exit 2; }
for mode in m3 m4; do line="  $mode"
  for s in $BAND; do runs=$((runs+1))
    if [ "$mode" = m3 ]; then got="$(SCRIP_GC_STRESS=$s timeout -k 5 30 "$ROOT/scrip" "$WIT" < /dev/null 2>/dev/null)"; else got="$(SCRIP_GC_STRESS=$s timeout -k 5 30 "$W/ev" < /dev/null 2>/dev/null)"; fi
    if [ "$got" = "$want" ]; then line="$line stress=$s:ok"; else line="$line stress=$s:RED[$got]"; bad=$((bad+1)); fi
  done; echo "$line"; done
echo "population: 2 modes x $(echo $BAND | wc -w) stress levels = $runs runs, want [$want]"
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad of $runs runs lost a name runtime-compiled code baked -- a compile-time string lives in the collected heap (eval_build_chain's EVAL\$ target, or a lowering-time name the emitter bakes)"; exit 1; fi
echo "GATE PASS(0) [$G]: the names runtime-compiled code bakes survive every collection of the band in both modes ($runs runs, 0 red)"
