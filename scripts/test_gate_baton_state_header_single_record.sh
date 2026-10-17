#!/usr/bin/env bash
# test_gate_baton_state_header_single_record.sh — DONE-WHEN negative arm for row baton-state-header-single-record.
#
# ⛔⭐ WHY: 81% of baton `state:` headers disagreed with QUEUE.tsv (hq_B: agree=7, DISAGREE=29 over non-FREE rows
# with a baton). park/done/unclaim/assign write the QUEUE column and append a ledger line but never rewrite the
# baton's line 1 — while `next` tells every seat "THE BATON IS THE TASK FILE", whose first line is then wrong 4
# times in 5. ceo RULED at mint: DELETE the owner/state fields from baton line 1 rather than sync them. A state
# that exists in ONE file cannot go stale in two; QUEUE.tsv is the single record and the picker printout already
# carries owner/state on every serve.
# ⭐ THIS GATE IS THE ARM THAT KEEPS IT DELETED. Sweeping once without it just gets re-dirtied by the next mint —
# batons are hand-written, so nothing mechanical stops the old shape coming back.
PO="${S4E_PO:-/home/resources/postoffice}"
T="$PO/tasks"; Q="$PO/QUEUE.tsv"
[ -d "$T" ] || { echo "REFUSE (rc=2): no tasks dir at $T -- cannot measure, not a pass"; exit 2; }
[ -f "$Q" ] || { echo "REFUSE (rc=2): no QUEUE.tsv at $Q -- cannot measure, not a pass"; exit 2; }

shopt -s nullglob
batons=("$T"/*.task.md)
[ "${#batons[@]}" -gt 0 ] || { echo "REFUSE (rc=2): no *.task.md under $T -- cannot measure, not a pass"; exit 2; }

# LIVE = a baton whose topic appears in QUEUE.tsv col2. A retired baton is not this gate's business.
live=0; bad=0; noid=0
for f in "${batons[@]}"; do
    topic="$(basename "$f" .task.md)"
    grep -qP "^[0-9]+\t\Q$topic\E\t" "$Q" 2>/dev/null || continue
    live=$((live+1))
    l1="$(head -1 "$f")"
    case "$l1" in "# TASK $topic"*) ;; *) echo "  ⛔ $topic: line 1 lost its '# TASK <topic>' identity: $l1"; noid=$((noid+1));; esac
    if printf '%s' "$l1" | grep -qE '(^|[[:space:]·|])(state|owner):'; then
        echo "  ⛔ $topic: line 1 still carries owner:/state: -- QUEUE.tsv is the single record"
        echo "       $l1"
        bad=$((bad+1))
    fi
done
echo ""
echo "live batons (topic present in QUEUE.tsv): $live   with owner:/state: on line 1: $bad   missing # TASK identity: $noid"
if [ "$live" -eq 0 ]; then echo "REFUSE (rc=2): zero live batons matched QUEUE.tsv -- the scan found nothing to check, which is not a pass"; exit 2; fi
if [ "$bad" -eq 0 ] && [ "$noid" -eq 0 ]; then echo "GATE OK: every live baton's line 1 is a bare '# TASK <topic>' identity line"; exit 0; fi
echo "GATE FAILED -- owner/state must live in QUEUE.tsv only; the picker printout already tells each seat on serve."
exit 1
