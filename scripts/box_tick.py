#!/usr/bin/env python3
# box_tick.py -- THE FLEET TICK, ONE PROCESS A MINUTE (DESIGN-PLAN fleet-control step 4; the cio, 2026-11-07). SINCE 2026-11-13 IT DECIDES NOTHING ABOUT WHO RUNS
# (row one-limit-universally-respected-every-seat-runs-at-will; Lon 13:5x CST, in the cio's window, verbatim: "I wan tall descisions on when and when not to run a junior,
# senior, officer, or your GRANDMOTHER to STOP NOW! I want all seats to RUN at WILL." / "We do not want two or three limiters, we want ONE UNIVERSALALLY resepcted LIMIT.").
# THE ONE LIMIT: cores=N of /home/resources/postoffice/CORES.conf (S4E_CORES_CONF the seam). Every tick sets s4e.slice, the one slice that holds every process of the fleet, to
# CPUQuota=N*100% and clears every quota below it (and below app.slice/app-s4e.slice, where the graded runs lived until this row), so the kernel enforces the same number the
# door's tokens count (lib_slots.sh). The grader width W, the workers awake A and the controller's FLEET live set are gone: nothing else limits and nothing chooses a seat.
# With no CORES.conf, or no cores line, the tick sets no quota and clears none (the box of before).
#   box_tick.py --tick              one tick: sense, enforce the one limit, sync, sweep, print one TICK line; under flock on $TICK_DIR/tick.lock; rc 0
#   box_tick.py --probe-one-limit   the one limit on the live box and on planted trees; one ONE_LIMIT line, rc 0 ok / 1 red / 2 no number to read
#   box_tick.py --probe-one-limit --scratch   the planted arms only (the law of the code, no live reading): the landing's gate
#   box_tick.py --probe-roots-sync  every clean seat root's .github and harness fast-forwarded every fifth tick, a dirty root named and left; ROOTS_SYNC line, rc 0/1
# Every fifth tick (S4E_TICK_SWEEP_EVERY) the tick runs the LIVE s4e_msg.sh sweep and queues its WAKE lines in TICK_DIR/wake.pending (live_sweep, the coo 2026-11-12).
# Every fifth tick (S4E_TICK_FEED_EVERY) the tick starts util_reds_to_juniors.py --stock --apply as the unit s4e-feed, never two (stock_juniors; FEED.conf the switch).
# S4E_TICK_DRY=1: no 2 s sample, no systemctl, no expire, a scratch tick dir; the TICK line still prints with its cpu_s.
import os, sys, re, time, json, fcntl, resource, subprocess, glob, shutil, datetime, calendar
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_grade_locks as GL
import harness_paths as HP

ROOT = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PO = os.environ.get("S4E_POSTOFFICE") or os.environ.get("S4E_POST") or "/home/resources/postoffice"
PROG = "/home/resources/progress"
U = "/sys/fs/cgroup/user.slice/user-%d.slice/user@%d.service" % (os.getuid(), os.getuid())
GRADER = next((p for p in (U + "/s4e.slice/s4e-runs.slice/s4e-runs-grader.slice", U + "/app.slice/app-s4e.slice/app-s4e-grader.slice", U + "/s4e.slice/s4e-grader.slice") if os.path.isfile(p + "/cpu.pressure")), U + "/s4e.slice/s4e-grader.slice")   # the grader seat's runs enter app-s4e-grader.slice (util_mem_scope seat_slice); the class slice stood empty and read 0.0, so W rose on a hot box (cio 2026-11-11)
SEATS_SLICE = U + "/s4e.slice/s4e-seats.slice"
DRY = os.environ.get("S4E_TICK_DRY") == "1"
TICK_DIR = os.environ.get("S4E_TICK_DIR") or ("/tmp/s4e/%s/tick" % os.environ.get("S4E_SEAT", "cio"))
CORES_CONF = os.environ.get("S4E_CORES_CONF") or (PO + "/CORES.conf")
FLEET_SLICE = "s4e.slice"   # the one slice: every seat scope, the grader, batch and (since this row) the graded runs, util_mem_scope.seat_slice
FLEET_TREES = ("s4e.slice", "app.slice/app-s4e.slice")   # every quota below these is a second limiter and is cleared; app-s4e.slice is where the graded runs lived before
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


def cores_conf(path=None):
    """THE ONE NUMBER: the last cores=N line of CORES.conf (lib_slots.sh s4e_cores_conf reads it the same way); None when the file, the line or a number is absent"""
    v = None
    try:
        for line in open(path or CORES_CONF):
            m = re.match(r"^cores=(\d+)\s*$", line)
            if m: v = int(m.group(1))
    except OSError:
        return None
    return v if v and v >= 1 else None


def _quota(cg):
    """the cgroup's cpu.max quota in percent of one core, None for max (no quota), '?' when unreadable"""
    try:
        q, per = open(os.path.join(cg, "cpu.max")).read().split()[:2]
    except (OSError, ValueError):
        return "?"
    return None if q == "max" else int(round(int(q) * 100.0 / int(per)))


def one_limit_actions(top, n):
    """what the tick must change so that ONE number limits the fleet: [(unit, 'N%')] for the fleet slice when it is not N*100 percent, then [(unit, '')] (a cleared CPUQuota)
    for every slice or scope below FLEET_TREES that carries a quota of its own. top is the user manager's cgroup (U), or a planted tree; n None asks nothing."""
    acts = []
    if not n:
        return acts
    if _quota(os.path.join(top, FLEET_SLICE)) != n * 100:
        acts.append((FLEET_SLICE, "%d%%" % (n * 100)))
    for tree in FLEET_TREES:
        root = os.path.join(top, tree)
        for d, subs, _ in os.walk(root):
            subs[:] = sorted(x for x in subs if x.endswith((".slice", ".scope")))
            if d == os.path.join(top, FLEET_SLICE):
                continue
            if os.path.basename(d).endswith((".slice", ".scope")) and _quota(d) not in (None, "?"):
                acts.append((os.path.basename(d), ""))
    return acts


def enforce_one_limit():
    """the tick's one act on the box: the fleet slice to cores=N, every other fleet quota cleared (systemctl --user set-property --runtime, the runtime drop-in outranking
    every persistent one); returns the TICK line's word"""
    n = cores_conf()
    if not n:
        return "one_limit=none(no cores line in %s)" % CORES_CONF
    acts = one_limit_actions(U, n)
    if DRY:
        return "one_limit=%d dry_acts=%d" % (n, len(acts))
    bad = 0
    for unit, q in acts:
        try:
            r = subprocess.run(["systemctl", "--user", "set-property", "--runtime", unit, "CPUQuota=" + q], capture_output=True, text=True, timeout=30)
            bad += int(r.returncode != 0)
        except (OSError, subprocess.TimeoutExpired):
            bad += 1
    return "one_limit=%d acts=%d%s" % (n, len(acts), " failed=%d" % bad if bad else "")


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
RUNNERS_TSV = os.path.join(str(HP.harness(ROOT)), "scripts", "SUITE_RUNNERS.tsv")
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
    """the cells of one SUITE_RUNNERS row: core and every chunk:NN of its PARTITION.tsv (table <corpus>/tests/<lang> for a master, the table column for a pkg)"""
    d = os.path.join(str(HP.corpus(ROOT)), "tests", r[2]) if r[1] == "master" else (os.path.join(str(HP.corpus(ROOT)), r[4][len("corpus/"):]) if r[4].startswith("corpus/") else os.path.join(ROOT, r[4]))
    rows = _rows(os.path.join(d, "PARTITION.tsv"))
    if len(rows) < 2 or "part" not in rows[0]: return []
    ip = rows[0].index("part")
    parts = {x[ip] for x in rows[1:] if len(x) > ip and (x[ip] == "core" or x[ip].startswith("chunk:"))}
    return sorted(parts, key=lambda c: (c != "core", c))
def origin_head():
    """the short head of origin/main in SCRIP after a fetch under the s4e-fetch sem slot (the shape util_sync_root.sh uses); a fetch the slot refuses leaves the
    last fetched origin/main standing. Returns "" when origin/main does not resolve."""
    try:
        subprocess.run(["sem", "--will-cite", "--id", "s4e-fetch", "-j", "4", "--fg", "--semaphoretimeout", "-60", "git", "-C", str(HP.scrip(ROOT)), "fetch", "-q", "origin", "main"],
                       env=dict(os.environ, PARALLEL_HOME="/tmp/s4e-sem"), capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.TimeoutExpired): pass
    r = subprocess.run(["git", "-C", str(HP.scrip(ROOT)), "rev-parse", "--short=9", "origin/main"], capture_output=True, text=True, timeout=20)
    return r.stdout.strip() if r.returncode == 0 else ""
def _git_out(*args):
    return subprocess.run(["git", "-C", str(HP.scrip(ROOT))] + list(args), capture_output=True, text=True, timeout=20).stdout.strip()
def landing_features(base):
    """the impact set of the range base..origin/main: test_area_smoke.sh --list-only with AREA_SMOKE_BASE=base (its LIST line names the features; a MAP line
    carrying `*` is a widening). Returns (widen, features); the reading is parse_area's."""
    r = subprocess.run(["bash", os.path.join(str(HP.harness(ROOT)), "scripts", "test_area_smoke.sh"), "--list-only"], capture_output=True, text=True, timeout=300,
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
    w, f = parse_area(2, "AREA_SMOKE REFUSE(2): touched src/ file(s) with NO ROW in ../harness/scripts/area_map.tsv: src/lower/lower_pascal_types.c")  # one-disk: not a path
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
    rows = _rows(os.path.join(str(HP.corpus(ROOT)), "tests", lang, "PARTITION.tsv"))
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
        try: cols = set(open(os.path.join(str(HP.corpus(ROOT)), "tests", r[2], "ALL.csv"), encoding="utf-8").readline().strip().split(","))
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
        try: cols = open(os.path.join(str(HP.corpus(ROOT)), "tests", r[2], "ALL.csv"), encoding="utf-8").readline().strip().split(",")
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
SWEEP_EVERY = int(os.environ.get("S4E_TICK_SWEEP_EVERY", "5"))
def live_sweep(n):
    """THE LIVE SWEEP ON THE CLOCK (the coo 2026-11-12 22:18 CST, MEASURED: nothing ran s4e_msg.sh sweep on the live postoffice, box_tick.sh's plant sweep
    being a self-test on a scratch one, so 15 rows sat PARKED-AWAITING, 12 for hours after their verdicts were served). Every SWEEP_EVERY-th tick and never on
    a dry or probing tick: s4e_msg.sh sweep under timeout 240, its output kept in TICK_DIR/sweep_live.last, and each WAKE line it prints (a row restored to a
    seat's tube on its verdict) appended to TICK_DIR/wake.pending with its stamp, for the loop that sends SendMessage (a tick is no Claude session and wakes
    nobody itself). Returns the TICK line's sweep= text."""
    if DRY or PROBING or n % SWEEP_EVERY:
        return "sweep=skipped"
    try:
        r = subprocess.run(["timeout", "-k", "5", "240", "bash", os.path.join(str(HP.harness(ROOT)), "scripts/s4e_msg.sh"), "sweep"], capture_output=True, text=True,
                           errors="replace", stdin=subprocess.DEVNULL, env=dict(os.environ, S4E_NO_BANNER="1"))
    except Exception as e:
        return "sweep=failed:%s" % type(e).__name__
    out = r.stdout + r.stderr
    with open(TICK_DIR + "/sweep_live.last", "w", encoding="utf-8") as f:
        f.write(out[-20000:])
    wakes = [l for l in out.splitlines() if l.startswith("WAKE: SendMessage")]
    for w in wakes:
        _append(TICK_DIR + "/wake.pending", "%s %s" % (_utc(), w))
    m = re.search(r"sweep: (\d+) row\(s\) PARKED-AWAITING", out)
    return "sweep=rc%d:restored=%s:wakes=%d" % (r.returncode, m.group(1) if m else "0", len(wakes))


FEED_EVERY = int(os.environ.get("S4E_TICK_FEED_EVERY", "5"))
FEED_UNIT = "s4e-feed"
def stock_cmd():
    """the one command a stock run is: a transient service in the batch slice, its WAKE lines to TICK_DIR/wake.pending, its log beside them"""
    return ["systemd-run", "--user", "--quiet", "--collect", "--unit=" + FEED_UNIT, "--slice=s4e-batch.slice", "-p", "RuntimeMaxSec=1800",
            "--setenv=S4E_HOME=" + ROOT, "--setenv=S4E_POST=" + POST, "--setenv=S4E_SEAT=" + os.environ.get("S4E_SEAT", "cio"),
            "--setenv=S4E_FEED_WAKES=" + TICK_DIR + "/wake.pending", "-p", "StandardOutput=append:" + TICK_DIR + "/feed.log", "-p", "StandardError=append:" + TICK_DIR + "/feed.log",
            sys.executable, "-I", os.path.join(str(HP.harness(ROOT)), "scripts/util_reds_to_juniors.py"), "--stock", "--apply"]


def stock_juniors(n, active=None, run=None):
    """THE CLOCK STOCKS THE JUNIORS' TUBES (the cio 2026-11-13, row the-tick-keeps-every-live-juniors-tube-stocked; Lon, in the coo's window, verbatim:
    "It seems not enough work is going to JUNIORS. Is that correct?"; MEASURED 13:21: 11 of 16 juniors idle, nothing dealing a red but the coo's hand).
    Every FEED_EVERY-th tick, never on a dry or probing tick: util_reds_to_juniors.py --stock --apply as the transient unit s4e-feed, never two (a unit
    still active is left to finish). The tick waits on nothing: the feeder reads FEED.conf itself (no file or depth 0 is off) and writes its own line to
    FEED_STOCK.tsv. Returns the TICK line's feed= text."""
    if DRY or PROBING or n % FEED_EVERY:
        return "feed=skipped"
    if active is None:
        active = systemctl("is-active", FEED_UNIT).strip() in ("active", "activating")
    if active:
        return "feed=busy"
    try:
        r = (run or (lambda c: subprocess.run(c, capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL)))(stock_cmd())
    except Exception as e:
        return "feed=failed:%s" % type(e).__name__
    return "feed=started" if r.returncode == 0 else "feed=rc%d" % r.returncode


def probe_feed():
    """the stock wiring on planted state: a skipped tick runs nothing, an active unit is left, a due tick runs the one command; FEED_TICK_PROBE ... ok=1"""
    ran = []
    class R: returncode = 0
    run = lambda c: ran.append(c) or R()
    a = stock_juniors(FEED_EVERY + 1, active=False, run=run)
    b = stock_juniors(FEED_EVERY, active=True, run=run)
    c = stock_juniors(FEED_EVERY, active=False, run=run)
    cmd = ran[0] if ran else []
    ok = (a == "feed=skipped" and b == "feed=busy" and c == "feed=started" and len(ran) == 1 and "--unit=" + FEED_UNIT in cmd and "--stock" in cmd and "--apply" in cmd
          and any(x.startswith("--setenv=S4E_FEED_WAKES=") and x.endswith("/wake.pending") for x in cmd)) if not DRY else False
    print("FEED_TICK_PROBE skipped=%s busy=%s due=%s runs=%d ok=%d" % (a, b, c, len(ran), int(ok)))
    return 0 if ok else 1


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
    one = enforce_one_limit()
    grader = "retired (CIO-82: the cycle is the one grading road)"
    expired = expire_leases() if n % 5 == 0 else 0
    fed = "retired (CIO-82: the cycle serves test requests)"
    st = {"alarm": 0, "line": "stall=retired"}   # the grade tube's stall watch retired with the tube (CIO-82); the BOX.state and TICK line keys keep their shape
    view = regenerate_view()
    sweep = live_sweep(n)
    feedst = stock_juniors(n)
    with open(TICK_DIR + "/decide.last", "w") as f:
        f.write(json.dumps(dict(tick=n, sensors=s, one_limit=one, grader=grader, expired=expired, fed=fed, view=view)) + "\n")
    # BOX.state: the controller is its writer (the coo 2026-11-07 15:29: the retired box_controller's file had no writer and its readers, the coo's OPS line, opswatch and
    # fleet_health.py, read a 520 s old width of 2). The old keys that still mean something keep their names (ts busy cores cpu_psi10 cpu_psi60 grader_width action); the rest are the tick's.
    try:
        if DRY: raise RuntimeError("dry tick writes no state")
        gq = 0; gq_read = None
        gq = gq_read = 0   # the grade tube is retired (CIO-82): no job is ever queued in it
        log_tick(n, gq_read)
        rph, lap = rows_recent(3600), rows_recent(86400)
        with open(PROG + "/BOX.state.tmp", "w") as f:
            f.write("ts=%s\nbusy=%.1f\ncores=%d\ncpu_psi10=%.1f\ncpu_psi60=%.1f\ncpu_psi300=%.1f\none_limit_cores=%s\naction=%s\ngrader_queue=%d\ngrader_stall=%d\ncontroller=box_tick.py\ntick=%d\ncontroller_sync=%s\nrows_per_hour=%d\nlap_rows_24h=%d\n%s\n"
                    % (time.strftime("%Y-%m-%dT%H:%M:%S%z"), s["load1"], os.cpu_count() or 16, s["cpu10"], s["cpu60"], s["cpu300"], cores_conf() or "none", one.replace(" ", ","), gq, st["alarm"], n, sy["kind"], rph, lap,
                       grader.replace(" ", "\n").replace("grader\n", "grader_")))
        os.replace(PROG + "/BOX.state.tmp", PROG + "/BOX.state")
    except Exception as e:
        print("BOX.state not written: %s" % e)
    ru = resource.getrusage(resource.RUSAGE_SELF); rc = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_s = ru.ru_utime + ru.ru_stime + rc.ru_utime + rc.ru_stime
    print("TICK unit=s4e-tick.timer controller=box_tick.py tick=%d psi10=%.1f psi60=%.1f psi300=%.1f load1=%.1f mem_rise=%d %s %s %s expired=%d %s %s %s %s %s secs=%d cpu_s=%.2f%s"
          % (n, s["cpu10"], s["cpu60"], s["cpu300"], s["load1"], s.get("mem_rise", 0), one,
             sy["disp"], grader, expired, fed, view, st["line"], sweep, feedst, int(time.time() - t0), cpu_s, " dry=1" if DRY else ""))
    return 0


def probe_one_limit(scratch=False):
    """THE ONE LIMIT, PROVED (row one-limit-universally-respected-every-seat-runs-at-will). The planted arms read the law of the code on scratch trees and a scratch
    CORES.conf; the live arms (all but --scratch) read the box: the number, the kernel's quota on the one slice, no quota anywhere below it, no fleet process outside it,
    no FLEET or WORKERS-AWAKE line in MODE, BUDGET.tsv declaring no other CPUQuota, spawn_fleet.sh giving a seat scope none. One ONE_LIMIT line: rc 0 ok, 1 red, 2 no number."""
    import tempfile
    here = os.path.dirname(os.path.abspath(__file__))
    arms, red = [], []
    def arm(name, ok, why=""):
        arms.append("%s=%s" % (name, "ok" if ok else "red"))
        if not ok: red.append("%s(%s)" % (name, why))
    with tempfile.TemporaryDirectory(prefix="one_limit.", dir=os.environ.get("TMPDIR") or "/tmp") as T:
        def plant(rel, q):
            os.makedirs(os.path.join(T, "u", rel), exist_ok=True)
            open(os.path.join(T, "u", rel, "cpu.max"), "w").write(("max" if q is None else str(q * 1000)) + " 100000\n")
        plant("s4e.slice", 800); plant("s4e.slice/s4e-seats.slice", 1200); plant("s4e.slice/s4e-seats.slice/s4e-seat-x.scope", 400)
        plant("s4e.slice/s4e-grader.slice", None); plant("s4e.slice/s4e-runs.slice/s4e-runs-grader.slice", None); plant("app.slice/app-s4e.slice", 1000)
        plant("app.slice/app-gnome.slice", 300)   # outside the fleet: never touched
        got = sorted(one_limit_actions(os.path.join(T, "u"), 14))
        want = sorted([("s4e.slice", "1400%"), ("s4e-seats.slice", ""), ("s4e-seat-x.scope", ""), ("app-s4e.slice", "")])
        arm("law", got == want, "actions %s, want %s" % (got, want))
        plant("s4e.slice", 1400)
        for r in ("s4e.slice/s4e-seats.slice", "s4e.slice/s4e-seats.slice/s4e-seat-x.scope", "app.slice/app-s4e.slice"): plant(r, None)
        arm("settled", one_limit_actions(os.path.join(T, "u"), 14) == [], "a tree already at the one limit still asks for acts")
        arm("noconf", one_limit_actions(os.path.join(T, "u"), None) == [], "no number must change nothing")
        conf = os.path.join(T, "CORES.conf")
        open(conf, "w").write("# planted\ncores=4\ngrader=1\nseat=2\n")
        arm("number", cores_conf(conf) == 4 and cores_conf(os.path.join(T, "absent")) is None, "cores_conf misread the planted file")
        gone = [x for x in ("decide", "write_awake", "write_live_set", "current_width", "current_awake", "wmax") if x in globals()]
        arm("chooses_nothing", not gone, "the tick still defines " + ",".join(gone))
        try:
            import util_mem_scope
            sl = util_mem_scope.seat_slice()
        except Exception as e:
            sl = "error:%s" % e
        arm("runs_inside", sl.startswith("s4e-runs-"), "seat_slice() is %s, outside s4e.slice" % sl)
        noc = os.path.join(T, "NOCORES.conf"); open(noc, "w").write("grader=1\n")
        def sh(script, conf_path, extra=None):
            env = dict(os.environ, S4E_CORES_CONF=conf_path, S4E_SEM=os.path.join(T, "no-sem"), S4E_SEM_HOME=os.path.join(T, "sem"), S4E_SLOT_WAITS=os.path.join(T, "waits.tsv"), **(extra or {}))
            env.pop("S4E_ADMITTED", None); env.pop("S4E_CORE_HELD", None); env.pop("S4E_RUN_SLOT_HELD", None)
            r = subprocess.run(["bash", "-c", script, "x", here], env=env, capture_output=True, text=True, timeout=120)
            return r.returncode, r.stdout.strip()
        a1, _ = sh('. "$1/lib_slots.sh"; s4e_sem_admit run', conf)
        a2, _ = sh('. "$1/lib_slots.sh"; s4e_sem_admit run', noc)
        arm("admit_one_count", a1 == 0 and a2 == 2, "with cores= the sem admission must pass with no sem (rc %d), without it the sem rule stands (rc %d, want 2)" % (a1, a2))
        la = os.path.join(T, "loadavg"); open(la, "w").write("10.00 10.00 10.00 1/1 1\n")
        sm = '. "$1/lib_smoke_honest.sh"; smoke_note 124; echo "$SMOKE_TIMEOUTS_LOADED"'
        _, s4 = sh(sm, conf, {"SMOKE_LOADAVG": la})
        c8 = os.path.join(T, "C8.conf"); open(c8, "w").write("cores=8\n")
        _, s8 = sh(sm, c8, {"SMOKE_LOADAVG": la})
        arm("smoke_one_count", s4 == "1" and s8 == "0", "load 10 must count loaded against cores=4 (%s) and not against cores=8 (%s)" % (s4, s8))
        if not scratch:
            n = cores_conf()
            if not n:
                print("ONE_LIMIT REFUSE(2): no cores=N line in %s -- there is no one number to read (%s)" % (CORES_CONF, " ".join(arms)))
                return 2
            q = _quota(os.path.join(U, FLEET_SLICE))
            arm("kernel", q == n * 100, "%s cpu.max is %s percent, cores=%d" % (FLEET_SLICE, q, n))
            acts = [u for u, v in one_limit_actions(U, n) if u != FLEET_SLICE]
            arm("nested", not acts, "%d other quota(s): %s" % (len(acts), ",".join(acts[:6])))
            outside = 0
            for d, _, fs in os.walk(os.path.join(U, "app.slice/app-s4e.slice")):
                if "cgroup.procs" in fs:
                    try: outside += sum(1 for _ in open(os.path.join(d, "cgroup.procs")))
                    except OSError: pass
            stray = []
            for pid in os.listdir("/proc"):
                if not pid.isdigit(): continue
                try:
                    if open("/proc/%s/comm" % pid).read().strip() != "claude": continue
                    if not os.readlink("/proc/%s/cwd" % pid).startswith("/home/claude_"): continue
                    if "/s4e.slice/" not in open("/proc/%s/cgroup" % pid).read(): stray.append(pid)
                except OSError:
                    continue
            arm("one_slice", outside == 0 and not stray, "%d process(es) in app-s4e.slice, %d seat session(s) outside %s" % (outside, len(stray), FLEET_SLICE))
            mode = mode_text()
            keyed = re.findall(r"^(FLEET|WORKERS-AWAKE):", mode, re.M)
            arm("mode", not keyed, "MODE still keys " + ",".join(keyed))
            bud = os.environ.get("S4E_BUDGET") or (PO + "/BUDGET.tsv")
            extra = []
            try:
                rows = [l.rstrip("\n").split("\t") for l in open(bud) if l.strip() and not l.startswith("#")]
                hdr = rows[0]; iu, iq = hdr.index("unit"), hdr.index("CPUQuota")
                for r in rows[1:]:
                    if len(r) <= iq: continue
                    if r[iu] == FLEET_SLICE:
                        if r[iq] != "%d%%" % (n * 100): extra.append("%s=%s" % (r[iu], r[iq]))
                    elif r[iq] not in ("-", ""):
                        extra.append("%s=%s" % (r[iu], r[iq]))
            except (OSError, ValueError, IndexError) as e:
                extra.append("unread:%s" % e)
            arm("budget", not extra, "BUDGET.tsv declares " + ",".join(extra))
            sp = os.environ.get("S4E_SPAWN_FLEET") or "/usr/local/bin/spawn_fleet.sh"
            try:
                o = subprocess.run(["bash", sp, "--probe-scope"], capture_output=True, text=True, timeout=60).stdout
            except (OSError, subprocess.TimeoutExpired) as e:
                o = str(e)
            arm("spawn", re.search(r"^SCOPE .* cpu=none ", o, re.M) is not None, "%s --probe-scope gives a seat scope a quota: %s" % (sp, o.strip()[:120]))
    n = cores_conf()
    print("ONE_LIMIT %s cores=%s %s%s" % ("red" if red else "ok", n if n else "none", " ".join(arms), " RED: " + "; ".join(red) if red else ""))
    return 1 if red else 0


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
    if arg == "--probe-one-limit":
        sys.exit(probe_one_limit(scratch="--scratch" in sys.argv[2:]))
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
    if arg == "--probe-feed":
        sys.exit(probe_feed())
    print("usage: box_tick.py --tick | --probe-one-limit [--scratch] | --probe-rows | --probe-sync | --probe-roots-sync | --probe-impact | --probe-area-refusal | --probe-feed"); sys.exit(2)
