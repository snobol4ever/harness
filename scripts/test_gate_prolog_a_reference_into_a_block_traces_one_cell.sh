#!/usr/bin/env bash
# test_gate_prolog_a_reference_into_a_block_traces_one_cell.sh -- THE INTERIOR REFERENCE (ARCH-PROLOG-ACTIVATION-LIFETIME.md section 6.4 R2; the cfo 2026-10-25).
#
# MEASURED, which is why this is a gate: gc_witnesses/pl_open_tail_difference_list.pl threads a difference list with an OPEN tail
# through a last-call loop for 200,000 steps.  The tail variable Z is the second cell of the first pair block _-_, whose first cell
# is bound to the list's head; every later pair B-Z carries a reference to Z; the collector reaches the first pair through that
# reference, marks the block whole, traces its first cell, and the whole list stays: 48 bytes per step, grew=14336 at -i2048k in
# both modes, swipl flat at 7 MB.  THE CONTROL: the same loop with the tail closed (L = _-[]) reads grew=0 -- the gate's control
# arm rewrites the witness's mk/1 to that line, so the instrument is proven able to read green before the witness is graded.
#
# THE RULE: a DT_PLVAR reference into an HB_DVEC block is a reference to ONE CELL -- the collector keeps the block but traces only
# the referenced cell, and a cell nothing reaches is written to the null DESCR at the sweep.  The mechanism is the cto's ruling,
# hq_collector builds.  Green means grew=0 in both modes at N=200000 under -i2048k -d131072k -s4096k.  REPORTED in make test
# until the cure lands, then BLOCKING in that landing.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
WIT="$HERE/gc_witnesses/pl_open_tail_difference_list.pl"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2) [$G]: no ./scrip to measure"; exit 2; }
[ -f "$WIT" ] || { echo "⛔ REFUSE(2) [$G]: the witness $WIT is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
sed 's/^mk(N) :- loop(N, _-_)\.$/mk(N) :- L = _-[], loop(N, L)./' "$WIT" > "$T/control.pl"
grep -q '^mk(N) :- L = _-\[\], loop(N, L)\.$' "$T/control.pl" || { echo "⛔ REFUSE(2) [$G]: the control rewrite found no mk/1 line to close the tail of"; exit 2; }
SW="-d131072k -s4096k -i2048k"
grew_of() { sed -n 's/.*\[GC-EXERCISE\].* grew=\([0-9][0-9]*\).*/\1/p' "$1" | tail -1; }
run_m3() { ( cd "$ROOT" && SCRIP_GC_EXERCISE=1 timeout 60 ./scrip $SW "$1" < /dev/null > "$2.out" 2> "$2.err" ); echo $?; }
run_m4() {
    ( cd "$ROOT" && timeout 60 ./scrip --compile -o "$2.s" "$1" < /dev/null > /dev/null 2> "$2.cerr" ) || { echo 2; return; }
    gcc "$2.s" -o "$2.bin" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$2.lerr" || { echo 2; return; }
    ( SCRIP_GC_EXERCISE=1 timeout 60 "$2.bin" $SW < /dev/null > "$2.out" 2> "$2.err" ); echo $?; }
red=0
for mode in m3 m4; do
    for arm in witness control; do
        src="$WIT"; [ "$arm" = control ] && src="$T/control.pl"
        rc=$(run_$mode "$src" "$T/$arm.$mode")
        out="$(tr -d '\n' < "$T/$arm.$mode.out")"
        grew="$(grew_of "$T/$arm.$mode.err")"
        if [ "$rc" != 0 ] || [ "$out" != done ] || [ -z "$grew" ]; then echo "⛔ REFUSE(2) [$G]: $arm $mode rc=$rc out=[$out] grew=[$grew] -- the run did not complete or printed no GC-EXERCISE line"; sed -n '1,3p' "$T/$arm.$mode.err"; exit 2; fi
        if [ "$arm" = control ]; then
            if [ "$grew" != 0 ]; then echo "⛔ REFUSE(2) [$G]: the control (closed tail) grew=$grew in $mode -- the instrument cannot read green, nothing is graded"; exit 2; fi
            echo "[$G] control $mode grew=0 (the closed tail holds nothing)"
        else
            if [ "$grew" != 0 ]; then echo "⛔ RED [$G]: witness $mode grew=$grew -- the reference to the open tail roots the first pair block whole, and through its first cell the entire list (section 6.4 R2)"; red=1; else echo "[$G] witness $mode grew=0"; fi
        fi
    done
done
[ $red = 0 ] && echo "PASS [$G]: a reference into a block traces one cell in both modes"
exit $red
