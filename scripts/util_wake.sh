#!/usr/bin/env bash
# util_wake.sh -- box-scheduler step 10 (CTO-496): THE WAKE REACHES THE IDLE SESSION BY HOOK, NOT BY A PERSON. The mechanism is s4e_stop_gate.sh behind
# every seat's Stop hook (settings.json -> s4e_banner_cached.sh -> the gate): a seat holding unread mail or a row ASSIGNED or CLAIMED to it cannot go
# idle; the hook blocks the stop with the row and its NEXT and the session continues. The one case left to a session is a seat Lon reset (/clear): it
# has no turn to stop, so one SendMessage starts it, and from then on the hook holds it to its work.
#   util_wake.sh <seat>            what the seat's hook would answer now (dry: PASS, BLOCK or CAP) and whether its Stop hook is wired to the gate
#   util_wake.sh --probe <seat>    prove the route on a plant: WAKE by=hook delivered ... (rc 0), WAKE by=hook RED ... (rc 1), REFUSE (rc 2)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
refuse() { echo "REFUSE(2) [util_wake]: $*"; exit 2; }
root_of() { case "$1" in cto|coo|cfo|cao|cqo|cio) echo "/home/claude_$1";; hq_*) echo "/home/claude_${1#hq_}";; *) echo "";; esac; }
wired() { local r; r="$(root_of "$1")"; [ -n "$r" ] && [ -f "$r/.claude/settings.json" ] || return 1
    python3 - "$r/.claude/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); ok=any('s4e_banner_cached.sh' in h.get('command','') for g in d.get('hooks',{}).get('Stop',[]) for h in g.get('hooks',[]))
sys.exit(0 if ok else 1)
PY
}
if [ "${1:-}" = --probe ]; then
    seat="${2:-}"; [ -n "$seat" ] || refuse "--probe takes a seat"
    [ -f "$HERE/s4e_stop_gate.sh" ] || refuse "no s4e_stop_gate.sh beside util_wake.sh"
    w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_wake_probe.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$w"' EXIT
    mkdir -p "$w/$seat/inbox" "$w/tasks" "$w/claims"; t="wake-plant-$$"; why=""
    printf '# plant queue (box-scheduler step 10, CTO-496)\n2\t%s\t%s\tASSIGNED:%s\n2\twake-plant-other-%s\tplant-other\tASSIGNED:plant-other\n' "$t" "$seat" "$seat" "$$" > "$w/QUEUE.tsv"
    printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nresume at the plant step\n## QA\n## LEDGER\n' "$t" > "$w/tasks/$t.task.md"
    printf 'FROM plant TO %s RE wake-plant-mail\nplant\n' "$seat" > "$w/$seat/inbox/1-plant-wake-plant-mail.msg"
    gate() { printf '{"session_id":"plant","hook_event_name":"Stop","stop_hook_active":false}' | S4E_POST="$w" S4E_STOP_CAP=3 bash "$HERE/s4e_stop_gate.sh" "$S4E" "$seat" "$@" 2>&1; }
    o="$(gate --dry)"; case "$o" in "BLOCK $seat has 1 unread telegram(s) (plant: wake-plant-mail)"*) ;; *) why="$why mail did not block [$o];";; esac
    isblock() { python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("decision")=="block" and sys.argv[1] in d.get("reason","") else 1)' "$1" 2>/dev/null; }
    o="$(gate --dry --json)"; printf '%s' "$o" | isblock unread || why="$why the mail JSON is not a block [$o];"
    rm -f "$w/$seat/inbox/"*.msg
    o="$(gate --dry)"; case "$o" in "BLOCK $seat is stopping while row $t reads ASSIGNED:$seat."*"resume at the plant step"*) ;; *) why="$why the row did not block [$o];";; esac
    o="$(gate --dry --json)"; printf '%s' "$o" | isblock "$t" || why="$why the row JSON is not a block [$o];"
    sed -i "s/\tASSIGNED:$seat\$/\tPARKED-AWAITING:plant-request/" "$w/QUEUE.tsv"
    o="$(gate --dry)"; case "$o" in "PASS "*) ;; *) why="$why a parked row did not pass [$o];";; esac
    o="$(gate --dry --json)"; [ "$o" = "{}" ] || why="$why the pass JSON is not empty [$o];"
    sed -i "s/\tPARKED-AWAITING:plant-request\$/\tCLAIMED:$seat/" "$w/QUEUE.tsv"
    cf="/tmp/s4e/$seat/stop_blocks.$(date +%Y%m%d%H)"; sv=""; [ -f "$cf" ] && { sv="$(mktemp)"; cp "$cf" "$sv"; }
    rm -f "$cf"; for i in 1 2 3; do gate > /dev/null; done
    o="$(gate)"; case "$o" in "CAP 3 continuations this hour"*) ;; *) why="$why the cap did not hold at 3 [$o];";; esac
    rm -f "$cf"; [ -n "$sv" ] && mv "$sv" "$cf"
    if wired "$seat"; then wd="wired=yes"; else wd="wired=no"; why="$why $seat's settings.json Stop hook does not run s4e_banner_cached.sh;"; fi
    [ -z "$why" ] && { echo "WAKE by=hook delivered seat=$seat row=$t $wd: the Stop hook blocks the idle with unread mail first, then with the ASSIGNED or CLAIMED row and its NEXT;" \
        "a parked row passes; the cap holds"; exit 0; }
    echo "WAKE by=hook RED seat=$seat:$why"; exit 1
fi
seat="${1:-}"; [ -n "$seat" ] || refuse "usage: util_wake.sh <seat> | --probe <seat>"
[ -d "/home/resources/postoffice/$seat/inbox" ] || refuse "no mailbox $seat"
o="$(printf '{"hook_event_name":"Stop"}' | bash "$HERE/s4e_stop_gate.sh" "$S4E" "$seat" --dry 2>&1)"
if wired "$seat"; then wd=yes; else wd=no; fi
echo "WAKE seat=$seat hook_wired=$wd gate: $o"
