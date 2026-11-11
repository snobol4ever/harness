#!/usr/bin/env bash
# s4e_probe_take_reads_the_claim_first.sh -- THE PROBE OF BASELINE bus-tube-herd-1 (officer_01, 2026-11-11): a take reads the foreign claim of a
# row BEFORE its root sync, its make and its premise, and a held row returns rc 5, never the red-premise rc 4. A scratch root and a scratch
# postoffice under /tmp/s4e/<seat>/; the live queue, the live batons and the live root are never read or written beyond the real TIERS table.
# Head row A is held by a hand claim (no RESERVED line) and its PREMISE-WHEN would leave a witness file; row B is free and the next take must serve it.
# TAKE_CLAIM_FIRST ok (rc 0) or TAKE_CLAIM_FIRST red: <each failed check> (rc 1); REFUSE(2) when it cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
refuse() { echo "REFUSE(2) [take-claim-first probe]: $*"; exit 2; }
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/take_claim_first.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$w"' EXIT
A="tkcf-a-$$"; B="tkcf-b-$$"
TIERS="$REAL/.github/TIERS.tsv"; [ -f "$TIERS" ] || refuse "no real TIERS table at $TIERS"
mkdir -p "$w/root/SCRIP" "$w/po/tasks" "$w/po/claims" "$w/po/$ME/inbox" || refuse "cannot make the scratch postoffice and root"
printf 'all:\n\techo x >> %s\n' "$w/make.count" > "$w/root/SCRIP/Makefile"
{ head -1 /home/resources/postoffice/MODE 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: $ME"; } > "$w/po/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/po/PROTOCOL-VERSION"
: > "$w/po/QUEUE.tsv"
baton() {   # <topic> <minted-ts> <premise>
    printf '# TASK %s\nGOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: false\nPREMISE-WHEN: %s\nLINKS: minted via `mint` by probe, %s\n## NEXT\nplant\n## QA\n## LEDGER\n- [probe] minted\n' \
        "$1" "$3" "$2" > "$w/po/tasks/$1.task.md"; }
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$ME" "$3" >> "$w/po/QUEUE.tsv"; }   # rank topic state
row 2 "$A" "QUEUED:seat-$ME"; row 2 "$B" "QUEUED:seat-$ME"
baton "$A" 2026-11-01T00:00:00Z "touch $w/ran-A; true"
baton "$B" 2026-11-02T00:00:00Z "touch $w/ran-B; true"
printf '%s\n%s\n' probe_other RUNNING > "$w/po/claims/$A.claim"
out="$(env -u S4E_PID_LOCK S4E_POST="$w/po" S4E_HOME="$w/root" S4E_TIERS="$TIERS" S4E_SEAT="$ME" S4E_NO_BANNER=1 S4E_LAND_IGNORE_MAIL=probe \
    timeout -k 5 300 bash "$HERE/s4e_msg.sh" next 2>&1)"
why=""
n="$(cat "$w/make.count" 2>/dev/null | wc -l)"
[ "$n" -eq 1 ] || why="$why make ran $n times, want 1 (the held head must return before the sync and the make);"
[ ! -e "$w/ran-A" ] || why="$why the premise of the held row $A ran (its witness exists: the premise was read before the claim check);"
grep -q 'PREMISE-WHEN read RED' "$w/po/tasks/$A.task.md" && why="$why the baton of $A carries the false RED line;"
sa="$(awk -F'\t' -v t="$A" '$2 == t { print $4; exit }' "$w/po/QUEUE.tsv")"
[ "$sa" = "QUEUED:seat-$ME" ] || why="$why row $A reads '${sa:-none}' after the take, not QUEUED:seat-$ME;"
[ -f "$w/po/claims/$B.claim" ] && [ "$(head -1 "$w/po/claims/$B.claim")" = "$ME" ] || why="$why row $B was not taken by $ME (the next take must serve it: got '$(printf '%s' "$out" | grep -m1 -E 'RESERVED|REFUSE|⛔' | cut -c1-120)');"
if [ -z "$why" ]; then echo "TAKE_CLAIM_FIRST ok"; exit 0; fi
echo "TAKE_CLAIM_FIRST red:$why"; exit 1
