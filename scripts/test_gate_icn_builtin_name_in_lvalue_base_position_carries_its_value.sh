#!/usr/bin/env bash
# test_gate_icn_builtin_name_in_lvalue_base_position_carries_its_value.sh -- hq_C 2026-09-10, CEO-534,
# row icon-jcon-errors-red-both-modes-diagnosed-to-its-first-divergence-and-cured (jcon errors.icn line 88).
#
# WHAT IT PINS. A bare builtin/procedure NAME used as the BASE of an lvalue-capable operation -- x[i], x[i:j],
# x[i]:=v, ?x, !x -- must carry its procedure value in &errorvalue when that operation raises, exactly as the
# Arizona oracle does. SCRIP lowers a bare name in base position to IR_VAR_REF (for assignability: x[1]:=5
# needs it) while every OTHER operand position goes through lower() and resolves the name to its value; the
# IR_VAR->IR_PROC_VALUE post-pass in lower_icon_resolve_call_kinds() (src/lower/lower_icon.c) therefore never
# saw the base, and &errorvalue read &null. That pass now visits IR_VAR_REF under its own unchanged guard.
#
# ⭐ WHY THE GUARD LIVES IN A POST-PASS AND NOT AT THE LOWERING SITE, which is the reusable part. The test is
# "this name is a builtin/procedure AND is not an assignable variable HERE", and the second half is a
# WHOLE-GRAPH question -- is this name ever the target of an assignment in this procedure -- which cannot be
# answered while the graph is still being built. The post-pass already answered it for value position. Widening
# its node filter by one op was the whole cure; a new guard at the lowering site would have had to re-derive it
# and could not have.
# ⛔ A patch at the runtime raise site CANNOT work and this is measured, not argued: c_rt_subscript_var is
# handed a cell-form varref (DT_N slen=1, ptr=<stack cell>) with NO NAME present, so no runtime-side lookup
# can recover `pull`. A name-form patch there compiles, reads correctly and changes nothing.
#
# ⛔ THIS GATE ASSERTS THE ORACLE'S OWN VALUES, NOT THE ABSENCE OF THE OLD BAD ONE. Grepping for "&null" would
# go green the moment the wrong value acquired a different spelling. Every want below is cut from a FRESHLY
# BUILT icont/iconx binary -- ⛔ never from a stale ./probe left in the scratch dir by an earlier compile, which
# is how a failed icont run reads as a passing oracle.
# ⛔⭐⭐ `SECTION` (`pull[1:2]`) IS BLOCKING, AND THE STORY OF HOW IT NEARLY WAS NOT IS THE SECOND LESSON HERE.
# It is a TWO-SEAT COMPOSITION: 4c1ed8593 (another seat, same sitting) made a section of the null value RAISE
# 110 instead of quietly slicing nothing, and this commit made the base carry its VALUE. Neither cure alone
# greens this arm; together the shape matches the oracle exactly, in both modes.
# ⛔ I WROTE THIS ARM AS INFORMATIONAL-AND-NOT-OURS FIRST, and it was already cured in the tree I was about to
# land on. That is CLAUDE.md's tolerated-red rule biting inside a single sitting: a carve-out is written when
# the defect is discovered and read long after it is closed, so it goes stale in the FLATTERING direction --
# it invites the next reader to tolerate a failure that is now a live regression. ⭐ THE CHEAP GUARD IS THE ONE
# THAT CAUGHT IT: run the DONE-WHEN after the rebase, not before, and read every arm of the output rather than
# the verdict line -- the ✅ on a row I had just documented as red is what exposed it. A carve-out needs a
# re-measurement on the merged tree before it ships, exactly like any other number.
# ⛔ IT IS ALSO WHERE THIS GATE ALMOST PINNED A FICTION: read inside a multi-error program the expression
# reported 114 in one probe and 116 in the next -- each time the number the PRECEDING record had raised. A
# number that moves when you reorder the probes around it is not that expression's number. Run the suspect
# FIRST, in a program of its own, where UNSET is reachable: before 4c1ed8593 SCRIP printed no line at all
# there, because the enclosing write() fails on an unset &errornumber. That is the honest signature of "no
# error was raised", and it is invisible anywhere a previous raise has left a plausible value behind.
# ⭐ ARM 2 IS THE CONTROL THAT MUST NOT MOVE: subscript ASSIGNMENT through a real variable -- declared local,
# global, and IMPLICITLY-declared local alike. Getting the guard wrong breaks exactly these, and they are the
# reason the prior seat stopped at the diagnosis rather than half-landing the cure.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
R="$PWD"
[ -x "$R/scrip" ] || { echo "GATE UNPROVEN(2) [icn_builtin_name_in_lvalue_base_position]: scrip not built -- measured nothing."; exit 2; }
ICONT=/home/resources/icon-master/bin/icont
ICONX=/home/resources/icon-master/bin/iconx
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "GATE UNPROVEN(2): no Arizona oracle at $ICONT / $ICONX -- measured nothing."; exit 2; }
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
cat > "$T/g.icn" <<'ICN'
global G
procedure main();
   local L, c, u;
   L := [1,2,3];
   G := [7,8,9];
   c := 'abc';
   L[1] := 9;
   write("CTL localsub ", L[1]);
   G[2] := 5;
   write("CTL globalsub ", G[2]);
   u := [4,5];
   u[1] := 6;
   write("CTL implicitsub ", u[1]);
   L[1+1] := 42;
   write("CTL exprsub ", L[2]);
   &error := -1;
   pull[c];
   write("SUB n=", &errornumber, " v=", image(&errorvalue));
   &error := -1;
   pull[c] := 1;
   write("SUBASSIGN n=", &errornumber, " v=", image(&errorvalue));
   &error := -1;
   ?pull;
   write("RANDOM n=", &errornumber, " v=", image(&errorvalue));
   &error := -1;
   !pull;
   write("ITERATE n=", &errornumber, " v=", image(&errorvalue));
   &error := -1;
   pull[1:2];
   write("SECTION n=", &errornumber, " v=", image(&errorvalue));
end
ICN
rm -f "$T/oracle" "$T/g.u1" "$T/g.u2"
( cd "$T" && "$ICONT" -s -o oracle g.icn ) > "$T/icont.log" 2>&1
[ -x "$T/oracle" ] || { echo "GATE UNPROVEN(2): icont refused the witness -- measured nothing:"; sed 's/^/    /' "$T/icont.log"; exit 2; }
"$ICONX" "$T/oracle" < /dev/null > "$T/want" 2>&1 || true
grep -q '^SUB n=' "$T/want" || { echo "GATE UNPROVEN(2): the oracle printed no SUB row -- measured nothing:"; sed 's/^/    /' "$T/want"; exit 2; }
timeout -k 5 60 "$R/scrip" "$T/g.icn" < /dev/null > "$T/m3" 2>&1
timeout -k 5 60 "$R/scrip" --compile -o "$T/g.s" "$T/g.icn" < /dev/null > "$T/cc.log" 2>&1
if [ -s "$T/g.s" ]; then
  gcc -m64 -no-pie "$T/g.s" -o "$T/m4bin" -L"$R/out" -lscrip_rt -Wl,-rpath,"$R/out" -lm -lpthread >> "$T/cc.log" 2>&1
fi
[ -x "$T/m4bin" ] || { echo "GATE UNPROVEN(2): mode 4 produced no binary -- measured nothing:"; tail -3 "$T/cc.log" | sed 's/^/    /'; exit 2; }
timeout -k 5 60 "$T/m4bin" < /dev/null > "$T/m4" 2>&1
bad=0
for key in CTL_localsub CTL_globalsub CTL_implicitsub CTL_exprsub SUB SUBASSIGN RANDOM ITERATE SECTION; do
  k=${key/CTL_/CTL }
  w=$(grep -F "$k " "$T/want" | head -1)
  [ -n "$w" ] || { echo "  ⛔ UNPROVEN  $key: the oracle named no such row"; bad=$((bad + 1)); continue; }
  for m in m3 m4; do
    g=$(grep -F "$k " "$T/$m" | head -1)
    if [ "$g" = "$w" ]; then printf '  ✅ %-4s %-14s %s\n' "$m" "$key" "$w"
    else printf '  ⛔ %-4s %-14s want: %s\n              got:  %s\n' "$m" "$key" "$w" "${g:-<absent>}"; bad=$((bad + 1)); fi
  done
done
echo "gate: $bad divergence(s) from the Arizona oracle, over 9 blocking shapes x 2 modes."
[ "$bad" -eq 0 ] || { echo "GATE FAIL [icn_builtin_name_in_lvalue_base_position_carries_its_value]: a bare builtin name in lvalue-base position does not match the oracle."; exit 1; }
echo "GATE PASS [icn_builtin_name_in_lvalue_base_position_carries_its_value]"
exit 0
