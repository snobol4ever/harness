#!/usr/bin/env bash
# test_monitor_2way_sync_step_all_langs.sh -- THE ONE HARNESS ARM OF THE ONE SYNC-STEP DESIGN (ceo 2026-09-23, CEO-1185; Lon, verbatim:
# "Get IPC sync-step monitor working for all languages, Icon, Prolog, Pascal, and Raku."; MONITOR-BINARY-DESIGN.md § THE PLUG INTERFACE).
# For each language with a plug, one committed witness under ../harness/scripts/monitor/witnesses/ runs through the auto harness with TWO SCRIP
# participants -- mode 3 (--run) against mode 4 (the compiled binary) -- both built with --trace, so every statement, assignment,
# call and return the frontend's plug emits goes to the binary wire through the shared hooks rt_trace_stmt/_value/_call/_return,
# and the controller (monitor_sync_bin.py) steps them in lock-step and reports the first divergence. No oracle bridge is needed,
# which is why this is every language's FIRST arm; a mode-3/mode-4 divergence is MODES-MAY-DIVERGE semantic drift, a row on the rung.
# ⛔ SELF-PIN, NOT AN ORACLE DIFF: it proves the two modes agree event-for-event, never that either is right -- REPORTED, not blocking.
# PASS rc=0 when every language's controller run ends in clean termination with events exchanged; FAIL rc=1 naming the language;
# REFUSE rc=2 when the harness, the controller or the binary cannot run (a participant that never starts is a refusal, never a red).
# ⛔ Each language's line carries the controller's VERDICT counts, and a run whose VERDICT reads UNGRADED above 0 says so by name --
# an untyped value (MWT_UNKNOWN) was never compared, so "event-for-event" is never printed over it (the coo, 2026-09-23, row
# monitor-the-controller-reads-an-untyped-value-as-agree-...); a run with no VERDICT line cannot say what it graded and REFUSES.
# Usage: bash ../harness/scripts/test_monitor_2way_sync_step_all_langs.sh [--lang icon|prolog|pascal|raku|snobol4]   (default: all five)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SD="$S4E/SCRIP"; H="$SD/../harness/scripts/test_monitor_3way_sync_step_auto.sh"; WD="$SD/../harness/scripts/monitor/witnesses"
[ -x "$SD/scrip" ] || { echo "REFUSE(2): no $SD/scrip -- build first"; exit 2; }
[ -f "$H" ] || { echo "REFUSE(2): the auto harness is missing at $H"; exit 2; }
[ -f "$SD/../harness/scripts/monitor/monitor_sync_bin.py" ] || { echo "REFUSE(2): monitor_sync_bin.py missing"; exit 2; }
if [ "$SD/scrip" -ot "$SD/src/runtime/core/core.c" ] || [ "$SD/scrip" -ot "$SD/src/lower/lower_icon.c" ]; then echo "REFUSE(2): ./scrip predates src/ -- run make"; exit 2; fi
want="${2:-}"; [ "${1:-}" = "--lang" ] || want=""
declare -A W=( [icon]=sync_step_icon.icn [prolog]=sync_step_prolog.pl [pascal]=sync_step_pascal.pas [raku]=sync_step_raku.raku [snobol4]=sync_step_snobol4.sno )
pass=0; fail=0; refuse=0; langs=0; ungraded_total=0
for l in icon prolog pascal raku snobol4; do
  [ -n "$want" ] && [ "$want" != "$l" ] && continue
  langs=$((langs+1)); f="$WD/${W[$l]}"; [ -f "$f" ] || { echo "REFUSE(2): witness missing for $l: $f"; refuse=$((refuse+1)); continue; }
  log=$(mktemp); PARTICIPANTS="scr3 scr4" timeout -k 5 240 bash "$H" "$f" > "$log" 2>&1; rc=$?
  steps=$(grep -oE 'all reached END after [0-9]+ steps' "$log" | grep -oE '[0-9]+' | head -1)
  verdict=$(grep -aoE 'VERDICT AGREE=[0-9]+ DIVERGE=[0-9]+ UNGRADED=[0-9]+' "$log" | head -1 | sed 's/^VERDICT //')
  ungr=$(printf '%s' "$verdict" | sed -n 's/.*UNGRADED=\([0-9]*\).*/\1/p')
  if [ "$rc" = 2 ] || [ "$rc" = 124 ]; then echo "  REFUSE $l: harness rc=$rc -- $(grep -E 'REFUS|FAIL' "$log" | head -1 | cut -c1-120)"; refuse=$((refuse+1))
  elif [ "$rc" = 0 ] && [ -n "$steps" ] && [ "$steps" -gt 0 ] && [ -z "$verdict" ]; then echo "  REFUSE $l: the controller printed no VERDICT line -- an agreement whose UNGRADED count is unknown is not a pass"; refuse=$((refuse+1))
  elif [ "$rc" = 0 ] && [ -n "$steps" ] && [ "$steps" -gt 0 ] && [ "$ungr" = 0 ]; then echo "  ok    $l: modes 3 and 4 agree event-for-event, clean termination at step $steps ($verdict)"; pass=$((pass+1))
  elif [ "$rc" = 0 ] && [ -n "$steps" ] && [ "$steps" -gt 0 ]; then echo "  ok    $l: modes 3 and 4 agree on every GRADED event, clean termination at step $steps ($verdict) -- UNGRADED, never a match: $(grep -a '^\[ctrl\] VERDICT' "$log" | head -1 | sed -n 's/.*UNGRADED is never a match: //p' | cut -c1-120)"; pass=$((pass+1)); ungraded_total=$((ungraded_total+ungr))
  elif [ "$rc" = 0 ]; then echo "  REFUSE $l: the controller reported no lock-step termination line (steps unknown) -- an empty agreement is not a pass"; refuse=$((refuse+1))
  else echo "  FAIL  $l: harness rc=$rc -- $(grep -E 'DIVERGE|PARTIAL|PROTOCOL' "$log" | head -1 | cut -c1-140)"; fail=$((fail+1)); fi
  rm -f "$log"
done
echo "SYNC-STEP-ALL-LANGS languages=$langs pass=$pass fail=$fail refused=$refuse ungraded_steps=$ungraded_total participants=scr3,scr4 gate=--trace"
[ "$langs" -gt 0 ] || { echo "REFUSE(2): no language selected"; exit 2; }
[ "$refuse" -eq 0 ] || { echo "REFUSE(2) [monitor_2way_sync_step_all_langs]: $refuse language(s) could not be measured"; exit 2; }
[ "$fail" -eq 0 ] && { echo "GATE PASS(0) [monitor_2way_sync_step_all_langs]: $pass of $langs languages agree between modes under the shared trace hooks"; exit 0; }
echo "GATE FAIL(1) [monitor_2way_sync_step_all_langs]: $fail of $langs languages diverge between modes"; exit 1
