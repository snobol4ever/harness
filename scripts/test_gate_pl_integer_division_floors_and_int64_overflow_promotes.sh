#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_pl_integer_division_floors_and_int64_overflow_promotes.sh -- ISO 9.1.3 integer arithmetic (cto, 2026-09-12,
# row prolog-integer-division-floors-and-int64-overflow-raises-instead-of-trapping, ceo re CTO-33). RED BEFORE:
# -10 div 3 gave -3 (truncated like //, ISO floors to -4) and -9223372036854775808 // -1 executed idiv on INT64_MIN / -1,
# a CPU trap (SIGFPE, rc=136) that killed the program -- core/test_arith.pl lost every case after it (0/220 on the SWI board).
# FLOOR RAISED 2026-10-04 (hq_prolog, the coo's pass-36 red: 175 -> 74 of 220 since 9f6049d47 read GREEN against the old floor of 55): the per-mode
# floor is the measured reading after the cure (ball propagation past packet clauses, bignums in asserted clauses) -- m3 hit 167, m4 hit 174 --
# then 174 in both modes once a cut commits a packet predicate (the m3 deficit was the shim's condition check taking a later clause after its cut) --
# so a loss of the thirteen units after bigint, or any one case, reds here instead of passing a floor 120 cases below it.
# ARMS, both modes: (1) a witness prints [-3,2,-1,-4] for // mod rem div of -10 by 3 and catches
# evaluation_error(int_overflow) (or prints the promoted 9223372036854775808) for INT64_MIN // -1, INT64_MIN mod -1,
# abs(INT64_MIN) and -(INT64_MIN); (2) core/test_arith.pl through the shim exits by rc, never by signal, and
# util_swi_match.py reads hit >= 55 of 220 (MEASURED at the cure: 29 -> 55; the mint estimated 150, but 150 of the
# remaining 165 misses are tests the file guards with :- if(current_prolog_flag(bounded, false)) -- the UNBOUNDED
# INTEGER class (bigint, minint/maxint promotion, rationals), which this reader correctly does not compile under
# bounded=true and which is its own row, never this one's).
# ⛔ RENAMED AND TIGHTENED 2026-09-13 (cto). THIS GATE WAS BLIND ON THE AXIS ITS OWN NAME ASSERTED. Its witness
# arm graded the four overflow lines with `case "$l" in int_overflow|9223372036854775808|0)`, a disjunction that
# accepts RAISING and PROMOTING alike -- so a gate called ..._int64_overflow_raises passed identically whether
# int64 overflow raised or promoted, and could not fail on the one thing it was named for. Measured both ways:
# on clean origin 8f7f0d394 the arm printed `int_overflow` and passed; with the promotion cure it printed
# `9223372036854775808` and passed. An arm that cannot distinguish the two states it exists to separate is not
# measuring (cto's law THE UNEXPLAINED GREEN, corollary 1: falsifiable in both directions or not counted).
# The four lines are now pinned to the oracle's exact answers, CUT FROM swipl 9:
#   [-3,2,-1,-4] / 9223372036854775808 / 0 / 9223372036854775808 / 9223372036854775808
# and the name says promotes, because that is what the tree does since the int64-overflow promotion landing.
set -u
GATE_NAME=test_gate_pl_integer_division_floors_and_int64_overflow_promotes
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="${S4E_CORPUS:-$ROOT/corpus}"
SWIT="$CORPUS/packages/prolog/swi_tests"; PLUNIT="$CORPUS/tests/prolog/plunit.pl"
SCRIP="$HERE/../../SCRIP/scrip"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -f "$PLUNIT" ] || refuse "no shim at $PLUNIT"; [ -f "$SWIT/core/test_arith.pl" ] || refuse "no vendored core/test_arith.pl"
[ -x "$SCRIP" ] || refuse "no scrip binary -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
red=0; total=0
run() { local mode="$1"; shift
    if [ "$mode" = m4 ]; then timeout -k 5 60 "$SCRIP" --compile "$@" > "$T/p.s" 2>/dev/null && gcc -no-pie "$T/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$T/p" 2>/dev/null && timeout -k 5 60 "$T/p" </dev/null 2>/dev/null
    else timeout -k 5 60 "$SCRIP" --run "$@" </dev/null 2>/dev/null; fi; }
cat > "$T/w.pl" <<'EOP'
:- initialization(main).
ov(G) :- catch((V is G, write(V)), error(evaluation_error(int_overflow), _), write(int_overflow)), nl.
main :- A is -10 // 3, B is -10 mod 3, C is -10 rem 3, D is -10 div 3, write([A,B,C,D]), nl,
    ov(-9223372036854775808 // -1), ov(-9223372036854775808 mod -1), ov(abs(-9223372036854775808)), ov(-(-9223372036854775808)), halt.
EOP
for mode in ${MODES//,/ }; do
    total=$((total+1))
    got="$(run "$mode" "$T/w.pl")"; rc=$?
    ok=1; [ "$rc" = 0 ] || ok=0
    [ "$(printf '%s\n' "$got" | sed -n 1p)" = "[-3,2,-1,-4]" ] || ok=0
    [ "$(printf '%s\n' "$got" | sed -n 2p)" = "9223372036854775808" ] || ok=0
    [ "$(printf '%s\n' "$got" | sed -n 3p)" = "0" ] || ok=0
    [ "$(printf '%s\n' "$got" | sed -n 4p)" = "9223372036854775808" ] || ok=0
    [ "$(printf '%s\n' "$got" | sed -n 5p)" = "9223372036854775808" ] || ok=0
    if [ "$ok" = 1 ]; then echo "  ok  witness $mode: $(printf '%s' "$got" | tr '\n' ' ')"; else echo "  RED witness $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' ' ')]"; red=$((red+1)); fi
    total=$((total+1))
    run "$mode" "$PLUNIT" "$SWIT/core/test_arith.pl" "$T/wrap.pl" > "$T/act"; rc=$?
    line="$(python3 "$HERE/util_swi_match.py" "$SWIT/core/test_arith.pl" "$SWIT/core/test_arith.ref" "$T/act" | tail -1)"
    h="$(printf '%s' "$line" | sed -n 's/.* hit=\([0-9]*\).*/\1/p')"
    fl=174
    if [ "$rc" -lt 128 ] && [ "${h:-0}" -ge "$fl" ]; then echo "  ok  test_arith $mode: rc=$rc $line (floor hit>=$fl, exit by rc)"; else echo "  RED test_arith $mode: rc=$rc $line (floor hit>=$fl, exit by rc never by signal)"; red=$((red+1)); fi
done
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
