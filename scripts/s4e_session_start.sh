#!/usr/bin/env bash
# s4e_session_start.sh -- A SESSION PLACES ITSELF (ARCH-SHARED-DEVELOPMENT.md 2.2 and 4.2; the cto's design CEO-2041, step 2 built by the ceo).
# Every seat's SessionStart hook runs it (util_fleet_settings.sh installs the hook; Lon runs that script). It reads the session's own cgroup
# scope, appends one line to /home/resources/progress/SEATS.tsv (utc, seat, class, scope, pid, start; the newest line per seat is the live
# one, the older lines are history) and applies the class's properties to the scope with systemctl --user set-property --runtime:
#   SEAT  CPUWeight=100 MemoryHigh=4G MemoryMax=8G MemorySwapMax=1G TasksMax=2048
#   LON   CPUWeight=200 (a Claude session whose root is not a seat's; no memory cap on Lon's class)
# ORDER (section 10): a scope is weighted ONLY when app-org.gnome.Terminal.slice already reads CPUWeight=600, because the first weight below
# app.slice enables the cpu controller there; until Lon's script has set the slices, the hook registers and weights nothing.
# It also makes the seat's TMPDIR (/tmp/s4e/<seat>). It is idempotent, takes well under a second, and NEVER fails the session (rc 0 always).
#   s4e_session_start.sh             the hook: this session (its parent Claude process)
#   s4e_session_start.sh --pid P     place the live session whose process is P (util_fleet_settings.sh --apply uses it)
#   s4e_session_start.sh --check     step 2's DONE-WHEN: rc 0 every live seat session registered and weighted, the sessions' slice at 600 and
#                                    the grader and batch slices configured; rc 1 RED with the first gaps named; rc 2 nothing registered yet
exec python3 - "$@" <<'PY'
import os, re, subprocess, sys, time, fcntl
LEDGER = "/home/resources/progress/SEATS.tsv"
OFFICERS = {"ceo", "cto", "cfo", "coo", "cao", "cqo"}
TERM = "app-org.gnome.Terminal.slice"
SEAT_PROPS = ["CPUWeight=100", "MemoryHigh=4G", "MemoryMax=8G", "MemorySwapMax=1G", "TasksMax=2048"]
LON_PROPS = ["CPUWeight=200"]
def seat_of_root(path):
    m = re.match(r"/home/claude_([a-z0-9_]+)(/|$)", path or "")
    if not m: return None
    x = m.group(1)
    return x if x in OFFICERS else "hq_" + x
def proc_env(pid):
    try: return dict(kv.split("=", 1) for kv in open("/proc/%d/environ" % pid, "rb").read().decode("utf-8", "replace").split("\0") if "=" in kv)
    except Exception: return {}
def cwd_of(pid):
    try: return os.readlink("/proc/%d/cwd" % pid)
    except Exception: return ""
def cgroup_of(pid):
    try:
        for line in open("/proc/%d/cgroup" % pid):
            if line.startswith("0::"): return line.strip()[3:]
    except Exception: pass
    return ""
def start_of(pid):
    try:
        st = open("/proc/%d/stat" % pid).read(); f = st[st.rindex(")") + 2:].split()
        boot = float([l.split()[1] for l in open("/proc/stat") if l.startswith("btime")][0])
        return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(boot + int(f[19]) / os.sysconf("SC_CLK_TCK")))
    except Exception: return "?"
def comm_of(pid):
    try: return open("/proc/%d/comm" % pid).read().strip()
    except Exception: return ""
def show(unit, prop):
    try: return subprocess.run(["systemctl", "--user", "show", unit, "-p", prop, "--value"], capture_output=True, text=True, timeout=3).stdout.strip()
    except Exception: return ""
def session_pid():
    p = os.getppid()
    for _ in range(8):
        if comm_of(p) == "claude": return p
        try: p = int(open("/proc/%d/stat" % p).read().rsplit(")", 1)[1].split()[1])
        except Exception: break
        if p <= 1: break
    return os.getppid()
def place(pid):
    env = proc_env(pid)
    seat = env.get("S4E_SEAT") or seat_of_root(cwd_of(pid))
    klass = "SEAT" if seat else "LON"
    seat = seat or "lon"
    cg = cgroup_of(pid)
    unit = cg.rsplit("/", 1)[-1] if cg else ""
    if klass == "SEAT":
        try: os.makedirs("/tmp/s4e/" + seat, mode=0o700, exist_ok=True)
        except Exception: pass
    weighted = "no"
    if unit.endswith(".scope") and ("/" + TERM + "/") in cg and show(TERM, "CPUWeight") == "600":
        props = SEAT_PROPS if klass == "SEAT" else LON_PROPS
        try:
            r = subprocess.run(["systemctl", "--user", "set-property", "--runtime", unit] + props, capture_output=True, text=True, timeout=5)
            weighted = "yes" if r.returncode == 0 else "failed"
        except Exception: weighted = "failed"
    line = "\t".join([time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), seat, klass, cg or "?", str(pid), start_of(pid), weighted]) + "\n"
    try:
        with open(LEDGER, "a") as fh:
            fcntl.flock(fh, fcntl.LOCK_EX)
            if fh.tell() == 0: fh.write("utc\tseat\tclass\tscope\tpid\tstart\tweighted\n")
            fh.write(line)
    except Exception: pass
    return seat, klass, unit, weighted
def live_sessions():
    out = {}
    for d in os.listdir("/proc"):
        if not d.isdigit(): continue
        pid = int(d)
        if comm_of(pid) != "claude": continue
        seat = proc_env(pid).get("S4E_SEAT") or seat_of_root(cwd_of(pid))
        if seat: out.setdefault(seat, []).append(pid)
    return out
def check():
    if not os.path.exists(LEDGER): print("REFUSE(2): %s does not exist: no session has registered yet" % LEDGER); return 2
    newest = {}
    for l in open(LEDGER):
        f = l.rstrip("\n").split("\t")
        if len(f) >= 7 and f[0] != "utc" and f[2] == "SEAT": newest[f[1]] = f
    if not newest: print("REFUSE(2): %s holds no SEAT line" % LEDGER); return 2
    gaps = []
    if show(TERM, "CPUWeight") != "600": gaps.append("%s CPUWeight=%s, not 600" % (TERM, show(TERM, "CPUWeight") or "?"))
    for sl, w in (("s4e-grader.slice", "300"), ("s4e-batch.slice", "100")):
        if show(sl, "CPUWeight") != w: gaps.append("%s CPUWeight=%s, not %s" % (sl, show(sl, "CPUWeight") or "?", w))
    live = live_sessions()
    for seat, pids in sorted(live.items()):
        if seat not in newest: gaps.append("%s has a live session (pid %s) and no SEATS.tsv line" % (seat, pids[0])); continue
        f = newest[seat]; scope = "/sys/fs/cgroup" + f[3]
        if int(f[4]) not in pids: gaps.append("%s: the live session %s is not the registered pid %s (restarted after registering)" % (seat, pids[0], f[4])); continue
        if not os.path.isdir(scope): gaps.append("%s: scope %s is gone" % (seat, f[3])); continue
        def rd(n):
            try: return open(os.path.join(scope, n)).read().strip()
            except Exception: return "?"
        if rd("cpu.weight") != "100": gaps.append("%s: cpu.weight=%s, not 100" % (seat, rd("cpu.weight")))
        if rd("memory.max") in ("max", "?"): gaps.append("%s: memory.max=%s" % (seat, rd("memory.max")))
        if rd("pids.max") in ("max", "?"): gaps.append("%s: pids.max=%s" % (seat, rd("pids.max")))
    print("SEATS live=%d registered=%d gaps=%d" % (len(live), len(newest), len(gaps)))
    for g in gaps[:12]: print("  RED " + g)
    if gaps: return 1
    print("GREEN: every live seat session is registered with cpu.weight 100 and its memory and task caps; %s at 600, the grader and batch slices configured" % TERM)
    return 0
a = sys.argv[1:]
if a[:1] == ["--check"]: sys.exit(check())
if a[:1] == ["--pid"]:
    try: pid = int(a[1])
    except Exception: print("usage: s4e_session_start.sh [--pid P | --check]"); sys.exit(2)
    print("PLACED seat=%s class=%s scope=%s weighted=%s" % place(pid)); sys.exit(0)
try: place(session_pid())
except Exception: pass
sys.exit(0)
PY
