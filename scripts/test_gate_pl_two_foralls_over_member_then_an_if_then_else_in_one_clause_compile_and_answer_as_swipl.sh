#!/bin/bash
# test_gate_pl_two_foralls_over_member_then_an_if_then_else_in_one_clause_compile_and_answer_as_swipl.sh -- THE UNMARK-OVER-BOUND CHAIN IN THE INDEF MARKING (row
# prolog-two-forall-over-member-of-a-list-literal-then-an-if-then-else-in-one-clause-fatals-in-x86-zop-key-with-no-frame-bytes, found by hq_packages, worked by hq_zetas under the cto).
# THE WITNESS: rd :- forall(member(S,[a]),t(S)), forall(member(X,[1,2]),t(X)), (integer(1) -> true ; true). aborted the compile with FATAL x86_zop: offset 584 is a key with no frame bytes behind
# it (zls_key_unbacked) at the IR_UNMARK of the if-then-else's BOUND, in both modes, on every build back to 336a29fcd.
# THE MECHANISM: zd_pl_bases marks the runs after a retaining call INDEF, and skips an UNMARK-headed run whose BOUND's run is known. The second forall's outer BOUND sits in a run headed by the
# first forall's outer UNMARK, a run the UNMARK-over-BOUND rule makes known only AFTER the marking, so the second forall's UNMARKs and the whole tail behind them (the if-then-else's spine BOUND
# and its failure-arm UNMARK, in two runs with no shared coordinate) went INDEF and the UNMARK had no address for its BOUND's key.
# CURED (hq_zetas): the skip test follows the UNMARK-over-BOUND chain to a known run (restored() in zd_pl_bases), the rule the later pass already applies.
# r1 is the witness; r2 (three foralls), r3 (a double negation between), r4 (a condition made of foralls) are the same class and read red before the cure; r5 (a retaining call in the condition,
# its BOUND on RBP) and r6 (a failing condition) are controls that passed before. The ref was cut from swipl 9.0.4.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs or the compile aborts; rc 2 cannot measure (no SCRIP beside the harness).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/tfite-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/tfite.pl" <<'PL'
:- initialization(main).
t(_).
r1 :- forall(member(S, [a]), t(S)), forall(member(X, [1,2]), t(X)), ( integer(1) -> write(then1) ; write(else1) ), nl.
r2 :- forall(member(S, [a]), t(S)), forall(member(X, [1,2]), t(X)), forall(member(Y, [p,q,r]), t(Y)), ( integer(1) -> write(then2) ; write(else2) ), nl.
r3 :- forall(member(S, [a]), t(S)), \+ \+ member(_, [1,2]), forall(member(X, [1,2]), t(X)), ( \+ integer(a) -> write(neg3) ; write(pos3) ), nl.
r4 :- forall(member(S, [a,b]), t(S)), forall(member(X, [1,2]), X > 0), ( integer(1) -> write(then4) ; write(else4) ), nl, ( forall(member(Z, [1,2]), Z < 2) -> write(all4) ; write(notall4) ), nl.
r5 :- forall(member(S, [a]), t(S)), forall(member(X, [1,2]), t(X)), ( member(Q, [1,2,3]), Q > 1 -> write(q5(Q)) ; write(none5) ), nl.
r6 :- forall(member(S, [a]), t(S)), forall(member(X, [1,2]), t(X)), ( integer(a) -> write(then6) ; write(else6) ), nl.
main :- r1, r2, r3, r4, r5, r6, write(ok), nl.
PL
cat > "$T/tfite.ref" <<'REF'
then1
then2
neg3
then4
notall4
q5(2)
else6
ok
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/tfite.pl" "$T/tfite.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes compile and answer as swipl for two or more foralls over member/2 followed by an if-then-else in one clause"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- foralls over member/2 followed by an if-then-else in one clause do not compile or answer as swipl"; exit 1;; esac
