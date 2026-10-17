#!/usr/bin/env bash
# ✅ GREEN, AND WIRED INTO `make test` IN THE SAME COMMIT THAT CURED THE DEFECT (2026-09-16, hq_snobol4).
# A SNOBOL4 REAL LITERAL THAT OVERFLOWS DOUBLE used to hand back the IEEE infinity as an ordinary value:
# X = 1.797693135E+308 printed `inf`, and SNOBOL4 has no infinity. The lexer converted with atof(), which
# reports nothing at all. SPITBOL REJECTS THE PROGRAM AT COMPILE TIME -- ERROR 231 "syntax error: invalid
# numeric item" -- so no code is generated and nothing runs. Row: snobol4-a-real-that-overflows-yields-inf-
# as-a-value-where-spitbol-fails. Cure: src/parsers/snobol4/snobol4.l, one authority, strtod + isfinite.
#
# ⛔ THE ORACLE'S ANSWER IS A COMPILE-TIME REFUSAL, NOT A RUNTIME STATEMENT FAILURE, AND THAT DISTINCTION IS
# THE WHOLE GATE. The row's minted DONE-WHEN expects `lit=failed` -- i.e. the :F() branch taken at run time --
# which the oracle NEVER produces: it never runs the program at all. That .ref was cut from an assumption
# rather than from the oracle. This gate measures what the oracle actually does. See the baton's LEDGER.
#
# ⭐ IT HAS CONTROL ARMS ON PURPOSE, AND THEY ARE THE POINT: the cure must reject ONLY what overflows.
# 1.797693134E+308 is just under DBL_MAX and MUST still compile and print -- an over-eager check that
# rejected the whole large-exponent range would pass a naive "does it refuse?" test while breaking real
# programs. Each arm is compared against the live oracle in this same run, never against a pinned string.
set -eu
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSES rc=2: no built ./scrip -- run make first. A missing binary proves NOTHING about this defect."; exit 2; }
SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || { echo "⛔ REFUSES rc=2: correctness oracle absent at $SBL (absolute path, never command -v)"; exit 2; }
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mk(){ printf '        X = %s\n        OUTPUT = "lit=[" X "]"\nEND\n' "$1" > "$W/r.sno"; }
ours(){ timeout -k 5 8 ./scrip --run "$W/r.sno" </dev/null 2>&1 || true; }
orac(){ timeout -k 5 8 "$SBL" -bf "$W/r.sno" </dev/null 2>&1 || true; }
mk '1.797693135E+308'; og=$(orac)
printf '%s' "$og" | grep -q 'ERROR 231' || { echo "⛔ REFUSES rc=2 (premise gone): the oracle no longer raises ERROR 231 for an overflowing real literal. Re-measure before trusting this gate. Oracle said: $og"; exit 2; }
fail=0; examined=0
arm_reject(){ examined=$((examined+1)); mk "$1"
  o=$(orac); printf '%s' "$o" | grep -q 'ERROR 231' || { echo "  FAIL oracle-premise $1: oracle did not refuse"; fail=$((fail+1)); return; }
  u=$(ours); rc=0; timeout -k 5 8 ./scrip --run "$W/r.sno" </dev/null >/dev/null 2>&1 || rc=$?
  if printf '%s' "$u" | grep -q 'invalid numeric item' && [ "$rc" -ne 0 ] && ! printf '%s' "$u" | grep -q 'lit='; then echo "  ok   reject $1 (compile-time refusal, rc=$rc, nothing printed)"
  else echo "  FAIL reject $1: expected a compile-time refusal naming 'invalid numeric item' with rc!=0 and no lit= line; got rc=$rc and: $u"; fail=$((fail+1)); fi; }
arm_accept(){ examined=$((examined+1)); mk "$1"
  o=$(orac); ov=$(printf '%s' "$o" | grep -oE 'lit=\[[^]]*\]' | head -1)
  [ -n "$ov" ] || { echo "  FAIL oracle-premise $1: oracle printed no lit= line, so this arm cannot be measured against it"; fail=$((fail+1)); return; }
  uv=$(ours | grep -oE 'lit=\[[^]]*\]' | head -1)
  if [ "$uv" = "$ov" ]; then echo "  ok   accept $1 -> $uv (byte-equal to the oracle)"
  else echo "  FAIL accept $1: ours '$uv' vs oracle '$ov'"; fail=$((fail+1)); fi; }
arm_reject '1.797693135E+308'
arm_reject '1.0E+309'
arm_reject '1.0E+400'
arm_accept '1.797693134E+308'
arm_accept '1.5E+10'
arm_accept '3.14159'
arm_accept '0.0'
arm_accept '2.5D+5'
echo "examined=$examined fail=$fail"
[ "$fail" -eq 0 ] || { echo "⛔ RED [sno_real_literal_overflow_is_a_parse_error]: $fail/$examined arm(s) failed"; exit 1; }
echo "✅ GREEN [sno_real_literal_overflow_is_a_parse_error]: $examined/$examined"
