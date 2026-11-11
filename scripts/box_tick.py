#!/usr/bin/env python3
# box_tick.py -- THE FLEET CONTROLLER, ONE PROCESS A MINUTE (DESIGN-PLAN fleet-control steps 4 and 5; the cio, 2026-11-07, on Lon's word:
# "gain control of the CPU problem" / "queue and limit as necessary. use modern industry proven tools"). It replaces box_tick.sh, a shell
# script that forked about 9,000 processes a tick (7 CPU-s quiet, 18 under load, MEASURED 2026-11-07 11:4x). THE LAW: one signal, PSI
# (/proc/pressure/cpu, the kernel's own pressure accounting); one decision a tick for two knobs, the grader width W and the workers awake A;
# the controller alone writes them (W to box.width, read by the cycle, the one grader since CIO-82; A to MODE's WORKERS-AWAKE line and the controller-owned
# FLEET: IDLE EXCEPT list the Stop gate enforces). No seat chooses. A hand-written FLEET line (no "(controller" marker) freezes A: Lon's hand
# outranks the controller, and the controller says so on its TICK line.
#   box_tick.py --tick           one tick: sense, decide, act, print one TICK line; under flock on $TICK_DIR/tick.lock; rc 0
#   box_tick.py --probe-width    the law on planted sensors: quiet raises one step, hot lowers one step, a hold holds; one WIDTH_PSI line, rc 0/1
#   box_tick.py --decide         print the decision for the live sensors without acting
#   box_tick.py --probe-roots-sync  every clean seat root's .github and harness fast-forwarded every fifth tick, a dirty root named and left; ROOTS_SYNC line, rc 0/1
# S4E_TICK_DRY=1: no 2 s sample, no systemctl, no expire, no MODE write, a scratch tick dir; the TICK line still prints with its cpu_s.
# THE LAW OF THE TWO KNOBS (one step a tick at most, a step every S4E_STEP_EVERY ticks, default 2):
#   quiet: cpu PSI avg60 < 25 and avg10 < 25 and no grader memory event  -> W and A go up one (to WMAX, AMAX)
#   hot:   cpu PSI avg60 > 40, or avg10 > 60, or a grader memory event   -> W and A go down one at once (to WMIN, AMIN)
#   else hold. Night (22:00-05:59) or FLEET: IDLE raises WMAX to BOX_WMAX_NIGHT (8); day WMAX is BOX_WMAX_DAY (4). AMAX is S4E_WORKERS_MAX (20).
import os, sys, re, time, json, fcntl, resource, subprocess, glob, shutil, datetime, calendar
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_grade_locks as GL

ROOT = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PO = os.environ.get("S4E_POSTOFFICE") or os.environ.get("S4E_POST") or "/home/resources/postoffice"
PROG = "/home/resources/progress"
U = "/sys/fs/cgroup/user.slice/user-%d.slice/user@%d.service" % (os.getuid(), os.getuid())
GRADER = next((p for p in (U + "/app.slice/app-s4e.slice/app-s4e-grader.slice", U + "/s4e.slice/s4e-grader.slice") if os.path.isfile(p + "/cpu.pressure")), U + "/s4e.slice/s4e-grader.slice")   # the grader seat's runs enter app-s4e-grader.slice (util_mem_scope seat_slice); the class slice stood empty and read 0.0, so W rose on a hot box (cio 2026-11-11)
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


LAST_SCALE = {}   # the last scale's want, running and instance lists, for TICK_DIR/ticks.log (test-cycle step 8)
REQ_DIR = os.environ.get("S4E_TEST_REQUEST_DIR") or "/home/resources/postoffice/test_requests"
GRADE_TUBE = os.environ.get("S4E_GRADE_TUBE") or "grade"
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
def master_pkg_rows(): return [r for r in _rows(RUNNERS_TSV) if len(r) >= 5 and r[1] in ("master", "pkg")]
def suite_cells(r):
    """the cells of one SUITE_RUNNERS row: core and every chunk:NN of its PARTITION.tsv (table corpus/tests/<lang> for a master, the table column for a pkg)"""
    d = os.path.join(ROOT, "corpus", "tests", r[2]) if r[1] == "master" else os.path.join(ROOT, r[4])
    rows = _rows(os.path.join(d, "PARTITION.tsv"))
    if len(rows) < 2 or "part" not in rows[0]: return []
    ip = rows[0].index("part")
    parts = {x[ip] for x in rows[1:] if len(x) > ip and (x[ip] == "core" or x[ip].startswith("chunk:"))}
    return sorted(parts, key=lambda c: (c != "core", c))
def origin_head():
    """the short head of origin/main in SCRIP after a fetch under the s4e-fetch sem slot (the shape util_sync_root.sh uses); a fetch the slot refuses leaves the
    last fetched origin/main standing. Returns "" when origin/main does not resolve."""
    try:
        subprocess.run(["sem", "--will-cite", "--id", "s4e-fetch", "-j", "4", "--fg", "--semaphoretimeout", "-60", "git", "-C", os.path.join(ROOT, "SCRIP"), "fetch", "-q", "origin", "main"],
                       env=dict(os.environ, PARALLEL_HOME="/tmp/s4e-sem"), capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.TimeoutExpired): pass
    r = subprocess.run(["git", "-C", os.path.join(ROOT, "SCRIP"), "rev-parse", "--short=9", "origin/main"], capture_output=True, text=True, timeout=20)
    return r.stdout.strip() if r.returncode == 0 else ""
def _git_out(*args):
    return subprocess.run(["git", "-C", os.path.join(ROOT, "SCRIP")] + list(args), capture_output=True, text=True, timeout=20).stdout.strip()
def landing_features(base):
    """the impact set of the range base..origin/main: test_area_smoke.sh --list-only with AREA_SMOKE_BASE=base (its LIST line names the features; a MAP line
    carrying `*` is a widening). Returns (widen, features); the reading is parse_area's."""
    r = subprocess.run(["bash", os.path.join(ROOT, "harness", "scripts", "test_area_smoke.sh"), "--list-only"], capture_output=True, text=True, timeout=300,
                       env=dict(os.environ, AREA_SMOKE_BASE=base), cwd=ROOT)
    return parse_area(r.returncode, r.stdout + r.stderr)
def parse_area(rc, out):
    """the pure reading of one test_area_smoke --list-only run (its rc and output, never a live range). A refusal that names a touched file with NO ROW in
    area_map.tsv widens: the file's impact cannot be read, so the whole tree is the impact (test-cycle step 5c, the cio's design answer; the range would otherwise
    refuse on every tick, the head never moving past it). Any other refusal raises: nothing is put for a range that cannot be read."""
    if rc != 0:
        if "with NO ROW in" in out: return True, []
        raise RuntimeError("test_area_smoke rc=%d" % rc)
    widen = any("->" in l and "*" in l.split("->", 1)[1].split() for l in out.splitlines() if l.startswith("AREA_SMOKE_MAP "))
    m = re.search(r"AREA_SMOKE_LIST features=(.*?) runnable_entries=", out)
    return widen, (m.group(1).split() if m else [])
def probe_area_refusal():
    """--probe-area-refusal: parse_area on three canned readings, never a live range: an unmapped file widens, another refusal raises, a listed range names its features"""
    w, f = parse_area(2, "AREA_SMOKE REFUSE(2): touched src/ file(s) with NO ROW in ../harness/scripts/area_map.tsv: src/lower/lower_pascal_types.c")
    unmapped = "widen" if w is True and f == [] else "wrong"
    try:
        parse_area(2, "AREA_SMOKE REFUSE(2): cannot read the range")
        other = "wrong"
    except RuntimeError:
        other = "raise"
    w2, f2 = parse_area(0, "AREA_SMOKE_LIST features=lang:pascal ARB runnable_entries=3")
    listed = "features" if w2 is False and f2 == ["lang:pascal", "ARB"] else "wrong"
    ok = int(unmapped == "widen" and other == "raise" and listed == "features")
    print("AREA_REFUSAL_PROBE unmapped=%s other=%s listed=%s ok=%d" % (unmapped, other, listed, ok))
    return 0 if ok else 1
def shell_vocab(lang):
    """the shells vocabulary of one master (test-cycle step 5c): every whitespace word of the shells column of its PARTITION.tsv, the union over the rows;
    an absent table or column is empty. A feature outside it has no shell cell (util_suite_partition builds shells for distinctive features only)"""
    rows = _rows(os.path.join(ROOT, "corpus", "tests", lang, "PARTITION.tsv"))
    if not rows or "shells" not in rows[0]: return set()
    ish = rows[0].index("shells")
    return {w for x in rows[1:] if len(x) > ish for w in x[ish].split()}
def impact_cells(base):
    """the impact set of the range (test-cycle step 5c): a widening puts every master's chunk:01; else for each master whose ALL.csv has the feature column the
    cell shell:<feature> (a token lang:feature names its lang's masters only)"""
    widen, feats = landing_features(base)
    return cells_for(widen, feats)
def cells_for(widen, feats):
    """the cells of a range's features: see impact_cells; a feature the master's shells vocabulary lacks puts NO cell (the core carries it in the smoke band)"""
    masters = [r for r in master_pkg_rows() if r[1] == "master"]
    if widen: return [(r[0], "chunk:01") for r in masters]
    cells = {}
    for r in masters:
        try: cols = set(open(os.path.join(ROOT, "corpus", "tests", r[2], "ALL.csv"), encoding="utf-8").readline().strip().split(","))
        except OSError: continue
        vocab = shell_vocab(r[2])
        for t in feats:
            lang, _, f = t.rpartition(":")
            if (lang and lang != r[2]) or f not in cols or f not in vocab: continue
            cells[(r[0], "shell:" + f)] = None
    return list(cells)
def probe_impact():
    """--probe-impact (test-cycle step 5c): every master's own feature columns, run through cells_for; each cell must grade entries (util_grade_job.cell_entries),
    and the columns a master's shells vocabulary does not carry are dropped, counted. ok=1 only when cells exist, none is empty and some column was dropped."""
    masters = [r for r in master_pkg_rows() if r[1] == "master"]
    feats, dropped = [], 0
    for r in masters:
        try: cols = open(os.path.join(ROOT, "corpus", "tests", r[2], "ALL.csv"), encoding="utf-8").readline().strip().split(",")
        except OSError: continue
        vocab = shell_vocab(r[2])
        feats += ["%s:%s" % (r[2], c) for c in cols]
        dropped += sum(1 for c in cols if c not in vocab)
    cells = cells_for(False, feats)
    empty = 0
    for key, cell in cells:
        # util_grade_job runs its verb dispatcher at import, so the entries are read through its budget verb (cell_entries behind it); a refusal is zero
        r = subprocess.run([sys.executable, "-I", os.path.join(os.path.dirname(os.path.abspath(__file__)), "util_grade_job.py"), "budget", "--suite", key, "--cell", cell],
                           capture_output=True, text=True, timeout=300, env=dict(os.environ))
        m = re.search(r"entries=(\d+)", r.stdout)
        if r.returncode != 0 or not m or int(m.group(1)) == 0: empty += 1
    ok = int(len(cells) > 0 and empty == 0 and dropped > 0)
    print("IMPACT_PROBE masters=%d cells=%d empty=%d dropped=%d ok=%d" % (len(masters), len(cells), empty, dropped, ok))
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
    try: tubes = "".join(l.split("\t")[3] for l in open(PO + "/QUEUE.tsv") if l[:1].isdigit() and l.count("\t") >= 3)   # the queue file's state column (CIO-82)
    except OSError: tubes = ""
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


ROOTS_GLOB = os.environ.get("S4E_ROOTS_GLOB", "/home/claude_*")
ROOTS_EVERY = 5
def sync_seat_roots(n):
    """THE CONTROLLER FAST-FORWARDS .github AND harness IN EVERY CLEAN SEAT ROOT (the cio's design 2026-11-08 08:4x CST; cut by officer_03 under COO-484).
    Every ROOTS_EVERY-th tick and never on a dry tick (else kind=skipped), for each directory of sorted(glob(ROOTS_GLOB)) except ROOT and GRADER_HOME that
    holds both .github/.git and harness/.git: a root whose two HEADs equal ROOT's two origin/main refs is current and skipped; else when both repos are
    clean (git status --porcelain empty), each fetches +refs/remotes/origin/main from ROOT's same repo (a LOCAL fetch: sync_root keeps ROOT's refs current;
    MEASURED by officer_03 2026-11-08 10:1x CST, a network fetch under the s4e-fetch sem costs 0.11-0.19 CPU-s of sem and 0.22 s wall a repo, a local fetch
    0.01 s) and merges --ff-only origin/main; one line per root that moved is appended to TICK_DIR/roots_sync.log; a dirty or diverged root is named in
    dirty and left alone. Returns dict(kind=ok|skipped, moved=[roots that moved], dirty=[roots named], disp=the TICK line's roots= text). THE BODY IS THE
    WORKER'S ROW."""
    return dict(kind="ok", moved=[], dirty=[], disp="roots=none")


def probe_roots_sync():
    """--probe-roots-sync: two LOCAL BARE origins (.github, harness), each given two commits; three scratch roots under a scratch dir, each cloned from them
    and reset one commit behind: claude_clean (clean), claude_dirty (an untracked file in harness), claude_grader (clean, named GRADER_HOME). Tick 6 is
    skipped (nothing moves); ROOT is a scratch controller root cloned at the tip (outside the glob); tick 5 moves claude_clean's two repos to the tip, leaves claude_dirty and claude_grader behind, names claude_dirty once and writes
    one roots_sync.log line naming claude_clean; tick 10 moves nothing and the log keeps one line; tick() calls sync_seat_roots. Prints ROOTS_SYNC; rc 0/1."""
    import tempfile, inspect
    global ROOTS_GLOB, TICK_DIR, GRADER_HOME, ROOT
    saved = (ROOTS_GLOB, TICK_DIR, GRADER_HOME, ROOT)
    base = "/tmp/s4e/%s" % os.environ.get("S4E_SEAT", "cio"); os.makedirs(base, exist_ok=True)
    d = tempfile.mkdtemp(prefix="s4e-roots-probe-", dir=base)
    who = dict(GIT_AUTHOR_NAME="s4e-probe", GIT_AUTHOR_EMAIL="probe@s4e.invalid", GIT_COMMITTER_NAME="s4e-probe", GIT_COMMITTER_EMAIL="probe@s4e.invalid")
    def git(*a, cwd=None):
        r = subprocess.run(["git", "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main", *a], cwd=cwd, capture_output=True, text=True, timeout=60,
                           env=dict(os.environ, **who), stdin=subprocess.DEVNULL)
        if r.returncode != 0:
            raise RuntimeError("git %s: %s" % (a[0], r.stderr.strip()[:200]))
        return r.stdout.strip()
    repos, names = [".github", "harness"], ["claude_clean", "claude_dirty", "claude_grader"]
    why, moved, named, lines = [], 0, 0, -1
    try:
        for r in repos:
            bare, w = d + "/origin/" + r + ".git", d + "/work/" + r
            git("init", "-q", "--bare", "-b", "main", bare); git("init", "-q", "-b", "main", w); git("remote", "add", "origin", bare, cwd=w)
            for t in ("one", "two"):
                with open(w + "/f.txt", "a") as fh: fh.write(t + "\n")
                git("add", "f.txt", cwd=w); git("commit", "-q", "-m", t, cwd=w)
            git("push", "-q", "origin", "main", cwd=w)
        tip = {r: git("rev-parse", "HEAD", cwd=d + "/work/" + r) for r in repos}
        for r in repos:
            git("clone", "-q", d + "/origin/" + r + ".git", d + "/controller/" + r)
        for nm in names:
            for r in repos:
                git("clone", "-q", d + "/origin/" + r + ".git", d + "/" + nm + "/" + r); git("reset", "-q", "--hard", "HEAD~1", cwd=d + "/" + nm + "/" + r)
        open(d + "/claude_dirty/harness/untracked.txt", "w").write("dirty\n")
        behind = git("rev-parse", "HEAD", cwd=d + "/claude_clean/harness")
        ROOTS_GLOB, TICK_DIR, GRADER_HOME, ROOT = d + "/claude_*", d + "/tick", d + "/claude_grader", d + "/controller"
        os.makedirs(TICK_DIR)
        head = lambda nm, r: git("rev-parse", "HEAD", cwd=d + "/" + nm + "/" + r)
        logn = lambda: len(open(TICK_DIR + "/roots_sync.log").read().splitlines()) if os.path.exists(TICK_DIR + "/roots_sync.log") else 0
        s6 = sync_seat_roots(6)
        if s6.get("kind") != "skipped" or head("claude_clean", "harness") != behind: why.append("tick 6 was not skipped")
        s5 = sync_seat_roots(5)
        moved = sum(1 for r in repos if head("claude_clean", r) == tip[r])
        if moved != 2: why.append("claude_clean moved %d of 2 repos" % moved)
        if any(head(nm, r) == tip[r] for nm in ("claude_dirty", "claude_grader") for r in repos): why.append("a dirty or grader root moved")
        named = sum(1 for x in s5.get("dirty", []) if os.path.basename(x.rstrip("/")) == "claude_dirty")
        if named != 1 or len(s5.get("dirty", [])) != 1: why.append("dirty named %d time(s) among %s" % (named, s5.get("dirty")))
        lines = logn()
        if lines != 1 or "claude_clean" not in open(TICK_DIR + "/roots_sync.log").read(): why.append("roots_sync.log holds %d line(s), not one naming claude_clean" % lines)
        s10 = sync_seat_roots(10)
        if s10.get("moved") or logn() != 1: why.append("tick 10 moved %s, log lines %d" % (s10.get("moved"), logn()))
        if "sync_seat_roots(" not in inspect.getsource(tick): why.append("tick() does not call sync_seat_roots")
    except Exception as e:
        why.append("error " + str(e)[:200])
    finally:
        ROOTS_GLOB, TICK_DIR, GRADER_HOME, ROOT = saved
        shutil.rmtree(d, ignore_errors=True)
    ok = int(not why)
    print("ROOTS_SYNC moved=%d dirty_named=%d log_lines=%d ok=%d%s" % (1 if moved == 2 else 0, named, lines, ok, "" if ok else " (PROBE RED: %s)" % "; ".join(why)))
    return 0 if ok else 1


TICKS_LOG_MAX = 8 << 20
def log_tick(n, gq):
    """TICK_DIR/ticks.log: ONE JSON line a tick (DESIGN-PLAN test-cycle step 8, the acceptance instrument util_seat_census.py --test-cycle-acceptance reads it):
    ts, tick, grader_queue (0 since the grade tube retired, CIO-82), want and running (the grade worker
    instances asked for and found running), and the instances this tick started and stopped (the controller's stops, so a hand stop is told apart).
    Over TICKS_LOG_MAX bytes the oldest half is dropped (about 70,000 ticks, seven weeks, kept)."""
    path = TICK_DIR + "/ticks.log"
    try:
        with open(path, "a") as f:
            f.write(json.dumps(dict(ts=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), tick=n, grader_queue=gq, want=LAST_SCALE.get("want"), running=LAST_SCALE.get("running"),
                                    starts=LAST_SCALE.get("starts", []), stops=LAST_SCALE.get("stops", []))) + "\n")
        if os.path.getsize(path) > TICKS_LOG_MAX:
            with open(path, "rb") as f:
                f.seek(-(TICKS_LOG_MAX // 2), 2); keep = f.read().split(b"\n", 1)[-1]
            with open(path + ".tmp", "wb") as f: f.write(keep)
            os.replace(path + ".tmp", path)
    except OSError as e:
        print("ticks.log not written: %s" % e)


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
    grader = "retired (CIO-82: the cycle is the one grading road)"
    awake = write_awake(d["A"], d["why"], s, mode)
    liveset = write_live_set(d["A"], mode_text())
    expired = expire_leases() if n % 5 == 0 else 0
    fed = "retired (CIO-82: the cycle serves test requests)"
    st = {"alarm": 0, "line": "stall=retired"}   # the grade tube's stall watch retired with the tube (CIO-82); the BOX.state and TICK line keys keep their shape
    view = regenerate_view()
    with open(TICK_DIR + "/decide.last", "w") as f:
        f.write(json.dumps(dict(tick=n, sensors=s, decision=d, grader=grader, awake=awake, liveset=liveset, expired=expired, fed=fed, view=view)) + "\n")
    # BOX.state: the controller is its writer (the coo 2026-11-07 15:29: the retired box_controller's file had no writer and its readers, the coo's OPS line, opswatch and
    # fleet_health.py, read a 520 s old width of 2). The old keys that still mean something keep their names (ts busy cores cpu_psi10 cpu_psi60 grader_width action); the rest are the tick's.
    try:
        if DRY: raise RuntimeError("dry tick writes no state")
        gq = 0; gq_read = None
        gq = gq_read = 0   # the grade tube is retired (CIO-82): no job is ever queued in it
        log_tick(n, gq_read)
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
    print("TICK unit=s4e-tick.timer controller=box_tick.py tick=%d psi10=%.1f psi60=%.1f psi300=%.1f load1=%.1f mem_rise=%d step=%+d why=%s W=%d/%d A=%d/%d %s %s %s %s expired=%d %s %s %s secs=%d cpu_s=%.2f%s"
          % (n, s["cpu10"], s["cpu60"], s["cpu300"], s["load1"], s.get("mem_rise", 0), d["step"], d["why"], d["W"], d["WMAX"], d["A"], d["AMAX"],
             sy["disp"], grader, awake, liveset, expired, fed, view, st["line"], int(time.time() - t0), cpu_s, " dry=1" if DRY else ""))
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
    if arg == "--probe-sync":
        sys.exit(probe_sync())
    if arg == "--probe-roots-sync":
        sys.exit(probe_roots_sync())
    if arg == "--probe-impact":
        sys.exit(probe_impact())
    if arg == "--probe-area-refusal":
        sys.exit(probe_area_refusal())
    if arg == "--decide":
        mode = mode_text(); s = sense(); print(json.dumps(decide(s, current_width(), current_awake(mode), mode, read_int(TICK_DIR + "/tick.count", 0) + 1))); sys.exit(0)
    print("usage: box_tick.py --tick | --probe-width | --probe-rows | --probe-sync | --probe-roots-sync | --probe-impact | --probe-area-refusal | --decide"); sys.exit(2)
