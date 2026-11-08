#!/usr/bin/env bash
# two_jobs_one_row.sh -- THE PROBE of row bus-a-second-job-for-a-held-row-is-deleted-never-served-two-jobs-one-row-interim (officer_05, 2026-11-08 13:1x CST,
# on the coo's URGENT telegram of 11:56: job 5665 of icon-unicon-step-44 served to five juniors in ten minutes). MEASURED cause, the five holder logs
# /tmp/s4e/junior_{09,10,11,14,15}/queue_hold.5665.log: every holder exited "claim names <another seat>, not <me>: release", because the row had TWO jobs
# (5651 in tier-opus, 5665 in tier-haiku) and each take of either archived the other's LIVE claim as STALE, so the holders took turns releasing.
# On a scratch postoffice and a PRIVATE beanstalkd (never 11300): seat pa takes job J1 of topic t; a duplicate job J2 of the same topic is then served to
# seat pb. EXPECT: pb is NOT served t; t's claim still names pa on J1; J2 is deleted by pb's holder within 20 s; J1 is still reserved.
# One line: TWO_JOBS served_dup=0|1 claim_kept=0|1 dup_deleted=0|1 live_kept=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_two_jobs_one_row.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
MSG="$S4E/harness/scripts/s4e_msg.sh"; UQ="$S4E/harness/scripts/util_queue.py"
sess="$(awk -F'\t' -v s="$ME" '!/^#/ && $1==s {print $2; exit}' "$S4E/.github/TIERS.tsv")"
[ -n "$sess" ] || { echo "REFUSE(2): $ME has no row in $S4E/.github/TIERS.tsv"; exit 2; }
pgrep -f "(^|/)claude --name $sess( |\$)" >/dev/null || { echo "REFUSE(2): no live session $sess (the holders would release at once); run it from a live seat"; exit 2; }
port=$((21000 + ($$ % 20000)))
beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bp=$!
w="$(mktemp -d "/tmp/s4e/$ME/two_jobs.XXXXXX")" || { kill "$bp"; echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -f "$w/claims/"*.claim; kill "$bp" 2>/dev/null; wait "$bp" 2>/dev/null; rm -rf "$w"' EXIT
export S4E_QUEUE_PORT="$port"
for i in $(seq 1 50); do python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && break; sleep 0.1; done
python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' || { echo "REFUSE(2): a private beanstalkd would not start on port $port"; exit 2; }
mkdir -p "$w/tasks" "$w/claims" "$w/pa/inbox" "$w/pb/inbox"
{ head -1 /home/resources/postoffice/MODE; echo "# probe"; echo "ROSTER: pa pb"; } > "$w/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/PROTOCOL-VERSION"
printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\npa\t%s\t/tmp\tclaude-haiku-5-5\thigh\tblue\t4\tworker\npb\t%s\t/tmp\tclaude-haiku-5-5\thigh\tblue\t4\tworker\n' "$sess" "$sess" > "$w/TIERS.tsv"
t="two-jobs-one-row-$$"
printf '2\t%s\t@haiku\tQUEUED:tier-haiku\n' "$t" > "$w/QUEUE.tsv"
printf '# TASK %s\nGOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: false\nPREMISE-WHEN: true\nLINKS: minted via `mint` by probe, 2026-11-08T00:00:00Z\n## NEXT\nplant\n## QA\n## LEDGER\n- [probe] minted\n' "$t" > "$w/tasks/$t.task.md"
bus() { env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$1" S4E_HOME="$S4E" S4E_TIERS="$w/TIERS.tsv" S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK=1 timeout -k 5 300 bash "$MSG" next 2>&1; }
j1="$(python3 "$UQ" put tier-haiku "$t" --pri 1000 --ttr 600)" || { echo "REFUSE(2): put J1 failed"; exit 2; }
o="$(bus pa)"; printf '%s\n' "$o" | grep -q "^RESERVED $t " || { echo "REFUSE(2): pa was not served J1 [$(printf '%s' "$o" | grep -m1 -E 'RESERVED|nothing|REFUSE|⛔' | cut -c1-100)]"; exit 2; }
grep -q "^RESERVED job=$j1 " "$w/claims/$t.claim" || { echo "REFUSE(2): pa's claim does not name J1"; exit 2; }
j2="$(python3 "$UQ" put tier-haiku "$t" --pri 1000 --ttr 600)" || { echo "REFUSE(2): put J2 failed"; exit 2; }
o="$(bus pb)"
sd=0; printf '%s\n' "$o" | grep -q "^RESERVED $t " && sd=1
ck=0; [ "$(head -1 "$w/claims/$t.claim" 2>/dev/null)" = pa ] && grep -q "^RESERVED job=$j1 " "$w/claims/$t.claim" && ck=1
dd=0; for i in $(seq 1 20); do python3 "$UQ" stats-job "$j2" >/dev/null 2>&1 || { dd=1; break; }; sleep 1; done
lk=0; [ "$(python3 "$UQ" stats-job "$j1" 2>/dev/null | cut -f3)" = reserved ] && lk=1
ok=0; [ "$sd" = 0 ] && [ "$ck" = 1 ] && [ "$dd" = 1 ] && [ "$lk" = 1 ] && ok=1
echo "TWO_JOBS served_dup=$sd claim_kept=$ck dup_deleted=$dd live_kept=$lk ok=$ok"
[ "$ok" = 1 ]
