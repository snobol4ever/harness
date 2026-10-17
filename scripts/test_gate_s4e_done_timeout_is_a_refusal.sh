#!/usr/bin/env bash
# test_gate_s4e_done_timeout_is_a_refusal.sh -- `s4e_msg.sh done` budgets its DONE-WHEN at 3600s by DEFAULT, and a
# criterion that does not finish inside that budget is a REFUSAL (rc=2, "I could not measure"), never a red criterion
# (rc=1, "I measured and it is not done"). Both outcomes quote the budget they ran under AND the wall-clock they used.
# Row s4e-done-timeout-default-below-make-test-under-fleet-load (hq_B measured 2026-09-03, ceo dispatched rank 0): the
# default was 900s while `make test` measures ~1100s on this box under twelve seats, so every DONE-WHEN containing
# `make test` -- every rung baton, most instrument rows -- died at the default for a reason unrelated to the work AND
# reported it as "NOT DONE ... exited 124", sending the seat off to debug work that was already finished.
# THREE ARMS against a THROWAWAY postoffice under mktemp -- never the live one -- each run against the live
# s4e_msg.sh and against mutated copies with one half of the cure removed (FAIL-ONCE, INSTRUMENT LAWS fifth batch):
#   (A) DEFAULT IS 3600 -- BEHAVIOURALLY, not by grep: with S4E_DONE_TIMEOUT unset, a passing criterion's receipt
#       says `timeout 3600s`. A grep proves the string is in the file; this proves the value reached `timeout`.
#   (B) TIMEOUT IS A REFUSAL: S4E_DONE_TIMEOUT=1 against a sleeping criterion -> rc=2, the word REFUSED, the budget
#       and the elapsed named, NO "NOT DONE" verdict, and the claim NOT closed.
#   (C) A RED CRITERION IS STILL RED: a fast non-zero criterion -> rc=1, "NOT DONE", budget and elapsed named.
# EXIT 0 all three hold on the live script AND each mutant goes red; 1 otherwise; 2 REFUSED (fixture cannot be built).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
ROOT="$(cd "$HERE/../.." && pwd)"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
[ -f "$ROOT/harness/scripts/s4e_msg.sh" ] || { echo "⛔ REFUSED: sibling root not resolvable from $HERE (want $ROOT/SCRIP)"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B
# ⛔ EVERY criterion below names a path or a variable ON PURPOSE: `done`'s vacuity probe SKIPS a criterion containing
# `/` or `$`, and without that the sleeping arm would be caught by the PROBE's own 20s timeout and refuse for the
# wrong reason -- a green gate proving something other than what it says. (A fixture that passes for a reason the
# gate does not name is the same defect class the gate is here to cure.)
DW_FAST='test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"'
DW_HANG='sleep 300 && test -d /etc'
DW_RED='test -f /no-such-file-s4e-done-timeout-gate-fixture'
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf "TRIO\n" > "$PO/MODE"
  { printf '# gate fixture queue\n'; printf '2\tt-fast\tunassigned\tFREE\n'; printf '2\tt-hang\tunassigned\tFREE\n'
    printf '2\tt-red\tunassigned\tFREE\n'; } > "$PO/QUEUE.tsv"
  local t d; for t in t-fast t-hang t-red; do
    case "$t" in t-fast) d="$DW_FAST";; t-hang) d="$DW_HANG";; *) d="$DW_RED";; esac
    printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: %s\nLINKS: none\n## NEXT\n(none)\n## LEDGER\n' "$t" "$d" > "$PO/tasks/$t.task.md"
    S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$ROOT" S4E_NO_BANNER=1 bash "$MSG" claim "$t" >/dev/null 2>&1 || return 2
    [ "$(head -1 "$PO/claims/$t.claim")" = "$ME" ] || return 2
  done
}
# run <script> <topic> [TIMEOUT_VALUE] -> writes $W/out, sets $RC
RC=0
run() { local s="$1" t="$2" to="${3:-}"
  if [ -n "$to" ]; then S4E_DONE_TIMEOUT="$to" S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$ROOT" S4E_NO_BANNER=1 bash "$s" done "$t" >"$W/out" 2>&1
  else                             S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$ROOT" S4E_NO_BANNER=1 bash "$s" done "$t" >"$W/out" 2>&1; fi
  RC=$?; }
say() { sed 's/^/      | /' "$W/out" | grep -m3 -E '⛔|NOT DONE|REFUSED|✅|timeout' || tail -3 "$W/out" | sed 's/^/      | /'; }
arm() {   # arm <label> <script> -> 0 iff all three contracts hold on <script>; 2 iff the fixture broke
  local lbl="$1" s="$2" ok=1
  mk_po || return 2
  # (A) default budget
  run "$s" t-fast
  [ "$RC" = 0 ] || { echo "  [$lbl] (A) passing criterion exited $RC (want 0)"; say; ok=0; }
  grep -q 'timeout 3600s' "$W/out" || { echo "  [$lbl] (A) receipt does not name a 3600s budget -- the DEFAULT did not reach \`timeout\`"; say; ok=0; }
  grep -qE 'exited 0 in [0-9]+s' "$W/out" || { echo "  [$lbl] (A) receipt does not name the elapsed wall-clock"; say; ok=0; }
  # (B) timeout is a refusal, not a red
  run "$s" t-hang 1
  [ "$RC" = 2 ] || { echo "  [$lbl] (B) a criterion that never finished exited $RC (want 2 -- could not measure)"; say; ok=0; }
  grep -q 'REFUSED (rc=2)' "$W/out" || { echo "  [$lbl] (B) output does not REFUSE"; say; ok=0; }
  grep -q 'within 1s' "$W/out" || { echo "  [$lbl] (B) refusal does not name the budget it ran under"; say; ok=0; }
  grep -qE 'elapsed [0-9]+s' "$W/out" || { echo "  [$lbl] (B) refusal does not name the elapsed wall-clock"; say; ok=0; }
  grep -q 'NOT DONE' "$W/out" && { echo "  [$lbl] (B) a timeout was reported as a RED criterion -- the two answers still share one voice"; say; ok=0; }
  grep -q '^DONE$' "$PO/claims/t-hang.claim" && { echo "  [$lbl] (B) ⛔ the row CLOSED on a criterion that never ran"; ok=0; }
  # (C) a red criterion is still red
  run "$s" t-red
  [ "$RC" = 1 ] || { echo "  [$lbl] (C) a failing criterion exited $RC (want 1 -- measured and red)"; say; ok=0; }
  grep -q 'NOT DONE' "$W/out" || { echo "  [$lbl] (C) a red criterion no longer says NOT DONE"; say; ok=0; }
  grep -qE 'after [0-9]+s \(timeout 3600s\)' "$W/out" || { echo "  [$lbl] (C) red verdict does not name elapsed + budget"; say; ok=0; }
  [ "$ok" = 1 ]
}
echo "s4e done: 3600s default, and a timeout REFUSES rather than reds (scratch postoffice under $W)"
if arm PASS "$MSG"; then echo "  [PASS] (A) default 3600s reaches timeout; (B) rc=2 refusal names budget+elapsed and keeps the row open; (C) red stays rc=1"; pass=1
else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
# FAIL-ONCE, one mutant per half of the cure: a gate that cannot go red for EACH defect it names is only claiming to
# cover both. M1 reverts the default to 900 (arm A must red); M2 removes the 124 distinction (arm B must red).
sed 's/S4E_DONE_TIMEOUT:-3600/S4E_DONE_TIMEOUT:-900/' "$MSG" > "$W/m1.sh"
sed 's/"\$rc" -eq 124/"$rc" -eq 90124/g'               "$MSG" > "$W/m2.sh"
grep -q 'S4E_DONE_TIMEOUT:-900' "$W/m1.sh" || { echo "⛔ REFUSED: could not build mutant M1 (the default moved?)"; exit 2; }
grep -q -- '-eq 90124' "$W/m2.sh"          || { echo "⛔ REFUSED: could not build mutant M2 (the 124 branch moved?)"; exit 2; }
red=1
for m in m1 m2; do
  if arm "FAIL-ONCE:$m" "$W/$m.sh" >"$W/fo.$m" 2>&1; then echo "  [FAIL-ONCE:$m] ⛔ STAYED GREEN with that half of the cure removed -- it cannot detect the defect it exists for"; red=0
  else echo "  [FAIL-ONCE:$m] red as required: $(grep -m1 '  \[' "$W/fo.$m" | sed 's/^ *//' | cut -c1-110)"; fi
done
if [ "$pass" = 1 ] && [ "$red" = 1 ]; then echo "✅ GATE OK: done budgets 3600s by default, refuses rc=2 when it cannot measure, still reds rc=1 when it can, and goes red when either half is removed."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass fail-once-red=$red)"; exit 1
