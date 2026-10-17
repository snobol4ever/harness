#!/usr/bin/env bash
# test_gate_pl_a_ball_propagates_past_the_remaining_clauses_of_a_dynamic_predicate.sh -- A BALL IN FLIGHT PROPAGATES PAST THE REMAINING CLAUSES OF A DYNAMIC (PACKET) PREDICATE, AND AN ASSERTED CLAUSE KEEPS ITS BIGNUMS.
# hq_prolog 2026-10-04, the coo's red (pass 36): SWI core/test_arith.pl 175 -> 74 of 220 in both modes, first bad 9f6049d47 (the dynamic database as a
# packet of clause fragments). Two defects of that road: (1) the packet fragment's chain-omega walked to the next visible clause with a ball in flight
# (r15 armed) -- the static chain's step propagates it (its _step_ball arm) -- so a clause that threw had its exception swallowed and the NEXT clause ran;
# under the SWI shim (protect_static_code false) clause/3 seeds static predicates into packets, length/2 among them, so length(_, -1) retried itself for
# ever and died ERROR 246, taking the thirteen units after bigint with it; (2) the run-time compile's term-to-tree conversion (pl_cell_tree) had no
# DT_BIG case, so a bignum inside an asserted clause became the atom '?' (type_error(evaluable, ?/0) in the plunit tests, whose bodies are asserted).
# ARM 1 (both modes): a dynamic p/1 whose first clause throws -- catch sees boom and the second clause never runs (RED on origin 275162cd9: prints
# "second"); ARM 2 (both modes): bignums in asserted clauses (RED on origin: caught(type_error(evaluable,?/0)), dyn_no, ?); ARM 3 (mode 3, under plunit):
# after assert/2 + clause/3, length(_, -1) raises its domain error (RED on origin: ERROR 246). Expected text cut from swipl -q -t halt.
# ARMS cut, cut2 (both modes; the same road, found next): a CUT in a packet clause commits the predicate -- r(a) :- !, fail. r(_). makes r(a) fail
# (RED on c7dda478d: the chain-omega walked to r(_)), while a LOCAL cut (if-then-else, \+, call/1) does not: the chain-omega concedes only
# when B is older than the fragment's header (the gamma's own rule); the call/1 case reds if it concedes on any B != H.
set -u
GATE_NAME=test_gate_pl_a_ball_propagates_past_the_remaining_clauses_of_a_dynamic_predicate
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
PLU="${S4E_CORPUS:-$ROOT/corpus}/tests/prolog/plunit.pl"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$PLU" ] || refuse "no plunit shim at $PLU"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
cat > "$TMPD/ball.pl" <<'EOP'
:- dynamic(p/1).
:- dynamic(q/2).
p(X) :- X > 0, throw(boom).
p(_) :- write(second), nl.
main :- catch(p(1), E, (write(caught(E)), nl)), assertz(q(1, a)), assertz((q(X, b) :- X > 5, throw(qq))), assertz(q(_, c)),
        catch(findall(V, q(9, V), L), E2, (write(caught(E2)), nl)), ( var(L) -> true ; write(L), nl ),
        findall(V, q(1, V), L1), write(L1), nl.
:- initialization(main).
EOP
cat > "$TMPD/big.pl" <<'EOP'
:- initialization(main).
t1 :- A is 1 + 9223372036854775807, A =:= 9223372036854775808.
main :- ( catch(t1, E, (write(caught(E)), nl, fail)) -> write(static_ok) ; write(static_no) ), nl,
        assertz((t2 :- A is 1 + 9223372036854775807, A =:= 9223372036854775808)),
        ( catch(t2, E2, (write(caught(E2)), nl, fail)) -> write(dyn_ok) ; write(dyn_no) ), nl,
        X = 9223372036854775808, assertz(t3(X)), t3(Y), write(Y), nl,
        assertz((t4(Z) :- Z is -9223372036854775809 - 1)), t4(W), write(W), nl.
EOP
cat > "$TMPD/unit.pl" <<'EOP'
:- begin_tests(bigint,
	       [ condition(current_prolog_flag(bounded, false))
	       ]).

:- dynamic
    gmp_clause/2.

fac(1,1) :- !.
fac(X,N) :-
    X > 1,
    X2 is X - 1,
    fac(X2, N0),
    N is N0 * X.

oefac(X, Fac) :-                        % produce large pos and neg ints
    fac(X, F0),
    odd_even_neg(X, F0, Fac).

odd_even_neg(X, V0, V) :-
    (   X mod 2 =:= 0
    ->  V = V0
    ;   V is -V0
    ).

:- if(current_prolog_flag(bounded, false)). % GMP implies rational

ratp(C, X, X ) :-
    C =< 0,
    !.
ratp(Count, In, Out) :-
    succ(Count0, Count),
    T is In + (In rdiv 2),
    ratp(Count0, T, Out).

dec(X, Y) :-
    Y is X - 1.

unbound(_).

:- endif.
test(t1) :- Clause = (gmp_clause(X,Y) :- X is Y + 3), assert(Clause, Ref), clause(H,B,Ref).
test(probe) :- catch(length(_, -1), E, true), E = error(domain_error(not_less_than_zero, -1), _).
:- end_tests(bigint).
EOP
cat > "$TMPD/cut.pl" <<'EOP'
:- initialization(main).
:- dynamic(r/1).
:- dynamic(s/1).
r(a) :- !, fail.
r(_).
s(X) :- X == a, !, \+ true.
s(_) :- true.
main :- ( r(a) -> write(wrong) ; write(cut_ok) ), nl, ( s(a) -> write(wrong) ; write(cut_ok) ), nl, assertz((t(X) :- X == a, !, fail)), assertz(t(_)), ( t(a) -> write(wrong) ; write(cut_ok) ), nl, ( t(b) -> write(ok_b) ; write(wrong_b) ), nl.
EOP
cat > "$TMPD/cut2.pl" <<'EOP'
:- initialization(main).
:- dynamic(p/1). :- dynamic(q/1). :- dynamic(u/1). :- dynamic(v/2). :- dynamic(w/1).
p(X) :- member(X, [1,2,3]), X > 1, !.
p(9).
q(X) :- ( X > 0 -> true ; fail ).
q(_) :- true.
u(X) :- \+ X = a.
u(b).
v(X, Y) :- call((member(Y, [x, y]), !)), X = 1.
v(2, z).
w(1). w(2) :- !. w(3).
main :- findall(X, p(X), L1), write(L1), nl, findall(a, q(1), L2), length(L2, N2), write(N2), nl,
        findall(X, u(X), L3), write(L3), nl, findall(X-Y, v(X, Y), L4), write(L4), nl, findall(X, w(X), L5), write(L5), nl,
        assertz(w(4)), findall(X, (w(X), X > 1), L6), write(L6), nl, ( w(2) -> write(w2) ; write(no) ), nl.
EOP
printf 'main :- run_tests.\n:- initialization(main).\n' > "$TMPD/wrap.pl"
want_ball='caught(boom)
caught(qq)
[a,c]'
want_cut='cut_ok
cut_ok
cut_ok
ok_b'
want_cut2='[2]
2
[b]
[1-x,2-z]
[1,2]
[2]
w2'
want_big='static_ok
dyn_ok
9223372036854775808
-9223372036854775810'
for w in ball big cut cut2; do eval "want=\$want_$w"
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got=$(cd "$TMPD" && timeout -k 5 30 "$SCRIP" "$w.pl" </dev/null 2>/dev/null)
        else got=$( (cd "$TMPD" && timeout -k 5 120 "$SCRIP" --compile -o "$w.s" "$w.pl" </dev/null >/dev/null 2>&1) && gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null && cd "$TMPD" && timeout -k 5 30 "./$w.bin" </dev/null 2>/dev/null); fi
        if [ "$got" = "$want" ]; then echo "  ok  $w $mode"; else echo "  RED $w $mode: got [$(printf '%s' "$got" | tr '\n' '|' | cut -c1-160)] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
    done
done
got=$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" --run -d131072k -s4096k "$PLU" unit.pl wrap.pl </dev/null 2>&1)
if printf '%s' "$got" | grep -q 'pass: bigint:probe' && ! printf '%s' "$got" | grep -q 'ERROR 246'; then echo "  ok  arm 3: after assert/2 + clause/3 under plunit, length(_, -1) raises its domain error"
else echo "  RED arm 3: $(printf '%s' "$got" | grep -E 'probe|ERROR' | head -2 | tr '\n' '|' | cut -c1-160)"; red=$((red+1)); fi
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a ball propagates past a dynamic predicate's remaining clauses and an asserted clause keeps its bignums, in both modes; length/2 raises its error after clause/3 under plunit"
exit 0
