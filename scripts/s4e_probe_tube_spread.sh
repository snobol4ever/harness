#!/usr/bin/env bash
# s4e_probe_tube_spread.sh -- the tube-spread probe (bus-tube-herd-2, officer_01 2026-11-11): eight haiku seats on a scratch postoffice must
# not all take the same head job of one tube. Round 1: eight rows of rank 2 with distinct mint stamps; each seat, in turn, takes a fresh
# claim set and runs `next`; the head it wrote is recorded. Round 2: a ninth row sp-0 at rank 1 is planted; every seat must take sp-0
# (rank still rules). A claim is the reserve, so each seat's take is cleared before the next seat runs. Prints one TUBE_SPREAD line;
# rc 0 only when round 1 shows at least 5 distinct heads and round 2 gives sp-0 to every seat. Scratch state only (never the live queue).
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
BUS="$S4E/harness/scripts/s4e_msg.sh"
SEATS="junior_01 junior_02 junior_03 junior_04 junior_05 junior_06 junior_07 junior_08"
ME_TOP="${S4E_SEAT:-probe}"
mkdir -p "/tmp/s4e/$ME_TOP" 2>/dev/null
w="$(mktemp -d "/tmp/s4e/$ME_TOP/tube_spread.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$w"' EXIT
po="$w/po"
mkdir -p "$po/claims" "$po/tasks"
for s in $SEATS; do mkdir -p "$po/$s/inbox"; done
{ head -1 /home/resources/postoffice/MODE 2>/dev/null || echo TENET; echo "# tube-spread probe"; echo "ROSTER: $SEATS"; } > "$po/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$po/PROTOCOL-VERSION"
{ printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\n'
  for s in $SEATS; do printf '%s\tP\t/tmp\tclaude-haiku-5-5\txhigh\tblue\t4\tworker\n' "$s"; done; } > "$po/TIERS.tsv"

plant_task() {   # <topic> <stamp-minute>: a baton with a distinct mint stamp; DONE-WHEN is false (the serve never runs it)
    printf '# TASK %s\nGOAL: tube-spread probe row\nDONE-WHEN: false\nPREMISE-WHEN: true\nLINKS: minted via `mint` by plant, 2026-11-11T10:%s:00Z\n## NEXT\nplant\n## QA\n## LEDGER\n- [plant] minted\n' "$1" "$2" > "$po/tasks/$1.task.md"
}
plant_queue() {  # the queue as round 1 needs it (eight rank-2 rows) plus, when $1 is 9, the rank-1 row sp-0
    {
        printf '# tube-spread probe queue\n'
        [ "${1:-8}" = 9 ] && printf '1\tsp-0\tcoo\tQUEUED:tier-haiku\n'
        for n in 1 2 3 4 5 6 7 8; do printf '2\tsp-%s\tcoo\tQUEUED:tier-haiku\n' "$n"; done
    } > "$po/QUEUE.tsv"
}
for n in 1 2 3 4 5 6 7 8; do plant_task "sp-$n" "0$n"; done
plant_task "sp-0" "00"

round() {        # prints the head each seat takes, one per line: "<seat> <head>"
    local s out head
    for s in $SEATS; do
        rm -f "$po"/claims/*.claim
        out="$(env -u S4E_PID_LOCK S4E_POST="$po" S4E_SEAT="$s" S4E_HOME="$S4E" S4E_TIERS="$po/TIERS.tsv" S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK=1 timeout -k 5 120 bash "$BUS" next 2>&1 < /dev/null)"
        head="$(ls "$po"/claims/*.claim 2>/dev/null | sed 's#.*/##; s#\.claim$##' | head -1)"
        printf '%s %s\n' "$s" "${head:-none}"
        [ -n "$head" ] || printf '  (no claim; next said: %s)\n' "$(printf '%s' "$out" | tail -1 | cut -c1-120)" >&2
        plant_queue "$PLANT_N"
    done
}

PLANT_N=8; plant_queue 8
R1="$(round)"
PLANT_N=9; plant_queue 9
R2="$(round)"

distinct="$(printf '%s\n' "$R1" | awk '{print $2}' | grep -v '^none$' | sort -u | wc -l)"
r2_ok="$(printf '%s\n' "$R2" | awk '$2=="sp-0"' | wc -l)"
heads_seen="$(printf '%s\n' "$R1" | awk '{print $2}' | sort | uniq -c | awk '{printf "%s:%s ", $2, $1}')"

if [ "$distinct" -ge 5 ] && [ "$r2_ok" = 8 ]; then
    echo "TUBE_SPREAD ok distinct_heads=$distinct round2_rank1_taken=$r2_ok/8"
    exit 0
fi
echo "TUBE_SPREAD red: distinct_heads=$distinct round2_rank1_taken=$r2_ok/8 heads_seen=[$heads_seen]"
exit 1
