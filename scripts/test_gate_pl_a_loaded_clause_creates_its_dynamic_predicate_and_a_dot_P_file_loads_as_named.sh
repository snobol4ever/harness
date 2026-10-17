#!/usr/bin/env bash
# test_gate_pl_a_loaded_clause_creates_its_dynamic_predicate_and_a_dot_P_file_loads_as_named.sh -- two loader classes the XSB delay and
# neg files named (hq_prolog 2026-10-14, SWI xsb/delay_tests interp1..15 and xsb/neg_tests q7), answered as swipl 10 answers them, m3 and m4.
# (1) A CLAUSE LOADED AT RUN TIME (load_files/2) that asserts or retracts a predicate nothing defines CREATES IT DYNAMIC, as ISO and swipl do:
#     `new_program :- cleanup, assert(query(p)).` loaded from a file raised permission_error(modify, static_procedure, query/1) because the
#     run-time lowering knew no `query/1` and read "not known" as "static" (twelve interp/ac cases of xsb_test_delay, 24 case-modes).
# (2) `:- ensure_loaded('data.P')` loads the file NAMED: the resolver tried the four Prolog suffixes and never the name as written, so a
#     `.P` sibling (xsb neg q7 loads genome.P, 5386 hitb/2 facts) was "cannot find source" and every call to it an existence_error.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: each expectation below was cut 2026-10-14 from /usr/bin/swipl by absolute path and
# every run re-cuts both from the live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE: on the parent (a) raised the permission_error, (b) printed "cannot find source for 'data.P'" and an existence_error for fact/1.
# NOT GRADED: asserting to a COMPILED static predicate from a loaded clause (swipl raises permission_error, SCRIP accepts it today -- a
# divergence that predates this gate and is outside it).
# Usage: bash ../harness/scripts/test_gate_pl_a_loaded_clause_creates_its_dynamic_predicate_and_a_dot_P_file_loads_as_named.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_loaded_clause_creates_its_dynamic_predicate_and_a_dot_P_file_loads_as_named
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
mkdir -p "$d/lc" "$d/pf"
cat > "$d/lc/ld.pl" <<'PL'
new_program :- cleanup, assert(query(p)), assert(query(q)), assertz(rule(p, [])).
cleanup :- retractall(query(_)), retractall(rule(_, _)).
PL
cat > "$d/lc/w.pl" <<'PL'
:- initialization(main).
t(N, G) :- catch((call(G) -> R = yes ; R = no), error(E, _), (E =.. [F|_], R = err(F))), write(N-R), nl.
main :- load_files('ld.pl', []), t(new_program, new_program), findall(X, query(X), L), write(L), nl, findall(B, rule(p, B), Bs), write(Bs), nl,
        t(again, new_program), findall(X, query(X), L2), write(L2), nl, halt.
PL
cat > "$d/lc.want" <<'WANT'
new_program-yes
[p,q]
[[]]
again-yes
[p,q]
WANT
printf '%s\n' 'fact(1).' 'fact(2).' > "$d/pf/data.P"
cat > "$d/pf/w.pl" <<'PL'
:- ensure_loaded('data.P').
:- initialization(main).
main :- findall(X, fact(X), L), write(L), nl, halt.
PL
printf '%s\n' '[1,2]' > "$d/pf.want"
fails=0; graded=0
for w in lc pf; do
    (cd "$d/$w" && "$SWIPL" -q -g main -t halt w.pl </dev/null > "$d/$w.oracle" 2>/dev/null)
    cmp -s "$d/$w.want" "$d/$w.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the $w expectation table is not what $SWIPL prints now"; diff "$d/$w.want" "$d/$w.oracle" | head -5; exit 2; }
    (cd "$d/$w" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/$w.m3"); rc=$?; graded=$((graded + 1))
    if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m3"; then fails=$((fails + 1)); echo "  $w m3 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m3" | head -10; fi
    graded=$((graded + 1))
    if (cd "$d/$w" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 && as --64 -o w.o w.s 2>/dev/null \
        && gcc -no-pie -o w.bin w.o "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d/$w" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/$w.m4"); rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m4"; then fails=$((fails + 1)); echo "  $w m4 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m4" | head -10; fi
    else fails=$((fails + 1)); echo "  $w m4 did not compile or link"; fi
done
echo "PLLOADERCLASS_BOARD programs=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
