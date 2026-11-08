#!/usr/bin/env bash
# s4e_probe_refused_take_releases_its_job.sh -- THE PROBE of row bus-a-take-that-refuses-before-its-claim-releases-its-job-at-once
# (officer_05, 2026-11-08 14:2x CST). MEASURED on officer_05's own root: next reserved job 5824 (tier-opus), the take refused "this root is dirty in
# .github", and the holder kept the job reserved (its 600 s take grace, harness 4b3c63ae) with no claim behind it, so no other escalation officer could be
# served it until officer_05 killed its own holder by pid. The take's three refusals before a claim exists (no baton, make failed, a dirty root) now drop
# a marker <topic>.claim.release.<job> and the holder releases at once on it. On a scratch claim dir and a PRIVATE beanstalkd (never 11300):
#   job J1: reserve-hold as pa beside a stale claim of px on J1; at 3 s the marker for J1 is written  -> ready by 14 s (released=1), the marker gone (cleaned=1)
#   job J2: the same, no marker                                                                  -> still reserved at 14 s (held=1: the take grace stands)
#   and s4e_msg.sh's take calls the marker on all three refusals (calls=3).
# One line: REFUSED_TAKE released=0|1 cleaned=0|1 held=0|1 calls=N ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_refused_take_releases_its_job.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
UQ="$S4E/harness/scripts/util_queue.py"; MSG="$S4E/harness/scripts/s4e_msg.sh"
[ -f "$UQ" ] && [ -f "$MSG" ] || { echo "REFUSE(2): no $UQ or $MSG"; exit 2; }
sess="$(awk -F'\t' -v s="$ME" '!/^#/ && $1==s {print $2; exit}' "$S4E/.github/TIERS.tsv")"
[ -n "$sess" ] || { echo "REFUSE(2): $ME has no row in $S4E/.github/TIERS.tsv"; exit 2; }
pgrep -f "(^|/)claude --name $sess( |\$)" >/dev/null || { echo "REFUSE(2): no live session $sess; run it from a live seat"; exit 2; }
command -v beanstalkd >/dev/null || { echo "REFUSE(2): no beanstalkd binary"; exit 2; }
mkdir -p "/tmp/s4e/$ME"; port=$((21000 + ($$ % 20000)))
beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bp=$!
w="$(mktemp -d "/tmp/s4e/$ME/refused_take.XXXXXX")" || { kill "$bp"; echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'for f in "$w/claims/"*.claim; do [ -f "$f" ] && echo DONE >> "$f"; done; sleep 6; kill "$bp" 2>/dev/null; wait "$bp" 2>/dev/null; rm -rf "$w"' EXIT
export S4E_QUEUE_PORT="$port"
for i in $(seq 1 50); do python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && break; sleep 0.1; done
python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' || { echo "REFUSE(2): a private beanstalkd would not start on port $port"; exit 2; }
mkdir -p "$w/tasks" "$w/claims"; tube="probe-refused-$$"
plant() { printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nplant\n## QA\n## LEDGER\n' "$1" > "$w/tasks/$1.task.md"; printf 'px\nRESERVED job=%s tube=%s 2026-11-08T00:00:00Z\n' "$2" "$tube" > "$w/claims/$1.claim"; }
state() { python3 "$UQ" stats-job "$1" 2>/dev/null | cut -f3; }
hold() { python3 "$UQ" reserve-hold "$tube" --seat pa --session "$sess" --claim-dir "$w/claims" --baton-dir "$w/tasks" --timeout 0 2>/dev/null | cut -f1; }
t1="refused-a-$$"; t2="refused-b-$$"
j1="$(python3 "$UQ" put "$tube" "$t1" --pri 1000 --ttr 600)"; plant "$t1" "$j1"; r1="$(hold)"; [ "$r1" = "$j1" ] || { echo "REFUSE(2): hold reserved [$r1], not $j1"; exit 2; }
j2="$(python3 "$UQ" put "$tube" "$t2" --pri 1000 --ttr 600)"; plant "$t2" "$j2"; r2="$(hold)"; [ "$r2" = "$j2" ] || { echo "REFUSE(2): hold reserved [$r2], not $j2"; exit 2; }
sleep 3; : > "$w/claims/$t1.claim.release.$j1"; sleep 11
rel=0; [ "$(state "$j1")" = ready ] && rel=1
cln=0; [ ! -e "$w/claims/$t1.claim.release.$j1" ] && cln=1
hld=0; [ "$(state "$j2")" = reserved ] && hld=1
[ "$rel" = 1 ] && python3 "$UQ" delete "$j1" >/dev/null 2>&1
calls="$(grep -c 's4e_take_refused "\$_t" "\$2"' "$MSG")"
ok=0; [ "$rel" = 1 ] && [ "$cln" = 1 ] && [ "$hld" = 1 ] && [ "$calls" -ge 3 ] && ok=1
echo "REFUSED_TAKE released=$rel cleaned=$cln held=$hld calls=$calls ok=$ok"
[ "$ok" = 1 ]
