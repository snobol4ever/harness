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
# A SPAWNED SEAT (the coo 2026-11-12 18:2x): a scope s4e-seat-<seat>.scope under s4e-seats.slice (spawn_fleet.sh) gets the @SEAT row less its CPUQuota, which
# spawn sets and box_controller.sh moves; before this the hook read weighted=no there, and no seat scope carried MemorySwapMax or TasksMax.
# THE CAGE (the weighted door, step 2; the president 2026-11-18 on the chairman's measurement of 08:01): only while /home/resources/postoffice/CORES.conf carries the line cage=on, a
# session whose claude is not in s4e-seats.slice/s4e-seat-<seat>.scope is ADOPTED into that scope by one StartTransientUnit (PIDs, Slice, OOMPolicy=continue, MemoryMax of @SEAT, ManagedOOMPreference=omit),
# whoever opened its window; a unit of that name that holds other live pids is left alone and the hook prints CAGE refused. With no cage=on line the hook is what it was.
#   s4e_session_start.sh --probe-cage  seven arms on scratch processes and s4e-cage-probe-* units, rc 0 only when every arm reads ok
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
    OFFICERS = {"cto", "cfo", "president", "cao", "cqo", "chairman"}
TERM = "app-org.gnome.Terminal.slice"
SEATS_SLICE = "s4e-seats.slice"   # spawn_fleet.sh runs each seat in systemd-run --scope --slice=s4e-seats.slice --unit=s4e-seat-<seat>
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
CORES_CONF_DEFAULT = "/home/resources/postoffice/CORES.conf"
CAGE_BUS = ["busctl", "--user", "call", "org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager"]
def cage_on():
    # THE CAGE (the weighted door, step 2): live only while CORES.conf carries the line cage=on (S4E_CORES_CONF names another file); with no such line the hook behaves as it always did
    v = None
    try:
        for l in open(os.environ.get("S4E_CORES_CONF", CORES_CONF_DEFAULT)):
            l = l.strip()
            if l and not l.startswith("#") and "=" in l:
                k, x = l.split("=", 1)
                if k.strip() == "cage": v = x.strip()
    except Exception: return False
    return v == "on"
def size_bytes(s):
    m = re.fullmatch(r"(\d+)([KMGT]?)", s or "")
    return int(m.group(1)) * {"": 1, "K": 1 << 10, "M": 1 << 20, "G": 1 << 30, "T": 1 << 40}[m.group(2)] if m else 0
def seat_mem_max():
    for p in SEAT_PROPS:
        if p.startswith("MemoryMax="): return size_bytes(p.split("=", 1)[1]) or (8 << 30)
    return 8 << 30
def unit_pids(unit):
    cgp = show(unit, "ControlGroup")
    try: return [int(x) for x in open("/sys/fs/cgroup" + cgp + "/cgroup.procs").read().split()] if cgp else []
    except Exception: return []
def adopt_call(unit, props):
    # one StartTransientUnit that ADOPTS live pids (systemd-run cannot); props are (name, dbus type, value words); rc 0 when systemd took the job
    args = CAGE_BUS + ["StartTransientUnit", "ssa(sv)a(sa(sv))", unit, "fail", str(len(props))]
    for k, t, v in props: args += [k, t] + v.split()
    args += ["0"]
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=10)
        return r.returncode, (r.stderr or r.stdout).strip().splitlines()[:1]
    except Exception as e: return 1, [str(e)]
def cage(pid, unit, mem_max=None, extra=()):
    # a session placed by hand lands in a vte scope outside s4e.slice, and a spawned one is made with OOMPolicy=stop: make the session's own scope s4e-seats.slice/<unit> ADOPTING its claude pid,
    # with OOMPolicy=continue, the @SEAT MemoryMax and ManagedOOMPreference=omit. systemd moves the pid asynchronously, so poll /proc/<pid>/cgroup. The pid moves alone: its parent shell and
    # the processes it started earlier stay behind, and the pages it already holds stay charged to the old scope (the ledger of the row). One word comes back: off already caged refused failed skipped
    if not cage_on(): return "off"
    if cgroup_of(pid).endswith("/" + SEATS_SLICE + "/" + unit): return "already"
    st = show(unit, "ActiveState")
    if st in ("active", "activating", "deactivating", "reloading"):
        live = [p for p in unit_pids(unit) if p != pid]
        if live:
            print("CAGE refused: %s already holds live pids %s (a second session of the seat); pid %d stays where it is" % (unit, live[:4], pid)); return "refused"
    if st == "failed":
        try: subprocess.run(["systemctl", "--user", "reset-failed", unit], capture_output=True, text=True, timeout=5)
        except Exception: pass
    if os.environ.get("S4E_CAGE_SKIP_ADOPT") == "1": return "skipped"
    props = [("PIDs", "au", "1 %d" % pid), ("Slice", "s", SEATS_SLICE), ("OOMPolicy", "s", "continue"), ("MemoryMax", "t", str(mem_max or seat_mem_max())), ("ManagedOOMPreference", "s", "omit")] + list(extra)
    rc, why = adopt_call(unit, props)
    if rc != 0:
        print("CAGE failed: %s: %s" % (unit, " ".join(why) or "StartTransientUnit refused")); return "failed"
    for _ in range(25):
        if cgroup_of(pid).endswith("/" + SEATS_SLICE + "/" + unit): return "caged"
        time.sleep(0.2)
    print("CAGE failed: pid %d did not reach %s within 5 s" % (pid, unit)); return "failed"
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
        if cage_on() and cage(pid, "s4e-seat-%s.scope" % (seat[3:] if seat.startswith("hq_") else seat)) == "caged":
            cg = cgroup_of(pid); unit = cg.rsplit("/", 1)[-1] if cg else ""
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
    elif klass == "SEAT" and unit.startswith("s4e-seat-") and unit.endswith(".scope") and "/" + SEATS_SLICE + "/" in cg:
        props = [p for p in SEAT_PROPS if not p.startswith("CPUQuota=")]   # a spawned seat's scope: spawn_fleet.sh made it with the quota and box_controller.sh moves that under the ceiling, so it is never reset here; the rest of @SEAT (MemorySwapMax, TasksMax) spawn does not set (the coo 2026-11-12 18:2x: all 33 read neither)
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
def probe_cage():
    # THE PROBE (rc 0 only when every arm reads ok, rc 1 otherwise): scratch processes and units named s4e-cage-probe-* only, a scratch CORES.conf, never a session and never an s4e-seat-* unit
    import shutil, signal, tempfile
    seat = os.environ.get("S4E_SEAT") or "probe"
    base = "/tmp/s4e/" + seat
    os.makedirs(base, exist_ok=True)
    root = tempfile.mkdtemp(prefix="cage-probe-", dir=base)
    tag = str(os.getpid())
    kids, units, arms = [], [], []
    saved = {k: os.environ.get(k) for k in ("S4E_CORES_CONF", "S4E_CAGE_SKIP_ADOPT")}
    def uname(x):
        n = "s4e-cage-probe-%s%s.scope" % (x, tag); units.append(n); return n
    def spawn(argv):
        p = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); kids.append(p); return p
    def arm(name, ok, what):
        arms.append(ok); print("%s %s %s" % ("ok " if ok else "RED", name, what))
    def tail(c): return c.rsplit("/", 2)[-2] + "/" + c.rsplit("/", 1)[-1] if c.count("/") > 1 else c
    conf_on, conf_off = root + "/on.conf", root + "/off.conf"
    open(conf_on, "w").write("cage=on\n"); open(conf_off, "w").write("cores=6\n")
    try:
        os.environ["S4E_CORES_CONF"] = conf_on
        os.environ.pop("S4E_CAGE_SKIP_ADOPT", None)
        sl = spawn(["sleep", "300"]); old = cgroup_of(sl.pid); ua = uname("a")
        ra = cage(sl.pid, ua); new = cgroup_of(sl.pid)
        arm("(a) adopt", ra == "caged" and new.endswith("/%s/%s" % (SEATS_SLICE, ua)) and new != old, "%s -> %s (%s)" % (tail(old), tail(new), ra))
        pol, pref = show(ua, "OOMPolicy"), show(ua, "ManagedOOMPreference")
        arm("(b) policy", pol == "continue" and pref == "omit", "OOMPolicy=%s ManagedOOMPreference=%s" % (pol, pref))
        sk = spawn(["sleep", "300"]); oldk = cgroup_of(sk.pid); ud = uname("d")
        os.environ["S4E_CAGE_SKIP_ADOPT"] = "1"
        rk = cage(sk.pid, ud); gone = cgroup_of(sk.pid)
        os.environ.pop("S4E_CAGE_SKIP_ADOPT", None)
        arm("(d) mechanism out reads red", rk == "skipped" and gone == oldk and gone != new and show(ud, "ActiveState") != "active", "adopt skipped: cgroup stays %s, differs from the adopted %s" % (tail(gone), tail(new)))
        hp = root + "/h"
        os.makedirs(hp)
        open(root + "/shell.sh", "w").write('#!/bin/bash\nwhile [ ! -e "$1/go" ]; do sleep 0.1; done\ntimeout 20 python3 -c \'b = bytearray(b"a") * (600 << 20); import time; time.sleep(5)\'\necho $? > "$1/rc"\nsleep 60\n')
        sh = spawn(["bash", root + "/shell.sh", hp]); uc = uname("c")
        rc_c = cage(sh.pid, uc, mem_max=300 << 20, extra=[("MemorySwapMax", "t", "0")])
        open(hp + "/go", "w").close()
        got = ""
        for _ in range(130):
            try: got = open(hp + "/rc").read().strip()
            except Exception: got = ""
            if got: break
            time.sleep(0.2)
        alive = sh.poll() is None and show(uc, "ActiveState") == "active"
        arm("(c) hog dies, shell lives", rc_c == "caged" and got == "137" and alive, "adopted %s, hog rc=%s (137 = killed), shell alive=%s, unit %s" % (rc_c, got or "none in 26 s", alive, show(uc, "ActiveState")))
        os.environ["S4E_CORES_CONF"] = conf_off
        se = spawn(["sleep", "300"]); olde = cgroup_of(se.pid); ue = uname("e")
        re_ = cage(se.pid, ue)
        arm("(e) no cage=on, no unit", re_ == "off" and cgroup_of(se.pid) == olde and show(ue, "LoadState") == "not-found", "cage()=%s, pid stays %s, unit LoadState=%s" % (re_, tail(cgroup_of(se.pid)), show(ue, "LoadState")))
        os.environ["S4E_CORES_CONF"] = conf_on
        sr = spawn(["sleep", "300"]); oldr = cgroup_of(sr.pid)
        rr = cage(sr.pid, ua)
        arm("(f) a live unit of the name is refused", rr == "refused" and cgroup_of(sr.pid) == oldr, "cage()=%s, pid stays %s" % (rr, tail(cgroup_of(sr.pid))))
        ug = uname("g")
        hp2 = root + "/h2"
        os.makedirs(hp2)
        hog = spawn(["bash", root + "/shell.sh", hp2])
        adopt_call(ug, [("PIDs", "au", "1 %d" % hog.pid), ("Slice", "s", SEATS_SLICE), ("OOMPolicy", "s", "stop"), ("MemoryMax", "t", str(100 << 20)), ("MemorySwapMax", "t", "0")])
        for _ in range(25):
            if cgroup_of(hog.pid).endswith("/" + ug): break
            time.sleep(0.2)
        open(hp2 + "/go", "w").close()
        st = ""
        for _ in range(60):
            st = show(ug, "ActiveState")
            if st == "failed": break
            time.sleep(0.2)
        if st == "failed":
            sg = spawn(["sleep", "300"]); oldg = cgroup_of(sg.pid)
            rg = cage(sg.pid, ug)
            arm("(g) a failed unit of the name is reset", rg == "caged" and cgroup_of(sg.pid).endswith("/%s/%s" % (SEATS_SLICE, ug)), "unit was failed, cage()=%s, pid %s -> %s" % (rg, tail(oldg), tail(cgroup_of(sg.pid))))
        else:
            arm("(g) a failed unit of the name is reset", False, "could not make a failed scratch unit (ActiveState=%s)" % st)
    except Exception as e:
        arm("probe", False, "exception %r" % (e,))
    finally:
        for p in kids:
            try:
                if p.poll() is None: p.kill()
                p.wait(timeout=5)
            except Exception: pass
        for u in units:
            if not u.startswith("s4e-cage-probe-"): continue
            try:
                if show(u, "ActiveState") in ("active", "failed", "deactivating"):
                    subprocess.run(["systemctl", "--user", "stop", u], capture_output=True, text=True, timeout=10)
                    subprocess.run(["systemctl", "--user", "reset-failed", u], capture_output=True, text=True, timeout=10)
            except Exception: pass
        for k, v in saved.items():
            if v is None: os.environ.pop(k, None)
            else: os.environ[k] = v
        shutil.rmtree(root, ignore_errors=True)
    good = bool(arms) and all(arms)
    print("PROBE-CAGE %s: %d of %d arms ok" % ("GREEN" if good else "RED", sum(1 for x in arms if x), len(arms)))
    return 0 if good else 1
a = sys.argv[1:]
if a[:1] == ["--probe-cage"]: sys.exit(probe_cage())
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
