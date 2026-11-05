#!/usr/bin/env bash
# util_queue.sh -- THE QUEUE DAEMON'S STATUS AND PROBES (DESIGN-PLAN fleet-queue step 1 and 5, the cio 2026-11-05; skill fleet-bus section 8).
#   util_queue.sh status            the one status line (python3 util_queue.py status); rc 0 only with the client present and the binlog on
#   util_queue.sh tubes             one line per tube
#   util_queue.sh stats TUBE        one line: TUBE <name> ready= reserved= delayed= buried= total= watching= (zeros for a tube with no jobs)
#   util_queue.sh --probe-lease     step 5's probe: plants a job with a 2 s TTR, reserves it from a process that dies, shows it back in its tube,
#                                   the claim cleared and the ledger line written (built with step 5; refuses rc 2 until then)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
    status|tubes) exec python3 "$HERE/util_queue.py" "$1" ;;
    stats) exec python3 "$HERE/util_queue.py" stats-tube "${2:?util_queue.sh stats TUBE}" ;;
    --probe-lease)   # fleet-queue step 5: a holder whose session is gone releases the job within its interval; the tick's expire clears the claim and ledgers it
        PO="${S4E_POST:-/home/resources/postoffice}"; S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
        w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_lease_probe.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
        mkdir -p "$w/claims" "$w/tasks" "$w/cio/inbox"; cp "$PO/MODE" "$w/MODE"; t="lease-plant-$$"; tube="probe-lease-$$"; now="$(date -u +%FT%TZ)"
        printf '2\t%s\tcio\tFREE\n' "$t" > "$w/QUEUE.tsv"
        printf '# TASK %s\nGOAL: plant\nDONE-WHEN: true\nPREMISE-WHEN: true\nLINKS: minted via mint by cio, %s\n## RESUME\nRESUME tree=/tmp command=true state=plant log=/dev/null %s\n## NEXT\nplant\n## QA\n## LEDGER\n' "$t" "$now" "$now" > "$w/tasks/$t.task.md"
        jid="$(python3 "$HERE/util_queue.py" put "$tube" "$t" --pri 1000 --ttr 5)" || { echo "REFUSE(2): put failed"; rm -rf "$w"; exit 2; }
        res="$(python3 "$HERE/util_queue.py" reserve-hold "$tube" --seat probe-seat --session "NO-SUCH-SESSION-$$" --claim-dir "$w/claims" --baton-dir "$w/tasks" --timeout 0)" || { echo "REFUSE(2): reserve failed"; rm -rf "$w"; exit 2; }
        printf 'probe-seat\nRESERVED job=%s tube=%s %s\n' "$jid" "$tube" "$now" > "$w/claims/$t.claim"
        st0="$(python3 "$HERE/util_queue.py" stats-job "$jid" | cut -f3)"; sleep 4
        st1="$(python3 "$HERE/util_queue.py" stats-job "$jid" | cut -f3)"; expired=0; [ "$st0" = reserved ] && [ "$st1" = ready ] && expired=1
        out="$(S4E_POST="$w" S4E_SEAT=cio S4E_NO_BANNER=1 bash "$S4E/harness/scripts/s4e_msg.sh" expire "$t" 2>&1)"
        cleared=0; [ -f "$w/claims/$t.claim" ] || cleared=1; ledger=0; grep -q '^- .*LEASE expired holder=probe-seat' "$w/tasks/$t.task.md" && ledger=1
        resume=0; printf '%s\n' "$out" | grep -q 'resume_line=1' && resume=1; queued=0; grep -qP "\t$t\tcio\tQUEUED:$tube\$" "$w/QUEUE.tsv" && queued=1
        python3 "$HERE/util_queue.py" delete "$jid" >/dev/null 2>&1; rm -rf "$w"
        printf 'LEASE ttr_s=5 held_by=holder expired=%s returned=%s claim_cleared=%s ledger=%s resume_line=%s queued=%s\n' "$expired" "$expired" "$cleared" "$ledger" "$resume" "$queued"
        [ "$expired" = 1 ] && [ "$cleared" = 1 ] && [ "$ledger" = 1 ] && [ "$resume" = 1 ]; exit $? ;;
    *) echo "usage: util_queue.sh status | tubes | --probe-lease"; exit 2 ;;
esac
