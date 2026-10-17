#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_bal_is_a_backtracking_generator.sh -- hq_I 2026-09-06.
#
# THE CLASS: icon-bal-generator-yields-one-result-not-a-backtracking-sequence (rank 1, root-caused by
# seat07 from ipl/progs/lisp.icn, whose tokenizer -- bstol/balstr/checkbal -- is built entirely on
# backtracking through bal's successive balance points).
#
# ⛔ IT WAS TWO INDEPENDENT DEFECTS AND EACH HID THE OTHER, which is why this gate grades the whole
# SEQUENCE by value and never merely asks whether a second result exists:
#   1. lower_icon.c admitted `bal` to the generator-builtin test only at nargs==1, so the ZERO-argument
#      form -- how every IPL scanner writes it, `s ? tab(bal())` -- built a plain IR_CALL: one result,
#      no beta port, no resumption at all.
#   2. the box's beta arm re-entered the scan loop PAST the character it had just succeeded on, without
#      running that character through the '('/')' depth accounting, because the success path exits
#      through gamma before reaching the classifier. The opening bracket was never counted, depth stayed
#      0, and every following position looked balanced.
# Fixing 1 alone yields 1,2,3,4 on "(AB) " where iconx yields 1,5 -- WRONG, and it looks like progress.
# ⭐ THE GENERAL FORM: the success arm and the classify arm are two exits from ONE loop iteration, and a
# generator's resume must re-enter the iteration it LEFT, never the next one.
#
# EVERY EXPECTATION HERE IS CUT FROM THE REAL ORACLE AT RUN TIME, not typed: the gate runs icont/iconx on
# the same source and diffs. A hand-typed expectation is a second opinion about Icon, and this class is
# precisely one where a plausible wrong answer (1,2,3,4) reads as correct to anyone not holding iconx.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSES: lib_oracle_flags.sh unloadable" >&2; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSES: no Icon oracle" >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSES: no scrip binary at $SCRIP -- cannot measure" >&2; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/bal_gate.XXXXXX")" || { echo "⛔ GATE REFUSES: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$W"' EXIT
fails=0; graded=0
cat > "$W/bal.icn" <<'ICN'
procedure t(s)
   write("subject=", image(s));
   s ? every write("  bare=", bal());
   s ? every write("  tab =", image(tab(bal())));
   s ? every write("  cset=", bal(&cset));
end
procedure main()
   t("(AB) ");
   t("(a(b)c)d");
   t("abc");
   t("(()) ");
   t(")(");
   t("");
end
ICN
( cd "$W" && "$ICONT" -s bal.icn >/dev/null 2>&1 && ./bal > oracle.out 2>&1 )
[ -s "$W/oracle.out" ] || { echo "⛔ GATE REFUSES: the oracle produced no output for the witness -- nothing to grade against" >&2; exit 2; }
lines=$(grep -c . "$W/oracle.out")
[ "$lines" -ge 20 ] || { echo "⛔ GATE REFUSES: the oracle produced only $lines line(s); this witness must exercise every subject, so a short answer means the harness, not the compiler, is what changed" >&2; exit 2; }
( cd "$W" && "$SCRIP" --run bal.icn </dev/null > m3.out 2>&1 )
graded=$((graded+1))
if cmp -s "$W/oracle.out" "$W/m3.out"; then echo "✅ PASS  m3: bal generates the same sequence as iconx over all 6 subjects ($lines lines)"
else echo "⛔ FAIL  m3: bal's sequence differs from iconx"; diff "$W/oracle.out" "$W/m3.out" | head -12; fails=$((fails+1)); fi
if ( cd "$W" && "$SCRIP" --compile bal.icn > bal.s 2>/dev/null </dev/null ) && [ -s "$W/bal.s" ] \
   && gcc -no-pie "$W/bal.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$W/bal.bin" 2>/dev/null; then
  ( cd "$W" && ./bal.bin > m4.out 2>&1 )
  graded=$((graded+1))
  if cmp -s "$W/oracle.out" "$W/m4.out"; then echo "✅ PASS  m4: bal generates the same sequence as iconx over all 6 subjects"
  else echo "⛔ FAIL  m4: bal's sequence differs from iconx"; diff "$W/oracle.out" "$W/m4.out" | head -12; fails=$((fails+1)); fi
else
  echo "⛔ FAIL  m4: could not compile or link the witness"; fails=$((fails+1))
fi
# ⭐ THE STRUCTURAL ARM, and it is the one that catches a HALF cure. Defect 1 is invisible to the value
# arms once defect 2 is fixed only if you never write the zero-argument form -- so this asks the compiler
# directly whether `bal()` reaches the scan box at all, rather than inferring it from an output that a
# one-argument spelling could have produced.
printf 'procedure main()\n   local s;\n   s := "(AB) ";\n   s ? every write(bal());\nend\n' > "$W/zero.icn"
ir="$("$SCRIP" --dump-ir "$W/zero.icn" </dev/null 2>&1)"
graded=$((graded+1))
if printf '%s' "$ir" | grep -q 'SCAN_BAL'; then echo "✅ PASS  the zero-argument form lowers to SCAN_BAL, not to a plain by-name call"
else echo "⛔ FAIL  bal() with no arguments does not reach the scan box -- it lowers to a plain call, which has no beta port and can only ever yield one result"; fails=$((fails+1)); fi
[ "$graded" -gt 0 ] || { echo "⛔ GATE REFUSES: graded zero witnesses" >&2; exit 2; }
if [ "$fails" -ne 0 ]; then echo "⛔ GATE RED: $fails of $graded arms failed"; exit 1; fi
echo "✅ GATE GREEN: $graded arms, every expectation cut from the live oracle"; exit 0
