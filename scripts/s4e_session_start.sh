#!/usr/bin/env bash
# s4e_session_start.sh -- A SESSION PLACES ITSELF (ARCH-SHARED-DEVELOPMENT.md 2.2 and 4.2; the cto's design R-2041, step 2 built by the officer).
# Every seat's SessionStart hook runs it (util_fleet_settings.sh installs the hook; Lon runs that script). It reads the session's own cgroup
# scope, appends one line to /home/resources/progress/SEATS.tsv (utc, seat, class, scope, pid, start; the newest line per seat is the live
# one, the older lines are history) and applies the class's properties to the scope with systemctl --user set-property --runtime, READ FROM THE ONE
# DECLARED BUDGET TABLE /home/resources/postoffice/BUDGET.tsv (box-budget step 2, CTO-478; util_seat_census.py budget_rows), its @SEAT and @LON rows:
#   SEAT  on 2026-11-04 CPUWeight=100 CPUQuota=400% MemoryHigh=4G MemoryMax=8G MemorySwapMax=1G TasksMax=2048 (the quota: R-2105, the session scope is the door)
#   LON   on 2026-11-04 CPUWeight=1000 (a Claude session whose root is not a seat's; no memory cap on Lon's class; R-2105 (d): ten to one over a seat)
# No table (or no row) weights nothing (weighted=no-budget) and --check reads RED: the table is the one copy of the numbers.
# HELPERS (R-2108, ARCH-SHARED-DEVELOPMENT 13): a claude whose argv[1] is daemon, whose argv carries --bg-pty-host or --bg-spare, or whose parent
# is a claude (or a Claude version binary) is a helper: it writes no ledger line and gets no set-property (--pid on one prints SKIPPED helper), and the
# hook's walk up passes it to the session that spawned it. A scope the ledger's newest SEAT line names is never weighted LON (weighted=refused).
# ORDER (section 10): a scope is weighted ONLY when app-org.gnome.Terminal.slice already reads its CPUWeight (100 since R-2105 (d), under the grader's 300), because the first weight below
# app.slice enables the cpu controller there; until Lon's script has set the slices, the hook registers and weights nothing.
# It also makes the seat's TMPDIR (/tmp/s4e/<seat>). It is idempotent, takes well under a second, and NEVER fails the session (rc 0 always).
#   s4e_session_start.sh             the hook: this session (its parent Claude process)
#   s4e_session_start.sh --pid P     place the live session whose process is P (util_fleet_settings.sh --apply uses it)
#   s4e_session_start.sh --props     print the SEAT and LON properties and the sessions' slice weight it reads from the table (S4E_BUDGET names another); rc 2 none
#   s4e_session_start.sh --check     step 2's DONE-WHEN: rc 0 every live seat session registered and weighted, the sessions' slice at 100 (R-2105 (d)) and
#                                    the grader and batch slices configured; rc 1 RED with the first gaps named; rc 2 nothing registered yet
S4E_SESSION_START_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" exec python3 - "$@" <<'PY'
import os, re, subprocess, sys, time, fcntl
sys.path.insert(0, os.environ.get("S4E_SESSION_START_HERE", "."))
try:
    import util_seat_census as census
    BROWS = {r["unit"]: r for r in census.budget_rows()}
except Exception:
    census, BROWS = None, {}
LEDGER = "/home/resources/progress/SEATS.tsv"
try:
    import util_score_row as _usr
    OFFICERS = set(_usr.roster_officers())
except Exception:
    OFFICERS = {"cto", "cfo", "coo", "cao", "cqo", "cio"}
TERM = "app-org.gnome.Terminal.slice"
SEAT_PROPS = census.budget_props(BROWS.get("@SEAT")) if census else []   # CPUQuota (R-2105): the session scope IS the door -- every child of a seat session inherits a four-core cap
LON_PROPS = census.budget_props(BROWS.get("@LON")) if census else []   # R-2105 (d): inside the sessions' slice Lon's terminal outranks every seat (100) ten to one
TERM_WEIGHT = BROWS.get(TERM, {}).get("CPUWeight", "")   # R-2105 (d): the sessions' slice at the default 100, equal to any desktop app, under the grader slice (300); a seat scope is weighted only once the sessions' slice reads it
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
def ppid_of(pid):
    try: return int(open("/proc/%d/stat" % pid).read().rsplit(")", 1)[1].split()[1])
    except Exception: return 0
def argv_of(pid):
    try: return open("/proc/%d/cmdline" % pid, "rb").read().decode("utf-8", "replace").split("\0")
    except Exception: return []
def claude_comm(c):
    return c == "claude" or re.fullmatch(r"\d+\.\d+\.\d+", c or "") is not None
def is_helper(pid):
    # R-2108 (a): a SESSION is a claude process with no subcommand whose parent is not a claude process; Claude Code's own daemon
    # (claude daemon run), its background pty hosts and spares, and any claude spawned by a claude are HELPERS -- never a session
    a = argv_of(pid)
    return a[1:2] == ["daemon"] or "--bg-pty-host" in a or "--bg-spare" in a or claude_comm(comm_of(ppid_of(pid)))
def session_pid():
    p = os.getppid()
    for _ in range(12):
        if comm_of(p) == "claude" and not is_helper(p): return p
        p = ppid_of(p)
        if p <= 1: break
    return os.getppid()
def seat_scopes():
    # R-2108 (b): the scopes the ledger's newest SEAT line per seat names; a scope in this set is never weighted LON
    newest = {}
    try:
        for l in open(LEDGER):
            f = l.rstrip("\n").split("\t")
            if len(f) >= 7 and f[0] != "utc" and f[2] == "SEAT": newest[f[1]] = f[3]
    except Exception: pass
    return set(newest.values())
def place(pid):
    if is_helper(pid): return None
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
    if klass == "LON" and cg in seat_scopes(): weighted = "refused"
    elif unit.endswith(".scope") and ("/" + TERM + "/") in cg and TERM_WEIGHT and show(TERM, "CPUWeight") == TERM_WEIGHT:
        props = SEAT_PROPS if klass == "SEAT" else LON_PROPS
        if not props: weighted = "no-budget"
        else:
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
        if comm_of(pid) != "claude" or is_helper(pid): continue
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
    if census is None or "@SEAT" not in BROWS: print("REFUSE(2): no budget table with a @SEAT row (util_seat_census.py budget_rows, /home/resources/postoffice/BUDGET.tsv)"); return 2
    gaps = []
    if show(TERM, "CPUWeight") != TERM_WEIGHT: gaps.append("%s CPUWeight=%s, not %s" % (TERM, show(TERM, "CPUWeight") or "?", TERM_WEIGHT or "declared"))
    svc = "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/"
    for sl, r in sorted(BROWS.items()):
        if not sl.endswith(".slice") or sl == TERM or r["CPUWeight"] == "-": continue
        try: w = open(svc + census.slice_path(sl) + "/cpu.weight").read().strip()
        except Exception: w = "?"
        if w != r["CPUWeight"]: gaps.append("%s cpu.weight=%s, not %s" % (sl, w, r["CPUWeight"]))
    live = live_sessions()
    for seat, pids in sorted(live.items()):
        if seat not in newest: gaps.append("%s has a live session (pid %s) and no SEATS.tsv line" % (seat, pids[0])); continue
        f = newest[seat]; scope = "/sys/fs/cgroup" + f[3]
        if int(f[4]) not in pids: gaps.append("%s: the live session %s is not the registered pid %s (restarted after registering)" % (seat, pids[0], f[4])); continue
        if not os.path.isdir(scope): gaps.append("%s: scope %s is gone" % (seat, f[3])); continue
        def rd(n):
            try: return open(os.path.join(scope, n)).read().strip()
            except Exception: return "?"
        for k, fn in census.BUDGET_KNOBS:
            v = BROWS["@SEAT"][k]
            bad = census.budget_knob_gap(BROWS["@SEAT"], k, rd(fn)) if v != "-" else ""
            if bad: gaps.append("%s: %s %s" % (seat, fn, bad))
    print("SEATS live=%d registered=%d gaps=%d" % (len(live), len(newest), len(gaps)))
    for g in gaps[:12]: print("  RED " + g)
    if gaps: return 1
    print("GREEN: every live seat session is registered and its scope reads the budget table's @SEAT row (%s); %s and every slice row at its declared cpu.weight" % (" ".join(SEAT_PROPS), TERM))
    return 0
a = sys.argv[1:]
if a[:1] == ["--check"]: sys.exit(check())
if a[:1] == ["--props"]:
    print("SEAT_PROPS=%s LON_PROPS=%s TERM_WEIGHT=%s" % (",".join(SEAT_PROPS) or "-", ",".join(LON_PROPS) or "-", TERM_WEIGHT or "-")); sys.exit(0 if SEAT_PROPS and TERM_WEIGHT else 2)
if a[:1] == ["--pid"]:
    try: pid = int(a[1])
    except Exception: print("usage: s4e_session_start.sh [--pid P | --check]"); sys.exit(2)
    r = place(pid)
    if r is None: print("SKIPPED helper pid=%d parent=%d (%s): a helper is never a session, no ledger line, no set-property (R-2108)" % (pid, ppid_of(pid), " ".join(argv_of(pid)[:3]).strip())); sys.exit(0)
    print("PLACED seat=%s class=%s scope=%s weighted=%s" % r); sys.exit(0)
try: place(session_pid())
except Exception: pass
sys.exit(0)
PY
