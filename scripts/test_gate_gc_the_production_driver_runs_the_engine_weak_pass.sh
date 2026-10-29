#!/usr/bin/env bash
# test_gate_gc_the_production_driver_runs_the_engine_weak_pass.sh -- THE ASM PRODUCTION DRIVER RUNS THE SAME WEAK PASSES AS THE C DRIVER (the collector, found 2026-10-28 while curing the coo's ProBench reds on the R2 cell-only mark).
#
# MEASURED, which is why this is a gate: gc_collect_ex runs the asm production driver (rtx_gc.s .Lgx_fast) when no diagnostic knob is on, SCRIP_DIAG=0 being every benchmark's setting, and the
# C driver gc_collect_ex_c otherwise.  SCRIP ca4f73c65 (an engine handle is a collector-visible value and an unreachable engine is reclaimed after a collection) added rt_pl_eng_gc_weak to the
# C driver only.  Under SCRIP_DIAG=0 the engine table was left pointing at a block the slide had moved: gc_witnesses/pl_cellshape_engine1.pl (an engine yielding three solutions with a churn of
# compound terms between the engine_next calls) printed NOTHING at all, rc 0, under SCRIP_GC_STRESS 1, 3 and 5, in both modes, on origin 496d4e89f, and printed its swipl ref with diagnostics on.
# THE CONTROL: the same witness with no stress must print its ref under the fast driver, and with stress under the C driver, or the instrument cannot read green and nothing is graded.
# THE GRADE: SCRIP_DIAG=0 at SCRIP_GC_STRESS 3 and 1, both modes, must print the ref (gc_witnesses/pl_cellshape_engine1.ref, cut from swipl 9.0.4).  RED on 496d4e89f, green once the asm driver calls it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
SRC="$HERE/gc_witnesses/pl_cellshape_engine1.pl"; REF="$HERE/gc_witnesses/pl_cellshape_engine1.ref"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2) [$G]: no ./scrip to measure"; exit 2; }
[ -f "$SRC" ] && [ -f "$REF" ] || { echo "⛔ REFUSE(2) [$G]: the witness or its ref pl_cellshape_engine1 is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
SW="-d131072k -s4096k"
BIN="$T/engine1.bin"
( cd "$ROOT" && timeout 60 ./scrip --compile --out="$BIN.s" "$SRC" < /dev/null > /dev/null 2> "$BIN.cerr" ) && gcc "$BIN.s" -o "$BIN" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$BIN.lerr" || { echo "⛔ REFUSE(2) [$G]: the witness did not compile and link in mode 4"; exit 2; }
run() {
    if [ "$1" = m3 ]; then ( cd "$ROOT" && env $2 SCRIP_GC_STRESS="$3" timeout 60 ./scrip $SW "$SRC" < /dev/null > "$4" 2> "$4.err" ); echo $?
    else ( env $2 SCRIP_GC_STRESS="$3" timeout 60 "$BIN" $SW < /dev/null > "$4" 2> "$4.err" ); echo $?; fi
}
red=0; graded=0
for mode in m3 m4; do
    rc=$(run $mode SCRIP_DIAG=0 0 "$T/ctl.fast.$mode")
    if [ "$rc" != 0 ] || ! cmp -s "$T/ctl.fast.$mode" "$REF"; then echo "⛔ REFUSE(2) [$G]: control $mode under SCRIP_DIAG=0 with no stress rc=$rc -- the witness does not print its swipl ref, so the instrument cannot read green and nothing is graded"; exit 2; fi
    rc=$(run $mode SCRIP_DIAG=1 3 "$T/ctl.diag.$mode")
    if [ "$rc" != 0 ] || ! cmp -s "$T/ctl.diag.$mode" "$REF"; then echo "⛔ REFUSE(2) [$G]: control $mode under the C driver at stress 3 rc=$rc -- the witness does not print its swipl ref, so the instrument cannot read green and nothing is graded"; exit 2; fi
    for st in 3 1; do
        rc=$(run $mode SCRIP_DIAG=0 $st "$T/st$st.$mode")
        graded=$((graded + 1))
        if [ "$rc" != 0 ] || ! cmp -s "$T/st$st.$mode" "$REF"; then echo "⛔ RED [$G]: $mode under SCRIP_DIAG=0 at SCRIP_GC_STRESS=$st rc=$rc -- the production driver left the engine table pointing at a moved block (rt_pl_eng_gc_weak is not called)"; red=1; else echo "[$G] $mode SCRIP_DIAG=0 stress $st prints its ref"; fi
    done
done
[ $red = 0 ] && echo "PASS [$G]: $graded production-driver readings print the swipl ref, the engine table survives a slide in both modes"
exit $red
