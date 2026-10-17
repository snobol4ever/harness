#!/usr/bin/env bash
# test_gate_gc_callback_wraps_are_counted_live.sh -- THE CALLBACK WRAPS ARE COUNTED BY REACH, NOT BY SPELLING (row
# gc-the-forty-nine-callback-wrap-sites-carry-rt-gc-callback-and-the-count-is-live-not-static, the cfo, 2026-09-28; ceo CEO-1040:
# util_gc_acceptance.py's static wrap count cannot tell "every site wrapped" from "no site ever run", the defect retracted at CEO-1041).
#
# THE INSTRUMENT is ../harness/scripts/util_gc_callback_reach.py: it runs programs under gdb with a silent breakpoint on rt_gc_cb_close and
# reads the file and line every RT_GC_CALLBACK close passes, so a site is REACHED only when a real callback through it returned --
# no runtime change, no getenv on the callback path, no new static.  This gate proves the instrument can see and cannot be fooled;
# the full census over the collector witnesses is the row's DONE-WHEN, not an arm here (it runs every witness under gdb).
#
# ARMS: (1) THE INSTRUMENT SEES: over hb_wsb_rk_iter_map.raku and hb_wsb_rk_iter_grep.raku the reader exits 0 with close events,
# reaches the array-call wrap in rt_call_arr_bl (named by FUNCTION, never by line), and reads UNLISTED 0 -- every event on a line
# the static list holds; (2) THE BLINDFOLD IS REFUSED: over a program that NEVER RUNS (a SNOBOL4 source that fails to parse, so zero
# closes by construction) the reader exits 2 with ZERO close events -- never "0 reached".  Measured while cutting this arm: a
# one-line SNOBOL4, Icon, Pascal or Raku program is NOT callback-free -- each closes 2 to 5 wraps at start-up through rt_call_arr_bl
# and rt_call_arr_bl_s (a one-line Prolog program closes none) -- so "a program with no callback" is not a safe fixture; (3) FAIL-ONCE: CB_REACH_PLANT_NO_PENDING=1 drops `set breakpoint pending on`, the breakpoint on a
# symbol of the not-yet-loaded runtime library then never exists, and arm (1)'s own population must REFUSE rc 2 -- the defect
# this reader had in its first cut, caught by its own refusal.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
command -v gdb >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: gdb is not installed"; exit 2; }
R="$ROOT/../harness/scripts/util_gc_callback_reach.py"; W="$ROOT/../harness/scripts/gc_witnesses"
for w in hb_wsb_rk_iter_map.raku hb_wsb_rk_iter_grep.raku; do [ -s "$W/$w" ] || { echo "⛔ GATE REFUSE(2) [$G]: witness $w missing"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
python3 "$R" "$W/hb_wsb_rk_iter_map.raku" "$W/hb_wsb_rk_iter_grep.raku" > "$T/a1.txt" 2>&1; r1=$?
ev=$(sed -n 's/.*program(s) run, [0-9]* reached a callback, [0-9]* timed out, \([0-9]*\) close event.*/\1/p' "$T/a1.txt")
if [ $r1 -eq 0 ] && [ "${ev:-0}" -gt 0 ] && grep -qE '^  REACHED .* rt_call_arr_bl ' "$T/a1.txt" && grep -q 'UNLISTED 0$' "$T/a1.txt"; then echo "  arm 1 PASS: the reader sees $ev close event(s), reaches the rt_call_arr_bl wrap, and every event is on a listed line -- $(grep '^CB-REACH REACHED' "$T/a1.txt")"
else echo "  arm 1 FAIL: rc=$r1 events=${ev:-none}"; sed 's/^/     /' "$T/a1.txt" | grep -vE 'UNREACHED' | head -6; RC=1; fi
printf '        OUTPUT = (\nEND\n' > "$T/neverruns.sno"
python3 "$R" "$T/neverruns.sno" > "$T/a2.txt" 2>&1; r2=$?
if [ $r2 -eq 2 ] && grep -q 'ZERO close events' "$T/a2.txt"; then echo "  arm 2 PASS: a program that never runs is REFUSED rc 2 with zero close events -- never read as 0 reached"
else echo "  arm 2 FAIL: rc=$r2 -- the reader did not refuse a population it saw nothing over"; head -3 "$T/a2.txt" | sed 's/^/     /'; RC=1; fi
CB_REACH_PLANT_NO_PENDING=1 python3 "$R" "$W/hb_wsb_rk_iter_map.raku" "$W/hb_wsb_rk_iter_grep.raku" > "$T/a3.txt" 2>&1; r3=$?
if [ $r3 -eq 2 ] && grep -q 'ZERO close events' "$T/a3.txt"; then echo "  arm 3 PASS: planted, with no pending breakpoint the same population REFUSES rc 2 -- arm 1's events exist only because the breakpoint does"
else echo "  arm 3 FAIL: rc=$r3 -- the plant did not blind the reader, so arm 1 does not prove the breakpoint fired"; RC=1; fi
echo "population: 3 arm(s) graded"
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE FAIL [$G]"
exit $RC
