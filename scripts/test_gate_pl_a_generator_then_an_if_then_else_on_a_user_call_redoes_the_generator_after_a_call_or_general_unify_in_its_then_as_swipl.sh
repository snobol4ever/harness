#!/bin/bash
# test_gate_pl_a_generator_then_an_if_then_else_on_a_user_call_redoes_the_generator_after_a_call_or_general_unify_in_its_then_as_swipl.sh -- THE GATE ARM'S COORDINATE ORIGIN (ceo CEO-1959; row
# prolog-the-gate-arm-origin-sits-after-the-conditions-operand-cells-so-a-then-branch-redo-resumes-the-generator-at-the-wrong-rsp-ceo-1959, built by hq_zetas under the cto; finding
# .github/findings/FINDING-2026-10-25-hq_packages-an-if-then-else-whose-condition-binds-a-fresh-variable-the-then-branch-uses-loses-the-generators-redo.md; class table taken apart by the cfo on 5f0f016f3).
# THE WITNESS: between(1,3,L), ( q1(R0) -> R = R0 ; fail ) with q1(X) :- X = [a,b]. answers L = 1 and then loses the generator (swipl: 1, 2, 3). THE CLASS (cfo, 24 shape probes): it needs (1) a retained generator
# BEFORE the if-then-else (between/3 -- member/2 PASSES, so between's retained activation is part of it), (2) a condition that is a USER-PREDICATE CALL leaving operand cells on the spine (q1(R0) and q1(_) both fail;
# true and atom_codes(abc,R0) as the condition pass -- the fresh variable is NOT the trigger), (3) a then-branch box that reads or pops by an rsp-relative distance: a call (atom_length, is/2, nl, write), the general
# unify leaf (R = R0, R0 = R, R == R0), copy_term -- while an inline unify_const (R = a) passes because it reads its cell through rbp and fails by jumping to the gate's else road. The else arm is irrelevant.
# THE MECHANISM (SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 on the witness: [ZSM-AEXP] RSP EXPECTED-VALUE MISMATCH AT ALPHA depth=64 but op_zdepth=16; [ZSM-DECL-SUM] port=beta checked=3 bad=3): the arm's coordinate origin is placed
# AFTER the condition's 48 bytes of operand cells instead of at the fence the BOUND saved ([rbp+264], the rsp at the arm's entry), so every then-branch distance the plan bakes is 48 bytes short and the then-branch
# call's failure road pops 48 too few before the chain's step resumes between's choice point at the wrong rsp. The planner's own check (zd_check) reads zero violations because it grades the plan against itself.
# SCRIP_OPT=0 changes nothing; every build back to 10-21 shows it; -d2g -s64m change nothing (not the collector).
# THE GATE IS RED ON ORIGIN BY DESIGN and is the DONE-WHEN of that row (wired as a TASK gate, not in the blocking set) until hq_zetas's cure flips it; then it is wired WIRED in the same landing.
# The witness has 8 shapes that must answer [1,2,3] (s1-s8, the class) and 7 controls that already do (p1-p7); the ref was cut from swipl 9.0.4 and swipl 10.1.5 reads it byte-identically.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/iteg-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/iteg.pl" <<'PL'
:- initialization(main).
q1(X) :- X = [a,b].
s1(L, R) :- between(1, 3, L), ( q1(R0) -> R = R0 ; fail ).
s2(L, R) :- between(1, 3, L), ( q1(_) -> atom_length(abc, R) ; fail ).
s3(L, R) :- between(1, 3, L), ( q1(R0) -> copy_term(R0, R) ; fail ).
s4(L, R) :- between(1, 3, L), ( q1(R0) -> R0 = R ; fail ).
s5(L, R) :- between(1, 3, L), ( q1(R0) -> R = x(R0) ; fail ).
s6(L, R) :- between(1, 3, L), ( q1(_) -> R is 1 + 2 ; fail ).
s7(L, R) :- between(1, 3, L), ( q1(R0) -> R0 == [a,b], R = ok ; fail ).
s8(L, R) :- between(1, 3, L), ( q1(R0) -> R = R0 ; R = none ).
p1(L, R) :- between(1, 3, L), ( q1(_) -> R = a ; fail ).
p2(L, R) :- member(L, [1,2,3]), ( q1(R0) -> R = R0 ; fail ).
p3(L, R) :- between(1, 3, L), ( true -> R = a ; fail ).
p4(L, R) :- between(1, 3, L), ( atom_codes(abc, R0) -> R = R0 ; fail ).
p5(L, R) :- between(1, 3, L), ( q1(R0), true -> R = R0 ; fail ).
p6(L, R) :- between(1, 3, L), ( q1(R0) -> true ; fail ), R = R0.
p7(L, R) :- between(1, 3, L), q1(R0), R = R0.
run(G) :- findall(L, call(G, L, _), Ls), write(G-Ls), nl.
main :- forall(member(G, [s1, s2, s3, s4, s5, s6, s7, s8, p1, p2, p3, p4, p5, p6, p7]), run(G)).
PL
cat > "$T/iteg.ref" <<'REF'
s1-[1,2,3]
s2-[1,2,3]
s3-[1,2,3]
s4-[1,2,3]
s5-[1,2,3]
s6-[1,2,3]
s7-[1,2,3]
s8-[1,2,3]
p1-[1,2,3]
p2-[1,2,3]
p3-[1,2,3]
p4-[1,2,3]
p5-[1,2,3]
p6-[1,2,3]
p7-[1,2,3]
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/iteg.pl" "$T/iteg.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes redo the generator after an if-then-else on a user call whose then-branch calls or unifies, as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a generator before an if-then-else on a user call is not redone as swipl redoes it"; exit 1;; esac
