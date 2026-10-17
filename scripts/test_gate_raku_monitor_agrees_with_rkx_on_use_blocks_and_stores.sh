#!/usr/bin/env bash
# test_gate_raku_monitor_agrees_with_rkx_on_use_blocks_and_stores.sh -- the Raku plug of the IPC sync-step monitor fires the
# events the instrumented Rakudo (rkx) fires, on the forms the Roast walk tripped over (hq_raku 2026-09-25, Lon in-chat: "walk
# the roast test suite using IPC sync-step monitor"; ceo CEO-1270). Each rule was MEASURED against rkx one form at a time:
#   use <Module>;            fires a statement event; only a version pragma (use v6, use v6.d) does not
#   { ... } hoisted __blk_N  is a block, not a routine: no CALL, no RETURN; its tail statement keeps its line
#   .= / ++ / -- / (a,b)=    fire no VALUE (rkx instruments assign_op only); = and op= do; internal temps never do
#   a sub's tail expression  keeps its LABEL: the RETURN the parser wraps round it carries the statement's line
#   sub main                 is an ordinary sub (only MAIN is called by Raku); its CALL is named main
# The witness is ../harness/scripts/monitor/witnesses/sync_step_raku_use_blocks_stores.raku. PASS = monitor_run.sh --oracle reads AGREE.
# EXIT 0 agree, 1 diverge, 2 could not measure (no rkx fork built, no scrip, the harness refused).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$HERE/monitor/witnesses/sync_step_raku_use_blocks_stores.raku"
[ -f "$W" ] || { echo "⛔ REFUSED(2): witness missing at $W"; exit 2; }
out=$(bash "$HERE/monitor_run.sh" "$W" --oracle 2>&1); rc=$?
if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q '^\[monitor_run\] AGREE:'; then
    echo "GATE PASS(0) [raku_monitor_agrees_with_rkx]: $(printf '%s\n' "$out" | grep -m1 '^\[monitor_run\] AGREE:' | cut -c1-160)"; exit 0; fi
if [ "$rc" = 1 ]; then
    printf '%s\n' "$out" | grep -E '^\| \*\*>|VERDICT' | head -3
    echo "GATE FAIL(1) [raku_monitor_agrees_with_rkx]: scr and rkx diverge on the witness -- the Raku plug fires an event rkx does not, or misses one"; exit 1; fi
printf '%s\n' "$out" | tail -3
echo "⛔ REFUSED(2) [raku_monitor_agrees_with_rkx]: the monitor could not measure (rc=$rc) -- not a verdict"; exit 2
