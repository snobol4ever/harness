#!/usr/bin/env bash
# test_gate_bus_probe_kills_its_whole_tree_and_holds_no_identity.sh -- THE BUS PROBES LEAVE NO ORPHAN AND FREEZE NO IDENTITY (the coo 2026-11-01, R-2107 as
# amended, ARCH-SHARED-DEVELOPMENT 12 item 7; Lon: "how do all the orphans get created? fix that."). At 14:2x three assign probes timed out: GNU timeout
# signals only its own process group, the runner's own inner `timeout -k 10 1500` was a second group, so three XSB smoke trees ran on reparented to the
# user manager for 25 minutes and pinned the coo's scope at its memory.high; and the assigns held the coo identity for their whole probe run, so every
# coo send was refused. Hermetic, ~15 s, a throwaway postoffice (S4E_POST) and root: ARM 1 a DONE-WHEN that starts a nested `timeout` child leaves NO
# survivor after the assign's probe budget (2 s) fires; ARM 2 a coo-side send made WHILE an assign probes (a 4 s DONE-WHEN) is delivered; ARM 3 the
# assign still writes ASSIGNED:<seat> after its probes; ARM 4 the budget is reported. rc 0 every arm; rc 1 an arm red; rc 2 cannot measure.
set -u
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="${S4E_GATE_MSG:-$H/s4e_msg.sh}"; G=bus_probe_kills_its_whole_tree_and_holds_no_identity
[ -r "$MSG" ] || { echo "⛔ GATE REFUSE(2) [$G]: $MSG missing"; exit 2; }
command -v setsid >/dev/null && command -v pkill >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: setsid or pkill missing"; exit 2; }
T=$(mktemp -d) || { echo "⛔ GATE REFUSE(2) [$G]: no scratch"; exit 2; }
M=$(( $$ % 90000 + 10007 ))
reap() { local p; for p in $(ps -eo pid=,args= | awk -v m="sleep 6[01]0[.]$M" '$0 ~ m && !/awk/ {print $1}'); do kill -KILL "$p" 2>/dev/null; done; }
trap 'reap; rm -rf "$T"' EXIT
mkdir -p "$T/root/harness/scripts" "$T/po"/{claims,tasks,seatAA/inbox,hq_C/inbox}
printf '%s\n' '#!/bin/sh' 'echo HANDOFF COMPLETE' 'exit 0' > "$T/root/harness/scripts/handoff_status.sh"; chmod +x "$T/root/harness/scripts/handoff_status.sh"
printf '5\trow-orphan\tb\tFREE\n5\trow-slow\tb\tFREE\n' > "$T/po/QUEUE.tsv"
printf 'DONE-WHEN: timeout -k 1 600 sleep 600.%s >/dev/null 2>&1 & sleep 600.%s; exit 1\n' "$M" "$M" > "$T/po/tasks/row-orphan.task.md"
printf 'DONE-WHEN: sleep 4; exit 1\n' > "$T/po/tasks/row-slow.task.md"
run() { local seat="$1"; shift; S4E_POST="$T/po" S4E_HOME="$T/root" S4E_SEAT="$seat" S4E_NO_BANNER=1 bash "$MSG" "$@" 2>&1; }
fail=0; n=0
ok() { n=$((n + 1)); echo "  ok   ARM $n: $1"; }
no() { n=$((n + 1)); echo "  RED  ARM $n: $1 -- $2"; fail=1; }
out="$(S4E_DISPATCH_PROBE_TIMEOUT=2 timeout 60 bash -c 'S4E_POST="$1" S4E_HOME="$2" S4E_SEAT=hq_C S4E_NO_BANNER=1 bash "$3" assign seatAA row-orphan 2>&1' - "$T/po" "$T/root" "$MSG")"; arc=$?
sleep 2
left=$(ps -eo args= | grep -c "[s]leep 600.$M")
[ "$arc" != 124 ] && [ "$left" = 0 ] && ok "a probe whose DONE-WHEN starts a nested timeout child leaves no survivor after its 2 s budget" || no "a probe's budget kills its whole tree" "assign rc $arc, $left 'sleep 600.$M' process(es) survived the probe (orphaned to the user manager)"
reap
case "$out" in *"did not finish within 2s"*) ok "the probe budget is reported, not ignored";; *) no "the probe budget is reported" "no 'did not finish within 2s' line: $(printf '%s' "$out" | grep -m1 -i -E 'probe|budget' | cut -c1-120)";; esac
( S4E_DISPATCH_PROBE_TIMEOUT=20 S4E_POST="$T/po" S4E_HOME="$T/root" S4E_SEAT=hq_C S4E_NO_BANNER=1 timeout 60 bash "$MSG" assign seatAA row-slow > "$T/assign2.out" 2>&1 ) & ap=$!
sleep 1.5
sout="$(printf 'probe-window telegram %s\n' "$M" | run hq_C send seatAA probe-window-$M --stdin)"; src=$?
wait "$ap"
if [ "$src" = 0 ] && ls "$T/po/seatAA/inbox" 2>/dev/null | grep -q "probe-window-$M"; then ok "a send by the assigning identity WHILE its assign probes is delivered (the probes hold no identity)"
else no "a send during an assign's probe is delivered" "send rc $src: $(printf '%s' "$sout" | grep -m1 -E 'REFUSED|⛔' | cut -c1-120)"; fi
awk -F'\t' '$2=="row-slow" {print $4}' "$T/po/QUEUE.tsv" | grep -qx 'ASSIGNED:seatAA' && ok "the assign still writes ASSIGNED:seatAA after its probes (the identity taken again for the write)" || no "the assign writes the row after its probes" "QUEUE reads $(awk -F'\t' '$2=="row-slow" {print $4}' "$T/po/QUEUE.tsv"): $(tail -2 "$T/assign2.out" | tr '\n' ' ' | cut -c1-140)"
[ "$n" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: no arm ran"; exit 2; }
echo "BUS_PROBE_BOARD arms=$n red=$fail (harness $(git -C "$H/.." rev-parse --short HEAD 2>/dev/null || echo ?))"
if [ "$fail" = 0 ]; then echo "GATE PASS(0) [$G]: $n arms -- a probe's budget kills its whole tree, the budget is reported, the probes hold no identity, and the assign still writes the row"; exit 0; fi
echo "GATE FAIL(1) [$G]: see the RED arms"; exit 1
