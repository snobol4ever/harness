#!/usr/bin/env bash
# s4e_probe_flock_lock.sh -- fleet-queue step 19's probe (the cio, 2026-11-05), run as: bash harness/scripts/s4e_msg.sh whoami --probe-lock
# THE BUS LOCK IS FLOCK, HELD FOR A WRITE ONLY, NEVER ACROSS A DONE-WHEN RUN. On a scratch postoffice under the caller's identity, a top-level
# done closes a plant row whose DONE-WHEN sleeps S4E_PROBE_CRIT_S seconds (default 10). The done runs with S4E_LOCK_TRACE set, so the holder
# appends its own take and release instants, and on each take the kernel's FLOCK entry on the identity file (kernel_flock=1). The probe
# grades those receipts, not a sample: a hold of a few milliseconds is invisible to any sampler. A send from the same identity is issued while
# the criterion runs and must be delivered; the send's own brief write is another pid and is not the done's hold.
# Phases are timed from the moment the done prints "verifying DONE-WHEN" (first seen by polling): gap is the first 0.5 s after it (the verb's
# release), probe is from 0.5 s to crit-0.5 s, post is the rest (the retake and the write). It prints one line:
#   LOCK by=flock held_for=write probe_held=<n> pre_held=<n> post_held=<n> gap_held=<n> takes=<n> criterion_s=<s> mid_run_send=<delivered|refused> done_rc=<rc> closed=yes
# by=flock when every take was a kernel FLOCK entry of the done; by=none when the done took no lock; by=unverified when a take was not one.
# held_for=write when the done held it before the criterion or after it. probe_held counts the done's holds that overlap the criterion's
# middle; the probe passes at 0. rc 0 when the probe measured, 2 when it could not (no seat, no /proc/locks, the done never reached its
# criterion or never closed the row).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ME="${S4E_SEAT:-}"
crit="${S4E_PROBE_CRIT_S:-10}"
refuse() { echo "REFUSE(2) [whoami --probe-lock]: $*"; exit 2; }
[ -n "$ME" ] || refuse "S4E_SEAT unset -- run it as: bash harness/scripts/s4e_msg.sh whoami --probe-lock"  # one-disk: not a path
case "$crit" in ''|*[!0-9]*) refuse "S4E_PROBE_CRIT_S takes whole seconds" ;; esac
[ "$crit" -ge 2 ] || refuse "S4E_PROBE_CRIT_S must be at least 2 s, so the probe window is not empty"
[ -r /proc/locks ] || refuse "/proc/locks is unreadable, so the kernel lock table cannot be measured"
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/flock_lock_probe.XXXXXX")" || refuse "mktemp failed"
bg=""
cleanup() { [ -n "$bg" ] && kill "$bg" 2>/dev/null; wait 2>/dev/null; rm -rf "$w"; }
trap cleanup EXIT
t="flock-lock-probe-$$"; now="$(date -u +%FT%TZ)"; trace="$w/lock.trace"
mkdir -p "$w/claims" "$w/tasks" "$w/$ME/inbox" "$w/probe_peer/inbox"
printf '# plant queue (fleet-queue step 19, the cio 2026-11-05)\n2\t%s\t%s\tASSIGNED:%s\n' "$t" "$ME" "$ME" > "$w/QUEUE.tsv"
printf '# TASK %s\nGOAL: plant\nDONE-WHEN: sleep %s && test -f "${S4E_HARNESS:-/home/harness}/scripts/s4e_msg.sh"\nLINKS: minted via mint by %s, %s\n## NEXT\n## QA\n## LEDGER\n' \
    "$t" "$crit" "$ME" "$now" > "$w/tasks/$t.task.md"
printf '%s\nASSIGNED-BY plant %s\nRUNNING\n' "$ME" "$now" > "$w/claims/$t.claim"
# The done runs as its own process: env execs bash, so $! is the verb's pid, the pid the kernel names as the holder in /proc/locks.
env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 S4E_LOCK_TRACE="$trace" \
    bash "$HERE/s4e_msg.sh" done "$t" > "$w/done.out" 2>&1 < /dev/null &
vpid=$!; bg="$vpid"
first=""; sent=""; n=0
while kill -0 "$vpid" 2>/dev/null; do
    if [ -z "$first" ] && grep -q '^verifying DONE-WHEN' "$w/done.out" 2>/dev/null; then first="$(date +%s%N)"; fi
    if [ -z "$sent" ] && [ -n "$first" ] && [ $(( $(date +%s%N) - first )) -ge 1000000000 ]; then
        printf 'the step 19 probe: a send while the criterion runs\n' | env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 \
            bash "$HERE/s4e_msg.sh" send probe_peer flock-lock-probe --stdin > "$w/send.out" 2>&1
        [ -n "$(ls "$w/probe_peer/inbox")" ] && sent=delivered || sent=refused
    fi
    n=$((n+1)); [ "$n" -gt $(( (crit + 600) * 10 )) ] && refuse "the done ran past $((crit + 600)) s"
    sleep 0.05
done
wait "$vpid" 2>/dev/null; rc=$?
bg=""
[ -n "$first" ] && [ -n "$sent" ] || { sed 's/^/  | /' "$w/done.out" | tail -15; refuse "the done never reached its criterion (rc ${rc:-?})"; }
# QUEUE.tsv is a VIEW since fleet-queue step 12 (84d8951): it is rebuilt from the batons and drops a closed row, so the closure is read from
# what done writes: the claim's DONE line.
grep -q '^DONE$' "$w/claims/$t.claim" \
    || { sed 's/^/  | /' "$w/done.out" | tail -15; refuse "the done did not close the plant row (rc ${rc:-?})"; }
c="$(sed -n 's/.*DONE-WHEN exited 0 in \([0-9]*\)s.*/\1/p' "$w/done.out" | head -1)"
[ -f "$trace" ] || : > "$trace"
lo=$(( first + 500000000 )); hi=$(( first + crit * 1000000000 - 500000000 ))
cnt="$(awk -v v="$vpid" -v f="$first" -v lo="$lo" -v hi="$hi" '
    $3 == v && $2 == "take" { op = $1; takes++; if ($4 != "kernel_flock=1") badk++; next }
    $3 == v && $2 == "release" && op != "" {
        s = op; e = $1; op = ""
        if (s < hi && e > lo) probe++
        else if (e <= lo) { if (e <= f) pre++; else gap++ }
        else post++
    }
    END { printf "%d %d %d %d %d %d", takes+0, badk+0, pre+0, gap+0, probe+0, post+0 }' "$trace")"
set -- $cnt; takes=$1; badk=$2; pre_h=$3; gap_h=$4; probe_h=$5; post_h=$6
by=none; [ "$takes" -gt 0 ] && by=flock; [ "$takes" -gt 0 ] && [ "$badk" -gt 0 ] && by=unverified
hf=none; [ $(( pre_h + post_h )) -gt 0 ] && hf=write
echo "LOCK by=$by held_for=$hf probe_held=$probe_h pre_held=$pre_h post_held=$post_h gap_held=$gap_h takes=$takes criterion_s=${c:-?} mid_run_send=$sent done_rc=$rc closed=yes"
exit 0
