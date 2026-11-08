#!/usr/bin/env bash
# s4e_probe_holder_keeps_a_job_through_its_take.sh -- THE PROBE of row bus-the-holder-keeps-its-job-through-the-take-a-stale-claim-of-the-same-job-never-releases-it
# (officer_05, 2026-11-08 12:3x CST, on the coo's telegrams of 11:56, 12:09 and 12:19: jobs 5665, 5674 and 5702 each served to four to six juniors).
# MEASURED cause, the holder logs /tmp/s4e/junior_{02,07,08,09,11}/queue_hold.5702.log: junior_09's holder released at its 60 s grace ("claim gone")
# because its take (sync, make, premise) had not yet written the claim; every later holder of the SAME job released 5 s after reserving ("claim
# names <the previous taker>, not <me>: release") because the previous taker's claim stays on disk until the new take overwrites it 20 to 25 s
# later. So the job is ready again during every take and the next junior is served it: a cascade, not a TTR expiry. The interim guard
# (harness b50476094) covers a DIFFERENT job for a held row only.
# On a scratch claim dir and a PRIVATE beanstalkd (never 11300), with S4E_HOLD_TAKE_GRACE_S=20:
#   job J1: a stale claim names seat px on J1; reserve-hold as pa; the claim is never rewritten.
#           EXPECT reserved at 12 s (held_through_take=1) and ready by 40 s (released_after_grace=1: a take that never comes does not hold forever).
#   job J2: the same stale claim; reserve-hold as pa; at 3 s the take rewrites the claim to pa on J2.
#           EXPECT reserved at 40 s (held_after_take=1); then the claim reads DONE and J2 is deleted within 15 s (deleted_on_done=1).
# One line: HOLD_TAKE held_through_take=0|1 released_after_grace=0|1 held_after_take=0|1 deleted_on_done=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_holder_keeps_a_job_through_its_take.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
UQ="$S4E/harness/scripts/util_queue.py"
[ -f "$UQ" ] || { echo "REFUSE(2): no $UQ"; exit 2; }
sess="$(awk -F'\t' -v s="$ME" '!/^#/ && $1==s {print $2; exit}' "$S4E/.github/TIERS.tsv")"
[ -n "$sess" ] || { echo "REFUSE(2): $ME has no row in $S4E/.github/TIERS.tsv"; exit 2; }
pgrep -f "(^|/)claude --name $sess( |\$)" >/dev/null || { echo "REFUSE(2): no live session $sess (the holders would release at once); run it from a live seat"; exit 2; }
command -v beanstalkd >/dev/null || { echo "REFUSE(2): no beanstalkd binary"; exit 2; }
mkdir -p "/tmp/s4e/$ME"
port=$((21000 + ($$ % 20000)))
beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bp=$!
w="$(mktemp -d "/tmp/s4e/$ME/hold_take.XXXXXX")" || { kill "$bp"; echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'for f in "$w/claims/"*.claim; do [ -f "$f" ] && echo DONE >> "$f"; done; sleep 6; kill "$bp" 2>/dev/null; wait "$bp" 2>/dev/null; rm -rf "$w"' EXIT
export S4E_QUEUE_PORT="$port" S4E_HOLD_TAKE_GRACE_S=20
for i in $(seq 1 50); do python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && break; sleep 0.1; done
python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' || { echo "REFUSE(2): a private beanstalkd would not start on port $port"; exit 2; }
mkdir -p "$w/tasks" "$w/claims"
plant() {   # topic job -> a baton and the previous taker's stale claim naming px on that job
    printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nplant\n## QA\n## LEDGER\n' "$1" > "$w/tasks/$1.task.md"
    printf 'px\nRESERVED job=%s tube=tier-haiku 2026-11-08T00:00:00Z\n' "$2" > "$w/claims/$1.claim"; }
state() { python3 "$UQ" stats-job "$1" 2>/dev/null | cut -f3; }
hold() {    # topic -> reserve-hold as pa; prints the job id it reserved
    python3 "$UQ" reserve-hold "probe-hold-$$" --seat pa --session "$sess" --claim-dir "$w/claims" --baton-dir "$w/tasks" --timeout 0 2>/dev/null | cut -f1; }
t1="hold-take-a-$$"; t2="hold-take-b-$$"
j1="$(python3 "$UQ" put "probe-hold-$$" "$t1" --pri 1000 --ttr 600)" || { echo "REFUSE(2): put J1 failed"; exit 2; }
plant "$t1" "$j1"
r1="$(hold)"; [ "$r1" = "$j1" ] || { echo "REFUSE(2): reserve-hold reserved [$r1], not J1 $j1"; exit 2; }
j2="$(python3 "$UQ" put "probe-hold-$$" "$t2" --pri 1000 --ttr 600)" || { echo "REFUSE(2): put J2 failed"; exit 2; }
plant "$t2" "$j2"
r2="$(hold)"; [ "$r2" = "$j2" ] || { echo "REFUSE(2): reserve-hold reserved [$r2], not J2 $j2"; exit 2; }
sleep 3
printf 'pa\nRESERVED job=%s tube=probe-hold-%s 2026-11-08T00:00:03Z\n' "$j2" "$$" > "$w/claims/$t2.claim.new" && mv "$w/claims/$t2.claim.new" "$w/claims/$t2.claim"
sleep 9
ht=0; [ "$(state "$j1")" = reserved ] && ht=1
sleep 28
ra=0; [ "$(state "$j1")" = ready ] && ra=1
withdraw="$(python3 "$UQ" stats-job "$j1" >/dev/null 2>&1 && echo y)"; [ -n "$withdraw" ] && [ "$ra" = 1 ] && python3 "$UQ" delete "$j1" >/dev/null 2>&1
ha=0; [ "$(state "$j2")" = reserved ] && ha=1
echo DONE >> "$w/claims/$t2.claim"
dd=0; for i in $(seq 1 15); do python3 "$UQ" stats-job "$j2" >/dev/null 2>&1 || { dd=1; break; }; sleep 1; done
ok=0; [ "$ht" = 1 ] && [ "$ra" = 1 ] && [ "$ha" = 1 ] && [ "$dd" = 1 ] && ok=1
echo "HOLD_TAKE held_through_take=$ht released_after_grace=$ra held_after_take=$ha deleted_on_done=$dd ok=$ok"
[ "$ok" = 1 ]
