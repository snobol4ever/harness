#!/usr/bin/env bash
# s4e_probe_done_lock.sh -- box-scheduler step 28's probe (CTO-496), run as: bash harness/scripts/s4e_msg.sh done --probe-lock
# On a scratch postoffice, under the caller's identity, a top-level done closes a row whose DONE-WHEN runs S4E_PROBE_CRIT_S seconds (default 10) while the
# identity lock file is sampled every 0.1 s, and a send from the same identity is issued while the criterion runs. The caller's own identity is released
# before the plant (a probe holds no identity). It prints one line:
#   DONE lock_held_s=<seconds the lock file named the done> criterion_s=<the criterion's run> mid_run_send=<delivered|refused> done_rc=<rc> closed=yes
# rc 0 when the plant measured (the step reads lock_held_s), 2 when it could not (no seat, no scratch, the done never reached its criterion or never closed).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ME="${S4E_SEAT:-}"
crit="${S4E_PROBE_CRIT_S:-10}"
refuse() { echo "REFUSE(2) [done --probe-lock]: $*"; exit 2; }
[ -n "$ME" ] || refuse "S4E_SEAT unset -- run it as: bash harness/scripts/s4e_msg.sh done --probe-lock"
case "$crit" in ''|*[!0-9]*) refuse "S4E_PROBE_CRIT_S takes whole seconds" ;; esac
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/done_lock_probe.XXXXXX")" || refuse "mktemp failed"
bg=""; sp=""
cleanup() { [ -n "$sp" ] && kill "$sp" 2>/dev/null; [ -n "$bg" ] && kill "$bg" 2>/dev/null; wait 2>/dev/null; rm -rf "$w"; }
trap cleanup EXIT
t="done-lock-probe-$$"; now="$(date -u +%FT%TZ)"
mkdir -p "$w/claims" "$w/tasks" "$w/$ME/inbox" "$w/probe_peer/inbox"
printf '# plant queue (box-scheduler step 28, CTO-496)\n2\t%s\t%s\tASSIGNED:%s\n' "$t" "$ME" "$ME" > "$w/QUEUE.tsv"
printf '# TASK %s\nGOAL: plant\nDONE-WHEN: sleep %s && test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\nLINKS: minted via mint by %s, %s\n## NEXT\n## QA\n## LEDGER\n' \
    "$t" "$crit" "$ME" "$now" > "$w/tasks/$t.task.md"
printf '%s\nASSIGNED-BY plant %s\nRUNNING\n' "$ME" "$now" > "$w/claims/$t.claim"
bus() { env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 bash "$HERE/s4e_msg.sh" "$@"; }
( while :; do printf '%s %s\n' "$(date +%s%N)" "$(awk '{print $4}' "$w/$ME/.pid" 2>/dev/null)"; sleep 0.1; done ) > "$w/samples" 2>/dev/null &
sp=$!
( bus done "$t" > "$w/done.out" 2>&1 < /dev/null; echo "$?" > "$w/done.rc" ) &
bg=$!
sent=""; n=0
while kill -0 "$bg" 2>/dev/null; do
    if [ -z "$sent" ] && grep -q '^verifying DONE-WHEN' "$w/done.out" 2>/dev/null; then
        sleep 1
        printf 'the step 28 probe: a send while the criterion runs\n' | bus send probe_peer done-lock-probe --stdin > "$w/send.out" 2>&1
        [ -n "$(ls "$w/probe_peer/inbox")" ] && sent=delivered || sent=refused
    fi
    n=$((n+1)); [ "$n" -gt $(( (crit + 600) * 10 )) ] && refuse "the done ran past $((crit + 600)) s"
    sleep 0.1
done
bg=""; kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null; sp=""
rc="$(cat "$w/done.rc" 2>/dev/null)"
[ -n "$sent" ] || { sed 's/^/  | /' "$w/done.out" | tail -15; refuse "the done never reached its criterion (rc ${rc:-?})"; }
{ grep -q '^DONE$' "$w/claims/$t.claim" && grep -qP "^2\t\Q$t\E\t[^\t]*\tDONE$" "$w/QUEUE.tsv"; } \
    || { sed 's/^/  | /' "$w/done.out" | tail -15; refuse "the done did not close the plant row (rc ${rc:-?})"; }
c="$(sed -n 's/.*DONE-WHEN exited 0 in \([0-9]*\)s.*/\1/p' "$w/done.out" | head -1)"
held="$(awk '{ if (NR > 1 && pc == "done") h += $1 - pt; pt = $1; pc = $2 } END { printf "%d", h / 1e9 + 0.5 }' "$w/samples")"
echo "DONE lock_held_s=$held criterion_s=${c:-?} mid_run_send=$sent done_rc=$rc closed=yes"
