#!/usr/bin/env bash
# s4e_probe_unclaim_releases_only_its_own.sh -- THE PROBE of row bus-unclaim-releases-only-the-callers-own-claim-a-boss-alone-forces-another
# (officer_05, 2026-11-08 13:4x CST, on the coo's telegram of 12:42: junior_11 ran unclaim on step 28 and the line read "released by HQ (forced by
# junior_11 over junior_07's claim)"; the row went back to QUEUED:tier-haiku and was re-served). MEASURED at harness 98e96a663: unclaim lets an "HQ"
# force another seat's claim, and s4e_is_hq answers yes for every seat of MODE's ROSTER, which now names every junior. On a scratch postoffice:
#   arm worker  seat pa (in ROSTER, not in BOSSES) unclaims px's claim -> rc 2, the claim still names px (refused=1)
#   arm boss    seat pb (in BOSSES) unclaims px's claim               -> rc 0, the claim is gone (forced=1: a boss still frees a dead seat's lock)
#   arm own     seat pa unclaims its own claim                        -> rc 0 (own=1)
# One line: UNCLAIM_OWN refused=0|1 forced=0|1 own=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_unclaim_releases_only_its_own.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
MSG="$S4E/harness/scripts/s4e_msg.sh"; PO=/home/resources/postoffice
[ -f "$MSG" ] || { echo "REFUSE(2): no $MSG"; exit 2; }
w="$(mktemp -d "/tmp/s4e/$ME/unclaim_own.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$w"' EXIT
t1="unclaim-own-a-$$"; t2="unclaim-own-b-$$"; t3="unclaim-own-c-$$"
mkdir -p "$w/tasks" "$w/claims" "$w/pa/inbox" "$w/pb/inbox" "$w/px/inbox"
{ head -1 "$PO/MODE" 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: pa pb px"; echo "BOSSES: pb"; } > "$w/MODE"
[ -f "$PO/PROTOCOL-VERSION" ] && cp "$PO/PROTOCOL-VERSION" "$w/PROTOCOL-VERSION"
printf '# probe\n' > "$w/QUEUE.tsv"
for t in "$t1" "$t2" "$t3"; do printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nplant\n## QA\n## LEDGER\n' "$t" > "$w/tasks/$t.task.md"; done
printf '1\t%s\tpx\tCLAIMED:px\n1\t%s\tpx\tCLAIMED:px\n1\t%s\tpa\tCLAIMED:pa\n' "$t1" "$t2" "$t3" >> "$w/QUEUE.tsv"
printf 'px\n' > "$w/claims/$t1.claim"; printf 'px\n' > "$w/claims/$t2.claim"; printf 'pa\n' > "$w/claims/$t3.claim"
bus() { local s="$1"; shift; env -u S4E_PID_LOCK -u S4E_QUEUE_PORT S4E_POST="$w" S4E_SEAT="$s" S4E_HOME="$S4E" S4E_NO_BANNER=1 timeout -k 5 60 bash "$MSG" "$@" > "$w/out.$s.$$" 2>&1 < /dev/null; }
bus pa unclaim "$t1"; r1=$?
bus pb unclaim "$t2"; r2=$?
bus pa unclaim "$t3"; r3=$?
ref=0; [ "$r1" = 2 ] && [ "$(head -1 "$w/claims/$t1.claim" 2>/dev/null)" = px ] && ref=1
frc=0; [ "$r2" = 0 ] && [ ! -f "$w/claims/$t2.claim" ] && frc=1
own=0; [ "$r3" = 0 ] && [ ! -f "$w/claims/$t3.claim" ] && own=1
[ "$frc" = 1 ] || [ "$own" = 1 ] || { echo "REFUSE(2): unclaim released nothing on the scratch postoffice (rc $r2, $r3): $(tail -2 "$w/out.pa.$$" | tr '\n' '|' | cut -c1-200)"; exit 2; }
ok=0; [ "$ref" = 1 ] && [ "$frc" = 1 ] && [ "$own" = 1 ] && ok=1
echo "UNCLAIM_OWN refused=$ref forced=$frc own=$own ok=$ok (worker rc $r1, boss rc $r2, own rc $r3)"
[ "$ok" = 1 ]
