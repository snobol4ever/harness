#!/usr/bin/env bash
# s4e_cycle_cron.sh -- THE MONITOR OF THE TEST CYCLE, RUN BY CRON EVERY MINUTE (Lon 2026-11-08: "write a fucking monitor to start it when it crashed" /
# "Is it not called CRON?"). If s4e_cycle.sh's pid (CYCLE.pid) is dead, start it again in the grader slice and log where it died. Nothing else.
#   crontab line:  * * * * * XDG_RUNTIME_DIR=/run/user/1000 bash /home/harness/scripts/s4e_cycle_cron.sh >> /home/resources/progress/CYCLE.cron.log 2>&1
# THE CYCLE IS STARTED FROM THIS SCRIPT'S OWN FOLDER (the cio 2026-11-14, row harness-one-disk-step-6-the-cutover): /home/harness, the one checkout, since the grader's
# root holds its SCRIP clone alone; S4E_HOME, default /home/claude_grader, is still the root the cycle builds and syncs.
#   bash s4e_cycle_cron.sh --status     one line: RUNNING pid=N lap= idx/total suite cell status since | DEAD last state
#   touch /home/resources/progress/CYCLE.STOP    the monitor starts nothing while this file exists (Lon's hand); rm it to resume
set -u
S4E="${S4E_HOME:-/home/claude_grader}"; HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export S4E_HOME="$S4E"
PROG=/home/resources/progress
PIDF="$PROG/CYCLE.pid"; STATE="$PROG/CYCLE.state"; LOG="$PROG/CYCLE.log"; STOP="$PROG/CYCLE.STOP"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
pid="$(cat "$PIDF" 2>/dev/null)"
alive=0; [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && alive=1
st="$(tr '\n' ' ' < "$STATE" 2>/dev/null)"
if [ "${1:-}" = --status ]; then
    if [ "$alive" = 1 ]; then echo "RUNNING pid=$pid $st"; else echo "DEAD ${st:-no state yet}$([ -e "$STOP" ] && echo ' STOP file present')"; fi
    exit 0
fi
[ "$alive" = 1 ] && exit 0
[ -e "$STOP" ] && exit 0
printf '%s START by cron; last state: %s\n' "$(date -u +%FT%TZ)" "${st:-none}" >> "$LOG"
if systemd-run --user --quiet --scope --slice=s4e-grader.slice --unit="s4e-cycle-$(date +%s)" -- setsid bash "$HERE/s4e_cycle.sh" >> "$PROG/CYCLE.out" 2>&1 < /dev/null & then :; fi
sleep 2
newpid="$(cat "$PIDF" 2>/dev/null)"
if [ -n "$newpid" ] && kill -0 "$newpid" 2>/dev/null; then echo "$(date -u +%FT%TZ) started pid=$newpid"; else
    setsid bash "$HERE/s4e_cycle.sh" >> "$PROG/CYCLE.out" 2>&1 < /dev/null &
    sleep 2; echo "$(date -u +%FT%TZ) started without a scope pid=$(cat "$PIDF" 2>/dev/null)"
fi
