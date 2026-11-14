#!/usr/bin/env bash
# s4e_probe_delete.sh -- the probe of the bus verb delete (CIO-65 (3); row bus-delete-verb-removes-a-live-row-its-task-file-and-its-claim-for-a-designers-re-cut-verdict),
# run as: bash harness/scripts/s4e_msg.sh delete --plant. On a scratch postoffice and a scratch RECUT.tsv, the verb runs as the cio: it plants a FREE row with its
# task file, its probe file and a claim held by the cio, deletes it, and must leave no row, no task file, no claim, and one line in RECUT.tsv. Then it plants a second
# row claimed by another seat and not DONE, and the verb must refuse it with rc 2 and leave the row in place. Prints DELETE_PLANT ok when both hold, else DELETE_PLANT RED
# with the reason. rc 0 green; rc 1 the verb misbehaves; rc 2 could not measure. The live queue and the live RECUT.tsv are never written.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ME="${S4E_SEAT:-}"
refuse() { echo "REFUSE(2) [delete --plant]: $*"; exit 2; }
[ -n "$ME" ] || refuse "S4E_SEAT unset -- run it as: bash harness/scripts/s4e_msg.sh delete --plant"  # one-disk: not a path
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/delete_probe.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$w"' EXIT
po="$w/po"; rf="$w/RECUT.tsv"
mkdir -p "$po/tasks" "$po/claims" "$po/cio/inbox" "$po/junior_07/inbox" || refuse "cannot make the scratch postoffice"
: > "$rf"
t1="plant-delete-probe-free"; t2="plant-delete-probe-claimed"
printf '2\t%s\t@haiku\tFREE\n2\t%s\t@haiku\tFREE\n' "$t1" "$t2" > "$po/QUEUE.tsv"
for t in "$t1" "$t2"; do
  printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nprobe\n## QA\n## LEDGER\n' "$t" > "$po/tasks/$t.task.md"
  printf 'probe\n' > "$po/tasks/$t.probe.sh"
done
printf 'cio\n' > "$po/claims/$t1.claim"
printf 'junior_07\n' > "$po/claims/$t2.claim"
bus() { env -u S4E_PID_LOCK S4E_POST="$po" S4E_SEAT=cio S4E_RECUT="$rf" S4E_HOME="$S4E" S4E_NO_BANNER=1 bash "$HERE/s4e_msg.sh" "$@"; }
why=""

out1="$(printf 'grep -q delete "${S4E_HARNESS:-/home/harness}/scripts/s4e_msg.sh"\n' | bus delete "$t1" --verdict DELETED-NOT-REAL --stdin 2>&1)"; rc1=$?
[ "$rc1" = 0 ] || why="$why the delete of the free planted row returned rc $rc1 ($(printf '%s' "$out1" | tail -1));"
printf '%s' "$out1" | grep -qx "DELETED $t1 DELETED-NOT-REAL" || why="$why the verb did not print DELETED $t1 DELETED-NOT-REAL;"
grep -qP "^[0-9]+\t\Q$t1\E\t" "$po/QUEUE.tsv" && why="$why the row survived the delete;"
[ -e "$po/tasks/$t1.task.md" ] && why="$why the task file survived the delete;"
[ -e "$po/tasks/$t1.probe.sh" ] && why="$why the probe file survived the delete;"
[ -e "$po/claims/$t1.claim" ] && why="$why the claim survived the delete;"
[ "$(wc -l < "$rf")" = 1 ] || why="$why RECUT.tsv gained $(wc -l < "$rf") lines, not one;"
awk -F'\t' -v t="$t1" '$2=="cio" && $3==t && $4=="DELETED-NOT-REAL" && $5=="-" && $6!=""' "$rf" | grep -q . || why="$why the RECUT.tsv line does not carry cio, the topic, the verdict, a dash and the body;"
grep -qP "^[0-9]+\t\Q$t2\E\t" "$po/QUEUE.tsv" || why="$why the second row was removed before its refusal;"

out2="$(printf 'body\n' | bus delete "$t2" --verdict DELETED-NOT-REAL --stdin 2>&1)"; rc2=$?
[ "$rc2" = 2 ] || why="$why a delete of a row claimed by another seat returned rc $rc2, not 2;"
grep -qP "^[0-9]+\t\Q$t2\E\t" "$po/QUEUE.tsv" || why="$why the row claimed by another seat was removed;"
[ -e "$po/claims/$t2.claim" ] || why="$why the claim of the refused row was removed;"
[ "$(wc -l < "$rf")" = 1 ] || why="$why the refused delete wrote to RECUT.tsv;"

if [ -z "$why" ]; then echo "DELETE_PLANT ok"; exit 0; fi
echo "DELETE_PLANT RED:$why"; exit 1
