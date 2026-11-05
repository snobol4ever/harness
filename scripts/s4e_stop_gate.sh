#!/usr/bin/env bash
# s4e_stop_gate.sh -- THE WAKE BY HOOK (DESIGN-PLAN box-scheduler step 10, CTO-496; Lon 2026-11-04: "you must automate that check" / "It appears that
# you have NOT automated the fleet system and are depending on seats actually thinking and doing. Wrong!"). Every seat's Stop hook asks this gate
# whether the seat may go idle. It may not while its inbox holds unread mail or QUEUE.tsv holds a row ASSIGNED or CLAIMED to it: the gate answers
# BLOCK with the mail or the row and its baton NEXT, the hook returns {"decision":"block"} and the session continues on its own work. No person and no
# other session wakes it. A seat that must wait parks the row first (PARKED-AWAITING:<id> or BLOCKED-ON:<topic>), and a parked row passes.
#   s4e_stop_gate.sh <root> <seat> [--dry] [--json]    reads the Stop hook's JSON on stdin when one is piped; --dry counts no continuation
# Prints one line: BLOCK <reason> | PASS <why> | CAP <n> <reason>; with --json the object the Stop hook returns ({"decision":"block","reason":...} or {}).
# S4E_STOP_CAP continuations per seat per hour (default 12; the file /tmp/s4e/<seat>/stop_blocks.<hour> counts them); past the cap the seat stops.
set -u
root="${1:?root}"; seat="${2:?seat}"; shift 2; dry=0; json=0
for a in "$@"; do case "$a" in --dry) dry=1;; --json) json=1;; esac; done
PO="${S4E_POST:-/home/resources/postoffice}"
in=""; [ -t 0 ] || in="$(timeout 2 cat 2>/dev/null)"
cap="${S4E_STOP_CAP:-12}"; case "$cap" in ''|*[!0-9]*) cap=12;; esac
hour="$(date +%Y%m%d%H)"; cf="/tmp/s4e/$seat/stop_blocks.$hour"; mkdir -p "/tmp/s4e/$seat" 2>/dev/null
n=0; [ -f "$cf" ] && n="$(wc -l < "$cf")"
emit() { local v="$1"; shift; local r="$*"
    if [ "$json" = 1 ]; then
        if [ "$v" = BLOCK ]; then printf '%s' "$r" | python3 -c 'import json,sys; print(json.dumps({"decision":"block","reason":sys.stdin.read()}))'; else echo '{}'; fi
    else echo "$v $r"; fi; }
reason=""; what=""
if grep -q '^FLEET: IDLE' "$PO/MODE" 2>/dev/null; then emit PASS "MODE carries FLEET: IDLE (Lon 2026-11-05: the fleet is brought to idle): a seat parks its row and stops; the gate holds nobody until the line is removed"; exit 0; fi
d="$PO/$seat/inbox"; u=$(ls "$d"/*.msg 2>/dev/null | wc -l)
if [ "$u" -gt 0 ]; then
    heads="$(for f in "$d"/*.msg; do head -1 "$f" | sed 's/^FROM \([^ ]*\) TO [^ ]* RE /\1: /'; done | head -3 | paste -sd';' | cut -c1-240)"
    reason="$seat has $u unread telegram(s) ($heads). THE LOOP step 1 before stopping: bash harness/scripts/s4e_msg.sh check, act or reply, then clear; an empty inbox is the acknowledgement."
    what="mail=$u"
else
    mrow="$(grep -P "\tMEASURING:\Q$seat\E:[0-9]+\$" "$PO/QUEUE.tsv" 2>/dev/null | sort -n | head -1)"; mpid="${mrow##*:}"
    row="$(grep -P "\t(ASSIGNED|CLAIMED):\Q$seat\E\$" "$PO/QUEUE.tsv" 2>/dev/null | sort -n | head -1)"
    if [ -n "$mrow" ] && [ ! -d "/proc/$mpid" ]; then
        t="$(printf '%s' "$mrow" | cut -f2)"
        reason="$seat is stopping while row $t reads MEASURING:$seat:$mpid and pid $mpid is gone: the measurement ended, so the row is yours to work again"
        reason="$reason (read its log, then done, or park it on a real blocker)."
        what="measured=$t"
    elif [ -n "$row" ]; then
        t="$(printf '%s' "$row" | cut -f2)"; st="$(printf '%s' "$row" | cut -f4)"
        nx="$(awk '/^## NEXT/{f=1;next} /^## /{f=0} f && NF' "$PO/tasks/$t.task.md" 2>/dev/null | head -1 | cut -c1-300)"
        reason="$seat is stopping while row $t reads $st. Work it now (bash harness/scripts/s4e_msg.sh next; its baton NEXT: ${nx:-empty});"
        reason="$reason close it by done when its DONE-WHEN is green; or park it first (park $t PARKED-AWAITING:<request-id> | BLOCKED-ON:<topic>)."
        reason="$reason A stop with a live row leaves the row to a wake by hand, which is the failure this hook removes."
        what="row=$t"
    fi
fi
[ -z "$reason" ] && { emit PASS "no unread mail and no row ASSIGNED or CLAIMED to $seat"; exit 0; }
[ "$n" -ge "$cap" ] && { emit CAP "$n continuations this hour (S4E_STOP_CAP $cap) -- $reason"; exit 0; }
[ "$dry" = 1 ] || printf '%s %s\n' "$(date -u +%FT%TZ)" "$what" >> "$cf"
emit BLOCK "$reason"
