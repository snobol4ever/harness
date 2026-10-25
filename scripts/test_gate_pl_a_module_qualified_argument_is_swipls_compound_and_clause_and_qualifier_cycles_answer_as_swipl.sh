#!/bin/bash
# test_gate_pl_a_module_qualified_argument_is_swipls_compound_and_clause_and_qualifier_cycles_answer_as_swipl.sh -- THE MODULE CONTEXT,
# ARCH-PROLOG-DATABASE.md section 6 (the cto's ruling 2026-10-25, hq_zetas builder; the witness mq1 with swipl 9.0.4's answers). In a module file: a closure or goal argument of a user meta predicate
# declared with an integer spec arrives as swipl's compound Module:Closure or Module:Goal, Module the CONTEXT module (a closure naming a user predicate included, reached through one inheritance step of the key; the flatten's mangled atom stays inside the registry); a goal-position clause call qualified by a module
# (M:clause(H, _, Ref)) answers the head bare when the clause's module is M and Mod:Head from another context; a meta argument declared with the colon spec arrives qualified by its context
# module and a chain a:b:foo is stripped to b:foo; a cyclic qualifier raises type_error(acyclic_term, T) at the call. The program is the witness and the expected output was cut from swipl
# 9.0.4 (a run of the same program). rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/mqw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/mqw.pl" <<'PL'
:- module(mq1, []).
:- initialization(main).
:- meta_predicate solve(2, -), solve0(0, -), run(2, ?, ?), mqual(:), mshow(:).
solve(Pred, R) :- ( Pred = M:t -> R = qualified(M) ; R = bare(Pred) ).
solve0(G, R) :- ( G = M:Goal -> R = q(M, Goal) ; R = bare0(G) ).
run(C, X, Y) :- call(C, X, Y).
mqual(_).
mshow(X) :- writeq(X), nl.
user:ut(_, _).
user:dbl(X, Y) :- Y is X * 2.
mdbl(X, Y) :- Y is X * 3.
t(_, _).
main :-
    solve(t, R), writeq(R), nl,
    solve(ut, Ru), writeq(Ru), nl,
    solve0(true, R0), writeq(R0), nl,
    solve0((true, fail ; true), R2), writeq(R2), nl,
    assert(test_module_2:term, Ref), test_module_2:clause(H, _, Ref), erase(Ref), writeq(H), nl,
    assert(test_module_2:term, R3), clause(H2, _, R3), erase(R3), writeq(H2), nl,
    assert(test_module_2:term, R4), clause(test_module_2:H3, _, R4), erase(R4), writeq(H3), nl,
    T = a:T, catch(mqual(T), error(E, _), true), ( nonvar(E) -> E = type_error(K, _), writeq(K) ; writeq(none) ), nl,
    mshow(foo), mshow(b:c:foo),
    run(dbl, 4, Y), writeq(Y), nl, run(mdbl, 4, Y2), writeq(Y2), nl, run(user:dbl, 5, Y3), writeq(Y3), nl, run(succ, 4, Y4), writeq(Y4), nl,
    maplist(mdbl, [1, 2, 3], L), writeq(L), nl,
    foldl([X, A0, A1]>>(A1 is A0 + X), [1, 2, 3], 0, S), writeq(S), nl.
PL
cat > "$T/mqw.ref" <<'REF'
qualified(mq1)
bare(mq1:ut)
q(mq1,true)
q(mq1,(true,fail;true))
term
test_module_2:term
term
acyclic_term
mq1:foo
c:foo
8
12
10
5
[3,6,9]
6
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/mqw.pl" "$T/mqw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes answer the module-context witness as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- the module-context witness answered differently from swipl in a mode"; exit 1;; esac
