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
# S4E_TICK_DRY=1: no 2 s sample, no systemctl, no expire, no MODE write, a scratch tick dir; the TICK line still prints with its cpu_s.
# THE LAW OF THE TWO KNOBS (one step a tick at most, a step every S4E_STEP_EVERY ticks, default 2):
#   quiet: cpu PSI avg60 < 25 and avg10 < 25 and no grader memory event  -> W and A go up one (to WMAX, AMAX)
#   hot:   cpu PSI avg60 > 40, or avg10 > 60, or a grader memory event   -> W and A go down one at once (to WMIN, AMIN)
#   else hold. Night (22:00-05:59) or FLEET: IDLE raises WMAX to BOX_WMAX_NIGHT (8); day WMAX is BOX_WMAX_DAY (4). AMAX is S4E_WORKERS_MAX (20).
import os, sys, re, time, json, fcntl, resource, subprocess, glob, shutil

ROOT = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PO = os.environ.get("S4E_POSTOFFICE") or os.environ.get("S4E_POST") or "/home/resources/postoffice"
PROG = "/home/resources/progress"
U = "/sys/fs/cgroup/user.slice/user-%d.slice/user@%d.service" % (os.getuid(), os.getuid())
GRADER = U + "/s4e.slice/s4e-grader.slice"
DRY = os.environ.get("S4E_TICK_DRY") == "1"
TICK_DIR = os.environ.get("S4E_TICK_DIR") or ("/tmp/s4e/%s/tick" % os.environ.get("S4E_SEAT", "cio"))
STEP_EVERY = int(os.environ.get("S4E_STEP_EVERY", "2"))
WMIN, AMIN = 1, 0
AMAX = int(os.environ.get("S4E_WORKERS_MAX", "20"))
QUIET, HOT60, HOT10 = 25.0, 40.0, 60.0


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
        g10, _, _ = psi(GRADER + "/cpu.pressure")
        oom, mx = mem_events()
        last = TICK_DIR + "/grader_mem_events.last"
        try:
            lo, lm = [int(x) for x in open(last).read().split()[:2]]
        except (OSError, ValueError):
            lo, lm = oom, mx
        s.update(cpu10=a10, cpu60=a60, cpu300=a300, gcpu10=g10, mem_rise=int(oom > lo or mx > lm))
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


def decide(s, w, a, mode, tick_no):
    """one step a tick at most, a step every STEP_EVERY ticks for a rise, at once for a fall"""
    hot = s["cpu60"] > HOT60 or s["cpu10"] > HOT10 or s.get("mem_rise", 0) == 1
    quiet = s["cpu60"] < QUIET and s["cpu10"] < QUIET and s.get("mem_rise", 0) == 0
    WMAX = wmax(mode)
    may_rise = tick_no % STEP_EVERY == 0
    if hot:
        step, why = -1, "hot"
    elif quiet and may_rise:
        step, why = +1, "quiet"
    elif quiet:
        step, why = 0, "quiet-hold"
    else:
        step, why = 0, "hold"
    nw = min(WMAX, max(WMIN, w + step))
    na = min(AMAX, max(AMIN, a + step))
    if fleet_idle(mode):
        na = 0
    return dict(step=step, why=why, W=nw, A=na, WMAX=WMAX, AMAX=AMAX)


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
    keep = [x for x in m.group(1).split() if not x.startswith("worker_")]
    workers = sorted((x for x in alive_seats() if x.startswith("worker_")), key=lambda x: int(x.split("_")[1]))[:A]
    live = keep + workers
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


def tick():
    os.makedirs(TICK_DIR, exist_ok=True)
    lock = open(TICK_DIR + "/tick.lock", "a+")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("REFUSE(3): another tick holds %s/tick.lock" % TICK_DIR); return 3
    t0 = time.time()
    n = read_int(TICK_DIR + "/tick.count", 0) + 1
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
    view = regenerate_view()
    with open(TICK_DIR + "/decide.last", "w") as f:
        f.write(json.dumps(dict(tick=n, sensors=s, decision=d, grader=grader, awake=awake, liveset=liveset, expired=expired, view=view)) + "\n")
    ru = resource.getrusage(resource.RUSAGE_SELF); rc = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_s = ru.ru_utime + ru.ru_stime + rc.ru_utime + rc.ru_stime
    print("TICK unit=s4e-tick.timer controller=box_tick.py tick=%d psi10=%.1f psi60=%.1f psi300=%.1f load1=%.1f mem_rise=%d step=%+d why=%s W=%d/%d A=%d/%d %s %s %s expired=%d %s secs=%d cpu_s=%.2f%s"
          % (n, s["cpu10"], s["cpu60"], s["cpu300"], s["load1"], s.get("mem_rise", 0), d["step"], d["why"], d["W"], d["WMAX"], d["A"], d["AMAX"],
             grader, awake, liveset, expired, view, int(time.time() - t0), cpu_s, " dry=1" if DRY else ""))
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
    print("WIDTH_PSI quiet=%+d hot=%+d middling=%+d mem_rise=%+d odd_tick=%+d W=%d->%d/%d A=%d->%d ok=%d"
          % (q["step"], h["step"], m["step"], r["step"], hold_odd["step"], 2, q["W"], q["WMAX"], 4, q["A"], ok))
    return 0 if ok else 1


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "--tick"
    if arg == "--tick":
        sys.exit(tick())
    if arg == "--probe-width":
        sys.exit(probe_width())
    if arg == "--decide":
        mode = mode_text(); s = sense(); print(json.dumps(decide(s, current_width(), current_awake(mode), mode, read_int(TICK_DIR + "/tick.count", 0) + 1))); sys.exit(0)
    print("usage: box_tick.py --tick | --probe-width | --decide"); sys.exit(2)
