#!/usr/bin/env bash
# test_gate_prolog_a_dead_frame_slot_is_not_a_root.sh -- THE DEAD SLOT (ARCH-PROLOG-ACTIVATION-LIFETIME.md section 6.4 R1; the cfo 2026-10-25).
#
# MEASURED, which is why this is a gate: gc_witnesses/pl_dead_slot_hamming_next.pl drives the Hamming generator's next/3 through
# run/2 for 200,000 steps.  main/1's frame cell for G (the initial state hamm(1,X,1,X,1,X,X)) is read for the last time when
# run(N, G)'s argument is staged, yet the cell stays a root for main's whole life; its X is bound to the first list cell, so EVERY
# Hamming number ever produced stays reachable: 48 bytes per step, the window grows (grew=30720 at -i2048k, both modes), swipl
# flat at 12 MB.  The holder was named with a reverse-pointer map at a collection stop (one stack root, rsp+416, into the oldest
# block).  THE CONTROL that proves the instrument can read green: the same loop with run(N, G) as main's LAST CALL (the tail arm
# releases main's frame) reads grew=0 -- see the gate's own control arm below.
#
# THE RULE: a frame cell is a root only while the clause can still read it.  THE CURE (hq_prolog): at the call that is a frame
# variable's last occurrence and is not the last call, under B == B0, the lowerer emits a KILL -- the cell written to the null
# DESCR -- after the argument is staged (a value) or at the call's omega (a home passed by reference).  Green means grew=0 in both
# modes at N=200000 under -i2048k -d131072k -s4096k.  REPORTED in make test until the cure lands, then BLOCKING in that landing.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
WIT="$HERE/gc_witnesses/pl_dead_slot_hamming_next.pl"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2) [$G]: no ./scrip to measure"; exit 2; }
[ -f "$WIT" ] || { echo "⛔ REFUSE(2) [$G]: the witness $WIT is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
sed 's/^main(N) :- mkHamm(G), run(N, G), write(done), nl\.$/main(N) :- mkHamm(G), run(N, G)./' "$WIT" > "$T/control.pl"
grep -q '^main(N) :- mkHamm(G), run(N, G)\.$' "$T/control.pl" || { echo "⛔ REFUSE(2) [$G]: the control rewrite found no main/1 line to turn into a last call"; exit 2; }
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
        out="$(tr -d '\n' < "$T/$arm.$mode.out")"; want=done; [ "$arm" = control ] && want=""
        grew="$(grew_of "$T/$arm.$mode.err")"
        if [ "$rc" != 0 ] || [ "$out" != "$want" ] || [ -z "$grew" ]; then echo "⛔ REFUSE(2) [$G]: $arm $mode rc=$rc out=[$out] grew=[$grew] -- the run did not complete or printed no GC-EXERCISE line"; sed -n '1,3p' "$T/$arm.$mode.err"; exit 2; fi
        if [ "$arm" = control ]; then
            if [ "$grew" != 0 ]; then echo "⛔ REFUSE(2) [$G]: the control (run as main's last call) grew=$grew in $mode -- the instrument cannot read green, nothing is graded"; exit 2; fi
            echo "[$G] control $mode grew=0 (the frame released by the tail arm holds nothing)"
        else
            if [ "$grew" != 0 ]; then echo "⛔ RED [$G]: witness $mode grew=$grew -- main/1's dead cell for G roots every Hamming number produced (section 6.4 R1)"; red=1; else echo "[$G] witness $mode grew=0"; fi
        fi
    done
done
[ $red = 0 ] && echo "PASS [$G]: a dead frame slot roots nothing in both modes"
exit $red
