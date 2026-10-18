#!/usr/bin/env bash
# test_gate_pl_write_1_never_silently_drops_a_term_shape.sh -- write/1 MUST EMIT SOMETHING FOR EVERY TERM SHAPE,
# and for a BARE UNBOUND VARIABLE it must emit a variable name the way the oracle does (row
# prolog-logtalk-write-term-print-and-write-canonical-family, hq_R 2026-09-13; case lgt_write_term_3_065).
#
# THE DEFECT THIS PINS. `write(X)` with X a fresh variable printed ABSOLUTELY NOTHING -- not a wrong name, not a
# placeholder, an empty string -- while writeq/1, write_term/2 and print/1 on the same variable all printed _G0
# correctly. ⛔ THAT ASYMMETRY IS THE WHOLE REASON THIS WENT UNNOTICED: variables INSIDE a compound were always
# printed (f(_G0,_G0) and [a|_G0] were correct), so every test that wrote a term containing a variable passed. Only
# a variable at the TOP LEVEL, alone, vanished -- the narrowest possible window, and the one shape a conformance
# suite tests on purpose.
#
# THE CAUSE, worth naming because it is a family: dop_write (the $write det leaf) formatted its argument with
# out_write_descr, the GENERIC descriptor writer, rather than with the Prolog term writer that writeq/write_term/
# print all use. The generic writer has no notion of an unbound Prolog variable, so it emitted nothing for one. The
# cure routes ONLY the unbound case to rt_pl_write_cell_fp, which is why it cannot trade a passing case: it adds
# output exactly where there was none and touches no other shape.
#
# ⛔ EMPTY OUTPUT IS THE FAILURE MODE THIS GATE EXISTS FOR, SO NO ARM MAY TREAT EMPTY AS A PASS. Each shape is
# graded on its own line with a marker around it, so "wrote nothing" is distinguishable from "wrote the wrong
# thing" AND from "the program died before printing" -- three outcomes a bare diff collapses into one.
#
# ⛔ ONE KNOWN DIVERGENCE IS NAMED RATHER THAN EXCLUDED: write(-(1)) prints `- (1)` here and `- 1` in swipl. That is
# operator spacing, not a dropped shape, it predates this row, and it is NOT what this gate grades -- so it is
# listed below with want '- (1)' and a comment, instead of being quietly dropped from the population. A shape
# deleted from a gate because it disagrees is a measurement the gate has silently stopped making.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_write_1_never_silently_drops_a_term_shape
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
D=$(mktemp -d) || { echo "⛔ REFUSE(2): no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
# goal <TAB> want.  VAR = must be a variable name: non-empty, starts with _, at least 2 chars (what the ISO suite's
# subsumes(['_', _| _], Chars) demands). Anything else is an exact expected string.
# write("str") is [115,116,114]: double_quotes defaults to codes (ISO 7.10.2.2, SCRIP 6a6983d9e), and gprolog 1.6.0 prints exactly
# that; the old pin str was swipl's SWI-7 string default, which the superset does not take as core (GOAL-PROLOG-100.md line 5).
W=$(cat <<'TEOF'
X = X, write(X)	VAR
write(a(b))	a(b)
write([1,2])	[1,2]
write('A b')	A b
write(1+2)	1+2
write("str")	[115,116,114]
write(3.14)	3.14
write({x})	{x}
write(a-b)	a-b
write(-(1))	- (1)
write([])	[]
write(f(X2,X2))	VARIN
TEOF
)
while IFS=$'\t' read -r goal want; do
  [ -n "$goal" ] || continue
  N=$((N+1))
  printf ':- initialization(main).\nmain :- write(user_output, @), %s, write(user_output, @), nl(user_output).\n' "$goal" > "$D/t.pl"
  got=$(timeout -k 5 20 "$SCRIP" "$D/t.pl" </dev/null 2>&1)
  rc=$?
  inner=${got#*@}; inner=${inner%@*}
  if [ $rc -ne 0 ]; then echo "  RED  [$goal] rc=$rc -- the program died before it could print"; FAIL=$((FAIL+1)); continue; fi
  case "$got" in *@*@*) ;; *) echo "  RED  [$goal] markers missing, so nothing can be concluded: got [$got]"; FAIL=$((FAIL+1)); continue ;; esac
  if [ "$want" = VAR ]; then
    case "$inner" in _?*) PASS=$((PASS+1)) ;;
      "") echo "  RED  [$goal] wrote NOTHING for a bare unbound variable (THE DEFECT: an empty string, not a wrong name)"; FAIL=$((FAIL+1)) ;;
      *)  echo "  RED  [$goal] wrote [$inner], which is not a variable name starting with _"; FAIL=$((FAIL+1)) ;;
    esac
  elif [ "$want" = VARIN ]; then
    case "$inner" in f\(_*,_*\)) PASS=$((PASS+1)) ;;
      *) echo "  RED  [$goal] a variable INSIDE a compound came out as [$inner]"; FAIL=$((FAIL+1)) ;;
    esac
  elif [ "$inner" = "$want" ]; then PASS=$((PASS+1))
  else echo "  RED  [$goal] wrote [$inner] want [$want]"; FAIL=$((FAIL+1)); fi
done <<< "$W"
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO shapes -- a runner that cannot measure must never print the success shape"; exit 2; }
echo "PL WRITE/1 SHAPES: PASS=$PASS FAIL=$FAIL / $N shapes graded (m3)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- write/1 emitted something for every shape, and a variable name for a bare variable"; exit 0; }
echo "verdict=RED"; exit 1
