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
if [ "${1:-}" = --probe-queue ]; then   # fleet-queue step 11's probe on a scratch postoffice: reserved claim, a ready job in the seat tube, mail, nothing
    HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_gate_probe.XXXXXX")"; ps="gate-probe-$$"
    mkdir -p "$w/claims" "$w/tasks" "$w/$ps/inbox"; cp "${S4E_POST:-/home/resources/postoffice}/MODE" "$w/MODE"; sed -i '/^FLEET: IDLE/d' "$w/MODE"
    g() { S4E_POST="$w" bash "$0" "$w" "$ps" --dry | cut -d' ' -f1; }
    printf '2\tgate-plant\t%s\tCLAIMED:%s\n' "$ps" "$ps" > "$w/QUEUE.tsv"; printf '# TASK gate-plant\n## NEXT\nplant\n## QA\n## LEDGER\n' > "$w/tasks/gate-plant.task.md"
    printf '%s\nRESERVED job=0 tube=seat-%s now\n' "$ps" "$ps" > "$w/claims/gate-plant.claim"; r1="$(g)"
    : > "$w/QUEUE.tsv"; rm -f "$w/claims/gate-plant.claim"; jid="$(python3 "$HERE/util_queue.py" put "seat-$ps" gate-plant --pri 100 --ttr 30)"; r2="$(g)"; python3 "$HERE/util_queue.py" delete "$jid" >/dev/null 2>&1
    printf 'FROM x TO %s RE plant\nplant\n' "$ps" > "$w/$ps/inbox/1-x-plant.msg"; r3="$(g)"; rm -f "$w/$ps/inbox/1-x-plant.msg"; r4="$(g)"
    printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\n%s\tP\t%s\tclaude-haiku-5-5\txhigh\tcyan\t4\tworker\n' "$ps" "$w" > "$w/TIERS.tsv"
    gt() { S4E_POST="$w" S4E_TIERS="$w/TIERS.tsv" S4E_TIER_TUBE_PREFIX="$ps-tier-" bash "$0" "$w" "$ps" --dry | cut -d' ' -f1; }
    jid="$(python3 "$HERE/util_queue.py" put "$ps-tier-haiku" gate-plant --pri 100 --ttr 30)"; r5="$(gt)"; python3 "$HERE/util_queue.py" delete "$jid" >/dev/null 2>&1; r6="$(gt)"
    r6w="$(S4E_POST="$w" S4E_TIERS="$w/TIERS.tsv" S4E_TIER_TUBE_PREFIX="$ps-tier-" bash "$0" "$w" "$ps" --dry | grep -c 'next --wait 240')"
    rm -rf "$w"; printf 'GATE reserved=%s seat_tube_ready=%s mail=%s idle=%s tier_tube_ready=%s tier_tube_empty=%s longpoll=%s\n' "$r1" "$r2" "$r3" "$r4" "$r5" "$r6" "$r6w"
    [ "$r1" = BLOCK ] && [ "$r2" = BLOCK ] && [ "$r3" = BLOCK ] && [ "$r4" = PASS ] && [ "$r5" = BLOCK ] && [ "$r6" = BLOCK ] && [ "$r6w" = 1 ]; exit $?
fi
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
# THE BOSSES ARE NEVER HELD (Lon 2026-11-08 07:4x in the coo's window, verbatim: "I see a Stop hook error. Fix that." / "I do not want to see the words
# "Stop hook error" EVER again."): every BLOCK this gate answers shows Lon those words, and a boss's wake is its own loop (the coo's /loop and Monitor) or a
# pointer (the cio and the cto sleep until a command or a design question reaches them). A seat MODE BOSSES names passes at once; the banner still prints.
bosses="$(sed -n 's/^BOSSES: *//p' "$PO/MODE" 2>/dev/null | head -1)"
case " $bosses " in *" $seat "*) emit PASS "$seat is a boss (MODE BOSSES: $bosses): never held at its Stop; its own loop or a pointer wakes it"; exit 0;; esac
fl="$(grep -m1 '^FLEET: IDLE' "$PO/MODE" 2>/dev/null)"
if [ -n "$fl" ]; then
    ex="$(printf '%s' "$fl" | sed -n 's/^FLEET: IDLE EXCEPT \([^(]*\).*/\1/p')"
    case " $ex " in *" $seat "*) ;; *) emit PASS "MODE carries FLEET: IDLE (Lon 2026-11-05: the fleet is brought to idle): a seat parks its row and stops; the gate holds nobody but the seats named after EXCEPT (${ex:-none}) until the line is removed"; exit 0;; esac
fi
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
    else
        # fleet-queue step 11 (the cio 2026-11-05): a job ready in the seat's own tube is work assigned to it; the gate holds the seat until next reserves it
        qr="$(python3 "$(dirname "$0")/util_queue.py" stats-tube "seat-$seat" 2>/dev/null | sed -n 's/^TUBE [^ ]* ready=\([0-9]*\).*/\1/p')"; qr="${qr:-0}"
        if [ "$qr" -gt 0 ]; then
            reason="$seat is stopping while $qr job(s) wait in its queue tube seat-$seat (a directed assign). Run bash harness/scripts/s4e_msg.sh next: it reserves the job and serves its baton."
            what="seat_tube=$qr"
        else
            # fleet-control step 11 (the cio, 2026-11-07 13:5x; Lon: "get this fleet humming"; MEASURED 13:55: five of eight live workers idle with fifteen jobs ready in
            # tier-haiku, each having stopped after its last done or escalation): a live-set seat with no claim and no seat-tube job is held while its TIER tube
            # (TIERS.tsv column 7: 2 opus, 3 sonnet, 4 haiku; the fable seats are never held, their loop is Lon's) has a ready job. THE LADDER: a worker works
            # only what the queue serves it, so an idle worker beside ready work is the failure this arm removes. S4E_TIER_TUBE_PREFIX lets the probe use a scratch tube.
            tiers="${S4E_TIERS:-$root/.github/TIERS.tsv}"; tn="$(awk -F'\t' -v s="$seat" '!/^#/ && $1==s {print $7; exit}' "$tiers" 2>/dev/null)"
            case "$tn" in 2|opus) tier=opus;; 3|sonnet) tier=sonnet;; 4|haiku) tier=haiku;; *) tier="";; esac
            if [ -n "$tier" ]; then
                tt="${S4E_TIER_TUBE_PREFIX:-tier-}$tier"
                tr="$(python3 "$(dirname "$0")/util_queue.py" stats-tube "$tt" 2>/dev/null | sed -n 's/^TUBE [^ ]* ready=\([0-9]*\).*/\1/p')"; tr="${tr:-0}"
                if [ "$tr" -gt 0 ]; then
                    reason="$seat is stopping idle while $tr job(s) wait ready in its tier tube $tt (THE LADDER, skill fleet-bus section 1: a seat works what the queue serves it; an idle seat beside ready work is the failure this arm removes). Run bash harness/scripts/s4e_msg.sh next: it reserves the first job and serves its baton; one honest try, then escalate with the measurement."
                    what="tier_tube=$tr"
                else
                    # fleet-control step 12 (the cio, 2026-11-07 14:5x; Lon: "The fleet system does not need the CIO's constant attention"): an idle session never
                    # re-fires its Stop hook, so a seat that passed here with an empty tube stayed idle until a message woke it (eight idle workers at 14:4x with four
                    # jobs ready a minute later). The gate now sends the seat back to LONG-POLL the tube: next --wait 240 holds the reserve open four minutes (under
                    # the shell tool's five-minute budget) and serves the first job that lands; nothing landed, the seat stops again and is sent back again. The poll
                    # is not a continuation against S4E_STOP_CAP (what=longpoll below): it is the seat waiting, not working.
                    reason="$seat has no row, no mail and nothing ready in $tt: wait on the tube, do not idle. Run bash harness/scripts/s4e_msg.sh next --wait 240 (it holds the reserve open 240 s and serves the first job that lands; on nothing ready, stop again and this gate sends you back)."
                    what="longpoll"
                fi
            fi
        fi
    fi
fi
[ -z "$reason" ] && { emit PASS "no unread mail and no row ASSIGNED or CLAIMED to $seat"; exit 0; }
[ "$n" -ge "$cap" ] && [ "$what" != longpoll ] && { emit CAP "$n continuations this hour (S4E_STOP_CAP $cap) -- $reason"; exit 0; }
[ "$dry" = 1 ] || [ "$what" = longpoll ] || printf '%s %s\n' "$(date -u +%FT%TZ)" "$what" >> "$cf"   # a long poll is a wait, not a continuation: it never counts against the cap
emit BLOCK "$reason"
