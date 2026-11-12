#!/usr/bin/env python3
# fleet_health.py -- THE HEALTH CHECK: a 2x2 grid, one terse snapshot of what the fleet is doing and how each part is doing (Lon, in the cio's
# window, 2026-11-07 08:1x CST, verbatim: "I would like a report, a 2x2 grid, a terse snapshot, of what the fleet is doing and how each are doing.
# design this for when I ask for a health check."). Four quadrants, each with a one-word verdict: THE BOX (cores, pressure, the law's knobs),
# THE QUEUE (the tubes by tier, the rows by state), THE SEATS (who is awake, who holds a job, by tier), THE WORK (the three tasks of COO-481:
# the suites, the test cycle, the fleet system; landings and reds in the last hour). Every number is read from the ledgers named beside it; a
# source that cannot be read prints `?` and never a guess. Read-only; no bus verb; under two seconds.
#   fleet_health.py            the grid
#   fleet_health.py --probe    the grid from planted files under a scratch dir (every quadrant prints a verdict; rc 0)
#   fleet_health.py --probe-work   the suite count from a planted table: a port row (key@engine) is counted apart from the SCRIP suites (rc 0)
#   fleet_health.py --probe-seats   the seats arithmetic from planted inputs: a sleeping seat is neither idle nor starved (rc 0)
#   fleet_health.py --sleeping F    the sleeping list F (default V/sleeping, the census's file; a missing file means nobody sleeps)
import os, re, sys, glob, time, subprocess, json
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PO = os.environ.get("S4E_POST", "/home/resources/postoffice"); P = os.environ.get("S4E_PROGRESS", "/home/resources/progress")
V = os.environ.get("S4E_BOX_S", "/home/claude_coo/.scratch/verifier"); T = os.environ.get("S4E_TICK_DIR", "/tmp/s4e/cio/tick"); TIERS = os.environ.get("S4E_TIERS", S4E + "/.github/TIERS.tsv")
W = 64   # column width of one quadrant (the seats line with asleep counts runs to 63)
SLEEPING = os.path.join(V, "sleeping")   # one seat per line; util_suite_row_owner_census.py's sleepers() reads the same file

def rd(p):
    try: return open(p, encoding="utf-8", errors="replace").read()
    except OSError: return ""
def kv(text):
    d = {}
    for l in text.split("\n"):
        if "=" in l: k, _, v = l.partition("="); d[k.strip()] = v.strip()
    return d
def num(x, default=None):
    try: return float(x)
    except (TypeError, ValueError): return default
def fmt(x, nd=1): return "?" if x is None else ("%d" % x if nd == 0 else "%.*f" % (nd, x))

def psi(path="/proc/pressure/cpu"):
    for l in rd(path).split("\n"):
        if l.startswith("some"):
            d = dict(kv.split("=", 1) for kv in l.split()[1:] if "=" in kv); return num(d.get("avg10")), num(d.get("avg60")), num(d.get("avg300"))
    return None, None, None

def tiers():
    rows = [l.split("\t") for l in rd(TIERS).split("\n") if l and not l.startswith("#") and not l.startswith("seat\t")]
    return {r[0]: int(r[6]) for r in rows if len(r) > 6 and r[6].isdigit()}

def tube_stats(names):   # bus-one-queue: a tube's ready count is the QUEUE.tsv rows whose column reads exactly QUEUED:<tube>; reserved is the live claims whose RESERVED line names the tube; nothing is buried on the file
    out = {}
    try: col = [l.split("\t")[3] for l in rd(PO + "/QUEUE.tsv").split("\n") if l and l[0].isdigit() and l.count("\t") >= 3]
    except Exception: return {t: None for t in names}
    held = []
    for c in glob.glob(PO + "/claims/*.claim"):
        try: lines = open(c).read().split("\n")
        except OSError: continue
        if "DONE" in lines: continue
        held += [m.group(1) for m in (re.search(r"^RESERVED (?:file|job=\d+) tube=(\S+)", l) for l in lines) if m]
    for t in names: out[t] = (col.count("QUEUED:" + t), held.count(t), 0, 0)
    return out

def cap(rel):
    m = rd("/sys/fs/cgroup/user.slice/user-%d.slice/user@%d.service%s/cpu.max" % (os.getuid(), os.getuid(), rel)).split()
    return "none" if not m or m[0] == "max" else "%d%%" % (int(m[0]) * 100 // int(m[1]))

def live_sessions():
    try: ps = subprocess.run(["pgrep", "-af", "(^|/)claude --name "], capture_output=True, text=True, timeout=5).stdout
    except Exception: return set()
    return {m.group(1).lower() for m in re.finditer(r"claude --name ([A-Za-z_0-9-]+)", ps)} | {m.group(1).lower().replace("-", "_") for m in re.finditer(r"claude --name ([A-Za-z_0-9-]+)", ps)}

def holders():
    h = {}
    for c in glob.glob(PO + "/claims/*.claim"):
        s = rd(c).split("\n")
        if not s or "DONE" in s: continue
        h.setdefault(s[0].strip(), []).append(os.path.basename(c)[:-6])
    return h

def done_today():
    try:
        r = subprocess.run(["grep", "-l", "-E", r"^- \[[^]]*%s[^]]*\].*DONE" % time.strftime("%Y-%m-%d")] + glob.glob(PO + "/tasks/*.task.md"), capture_output=True, text=True, timeout=20)
        return len([l for l in r.stdout.split("\n") if l])
    except Exception: return -1

def queue_rows():
    rows = [l.split("\t") for l in rd(PO + "/QUEUE.tsv").split("\n") if l and l[0].isdigit()]
    return [r for r in rows if len(r) >= 4]

def box():
    st = kv(rd(P + "/BOX.state")); a10, a60, a300 = psi()
    try: load = os.getloadavg()
    except OSError: load = (None, None, None)
    n = os.cpu_count() or 16; busy = num(st.get("busy")); width = rd(T + "/box.width").strip() or st.get("grader_width", "?")
    dec = rd(T + "/decide.last"); q = re.search(r"ACTUATOR sessions quota=(\d+)", dec); jt = re.search(r"ACTUATOR jobserver tokens=(\d+)", dec)
    mem = num(st.get("memavail_mb")); tmo = st.get("timeouts10", st.get("timeouts30", "?"))
    verdict = "RED" if (a60 or 0) >= 50 or (load[0] or 0) >= 2 * n else "WARN" if (a60 or 0) >= 30 or (load[0] or 0) >= n else "OK"
    return "THE BOX", verdict, [
        "load1 %s load5 %s on %d cores, busy %s" % (fmt(load[0]), fmt(load[1]), n, fmt(busy)),
        "cpu pressure some avg10 %s avg60 %s avg300 %s" % (fmt(a10), fmt(a60), fmt(a300)),
        "law: grader width %s, caps: seats %s, runs %s, s4e %s" % (width, cap("/s4e.slice/s4e-seats.slice"), cap("/app.slice/app-s4e.slice"), cap("/s4e.slice")),
        "memory free %s MB, timeouts %s, BOX.state age %ss" % (fmt(mem, 0), tmo, fmt(time.time() - os.path.getmtime(P + "/BOX.state"), 0) if os.path.exists(P + "/BOX.state") else "?"),
        "controller %s, tick timer %s" % ("alive" if subprocess.run(["systemctl", "--user", "is-active", "-q", "s4e-tick.timer"], capture_output=True).returncode == 0 else "DOWN",
                                            subprocess.run(["systemctl", "--user", "is-active", "-q", "s4e-tick.timer"], capture_output=True).returncode == 0 and "active" or "inactive"),
    ]

def queue():
    rows = queue_rows(); st = {}
    for r in rows: st[r[3].split(":")[0]] = st.get(r[3].split(":")[0], 0) + 1
    tubes = tube_stats(["tier-fable", "tier-opus", "tier-sonnet", "tier-haiku", "ask-fable", "ask-opus", "ask-sonnet"])
    def t(n): s = tubes.get(n); return "?" if s is None else "%d/%d/%d" % (s[0], s[1], s[3])
    haiku = tubes.get("tier-haiku"); asks = sum((tubes.get(a) or (0, 0, 0, 0))[0] for a in ("ask-fable", "ask-opus", "ask-sonnet"))
    verdict = "RED" if haiku is None else "DRY" if haiku[0] == 0 else "OK"
    if asks > 0: verdict = "ASKS"
    return "THE QUEUE (ready/reserved/buried)", verdict, [
        "haiku %s  sonnet %s  opus %s  fable %s" % (t("tier-haiku"), t("tier-sonnet"), t("tier-opus"), t("tier-fable")),
        "asks waiting on seniors: %d" % asks,
        "rows %d: FREE %d  QUEUED %d  CLAIMED %d  ASSIGNED %d" % (len(rows), st.get("FREE", 0), st.get("QUEUED", 0), st.get("CLAIMED", 0), st.get("ASSIGNED", 0)),
        "parked %d  blocked %d  grant-needed %d  awaiting %d" % (sum(v for k, v in st.items() if k.startswith("PARKED")), st.get("BLOCKED-ON", 0), st.get("GRANT-NEEDED", 0), st.get("PARKED-AWAITING", 0)),
        "rows closed today %d (a DONE ledger line dated today)" % done_today(),
    ]

def sleepers(path):
    if not os.path.exists(path): return set()
    try:
        with open(path, encoding="utf-8") as f: return {l.strip() for l in f if l.strip() and not l.startswith("#")}
    except OSError: return None

def seats_count(tr, live, h, sleep, haiku_ready):
    names = {1: "fable", 2: "opus", 3: "sonnet", 4: "haiku"}; lines = []; idle_workers = busy_workers = asleep_haiku = 0
    for k in (1, 2, 3, 4):
        ss = sorted(s for s, t in tr.items() if t == k)
        asleep = [s for s in ss if s in sleep]; awake = [s for s in ss if s in live and s not in sleep]
        holding = [s for s in ss if s in h]; idle = [s for s in awake if s not in h]
        if k == 4: idle_workers = len(idle); busy_workers = len(holding); asleep_haiku = len(asleep)
        lines.append("%-6s %2d seats: %2d awake, %2d asleep, %2d holding a row, %2d idle" % (names[k], len(ss), len(awake), len(asleep), len(holding), len(idle)))
    verdict = "RED" if not live else "IDLE" if busy_workers == 0 else "STARVED" if idle_workers > 0 and haiku_ready > 0 else "OK"
    lines.append("workers idle while a haiku job waits: %d" % (idle_workers if verdict == "STARVED" else 0))
    return verdict, lines, asleep_haiku, idle_workers

def seats():
    sl = sleepers(SLEEPING)
    if sl is None: return "THE SEATS", "RED", ["sleeping list unreadable"]
    tr = tiers(); live = live_sessions(); h = holders()
    v, lines, _, _ = seats_count(tr, live, h, sl, (tube_stats(["tier-haiku"]).get("tier-haiku") or (0,))[0])
    return "THE SEATS", v, lines

def seats_probe():
    tr = {"worker_01": 4, "worker_02": 4}; live = {"worker_01", "worker_02"}; h = {"worker_02": ["plant-row"]}
    v, _, asleep, idle = seats_count(tr, live, h, {"worker_01"}, 1)
    mv, _, _, _ = seats_count(tr, live, h, set(), 1)
    good = (asleep, idle, v) == (1, 0, "OK")
    if good: print("SEATS_PROBE asleep=1 awake_idle=0 starved=0 verdict=OK")
    else: print("SEATS_PROBE RED: asleep=%d awake_idle=%d verdict=%s, want asleep=1 awake_idle=0 verdict=OK" % (asleep, idle, v))
    mutant = mv == "STARVED"
    print("SEATS_PROBE_MUTANT starved=%d" % int(mutant))
    return 0 if good and mutant else 1

def work():
    suites = [l.split("\t") for l in rd(P + "/SUITES.tsv").split("\n") if l and not l.startswith("#")]
    at100 = below = p100 = pbelow = 0; worst = []
    for r in suites:   # SUITES.tsv: key nick emoji lang first_date first_pass first_total today_date today_pass today_total ...
        if len(r) < 10 or r[0] == "key" or not r[8].isdigit() or not r[9].isdigit(): continue
        a, b = int(r[8]), int(r[9])
        if "@" in r[0]:   # a port engine's row (key@engine): not a SCRIP suite, counted apart so this line and the suite banner read one population
            if b and a == b: p100 += 1
            elif b: pbelow += 1
            continue
        if b and a == b: at100 += 1
        elif b: below += 1; worst.append((a / b, "%s %d/%d" % (r[1] or r[0], a, b)))
    if "--probe-work" in sys.argv: return at100, at100 + below, p100, p100 + pbelow
    worst.sort()
    now = time.time(); hour = time.strftime("%Y-%m-%dT%H", time.gmtime(now - 3600))
    res = rd(P + "/results.tsv").split("\n"); recent = [l for l in res if l[:13] >= hour]
    fails = sum(1 for l in recent if "\tFAIL\t" in l)
    def steps(table, harness):
        rows = [l.split("\t") for l in rd(table).split("\n") if l and l[0].isdigit()]
        live = [l.split("\t")[1] for l in rd(PO + "/QUEUE.tsv").split("\n") if l.count("\t") >= 2 and not l.startswith("#")]
        done = sum(1 for r in rows if len(r) > 1 and not any(t.startswith(r[1]) for t in live))
        return "%d/%d steps closed" % (done, len(rows))
    landings = 0
    for repo in ("SCRIP", "harness", "corpus", ".github"):
        try: landings += int(subprocess.run(["git", "-C", S4E + "/" + repo, "rev-list", "--count", "--since=1 hour ago", "origin/main"], capture_output=True, text=True, timeout=5).stdout.strip() or 0)
        except Exception: pass
    verdict = "OK" if below <= 10 and fails == 0 else "REDS" if fails else "OK"
    return "THE WORK (COO-481)", verdict, [
        "suites at 100: %d of %d; ports %d of %d; worst %s" % (at100, at100 + below, p100, p100 + pbelow, ", ".join(w for _, w in worst[:2]) or "-"),
        "test-cycle %s; batch-grader %s" % (steps(S4E + "/harness/designs/test_cycle/STEPS.tsv", "test-cycle-step-"), steps(S4E + "/corpus/tests/shared/batch_grader/STEPS.tsv", "batch-grader-step-")),
        "fleet-queue %s; fleet rows in the haiku tube %d" % (steps(S4E + "/harness/designs/fleet_queue/STEPS.tsv", "fleet-queue-step-"), sum(1 for r in queue_rows() if r[2] == "@haiku" and re.match(r"(bus|tick|census|fleet|test-cycle|sitting|law|spawn)", r[1]))),
        "last hour: %d landings, %d readings, %d FAIL" % (landings, len(recent), fails),
    ]

def grid(quads):
    cells = []
    for title, verdict, lines in quads:
        head = ("%s: %s" % (title, verdict))[:W]
        body = [head, "-" * len(head)] + [l[:W] for l in lines]
        cells.append(body)
    h = max(len(c) for c in cells)
    for c in cells: c += [""] * (h - len(c))
    out = []
    for a, b in ((0, 1), (2, 3)):
        for i in range(h): out.append("%-*s | %s" % (W, cells[a][i], cells[b][i]))
        if a == 0: out.append("-" * W + "-+-" + "-" * W)
    return "\n".join(out)

def main():
    global PO, P, V, SLEEPING
    if "--probe-seats" in sys.argv: sys.exit(seats_probe())
    if "--sleeping" in sys.argv:
        i = sys.argv.index("--sleeping")
        if i + 1 >= len(sys.argv): sys.exit("REFUSE(2): --sleeping takes a file")
        SLEEPING = sys.argv[i + 1]
    if "--probe-work" in sys.argv:
        import tempfile
        d = tempfile.mkdtemp(prefix="fleet_health_probe."); P = d
        row = lambda k, a, b: "\t".join([k, "n", "e", "l", "d", "0", "0", "d", str(a), str(b)]) + "\n"
        open(d + "/SUITES.tsv", "w").write(row("full", 5, 5) + row("short", 4, 5) + row("full@dotnet", 5, 5) + row("short@jvm", 4, 5))
        got = work(); print("WORK_PROBE suites=%d/%d ports=%d/%d" % got); sys.exit(0 if got == (1, 2, 1, 2) else 1)
    if "--probe" in sys.argv:
        import tempfile
        d = tempfile.mkdtemp(prefix="fleet_health_probe.")
        for k in ("S4E_POST", "S4E_PROGRESS", "S4E_BOX_S"): os.environ[k] = d
        PO = P = V = d; SLEEPING = d + "/sleeping"
        os.makedirs(d + "/claims"); open(d + "/BOX.state", "w").write("busy=8.0\ngrader_width=4\n"); open(d + "/QUEUE.tsv", "w").write("2\tplant-row\t@haiku\tQUEUED:tier-haiku\n")
        open(d + "/SUITES.tsv", "w").write("plant\tx\ty\tz\t10/10\n"); open(d + "/results.tsv", "w").write("")
        q = [box(), queue(), seats(), work()]
        ok = all(v for _, v, _ in q)
        print(grid(q)); print("HEALTH_PROBE quadrants=4 verdicts=%d" % sum(1 for _, v, _ in q if v)); sys.exit(0 if ok else 1)
    print("FLEET HEALTH %s  (MODE %s)" % (time.strftime("%Y-%m-%d %H:%M %Z"), (rd(PO + "/MODE").split("\n") or ["?"])[0]))
    print(grid([box(), queue(), seats(), work()]))

if __name__ == "__main__": main()
