#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_raising_directive_does_not_abort_the_load.sh -- A DIRECTIVE THAT RAISES MUST NOT KILL THE LOAD.
# Row prolog-swi-tests-114-to-100-percent-both-modes-by-class (hq_C 2026-09-06);
# FINDING-2026-09-06-hq_C-a-directive-that-raises-aborts-the-whole-prolog-load-because-ignore-contains-failure-not-exceptions.
#
# THE DEFECT THIS PINS: lower_pl_stage2 wrapped every non-declarative directive in ignore(...), concatenated the
# wrapped directives AND every initialization/1 goal into ONE conjunctive root graph, and registered it as "main".
# ignore/1 contains FAILURE, not EXCEPTIONS -- so a directive that THREW escaped the whole conjunction to the root
# omega port (rt_pl_root_omega), which reports the ball and calls exit(0). Every later directive and every
# initialization goal was skipped, and the process exited SUCCESSFULLY with empty output. That is what made 2 of the
# 9 graded swi_tests files read as "the compiler emits nothing at all" -- rc=0, 0 bytes, no cause visible anywhere.
# THE CURE: ignore(catch(D, E, format(user_error, 'Warning: directive raised: ~q~n', [E]))) -- containment extended
# from failure to exceptions, which is SWI's own load behaviour, with the diagnostic KEPT rather than swallowed.
#
# WHAT IT PROVES, in four directions so a silent compiler cannot pass it:
#   (a) THE CURE: a raising directive is contained -- the later directive and initialization/1 still run, both modes.
#   (b) CONTROL, AND THE ONE THAT MATTERS MOST: the diagnostic is still PRINTED and still NAMES THE CULPRIT.
#       Without this arm the cheapest passing "cure" is catch(D,_,true) -- which trades a loud death for a SILENT
#       skip, i.e. the same class of defect facing the other way. Arm (a) alone cannot tell those two apart.
#   (c) CONTROL: a directive that merely FAILS is still contained, as ignore/1 always did -- the cure must not be a
#       regression of the behaviour it extends.
#   (d) CONTROL: containment is scoped to DIRECTIVES. An exception raised by the initialization GOAL itself must
#       still reach the reporter, or "contain everything everywhere" would pass and hide real program errors.
#   (e) The oracle is ASSERTED, never assumed: swipl is run on every arm and the gate REFUSES if its answer moved.
# ⛔ Hermetic: every program is written under mktemp; nothing in corpus/ is read or written.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP (a test that cannot measure REFUSES, never skips-as-success)"
SWIPL=/usr/bin/swipl; [ -x "$SWIPL" ] || refuse "no swipl at $SWIPL -- the oracle premise cannot be checked"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no $ROOT/out/libscrip_rt.so -- the m4 arm cannot link"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_pldir.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
printf 'a :- write(before), nl.\n:- no_such_directive(x).\nb :- write(after), nl.\n:- initialization(main).\nmain :- a, b.\n' > "$W/raise.pl"
printf 'a :- write(before), nl.\n:- fail.\nb :- write(after), nl.\n:- initialization(main).\nmain :- a, b.\n'                 > "$W/failing.pl"
printf ':- initialization(main).\nmain :- no_such_goal_at_all(z).\n'                                                          > "$W/initraise.pl"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
oracle(){ timeout -k 5 30 "$SWIPL" -q -g true -t halt "$1" </dev/null 2>/dev/null; }
echo "=== gate: a prolog directive that RAISES must not abort the load ==="
echo "--- (e) the ORACLE premise, asserted before anything is graded ---"
exp_raise="$(oracle "$W/raise.pl")"; exp_fail="$(oracle "$W/failing.pl")"
[ "$exp_raise" = "$(printf 'before\nafter')" ] && ck ok "oracle: raising directive -> load continues, main runs (before,after)" \
  || refuse "ORACLE PREMISE MOVED: swipl on a raising directive printed [$exp_raise], not before/after -- re-derive rather than grade"
[ "$exp_fail" = "$(printf 'before\nafter')" ] && ck ok "oracle: failing directive -> load continues, main runs (before,after)" \
  || refuse "ORACLE PREMISE MOVED: swipl on a failing directive printed [$exp_fail] -- re-derive rather than grade"
for m in m3 m4; do
  echo "--- $m ---"
  run(){ if [ "$m" = m3 ]; then timeout -k 5 60 "$SCRIP" "$1" </dev/null 2>"$W/err.txt"; else
           s="$W/out.s"; b="$W/out.bin"; rm -f "$s" "$b"
           timeout -k 5 90 "$SCRIP" --compile -o "$s" "$1" </dev/null >/dev/null 2>&1 || return 97
           timeout -k 5 90 gcc -no-pie -o "$b" "$s" -L"$ROOT/out" -lscrip_rt -lm >/dev/null 2>&1 || return 98
           LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 60 "$b" </dev/null 2>"$W/err.txt"; fi; }
  out="$(run "$W/raise.pl")"; rc=$?
  [ "$rc" -eq 0 ] && ck ok "$m (a) raising directive: rc=0" || ck no "$m (a) raising directive: rc=$rc, expected 0"
  [ "$out" = "$exp_raise" ] && ck ok "$m (a) load continued: printed [$out] == oracle" \
    || ck no "$m (a) printed [$out], oracle says [$exp_raise] -- a skipped initialization goal is a SILENT wrong answer (rc stays 0)"
  if grep -q 'no_such_directive' "$W/err.txt"; then ck ok "$m (b) the diagnostic survives and NAMES the culprit"
  else ck no "$m (b) stderr does not name no_such_directive -- containment that SWALLOWS the cause is the same defect facing the other way"; fi
  out="$(run "$W/failing.pl")"; rc=$?
  [ "$out" = "$exp_fail" ] && [ "$rc" -eq 0 ] && ck ok "$m (c) a merely FAILING directive is still contained" \
    || ck no "$m (c) failing directive printed [$out] rc=$rc, oracle says [$exp_fail] rc=0 -- the cure regressed what ignore/1 already did"
  out="$(run "$W/initraise.pl")"; rc=$?
  if grep -q 'no_such_goal_at_all' "$W/err.txt"; then ck ok "$m (d) an exception from the initialization GOAL still reaches the reporter"
  else ck no "$m (d) initialization goal's own exception was swallowed -- containment must be scoped to DIRECTIVES, not blanket"; fi
done
echo "------------------------------------------------------------"
if [ "$fails" -eq 0 ]; then echo "✅ GATE GREEN: a raising directive is contained, named, and does not abort the load (examined $checks checks)"; exit 0; fi
echo "⛔ GATE FAIL: $fails of $checks checks red"
echo "   CURE: lower_pl_stage2 must wrap each directive as ignore(catch(D, E, format(user_error, 'Warning: directive raised: ~q~n', [E])))"
exit 1
