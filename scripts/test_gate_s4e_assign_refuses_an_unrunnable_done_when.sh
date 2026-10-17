#!/usr/bin/env bash
# test_gate_s4e_assign_refuses_an_unrunnable_done_when.sh -- A MINT-TIME RED IS rc=1 WITH A LINE BEGINNING RED; rc 126, 127 AND 2 ARE
# REFUSALS, AT ASSIGN, AT THE DISPATCH PROBE AND AT done (ceo CEO-786; hq_prolog's finding relayed by the cto; coo 2026-09-16, row
# instruments-a-mint-time-red-must-be-rc-1-with-a-red-line-an-unrunnable-done-when-exits-127-and-reads-as-red-for-days).
#
# THE DEFECT: 'prove the DONE-WHEN red today' was satisfied equally by an UNRUNNABLE criterion -- hq_prolog's rung-9 row exited 127 in
# zero seconds for eleven days because its DONE-WHEN never cd'd into $S4E_HOME/SCRIP -- so a refusal was read as a red.
#
# ARMS (hermetic scratch postoffice; MODE TRIO; S4E_POST/S4E_SEAT/S4E_HOME):
#   (a) assign of a row whose DONE-WHEN exits 127 is REFUSED rc=2 naming 127, no claim written
#   (b) assign of a row whose DONE-WHEN exits 2 is REFUSED rc=2, no claim written
#   (c) assign of a row whose DONE-WHEN prints 'RED: x' and exits 1 is ASSIGNED (claim written) -- a real red dispatches
#   (d) done on a claimed row whose DONE-WHEN exits 127 REFUSES rc=2 (not red); the claim stays without DONE
#   (e) done on a claimed row whose DONE-WHEN exits 1 is NOT DONE rc=1 (a real red is still red)
# FAIL_ONCE=1 swaps arm (a)'s criterion for a real red so the expected refusal never comes, proving the arm trips.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"; ROOT="$(cd "$HERE/../.." && pwd)"
[ -f "$MSG" ] || { echo "⛔ REFUSED-TO-GRADE: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED-TO-GRADE: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_T; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/ceo/inbox"; : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf 'TRIO\n' > "$PO/MODE"
mk(){ printf '1\t%s\tunassigned\tFREE\n' "$1" >> "$PO/QUEUE.tsv"; printf '# TASK %s\nGOAL: fixture.\nDONE-WHEN: %s\nLINKS: none\n## NEXT\n(none)\n## LEDGER\n' "$1" "$2" > "$PO/tasks/$1.task.md"; }
: > "$PO/QUEUE.tsv"
A127='exit 127'; [ -n "${FAIL_ONCE:-}" ] && A127='echo RED: planted; exit 1'
mk r127 "$A127"; mk r2 'echo REFUSE: fixture; exit 2'; mk rred 'echo RED: fixture; exit 1'; mk d127 'no-such-command-for-the-gate-fixture'; mk dred 'echo RED: fixture; exit 1'
run(){ S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$ROOT" S4E_NO_BANNER=1 S4E_DONE_TIMEOUT=60 bash "$MSG" "$@" 2>&1; }
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: a mint-time red is rc=1 with a RED line; 126/127/2 are refusals (CEO-786) ==="
out="$(run assign "$ME" r127)"; rc=$?
[ "$rc" = 2 ] && [ ! -f "$PO/claims/r127.claim" ] && grep -q 'exited 127' <<<"$out" && ck ok "(a) assign of an exit-127 DONE-WHEN is REFUSED rc=2 naming 127, no claim written" || ck no "(a) rc=$rc claim=$([ -f "$PO/claims/r127.claim" ] && echo written || echo none) -- got: $(grep -E 'REFUSED|assigned' <<<"$out" | head -1 | cut -c1-160)"
out="$(run assign "$ME" r2)"; rc=$?
[ "$rc" = 2 ] && [ ! -f "$PO/claims/r2.claim" ] && ck ok "(b) assign of an exit-2 DONE-WHEN (the criterion refused) is REFUSED rc=2, no claim" || ck no "(b) rc=$rc -- got: $(grep -E 'REFUSED|assigned' <<<"$out" | head -1 | cut -c1-160)"
out="$(run assign "$ME" rred)"; rc=$?
[ -f "$PO/claims/rred.claim" ] && ck ok "(c) a real red (RED: line, exit 1) is ASSIGNED, claim written" || ck no "(c) rc=$rc -- got: $(grep -E 'REFUSED|assigned' <<<"$out" | head -1 | cut -c1-160)"
run claim d127 >/dev/null; out="$(run done d127)"; rc=$?
[ "$rc" = 2 ] && ! grep -q '^DONE$' "$PO/claims/d127.claim" && grep -q 'COULD NOT MEASURE' <<<"$out" && ck ok "(d) done on an exit-127 DONE-WHEN REFUSES rc=2 (could not measure), the claim stays open" || ck no "(d) rc=$rc -- got: $(grep -E 'REFUSED|NOT DONE' <<<"$out" | head -1 | cut -c1-160)"
run claim dred >/dev/null; out="$(run done dred)"; rc=$?
[ "$rc" = 1 ] && grep -q 'NOT DONE' <<<"$out" && ck ok "(e) done on a real red is NOT DONE rc=1 -- a red is still red" || ck no "(e) rc=$rc -- got: $(grep -E 'REFUSED|NOT DONE' <<<"$out" | head -1 | cut -c1-160)"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [s4e_assign_refuses_an_unrunnable_done_when]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [s4e_assign_refuses_an_unrunnable_done_when]: $fails of $checks arms FAIL"; exit 1
