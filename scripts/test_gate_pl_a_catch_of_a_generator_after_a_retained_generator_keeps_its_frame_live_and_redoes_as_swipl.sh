#!/bin/bash
# test_gate_pl_a_catch_of_a_generator_after_a_retained_generator_keeps_its_frame_live_and_redoes_as_swipl.sh -- THE CATCH'S UNMARK KEEPS THE CALLEE'S FRAME (hq_packages, ceo CEO-1959/1960; found on
# Trealla's sundry_shift_compiled, which died on signal 11 at pc 0xb0 in both modes; the SWI-dialect class of every clause that runs a retained generator and then catch/3 of a generator).
# THE WITNESS: s1(Y) :- member(_, [a,b]), catch(member(Y, [k1,k2]), _, true). answers [k1,k2,k1,k2] in swipl; SCRIP exited on SIGSEGV at pc 0xb0 -- no shift, no continuation, no engine is involved, and
# the same catch directly under shift/1 (s8) is only the shape that surfaced it. THE MECHANISM (measured in gdb on the mode-4 binary): the catch's IR_UNMARK is the nondeterministic-exit pop (ival & 8,
# bb_bound.cpp: B returns to the choice banked at the bound only when the goal left none of its own), which restores nothing of rsp -- the callee's frame, carrying its choice record, stays below rsp.
# 579537ddb (planner: a run headed by the UNMARK that restores a BOUND's rsp belongs to that BOUND's family) re-homed EVERY UNMARK-headed run into its BOUND's family, this one too, so the call's success
# tail emitted `add rsp, 144` -- 144 bytes up INTO member's frame (rsp 0x..d7c0 -> 0x..d850, the record at d830) -- and the next call (the coroutine park, a findall add, a write) overwrote the record
# B pointed at; the next backtrack jumped through a garbage redo address (0xb0 = the frame size). The no-shift form of the same clause emitted no add and ran. Bisected over the 23 commits 02de2f8e8..579537ddb
# on two scratch builds: 62968bae5 answers, 579537ddb crashes. CURED in zd_pl_bases: a UNMARK with ival & 8 keeps the family it had (none), exactly as before 579537ddb, and the new re-homing applies to the UNMARKs that
# restore rsp (the if-then-else gate, 8 shapes + 7 controls, stays green).
# The witness has 7 class shapes (s1-s7) and 2 under shift/1 (s8, s9) that crashed, and 7 controls (c1-c7) that already answered; the ref was cut from swipl 9.0.4 and swipl 10.1.5 reads it byte-identically.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/cgg-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/cgg.pl" <<'PL'
:- initialization(main).
k(C) :- ( C = cont(K) -> call(K) ; call(C) ).
s1(Y) :- member(_, [a,b]), catch(member(Y, [k1,k2]), _, true).
s2(Y) :- between(1, 2, _), catch(member(Y, [k1,k2]), _, true).
s3(Y) :- member(X, [a,b]), catch(member(Y, [X,k2]), _, true).
s4(Y) :- member(_, [a,b]), catch(member(Y, [k1,k2]), _, fail).
s5(Y) :- member(_, [a,b]), catch((member(Y, [k1,k2]), true), _, true).
s6(Y) :- member(_, [a,b]), findall(Z, catch(member(Z, [k1,k2]), _, true), Y).
s7(Y) :- member(_, [a,b]), catch(member(Y, [k1,k2]), foo, true).
s8(Y) :- shift(a), catch(member(Y, [k1,k2]), _, true).
s9(Y) :- shift(a), findall(Z, catch(member(Z, [k1,k2]), _, true), Y).
c1(Y) :- catch(member(Y, [k1,k2]), _, true).
c2(Y) :- member(_, [a,b]), catch(true, _, true), Y = 1.
c3(Y) :- member(_, [a,b]), catch(throw(x), x, Y = caught).
c4(Y) :- member(_, [a,b]), once(member(Y, [k1,k2])).
c5(Y) :- member(_, [a,b]), catch(member(Y, [k1,k2]), _, true), !.
c6(Y) :- member(_, [a,b]), catch(catch(member(Y, [k1,k2]), foo, true), bar, true).
c7(Y) :- shift(a), catch(throw(x), x, Y = caught).
run(G) :- findall(Y, call(G, Y), L), write(G-L), nl.
runk(G) :- findall(Y, (reset(call(G, Y), _, C), k(C)), L), write(G-L), nl.
main :- forall(member(G, [s1, s2, s3, s4, s5, s6, s7, c1, c2, c3, c4, c5, c6]), run(G)), forall(member(G, [s8, s9, c7]), runk(G)).
PL
cat > "$T/cgg.ref" <<'REF'
s1-[k1,k2,k1,k2]
s2-[k1,k2,k1,k2]
s3-[a,k2,b,k2]
s4-[k1,k2,k1,k2]
s5-[k1,k2,k1,k2]
s6-[[k1,k2],[k1,k2]]
s7-[k1,k2,k1,k2]
c1-[k1,k2]
c2-[1,1]
c3-[caught,caught]
c4-[k1,k1]
c5-[k1]
c6-[k1,k2,k1,k2]
s8-[k1,k2]
s9-[[k1,k2]]
c7-[caught]
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/cgg.pl" "$T/cgg.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes keep the callee's frame live under a catch of a generator after a retained generator, and redo it, as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a catch of a generator after a retained generator crashed or answered differently from swipl"; exit 1;; esac
