#!/usr/bin/env bash
# util_tmp_sweep.sh -- THE /tmp SWEEPER (ceo CEO-1831, Lon 2026-10-18 11:2x CDT, in-chat to the ceo, verbatim: "Fix the /tmp
# problem. Find out why does it it keep filling; seems like a LEAK.").
#
# WHY /tmp FILLS (measured 2026-10-18 11:21 CDT, /tmp 63G at 100 percent, 418M free): every scratch maker in the harness
# already cleans up with `trap 'rm -rf "$W"' EXIT`, and the debris is still there, because the kill paths never run a trap:
# a tool call or a loop killed on its timeout dies by SIGKILL after the grace (timeout -k, the cgroup kill, a dead loop's
# children), and its scratch stays. The other half is the seats' own scratchpads under /tmp/claude-1000/<seat>/<session>:
# a session that ended keeps its multi-GB .s and .bin outputs forever (28G across ten seats; hq_runtime alone 9.6G in
# four dead sessions). A trap is not a cure for a kill; a sweep by age is.
#
# THE POLICY, under the grant of CEO-754 (/tmp scratch may be deleted on AGE ALONE, over 48 hours, freed bytes recorded in
# GOAL-CFO.md): (1) a top-level /tmp entry is dead when no file in its tree is newer than the cutoff and no live process
# has its cwd inside it; the AGE IS THE NEWEST FILE INSIDE, never the directory's own mtime (a directory written into
# every minute keeps an old mtime). (2) a seat's session scratchpad is dead when its session is not the seat's newest
# transcript and nothing inside is newer than the cutoff. (3) never touched: anything dot-named, systemd and X11 sockets,
# snap, tmux and ssh agents, the build objdirs /tmp/si_objs* (a stale one costs a rebuild, and the freshness guard owns
# that), and any entry a live process sits in. (4) --hours N moves the cutoff (default 48); --dead-sessions-hours N applies
# a shorter cutoff to session scratchpads of a seat MODE's ROSTER line does not name (a stood-down seat runs nothing) --
# the ceo's reading of Lon's order this day, default 0 (off) so the grant's 48 h is the rule unless the caller says so.
#
# (5) ANONYMOUS SCRATCH (ceo CEO-1842, 2026-10-18 17:0x CDT, measured: 15 GB of mktemp debris under 48 h -- a1.A.bin bench trees,
# verify_s_owed.XXXXXX, tmp.XXXXXXXXXX from gates killed on their timeout -- while /tmp read 22G): an entry whose NAME is a mktemp
# pattern (tmp.XXXXXXXXXX, tmpXXXXXXXX, <word>.XXXXXX) has no owner but the run that made it, so it is dead when that run is: no live
# process has its cwd or an OPEN FILE inside it and nothing in it is newer than --scratch-hours N (default 3; 0 turns the arm off).
# A named entry keeps the 48 h rule. The receipt counts these as scratch=<n> scratch_mb=<mb>.
# USE: bash harness/scripts/util_tmp_sweep.sh            # dry run: what would go, by class, with bytes
#      bash harness/scripts/util_tmp_sweep.sh --apply    # delete it, print the receipt line, append it to the ledger
# RECEIPT: TMP_SWEEP applied=<0|1> cutoff_hours=<h> entries=<n> freed_mb=<mb> sessions=<n> session_mb=<mb> free_after=<...>
# LEDGER: /home/resources/progress/TMP-SWEEP.tsv (one row per --apply), folded into GOAL-CFO.md by the ceo per sitting.
# EXIT: 0 swept or nothing to sweep; 2 refused (not on this box's layout, or /tmp unreadable).
set -u
HOURS=48; DEAD_H=0; SCR_H=3; APPLY=0
while [ $# -gt 0 ]; do case "$1" in --apply) APPLY=1;; --hours) HOURS="$2"; shift;; --dead-sessions-hours) DEAD_H="$2"; shift;; --scratch-hours) SCR_H="$2"; shift;;
  -h|--help) sed -n '2,30p' "$0"; exit 0;; *) echo "REFUSE(2): unknown argument $1" >&2; exit 2;; esac; shift; done
[ -d /tmp ] && [ -r /tmp ] || { echo "REFUSE(2): /tmp unreadable"; exit 2; }
LEDGER=/home/resources/progress/TMP-SWEEP.tsv
PO=/home/resources/postoffice
ROSTER="$(grep -m1 '^ROSTER:' "$PO/MODE" 2>/dev/null | sed 's/^ROSTER://')"
python3 - "$HOURS" "$DEAD_H" "$APPLY" "$LEDGER" "$ROSTER" "$SCR_H" <<'PYEOF'
import os, sys, time, shutil, subprocess, datetime
hours = float(sys.argv[1]); dead_h = float(sys.argv[2]); apply = sys.argv[3] == "1"; ledger = sys.argv[4]; roster = set(sys.argv[5].split()); scr_h = float(sys.argv[6])
now = time.time(); cutoff = now - hours * 3600
KEEP_PREFIX = (".", "systemd-", "snap.", "tmux-", "ssh-", "si_objs", "claude-1000", "pulse-", "dbus-", "Temp-")
def newest_in(path, limit=400000):
    best = 0; n = 0
    try: st = os.lstat(path)
    except OSError: return 0
    best = st.st_mtime
    if not os.path.isdir(path) or os.path.islink(path): return best
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(root, d))]
        for f in files:
            n += 1
            if n > limit: return now
            try: m = os.lstat(os.path.join(root, f)).st_mtime
            except OSError: continue
            if m > best: best = m
    return best
def size_kb(path):
    try: return int(subprocess.run(["du", "-xsk", path], capture_output=True, text=True).stdout.split("\t")[0])
    except Exception: return 0
live_cwd = set(); live_fd = set()
for p in os.listdir("/proc"):
    if not p.isdigit(): continue
    try: live_cwd.add(os.readlink("/proc/%s/cwd" % p))
    except OSError: pass
    try:
        for fd in os.listdir("/proc/%s/fd" % p):
            try:
                t = os.readlink("/proc/%s/fd/%s" % (p, fd))
                if t.startswith("/tmp/"): live_fd.add(t)
            except OSError: pass
    except OSError: pass
import re
SCRATCH = re.compile(r"^(tmp\.[A-Za-z0-9]{6,}|tmp[a-z0-9_]{6,}|[A-Za-z0-9_-]+\.[A-Za-z0-9]{6})$")
def held_fd(path):
    pre = path.rstrip("/") + "/"
    return any(c == path or c.startswith(pre) for c in live_fd)
def held(path):
    pre = path.rstrip("/") + "/"
    return any(c == path or c.startswith(pre) for c in live_cwd)
victims = []
for name in sorted(os.listdir("/tmp")):
    if name.startswith(KEEP_PREFIX): continue
    path = "/tmp/" + name
    if held(path): continue
    if SCRATCH.match(name) and scr_h > 0 and os.path.isdir(path) and not held_fd(path) and newest_in(path) < now - scr_h * 3600:
        victims.append(("scratch", path, size_kb(path))); continue
    if newest_in(path) >= cutoff: continue
    victims.append(("entry", path, size_kb(path)))
sessions = []
root = "/tmp/claude-1000"
if os.path.isdir(root):
    for seat in sorted(os.listdir(root)):
        sd = os.path.join(root, seat)
        if not os.path.isdir(sd): continue
        proj = "/home/satirical/.claude/projects/" + seat
        cur = None
        try:
            js = [f for f in os.listdir(proj) if f.endswith(".jsonl")]
            if js: cur = max(js, key=lambda f: os.stat(os.path.join(proj, f)).st_mtime)[:-6]
        except OSError: pass
        seat_id = seat.replace("-home-claude-", "")
        seat_name = {"ceo": "ceo", "cto": "cto", "coo": "coo", "cfo": "cfo"}.get(seat_id, "hq_" + seat_id)
        down = roster and seat_name not in roster
        for ses in os.listdir(sd):
            p = os.path.join(sd, ses)
            if not os.path.isdir(p) or ses == cur or held(p): continue
            lim = cutoff
            if down and dead_h > 0: lim = max(lim, now - dead_h * 3600)
            if newest_in(p) >= lim: continue
            sessions.append(("session", p, size_kb(p)))
freed = 0; sfreed = 0; scr_n = 0; scr_kb = 0
for kind, path, kb in victims + sessions:
    age_h = (now - newest_in(path)) / 3600
    print("%-8s %8.1fM %6.1fh %s" % (kind, kb / 1024, age_h, path))
    if apply:
        try:
            if os.path.isdir(path) and not os.path.islink(path): shutil.rmtree(path, ignore_errors=True)
            else: os.unlink(path)
        except OSError as e: print("   not removed: %s" % e); continue
    if kind == "entry": freed += kb
    elif kind == "scratch": freed += kb; scr_n += 1; scr_kb += kb
    else: sfreed += kb
st = os.statvfs("/tmp"); free_after = st.f_bavail * st.f_frsize / 1048576
line = "TMP_SWEEP applied=%d cutoff_hours=%g dead_sessions_hours=%g scratch_hours=%g entries=%d freed_mb=%d scratch=%d scratch_mb=%d sessions=%d session_mb=%d free_after_mb=%d" % (
    1 if apply else 0, hours, dead_h, scr_h, len(victims), freed // 1024, scr_n, scr_kb // 1024, len(sessions), sfreed // 1024, free_after)
print(line)
if apply:
    try:
        new = not os.path.exists(ledger)
        with open(ledger, "a", encoding="utf-8") as fh:
            if new: fh.write("ts_utc\tcutoff_hours\tdead_sessions_hours\tentries\tfreed_mb\tsessions\tsession_mb\tfree_after_mb\n")
            fh.write("%s\t%g\t%g\t%d\t%d\t%d\t%d\t%d\n" % (datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), hours, dead_h, len(victims), freed // 1024, len(sessions), sfreed // 1024, free_after))
    except OSError as e: print("ledger not written: %s" % e)
PYEOF
