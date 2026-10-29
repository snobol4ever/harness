#!/usr/bin/env bash
# ✅ GREEN, AND WIRED INTO `make test` (2026-09-05) IN THE SAME COMMIT THAT CURED THE DEFECT.
# An integer-required keyword assigned a STRING holding C-style hex ("0x10") silently stores a WRONG
# NUMBER (16) where SPITBOL raises ERROR 208 -- keyword value assigned is not integer. Regression from
# SCRIP 0fa9c4cb4, which replaced a base-10 strtol() acceptance test in kwb_write_ent() with
# kwb_numeric_text() built on strtod(); strtod accepts the C99 0x/0X form, strtol(s,&end,10) did not.
# Row: snobol4-integer-keyword-accepts-hex-string-oracle-raises-error-208 (hq_P, rank 1).
#
# ⭐ WHY IT WAS HELD OUT UNTIL THE CURE LANDED: a red in the blocking set stops EVERY seat's landing,
# not just the owner's -- measured this same day, when two attributed reds blocked three separate seats'
# DONE-WHENs until an HQ ruled exclusion-by-name. Wired in IN THE COMMIT THAT CURED IT, never before.
#
# ⭐ IT HAS A CONTROL ARM ON PURPOSE: 0fa9c4cb4's INTENT is correct and must survive the cure --
# "3.7" -> 3 is what SPITBOL does. The control arm fails if someone "fixes" this by reverting the
# commit, which would trade a wrong number for a different wrong number.
set -eu
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSES rc=2: no built ./scrip -- run make first. A missing binary proves NOTHING about this defect."; exit 2; }
SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || { echo "⛔ REFUSES rc=2: correctness oracle absent at $SBL"; exit 2; }
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mk(){ printf '\t&ANCHOR = "%s"\n\tOUTPUT = "anchor=" &ANCHOR\nEND\n' "$1" > "$W/k.sno"; }
run3(){ timeout -k 5 8 ./scrip --run "$W/k.sno" </dev/null 2>&1 || true; }
run4(){ ./scrip --compile --out="$W/k.s" "$W/k.sno" </dev/null >/dev/null 2>&1 || { echo COMPILEFAIL; return; }
  as -o "$W/k.o" "$W/k.s" 2>/dev/null && gcc -o "$W/k.bin" "$W/k.o" out/libscrip_rt.so -Wl,-rpath,"$PWD/out" 2>/dev/null || { echo LINKFAIL; return; }
  timeout -k 5 8 "$W/k.bin" </dev/null 2>&1 || true; }
mk '0x10'; og=$("$SBL" -bf "$W/k.sno" </dev/null 2>&1 || true)
printf '%s' "$og" | grep -q 'ERROR 208' || { echo "⛔ REFUSES rc=2 (premise gone): the oracle no longer raises ERROR 208 for &ANCHOR=\"0x10\". Re-measure before trusting this gate. Oracle said: $og"; exit 2; }
fail=0
# ⛔ THE SIGNED AND LEADING-SPACE FORMS ARE HERE BECAUSE hq_C FOUND THEM AFTER THIS GATE'S FIRST CUT:
# a cure aimed only at a bare "0x10" leaves "+0x3" still accepting hex, and this gate would have PASSED it.
# The gate's own denominator was narrower than the defect -- the same shape it exists to catch.
for v in '0x10' '0X1f' '  0x10  ' '+0x3' '+0X2a' ' 0x10'; do
  mk "$v"
  for m in 3 4; do g=$("run$m")
    if printf '%s' "$g" | grep -qE 'anchor=[0-9]'; then echo "FAIL: m$m silently accepts hex [$v] -> $(printf '%s' "$g" | head -1)  (oracle: ERROR 208)"; fail=1; fi
  done
done
# ⛔ REFUSING FOR THE WRONG REASON IS NOT REFUSING. "-0x2" is already rejected today, but with
# ERROR 210 (negative or too large) instead of the oracle's ERROR 208 (not integer) -- strtod parses the
# hex to -2 and a LATER guard catches it. So this form was hiding behind an unrelated check, and a cure
# that reads the current refusal as "already correct" would leave the hex path live underneath it.
# ⛔ THE WRONG-REASON FAMILY IS WIDER THAN THE HEX FORM, MEASURED AT CURE TIME (hq_P): strtod also
# accepts "inf"/"infinity"/"nan"/"nan(chars)" and overflows "1e400" to HUGE_VAL. Every one of them was
# refused with ERROR 210 (negative or too large) where the oracle raises ERROR 208 (not integer) -- the
# value was parsed, then caught by an unrelated range guard, exactly as "-0x2" was. A gate carrying only
# the hex arms would have gone green on the narrow cure and left the rest of the class live underneath.
for v in '-0x2' 'inf' 'INF' 'infinity' 'nan' 'NAN' 'nan(0)' '1e400' '  inf  '; do
  mk "$v"
  og=$("$SBL" -bf "$W/k.sno" </dev/null 2>&1 || true)
  printf '%s' "$og" | grep -q 'ERROR 208' || { echo "⛔ REFUSES rc=2 (premise gone): the oracle no longer raises ERROR 208 for [$v]. Oracle said: $og"; exit 2; }
  for m in 3 4; do g=$("run$m")
    if ! printf '%s' "$g" | grep -qE 'Error 208|ERROR 208|error 208:'; then
      echo "FAIL: m$m refuses [$v] for the WRONG reason -- got $(printf '%s' "$g" | grep -oiE 'error [0-9]+' | head -1), oracle raises ERROR 208 (not integer). The value is being parsed and then caught by the negative/too-large guard."; fail=1; fi
  done
done
# ⭐ SECOND CONTROL ARM: a FINITE number that is merely too large must KEEP raising 210, not 208 --
# over-rejecting into "not integer" would trade one wrong error code for another and still match no oracle.
for v in '1e30' '99999999' '16777217' '-3'; do
  mk "$v"
  for m in 3 4; do g=$("run$m")
    if ! printf '%s' "$g" | grep -qE 'Error 210|ERROR 210|error 210:'; then
      echo "FAIL(control): m$m gives $(printf '%s' "$g" | grep -oiE 'error [0-9]+' | head -1) for [$v], expected Error 210 -- a finite out-of-range number is 'too large', not 'not integer'."; fail=1; fi
  done
done
for pair in '3.7 3' '+3 3' '010 10' '.5 0' '1.5e3 1500' '3. 3' '1e7 10000000'; do set -- $pair; mk "$1"
  for m in 3 4; do g=$("run$m" | head -1)
    if [ "$g" != "anchor=$2" ]; then echo "FAIL(control): m$m gives [$g] for [$1], expected anchor=$2 -- 0fa9c4cb4's real-coercion intent was lost. Cure the hex prefix in kwb_numeric_text; do NOT revert the commit."; fail=1; fi
  done
done
[ "$fail" = 0 ] || { echo "⛔ GATE FAIL: integer-keyword hex acceptance (row snobol4-integer-keyword-accepts-hex-string-oracle-raises-error-208)"; exit 1; }
echo "✅ hex, infinity and NaN keyword assignments all refused with ERROR 208 in BOTH modes; real/decimal coercion and the 210 range guard preserved"
