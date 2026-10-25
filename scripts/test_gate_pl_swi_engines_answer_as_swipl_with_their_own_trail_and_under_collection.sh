#!/bin/bash
# test_gate_pl_swi_engines_answer_as_swipl_with_their_own_trail_and_under_collection.sh
# -- SWI ENGINES (ceo CEO-1960/1964/1966, row prolog-swi-engines-designed-by-the-cto-and-built-ceo-1960; the cto's design ARCH-PROLOG-THREADS.md sec 4; SWI engines/test_engines.pl). engine_create/3,4, engine_next/2,
# engine_next_reified/2, engine_yield/1, engine_post/2,3, engine_fetch/1, engine_destroy/1, engine_self/1, current_engine/1 and is_engine/1 are a LOCAL prelude library (prelude/engines.pl) over five leaves that drive a
# generator coroutine (the '$co_*' road's cousin) running on the engine's OWN trail arena: a caller that backtracks across engine_next/2 never undoes the engine's bindings, an engine that backtracks into its goal
# never undoes the caller's, an answer or yield is copied to the heap before it crosses the switch, an exception in the body crosses as data and is re-thrown on the caller's stack. TWO WITNESSES, refs cut from swipl
# 9.0.4 (/usr/bin/swipl, the suite's oracle): behaviour (the findall/yield/post/error/alias/no_data cases, a caller that backtracks and repeat-fails across engine_next, no variable sharing, mismatch consuming an
# answer, nested engines, the destroyed- and exhausted-engine rules, the errors outside an engine) and a collection stress (an engine growing a structure across yields while the caller churns the heap, 5,000
# answers, eight engines of a hundred) -- run in both modes. NOTE the oracles differ on one line, engine_next_reified of an exception: swipl 9.0.4 answers exception(Ball), swipl 10.1.5 throw(Ball); the ref is
# the suite oracle's. NOT HERE: reclaiming an UNREACHABLE engine (it is destroyed only by engine_destroy/1 until the collector's HB_ENGINE sweep lands), the threads-conditional count case.
# rc 0 both modes equal the swipl-cut refs; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/engw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/engw.pl" <<'PL'
:- use_module(library(lists)).
:- use_module(library(apply)).
:- initialization(main).
sh(Name, T) :- \+ \+ ( numbervars(T, 0, _), print(Name-T), nl ).
t(Name, G) :-
    (   catch(G, E, ( E = error(F, _) -> ( sh(Name-err, F) ) ; ( sh(Name-ball, E) ) ))
    ->  true
    ;   sh(Name, failed)
    ).
drain(E, [H|T]) :- engine_next(E, H), !, drain(E, T).
drain(_, []).
sum(Sum) :- engine_fetch(New), Sum1 is New + Sum, engine_yield(Sum1), sum(Sum1).
main :-
    t(findall, ( engine_create(X, between(1, 5, X), E1), drain(E1, L1), sh(l, L1), engine_destroy(E1) )),
    t(backtracking_caller, ( engine_create(X, member(X, [a,b,c,d]), E2),
        findall(Y, ( between(1, 4, _), engine_next(E2, Y) ), L2), sh(l, L2), engine_destroy(E2) )),
    t(repeat_fail, ( engine_create(X, between(1, 3, X), E3),
        findall(Y, ( repeat, ( engine_next(E3, Y) -> true ; !, fail ) ), L3), sh(l, L3), engine_destroy(E3) )),
    t(no_sharing, ( engine_create(f(A, B), ( A = 1 ; A = 2, B = x ), E4), engine_next(E4, T1), engine_next(E4, T2), sh(a, T1-T2), ( var(A) -> sh(outer, unbound) ; sh(outer, bound) ), engine_destroy(E4) )),
    t(yield_and_answers, ( engine_create(X, ( engine_yield(first), ( X = 1 ; X = 2 ) ), E5), drain(E5, L5), sh(l, L5), engine_destroy(E5) )),
    t(post, ( engine_create(_, sum(0), E6), maplist(engine_post(E6), [1,2,3,4], S6), sh(sums, S6), engine_destroy(E6) )),
    t(no_data, ( engine_create(_, sum(0), E7, [alias(e7)]), call_cleanup(engine_next(E7, _), engine_destroy(E7)) )),
    t(post_twice, ( engine_create(_, sum(0), E8, [alias(e8)]), engine_post(E8, 1), call_cleanup(engine_post(E8, 2), engine_destroy(E8)) )),
    t(reified, ( engine_create(X, member(X, [p]), E9), engine_next_reified(E9, R1), engine_next_reified(E9, R2), sh(r, R1-R2), engine_destroy(E9) )),
        t(error, ( engine_create(_, throw(foo), E11), catch(engine_next(E11, _), Ex, true), sh(caught, Ex), engine_destroy(E11) )),
    t(alias, ( engine_create(X, engine_self(X), E12, [alias(eng_a)]), sh(handle, E12), engine_next(E12, Al), sh(self, Al),
        ( is_engine(eng_a) -> sh(is_engine, yes) ; sh(is_engine, no) ), engine_destroy(eng_a), ( is_engine(eng_a) -> sh(is_engine, yes) ; sh(is_engine, no) ) )),
    t(alias_taken, ( engine_create(x, true, E13, [alias(eng_b)]), call_cleanup(engine_create(y, true, _, [alias(eng_b)]), engine_destroy(E13)) )),
    t(next_destroyed, ( engine_create(x, true, E14, [alias(e14)]), engine_destroy(E14), engine_next(E14, _) )),
    t(mismatch_consumes, ( engine_create(X, member(X, [1,2,3]), E15), ( engine_next(E15, 99) -> sh(m, matched) ; sh(m, failed) ), engine_next(E15, Z), sh(z, Z), engine_destroy(E15) )),
    t(filter, ( engine_create(X, ( member(X, [1,2,3]), X > 1 ), E16), drain(E16, L16), sh(l, L16), engine_destroy(E16) )),
    t(immediate_fail, ( engine_create(_, fail, E17, [alias(e17)]), ( engine_next(E17, _) -> sh(n1, yes) ; sh(n1, no) ), ( engine_next(E17, _) -> sh(n2, yes) ; sh(n2, no) ), engine_destroy(E17) )),
    t(current_engine, ( findall(E, current_engine(E), Es0), length(Es0, N0), engine_create(_, true, Ea), engine_create(_, true, Eb),
        findall(E, current_engine(E), Es1), length(Es1, N1), D1 is N1 - N0, sh(created, D1), engine_destroy(Ea), engine_destroy(Eb),
        findall(E, current_engine(E), Es2), length(Es2, N2), D2 is N2 - N0, sh(after_destroy, D2) )),
    t(nested, ( engine_create(X, ( engine_create(Y, member(Y, [10,20]), In), engine_next(In, V1), engine_next(In, V2), engine_destroy(In), X is V1 + V2 ), E18), engine_next(E18, R18), sh(nested, R18), engine_destroy(E18) )),
    t(destroy_twice, ( engine_create(x, true, Ed, [alias(ed)]), engine_destroy(Ed), engine_destroy(ed) )),
    t(destroy_after_exhaust, ( engine_create(x, fail, Ee, [alias(ee)]), ( engine_next(Ee, _) -> true ; true ), ( is_engine(ee) -> sh(is, yes) ; sh(is, no) ), engine_destroy(ee), ( is_engine(ee) -> sh(is, yes) ; sh(is, no) ) )),
    t(reified_after_exhaust, ( engine_create(x, fail, Ef, [alias(ef)]), engine_next_reified(Ef, Rf1), sh(r1, Rf1), engine_next_reified(Ef, Rf2), sh(r2, Rf2), engine_destroy(ef) )),
    t(exception_then_next, ( engine_create(_, throw(e1), Eg, [alias(eg)]), catch(engine_next(Eg, _), _, true), ( is_engine(eg) -> sh(is, yes) ; sh(is, no) ), catch(engine_next(Eg, _), Bg, true), sh(b2, Bg), engine_destroy(eg) )),
    t(post_to_exhausted, ( engine_create(_, true, Eh, [alias(eh)]), ( engine_next(Eh, _) -> true ; true ), engine_post(Eh, x), sh(post, ok), engine_destroy(eh) )),
    t(reified_exc_shape, ( engine_create(_, throw(oops), Ei), engine_next_reified(Ei, Ri), Ri =.. [Fi|_], sh(functor, Fi), engine_destroy(Ei) )),
    t(yield_outside, engine_yield(x)),
    t(fetch_outside, engine_fetch(_)),
    t(unbound_engine, engine_next(_, _)),
    t(not_an_engine, engine_next(foo(bar), _)),
    t(bindings_inside, ( engine_create(S, ( length(L, 3), maplist(=(z), L), atomic_list_concat(L, '-', S) ), E19), engine_next(E19, R19), sh(s, R19), engine_destroy(E19) )),
    t(many, ( numlist(1, 30, Ns), maplist([N, E]>>engine_create(N, true, E), Ns, Engs), maplist([En, V]>>engine_next(En, V), Engs, Vs), sum_list(Vs, Sum), sh(sum, Sum), maplist(engine_destroy, Engs) )).
PL
cat > "$T/engw.ref" <<'REF'
l-[1,2,3,4,5]
l-[a,b,c,d]
l-[1,2,3]
a-(f(1,A)-f(2,x))
outer-unbound
l-[first,1,2]
sums-[1,3,6,10]
no_data-err-existence_error(term,delivery,e7)
post_twice-err-permission_error(post_to,engine,e8)
r-(the(p)-no)
caught-foo
handle-eng_a
self-eng_a
is_engine-yes
is_engine-no
alias_taken-err-permission_error(create,engine,eng_b)
next_destroyed-err-existence_error(engine,e14)
m-failed
z-2
l-[2,3]
n1-no
immediate_fail-err-existence_error(engine,e17)
created-2
after_destroy-0
nested-30
destroy_twice-err-existence_error(engine,ed)
(is)-yes
(is)-no
r1-no
r2-exception(error(existence_error(engine,ef),context(system:engine_next/2,A)))
(is)-yes
b2-error(existence_error(engine,eg),context(system:engine_next/2,A))
post-ok
functor-exception
yield_outside-err-permission_error(execute,vmi,'I_YIELD')
fetch_outside-err-existence_error(term,delivery,main)
unbound_engine-err-instantiation_error
not_an_engine-err-type_error(engine,foo(bar))
s-'z-z-z'
sum-465
REF
cat > "$T/engs.pl" <<'PL'
:- use_module(library(lists)).
:- use_module(library(apply)).
:- initialization(main).
grow(N, L) :- grow(1, N, [], L).
grow(I, N, A, L) :- ( I > N -> L = A ; A1 = [f(I, g(I, [I,I,I]))|A], length(A1, Len), engine_yield(Len), I1 is I + 1, grow(I1, N, A1, L) ).
churn(0) :- !.
churn(K) :- numlist(1, 300, L), maplist([X, f(X, Y)]>>(Y is X * 2), L, _), K1 is K - 1, churn(K1).
drive(E, Acc, Out) :- ( engine_next(E, V) -> churn(2), drive(E, [V|Acc], Out) ; Out = Acc ).
sumloop(E, A, S) :- ( engine_next(E, f(I, L)) -> length(L, Ln), A1 is A + I + Ln, sumloop(E, A1, S) ; S = A ).
main :-
    engine_create(L, grow(300, L), E1),
    drive(E1, [], Out), Out = [Last|_], length(Out, N1), length(Last, LL), format("grow yields=~w last_len=~w~n", [N1, LL]),
    engine_destroy(E1),
    engine_create(X, ( between(1, 5000, I), X = f(I, [a,b,c,I]) ), E2),
    sumloop(E2, 0, S2), format("sum=~w~n", [S2]),
    engine_destroy(E2),
    findall(S, ( between(1, 8, K), engine_create(Y, ( between(1, 100, J), Y is J * K ), Ek), findall(Z, ( between(1, 100, _), engine_next(Ek, Z) ), Zs), sum_list(Zs, S), engine_destroy(Ek) ), Ss),
    sum_list(Ss, Tot), format("many=~w~n", [Tot]).
PL
cat > "$T/engs.ref" <<'REF'
grow yields=301 last_len=300
sum=12522500
many=181800
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/engw.pl" "$T/engw.ref" "$T/engs.pl" "$T/engs.ref" 2>&1)"; rc=$?
echo "$out" | tail -5
case $rc in 0) echo "GATE OK -- both modes answer the engine witnesses as swipl 9.0.4"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- the engines do not answer as swipl 9.0.4"; exit 1;; esac
