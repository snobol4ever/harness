#!/usr/bin/env bash
# util_probe_next_resume_skip.sh -- the probe of bus row B (senior_07 2026-11-08, COO-493): next's PASS 2 (the RESUME of an unfinished claim) must skip a claim whose QUEUE.tsv row is PARKED*, BLOCKED-ON:*, QUEUED:* or DONE*.
# A scratch postoffice and scratch tiers only; it never reads or writes the live queue. rc 0 GREEN, 1 RED, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
SH="$S4E/harness/scripts/s4e_msg.sh"
[ -f "$SH" ] || { echo "REFUSE(2): no $SH"; exit 2; }
w="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-probe}/resume_skip.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$w"' EXIT
mkdir -p "$w/claims" "$w/tasks" "$w/senior_07/inbox"; cp /home/resources/postoffice/MODE "$w/MODE" || { echo "REFUSE(2): no MODE"; exit 2; }
printf 'senior_07\tSENIOR-07\t/tmp\tclaude-sonnet-5-5\tmedium\tpurple\t3\tsenior\n' > "$w/TIERS.tsv"
printf '1\tprobe-r1\t@senior_07\tCLAIMED:senior_07\n0\tprobe-r2\t@senior_07\tPARKED-LON-HOLD:x\n' > "$w/QUEUE.tsv"
for t in probe-r1 probe-r2; do printf '# TASK %s\nGOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: true\nPREMISE-WHEN: true\nLINKS: probe\n## NEXT\nplant\n## LEDGER\n' "$t" > "$w/tasks/$t.task.md"; printf 'senior_07\nCLAIMED 2026-11-08T00:00:00Z\n' > "$w/claims/$t.claim"; done
run() { S4E_POST="$w" S4E_SEAT=senior_07 S4E_TIERS="$w/TIERS.tsv" S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK=1 S4E_QUEUE_PORT=1 timeout -k 5 60 bash "$SH" next < /dev/null 2>&1; }
o1="$(run)"
printf '%s\n' "$o1" | grep -q '^RESUME probe-r1 ' || { echo "RED: with r1 CLAIMED and r2 parked, next did not print RESUME probe-r1"; printf '%s\n' "$o1" | head -5; exit 1; }
printf '%s\n' "$o1" | grep -q '^RESUME probe-r2 ' && { echo "RED: next RESUMED probe-r2, a row PARKED-LON-HOLD"; exit 1; }
printf '%s\n' "$o1" | grep -q '^SKIP probe-r2' || { echo "RED: no SKIP line for probe-r2"; exit 1; }
rm -f "$w/claims/probe-r1.claim"
o2="$(run)"
printf '%s\n' "$o2" | grep -q '^SKIP probe-r2' || { echo "RED: with r1 gone, no SKIP line for probe-r2"; printf '%s\n' "$o2" | head -5; exit 1; }
printf '%s\n' "$o2" | grep -q '^RESUME probe-r2 ' && { echo "RED: with r1 gone, next RESUMED probe-r2"; exit 1; }
echo "GREEN: next resumes the claim whose row is CLAIMED and skips the claim whose row is PARKED-LON-HOLD"
