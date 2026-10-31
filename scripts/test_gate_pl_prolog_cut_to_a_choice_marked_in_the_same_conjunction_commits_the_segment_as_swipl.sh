#!/bin/bash
# test_gate_pl_prolog_cut_to_a_choice_marked_in_the_same_conjunction_commits_the_segment_as_swipl.sh -- THE SEGMENT COMMIT OF ARCH-PROLOG-C-OUT-OF-THE-BOX section 2.3 (the cto's ruling
# 2026-10-31 12:0x CDT, built by the cqo in row prolog-swi-suite-to-100-ceo-1981; SWI core/test_misc cut_to and cut_to_cleanup).
# THE RULING: B names a frame and the in-frame choices are reached only by the compile-time omega wiring, so B := Ch prunes nothing; LOWER recognises prolog_current_choice(V) followed in the
# same conjunction by prolog_cut_to(V), V fresh and used nowhere else, and lowers the segment between them as ( Seg -> true ): the bound banks B and the trail mark, the fence commit restores them,
# and a pruned call_cleanup runs its cleanup on the commit road. The run-time meta-call road (pl_cutcall_walk) compiles a goal carrying the pair as it compiles a goal carrying a cut, with V one
# leaf. A prolog_cut_to with no mark in its clause raises error(system_error(unsupported(prolog_cut_to/1)), prolog_cut_to/1): DEBT against swipl until the choice-record rung, not graded here.
# THE WITNESS: t1 the pair around between/3 inside findall/3; t2 call_cleanup pruned by the pair runs its cleanup; t3 the mark after an outer member/2 keeps the outer choice; t4 the pair in an
# if-then-else condition, the later test failing with no choice left; t5 the pair inside a goal built at run time and meta-called; t6 an empty segment. Red on origin c66534734 in both modes
# (existence_error prolog_current_choice/1). The ref was cut from swipl 9.0.4.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no SCRIP beside the harness).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/cutto-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/cutto.pl" <<'PL'
:- initialization(main).
:- dynamic cl/0.
t1 :- findall(X, (prolog_current_choice(Ch), between(1, 5, X), prolog_cut_to(Ch)), L), writeq(L), nl.
t2 :- retractall(cl), prolog_current_choice(Chp), call_cleanup(between(1, 2, _), assert(cl)), prolog_cut_to(Chp), ( retract(cl) -> writeq(cleaned) ; writeq(not_cleaned) ), nl.
t3 :- findall(X-Y, (member(X, [a, b]), prolog_current_choice(C), member(Y, [1, 2, 3]), Y > 1, prolog_cut_to(C)), L), writeq(L), nl.
t4 :- ( prolog_current_choice(C), member(Z, [p, q]), prolog_cut_to(C), Z == q -> writeq(yes) ; writeq(no) ), nl.
g(X, (prolog_current_choice(C), between(1, 5, X), prolog_cut_to(C))).
t5 :- g(X, G), findall(X, call(G), L), writeq(L), nl.
t6 :- findall(X, (prolog_current_choice(C), prolog_cut_to(C), member(X, [u, v])), L), writeq(L), nl.
main :- t1, t2, t3, t4, t5, t6, writeq(ok), nl.
PL
cat > "$T/cutto.ref" <<'REF'
[1]
cleaned
[a-2,b-2]
no
[1]
[u,v]
ok
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/cutto.pl" "$T/cutto.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes commit the segment between prolog_current_choice/1 and prolog_cut_to/1 as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- the segment between prolog_current_choice/1 and prolog_cut_to/1 does not answer as swipl"; exit 1;; esac
