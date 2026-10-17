#!/usr/bin/env bash
# test_gate_monitor_a_long_run_agrees_past_one_hundred_thousand_events.sh -- THE MONITOR CARRIES A LONG RUN, AND A BROKEN WIRE IS
# NEVER A DIVERGENCE (coo 2026-09-25, on hq_snobol4's report: monitor_run.sh --oracle on aisnobol TEST.sno agreed for 99,999 events
# and then read "DIVERGE" with "[ctrl] PROTOCOL ERR step 100000 on scr: insane value_len 525553231").
# THE CAUSE, measured: test_monitor_3way_sync_step_auto.sh launched every SCRIP participant with SCRIP_TRACE defaulting to 99999, the
# participant's event budget, so SCRIP stopped emitting at event 99,999 while the oracle went on. A 60,000-iteration loop broke at
# the same step 100000 (value_len 858993459 = 0x33333333, ASCII "3333": past the budget, core.c comm_var falls through to the TEXT
# mon_send on the binary wire -- a runtime defect routed to its owner, not cured here). And monitor_run.sh printed the controller's
# PROTOCOL ERR as DIVERGE, sending the HQ to bisect its program at a step where the two programs had not disagreed.
# ARMS: (1) --oracle: a SNOBOL4 loop of 40,000 iterations (about 120,000 events) AGREES against the SPITBOL fork past step 100000;
# (2) --modes: the same loop, mode 3 against mode 4, AGREES past step 100000; (3) a PROTOCOL ERR from the harness reads REFUSE(2)
# naming the wire, never DIVERGE -- monitor_run.sh run from a scratch tree whose harness is a stub printing the controller's line.
# ⛔ FAILED ONCE (measured at the landing): with the 99999 default, arm 1 reads "PROTOCOL ERR step 100000"; with the old
# monitor_run.sh, arm 3 reads DIVERGE rc=1.
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED (the binary or an oracle is missing -- nothing measured).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSED(2): cannot load lib_gate.sh"; exit 2; }; GATE_NAME=monitor_a_long_run_agrees_past_one_hundred_thousand_events
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2   # a stale binary is a refusal, never a verdict (test_gate_runners_refuse_on_a_stale_binary.sh census #2)
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
printf '        I = 0\nLOOP    I = I + 1\n        LT(I, 40000)   :S(LOOP)\n        OUTPUT = I\nEND\n' > "$T/longloop.sno"
steps_of() { sed -n 's/.*clean termination at step \([0-9]*\).*/\1/p' "$1" | head -1; }
for m in oracle modes; do
  SCRIP_SNO_STMTKW=1 timeout -k 5 600 bash "$HERE/monitor_run.sh" "$T/longloop.sno" --$m > "$T/$m.out" 2>&1; rc=$?
  n="$(steps_of "$T/$m.out")"
  if [ "$rc" = 2 ] && ! grep -q 'PROTOCOL ERR\|WIRE BROKE' "$T/$m.out"; then echo "⛔ REFUSED(2): monitor_run --$m could not measure the witness: $(grep -m1 REFUSE "$T/$m.out" | cut -c1-200)"; exit 2; fi
  arm=1; [ "$m" = modes ] && arm=2
  [ "$rc" = 0 ] && [ -n "$n" ] && [ "$n" -gt 100000 ] && grep -q 'AGREE:' "$T/$m.out" \
    && ck ok "($arm) --$m: a 40,000-iteration loop agrees event-for-event to step $n, past the old 99,999-event budget" \
    || ck no "($arm) --$m: rc=$rc steps=${n:-none} :: $(grep -m1 -a 'PROTOCOL ERR\|DIVERGE\|REFUSE\|AGREE' "$T/$m.out" | cut -c1-200)"
done
# (3) a scratch S4E_HOME whose harness is a stub printing the controller's PROTOCOL ERR line and exiting 3 (the harness's code for it)
S="$T/home"; . "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$S" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $S"; exit 2; }
printf '#!/usr/bin/env bash\necho "[ctrl] PROTOCOL ERR step 100000 on scr: insane value_len 858993459 (>16777216) -- torn/garbage header"\necho "[ctrl] VERDICT AGREE=99999 DIVERGE=0 UNGRADED=0 of 99999 compared step(s) -- PROTOCOL ERR at step 100000"\nexit 3\n' > "$S/harness/scripts/test_monitor_3way_sync_step_auto.sh"
printf '        OUTPUT = 1\nEND\n' > "$T/one.sno"
# the stub enters through MONITOR_HARNESS: monitor_run.sh runs its own repository's binary and harness since CEO-1496 (the coo 2026-10-04),
# so a scratch S4E_HOME no longer reaches it
MONITOR_HARNESS="$S/harness/scripts/test_monitor_3way_sync_step_auto.sh" SCRIP_SNO_STMTKW=1 timeout -k 5 300 bash "$HERE/monitor_run.sh" "$T/one.sno" --oracle > "$T/stub.out" 2>&1; rc=$?
[ "$rc" = 2 ] && grep -q 'REFUSE(2): THE WIRE BROKE, NOT THE PROGRAM' "$T/stub.out" && grep -q 'AGREE=99999' "$T/stub.out" && ! grep -q 'DIVERGE (rc' "$T/stub.out" \
  && ck ok "(3) a controller PROTOCOL ERR reads REFUSE(2), the wire named and the agreement up to it kept -- never DIVERGE" \
  || ck no "(3) a PROTOCOL ERR read rc=$rc: $(grep -m1 'REFUSE\|DIVERGE' "$T/stub.out" | cut -c1-200)"
echo "population: $checks arm(s) -- one 40,000-iteration SNOBOL4 loop under --oracle and --modes, one stubbed controller protocol error"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [monitor_a_long_run_agrees_past_one_hundred_thousand_events]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL(1) [monitor_a_long_run_agrees_past_one_hundred_thousand_events]: $fails of $checks arms red"; exit 1
