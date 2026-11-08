#!/usr/bin/env python3
# box_tick.py -- THE FLEET CONTROLLER, ONE PROCESS A MINUTE (DESIGN-PLAN fleet-control steps 4 and 5; the cio, 2026-11-07, on Lon's word:
# "gain control of the CPU problem" / "queue and limit as necessary. use modern industry proven tools"). It replaces box_tick.sh, a shell
# script that forked about 9,000 processes a tick (7 CPU-s quiet, 18 under load, MEASURED 2026-11-07 11:4x). THE LAW: one signal, PSI
# (/proc/pressure/cpu, the kernel's own pressure accounting); one decision a tick for two knobs, the grader width W and the workers awake A;
# the controller alone writes them (W to systemd, the s4e-grade-worker@N instances; A to MODE's WORKERS-AWAKE line and the controller-owned
# FLEET: IDLE EXCEPT list the Stop gate enforces). No seat chooses. A hand-written FLEET line (no "(controller" marker) freezes A: Lon's hand
# outranks the controller, and the controller says so on its TICK line.
#   box_tick.py --tick           one tick: sense, decide, act, print one TICK line; under flock on $TICK_DIR/tick.lock; rc 0
#   box_tick.py --probe-width    the law on planted sensors: quiet raises one step, hot lowers one step, a hold holds; one WIDTH_PSI line, rc 0/1
#   box_tick.py --decide         print the decision for the live sensors without acting
#   box_tick.py --probe-stall    the grader's stall on planted bury lines: one telegram each to cio and coo, one kick, no second telegram; STALL_PROBE line, rc 0/1
#   box_tick.py --probe-lap      the lap (test-cycle step 5b): a full lap put once, a second feed puts nothing, the done mark, one oldest-suite feed; one LAP_PROBE line, rc 0/1
# S4E_TICK_DRY=1: no 2 s sample, no systemctl, no expire, no MODE write, a scratch tick dir; the TICK line still prints with its cpu_s.
# THE LAW OF THE TWO KNOBS (one step a tick at most, a step every S4E_STEP_EVERY ticks, default 2):
#   quiet: cpu PSI avg60 < 25 and avg10 < 25 and no grader memory event  -> W and A go up one (to WMAX, AMAX)
#   hot:   cpu PSI avg60 > 40, or avg10 > 60, or a grader memory event   -> W and A go down one at once (to WMIN, AMIN)
#   else hold. Night (22:00-05:59) or FLEET: IDLE raises WMAX to BOX_WMAX_NIGHT (8); day WMAX is BOX_WMAX_DAY (4). AMAX is S4E_WORKERS_MAX (20).
import os, sys, re, time, json, fcntl, resource, subprocess, glob, shutil, datetime, calendar

ROOT = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PO = os.environ.get("S4E_POSTOFFICE") or os.environ.get("S4E_POST") or "/home/resources/postoffice"
PROG = "/home/resources/progress"
U = "/sys/fs/cgroup/user.slice/user-%d.slice/user@%d.service" % (os.getuid(), os.getuid())
GRADER = U + "/s4e.slice/s4e-grader.slice"
SEATS_SLICE = U + "/s4e.slice/s4e-seats.slice"
DRY = os.environ.get("S4E_TICK_DRY") == "1"
TICK_DIR = os.environ.get("S4E_TICK_DIR") or ("/tmp/s4e/%s/tick" % os.environ.get("S4E_SEAT", "cio"))
STEP_EVERY = int(os.environ.get("S4E_STEP_EVERY", "2"))
WMIN, AMIN = 1, 0
AMAX = int(os.environ.get("S4E_WORKERS_MAX", "20"))
QUIET, HOT60, HOT10 = 25.0, 40.0, 60.0
GRADE_LOG = os.environ.get("S4E_GRADE_LOG") or PROG + "/GRADE_WORKERS.log"
POST = os.environ.get("S4E_POST") or PO
GRADER_HOME = os.environ.get("S4E_GRADER_HOME") or "/home/claude_grader"
STALL_TELL_GAP, STALL_SYNC_EVERY = 3600, 10
STALL_TREE = "could not reach tree"
SYNC_EVERY = int(os.environ.get("S4E_TICK_SYNC_EVERY", "2"))
SYNC_TIMEOUT = 120
PROBING = False


def psi(path):
    try:
        for line in open(path):
            if line.startswith("some"):
                d = dict(kv.split("=") for kv in line.split()[1:])
                return float(d.get("avg10", 0)), float(d.get("avg60", 0)), float(d.get("avg300", 0))
    except OSError:
        pass
    return 0.0, 0.0, 0.0


def read_int(path, default=0):
    try:
        return int(open(path).read().split()[0])
    except (OSError, ValueError, IndexError):
        return default


def mem_events():
    oom = mx = 0
    try:
        for line in open(GRADER + "/memory.events"):
            k, v = line.split()
            if k == "oom": oom = int(v)
            if k == "max": mx = int(v)
    except OSError:
        pass
    return oom, mx


def mode_text():
    try:
        return open(PO + "/MODE").read()
    except OSError:
        return ""


def fleet_idle(mode):
    """Lon's hand idles the fleet: a FLEET: IDLE line without the controller's marker. The controller's own line (FLEET: IDLE EXCEPT <live set> (controller ...)) is the live set, not an idle."""
    m = re.search(r"^FLEET: IDLE.*$", mode, re.M)
    return m is not None and "(controller" not in m.group(0)


def hand_fleet_line(mode):
    m = re.search(r"^FLEET: .*$", mode, re.M)
    return m is not None and "(controller" not in m.group(0)


def wmax(mode):
    hh = time.localtime().tm_hour
    if hh >= 22 or hh < 6 or fleet_idle(mode):
        return int(os.environ.get("BOX_WMAX_NIGHT", "8"))
    return int(os.environ.get("BOX_WMAX_DAY", "4"))


def sense(planted=None):
    s = {}
    if planted:
        s.update(planted)
    else:
        a10, a60, a300 = psi("/proc/pressure/cpu")
        g10, g60, _ = psi(GRADER + "/cpu.pressure")
        s10, s60, _ = psi(SEATS_SLICE + "/cpu.pressure")
        oom, mx = mem_events()
        last = TICK_DIR + "/grader_mem_events.last"
        try:
            lo, lm = [int(x) for x in open(last).read().split()[:2]]
        except (OSError, ValueError):
            lo, lm = oom, mx
        s.update(cpu10=a10, cpu60=a60, cpu300=a300, gcpu10=g10, gcpu60=g60, scpu10=s10, scpu60=s60, mem_rise=int(oom > lo or mx > lm))
        if not DRY:
            os.makedirs(TICK_DIR, exist_ok=True)
            open(last, "w").write("%d %d\n" % (oom, mx))
    s.setdefault("cores", os.cpu_count() or 16)
    s["load1"] = os.getloadavg()[0]
    return s


def current_width():
    w = read_int(TICK_DIR + "/box.width", 0)
    return w if w >= 1 else 2


def current_awake(mode):
    m = re.search(r"^WORKERS-AWAKE: (\d+)", mode, re.M)
    return int(m.group(1)) if m else 0


def one_step(hot, quiet, may_rise):
    if hot: return -1, "hot"
    if quiet and may_rise: return +1, "quiet"
    if quiet: return 0, "quiet-hold"
    return 0, "hold"


def decide(s, w, a, mode, tick_no):
    """one step a tick at most, a step every STEP_EVERY ticks for a rise, at once for a fall.
    EACH ACTUATOR READS ITS OWN SLICE (the coo 2026-11-07 16:05, measured: s4e-seats.slice at its 1200 percent quota read cpu PSI 60 while
    s4e-grader.slice read 0.0, and the box PSI, which counts the seats' throttled tasks, made the tick narrow the grader 8 to 5 for a pressure
    that was not the grader's): W, the grader width, follows s4e-grader.slice's cpu.pressure and the grader memory event; A, the workers awake,
    follows s4e-seats.slice's cpu.pressure. The box PSI stays in the TICK line as a reading. Planted sensors that name only cpu10/cpu60 (the
    older probes) drive both, so the law on them is unchanged."""
    g10 = s.get("gcpu10", s["cpu10"]); g60 = s.get("gcpu60", s["cpu60"])
    s10 = s.get("scpu10", s["cpu10"]); s60 = s.get("scpu60", s["cpu60"])
    mem = s.get("mem_rise", 0) == 1
    WMAX = wmax(mode)
    may_rise = tick_no % STEP_EVERY == 0
    step, why = one_step(g60 > HOT60 or g10 > HOT10 or mem, g60 < QUIET and g10 < QUIET and not mem, may_rise)
    step_a, why_a = one_step(s60 > HOT60 or s10 > HOT10, s60 < QUIET and s10 < QUIET, may_rise)
    nw = min(WMAX, max(WMIN, w + step))
    na = min(AMAX, max(AMIN, a + step_a))
    if fleet_idle(mode):
        na = 0
    return dict(step=step, why="%s/seats:%s" % (why, why_a) if why_a != why else why, W=nw, A=na, WMAX=WMAX, AMAX=AMAX, step_a=step_a, why_a=why_a, gcpu60=g60, scpu60=s60)


def systemctl(*args):
    if DRY:
        return ""
    try:
        return subprocess.run(["systemctl", "--user", *args], capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def scale_grade_workers(W):
    """the grade workers follow THE SWITCH $TICK_DIR/GRADE_WORKERS (on) and W; off stops every instance"""
    try:
        on = open(TICK_DIR + "/GRADE_WORKERS").readline().strip() == "on"
    except OSError:
        on = False
    want = W if on else 0
    running = set()
    for line in systemctl("list-units", "s4e-grade-worker@*", "--no-legend", "--plain", "--state=running").splitlines():
        m = re.match(r"s4e-grade-worker@(\d+)\.service", line.split()[0] if line.split() else "")
        if m: running.add(int(m.group(1)))
    starts = [n for n in range(1, want + 1) if n not in running]
    stops = [n for n in running if n > want]
    for n in starts: systemctl("start", "s4e-grade-worker@%d" % n)
    for n in stops: systemctl("stop", "s4e-grade-worker@%d" % n)
    return "grader on=%d want=%d running=%d starts=%d stops=%d" % (on, want, len(running), len(starts), len(stops))


REQ_DIR = os.environ.get("S4E_TEST_REQUEST_DIR") or "/home/resources/postoffice/test_requests"
GRADE_TUBE = os.environ.get("S4E_GRADE_TUBE") or "grade"
def feed_requests():
    """fleet-control step 10 (the cio, 2026-11-07, Lon: "whatever it takes to get this fleet humming"): a landed row's test request (s4e_test_request.sh, one
    .req file: seat= suite= entries=) becomes ONE request-band grade job (util_grade_job.py put, cell entry:a,b,..., requester the seat) the first tick that
    sees it; the .req gets a fed= line naming the job, and s4e_grade_worker.sh's record step moves it to done/ with the verdict. Nobody but the controller feeds;
    a .req already fed or served is left alone. Returns "fed=N" (N jobs put this tick)."""
    if DRY: return "fed=dry"
    n = 0
    try: names = sorted(x for x in os.listdir(REQ_DIR) if x.endswith(".req"))
    except OSError: return "fed=nodir"
    for name in names:
        path = os.path.join(REQ_DIR, name)
        try: txt = open(path, encoding="utf-8").read().splitlines()
        except OSError: continue
        if any(l.startswith(("fed=", "served=")) for l in txt): continue
        f = dict(l.split("=", 1) for l in txt if "=" in l)
        seat, suite, ents = f.get("seat", "").strip(), f.get("suite", "").strip(), f.get("entries", "").split()
        if not (seat and suite and ents): continue
        r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_grade_job.py"), "put", "--suite", suite, "--cell", "entry:" + ",".join(ents),
                            "--band", "request", "--modes", "m3,m4", "--requester", seat, "--tube", GRADE_TUBE], capture_output=True, text=True, timeout=120)
        jm = re.search(r"^job=(\d+) tube=", r.stdout, re.M); jid = jm.group(1) if jm else ""
        if r.returncode != 0 or not jid.isdigit():
            with open(path, "a") as fh: fh.write("fed=%s REFUSED rc=%d %s\n" % (time.strftime("%FT%TZ", time.gmtime()), r.returncode, (r.stdout + r.stderr).strip().replace("\n", " | ")[-200:]))
            continue
        with open(path, "a") as fh: fh.write("fed=%s job=%s tube=%s cell=entry:%s\n" % (time.strftime("%FT%TZ", time.gmtime()), jid, GRADE_TUBE, ",".join(ents)))
        n += 1
    return "fed=%d" % n
def probe_feed():
    """--probe-feed: a scratch request dir with one .req and a scratch tube; one feed puts one job and writes the fed= line, a second feed puts nothing; the job is deleted.
    Prints FEED_PROBE ...; rc 0 only when ok=1."""
    import tempfile
    global REQ_DIR, GRADE_TUBE
    d = tempfile.mkdtemp(prefix="s4e-feed-probe-", dir="/tmp/s4e/%s" % os.environ.get("S4E_SEAT", "cio")); REQ_DIR = d; GRADE_TUBE = "probe-feed-%d" % os.getpid()
    open(d + "/20260101T000000-probe-sno-rungs-1.req", "w").write("seat=probe\nsuite=sno-rungs\ntable=tests/snobol4\nfiled=probe\nentries=fence_tab_pos_branch_1\nsince=probe\n")
    f1 = feed_requests(); txt = open(d + "/20260101T000000-probe-sno-rungs-1.req").read(); f2 = feed_requests()
    m = re.search(r"^fed=\S+ job=(\d+) tube=(\S+) cell=entry:fence_tab_pos_branch_1$", txt, re.M)
    st = ""
    if m:
        r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_queue.py"), "stats-job", m.group(1)], capture_output=True, text=True, timeout=60); st = r.stdout.strip()
        subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_queue.py"), "delete", m.group(1)], capture_output=True, text=True, timeout=60)
    shutil.rmtree(d, ignore_errors=True)
    ok = int(f1 == "fed=1" and f2 == "fed=0" and m is not None and m.group(2) == GRADE_TUBE and GRADE_TUBE in st)
    print("FEED_PROBE first=%s second=%s fed_line=%d job_in_tube=%d ok=%d" % (f1, f2, int(m is not None), int(bool(st) and GRADE_TUBE in st), ok)); return 0 if ok else 1
def grader_tail():
    """the last three lines of GRADE_WORKERS.log and how many of them read the stall: action=bury naming the unreachable tree"""
    try:
        lines = open(GRADE_LOG, encoding="utf-8", errors="replace").read().splitlines()[-3:]
    except OSError:
        lines = []
    return lines, sum(1 for l in lines if "action=bury" in l and STALL_TREE in l)


def tube_buried(tube):
    r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_queue.py"), "stats-tube", tube], capture_output=True, text=True, timeout=30)
    m = re.search(r"buried=(\d+)", r.stdout)
    return int(m.group(1)) if m and r.returncode == 0 else 0


def kick_tube(tube, n):
    r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_queue.py"), "kick", tube, str(n)], capture_output=True, text=True, timeout=30)
    try:
        return int(r.stdout.strip()) if r.returncode == 0 else 0
    except ValueError:
        return 0


def sync_grader():
    """the grader root syncs by util_sync_root.sh under its own S4E_HOME; rc 0 is the only go to kick. The probe names its rc (S4E_STALL_PROBE_SYNC_RC)."""
    forced = os.environ.get("S4E_STALL_PROBE_SYNC_RC")
    if forced is not None:
        return int(forced)
    try:
        return subprocess.run(["bash", os.path.join(ROOT, "harness", "scripts", "util_sync_root.sh")], env=dict(os.environ, S4E_HOME=GRADER_HOME),
                              capture_output=True, text=True, timeout=600, stdin=subprocess.DEVNULL).returncode
    except (OSError, subprocess.TimeoutExpired):
        return 2


def tell_stall(lines, when):
    """the one telegram of an alarm: the three log lines and the cure in words, to the cio and the coo through s4e_msg.sh send; returns how many were sent"""
    body = ("The grader root could not reach its tree three times running. Its last three GRADE_WORKERS log lines:\n" + "\n".join(lines) +
            "\nThe cure, in words: rebase the grader root's repos onto origin main (each of its harness and .github carries one local commit that is not on origin),"
            " then the controller kicks the buried grade jobs once the sync reads clean.\n")
    told = 0
    for seat in ("cio", "coo"):
        r = subprocess.run(["bash", os.path.join(ROOT, "harness", "scripts", "s4e_msg.sh"), "send", seat, "grader-stalled-" + when, "--stdin"], input=body,
                           capture_output=True, text=True, timeout=60, env=dict(os.environ, S4E_POST=POST, S4E_SEAT="cio", S4E_NO_BANNER="1"))
        told += int(r.returncode == 0)
    return told


def watch_grader(n):
    """test-cycle step 10 (the cio, 2026-11-08, CTO baton test-cycle-step-10): THE ALARM: the last three GRADE_WORKERS.log lines all read action=bury naming
    the unreachable tree -> ONE telegram each to the cio and the coo, stamped in TICK_DIR/stall.told; no second within STALL_TELL_GAP seconds.
    THE KICK: the grade tube holds buried jobs and the grader root syncs rc 0 (tried at most once every STALL_SYNC_EVERY ticks) -> one kick of them.
    Nobody else kicks. Returns the dict the tick prints (line) and BOX.state keeps (alarm)."""
    lines, buries = grader_tail()
    out = dict(buries=buries, alarm=int(buries == 3), told=0, kicked=0, buried=0)
    if DRY:
        out["line"] = "stall=dry"; return out
    if out["alarm"] and time.time() - read_int(TICK_DIR + "/stall.told", 0) >= STALL_TELL_GAP:
        out["told"] = tell_stall(lines, time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()))
        if out["told"]:
            open(TICK_DIR + "/stall.told", "w").write("%d\n" % int(time.time()))
    out["buried"] = tube_buried(GRADE_TUBE)
    if out["buried"] > 0:
        stamp = TICK_DIR + "/stall.sync_tick"
        if n - read_int(stamp, -STALL_SYNC_EVERY) >= STALL_SYNC_EVERY:
            open(stamp, "w").write("%d\n" % n)
            if sync_grader() == 0:
                out["kicked"] = kick_tube(GRADE_TUBE, out["buried"])
    out["line"] = "stall=%d/told=%d/kicked=%d" % (out["alarm"], out["told"], out["kicked"])
    return out


def probe_stall():
    """--probe-stall (test-cycle step 10): a scratch GRADE_WORKERS.log with three planted bury lines, a scratch post office (cio and coo inboxes), a
    scratch tick dir and a scratch tube holding one put-buried job, the sync replaced by S4E_STALL_PROBE_SYNC_RC=0. The first watch tells two seats and
    kicks the job; the second tells nobody. Prints STALL_PROBE ...; rc 0 only when ok=1; the job is deleted."""
    import tempfile
    global GRADE_LOG, POST, GRADE_TUBE, TICK_DIR
    base = "/tmp/s4e/%s" % os.environ.get("S4E_SEAT", "cio"); os.makedirs(base, exist_ok=True)
    d = tempfile.mkdtemp(prefix="s4e-stall-probe-", dir=base)
    GRADE_LOG = d + "/GRADE_WORKERS.log"; POST = d + "/post"; TICK_DIR = d + "/tick"; GRADE_TUBE = "probe-stall-%d" % os.getpid()
    os.makedirs(POST + "/cio/inbox"); os.makedirs(POST + "/coo/inbox"); os.makedirs(TICK_DIR)
    planted = ["2026-11-08T12:59:19Z worker=5 job=1246 suite=gimpel cell=core modes=m3,m4 rc=2 action=bury secs=1 reason=refused: the grader root could not reach tree b75a4c594 (sync rc 1, make rc -): fatal: Not possible to fast-forward, aborting.",
               "2026-11-08T13:00:02Z worker=6 job=1247 suite=roast cell=core modes=m3,m4 rc=2 action=bury secs=1 reason=refused: the grader root could not reach tree b75a4c594 (sync rc 1, make rc -): fatal: Not possible to fast-forward, aborting.",
               "2026-11-08T13:00:40Z worker=7 job=1248 suite=unitests cell=entry:general/var modes=m3,m4 rc=2 action=bury secs=1 reason=refused: the grader root could not reach tree b75a4c594 (sync rc 1, make rc -): fatal: Not possible to fast-forward, aborting."]
    open(GRADE_LOG, "w").write("\n".join(planted) + "\n")
    os.environ["S4E_STALL_PROBE_SYNC_RC"] = "0"
    jid = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_queue.py"), "put-buried", GRADE_TUBE, "probe-stall-job"],
                         capture_output=True, text=True, timeout=60).stdout.strip()
    w1 = watch_grader(10); w2 = watch_grader(11)
    if jid.isdigit():
        subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_queue.py"), "delete", jid], capture_output=True, text=True, timeout=60)
    os.environ.pop("S4E_STALL_PROBE_SYNC_RC", None)
    shutil.rmtree(d, ignore_errors=True)
    ok = int(w1["buries"] == 3 and w1["told"] == 2 and w1["kicked"] == 1 and w2["told"] == 0)
    print("STALL_PROBE buries=%d told=%d kicked=%d second_told=%d ok=%d" % (w1["buries"], w1["told"], w1["kicked"], w2["told"], ok)); return 0 if ok else 1
LAP_TSV = os.environ.get("S4E_LAP_TSV") or (PROG + "/LAP.tsv")
FEED_TSV = os.environ.get("S4E_FEED_TSV") or (PROG + "/FEED.tsv")
SUITES_TSV = os.environ.get("S4E_SUITES_TSV") or (PROG + "/SUITES.tsv")
RUNNERS_TSV = os.path.join(ROOT, "harness", "scripts", "SUITE_RUNNERS.tsv")
def _rows(path):
    try: return [l.rstrip("\n").split("\t") for l in open(path, encoding="utf-8") if l.strip() and not l.startswith("#")]
    except OSError: return []
def _now(): return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
def _utc(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _append(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh: fh.write(text + "\n")
def lap_tree():
    try: return subprocess.run(["git", "-C", os.path.join(ROOT, "SCRIP"), "rev-parse", "--short=9", "origin/main"], capture_output=True, text=True, check=True, timeout=20).stdout.strip()
    except Exception: return "0000000"
def master_pkg_rows(): return [r for r in _rows(RUNNERS_TSV) if len(r) >= 5 and r[1] in ("master", "pkg")]
def suite_cells(r):
    """the cells of one SUITE_RUNNERS row: core and every chunk:NN of its PARTITION.tsv (table corpus/tests/<lang> for a master, the table column for a pkg)"""
    d = os.path.join(ROOT, "corpus", "tests", r[2]) if r[1] == "master" else os.path.join(ROOT, r[4])
    rows = _rows(os.path.join(d, "PARTITION.tsv"))
    if len(rows) < 2 or "part" not in rows[0]: return []
    ip = rows[0].index("part")
    parts = {x[ip] for x in rows[1:] if len(x) > ip and (x[ip] == "core" or x[ip].startswith("chunk:"))}
    return sorted(parts, key=lambda c: (c != "core", c))
def suite_date(key):
    for r in _rows(SUITES_TSV):
        if r[0] == key and len(r) > 7: return r[7].strip()
    return ""
def fed_recently(key, now):
    for f in _rows(FEED_TSV):
        if len(f) >= 4 and f[3] == key:
            try:
                if (now - datetime.datetime.strptime(f[2], "%Y-%m-%dT%H:%M:%SZ")).total_seconds() < 86400: return True
            except ValueError: continue
    return False
def pick_suite(now):
    """the pick rule (test-cycle step 5b, the re-cut of 2026-11-08): the master or pkg row whose SUITES.tsv today_date is OLDEST and older than 24 h,
    not fed in the last 24 h (FEED.tsv); ties by SUITE_RUNNERS.tsv row order. Returns the row or None."""
    best = None
    for order, r in enumerate(master_pkg_rows()):
        try: dt = datetime.datetime.strptime(suite_date(r[0]), "%Y-%m-%d")
        except ValueError: continue
        if (now - dt).total_seconds() <= 86400: continue
        if fed_recently(r[0], now) or not suite_cells(r): continue
        key = (dt, order)
        if best is None or key < best[0]: best = (key, r)
    return None if best is None else best[1]
def lap_put_today():
    t = time.localtime()
    for r in _rows(LAP_TSV):
        if len(r) >= 5 and r[0] == "lap" and r[2] == "put":
            try: u = time.localtime(calendar.timegm(time.strptime(r[4], "%Y-%m-%dT%H:%M:%SZ")))
            except ValueError: continue
            if (u.tm_year, u.tm_yday) == (t.tm_year, t.tm_yday): return True
    return False
def tube_load(tube):
    """ready plus reserved jobs of the tube; an absent tube holds none"""
    r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_queue.py"), "stats-tube", tube], capture_output=True, text=True, timeout=30)
    out = r.stdout + r.stderr
    if "unreachable" in out: raise RuntimeError("beanstalkd unreachable")
    m1 = re.search(r"ready=(\d+)", out); m2 = re.search(r"reserved=(\d+)", out)
    if m1 and m2: return int(m1.group(1)) + int(m2.group(1))
    if "NOT_FOUND" in out: return 0
    raise RuntimeError("stats-tube %s: %s" % (tube, out.strip()[:120].replace("\n", " | ")))
def put_cells(cells, tree, tube):
    """ONE put-many call (util_grade_job.py, step 5a): one line per cell, band lap, one job id back per cell in order; a short count refuses"""
    r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "harness", "scripts", "util_grade_job.py"), "put-many", "--band", "lap", "--tree", tree, "--tube", tube, "--requester", "lap", "--stdin"],
                       input="".join("%s\t%s\n" % sc for sc in cells), capture_output=True, text=True, timeout=600)
    jobs = [int(m.group(1)) for m in re.finditer(r"^job=(\d+) tube=", r.stdout, re.M)]
    if r.returncode != 0 or len(jobs) != len(cells):
        raise RuntimeError("put-many rc=%d put=%d of %d: %s" % (r.returncode, len(jobs), len(cells), (r.stdout + r.stderr).strip()[-160:].replace("\n", " | ")))
    return jobs
def _record_feed(cells, jobs, tree):
    utc = _utc()
    for (s, c), j in zip(cells, jobs): _append(FEED_TSV, "\t".join(["lap", tree, utc, s, c, "0", str(j)]))
def _feed_lap():
    """THE LAP (test-cycle step 5b; design text skill suites-and-grading section 7): (a) a full lap at the first tick of local hour 22 with no lap put that day,
    (b) a full lap when LAP.tsv holds no lap line, (c) otherwise ONE suite by the pick rule, only when the grade tube is empty and no lap is being put.
    A lap put with the tube empty again is marked done. Returns (kind, cells, suite) with kind none | lap | suite | done."""
    tube = GRADE_TUBE
    last = None
    for r in _rows(LAP_TSV):
        if len(r) >= 6 and r[0] == "lap": last = r
    if last is not None and last[2] == "put":
        if tube_load(tube) == 0:
            _append(LAP_TSV, "\t".join(["lap", last[1], "done", tube, _utc(), last[5]]))
            return "done", 0, ""
        return "none", 0, ""
    if tube_load(tube) != 0: return "none", 0, ""
    if last is None or (time.localtime().tm_hour == 22 and not lap_put_today()):
        cells = [(r[0], c) for r in master_pkg_rows() for c in suite_cells(r)]
        if not cells: return "none", 0, ""
        tree = lap_tree(); jobs = put_cells(cells, tree, tube)
        _append(LAP_TSV, "\t".join(["lap", tree, "put", tube, _utc(), "cells=%d" % len(cells)]))
        _record_feed(cells, jobs, tree)
        return "lap", len(cells), ""
    r = pick_suite(_now())
    if r is None: return "none", 0, ""
    cells = [(r[0], c) for c in suite_cells(r)]
    tree = lap_tree(); jobs = put_cells(cells, tree, tube); _record_feed(cells, jobs, tree)
    return "suite", len(cells), r[0]
def feed_lap():
    """the tick's lap line: lap=none:0 | lap=lap:N | lap=suite:N:KEY | lap=done:0; a refusal reads lap=refused(...) and never stops the tick"""
    if DRY: return "lap=dry"
    try: kind, n, key = _feed_lap()
    except Exception as e: return "lap=refused(%s)" % str(e).replace(" ", "_")[:120]
    return "lap=%s:%d%s" % (kind, n, (":" + key) if key else "")
def probe_lap():
    """--probe-lap: scratch LAP, FEED and SUITES files and a scratch tube probe-lap-<pid>. Phase 1: a first feed puts every cell (kind lap). Phase 2: a second feed
    with the tube non-empty puts nothing. The probe deletes every job; phase 3: a third feed writes the done line. Phase 4: a scratch SUITES.tsv with the first
    master or pkg suite dated 2026-01-01, a fresh FEED file, one feed puts exactly that suite (fresh=1). Prints LAP_PROBE; rc 0 only when ok=1."""
    import tempfile
    global LAP_TSV, FEED_TSV, SUITES_TSV, GRADE_TUBE
    saved = (LAP_TSV, FEED_TSV, SUITES_TSV, GRADE_TUBE)
    d = tempfile.mkdtemp(prefix="s4e-lap-probe-", dir="/tmp/s4e/%s" % os.environ.get("S4E_SEAT", "cio"))
    GRADE_TUBE = "probe-lap-%d" % os.getpid(); LAP_TSV = d + "/LAP.tsv"; FEED_TSV = d + "/FEED.tsv"
    sys.path.insert(0, os.path.join(ROOT, "harness", "scripts")); import util_queue
    gs, c = util_queue.client()
    def jobs_fed(): return [int(f[6]) for f in _rows(FEED_TSV) if len(f) >= 7 and f[0] == "lap" and f[6].isdigit()]
    def drain():
        n = 0
        for j in jobs_fed():
            try: c.delete(j); n += 1
            except gs.NotFoundError: pass
        return n
    tables = len(master_pkg_rows()); ok = 0; k4 = ""; fresh = 0
    try:
        k1, n1, _ = _feed_lap(); jobs1 = jobs_fed()
        k2, n2, _ = _feed_lap()
        deleted = drain()
        k3, n3, _ = _feed_lap()
        done = int(any(len(r) >= 3 and r[0] == "lap" and r[2] == "done" for r in _rows(LAP_TSV)))
        planted = next((r for r in master_pkg_rows() if suite_cells(r)), None)
        if planted is not None:
            out = []
            for l in open(saved[2], encoding="utf-8").read().splitlines(keepends=True):
                f = l.rstrip("\n").split("\t")
                if not l.startswith("#") and len(f) > 7 and f[0] == planted[0]: f[7] = "2026-01-01"; l = "\t".join(f) + "\n"
                out.append(l)
            open(d + "/SUITES.tsv", "w", encoding="utf-8").write("".join(out))
            SUITES_TSV = d + "/SUITES.tsv"; FEED_TSV = d + "/FEED4.tsv"
            k4, n4, key4 = _feed_lap()
            expected = len(suite_cells(planted))
            fresh = int(k4 == "suite" and key4 == planted[0] and n4 == expected and n4 > 0)
            drain()
        ok = int(k1 == "lap" and n1 > 0 and len(jobs1) == n1 and k2 == "none" and n2 == 0 and deleted == n1 and k3 == "done" and done == 1 and fresh == 1)
    except Exception as e:
        print("LAP_PROBE refused: %s" % str(e)[:160]); ok = 0; n1 = n2 = done = fresh = 0
    finally:
        try: drain()
        except Exception: pass
        c.close()
        LAP_TSV, FEED_TSV, SUITES_TSV, GRADE_TUBE = saved
        shutil.rmtree(d, ignore_errors=True)
    print("LAP_PROBE tables=%d cells=%d put=%d second=%d done=%d fresh=%d ok=%d" % (tables, n1, n1, n2, done, fresh, ok))
    return 0 if ok else 1
def alive_seats():
    """the seats whose claude session is alive, read from the sessions' working directories (no seat pattern: the root names the seat)"""
    seats = set()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            if open("/proc/%s/comm" % pid).read().strip() != "claude":
                continue
            cwd = os.readlink("/proc/%s/cwd" % pid)
        except OSError:
            continue
        m = re.match(r"/home/claude_([a-z0-9_]+)", cwd)
        if m: seats.add(m.group(1))
    return seats


def write_live_set(A, mode):
    """fleet-control step 5: a FLEET line the controller owns (it carries "(controller") lists cio and the first A workers alive, by number;
    a worker beyond A is dropped from the list and stops at its Stop; a hand-written FLEET line is never touched"""
    m = re.search(r"^FLEET: IDLE EXCEPT (.*?) \((controller.*)\)$", mode, re.M)
    if DRY or not m:
        return "liveset=hand" if not m else "liveset=dry"
    keep = [x for x in m.group(1).split() if not x.startswith(("worker_", "junior_"))]
    alive = alive_seats()
    workers = sorted((x for x in alive if x.startswith(("worker_", "junior_"))), key=lambda x: int(x.split("_")[1]))[:A]
    seniors = sorted(x for x in alive if not x.startswith(("worker_", "junior_")) and x not in keep)   # Lon 2026-11-07 13:5x ("fire any combination of Haiku, Sonnet, and Opus"):
    live = keep + seniors + workers   # every alive company man or officer is in the live set too; only the workers are counted against A
    line = "FLEET: IDLE EXCEPT %s (controller %s: cio and the first %d workers alive by the law of fleet-control step 5; a worker beyond the count stops at its Stop; Lon's hand replaces this line at will)" % (" ".join(live), time.strftime("%Y-%m-%d %H:%M"), A)
    if line.split(" (controller")[0] == m.group(0).split(" (controller")[0]:
        return "liveset=%d" % len(workers)
    new = mode.replace(m.group(0), line, 1)
    tmp = PO + "/MODE.tmp.%d" % os.getpid()
    open(tmp, "w").write(new); os.replace(tmp, PO + "/MODE")
    return "liveset=%d(written)" % len(workers)


def write_awake(A, why, s, mode):
    """the controller alone writes WORKERS-AWAKE; a hand-written FLEET line freezes it (Lon's hand outranks the controller)"""
    if DRY or hand_fleet_line(mode) or not os.path.isfile(PO + "/MODE"):
        return "awake=frozen-by-hand" if hand_fleet_line(mode) else "awake=dry"
    cur = current_awake(mode)
    if cur == A:
        return "awake=%d" % A
    stamp = time.strftime("%Y-%m-%d %H:%M")
    line = "WORKERS-AWAKE: %d (controller %s: %s, cpu PSI avg60 %.1f avg10 %.1f, was %d; fleet-control step 5)" % (A, stamp, why, s["cpu60"], s["cpu10"], cur)
    new = re.sub(r"^WORKERS-AWAKE: .*$", line, mode, count=1, flags=re.M) if re.search(r"^WORKERS-AWAKE:", mode, re.M) else mode.rstrip("\n") + "\n" + line + "\n"
    bak = PO + "/MODE.bak-%s-controller" % time.strftime("%Y-%m-%d")
    if not os.path.exists(bak):
        shutil.copy(PO + "/MODE", bak)
    tmp = PO + "/MODE.tmp.%d" % os.getpid()
    open(tmp, "w").write(new); os.replace(tmp, PO + "/MODE")
    return "awake=%d(was %d)" % (A, cur)


def expire_leases():
    """fleet-queue step 5 kept: a RESERVED claim whose job is back in its tube is expired by the bus verb; every fifth tick"""
    n = 0
    for c in glob.glob(PO + "/claims/*.claim"):
        try:
            t = open(c).read()
        except OSError:
            continue
        if "RESERVED job=" not in t or "\nDONE" in t or "\nBURIED" in t or "\nPARK " in t:
            continue
        topic = os.path.basename(c)[:-6]
        if DRY:
            n += 1; continue
        r = subprocess.run(["timeout", "60", "bash", ROOT + "/harness/scripts/s4e_msg.sh", "expire", topic],
                           capture_output=True, text=True, env=dict(os.environ, S4E_NO_BANNER="1"), stdin=subprocess.DEVNULL)
        if r.returncode == 0:
            n += 1
            with open(TICK_DIR + "/leases.log", "a") as f:
                f.write("%s %s\n" % (time.strftime("%F %T"), (r.stdout.strip().splitlines() or [""])[-1][:200]))
    return n


def view_stamp():
    try:
        st = "%.9f %.9f" % (os.stat(PO + "/tasks").st_mtime, os.stat(PO + "/claims").st_mtime)
    except OSError:
        st = "?"
    try:
        tubes = subprocess.run(["python3", ROOT + "/harness/scripts/util_queue.py", "tubes"], capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.TimeoutExpired):
        tubes = ""
    return st + "|" + str(hash(tubes))


def regenerate_view():
    """the queue view QUEUE.tsv is regenerated only when its inputs moved (tasks, claims, the tubes)"""
    if DRY:
        return "view=dry"
    stamp = view_stamp()
    try:
        last = open(TICK_DIR + "/view.stamp").read()
    except OSError:
        last = ""
    if stamp == last:
        return "view=kept"
    r = subprocess.run(["python3", ROOT + "/harness/scripts/util_queue_view.py", "--regenerate"], capture_output=True, text=True, timeout=120)
    if r.returncode == 0:
        open(TICK_DIR + "/view.stamp", "w").write(stamp)
        return "view=regenerated"
    return "view=failed"


RESULTS_TAIL = 8388608


def rows_recent(seconds):
    cut = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(time.time() - seconds))
    try:
        with open(PROG + "/results.tsv", "rb") as f:
            size = f.seek(0, 2)
            f.seek(max(0, size - RESULTS_TAIL))
            lines = f.read().decode("utf-8", "replace").split("\n")
    except OSError:
        return 0
    if size > RESULTS_TAIL:
        lines = lines[1:]
    return sum(1 for ln in lines if ln[:4].isdigit() and ln[:19] >= cut)


def sync_summary(text):
    """the probe's word for one TICK line's sync field: ok:<moved repos joined by +, or none>, refused, or skipped"""
    m = re.search(r"sync=(?:ok moved=(\S+)|(refused)|(skipped))", text)
    if not m:
        return "no-sync-field"
    if m.group(1):
        return "ok:" + m.group(1)
    return "refused" if m.group(2) else "skipped"


def sync_root(n):
    """test-cycle step 12 (the cio, 2026-11-08): THE CONTROLLER SYNCS ITS OWN ROOT at the top of the tick, before any decision, so a landed change to this
    file is live within two minutes without a seat. util_sync_root.sh runs under ROOT (fast-forward only, every fetch under the s4e-fetch slot), at most
    once every SYNC_EVERY ticks. Returns dict(kind=ok|refused|skipped, moved=[repos that fast-forwarded], disp=the TICK line's sync= text). A refusal
    (rc 1 or 2, a timeout) is named on the TICK line and in BOX.state, never a silence; the tick goes on with the tree it has."""
    import signal
    stamp = TICK_DIR + "/sync.tick"
    if n - read_int(stamp, -SYNC_EVERY) < SYNC_EVERY:
        return dict(kind="skipped", moved=[], disp="sync=skipped")
    open(stamp, "w").write("%d\n" % n)
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "util_sync_root.sh")
    p = subprocess.Popen(["bash", script], env=dict(os.environ, S4E_HOME=ROOT), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        out, _ = p.communicate(timeout=SYNC_TIMEOUT); rc = p.returncode
    except subprocess.TimeoutExpired:
        try: os.killpg(p.pid, signal.SIGKILL)
        except OSError: pass
        out, _ = p.communicate(); rc = 2
        out = "sync timed out after %d s\n%s" % (SYNC_TIMEOUT, out or "")
    lines = (out or "").splitlines()
    moved = []
    for ln in lines:
        m = re.match(r"^SYNC (\S+) (\S+)\.\.(\S+)$", ln)
        if m and m.group(2) != m.group(3):
            moved.append(m.group(1))
    if rc == 0:
        return dict(kind="ok", moved=moved, disp="sync=ok moved=%s" % ("+".join(moved) or "none"))
    first = next((ln for ln in lines if "REFUSE" in ln), (lines or ["rc=%d" % rc])[0]).strip()
    return dict(kind="refused", moved=moved, disp="sync=refused:%s" % first)


def probe_sync():
    """--probe-sync (test-cycle step 12): four LOCAL BARE origins (SCRIP, corpus, harness, .github), each given two commits of one file; a scratch root cloned
    from them with harness reset one commit behind its origin. Three dry ticks on the scratch root, a scratch tick dir, no re-exec: the first fast-forwards
    harness (sync=ok moved=harness), the second moves nothing (sync=ok moved=none); then a planted local commit in the scratch harness and a third commit
    pushed to its origin make the third refuse (sync=refused). Prints SYNC_PROBE first= second= third= ok=; rc 0 only when ok=1. Writes only under a scratch dir."""
    import tempfile, contextlib, io
    global ROOT, TICK_DIR, SYNC_EVERY, DRY, PROBING
    saved = (ROOT, TICK_DIR, SYNC_EVERY, DRY, PROBING)
    base = "/tmp/s4e/%s" % os.environ.get("S4E_SEAT", "cio"); os.makedirs(base, exist_ok=True)
    d = tempfile.mkdtemp(prefix="s4e-sync-probe-", dir=base)
    who = dict(GIT_AUTHOR_NAME="s4e-probe", GIT_AUTHOR_EMAIL="probe@s4e.invalid", GIT_COMMITTER_NAME="s4e-probe", GIT_COMMITTER_EMAIL="probe@s4e.invalid")
    def git(*a, cwd=None):
        r = subprocess.run(["git", "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main", *a], cwd=cwd, capture_output=True, text=True, timeout=60,
                           env=dict(os.environ, **who))
        if r.returncode != 0:
            raise RuntimeError("git %s: %s" % (a[0], r.stderr.strip()[:200]))
        return r.stdout
    def commit(cwd, text, msg):
        with open(os.path.join(cwd, "f.txt"), "a") as fh: fh.write(text)
        git("add", "f.txt", cwd=cwd); git("commit", "-q", "-m", msg, cwd=cwd)
    repos = ["SCRIP", "corpus", "harness", ".github"]
    summary, err = [], ""
    try:
        origin, work, root = d + "/origin", d + "/work", d + "/root"
        for p in (origin, work, root): os.makedirs(p)
        for r in repos:
            bare, w = origin + "/" + r + ".git", work + "/" + r
            git("init", "-q", "--bare", "-b", "main", bare)
            git("init", "-q", "-b", "main", w)
            git("remote", "add", "origin", bare, cwd=w)
            commit(w, "one\n", "c1"); commit(w, "two\n", "c2")
            git("push", "-q", "origin", "main", cwd=w)
        for r in repos:
            git("clone", "-q", origin + "/" + r + ".git", root + "/" + r)
        git("reset", "-q", "--hard", "HEAD~1", cwd=root + "/harness")
        ROOT, TICK_DIR, SYNC_EVERY, DRY, PROBING = root, d + "/tick", 1, True, True
        ticks = []
        for _ in range(2):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf): tick()
            ticks.append(buf.getvalue())
        commit(root + "/harness", "local\n", "planted local commit")
        commit(work + "/harness", "third\n", "third commit on origin")
        git("push", "-q", "origin", "main", cwd=work + "/harness")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf): tick()
        ticks.append(buf.getvalue())
        summary = [sync_summary(t) for t in ticks]
    except Exception as e:
        err = str(e)[:200]
    finally:
        ROOT, TICK_DIR, SYNC_EVERY, DRY, PROBING = saved
        shutil.rmtree(d, ignore_errors=True)
    first, second, third = (summary + ["none", "none", "none"])[:3]
    ok = int(not err and first == "ok:harness" and second == "ok:none" and third == "refused")
    print("SYNC_PROBE first=%s second=%s third=%s ok=%d%s" % (first, second, third, ok, (" error=" + err) if err else ""))
    return 0 if ok else 1


def tick():
    os.makedirs(TICK_DIR, exist_ok=True)
    lock = open(TICK_DIR + "/tick.lock", "a+")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("REFUSE(3): another tick holds %s/tick.lock" % TICK_DIR); return 3
    t0 = time.time()
    n = read_int(TICK_DIR + "/tick.count", 0) + 1
    if "S4E_TICK_REEXECED" in os.environ:
        sy = json.loads(os.environ.pop("S4E_TICK_REEXECED"))
    else:
        sy = sync_root(n)
        if "harness" in sy["moved"] and not PROBING:
            os.environ["S4E_TICK_REEXECED"] = json.dumps(sy)
            sys.stdout.flush()
            os.execv(sys.executable, sys.orig_argv)
    open(TICK_DIR + "/tick.count", "w").write("%d\n" % n)
    mode = mode_text()
    s = sense(dict(cpu10=4.0, cpu60=4.0, cpu300=4.0, gcpu10=1.0, mem_rise=0) if DRY else None)
    w, a = current_width(), current_awake(mode)
    d = decide(s, w, a, mode, n)
    open(TICK_DIR + "/box.width", "w").write("%d\n" % d["W"])
    grader = scale_grade_workers(d["W"])
    awake = write_awake(d["A"], d["why"], s, mode)
    liveset = write_live_set(d["A"], mode_text())
    expired = expire_leases() if n % 5 == 0 else 0
    fed = feed_requests()
    st = watch_grader(n)
    lapfeed = feed_lap()
    view = regenerate_view()
    with open(TICK_DIR + "/decide.last", "w") as f:
        f.write(json.dumps(dict(tick=n, sensors=s, decision=d, grader=grader, awake=awake, liveset=liveset, expired=expired, fed=fed, lap=lapfeed, view=view)) + "\n")
    # BOX.state: the controller is its writer (the coo 2026-11-07 15:29: the retired box_controller's file had no writer and its readers, the coo's OPS line, opswatch and
    # fleet_health.py, read a 520 s old width of 2). The old keys that still mean something keep their names (ts busy cores cpu_psi10 cpu_psi60 grader_width action); the rest are the tick's.
    try:
        if DRY: raise RuntimeError("dry tick writes no state")
        gq = 0
        try: gq = int(re.search(r"ready=(\d+)", subprocess.run(["python3", "-I", ROOT + "/harness/scripts/util_queue.py", "stats-tube", GRADE_TUBE], capture_output=True, text=True, timeout=10).stdout).group(1))
        except Exception: pass
        rph, lap = rows_recent(3600), rows_recent(86400)
        with open(PROG + "/BOX.state.tmp", "w") as f:
            f.write("ts=%s\nbusy=%.1f\ncores=%d\ncpu_psi10=%.1f\ncpu_psi60=%.1f\ncpu_psi300=%.1f\ngrader_width=%d\ngrader_wmax=%d\nworkers_awake=%d\nworkers_max=%d\naction=%s\ngrader_queue=%d\ngrader_stall=%d\ncontroller=box_tick.py\ntick=%d\ncontroller_sync=%s\nrows_per_hour=%d\nlap_rows_24h=%d\n%s\n%s\n"
                    % (time.strftime("%Y-%m-%dT%H:%M:%S%z"), s["load1"], os.cpu_count() or 16, s["cpu10"], s["cpu60"], s["cpu300"], d["W"], d["WMAX"], d["A"], d["AMAX"], d["why"], gq, st["alarm"], n, sy["kind"], rph, lap,
                       grader.replace(" ", "\n").replace("grader\n", "grader_"), liveset if liveset.startswith("liveset=") else "liveset=" + liveset))
        os.replace(PROG + "/BOX.state.tmp", PROG + "/BOX.state")
    except Exception as e:
        print("BOX.state not written: %s" % e)
    ru = resource.getrusage(resource.RUSAGE_SELF); rc = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_s = ru.ru_utime + ru.ru_stime + rc.ru_utime + rc.ru_stime
    print("TICK unit=s4e-tick.timer controller=box_tick.py tick=%d psi10=%.1f psi60=%.1f psi300=%.1f load1=%.1f mem_rise=%d step=%+d why=%s W=%d/%d A=%d/%d %s %s %s %s expired=%d %s %s %s %s secs=%d cpu_s=%.2f%s"
          % (n, s["cpu10"], s["cpu60"], s["cpu300"], s["load1"], s.get("mem_rise", 0), d["step"], d["why"], d["W"], d["WMAX"], d["A"], d["AMAX"],
             sy["disp"], grader, awake, liveset, expired, fed, view, lapfeed, st["line"], int(time.time() - t0), cpu_s, " dry=1" if DRY else ""))
    return 0


def probe_width():
    """the law on planted sensors: quiet raises one step on a rise tick, hot lowers one at once, a middling reading holds"""
    mode = "TENET\n"
    q = decide(dict(cpu10=5.0, cpu60=5.0, mem_rise=0), 2, 4, mode, 2)
    h = decide(dict(cpu10=70.0, cpu60=45.0, mem_rise=0), 2, 4, mode, 2)
    m = decide(dict(cpu10=30.0, cpu60=30.0, mem_rise=0), 2, 4, mode, 2)
    r = decide(dict(cpu10=5.0, cpu60=5.0, mem_rise=1), 2, 4, mode, 2)
    hold_odd = decide(dict(cpu10=5.0, cpu60=5.0, mem_rise=0), 2, 4, mode, 1)
    ok = int(q["step"] == 1 and q["W"] == 3 and q["A"] == 5 and h["step"] == -1 and h["W"] == 1 and h["A"] == 3
             and m["step"] == 0 and r["step"] == -1 and hold_odd["step"] == 0 and q["W"] <= q["WMAX"])
    # the slices are read apart (the coo 2026-11-07 16:05): a hot seats slice beside a quiet grader slice lowers A and raises W; the reverse lowers W and raises A
    sp = decide(dict(cpu10=70.0, cpu60=60.0, gcpu10=1.0, gcpu60=0.0, scpu10=70.0, scpu60=60.0, mem_rise=0), 2, 4, mode, 2)
    gp = decide(dict(cpu10=30.0, cpu60=30.0, gcpu10=70.0, gcpu60=60.0, scpu10=5.0, scpu60=5.0, mem_rise=0), 2, 4, mode, 2)
    split_ok = int(sp["step"] == 1 and sp["W"] == 3 and sp["A"] == 3 and gp["step"] == -1 and gp["W"] == 1 and gp["A"] == 5)
    ok = ok and split_ok
    print("WIDTH_PSI quiet=%+d hot=%+d middling=%+d mem_rise=%+d odd_tick=%+d W=%d->%d/%d A=%d->%d seats_hot_grader_quiet=W%+d/A%+d grader_hot_seats_quiet=W%+d/A%+d split_ok=%d ok=%d"
          % (q["step"], h["step"], m["step"], r["step"], hold_odd["step"], 2, q["W"], q["WMAX"], 4, q["A"], sp["step"], sp["step_a"], gp["step"], gp["step_a"], split_ok, ok))
    return 0 if ok else 1


def probe_rows():
    try:
        tail = min(os.path.getsize(PROG + "/results.tsv"), RESULTS_TAIL)
    except OSError:
        tail = 0
    h, d = rows_recent(3600), rows_recent(86400)
    ok = 1 if tail > 0 else 0
    print("ROWS_PROBE rows_per_hour=%d lap_rows_24h=%d tail_bytes=%d ok=%d" % (h, d, tail, ok))
    return 0 if ok else 1


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "--tick"
    if arg == "--tick":
        sys.exit(tick())
    if arg == "--probe-width":
        sys.exit(probe_width())
    if arg == "--probe-rows":
        sys.exit(probe_rows())
    if arg == "--probe-feed":
        sys.exit(probe_feed())
    if arg == "--probe-stall":
        sys.exit(probe_stall())
    if arg == "--probe-sync":
        sys.exit(probe_sync())
    if arg == "--probe-lap":
        sys.exit(probe_lap())
    if arg == "--decide":
        mode = mode_text(); s = sense(); print(json.dumps(decide(s, current_width(), current_awake(mode), mode, read_int(TICK_DIR + "/tick.count", 0) + 1))); sys.exit(0)
    print("usage: box_tick.py --tick | --probe-width | --probe-rows | --probe-feed | --probe-stall | --probe-sync | --probe-lap | --decide"); sys.exit(2)
