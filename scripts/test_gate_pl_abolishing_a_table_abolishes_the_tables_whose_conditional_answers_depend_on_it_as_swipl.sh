#!/usr/bin/env bash
# test_gate_pl_abolishing_a_table_abolishes_the_tables_whose_conditional_answers_depend_on_it_as_swipl.sh -- abolish_table_subgoals/1,2, abolish_table_call/1,2 and
# abolish_table_pred/1 answer as swipl 9.0.4 (hq_prolog 2026-10-18, row prolog-swi-tabling-the-xsb-loader-runs-the-xsb-test-drivers; SWI xsb/table_tests abolish_dag,
# abolish_cycle, abolish_cascade, abolish_neg_dag, abolish_neg_cycle, abolish_cascade_pred, pred_abolish_dag, pred_abolish_cycle).
# THE SEMANTICS, MEASURED ON swipl: abolishing a table abolishes every table whose call unifies with the goal and then, transitively, every table holding a CONDITIONAL
# answer whose delay list names an abolished table -- p01 :- p11 :- u1 :- undef (a tnot loop, so every answer is undefined): abolishing p11(a,b) takes p01(a,b) and
# keeps u1(a,b); a caller with UNCONDITIONAL answers keeps its table (abolishing q1(_) of q0 :- q1 :- q2 keeps q0 and q2); abolish_table_pred(r1/1) is
# abolish_table_subgoals of r1's general head, the same cascade. SCRIP had no abolish_table_subgoals or abolish_table_call (existence_error), and its abolish_table_pred
# dropped the matching tables alone. CURE: src/parsers/prolog/prelude/xsb_tables.pl (a LOCAL library) defines the five, linked where a program names one or loads files.
# The program prints the ground tables (sorted) and the count of non-ground ones after each step, then one option-domain error. m3 and m4.
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-18 from /usr/bin/swipl and every run re-cuts it from the live swipl and
# REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE: on SCRIP de14c4404 plus hq_prolog's six loader commits (a base where tabling runs; see below) without the cure, both modes printed the before line only and
# raised existence_error(procedure, abolish_table_subgoals/1).
# ⛔ ON ORIGIN FROM 0bb392122 (hq_zetas' spine chunk) THIS GATE IS RED WITH EVERY TABLING PROGRAM: an undefined answer bombs, then segfaults, and from the spine flip
# e53f5dcd6 every tabled call raises instantiation_error -- hq_zetas' rows under Lon's cure-forward word, tolerated by name until they land.
# NOT GRADED: abolish_table_subgoals(_) and abolish_table_pred(3) -- swipl raises type_error(callable, user:_) and type_error(callable_or_predicate_indicator, user:3),
# its meta-argument qualification inside the error term; SCRIP raises instantiation_error and the unqualified type_error.
# Usage: bash ../harness/scripts/test_gate_pl_abolishing_a_table_abolishes_the_tables_whose_conditional_answers_depend_on_it_as_swipl.sh   (from SCRIP)
set -uo pipefail
GATE_NAME=test_gate_pl_abolishing_a_table_abolishes_the_tables_whose_conditional_answers_depend_on_it_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="$HERE/../../SCRIP/out"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/g.pl" <<'PL'
:- initialization(main).
:- table undef/2, p01/2, p11/2, u1/2, q0/1, q1/1, q2/1, r0/1, r1/1.
undef(A,B):- tnot(undef(A,B)).
p01(A,B):- p11(A,B).
p11(A,B):- u1(A,B).
u1(A,B):- undef(A,B).
q0(X):- q1(X).
q1(X):- q2(X).
q2(1).
r0(X):- r1(X).
r1(X):- undef(X,X).
show(Tag):- findall(G, (current_table(user:G,_), ground(G)), L0), msort(L0, L), findall(x, (current_table(user:G,_), \+ ground(G)), V), length(V, NV), writeq(Tag-L-NV), nl.
err(G):- catch((G, writeq(no_error)), error(E,_), writeq(E)), nl.
main:- ( p01(a,b), fail ; p01(c,d), fail ; q0(_), fail ; r0(e), fail ; true ), show(before),
       abolish_table_subgoals(p11(a,b)), show(p11ab),
       abolish_table_call(q1(_)), show(q1),
       abolish_table_subgoals(u1(c,_), [abolish_tables_transitively]), show(u1c),
       abolish_table_pred(r1/1), show(r1),
       err(abolish_table_call(q0(_), [bad])), halt.
PL
cat > "$d/want" <<'WANT'
before-[r0(e),r1(e),p01(a,b),p01(c,d),p11(a,b),p11(c,d),u1(a,b),u1(c,d),undef(a,b),undef(c,d),undef(e,e)]-3
p11ab-[r0(e),r1(e),p01(c,d),p11(c,d),u1(a,b),u1(c,d),undef(a,b),undef(c,d),undef(e,e)]-3
q1-[r0(e),r1(e),p01(c,d),p11(c,d),u1(a,b),u1(c,d),undef(a,b),undef(c,d),undef(e,e)]-2
u1c-[r0(e),r1(e),u1(a,b),undef(a,b),undef(c,d),undef(e,e)]-2
r1-[u1(a,b),undef(a,b),undef(c,d),undef(e,e)]-2
domain_error([abolish_tables_transitively,abolish_tables_singly],[bad])
WANT
timeout -k 5 30 "$SWIPL" -q "$d/g.pl" </dev/null > "$d/oracle" 2>/dev/null
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
graded=$((graded + 1))
timeout -k 5 30 "$SCRIP" "$d/g.pl" </dev/null 2>/dev/null > "$d/m3"; rc=$?
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -8; fi
graded=$((graded + 1))
if timeout -k 5 60 "$SCRIP" --compile --out="$d/g.s" "$d/g.pl" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$d/g.bin" "$d/g.s" "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null; then
    timeout -k 5 30 "$d/g.bin" </dev/null 2>/dev/null > "$d/m4"; rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -8; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLABOLISHCASCADE_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
