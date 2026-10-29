#!/usr/bin/env bash
# test_gate_pl_a_run_time_clause_calling_a_predicate_created_by_assert_sees_every_clause.sh -- a clause compiled at run time (assertz, consult, load_files)
# that calls a predicate the static program never names and that another run-time clause creates by assert, enumerates EVERY clause of it, as swipl 9.0.4 does
# (hq_prolog 2026-10-17, found by SWI xsb/table_tests abol_test3*: tpred(X), tr(Y) returned tr(a) only).
# CAUSE: compiling the writer w :- assert(zz(a)), ... gives zz/1 a registry cell, so a reader compiled next lowers zz(Y) as a staged call to a live dynamic
# predicate -- but zz/1 has no procedure record yet, so bb_call_proc_staged took its deterministic arm and the by-name road, whose gamma landing keeps no
# redo point: the first clause answered and backtracking never re-entered. A reader compiled after the clauses exist takes the block protocol (record
# pinned) and a reader compiled before the cell exists takes the meta-call road; both were right. CURE (lower_prolog.c pl_user_call): a run-time clause's
# call to a live dynamic predicate with no procedure record yet goes by the meta-call road.
# FOUR ARMS per mode: (1) reader compiled between the writer's compile and its run -- the red; (2) reader compiled after the facts exist; (3) reader compiled
# before the writer; (4) the same pair loaded by consult/1 from a file. m3 and m4.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-17 from /usr/bin/swipl and every run re-cuts it from the live
# swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE: on the parent (99fd1798a's tree) arms 1 and 4 printed [a] in both modes.
# NOT GRADED: a call made before any assert has run -- swipl raises existence_error(procedure, zz/1), SCRIP's database guard answers [] (a divergence of its own).
# Usage: bash ../harness/scripts/test_gate_pl_a_run_time_clause_calling_a_predicate_created_by_assert_sees_every_clause.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_run_time_clause_calling_a_predicate_created_by_assert_sees_every_clause
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf '%s\n' 't :- assert(qq(a)), assert(qq(b)), assert(qq(c)), fail.' 't :- findall(Y, qq(Y), L), write(L), nl.' > "$d/two.pl"
cat > "$d/w.pl" <<'PL'
:- initialization(main).
c(A, T) :- term_to_atom(T, A).
main :- c('w1 :- assert(zz(a)), assert(zz(b)), assert(zz(c)), fail', W1), c('r1 :- findall(Y, zz(Y), L), write(L), nl', R1),
        c('w2 :- assert(yy(a)), assert(yy(b)), assert(yy(c)), fail', W2), c('r2 :- findall(Y, yy(Y), L), write(L), nl', R2),
        c('w3 :- assert(xx(a)), assert(xx(b)), assert(xx(c)), fail', W3), c('r3 :- findall(Y, xx(Y), L), write(L), nl', R3),
        assertz(W1), assertz(R1), ( w1 ; true ), r1,
        assertz(W2), ( w2 ; true ), assertz(R2), r2,
        assertz(R3), assertz(W3), ( w3 ; true ), r3,
        consult('two.pl'), t, halt.
PL
cat > "$d/want" <<'WANT'
[a,b,c]
[a,b,c]
[a,b,c]
[a,b,c]
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -8; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile --out=w.s w.pl </dev/null >/dev/null 2>&1 && gcc -no-pie -o w.bin w.s "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -8; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLRTDYNCALL_BOARD programs=1 arms=4 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
