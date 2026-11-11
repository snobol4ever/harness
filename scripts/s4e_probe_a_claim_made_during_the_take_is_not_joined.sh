#!/usr/bin/env bash
# s4e_probe_a_claim_made_during_the_take_is_not_joined.sh -- THE PROBE OF bus-tube-herd-4 (officer_01, 2026-11-11, on the coo's second double serve: row
# raku-a-method-the-receiver-lacks-throws-x-method-notfound-never-fails-silently reserved by junior_08 at 22:09:23Z and by junior_02 at 22:10:20Z, junior_02's
# RESERVED line appended to junior_08's claim file with no PARK line). s4e_queue_take_claim reads the foreign claim FIRST, then syncs, makes and reads the
# premise, and its tail appended this seat's RESERVED line to whatever claim file then existed. Here the row's PREMISE-WHEN is the racer: it writes a fresh
# file-form claim of probe_racer while the take is between its foreign check and its tail, an order of events and no clock. The take must not join it: the
# claim keeps probe_racer and its one RESERVED line, gains a PARK HELD-BY:probe_racer line, and the row is not served. A scratch postoffice and a scratch
# root (a SCRIP whose make does nothing) under /tmp/s4e/<seat>/; the live queue and the seat's root are never touched.
# JOINED_CLAIM ok (rc 0) or JOINED_CLAIM red: <each failed check> (rc 1); REFUSE(2) when it cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
refuse() { echo "REFUSE(2) [joined-claim probe]: $*"; exit 2; }
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/joined_claim.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$w"' EXIT
Q="jcl-$$"; C="$w/po/claims/$Q.claim"
TIERS="$REAL/.github/TIERS.tsv"; [ -f "$TIERS" ] || refuse "no real TIERS table at $TIERS"
mkdir -p "$w/po/tasks" "$w/po/claims/expired" "$w/po/$ME/inbox" "$w/root/SCRIP" || refuse "cannot make the scratch postoffice and root"
printf 'all:\n\t@true\n' > "$w/root/SCRIP/Makefile"
{ head -1 /home/resources/postoffice/MODE 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: $ME"; } > "$w/po/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/po/PROTOCOL-VERSION"
printf '2\t%s\t%s\tQUEUED:seat-%s\n' "$Q" "$ME" "$ME" > "$w/po/QUEUE.tsv"
racer="[ -f '$C' ] || printf 'probe_racer\nRESERVED file tube=seat-$ME session=RACER pid=0 %s\n' \"\$(date -u +%FT%TZ)\" > '$C'"
printf '# TASK %s\nGOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: false\nPREMISE-WHEN: %s\nLINKS: minted via `mint` by probe, 2026-11-01T00:00:00Z\n## NEXT\nplant\n## QA\n## LEDGER\n- [probe] minted\n' \
    "$Q" "$racer" > "$w/po/tasks/$Q.task.md"
out="$(env -u S4E_PID_LOCK S4E_POST="$w/po" S4E_HOME="$w/root" S4E_TIERS="$TIERS" S4E_SEAT="$ME" S4E_NO_BANNER=1 S4E_LAND_IGNORE_MAIL=probe \
    timeout -k 5 120 bash "$HERE/s4e_msg.sh" next 2>&1 < /dev/null)"
[ -f "$C" ] || refuse "the racer never ran: no claim of probe_racer at $C (the take did not reach the premise; next said: $(printf '%s' "$out" | tail -3 | tr '\n' ' ' | cut -c1-300))"
why=""
[ "$(head -1 "$C")" = probe_racer ] || why="$why the claim's owner is $(head -1 "$C"), not probe_racer;"
n="$(grep -c '^RESERVED ' "$C")"; [ "$n" = 1 ] || why="$why the racer's claim holds $n RESERVED lines (the take joined it);"
grep -q '^PARK HELD-BY:probe_racer:' "$C" || why="$why no PARK HELD-BY:probe_racer line on the claim (the take did not bury its duplicate);"
printf '%s' "$out" | grep -q "^RESERVED $Q " && why="$why $Q was served to $ME over the racer's claim;"
if [ -z "$why" ]; then echo "JOINED_CLAIM ok"; exit 0; fi
echo "JOINED_CLAIM red:$why"; exit 1
