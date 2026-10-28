#!/bin/bash
# test_gate_icn_a_value_producer_inside_a_user_procedure_call_argument_gets_its_frame_slot_and_answers_as_iconx.sh -- THE OPERAND THE ROW DOES NOT CARRY (row
# icon-a-value-producer-in-an-every-scan-body-gets-its-frame-slot-again-after-planner-step-4b-ceo-2006, found by the coo's identity pass, worked by hq_zetas).
# THE WITNESS: a program defining its own Image(x) and calling Image(every 1 to 3) | "none" aborted the compile with FATAL drive_value_slot: IR op=13 is a value-producer with no
# frame slot, in both modes, on every build since planner step 4b (a970b2748). The call's result is the DEREF row's operand 0 and the call is no row of the chain.
# THE MECHANISM: 4b made drive_value_slot read the node's own plan row; an operand the chain does not carry as a row has none, and the layout answer it used to ask for had no
# reader left. CURED (hq_zetas): the planner records the layout slot of every operand-reachable node that is no row (zeta_plan_t v_xoff) and drive_value_slot reads it.
# w.icn is the minimal witness, its ref the Icon semantics (an every that runs dry fails, so the alternation answers none); the two package programs are oracle-cut refs from
# the corpus (Jcon checkfpx, Zona checkfpc) and aborted the same way; IPL patchu needs its argv and stdin, so it is graded by its compile alone.
# rc 0 every witness equals its ref in both modes and patchu compiles; rc 1 a witness differs or a compile aborts; rc 2 cannot measure (no SCRIP beside the harness).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/icnxop-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<'ICN'
procedure main()
   write("a ", Image(every 1 to 3) | "none");
   write("b ", Image(every i := 1 to 3 do write(i)) | "none");
   write("c ", Image(2) | "none");
end
procedure Image(x)
   return x;
end
ICN
cat > "$T/w.ref" <<'REF'
a none
1
2
3
b none
c 2
REF
P="$HERE/../../corpus/packages/icon"
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/w.icn" "$T/w.ref" "$P/jcon_tests/checkfpx.icn" "$P/jcon_tests/checkfpx.ref" "$P/arizona_tests/general/checkfpc.icn" "$P/arizona_tests/general/checkfpc.ref" 2>&1)"; rc=$?
echo "$out" | tail -7
pc=0; timeout -k 2 60s ./scrip --compile -o /dev/null "$P/ipl/progs/patchu.icn" < /dev/null > /dev/null 2>&1 || pc=1
echo "PATCHU compile rc=$pc"
[ "$rc" = 2 ] && { echo "REFUSE(2): the witness runner could not measure"; exit 2; }
[ "$rc" = 0 ] && [ "$pc" = 0 ] && { echo "GATE OK -- a value-producer that is no row of the chain gets its frame slot from the plan, both modes answer as the oracle-cut refs"; exit 0; }
echo "GATE FAIL -- a call argument of a user procedure that is an every aborts the compile or answers differently"; exit 1
