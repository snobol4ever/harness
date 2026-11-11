#!/usr/bin/env bash
# s4e_probe_a_fresh_file_claim_reads_alive.sh -- THE PROBE OF BASELINE bus-tube-herd-3 (officer_01, 2026-11-11): a file-road RESERVED claim written
# seconds ago reads ALIVE to its holder check. The holder has no seat scope (probe_nobody), so only the time of its RESERVED line can read it alive.
# Row F holds a file-form claim (RESERVED file tube=... session=... pid=... <ts>); row J holds the job-form claim (RESERVED job=... tube=... <ts>).
# A fresh claim must not be archived or served over; a claim 700 s old reads dead and is taken. A scratch postoffice under /tmp/s4e/<seat>/; the live queue is never touched.
# FRESH_CLAIM ok (rc 0) or FRESH_CLAIM red: <each failed check> (rc 1); REFUSE(2) when it cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
refuse() { echo "REFUSE(2) [fresh-claim probe]: $*"; exit 2; }
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/fresh_claim.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$w"' EXIT
F="fcl-f-$$"; J="fcl-j-$$"
TIERS="$REAL/.github/TIERS.tsv"; [ -f "$TIERS" ] || refuse "no real TIERS table at $TIERS"
mkdir -p "$w/po/tasks" "$w/po/claims/expired" "$w/po/$ME/inbox" || refuse "cannot make the scratch postoffice"
{ head -1 /home/resources/postoffice/MODE 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: $ME"; } > "$w/po/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/po/PROTOCOL-VERSION"
: > "$w/po/QUEUE.tsv"
baton() {   # <topic> <minted-ts>
    printf '# TASK %s\nGOAL: plant\nSKILLS: fleet-bus\nDONE-WHEN: false\nPREMISE-WHEN: true\nLINKS: minted via `mint` by probe, %s\n## NEXT\nplant\n## QA\n## LEDGER\n- [probe] minted\n' \
        "$1" "$2" > "$w/po/tasks/$1.task.md"; }
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$ME" "$3" >> "$w/po/QUEUE.tsv"; }   # rank topic state
row 2 "$F" "QUEUED:seat-$ME"; row 2 "$J" "QUEUED:seat-$ME"
baton "$F" 2026-11-01T00:00:00Z; baton "$J" 2026-11-02T00:00:00Z
plant() {   # <age-seconds>: the two claims, each stamped that many seconds ago; the holder is probe_nobody, which has no seat scope
    local ts; ts="$(date -u -d "@$(( $(date -u +%s) - $1 ))" +%FT%TZ)"
    printf 'probe_nobody\nRESERVED file tube=seat-%s session=PROBE pid=0 %s\n' "$ME" "$ts" > "$w/po/claims/$F.claim"
    printf 'probe_nobody\nRESERVED job=2 tube=seat-%s %s\n' "$ME" "$ts" > "$w/po/claims/$J.claim"; }
bus() { env -u S4E_PID_LOCK S4E_POST="$w/po" S4E_HOME="$REAL" S4E_TIERS="$TIERS" S4E_SEAT="$ME" S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK=1 \
    S4E_LAND_IGNORE_MAIL=probe timeout -k 5 120 bash "$HERE/s4e_msg.sh" next 2>&1; }
why=""
alive() { grep -q 'holds the row and is alive' "$w/po/tasks/$1.task.md"; }
# 1. a claim written seconds ago reads ALIVE: the take says so on the baton (the live branch), the claim is kept and no row is served over it
plant 5; baton "$F" 2026-11-01T00:00:00Z; baton "$J" 2026-11-02T00:00:00Z
out="$(bus)"
alive "$F" || why="$why the fresh file-form claim of $F does not read alive (no live-holder line on its baton: the RESERVED line of the file form carries a time the check cannot read);"
alive "$J" || why="$why the fresh job-form claim of $J does not read alive (control arm);"
[ -f "$w/po/claims/$F.claim" ] || why="$why the fresh claim of $F was removed;"
[ -z "$(ls "$w/po/claims/expired" 2>/dev/null)" ] || why="$why a fresh claim was moved to claims/expired;"
printf '%s' "$out" | grep -q "^RESERVED $F " && why="$why the fresh claim's row $F was served to $ME over a live holder;"
# 2. a claim 700 s old reads DEAD: no alive line is written for it, and its row is not served over a live holder
baton "$F" 2026-11-01T00:00:00Z; baton "$J" 2026-11-02T00:00:00Z
plant 700
out="$(bus)"
alive "$F" && why="$why a 700 s old claim of $F reads alive (it should read dead);"
if [ -z "$why" ]; then echo "FRESH_CLAIM ok"; exit 0; fi
echo "FRESH_CLAIM red:$why"; exit 1
