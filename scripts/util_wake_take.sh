#!/usr/bin/env bash
# util_wake_take.sh -- A WAKE IS A TAKE (the weighted door; row harness-a-wake-is-a-take-the-verb-that-prints-a-wake-line-waits-at-the-door; the president's design of
# 2026-11-18, on the chairman's direction and Lon's word of 12:3x CST in the president's window, verbatim: "get control of the machine and the fleet, moron!"; the law is
# skill shared-box section 3, THE DOOR COUNTS WEIGHTS, item 6: no seat is told to hold or to wake in fours, the door spaces the wakes).
# MEASURED the hour it was cut: the president woke thirteen developers inside two minutes and two more at 12:32 CST, CPU pressure some avg10 went from 15 to 40, and a first
# sitting (sync, build, first reproduce) takes no token today. So the verb that prints a WAKE line FOR WORK takes ONE place of the seats' share of the one count before it prints
# it, waiting like any taker, and the place is held for the length of a first sitting, never for the verb's life.
#   util_wake_take.sh take SEAT TOPIC VERB     the mover's half (lib_wake.sh s4e_wake_take calls it): returns when the door has let the wake through, always rc 0; every note on stderr
#   util_wake_take.sh hold SEAT W READY        the detached holder `take` starts under setsid with a handle: it takes the token (S4E_SEAT=wake, a pseudo seat, so a wake never uses the
#                                              woken seat's own cap; s4e_slot_hold run, the very token files util_run_slot.sh takes), writes HELD to READY, keeps the token W seconds,
#                                              appends one line to COSTS.tsv (class wake, key wake:SEAT, the woken seat's scope cpu over the hold) and ends
#   util_wake_take.sh log WORDS...             one ordered line to $S4E_WAKE_LOG (the probe's record of the order of events), nothing when it is unset
#   util_wake_take.sh --probe                  the proof on a scratch pool: util_run_slot.sh --probe-wake-take
# ONE LINE TURNS IT ON AND OFF, wakes=on of CORES.conf (S4E_CORES_CONF names another); with no such line, or any other value, `take` returns at once and prints nothing: the verbs behave as
# they did, byte for byte. The chairman alone turns it on. wake_hold=W of the same file is the seconds a place is held; with none, WAKE_HOLD_DEFAULT below.
# A SEAT AT WORK TAKES NOTHING: a wake of a seat whose session already holds a run or compile token, or whose scope used over a quarter core in a one-second reading, is no wake for work.
# BACKGROUND ONLY THROUGH A HANDLE (skill seat-conduct section 1): the holder has its handle and log under /home/resources/keep/<mover>/bg/ as `util_run_slot.sh --bg` makes them
# (s4e_kill_mine.sh --handle stops it) and removes them at its end.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_slots.sh"
WAKE_HOLD_DEFAULT=75
_wk_conf() { awk -F= -v k="$1" '!/^#/ && $1 == k { v = $2 } END { print v }' "${S4E_CORES_CONF:-$S4E_CORES_CONF_DEFAULT}" 2>/dev/null; }
_wk_on() { [ "$(_wk_conf wakes)" = on ]; }
_wk_hold_s() { local w; w="$(s4e_cores_conf wake_hold)"; printf '%s' "${w:-$WAKE_HOLD_DEFAULT}"; }
_wk_scope() { printf '%s/s4e-seat-%s.scope' "${S4E_SEAT_SCOPES:-/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/s4e.slice/s4e-seats.slice}" "$1"; }
_wk_usage() { awk '$1 == "usage_usec" { print $2 }' "$(_wk_scope "$1")/cpu.stat" 2>/dev/null; }
_wk_log() { [ -n "${S4E_WAKE_LOG:-}" ] || return 0; ( flock -x 9; printf '%s\n' "$*" >&9 ) 9>> "$S4E_WAKE_LOG"; }
_wk_at_work() {   # <seat> -- rc 0 with the reason on stdout when the seat is at work, rc 1 when it is not
    local seat="$1" dir f u0 u1 t0 t1
    for dir in "${S4E_RUN_SLOT_DIR:-/tmp/s4e-run-slots}" "${S4E_CC_SLOT_DIR:-/tmp/s4e-cc-slots}"; do
        for f in "$dir/seat/$seat"/*; do [ -e "$f" ] || continue; flock -n "$f" true 2> /dev/null || { printf 'it holds a run or compile token'; return 0; }; done
    done
    u0="$(_wk_usage "$seat")"; [ -n "$u0" ] || return 1
    t0="$(date +%s.%N)"; sleep 1; u1="$(_wk_usage "$seat")"; t1="$(date +%s.%N)"; [ -n "$u1" ] || return 1
    awk -v a="$u0" -v b="$u1" -v t0="$t0" -v t1="$t1" 'BEGIN { exit !((b - a) / 1e6 / (t1 - t0) > 0.25) }' && { printf 'its scope used over a quarter core in the last second'; return 0; }
    return 1
}
_wk_hold() {   # <seat> <W> <ready>
    local seat="$1" w="$2" ready="$3" rc u0 u1 t0 t1 cost mem
    export S4E_SEAT=wake; unset S4E_CLASS S4E_CORE_HELD S4E_RUN_SLOT_HELD S4E_ADMITTED
    S4E_DOOR_CLASS=wake s4e_slot_hold run "wake:$seat"; rc=$?   # the wake names its key at the door (wake:SEAT, class wake, the ledger line it writes below), as a cell does
    if [ "$rc" = 2 ]; then printf 'REFUSED\n' > "$ready.tmp"; mv "$ready.tmp" "$ready"; rm -f "${ready%.ready}.handle" "${ready%.ready}.log"; return 0; fi
    u0="$(_wk_usage "$seat")"; t0="$(date +%s.%N)"
    _wk_log "HELD $seat"
    printf 'HELD\n' > "$ready.tmp"; mv "$ready.tmp" "$ready"
    sleep "$w"
    u1="$(_wk_usage "$seat")"; t1="$(date +%s.%N)"; mem="$(cat "$(_wk_scope "$seat")/memory.current" 2> /dev/null)"
    cost="${S4E_COSTS:-/home/resources/progress/COSTS.tsv}"
    if [ "$cost" != off ]; then
        [ -s "$cost" ] || printf '# COSTS: wait4 counts the child and the descendants it waited for, never a grandchild it left behind: a daemonised child is undercounted\n# at_utc\tseat\tclass\tkey\twall_s\tcpu_s\tcores\trss_mb\ttmp_mb\trc\n' >> "$cost" 2> /dev/null
        awk -v ts="$(date -u +%FT%TZ)" -v seat="$seat" -v a="${u0:-0}" -v b="${u1:-0}" -v t0="$t0" -v t1="$t1" -v mem="${mem:-0}" 'BEGIN { wall = t1 - t0; cpu = (b - a) / 1e6; if (cpu < 0) cpu = 0; printf "%s\t%s\twake\twake:%s\t%.3f\t%.3f\t%.3f\t%.3f\t0.000\t0\n", ts, seat, seat, wall, cpu, (wall > 0 ? cpu / wall : 0), mem / 1048576 }' >> "$cost" 2> /dev/null
    fi
    _wk_log "RELEASED $seat"
    rm -f "${ready%.ready}.handle" "${ready%.ready}.log"
    return 0
}
_wk_take() {   # <seat> <topic> <verb>
    local seat="$1" topic="$2" verb="$3" w why id keep ready pid t0 shown=0 mover what
    _wk_on || return 0
    if why="$(_wk_at_work "$seat")"; then echo "wake: $seat is at work ($why): no place taken for the $verb of $topic" >&2; _wk_log "WORK $seat"; return 0; fi
    w="$(_wk_hold_s)"; mover="$(s4e_slot_seat)"; keep="${S4E_KEEP:-/home/resources/keep}/$mover/bg"
    mkdir -p "$keep" 2> /dev/null || { echo "wake: cannot make $keep: no place taken for $seat" >&2; return 0; }
    id="wake-$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"; ready="$keep/$id.ready"
    S4E_BG_HANDLE="$id" setsid bash "$HERE/util_wake_take.sh" hold "$seat" "$w" "$ready" 7>&- 8>&- 9>&- > "$keep/$id.log" 2>&1 < /dev/null & pid=$!
    printf 'pid=%s seat=%s started=%s cwd=%s cmd=%s\n' "$pid" "$mover" "$(date -u +%FT%TZ)" "$PWD" "util_wake_take.sh hold $seat ${w}s (the place of a wake for $topic)" > "$keep/$id.handle"
    t0="$(date +%s)"
    while [ ! -s "$ready" ]; do
        kill -0 "$pid" 2> /dev/null || break
        if [ "$shown" = 0 ] && [ $(( $(date +%s) - t0 )) -ge 1 ]; then echo "wake: the $verb of $topic for $seat WAITS at the door for a place of the seats' share; its WAKE line is printed when the place is taken" >&2; shown=1; fi
        sleep 0.1
    done
    what="$(cat "$ready" 2> /dev/null)"; rm -f "$ready"
    case "$what" in
        HELD) echo "wake: a place is taken for $seat ($(( $(date +%s) - t0 )) s at the door, held ${w} s)" >&2;;
        REFUSED) echo "wake: no place for $seat within the door's bound: the WAKE line follows all the same, the wait is in SLOT_WAITS.tsv" >&2;;
        *) echo "wake: the holder for $seat ended before it held a place: the WAKE line follows" >&2;;
    esac
    return 0
}
_wk_probe() {
    local T here i n why="" busy_pid
    here="$HERE"; T="$(mktemp -d "/tmp/s4e/$(s4e_slot_seat)/wake-probe.XXXXXX" 2> /dev/null || mktemp -d)"; mkdir -p "$T/scopes" "$T/keep"
    printf 'cores=4\ngrader=1\nseats=3\nseat=3\nwakes=on\nwake_hold=5\nwait=120\n' > "$T/on.conf"
    printf 'cores=4\ngrader=1\nseats=3\nseat=3\nwake_hold=5\nwait=120\n' > "$T/none.conf"
    printf 'cores=4\ngrader=1\nseats=3\nseat=3\nwakes=off\nwake_hold=5\nwait=120\n' > "$T/off.conf"
    local -a E=(env -u S4E_CORE_HELD -u S4E_RUN_SLOT_HELD -u S4E_ADMITTED -u S4E_CLASS S4E_RUN_SLOT_DIR="$T/run" S4E_CC_SLOT_DIR="$T/cc" S4E_SLOT_WAITS=/dev/null S4E_KEEP="$T/keep" S4E_COSTS="$T/COSTS.tsv" S4E_SEAT_SCOPES="$T/scopes" S4E_WAKE_LOG="$T/log" S4E_SEAT=probe_mover)
    taker() { local conf="$1" s="$2"; "${E[@]}" S4E_CORES_CONF="$T/$conf.conf" bash "$here/util_wake_take.sh" take "$s" topic assign 2> "$T/err.$s"; "${E[@]}" bash "$here/util_wake_take.sh" log PRINT "$s"; }
    quiet() { n=0; while [ "$(grep -c '^HELD' "$T/log")" != "$(grep -c '^RELEASED' "$T/log")" ] && [ "$n" -lt 1200 ]; do sleep 0.2; n=$((n + 1)); done; }
    : > "$T/log"
    for i in $(seq 1 16); do taker on "w$i" & done; wait
    why="$(python3 -I - "$T/log" <<'PY'
import sys
held, out, mx, bad = set(), 0, 0, []
printed = 0
for ln in open(sys.argv[1]).read().split("\n"):
    w = ln.split()
    if not w: continue
    if w[0] == "HELD": held.add(w[1]); out += 1; mx = max(mx, out)
    elif w[0] == "RELEASED": out -= 1
    elif w[0] == "PRINT":
        printed += 1
        if w[1] not in held: bad.append(w[1])
print(("%d printed, at most %d places held at once, %d printed before their place was held" % (printed, mx, len(bad))) + ("" if printed == 16 and mx <= 3 and not bad else "|RED"))
PY
)"
    case "$why" in *"|RED") why="arm 1: sixteen wakes asked at once with seats=3: ${why%|RED};";; *) echo "wake probe arm 1: $why" >&2; why="";; esac
    n="$(grep -l "WAITS" "$T"/err.w* 2> /dev/null | wc -l)"
    [ "$n" -ge 13 ] || why="$why arm 1: only $n of the 13 wakes that had to wait said so on stderr;"
    quiet; : > "$T/log"; rm -rf "$T/keep"; mkdir -p "$T/keep"
    for i in $(seq 1 16); do taker none "n$i" & done; for i in $(seq 1 16); do taker off "f$i" & done; wait
    n="$(grep -c '^PRINT' "$T/log")"; [ "$n" = 32 ] && ! grep -q '^HELD' "$T/log" || why="$why arm 2: with no wakes line and with wakes=off all 32 must print at once and hold nothing (printed $n, HELD lines $(grep -c '^HELD' "$T/log"));"
    [ -z "$(ls -A "$T/keep" 2> /dev/null)" ] && ! cat "$T"/err.n* "$T"/err.f* 2> /dev/null | grep -q . || why="$why arm 2: a wake with the line off left a handle or wrote on stderr;"
    : > "$T/log"; mkdir -p "$T/run/seat/busy"
    local -a H=()
    for i in 1 2 3; do "${E[@]}" S4E_CORES_CONF="$T/on.conf" S4E_SEAT="h$i" bash "$here/util_run_slot.sh" sleep 300 > /dev/null 2>&1 & H+=("$!"); done
    held() { n=0; for i in 0 1 2; do [ -e "$T/run/slot$i" ] && ! flock -n "$T/run/slot$i" true 2> /dev/null && n=$((n + 1)); done; printf '%s' "$n"; }
    i=0; while [ "$(held)" != 3 ] && [ "$i" -lt 300 ]; do sleep 0.1; i=$((i + 1)); done
    [ "$(held)" = 3 ] || why="$why arm 3: three long takers did not fill the door (held $(held));"
    flock "$T/run/seat/busy/0" sleep 300 & busy_pid=$!
    sleep 0.3
    timeout 60 bash -c "$(declare -f taker); T='$T'; here='$here'; E=(${E[*]}); taker on busy" > /dev/null 2>&1
    ( "${E[@]}" S4E_CORES_CONF="$T/on.conf" bash -c ". '$here/lib_wake.sh'; s4e_wake_hint seat-other topic assign" > "$T/hint.other" 2> "$T/err.other"; "${E[@]}" bash "$here/util_wake_take.sh" log PRINT other ) & other_pid=$!
    sleep 3
    "${E[@]}" bash "$here/util_wake_take.sh" log PROBE-RELEASE; kill "${H[0]}" 2> /dev/null
    wait "$other_pid" 2> /dev/null
    kill "${H[1]}" "${H[2]}" "$busy_pid" 2> /dev/null; wait 2> /dev/null
    why="$why$(python3 -I - "$T/log" <<'PY'
import sys
order = [l.split() for l in open(sys.argv[1]).read().split("\n") if l.split()]
def at(kind, who):
    for i, w in enumerate(order):
        if w[0] == kind and w[1] == who: return i
    return None
rel = next((i for i, w in enumerate(order) if w[0] == "PROBE-RELEASE"), None)
pb, po = at("PRINT", "busy"), at("PRINT", "other")
bad = []
if pb is None or rel is None or pb > rel: bad.append("a wake of a seat at work did not print while the door was full")
if po is None or rel is None or po < rel: bad.append("a wake of an idle seat printed while the door was full, before a place was released")
if at("HELD", "busy") is not None: bad.append("a seat at work took a place")
if at("HELD", "other") is None: bad.append("the wake of the idle seat took no place after the release")
print((" arm 3: " + "; ".join(bad) + ";") if bad else "")
PY
)"
    grep -q '^WAKE:' "$T/hint.other" || why="$why arm 3: s4e_wake_hint printed no WAKE line after the door let it through;"
    quiet
    n="$(awk -F'\t' '!/^#/ && $3 == "wake" && $4 ~ /^wake:/ && NF == 10' "$T/COSTS.tsv" 2> /dev/null | wc -l)"
    [ "$n" -ge 17 ] || why="$why arm 4: the COSTS ledger holds $n wake lines of its ten columns, 17 places were held;"
    quiet; : > "$T/log"; rm -rf "$T/po"; mkdir -p "$T/po/mover"
    local -a H6=()
    for i in 1 2 3; do "${E[@]}" S4E_CORES_CONF="$T/on.conf" S4E_SEAT="g$i" bash "$here/util_run_slot.sh" sleep 300 > /dev/null 2>&1 & H6+=("$!"); done
    i=0; while [ "$(held)" != 3 ] && [ "$i" -lt 300 ]; do sleep 0.1; i=$((i + 1)); done
    cat > "$T/mover.sh" <<MV
. "$here/lib_wake.sh"
PO="$T/po"; ME=mover
s4e_pid_unhold() { flock -u 9; { exec 9>&-; } 2> /dev/null; _S4E_FD_OWNER=""; }
s4e_pid_retake() { exec 9<>"\$PO/\$ME/.pid"; flock -w 60 9; _S4E_FD_OWNER=\$\$; }
exec 9<>"\$PO/\$ME/.pid"; flock 9; _S4E_FD_OWNER=\$\$
exec 8>>"\$PO/.queue.flock"; flock 8; S4E_QFLOCK_HELD=1
s4e_wake_hint seat-mv topic assign > "$T/hint.mv"
exec 3>>"\$PO/mover/.pid"; flock -n 3 && echo IDENTITY-NOT-TAKEN-AGAIN >> "$T/mv.state"
exec 4>>"\$PO/.queue.flock"; flock -n 4 && echo QUEUE-FLOCK-NOT-TAKEN-AGAIN >> "$T/mv.state"
echo DONE >> "$T/mv.state"
MV
    : > "$T/mv.state"; : > "$T/hint.mv"
    "${E[@]}" S4E_CORES_CONF="$T/on.conf" S4E_SEAT=probe_mover bash "$T/mover.sh" 2> "$T/err.mv" & mv_pid=$!
    i=0; while ! grep -q WAITS "$T/err.mv" 2> /dev/null && [ "$i" -lt 300 ]; do sleep 0.1; i=$((i + 1)); done
    if flock -n "$T/po/mover/.pid" true 2> /dev/null && flock -n "$T/po/.queue.flock" true 2> /dev/null && [ ! -s "$T/hint.mv" ] && [ -z "$(cat "$T/mv.state")" ]; then :; else why="$why arm 6: while the wake waited at the door the identity or the queue flock was still held (or the wake had not waited);"; fi
    kill "${H6[0]}" 2> /dev/null; wait "$mv_pid" 2> /dev/null
    kill "${H6[1]}" "${H6[2]}" 2> /dev/null; wait 2> /dev/null
    grep -q '^WAKE:' "$T/hint.mv" && grep -qx DONE "$T/mv.state" && ! grep -q "NOT-TAKEN-AGAIN" "$T/mv.state" || why="$why arm 6: after the wait the wake line did not print or the verb did not hold the identity and the queue flock again ($(tr '\n' ' ' < "$T/mv.state"));"
    ( . "$here/lib_wake.sh"; for c in none off; do S4E_CORES_CONF="$T/$c.conf" S4E_KEEP="$T/keep2" S4E_SEAT=probe_mover s4e_wake_hint seat-zzz topic assign > "$T/hint.$c" 2> "$T/herr.$c"; done )
    cmp -s "$T/hint.none" "$T/hint.off" && [ -s "$T/hint.none" ] && [ ! -s "$T/herr.none" ] && [ ! -s "$T/herr.off" ] && [ ! -e "$T/keep2" ] || why="$why arm 5: s4e_wake_hint with the line off differs from the line absent, wrote on stderr or made a handle;"
    if [ -z "$why" ]; then rm -rf "$T"; echo "WAKE-TAKE probe ok (sixteen wakes at seats=3 hold at most three places and each waiter says it waits; no line or wakes=off prints all at once and holds nothing; a seat at work takes none and an idle one waits for a release; every held place writes its ledger line; the identity and the queue flock are free while a wake waits and held again after; s4e_wake_hint with the line off is what it was)"; return 0; fi
    echo "WAKE-TAKE probe RED:$why (scratch kept in $T)"; return 1
}
case "${1:-}" in
    take) shift; _wk_take "$@"; exit 0;;
    hold) shift; _wk_hold "$@"; exit 0;;
    log) shift; _wk_log "$@"; exit 0;;
    --probe) _wk_probe; exit $?;;
    *) echo "usage: util_wake_take.sh take SEAT TOPIC VERB | hold SEAT W READY | log WORDS... | --probe" >&2; exit 2;;
esac
