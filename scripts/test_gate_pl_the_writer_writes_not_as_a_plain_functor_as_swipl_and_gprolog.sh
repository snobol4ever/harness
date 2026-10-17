#!/usr/bin/env bash
# test_gate_pl_the_writer_writes_not_as_a_plain_functor_as_swipl_and_gprolog.sh -- not/1 IS NO OPERATOR: neither swipl 9.0.4 nor gprolog 1.6.0 lists
# it (current_op/3 fails in both) and both write not(a), but prolog_atom.c op_cols_fill seeded the WRITER's operator columns with not fy 900, so SCRIP
# wrote not a, not not b, - (not c), not (a,b) while its own current_op/3 also answered no_op (hq_prolog 2026-10-17, the first step of row
# prolog-writeq-brackets-the-swi-declaration-atoms-its-own-current-op-does-not-list-public-dynamic-table-not; owed to the cfo since 10-15).
# A program that declares op(900, fy, not) itself still gets it (the user operator path; corpus puzzles p3_logic_and_codes.pl does).
# Graded in the ISO dialect and under the SWI marker (use_module), m3 and m4 -- four arms.
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-17 from /usr/bin/swipl (gprolog 1.6.0 prints the same five
# lines) and every run re-cuts it from the live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE: on the parent (049d786cf) every arm printed [not a,not not b,- (not c),not (a,b),f(not,not x)] and not a.
# NOT GRADED: the declaration atoms (dynamic, table, public ...) the same table seeds -- swipl writes them as operators, gprolog does not; the row's
# remaining work.
# Usage: bash ../harness/scripts/test_gate_pl_the_writer_writes_not_as_a_plain_functor_as_swipl_and_gprolog.sh
set -uo pipefail
GATE_NAME=test_gate_pl_the_writer_writes_not_as_a_plain_functor_as_swipl_and_gprolog
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
body='main :- writeq([not(a), not(not(b)), - not(c), not((a,b)), f(not, not(x))]), nl, print(not(a)), nl, write_canonical(not(a)), nl, ( current_op(P, T, not) -> writeq(P-T) ; write(no_op) ), nl, halt.'
printf ':- initialization(main).\n%s\n' "$body" > "$d/iso.pl"
printf ':- use_module(library(lists)).\n:- initialization(main).\n%s\n' "$body" > "$d/swi.pl"
cat > "$d/want" <<'WANT'
[not(a),not(not(b)),-not(c),not((a,b)),f(not,not(x))]
not(a)
not(a)
no_op
WANT
timeout -k 5 30 "$SWIPL" -q "$d/iso.pl" </dev/null > "$d/oracle" 2>/dev/null
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
for w in iso swi; do
    graded=$((graded + 1))
    timeout -k 5 30 "$SCRIP" "$d/$w.pl" </dev/null 2>/dev/null > "$d/$w.m3"; rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/$w.m3"; then fails=$((fails + 1)); echo "  $w m3 rc=$rc differs:"; diff "$d/want" "$d/$w.m3" | head -6; fi
    graded=$((graded + 1))
    if timeout -k 5 60 "$SCRIP" --compile -o "$d/$w.s" "$d/$w.pl" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$d/$w.bin" "$d/$w.s" "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null; then
        timeout -k 5 30 "$d/$w.bin" </dev/null 2>/dev/null > "$d/$w.m4"; rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/$w.m4"; then fails=$((fails + 1)); echo "  $w m4 rc=$rc differs:"; diff "$d/want" "$d/$w.m4" | head -6; fi
    else fails=$((fails + 1)); echo "  $w m4 did not compile or link"; fi
done
echo "PLNOTWRITER_BOARD programs=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
