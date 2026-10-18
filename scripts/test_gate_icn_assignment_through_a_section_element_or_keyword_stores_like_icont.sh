#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_assignment_through_a_section_element_or_keyword_stores_like_icont.sh -- cfo 2026-09-11,
# NONET, closing two rank-0 rows ON MEASUREMENT rather than on a cure.
#
# WHAT IT PINS, AND WHY A GATE AND NOT A FLIP. Two rank-0 FREE rows said these shapes were FATAL:
# `icon-assignment-through-a-substring-or-element-variable-lvalue-aborts-the-emitter` (s[i:j] := x, !x := v
# and ?x := v aborted at compile time in emit_drive's IR_ASSIGN guard, killing arizona errors.icn and
# evalx.icn before either printed a line) and `icon-keyword-assignment-beyond-pos-and-random-bombs`
# (bb_keyword_assign implemented only &pos/&random, killing arizona traps.icn at line 2 of 17). BOTH READ
# CURED when measured on 4b1c47897: errors, evalx and traps diff ZERO lines against their .std in BOTH
# modes, in both the arizona and jcon copies, and the shapes below are byte-identical to icont 9.5.25a.
# ⛔ NOTHING IN `make test` HELD THEM. The only thing keeping these two classes honest was three graded
# suite files, which are read at BOARD cadence -- one pass per landing batch, by the one runner -- so a
# regression could ride for a whole batch. A row leaving the queue must not take its pin with it; that is
# the standing lesson row `snobol4-a-cure-proven-on-a-program-that-leaves-the-denominator-owes-a-gate`.
#
# ⭐ WANTS ARE CUT FROM THE ORACLE AT RUN TIME, NEVER TYPED. Typing a want for a cure that already landed
# records what the tree does today, not what Icon does -- it would green on the day it was written by
# construction. icont/iconx 9.5.25a is asked for every byte, and a missing oracle REFUSES (rc=2) rather
# than grading against an empty file.
# ⛔ EVERY WITNESS CARRIES SEMICOLONS: SCRIP's Icon frontend does ZERO newline processing (RULES.md), so a
# witness written the way icont accepts it dies in the parser and the gate would grade a parse error
# against real output. Both arms are written to parse under both engines.
# ⛔ THE ARMS ARE WRITE-SIDE ONLY and that is the point: `test_gate_icn_subscript_index_is_checked...` is
# already wired and pins subscript READS and their error accounts. It never stores through one.
# ⭐ A2 READS EVERY KEYWORD BACK AFTER ASSIGNING IT. Assigning and not reading would pass on a runtime that
# accepted the store and dropped it -- which is exactly what &subject did before CFO-45 (the Icon path
# assigns through rt_keyword_subject_set, NOT the general keyword store). &pos is read after &subject to
# catch the reset-to-1 that a subject store owes.
#
# ⛔ HOW IT WAS PROVEN TO DISCRIMINATE, HONESTLY STATED. The cures predate this HEAD by many commits and
# were NOT reverted to watch the gate go red -- a full revert of two classes across lower/emit was not paid
# for. Instead each arm was mutation-proved: one byte perturbed in each cut want reds that arm in both
# modes (measured, 4 of 4), so no arm is comparing empty to empty or empty to itself. The want-sanity block
# below makes that structural: an arm whose cut want is short or missing its discriminating token REFUSES.
# ⭐ A3 (hq_icon 2026-10-01, the cfo's carried witness): an ASSIGNMENT is a variable, so a section or element of one is
# assignable -- (s := "abcde")[2:5] := "x" is "axe" under iconx. lower_lvalue_var had no assignment case, so the base was
# lowered as a value and the outer store died "error 111: variable expected" in both modes; it now lowers the assignment and
# yields a reference to its variable (through a chain: ((s := "ab") ||:= "cd")[1:3]). A generator on the right-hand side
# backtracks through it. RED on the parent 170172244: a3 died at its first line, error 111, both modes.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"
[ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont oracle at $ICONT -- wants are cut, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/a1.icn" <<'ICN'
procedure main();
   local s, L, T;
   s := "abcdef";
   s[2:4] := "XY";
   write("section-same-length: ", s);
   s := "abcdef";
   s[2:4] := "LONGER";
   write("section-grows: ", s);
   s := "abcdef";
   s[3] := "Z";
   write("element: ", s);
   L := [1,2,3];
   every !L := 9;
   write("every-bang: ", L[1], L[2], L[3]);
   L := [1,2,3];
   ?L := 7;
   write("query-list-sum: ", L[1] + L[2] + L[3]);
   s := "hello";
   ?s := "Q";
   write("query-string-len: ", *s);
   T := table(0);
   T["k"] := 5;
   write("table: ", T["k"]);
end
ICN
cat > "$T/a2.icn" <<'ICN'
procedure main();
   &subject := "hello";
   write("subject: ", &subject, " pos: ", &pos);
   &pos := 3;
   write("pos: ", &pos);
   &random := 42;
   write("random: ", &random);
   &trace := 0;
   write("trace: ", &trace);
   &error := 5;
   write("error: ", &error);
   &subject := "second";
   write("resubject: ", &subject, " pos: ", &pos);
end
ICN
cat > "$T/a3.icn" <<'ICN'
global g
procedure main();
   local s, t, L;
   (s := "abcde")[2:5] := "x"; write("assign-section: ", s);
   (s := "hello")[1] := "J"; write("assign-element: ", s);
   ((s := "ab") ||:= "cd")[1:3] := "Z"; write("augop-chain: ", s);
   (g := "global")[1+:3] := "GLO"; write("global: ", g);
   L := ["one", "two", "three"];
   every (t := !L)[1] := "*" do writes(t, " ");
   write();
   if (s := "ab")[5:6] := "q" then write("bad") else write("out-of-range fails: ", s);
   (s := "xyz")[-1] := "Q"; write("negative: ", s);
end
ICN
for w in a1 a2 a3; do
  ( cd "$T" && "$ICONT" -s -o "$w.icx" "$w.icn" >/dev/null 2>&1 ) || { echo "⛔ REFUSE(2): icont would not translate $w.icn -- cannot cut a want"; exit 2; }
  ( cd "$T" && timeout -k 5 20 "./$w.icx" </dev/null > "$w.want" 2>&1 ) || { echo "⛔ REFUSE(2): the oracle's own run of $w failed -- cannot cut a want"; exit 2; }
done
[ "$(wc -l < "$T/a1.want")" -eq 7 ] || { echo "⛔ REFUSE(2): a1 want is $(wc -l < "$T/a1.want") lines, expected 7"; exit 2; }
[ "$(wc -l < "$T/a2.want")" -eq 6 ] || { echo "⛔ REFUSE(2): a2 want is $(wc -l < "$T/a2.want") lines, expected 6"; exit 2; }
[ "$(wc -l < "$T/a3.want")" -eq 7 ] || { echo "⛔ REFUSE(2): a3 want is $(wc -l < "$T/a3.want") lines, expected 7"; exit 2; }
grep -q 'section-grows: aLONGERdef' "$T/a1.want" || { echo "⛔ REFUSE(2): a1 want lost its discriminating token"; exit 2; }
grep -q 'resubject: second pos: 1' "$T/a2.want" || { echo "⛔ REFUSE(2): a2 want lost its discriminating token"; exit 2; }
grep -q 'augop-chain: Zcd' "$T/a3.want" || { echo "⛔ REFUSE(2): a3 want lost its discriminating token"; exit 2; }
graded=0; fail=0
for w in a1 a2 a3; do
  ( cd "$T" && timeout -k 5 30 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?
  graded=$((graded+1))
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -10; fail=1; fi
  if ( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o "$w.s" "$w.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie "$w.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" >/dev/null 2>&1 ); then
    ( cd "$T" && timeout -k 5 30 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?
    graded=$((graded+1))
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -10; fail=1; fi
  else echo "  FAIL  m4 $w: would not compile or link (this is the emitter abort the row named)"; fail=1; graded=$((graded+1)); fi
done
[ "$graded" -eq 6 ] || { echo "⛔ REFUSE(2): graded $graded arms, expected 6"; exit 2; }
if [ "$fail" = 0 ]; then echo "✅ PASS: 6/6 -- a section, an element and a generated element are lvalues that store, a keyword beyond &pos/&random accepts a value and reads it back, and an assignment is a variable a section or element of which is assignable, byte-exact against icont in BOTH modes"; exit 0; fi
echo "⛔ FAIL: assignment through a section, an element or a keyword no longer stores like icont (see the FAIL rows)"; exit 1
