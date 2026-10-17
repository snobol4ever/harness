#!/usr/bin/env bash
# test_gate_sno_eval_of_a_deferred_selection_falls_from_a_failed_first_alternative_through_a_user_call.sh -- EVAL OF A DEFERRED SELECTION WHOSE FIRST
# ALTERNATIVE FAILS INSIDE A BUILTIN PREDICATE OVER A USER-FUNCTION CALL FALLS TO THE NEXT ALTERNATIVE, IN BOTH MODES (the cfo's finding 2026-09-30, row
# spine-eval-of-a-deferred-selection-whose-first-alternative-fails-in-a-builtin-over-a-user-call-jumps-to-pc-1): X = *(GT(NT(), 1), 0) ; OUTPUT = EVAL(X)
# with NT() returning 0 died SIGSEGV at pc 0x1 or nil on e9d9e2b60 plus the base-cell change, where SPITBOL prints 0. Measured 2026-10-11 at SCRIP ea957ffc5: the
# witness prints 0 in both modes; the unevaluated-expression road moved to the star record (spine-bake chunk 2) and the cure came with it. This gate holds the shape.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=sno_eval_of_a_deferred_selection_falls_from_a_failed_first_alternative_through_a_user_call
FIX="$HERE/fixtures/sno_eval_of_a_deferred_selection_whose_first_alternative_fails_through_a_user_call.sno"
[ -f "$FIX" ] || { echo "GATE UNPROVEN(2) [$G]: fixture missing ($FIX)"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/evsel.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
want="${EVSEL_WANT:-0}"; bad=0
got3="$(timeout -k 5 60 "$ROOT/scrip" "$FIX" < /dev/null 2>/dev/null)"; rc3=$?
if [ "$got3" = "$want" ] && [ "$rc3" = 0 ]; then echo "  m3: ok (prints $want)"; else echo "  m3: RED rc=$rc3 printed [$got3] want [$want]"; bad=$((bad+1)); fi
if timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/w.s" "$FIX" < /dev/null > /dev/null 2> "$W/c.err" && gcc "$W/w.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/w" 2> "$W/l.err"; then
  got4="$(timeout -k 5 60 "$W/w" < /dev/null 2>/dev/null)"; rc4=$?
  if [ "$got4" = "$want" ] && [ "$rc4" = 0 ]; then echo "  m4: ok (prints $want)"; else echo "  m4: RED rc=$rc4 printed [$got4] want [$want]"; bad=$((bad+1)); fi
else echo "GATE UNPROVEN(2) [$G]: the fixture did not compile or link in mode 4: $(head -2 "$W/c.err" "$W/l.err" | head -3)"; exit 2; fi
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad mode(s) lost the fall from a failed first alternative of a deferred selection"; exit 1; fi
echo "GATE PASS(0) [$G]: EVAL of a deferred selection whose first alternative fails through a user call prints $want in both modes"
