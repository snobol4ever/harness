#!/usr/bin/env bash
# test_gate_pl_clause_2_returns_a_static_clause_with_its_leading_unifications_moved_to_the_head_and_a_loaded_unit_test_body_runs_in_its_unit_as_swipl.sh -- clause/2 of a static clause under the SWI dialect returns the clause as swipl 9.0.4's decompiler does when a body unification was moved to the
# head, and a test of a plunit unit whose clauses a term_expansion hook produced calls those clauses, m3 and m4 (hq_prolog 2026-11-04; swi core/test_moved_ubody
# decomp8 and core/test_body_index p2 and p6, 7 -> 9 of 9). THE RULES, read from swipl's pl-comp.c (annotate_unify, compileBodyUnify, mark_bvar_access,
# moved_unifications): in a static clause (no :- dynamic) a leading run of Var = Term goals (Term nonvar; true and Term = Term goals do not stop the run; any other goal
# does) annotates each head-argument variable once, trying either side; an annotated variable with no other use (head arguments, body goal arguments, a term inside a
# unification; the variable side of a Var = Term goal is no use) becomes its head argument's term and the goal goes; otherwise the goal is returned first as Var = Term,
# in head-argument order, and when the variable also sits inside another annotated unification's term swipl 9.0.4 returns Var = Var (its bug, matched). A dynamic
# predicate and a program without a SWI marker keep the source form. w1 is the compiled road (clauses in the file), w2 the run-time load road (clauses a
# term_expansion hook produced), w3 a unit whose tests call predicates its hook produced (the test body ran in user and raised existence_error). NOT MATCHED, the
# known difference: a Var = Var goal before the annotated one (c10(X, Y) :- X = Y, Y = f(_)).
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: each table is cut from /usr/bin/swipl on every run and the gate REFUSES rc=2 when swipl is absent or its answer is empty.
# FAIL-ONCE (CEO-1680): on origin 127bfb1c4 w1 reads FAIL in m3 and m4 (the unmoved source form), w2 FAIL, w3 FAIL (existence_error on the unqualified call).
# Usage: bash ../harness/scripts/test_gate_pl_clause_2_returns_a_static_clause_with_its_leading_unifications_moved_to_the_head_and_a_loaded_unit_test_body_runs_in_its_unit_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_clause_2_returns_a_static_clause_with_its_leading_unifications_moved_to_the_head_and_a_loaded_unit_test_body_runs_in_its_unit_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/w1.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
a1(X) :- X = f(A), q(A).
a2(X) :- f(_) = X, q(X).
a3(X, X) :- X = f(_).
a4(X) :- X = f(X).
a5(X) :- X = f(_), q([X]).
a6(X, Y) :- X = f(Y), Y = a.
a7(A, B) :- B = g(y), A = h(x), q(A, B).
a8(X) :- X = a, X = b.
a9(X) :- foo = bar, X = f(Y), q(Y).
a10(X) :- q(X), X = f(_).
a11(X, _) :- X = f(Z), Z = g(_), q(Z).
a12(X, Y) :- Y = k, X = j.
a13(f(X)) :- X = a, q(X).
a14([H|T]) :- H = a, q(T).
b1(X) :- X = a, q(X).
b2(X, Y) :- X = f(Y), q(Y).
b3(X) :- X = 1, q(X).
b4(X) :- X = [], q(X).
b5(X, Y) :- Y = a, X = f(Y).
b6(X, Y) :- X = f(Y), Y = g(Z), q(Z).
b7(X, Y) :- X = g(Y), Y = a, q(X).
b8(X) :- X = a.
b9(X, Y) :- X = f(Y), Y = g(_).
b10(X, Y) :- X = f(Y), Y = 1.
c1(X) :- X = f(Y), q(Y), X = g(_).
c2(X, Y) :- q(Y), X = f(_).
c3(X) :- ( X = f(_) ; q(X) ).
c4(X, Y) :- Y = k, q(Y), X = j.
c5(X) :- true, X = f(A), q(A).
c6(X) :- X = Y, q(Y).
c7(f(X), X) :- X = a.
c8(X) :- X = f(_), !, q(X).
c9(X) :- X = f(A), A = b, q(X).
c11(X) :- X = "str", q(X).
c12(X) :- X = 'A b', q(X).
:- dynamic d1/1.
d1(X) :- X = f(_), q(X).
q(_).
q(_, _).
s(a1, T) :- clause(a1(X1), B), T = (a1(X1) :- B).
s(a2, T) :- clause(a2(X1), B), T = (a2(X1) :- B).
s(a3, T) :- clause(a3(X1, X2), B), T = (a3(X1, X2) :- B).
s(a4, T) :- clause(a4(X1), B), T = (a4(X1) :- B).
s(a5, T) :- clause(a5(X1), B), T = (a5(X1) :- B).
s(a6, T) :- clause(a6(X1, X2), B), T = (a6(X1, X2) :- B).
s(a7, T) :- clause(a7(X1, X2), B), T = (a7(X1, X2) :- B).
s(a8, T) :- clause(a8(X1), B), T = (a8(X1) :- B).
s(a9, T) :- clause(a9(X1), B), T = (a9(X1) :- B).
s(a10, T) :- clause(a10(X1), B), T = (a10(X1) :- B).
s(a11, T) :- clause(a11(X1, X2), B), T = (a11(X1, X2) :- B).
s(a12, T) :- clause(a12(X1, X2), B), T = (a12(X1, X2) :- B).
s(a13, T) :- clause(a13(X1), B), T = (a13(X1) :- B).
s(a14, T) :- clause(a14(X1), B), T = (a14(X1) :- B).
s(b1, T) :- clause(b1(X1), B), T = (b1(X1) :- B).
s(b2, T) :- clause(b2(X1, X2), B), T = (b2(X1, X2) :- B).
s(b3, T) :- clause(b3(X1), B), T = (b3(X1) :- B).
s(b4, T) :- clause(b4(X1), B), T = (b4(X1) :- B).
s(b5, T) :- clause(b5(X1, X2), B), T = (b5(X1, X2) :- B).
s(b6, T) :- clause(b6(X1, X2), B), T = (b6(X1, X2) :- B).
s(b7, T) :- clause(b7(X1, X2), B), T = (b7(X1, X2) :- B).
s(b8, T) :- clause(b8(X1), B), T = (b8(X1) :- B).
s(b9, T) :- clause(b9(X1, X2), B), T = (b9(X1, X2) :- B).
s(b10, T) :- clause(b10(X1, X2), B), T = (b10(X1, X2) :- B).
s(c1, T) :- clause(c1(X1), B), T = (c1(X1) :- B).
s(c2, T) :- clause(c2(X1, X2), B), T = (c2(X1, X2) :- B).
s(c3, T) :- clause(c3(X1), B), T = (c3(X1) :- B).
s(c4, T) :- clause(c4(X1, X2), B), T = (c4(X1, X2) :- B).
s(c5, T) :- clause(c5(X1), B), T = (c5(X1) :- B).
s(c6, T) :- clause(c6(X1), B), T = (c6(X1) :- B).
s(c7, T) :- clause(c7(X1, X2), B), T = (c7(X1, X2) :- B).
s(c8, T) :- clause(c8(X1), B), T = (c8(X1) :- B).
s(c9, T) :- clause(c9(X1), B), T = (c9(X1) :- B).
s(c11, T) :- clause(c11(X1), B), T = (c11(X1) :- B).
s(c12, T) :- clause(c12(X1), B), T = (c12(X1) :- B).
s(d1, T) :- clause(d1(X1), B), T = (d1(X1) :- B).
pr(T) :- copy_term(T, T1), numbervars(T1, 0, _), writeq(T1), nl.
main :- forall(s(N, T), (writeq(N), write(' '), pr(T))), halt.
PL
cat > "$d/w2.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
q(_).
term_expansion(gen(H, B), [(H :- B)]).
gen(l1(X1), (f(_) = X1, q(X1))).
gen(l2(X1), (X1 = f(A), q(A))).
gen(l3(X1, X2), (X2 = k, X1 = j)).
gen(l4(X1), (X1 = f(_), q(X1))).
s(l1, T) :- clause(l1(X1), B), T = (l1(X1) :- B).
s(l2, T) :- clause(l2(X1), B), T = (l2(X1) :- B).
s(l3, T) :- clause(l3(X1, X2), B), T = (l3(X1, X2) :- B).
s(l4, T) :- clause(l4(X1), B), T = (l4(X1) :- B).
pr(T) :- copy_term(T, T1), numbervars(T1, 0, _), writeq(T1), nl.
main :- forall(s(N, T), (writeq(N), write(' '), pr(T))), halt.
PL
cat > "$d/w3.pl" <<'PL'
:- use_module(library(plunit)).
:- initialization(main).
main :- ( catch(run_tests, E, (print_message(silent, E), true)) -> true ; true ), halt.
:- begin_tests(u).
term_expansion(c2(H), [H]).
c2(p11(a)).
c2((p12(X) :- X = f(_))).
test(unqual) :- p11(a), format("T:unqual~n").
test(conj) :- true, p11(a), format("T:conj~n").
test(neg) :- \+ p11(b), format("T:neg~n").
test(once) :- once(p11(a)), format("T:once~n").
test(unif) :- p12(Y), Y = f(_), format("T:unif~n").
test(fails) :- p11(zzz), format("T:fails~n").
:- end_tests(u).
PL
filt() { case "$1" in w3) grep -o 'T:[a-z]*' | sort ;; *) cat ;; esac; }
for w in w1 w2 w3; do
    (cd "$d" && timeout -k 5 60 "$SWIPL" -q $w.pl </dev/null 2>/dev/null | filt $w > $w.want)
    [ -s "$d/$w.want" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: $SWIPL printed nothing for $w"; exit 2; }
done
fails=0; graded=0
for w in w1 w2 w3; do
    graded=$((graded + 1))
    (cd "$d" && timeout -k 5 60 "$SCRIP" $w.pl </dev/null 2>&1 | filt $w > $w.m3)
    if ! cmp -s "$d/$w.want" "$d/$w.m3"; then fails=$((fails + 1)); echo "  $w m3 differs:"; diff "$d/$w.want" "$d/$w.m3" | head -8; fi
    graded=$((graded + 1))
    if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile --out=$w.s $w.pl </dev/null >/dev/null 2>&1 \
        && gcc -no-pie -o $w.bin $w.s -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d" && timeout -k 5 60 ./$w.bin </dev/null 2>&1 | filt $w > $w.m4)
        if ! cmp -s "$d/$w.want" "$d/$w.m4"; then fails=$((fails + 1)); echo "  $w m4 differs:"; diff "$d/$w.want" "$d/$w.m4" | head -8; fi
    else fails=$((fails + 1)); echo "  $w m4 did not compile or link"; fi
done
echo "PLMOVEDUNIFY_BOARD programs=3 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || { echo "GATE FAIL [$GATE_NAME]"; exit 1; }
echo "GATE OK [$GATE_NAME]"
exit 0
