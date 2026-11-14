#!/usr/bin/env bash
# util_idle_seat_watch.sh [--once] -- AN IDLE SEAT THAT HOLDS WORK IS NAMED BY A SCRIPT, NOT NOTICED BY THE COO (the coo 2026-11-14 12:5x CST, on
# Lon's word in the coo's window, verbatim: "get these process automated into the shell scripts. quit depending on your feeble mind to do things." and
# "Get the FLEET working please. What is your malfunction?"; MEASURED 12:50: 8 seats sat idle at their prompts, junior_07, 08 and 09 holding claims and
# queued rows). A held Stop would keep a seat working but Claude Code labels it "Stop hook error" (Lon 2026-11-08: "I NEVER want to see \"Stop hook
# error\" ever again."), and no shell can message a running session, so this script finds the idle seats and prints one WAKE line each; the coo's
# Monitor turns each line into a SendMessage.
# IDLE: a worker seat's session (TIERS.tsv role junior, senior, designer or escalation) whose inner claude process has no child process and used under
# 0.5 CPU-s in the last poll, two polls running. WORK: a row CLAIMED, ASSIGNED or QUEUED to its seat tube, else a ready row in its tier's tube.
# OUTPUT: WAKE <NAME> seat=<seat> work=<what> next=<first row or tube>, at most once a seat every S4E_IDLE_REWAKE_S (900) seconds; --once polls twice and exits.
set -u
PO="${S4E_POST:-/home/resources/postoffice}"; TIERS="${S4E_TIERS:-/home/.github/TIERS.tsv}"; POLL="${S4E_IDLE_POLL_S:-60}"; REWAKE="${S4E_IDLE_REWAKE_S:-900}"
declare -A cpu0 idle1 last
ticks() { awk '{print $14 + $15}' "/proc/$1/stat" 2>/dev/null; }
poll() {
    local seat name role tube p kids t d first work
    while IFS=$'\t' read -r seat name _ _ _ _ _ role; do
        case "$role" in junior|senior|designer|escalation) ;; *) continue;; esac
        p="$(pgrep -f "^/home/satirical/.local/bin/claude --name $name( |\$)" | head -1)"; [ -n "$p" ] || continue
        kids="$(pgrep -P "$p" | wc -l)"; t="$(ticks "$p")"; d=$(( ${t:-0} - ${cpu0[$seat]:-${t:-0}} )); cpu0[$seat]="${t:-0}"
        if [ "$kids" -gt 0 ] || [ "$d" -ge 50 ]; then idle1[$seat]=0; continue; fi
        idle1[$seat]=$(( ${idle1[$seat]:-0} + 1 )); [ "${idle1[$seat]}" -ge 2 ] || continue
        [ $(( $(date +%s) - ${last[$seat]:-0} )) -ge "$REWAKE" ] || continue
        first="$(awk -F'\t' -v s="$seat" '$4 == "CLAIMED:" s || $4 == "ASSIGNED:" s || $4 == "QUEUED:seat-" s {print $4 " " $2; exit}' "$PO/QUEUE.tsv")"
        if [ -n "$first" ]; then work="own"; else
            case "$role" in junior) tube=tier-haiku;; senior) tube=tier-sonnet;; *) tube=tier-opus;; esac
            [ "$(awk -F'\t' -v q="QUEUED:$tube" '$4 == q' "$PO/QUEUE.tsv" | wc -l)" -gt 0 ] || continue
            work="tube"; first="$tube"
        fi
        last[$seat]="$(date +%s)"; echo "WAKE $name seat=$seat work=$work next=$first"
    done < <(awk -F'\t' '!/^#/ && $1 != "seat" && NF >= 8' "$TIERS")
}
if [ "${1:-}" = --once ]; then poll > /dev/null; sleep "$POLL"; poll; exit 0; fi
while :; do poll; sleep "$POLL"; done
