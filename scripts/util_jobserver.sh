#!/usr/bin/env bash
# util_jobserver.sh -- THE ONE BOX-WIDE COMPILE BUDGET: a GNU make jobserver every seat's build joins (DESIGN-PLAN box-scheduler step 1,
# the cto 2026-11-04, CTO-496; Lon, verbatim: "There has been talk, and only talk, about using industry recognized ways of doing make and
# build load balancing and management." / "So get to it.").
# THE MECHANISM (GNU make's own, make 4.3 as installed): one named pipe holds N tokens; a make joins it by opening the pipe on a known fd and
# reading MAKEFLAGS="-j --jobserver-auth=FD,FD"; every job a make starts beyond its one implicit job costs a token, returned when the job
# ends; sub-makes inherit the fd and the flags. Nineteen roots then never run more than N+makes compiles at once, by mechanism, not by
# discipline. MEASURED 2026-11-04 15:0x CST (/tmp/s4e/cto/jstest4.sh): with 2 tokens one make of six 1 s jobs ran 3 wide (2.00 s), two
# independent makes on the same pipe ran 4 wide together (3.01 s), a $(MAKE) child inherited it, and FIONREAD read the 2 tokens back.
# A pipe's bytes live only while a process holds it open, so a HOLDER unit keeps it open (systemd --user, s4e.slice).
#   start [N]   start the holder unit s4e-jobserver with N tokens (default: the tokens column of JOBSERVER.tsv, else 8)
#   stop        stop the holder (every joined make falls back to its one implicit job until a holder returns)
#   hold N      the holder's own body (run by start under systemd; never by hand)
#   status      JOBSERVER unit=<active|inactive> tokens=<declared> free=<in the pipe> makes=<processes holding the pipe>   rc 0 live, 1 down, 2 unmeasurable
#   set N       move the budget to N tokens (the controller's actuator): adds tokens, or takes the surplus out of the pipe as they return
#   make ARGS   run GNU make joined to the pipe (-j/--jobs arguments are dropped: the pipe is the budget); no holder: plain make ARGS
#   prove       the gate: one make of (N+5) one-second jobs against the live pipe must run exactly N+1 wide and leave N tokens; rc 0/1/2
set -uo pipefail
FIFO=/home/resources/progress/jobserver.fifo
TSV=/home/resources/progress/JOBSERVER.tsv
UNIT=s4e-jobserver
FD=7
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
refuse() { echo "REFUSE(2) [util_jobserver]: $*" >&2; exit 2; }
declared() { [ -s "$TSV" ] && awk -F'\t' '!/^#/ && $1=="tokens"{print $2; exit}' "$TSV"; }
record() { { echo "# JOBSERVER.tsv -- the declared box-wide compile budget (util_jobserver.sh, DESIGN-PLAN box-scheduler step 1): tokens, N, when, holder pid, by whom."; printf 'tokens\t%s\t%s\t%s\t%s\n' "$1" "$(date '+%Y-%m-%dT%H:%M:%S')" "$2" "$3"; } > "$TSV"; }
free_tokens() { python3 - "$FIFO" <<'PY'
import fcntl, os, struct, sys, termios
try:
    fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
    print(struct.unpack('i', fcntl.ioctl(fd, termios.FIONREAD, b'\0' * 4))[0])
except OSError as e:
    print(-1)
PY
}
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
unit_active() { systemctl --user is-active --quiet "$UNIT"; }
holder_pid() { [ -s "$TSV" ] && awk -F'\t' '!/^#/ && $1=="tokens" && $4 ~ /^[0-9]+$/ {print $4; exit}' "$TSV"; }
holder_alive() { local h; h="$(holder_pid)"; [ -n "$h" ] && [ "$(readlink /proc/"$h"/fd/$FD 2>/dev/null)" = "$FIFO" ]; }
holders() { local n=0 l; for l in /proc/[0-9]*/fd/$FD; do [ "$(readlink "$l" 2>/dev/null)" = "$FIFO" ] || continue; case "$l" in /proc/$$/*|/proc/$(holder_pid)/*) ;; *) n=$((n+1));; esac; done; echo "$n"; }
drain() { python3 - "$FIFO" <<'PY'
import os, sys
fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
n = 0
while True:
    try:
        b = os.read(fd, 4096)
    except BlockingIOError:
        break
    if not b: break
    n += len(b)
print(n)
PY
}
verb="${1:-}"; shift || true
case "$verb" in
  hold)
    n="${1:?hold takes N}"
    [ -p "$FIFO" ] || mkfifo "$FIFO" || refuse "cannot mkfifo $FIFO"
    exec 7<>"$FIFO"
    drain >/dev/null
    printf '%*s' "$n" '' | tr ' ' '+' >&7
    record "$n" "$$" "start"
    trap 'exit 0' TERM INT
    while :; do sleep 60; done ;;
  start)
    unit_active && { echo "JOBSERVER already active: $(bash "$SELF" status)"; exit 0; }
    n="${1:-$(declared)}"; n="${n:-8}"
    systemd-run --user --unit="$UNIT" -p Slice=s4e.slice --quiet bash "$SELF" hold "$n" || refuse "systemd-run failed"
    for i in 1 2 3 4 5 6 7 8 9 10; do [ "$(free_tokens)" = "$n" ] && break; sleep 0.5; done
    bash "$SELF" status ;;
  stop)
    systemctl --user stop "$UNIT" 2>/dev/null; echo "JOBSERVER stopped" ;;
  status)
    if holder_alive; then u=active; else u=inactive; fi
    d="$(declared)"; d="${d:-0}"
    f="$(free_tokens)"
    [ "$f" -ge 0 ] 2>/dev/null || f=0
    m="$(holders)"
    echo "JOBSERVER unit=$u tokens=$d free=$f makes=$m"
    [ "$u" = active ] && [ "$d" -gt 0 ] && exit 0
    exit 1 ;;
  set)
    n="${1:?set takes N}"; unit_active || refuse "no holder: start first"
    d="$(declared)"; d="${d:-0}"
    if [ "$n" -gt "$d" ]; then printf '%*s' "$((n - d))" '' | tr ' ' '+' > "$FIFO"
    elif [ "$n" -lt "$d" ]; then python3 - "$FIFO" "$((d - n))" <<'PY'
import os, sys, time
fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK); want = int(sys.argv[2]); got = 0; t0 = time.time()
while got < want and time.time() - t0 < 120:
    try: got += len(os.read(fd, want - got))
    except BlockingIOError: time.sleep(0.2)
PY
    fi
    record "$n" "$(holder_pid)" "set by ${S4E_SEAT:-$(id -un)}"
    bash "$SELF" status ;;
  make)
    args=(); for a in "$@"; do case "$a" in -j|-j[0-9]*|--jobs|--jobs=*) ;; *) args+=("$a") ;; esac; done
    if [ -p "$FIFO" ] && holder_alive; then
      exec 7<>"$FIFO"
      MAKEFLAGS="-j --jobserver-auth=$FD,$FD" exec make "${args[@]}"
    fi
    exec make "$@" ;;
  prove)
    holder_alive || { echo "PROVE: no holder (JOBSERVER inactive)"; exit 1; }
    d="$(declared)"; [ "${d:-0}" -gt 0 ] || refuse "no declared token count"
    w="$(mktemp -d "${TMPDIR:-/tmp}/jobserver_prove.XXXXXX")"
    k=$((d + 5))
    { printf 'all:'; for i in $(seq 1 "$k"); do printf ' j%d' "$i"; done; printf '\n'
      for i in $(seq 1 "$k"); do printf 'j%d:\n\t@date +%%s.%%N >> starts; sleep 1; date +%%s.%%N >> ends\n' "$i"; done; } > "$w/Makefile"
    ( cd "$w" && bash "$SELF" make -s all ) || { echo "PROVE: the joined make failed"; exit 1; }
    width="$(python3 - "$w" <<'PY'
import sys
w = sys.argv[1]
ev = [(float(x), 1) for x in open(w + '/starts')] + [(float(x), -1) for x in open(w + '/ends')]
ev.sort(); cur = mx = 0
for _, d in ev:
    cur += d; mx = max(mx, cur)
print(mx)
PY
)"
    f="$(free_tokens)"
    echo "PROVE: tokens=$d jobs=$k width=$width (expected $((d + 1))) free_after=$f (expected $d)"
    [ "$width" = "$((d + 1))" ] && [ "$f" = "$d" ] && exit 0
    exit 1 ;;
  *) refuse "usage: util_jobserver.sh start [N] | stop | status | set N | make ARGS | prove" ;;
esac
