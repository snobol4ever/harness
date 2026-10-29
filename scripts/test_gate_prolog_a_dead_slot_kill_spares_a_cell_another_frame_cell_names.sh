#!/usr/bin/env bash
# test_gate_prolog_a_dead_slot_kill_spares_a_cell_another_frame_cell_names.sh -- THE ALIASED CELL (ARCH-PROLOG-ACTIVATION-LIFETIME.md section 6.4 R1; hq_prolog 2026-10-25).
#
# The dead-slot kill writes a frame variable's cell to the null DESCR at its last read under B == B0.  Of two frame cells the younger
# binds to the older (section 6.2), so a variable unified with another while both were unbound may hold a REF to the dying cell; killing
# that cell leaves the live variable naming a null DESCR.  MEASURED on hq_prolog's first cut of the kill (no guard, 2026-10-25): the
# witness printed _G0 on seven of its eight lines in both modes (t1-t6, t8) where swipl prints the values; the cure's guard (a variable
# that shares a goal or the head with another variable before its last read is never killed; a first-and-last occurrence never when it
# shares that goal) reads all eight.  The ref is swipl's own answer, checked against /usr/bin/swipl when it is present; the comparison
# proves it can read red against a corrupted copy of the ref before it grades anything.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
WIT="$HERE/gc_witnesses/pl_dead_slot_aliased_cell.pl"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2) [$G]: no ./scrip to measure"; exit 2; }
[ -f "$WIT" ] || { echo "⛔ REFUSE(2) [$G]: the witness $WIT is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
printf '5\n5\nf(1)\nf(2)\ng(3)\ng(4)\nh(5)\nk(6)\n' > "$T/ref"
if [ -x /usr/bin/swipl ]; then
    ( cd "$T" && timeout 30 /usr/bin/swipl -q -g halt "$WIT" < /dev/null > "$T/swipl.out" 2> /dev/null )
    cmp -s "$T/swipl.out" "$T/ref" || { echo "⛔ REFUSE(2) [$G]: swipl no longer prints the ref -- the ref is not the oracle's answer"; diff "$T/ref" "$T/swipl.out" | head -4; exit 2; }
fi
sed 's/^5$/_G0/' "$T/ref" > "$T/corrupt"
cmp -s "$T/corrupt" "$T/ref" && { echo "⛔ REFUSE(2) [$G]: the corrupted ref equals the ref -- the comparison cannot read red"; exit 2; }
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then
        ( cd "$T" && timeout 60 "$ROOT/scrip" "$WIT" < /dev/null > "$T/$mode.out" 2> "$T/$mode.err" ); rc=$?
    else
        ( cd "$T" && timeout 60 "$ROOT/scrip" --compile --out="$T/w.s" "$WIT" < /dev/null > /dev/null 2> "$T/cc.err" ) || { echo "⛔ REFUSE(2) [$G]: the m4 compile failed"; sed -n '1,3p' "$T/cc.err"; exit 2; }
        gcc "$T/w.s" -o "$T/w.bin" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$T/l.err" || { echo "⛔ REFUSE(2) [$G]: the m4 link failed"; exit 2; }
        ( cd "$T" && timeout 60 "$T/w.bin" < /dev/null > "$T/$mode.out" 2> "$T/$mode.err" ); rc=$?
    fi
    [ "$rc" = 0 ] || { echo "⛔ REFUSE(2) [$G]: the $mode run exited rc=$rc"; sed -n '1,3p' "$T/$mode.err"; exit 2; }
    if cmp -s "$T/$mode.out" "$T/ref"; then echo "[$G] $mode: every variable bound to a killed variable keeps its value (8 of 8 lines as swipl)"
    else echo "⛔ RED [$G]: $mode -- a live variable names a cell the dead-slot kill wrote to the null DESCR"; diff "$T/ref" "$T/$mode.out" | head -8; red=1; fi
done
[ $red = 0 ] && echo "PASS [$G]: the dead-slot kill spares a cell another frame cell names, in both modes"
exit $red
