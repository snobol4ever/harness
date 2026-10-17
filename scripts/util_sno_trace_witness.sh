#!/usr/bin/env bash
# util_sno_trace_witness.sh <witness.sno> "<a line the oracle must print>"   |   util_sno_trace_witness.sh <witness.sno> --expect-error NNN
# ceo 2026-09-05 (GOAL-CEO CEO-282, Lon: "Add items to implement all the SNOBOL4 tracing"): grade ONE SNOBOL4 TRACE witness in BOTH
# modes against SPITBOL -bf. Byte-exact (stdout+stderr merged) in the first form; in the second form the oracle and both SCRIP modes
# must each print the SAME ERROR NUMBER (fatal listings carry a pathname and a time, so an error witness is never byte-compared).
# ⛔ THE NUMBER IS MATCHED, NOT THE CASING (cfo 2026-09-13): SPITBOL says "ERROR 199 -- ..." and SCRIP says "error 199: ..." since the
# ONE ERROR VOICE landing (146d027e7, CEO-624), so the original `grep -q "ERROR $errno"` graded EVERY --expect-error arm FAIL on a
# capital letter while both implementations agreed on the number -- measured on trace_bogus_type.sno (199) and trace_undefined_function.sno
# (198), both of which pass under the case-insensitive number match. The arm still refuses rc=2 when the ORACLE does not raise it.
# rc 0 = both modes match · rc 1 = a mode differs or fails to build · rc 2 = could not measure (no witness, no build, oracle silent).
# ORACLE: sbl_correctness_bin first; if it refuses the witness with SPITBOL's ERROR 199 ("trace second argument is not trace type" --
# the fork's trace-dispatch defect, hq_B 2026-09-05, CEO-280/282) the ref is cut from sbl_clean_bin instead and this is PRINTED. The
# fallback is moot since Lon swapped the oracle 2026-09-05T15:34:17Z and it NEVER applies under --expect-error: a witness that asks
# for ERROR 199 makes the fixed oracle print the very string the fallback greps for, so the heuristic cannot tell "the fork refuses
# every type" (the defect) from "this witness asked for a refusal" (the answer) -- it fired on trace_bogus_type.sno AFTER the swap and
# printed a NOTE blaming a defect that was already cured (hq_P 2026-09-05). Trace witnesses never set &CASE, so the stock binary's folding no-op cannot
# reach them. The "must print" argument is the oracle guard: an oracle that prints no trace line refuses rc=2, it never grades.
set -u
here=$(cd "$(dirname "$0")" && pwd); cd "$here/../../SCRIP" || exit 2
. ../harness/scripts/lib_oracle_flags.sh
w="${1:?usage: $0 <witness.sno> \"<line the oracle must print>\" | --expect-error NNN}"; shift
mode=exact; must=""; errno=""
if [ "${1:-}" = "--expect-error" ]; then mode=error; errno="${2:?--expect-error needs a number}"; else must="${1:?a line the oracle must print}"; fi
[ -f "$w" ] || { echo "REFUSED rc=2: no witness $w"; exit 2; }
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "REFUSED rc=2: build first (make) -- no ./scrip or out/libscrip_rt.so"; exit 2; }
O=$(sbl_correctness_bin) || { echo "REFUSED rc=2: no SPITBOL correctness oracle"; exit 2; }
ref=$(timeout -k 5 8s "$O" -bf "$w" </dev/null 2>&1)
if [ "$mode" != error ] && printf '%s\n' "$ref" | grep -q 'ERROR 199 -- trace second argument'; then
  O2=$(sbl_clean_bin) || { echo "REFUSED rc=2: $O refuses TRACE types (ERROR 199) and no stock oracle is present"; exit 2; }
  echo "NOTE: $O still refuses a GOOD TRACE type with ERROR 199 -- it looks like the pre-2026-09-05T15:34Z binary (fixed md5 bc694a0cc699f91d06ff7fde01732000); ref cut from the stock oracle $O2 instead. Re-run once the swapped oracle is in place; the two lineages agreed byte-for-byte on all six exact-mode trace witnesses when hq_P checked at the swap."
  O="$O2"; ref=$(timeout -k 5 8s "$O" -bf "$w" </dev/null 2>&1)
fi
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
m4build() { ./scrip --compile -o "$T/w.s" "$w" </dev/null >/dev/null 2>&1 && as -o "$T/w.o" "$T/w.s" 2>/dev/null && gcc -o "$T/w.bin" "$T/w.o" out/libscrip_rt.so -Wl,-rpath,"$PWD/out" 2>/dev/null; }
rc=0
if [ "$mode" = error ]; then
  printf '%s\n' "$ref" | grep -qiE "error 0*$errno([^0-9]|$)" || { echo "REFUSED rc=2: oracle $O did not print ERROR $errno on $w:"; printf '%s\n' "$ref" | head -8; exit 2; }
  got=$(timeout -k 5 8s ./scrip "$w" </dev/null 2>&1); if printf '%s\n' "$got" | grep -qiE "error 0*$errno([^0-9]|$)"; then echo "PASS m3 (ERROR $errno)"; else echo "FAIL m3: no ERROR $errno; got: $(printf '%s' "$got" | head -3 | tr '\n' '|')"; rc=1; fi
  if m4build; then got=$(timeout -k 5 8s "$T/w.bin" </dev/null 2>&1); if printf '%s\n' "$got" | grep -qiE "error 0*$errno([^0-9]|$)"; then echo "PASS m4 (ERROR $errno)"; else echo "FAIL m4: no ERROR $errno; got: $(printf '%s' "$got" | head -3 | tr '\n' '|')"; rc=1; fi
  else echo "FAIL m4: compile/assemble/link failed"; rc=1; fi
else
  printf '%s\n' "$ref" | grep -qF -- "$must" || { echo "REFUSED rc=2: oracle $O did not print [$must] on $w -- re-measure before trusting this witness:"; printf '%s\n' "$ref" | head -12; exit 2; }
  printf '%s\n' "$ref" > "$T/ref"
  got=$(timeout -k 5 8s ./scrip "$w" </dev/null 2>&1); printf '%s\n' "$got" > "$T/m3"
  if cmp -s "$T/ref" "$T/m3"; then echo "PASS m3"; else echo "FAIL m3 ($w vs $O -bf; < oracle, > scrip):"; diff "$T/ref" "$T/m3" | head -24; rc=1; fi
  if m4build; then got=$(timeout -k 5 8s "$T/w.bin" </dev/null 2>&1); printf '%s\n' "$got" > "$T/m4"
    if cmp -s "$T/ref" "$T/m4"; then echo "PASS m4"; else echo "FAIL m4 ($w vs $O -bf; < oracle, > scrip):"; diff "$T/ref" "$T/m4" | head -24; rc=1; fi
  else echo "FAIL m4: compile/assemble/link failed"; rc=1; fi
fi
echo "oracle=$O tree=$(git rev-parse --short HEAD 2>/dev/null) witness=$w rc=$rc"
exit $rc
