#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_no_synthetic_main.sh -- SCRIP RUNS WHAT THE ORACLE RUNS, AND SYNTHESIZES NOTHING.
# Row prolog-directive-less-entries-run-main-but-the-oracle-does-not (ceo ruling 2026-09-02 19:55, CEO-152).
#
# THE DEFECT THIS PINS: lower_pl_stage2 carried an `ninit == 0 && main/0 exists -> run main` fallback, so a
# directive-less program that merely DEFINED main/0 was executed by SCRIP while `swipl -q -g halt` consults the
# file and halts, printing nothing. SCRIP agreed with the oracle on rc and disagreed on OUTPUT -- for EVERY
# directive-less program in the corpus, not only the five hq_C measured. A program that wants main says so.
#
# WHAT IT PROVES, in both directions so a silent compiler cannot pass it:
#   (a) DIRECTIVE-LESS defining main/0 -> prints NOTHING, exits 0, in m3 AND m4. This is the cure.
#   (b) WITH `:- initialization(main).` -> still prints and exits 0, in m3 AND m4. Without this arm the gate
#       would go green against a compiler that had simply stopped running anything at all.
#   (c) The oracle itself is asserted, not assumed: swipl prints nothing for (a) and prints for (b). If the
#       oracle ever disagrees, this REFUSES rather than grading SCRIP against a premise that has moved.
# ⛔ Hermetic: programs are written under mktemp, nothing in corpus/ is read or written.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP (a test that cannot measure REFUSES, never skips-as-success)"
SWIPL=/usr/bin/swipl; [ -x "$SWIPL" ] || refuse "no swipl at $SWIPL -- the oracle premise cannot be checked"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_nosynth.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
printf 'main :- write(ran_main), nl.\n'                            > "$W/bare.pl"
printf ':- initialization(main).\nmain :- write(ran_main), nl.\n'  > "$W/decl.pl"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: no synthetic main -- SCRIP runs exactly what swipl -q -g halt runs ==="
echo "--- (c) the ORACLE premise ---"
o="$("$SWIPL" -q -g halt "$W/bare.pl" 2>/dev/null </dev/null)"; [ -z "$o" ] && ck ok "oracle prints nothing for a directive-less main/0" || refuse "oracle premise moved: swipl printed [$o] for a directive-less main/0"
o="$("$SWIPL" -q -g halt "$W/decl.pl" 2>/dev/null </dev/null)"; [ "$o" = "ran_main" ] && ck ok "oracle prints ran_main with the directive" || refuse "oracle premise moved: swipl printed [$o] with the directive"
for m in m3 m4; do
  echo "--- $m ---"
  run(){ if [ "$m" = m3 ]; then timeout -k 5 30 "$SCRIP" "$1" </dev/null 2>/dev/null; else
           s="$W/$(basename "$1" .pl).s"; b="$W/$(basename "$1" .pl).bin"
           timeout -k 5 60 "$SCRIP" --compile --out="$s" "$1" </dev/null >/dev/null 2>&1 || return 97
           timeout -k 5 60 gcc -no-pie -o "$b" "$s" -L"$ROOT/out" -lscrip_rt >/dev/null 2>&1 || return 98
           LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 "$b" </dev/null 2>/dev/null; fi; }
  out="$(run "$W/bare.pl")"; rc=$?
  [ "$rc" -eq 0 ] && ck ok "$m directive-less: rc=0" || ck no "$m directive-less: rc=$rc, expected 0"
  [ -z "$out" ] && ck ok "$m directive-less: prints NOTHING (no synthesized main)" || ck no "$m directive-less printed [$out] -- the ninit==0 fallback is synthesizing a main the oracle never runs"
  out="$(run "$W/decl.pl")"; rc=$?
  [ "$rc" -eq 0 ] && ck ok "$m with directive: rc=0" || ck no "$m with directive: rc=$rc, expected 0"
  [ "$out" = "ran_main" ] && ck ok "$m with directive: prints ran_main" || ck no "$m with directive printed [$out], expected ran_main -- the cure must not silence declared goals"
done
echo "------------------------------------------------------------"
[ "$fails" -ne 0 ] && { echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; }
echo "✅ GATE PASS: $checks/$checks checks"; exit 0
