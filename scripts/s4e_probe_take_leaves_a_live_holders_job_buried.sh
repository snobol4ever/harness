#!/usr/bin/env bash
# s4e_probe_take_leaves_a_live_holders_job_buried.sh -- THE PROBE of row bus-take-never-archives-a-live-claimants-claim-the-duplicate-job-is-buried-for-the-holder-cio-12-w2
# (the cio, 2026-11-08 13:0x CST, on the coo's EMERGENCY of 12:28: job 532 of step 28 taken by junior_03, 05, 08, 10, 11, 13, 14 and 12 in five minutes,
# each take archiving the live holder's claim as STALE under the head-never-cycles rule and the robbed holder releasing the job to the next taker;
# 30 STALE CLAIM ledger lines and twelve duplicate worktrees today). The holder side is cured at 4b3c63ae; this is the take side, the belt.
# On a scratch postoffice and a PRIVATE beanstalkd (never 11300), two jobs in tier-haiku:
#   J1 of t1: a claim names pa with RESERVED job=J1 stamped NOW (pa is alive by its stamp, S4E_CLAIM_LIVE_S). seat pb runs next.
#       EXPECT pb is NOT served t1; t1's claim still names pa, with a PARK HELD-BY line; J1 is BURIED within 20 s by pb's holder; no claims/expired/t1.*.
#   J2 of t2: a claim names px with RESERVED job=J2 stamped 2026-11-08T00:00:00Z (px has no seat scope and the stamp is old: dead).
#       EXPECT the same next serves t2 to pb and archives px's claim to claims/expired (today's stale-claim behaviour, kept for a dead claimant).
#   then pa runs escalate t1 with a measurement: EXPECT J1 (buried, no holder) is deleted by the bus and t1 reads QUEUED:tier-sonnet.
# One line: TAKE_LIVE dup_served=0|1 claim_kept=0|1 parked=0|1 buried=0|1 not_expired=0|1 dead_served=0|1 dead_archived=0|1 escalated=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
MSG="$S4E/harness/scripts/s4e_msg.sh"; UQ="$S4E/harness/scripts/util_queue.py"
sess="$(awk -F'\t' -v s="$ME" '!/^#/ && $1==s {print $2; exit}' "$S4E/.github/TIERS.tsv")"
[ -n "$sess" ] || { echo "REFUSE(2): $ME has no row in $S4E/.github/TIERS.tsv"; exit 2; }
pgrep -f "(^|/)claude --name $sess( |\$)" >/dev/null || { echo "REFUSE(2): no live session $sess (the holders would release at once); run it from a live seat"; exit 2; }
command -v beanstalkd >/dev/null || { echo "REFUSE(2): no beanstalkd binary"; exit 2; }
mkdir -p "/tmp/s4e/$ME"
port=$((21000 + ($$ % 20000)))
beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bp=$!
w="$(mktemp -d "/tmp/s4e/$ME/take_live.XXXXXX")" || { kill "$bp"; echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'for f in "$w/claims/"*.claim; do [ -f "$f" ] && echo DONE >> "$f"; done; sleep 6; kill "$bp" 2>/dev/null; wait "$bp" 2>/dev/null; rm -rf "$w"' EXIT
export S4E_QUEUE_PORT="$port"
for i in $(seq 1 50); do python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && break; sleep 0.1; done
python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' || { echo "REFUSE(2): a private beanstalkd would not start on port $port"; exit 2; }
mkdir -p "$w/tasks" "$w/claims" "$w/pa/inbox" "$w/pb/inbox" "$w/escalations"
{ head -1 /home/resources/postoffice/MODE; echo "# probe"; echo "ROSTER: pa pb"; echo "BOSSES: pa"; } > "$w/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/PROTOCOL-VERSION"
printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\npa\t%s\t/tmp\tclaude-haiku-5-5\thigh\tblue\t4\tworker\npb\t%s\t/tmp\tclaude-haiku-5-5\thigh\tblue\t4\tworker\n' "$sess" "$sess" > "$w/TIERS.tsv"
t1="take-live-held-$$"; t2="take-live-dead-$$"
printf '2\t%s\t@haiku\tQUEUED:tier-haiku\n2\t%s\t@haiku\tQUEUED:tier-haiku\n' "$t1" "$t2" > "$w/QUEUE.tsv"
for t in "$t1" "$t2"; do printf '# TASK %s\nGOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: false\nPREMISE-WHEN: true\nLINKS: minted via `mint` by probe, 2026-11-08T00:00:00Z\n## NEXT\nplant\n## QA\n## LEDGER\n- [probe] minted\n' "$t" > "$w/tasks/$t.task.md"; done
bus() { env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$1" S4E_HOME="$S4E" S4E_TIERS="$w/TIERS.tsv" S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK=1 timeout -k 5 300 bash "$MSG" "${@:2}" 2>&1; }
j1="$(python3 "$UQ" put tier-haiku "$t1" --pri 1000 --ttr 600)" || { echo "REFUSE(2): put J1 failed"; exit 2; }
j2="$(python3 "$UQ" put tier-haiku "$t2" --pri 1001 --ttr 600)" || { echo "REFUSE(2): put J2 failed"; exit 2; }
printf 'pa\nRESERVED job=%s tube=tier-haiku %s\n' "$j1" "$(date -u +%FT%TZ)" > "$w/claims/$t1.claim"
printf 'px\nRESERVED job=%s tube=tier-haiku 2026-11-08T00:00:00Z\n' "$j2" > "$w/claims/$t2.claim"
o="$(bus pb next)"
ds=0; printf '%s\n' "$o" | grep -q "^RESERVED $t1 " && ds=1
ck=0; [ "$(head -1 "$w/claims/$t1.claim" 2>/dev/null)" = pa ] && grep -q "^RESERVED job=$j1 " "$w/claims/$t1.claim" && ck=1
pk=0; grep -q "^PARK HELD-BY:pa:" "$w/claims/$t1.claim" 2>/dev/null && pk=1
bu=0; for i in $(seq 1 20); do [ "$(python3 "$UQ" stats-job "$j1" 2>/dev/null | cut -f3)" = buried ] && { bu=1; break; }; sleep 1; done
ne=1; ls "$w/claims/expired/$t1.claim."* >/dev/null 2>&1 && ne=0
dd=0; printf '%s\n' "$o" | grep -q "^RESERVED $t2 " && dd=1
da=0; ls "$w/claims/expired/$t2.claim."* >/dev/null 2>&1 && da=0 || da=0; ls "$w/claims/expired/$t2.claim."* >/dev/null 2>&1 && da=1
es=0
if [ "$bu" = 1 ]; then
    eo="$(printf 'MEASURED: probe arm, one honest try failed; the job was buried for the holder at a duplicate take.\n' | bus pa escalate "$t1" --stdin)"
    st="$(awk -F'\t' -v t="$t1" '$2==t {print $4}' "$w/QUEUE.tsv")"
    python3 "$UQ" stats-job "$j1" >/dev/null 2>&1 || { [ "$st" = QUEUED:tier-sonnet ] && es=1; }
fi
ok=0; [ "$ds" = 0 ] && [ "$ck" = 1 ] && [ "$pk" = 1 ] && [ "$bu" = 1 ] && [ "$ne" = 1 ] && [ "$dd" = 1 ] && [ "$da" = 1 ] && [ "$es" = 1 ] && ok=1
echo "TAKE_LIVE dup_served=$ds claim_kept=$ck parked=$pk buried=$bu not_expired=$ne dead_served=$dd dead_archived=$da escalated=$es ok=$ok"
[ "$ok" = 1 ] || { printf 'TAKE_LIVE next said (last 8 lines): %s\n' "$(printf '%s\n' "$o" | tail -8 | tr '\n' '|' | cut -c1-900)" >&2; [ -n "${eo:-}" ] && printf 'TAKE_LIVE escalate said: %s\n' "$(printf '%s\n' "$eo" | tail -4 | tr '\n' '|' | cut -c1-600)" >&2; }
[ "$ok" = 1 ]
