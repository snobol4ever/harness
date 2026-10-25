#!/bin/bash
# test_gate_pl_a_cut_local_to_a_shifted_goal_resumes_its_continuation_as_swipl.sh -- A RESUMED CONTINUATION'S CUT TIDIES ONLY ITS OWN TRAIL SEGMENT (ceo CEO-1959, hq_packages; the cfo's ruling on the finding
# .github/findings/FINDING-2026-10-25-hq_packages-a-cut-inside-a-resumed-continuation-tidies-the-trail-across-the-park-gap.md; SWI core/test_continuation.pl continuation:ifthen#1).
# A shift parks the coroutine; the main side grows the shared trail while it is parked; on the resume the coroutine's cut (once/1, the condition of ->, a disjunction's cut, *->) ran x86_pl_tr_tidy from the mark
# of the barrier it returned to -- BELOW the park gap -- and compacted the main side's entries judged against the coroutine's HB; the park fence (pl_floor) then refused the SUCCESSFUL continuation with
# permission_error(backtrack, continuation, done). The tidy now starts its walk at max(the barrier's mark, the activation's trail FLOOR), the floor being the header word rt_plco_resume writes at the resume
# (PL_TR_FLOOR_OFF, the header grew from 64 to 128 bytes); the fence reads the same word and keeps its refusal for a continuation that fails back across the floor. THE WITNESS shapes every cut that is
# local to a shifted goal, with and without a binding made by the main side while the coroutine is parked, plus the exact ifthen case; its ref was cut from swipl 9.0.4 and swipl 10.1.5 reads it byte-identically.
# NOT in the witness, by design: shapes that FAIL back across the floor (\+ \+, forall, a throw caught outside) -- the documented divergence, still refused.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/ctcut-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/ctcut.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
a1(R) :- shift(hello(X)), format(atom(R), 'Hello ~w', [X]).
a2(R) :- once(shift(hello(X))), format(atom(R), 'Hello ~w', [X]).
a3(R) :- ( shift(hello(X)) -> format(atom(R), 'Hello ~w', [X]) ; true ).
a4(R) :- ( shift(hello(_)) -> R = then ; R = else ).
a5(R) :- ( shift(hello(_)), true -> R = then ; R = else ).
a6(R) :- ( true, shift(hello(_)) -> R = then ; R = else ).
a7(R) :- shift(hello(_)), !, R = cut.
a8(R) :- ( shift(hello(_)), ! ; true ), R = disj_cut.
a9(R) :- once(( shift(hello(X)), Y = X )), R = got(Y).
a11(R) :- ( shift(hello(_)) *-> R = soft_then ; R = soft_else ).
a15(R) :- once(shift(hello(_))), once(shift(hello(_))), R = twice.
run(G, Bind, R) :- reset(call(G, R0), hello(X), Cont), ( Bind == bind -> X = world ; true ), ( Cont == 0 -> R = R0 ; ( call(Cont) , R = R0 ) ).
show(Bind, R) :- ( Bind == bind -> writeq(R) ; atom(R), sub_atom(R, 0, _, _, 'Hello') -> writeq(hello_atom) ; var(R) -> writeq(unbound) ; ground(R) -> writeq(R) ; writeq(nonground) ).
t(G, Bind) :- ( catch(run(G, Bind, R), error(E, _), ( E =.. [En|_], writeq(G-Bind-error(En)), nl, fail )) -> write(G-Bind), write(': '), show(Bind, R), nl ; write(G-Bind), write(': failed'), nl ).
r1(R) :- reset(shift_in_cond(R), hello(X), Cont), X = world, call(Cont).
shift_in_cond(R) :- ( shift(hello(X)) -> format(atom(R), 'Hello ~w', [X]) ; true ).
main :- forall(member(G, [a1, a2, a3, a4, a5, a6, a7, a8, a9, a11, a15]), forall(member(B, [nobind, bind]), t(G, B))), r1(R1), writeq(r1(R1)), nl.
PL
cat > "$T/ctcut.ref" <<'REF'
a1-nobind: hello_atom
a1-bind: 'Hello world'
a2-nobind: hello_atom
a2-bind: 'Hello world'
a3-nobind: hello_atom
a3-bind: 'Hello world'
a4-nobind: then
a4-bind: then
a5-nobind: then
a5-bind: then
a6-nobind: then
a6-bind: then
a7-nobind: cut
a7-bind: cut
a8-nobind: disj_cut
a8-bind: disj_cut
a9-nobind: nonground
a9-bind: got(world)
a11-nobind: soft_then
a11-bind: soft_then
a15-nobind-error(existence_error)
a15-nobind: failed
a15-bind-error(existence_error)
a15-bind: failed
r1('Hello world')
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/ctcut.pl" "$T/ctcut.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes resume a continuation whose goal cuts locally across its shift, as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a continuation with a cut local to the shifted goal does not resume as swipl resumes it"; exit 1;; esac
