#!/usr/bin/env bash
# lib_wake.sh -- THE WAKE LINE (the cio, 2026-11-08 10:5x CST; Lon in the cio's window, verbatim: "DESIGN FLOWS DOWN, and PROBLEMS FLOW UP. Design goes
# Fable -> Opus -> Sonnet -> Haiku, and PROBLEMS go Haiku -> Sonnet -> Opus -> Fable. Does anybody NOT KNOW they failed? Does anybody NOT KNOW they have
# finished a design. Does COO not available for EMERGENCIES, NOT babysitting."). A Claude session has no inbound event but a SendMessage from another
# session, and the Stop hook never holds a seat (Lon 08:1x: no "Stop hook error", ever). So THE SEAT THAT MOVES WORK WAKES ITS TAKER: every verb that puts a
# job in a tube (queue, escalate, ask, answer, assign) ends with one WAKE line naming the session to SendMessage, and the sitting rule (skill fleet-bus
# section 7) is that the seat sends it before it does anything else. Nobody waits on the coo; the coo is for emergencies.
#   s4e_wake_hint <tube> <topic> <verb>      prints the WAKE line for the tube: seat-<s> names that seat; tier-<t> and ask-<t> name one live seat of the
#                                            tier (chosen by the topic's checksum over the live set, so two movers spread their wakes) and list the others;
#                                            lon-hold or an empty tube prints nothing. Reads $S4E_TIERS (seat name root model effort color tier role) and
#                                            MODE's FLEET: IDLE EXCEPT line (the live set; no line means every seat of the tier is live).
s4e_wake_live_of_tier() {   # <tier name> -> the live seats of that tier, one per line
    local _tn _fl _ex; case "$1" in fable) _tn=1;; opus) _tn=2;; sonnet) _tn=3;; haiku) _tn=4;; *) return 0;; esac
    _fl="$(grep -m1 '^FLEET: IDLE' "${S4E_POST:-/home/resources/postoffice}/MODE" 2>/dev/null)"
    _ex="$(printf '%s' "$_fl" | sed -n 's/^FLEET: IDLE EXCEPT \([^(]*\).*/\1/p')"
    # ALIVE is a session, not a line: a seat whose s4e-seat-<seat>.scope holds a claude process is live; when no seat scope exists at all (a scratch probe,
    # a box without the slice) the MODE line decides, and with no line every seat of the tier counts.
    local _cg="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/s4e.slice/s4e-seats.slice" _have=0 _s
    [ -d "$_cg" ] && ls -d "$_cg"/s4e-seat-*.scope >/dev/null 2>&1 && _have=1
    local _bosses; _bosses=" $(sed -n 's/^BOSSES:[[:space:]]*//p' "${S4E_POST:-/home/resources/postoffice}/MODE" 2>/dev/null | head -1) "   # a boss (cio coo cto) is woken by tier-fable and ask-fable only: its own tube is its escalation road, not its hold
    awk -F'\t' -v t="$_tn" -v live=" $_ex " -v bosses="$_bosses" -v any="$([ -n "$_fl" ] && echo 0 || echo 1)" '!/^#/ && $7==t && $1!="" { if (t != 1 && index(bosses, " " $1 " ")) next; if (any || index(live, " " $1 " ")) print $1 }' "${S4E_TIERS:?S4E_TIERS unset}" 2>/dev/null | while read -r _s; do
        if [ "$_have" = 1 ]; then
            [ -f "$_cg/s4e-seat-$_s.scope/cgroup.procs" ] || continue
            ps -o comm= -p $(tr '\n' ',' < "$_cg/s4e-seat-$_s.scope/cgroup.procs" | sed 's/,$//') 2>/dev/null | grep -q -x -E 'claude|[0-9.]+' || continue
        fi
        printf '%s\n' "$_s"
    done
}
s4e_wake_hint() {   # <tube> <topic> <verb>
    local _tube="$1" _t="$2" _v="$3" _seats _n _pick _name _others _s _tier
    case "$_tube" in
        seat-*) _seats="${_tube#seat-}";;
        ask-fable) _seats="$(sed -n 's/^ON-CALL:[[:space:]]*//p' "${S4E_POST:-/home/resources/postoffice}/MODE" 2>/dev/null | head -1 | awk '{print $1}')"; [ -n "$_seats" ] || _seats="$(s4e_wake_live_of_tier fable | tr '\n' ' ')";;   # a design ask goes to the seat MODE names ON-CALL (the cto)
        tier-*|ask-*) _tier="${_tube#*-}"; _seats="$(s4e_wake_live_of_tier "$_tier" | tr '\n' ' ')";;
        *) return 0;;
    esac
    set -- $_seats; _n=$#; [ "$_n" -gt 0 ] || { printf 'WAKE: nobody of %s is in the live set (MODE FLEET: IDLE EXCEPT); the job waits in %s until a seat of that tier is spawned or the line is widened.\n' "$_tube" "$_tube"; return 0; }
    _pick=$(( $(printf '%s' "$_t" | cksum | cut -d' ' -f1) % _n + 1 )); eval "_s=\${$_pick}"
    _name="$(awk -F'\t' -v s="$_s" '!/^#/ && $1==s {print $2; exit}' "${S4E_TIERS:?}" 2>/dev/null)"; [ -n "$_name" ] || _name="$_s"
    _others=""; for _x in "$@"; do [ "$_x" = "$_s" ] || _others="$_others $(awk -F'\t' -v s="$_x" '!/^#/ && $1==s {print $2; exit}' "${S4E_TIERS:?}" 2>/dev/null)"; done
    printf 'WAKE: SendMessage to %s now (seat %s; tube %s%s) with this first line: "%s %s: run bash harness/scripts/s4e_msg.sh next, it serves this job"\n' "$_name" "$_s" "$_tube" "${_others:+; also live:$_others}" "$_v" "$_t"
    printf '      DESIGN FLOWS DOWN, PROBLEMS FLOW UP (Lon 2026-11-08): the seat that moves work wakes its taker before doing anything else; a telegram wakes nobody, the coo is for emergencies.\n'
}
