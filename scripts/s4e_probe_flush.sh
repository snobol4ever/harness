#!/usr/bin/env bash
# s4e_probe_flush.sh -- THE PROBE OF flush step 1 (the cio's design order 2026-11-11 on Lon: "Since so many asses are sharing the tube, sometimes shit gets stuck inside and needs flushing."; cut by officer_01):
# s4e_msg.sh flush archives every dead claim and every .bak or .release leftover older than a grace (S4E_FLUSH_GRACE_S, default 600) into claims/archive/flush-<ts>-<seat>/,
# keeps a claim whose row still names its holder, and says FLUSH archived=N kept=M. RUNS ON A SCRATCH POSTOFFICE under /tmp/s4e/<seat>/; the live queue is never read or written.
# Prints FLUSH_PROBE ok (rc 0) or FLUSH_PROBE red: <each failed check> (rc 1); REFUSE(2) when it cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ME="${S4E_SEAT:-probe}"
refuse() { echo "REFUSE(2) [flush probe]: $*"; exit 2; }
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/flush_probe.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$w"' EXIT
po="$w/po"
mkdir -p "$po/claims" "$po/tasks" "$po/$ME/inbox" || refuse "cannot make the scratch postoffice"
cp /home/resources/postoffice/MODE "$po/MODE" 2>/dev/null || echo TENET > "$po/MODE"
: > "$po/QUEUE.tsv"
old() { touch -d "@$(( $(date +%s) - 700 ))" "$1"; }
plant() {   # <file> <holder> <row-state or -> <old|young>: a claim file, its QUEUE.tsv row (unless -) and its baton
    local f="$1" h="$2" st="$3" age="$4" t="${1%.claim}"
    printf '%s\n' "$h" > "$po/claims/$f"
    [ "$age" = old ] && old "$po/claims/$f"
    [ "$st" = - ] || printf '1\t%s\t@sonnet\t%s\n' "$t" "$st" >> "$po/QUEUE.tsv"
    printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nplant\n## QA\n## LEDGER\n- [probe] minted\n' "$t" > "$po/tasks/$t.task.md"
}
plant gone.claim junior_01 - old
plant held.claim junior_02 CLAIMED:junior_02 old
plant wrong.claim junior_03 CLAIMED:junior_04 old
plant free.claim junior_05 FREE old
plant blocked.claim junior_06 BLOCKED-ON:held old
plant meas.claim junior_07 MEASURING:junior_07:1 old
plant asg.claim junior_08 ASSIGNED:junior_08 old
plant await.claim junior_09 PARKED-AWAITING:x old
plant done.claim junior_10 FREE old
printf 'DONE\n' >> "$po/claims/done.claim"; old "$po/claims/done.claim"
plant young.claim junior_11 - young
: > "$po/claims/x.claim.bakrename"; old "$po/claims/x.claim.bakrename"
: > "$po/claims/y.claim.release.123"; old "$po/claims/y.claim.release.123"
out="$(env -u S4E_PID_LOCK S4E_POST="$po" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 timeout -k 5 120 bash "$HERE/s4e_msg.sh" flush 2>&1)"
why=""
arch="$(ls -d "$po"/claims/archive/flush-* 2>/dev/null | head -1)"
for f in gone wrong free blocked; do
    [ ! -e "$po/claims/$f.claim" ] || why="$why $f.claim still in claims/;"
    [ -n "$arch" ] && [ -e "$arch/$f.claim" ] || why="$why $f.claim not under claims/archive/flush-*/;"
    [ "$(grep -c 'FLUSHED' "$po/tasks/$f.task.md")" = 1 ] || why="$why the baton of $f carries $(grep -c 'FLUSHED' "$po/tasks/$f.task.md") FLUSHED line(s) (want 1);"
done
for f in x.claim.bakrename y.claim.release.123; do
    [ ! -e "$po/claims/$f" ] || why="$why $f still in claims/;"
    [ -n "$arch" ] && [ -e "$arch/$f" ] || why="$why $f not under claims/archive/flush-*/;"
done
for f in held meas asg await done young; do
    [ -e "$po/claims/$f.claim" ] || why="$why $f.claim was moved (must stay);"
    [ "$(grep -c 'FLUSHED' "$po/tasks/$f.task.md")" = 0 ] || why="$why the baton of $f was written (must stay untouched);"
done
[ "$(printf '%s\n' "$out" | tail -1)" = "FLUSH archived=6 kept=6" ] || why="$why the last line reads '$(printf '%s\n' "$out" | tail -1)' (want FLUSH archived=6 kept=6);"
if [ -z "$why" ]; then echo "FLUSH_PROBE ok"; exit 0; fi
echo "FLUSH_PROBE red:$why"; exit 1
