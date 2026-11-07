#!/usr/bin/env python3
"""util_suite_row_owner_census.py [--suites F] [--queue F] [--tasks DIR] [--holder KEY] [--tiers F] [--claims DIR] [--tubes F] [--probe-seat-arm] -- EVERY SUITE BELOW 100 PERCENT HAS A ROW A SEAT
HOLDS, AND THE WORKER QUEUES ARE WORKED (the seat arm, SEAT_QUEUE_BOARD, below the suite arm: no starved worker, no cut job owed, no overdue escalation; either arm RED is rc 1).

Lon 2026-11-01 15:5x CST, in the coo's window, verbatim: "The goal is to get to 100% test suites, duh!" / "Well of course the bug fixes need
an owner and a row. WTF! How did you miss that." / "how will you not miss that next time. have you automated that process. you know you can
not trust your lying self." -- the coo found FPC, PasRungs, ProRungs and RakRungs below 100 with no live row, Jcon and ProRosetta with only a
FREE one, and util_red_coverage.py (R-1887) on file but run by nothing. This census is run by tier 1's fleet watch every five minutes and
telegrams the coo while it reads RED; it is not a memory.

Reads /home/resources/progress/SUITES.tsv (SCRIP rows: a key with no @) and, for every row not at 100 percent (today_pass < today_total,
no reading, or VOID), the live QUEUE rows (state not DONE, RETIRED or SUPERSEDED) whose DONE-WHEN line READS THAT SUITE: it names
util_suite_row_at_100.sh <key> or --suite <key>. A suite is
  OWNED          a reading row is CLAIMED:<seat> or ASSIGNED:<seat>
  HELD-BY-LON    a reading row is PARKED-LON-HOLD:<ruling> (Lon's hold, named on the row), or the suite is in RULED below (a standing ruling)
  UNOWNED        no reading row, or every reading row is FREE, PARKED or BLOCKED-ON -- RED, with the rows and their states named
Port-engine rows (<key>@<engine>) are counted and skipped: the ports are off the ROSTER by Lon's word of 2026-11-01 09:01.
Board line: SUITE_OWNER_BOARD suites=<n> below_100=<b> owned=<o> held_by_lon=<h> unowned=<u> ports_skipped=<p>
rc 0 every suite below 100 is OWNED or HELD-BY-LON; rc 1 RED, one line per UNOWNED suite ("  RED  suite <key> <p>/<n>: ..."); rc 2 could
not read the table or the queue, or the table holds no SCRIP row.
--holder KEY prints the seat holding the suite's reading row (one line, "-" when none) and exits 0; the loop routes a suite's red there.
"""
import os, re, sys
RULED = {
    "roast": "R-2070: Raku climbs the cto's rung ladder, not the suites, until half the rungs are green",
    "raku-demos": "R-2070: Raku climbs the cto's rung ladder, not the suites, until half the rungs are green",
}
CLOSED = ("DONE", "RETIRED", "SUPERSEDED")
def arg(name, default):
    a = sys.argv[1:]
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else default
SUITES = arg("--suites", "/home/resources/progress/SUITES.tsv")
QUEUE = arg("--queue", "/home/resources/postoffice/QUEUE.tsv")
TASKS = arg("--tasks", "/home/resources/postoffice/tasks")
def refuse(why): print("REFUSE(2): " + why); sys.exit(2)
try: lines = [l.rstrip("\n").split("\t") for l in open(SUITES, encoding="utf-8") if not l.startswith("#")]
except OSError as e: refuse("%s unreadable: %s" % (SUITES, e))
if not lines: refuse("%s is empty" % SUITES)
head = lines[0]
for col in ("key", "today_pass", "today_total"):
    if col not in head: refuse("%s has no %s column" % (SUITES, col))
rows = [dict(zip(head, x)) for x in lines[1:] if x and x[0]]
try: queue = [l.split("\t") for l in open(QUEUE, encoding="utf-8").read().split("\n")]
except OSError as e: refuse("%s unreadable: %s" % (QUEUE, e))
READS = re.compile(r"""(?:util_suite_row_at_100\.sh|--suite)\s+["']?([A-Za-z0-9_@.-]+)""")
readers = {}
for f in queue:
    if len(f) < 4 or not f[0].isdigit() or f[3].split(":")[0] in CLOSED: continue
    try: text = open(os.path.join(TASKS, f[1] + ".task.md"), encoding="utf-8", errors="replace").read()
    except OSError: continue
    for line in text.split("\n"):
        if line.startswith("DONE-WHEN:"):
            for k in set(READS.findall(line)): readers.setdefault(k, []).append((f[1], f[3]))
def holder_of(key):
    for topic, state in readers.get(key, []):
        if state.startswith(("CLAIMED:", "ASSIGNED:")): return state.split(":", 1)[1]
    return "-"
if "--holder" in sys.argv[1:]:
    print(holder_of(arg("--holder", ""))); sys.exit(0)
n = below = owned = held = 0; ports = 0; reds = []
for r in rows:
    k = r["key"]
    if "@" in k: ports += 1; continue
    n += 1
    try: p, t = int(r["today_pass"]), int(r["today_total"])
    except ValueError: p, t = 0, -1
    void = (r.get("today_void") or "").strip()
    if t > 0 and p >= t and not void: continue
    below += 1
    score = "%d/%d" % (p, t) if t >= 0 else "no-reading"
    if void: score += " VOID"
    rd = readers.get(k, [])
    if any(s.startswith(("CLAIMED:", "ASSIGNED:")) for _, s in rd): owned += 1; continue
    if k in RULED or any(s.startswith("PARKED-LON-HOLD") for _, s in rd): held += 1; continue
    if not rd: reds.append("  RED  suite %s %s: no live row reads this suite (mint one, DONE-WHEN util_suite_row_at_100.sh %s, owner the lane, then assign)" % (k, score, k))
    else: reds.append("  RED  suite %s %s: no seat holds its row -- %s (assign it to the lane)" % (k, score, "; ".join("%s [%s]" % (tp, st) for tp, st in rd)))
if n == 0: refuse("%s holds no SCRIP row" % SUITES)
print("SUITE_OWNER_BOARD suites=%d below_100=%d owned=%d held_by_lon=%d unowned=%d ports_skipped=%d" % (n, below, owned, held, len(reds), ports))
for x in reds: print(x)
# THE SEAT ARM (the cio, fleet-queue, 2026-11-07, on COO-481 and THE LADDER: a senior starts no task and serves escalations only; a worker holds only the job the queue serves it).
# It reads three things: the TIERS table (tier 4 is a worker, tiers 1-3 are seniors), the claims (a seat holds a job when a claim file's first line is the seat and it has a RESERVED job= line and no DONE) and the tube stats (tier-haiku, every seat-<worker> tube, and ask-<tier> and tier-<tier> of tiers 1-3).
#   STARVED       a worker to wake: an idle worker whose own seat tube holds a ready job, then one idle worker per ready tier-haiku job, its job waiting. RED, one line per starved worker.
#   DRY           idle workers minus ready tier-haiku jobs, when positive: the designers owe that many cut jobs. RED, printed DRY owed=N by cio,cto.
#   OVERDUE       an ask-<tier> or tier-<tier> job of tiers 1-3 ready longer than 1800 s (the escalation timeout, fleet-queue 9). RED, one line per overdue tube.
#   SENIOR_SHORT  a senior holding exactly one row. Informational, never rc: a senior holding zero rows is GREEN.
# rc 1 when STARVED, DRY or OVERDUE is above 0. --probe-seat-arm plants the three inputs in a scratch dir and prints SEAT_ARM_PROBE when it reads them as the cio's ruling says.
import subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TIERS = arg("--tiers", os.path.join(ROOT, ".github", "TIERS.tsv")); CLAIMS = arg("--claims", "/home/resources/postoffice/claims"); TUBES = arg("--tubes", None)
OVERDUE_S = 1800; UQ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "util_queue.py")
def table(path, need):
    try: rows = [l.rstrip("\n").split("\t") for l in open(path, encoding="utf-8") if l.strip() and not l.startswith("#")]
    except OSError as e: refuse("%s unreadable: %s" % (path, e))
    if len(rows) < 2: refuse("%s holds no rows" % path)
    for col in need:
        if col not in rows[0]: refuse("%s has no %s column" % (path, col))
    return [dict(zip(rows[0], r)) for r in rows[1:] if r and r[0]]
def live_tube(name, need_age):
    out = subprocess.run([sys.executable, UQ, "stats-tube", name], capture_output=True, text=True, timeout=60).stdout
    m = re.search(r"ready=(\d+)", out)
    if m is None: refuse("util_queue.py stats-tube %s printed no ready count: %s" % (name, out.strip()))
    ready, age = int(m.group(1)), 0
    if ready and need_age:
        pk = subprocess.run([sys.executable, UQ, "peek", name], capture_output=True, text=True, timeout=60).stdout.split("\t")
        if len(pk) > 3 and pk[3].strip().isdigit(): age = int(pk[3])
    return ready, age
def tsv_tube(path):
    rows = {r["tube"]: (int(r["ready"]), int(r["oldest_ready_age_s"])) for r in table(path, ("tube", "ready", "oldest_ready_age_s"))}
    return lambda name, need_age: rows.get(name, (0, 0))
def holdings(d):
    if not os.path.isdir(d): refuse("%s is not a directory" % d)
    held = {}
    for f in sorted(os.listdir(d)):
        if not f.endswith(".claim"): continue
        try: lines = open(os.path.join(d, f), encoding="utf-8", errors="replace").read().split("\n")
        except OSError: continue
        if not lines[0].strip() or any(l.startswith("DONE") for l in lines): continue
        if any(l.startswith("RESERVED job=") for l in lines): held.setdefault(lines[0].strip(), []).append(f)
    return held
def seat_arm(seats, held, tube):
    workers = [s["seat"] for s in seats if s["tier"] == "4"]
    idle = [w for w in workers if w not in held]
    haiku = tube("tier-haiku", False)[0]
    waiting = [w for w in idle if tube("seat-" + w, False)[0] > 0]
    pool = [w for w in idle if w not in waiting][:haiku]
    names = {}
    for s in seats: names.setdefault(s["tier"], s["model"].split("-")[1])
    overdue = []
    for t in ("1", "2", "3"):
        for pre in ("ask-", "tier-"):
            if t not in names: continue
            ready, age = tube(pre + names[t], True)
            if ready and age > OVERDUE_S: overdue.append((pre + names[t], ready, age))
    return {"workers": len(workers), "idle": len(idle), "haiku": haiku,
            "starved": [(w, "seat-%s holds a ready job" % w) for w in waiting] + [(w, "tier-haiku ready=%d" % haiku) for w in pool],
            "owed": max(0, len(idle) - haiku), "overdue": overdue,
            "short": [s["seat"] for s in seats if s["tier"] in ("1", "2", "3") and len(held.get(s["seat"], [])) == 1]}
if "--probe-seat-arm" in sys.argv[1:]:
    import shutil, tempfile
    d = tempfile.mkdtemp(prefix="seat_arm_probe_")
    try:
        with open(os.path.join(d, "TIERS.tsv"), "w") as f:
            f.write("seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\n")
            f.write("cio\tCIO\t/x\tclaude-fable-5-1\thigh\tred\t1\tfleet-system\n")
            f.write("coo\tCOO\t/x\tclaude-opus-5-5\txhigh\tgreen\t2\ttesting-officer\n")
            f.write("president\tPRESIDENT\t/x\tclaude-sonnet-5-5\txhigh\tpurple\t3\tcompany-man\n")
            for i in range(1, 21): f.write("worker_%02d\tWORKER_%02d\t/x\tclaude-haiku-5-5\txhigh\tcyan\t4\tworker\n" % (i, i))
        os.mkdir(os.path.join(d, "claims"))
        with open(os.path.join(d, "tubes.tsv"), "w") as f: f.write("tube\tready\toldest_ready_age_s\ntier-haiku\t1\t0\nask-opus\t1\t2000\n")
        a = seat_arm(table(os.path.join(d, "TIERS.tsv"), ("seat", "model", "tier")), holdings(os.path.join(d, "claims")), tsv_tube(os.path.join(d, "tubes.tsv")))
    finally: shutil.rmtree(d, ignore_errors=True)
    starved, dry, overdue, short = len(a["starved"]), int(a["owed"] > 0), len(a["overdue"]), len(a["short"])
    print("SEAT_ARM_PROBE starved=%d dry=%d overdue=%d senior_short=%d owed=%d" % (starved, dry, overdue, short, a["owed"]))
    sys.exit(0 if (starved, dry, overdue, short) == (1, 1, 1, 0) else 1)
a = seat_arm(table(TIERS, ("seat", "model", "tier")), holdings(CLAIMS), tsv_tube(TUBES) if TUBES else live_tube)
print("SEAT_QUEUE_BOARD workers=%d idle=%d haiku_ready=%d starved=%d dry=%d overdue=%d senior_short=%d owed=%d" % (a["workers"], a["idle"], a["haiku"], len(a["starved"]), int(a["owed"] > 0), len(a["overdue"]), len(a["short"]), a["owed"]))
for w, why in a["starved"]: print("  RED  worker %s starved: wake it, its job waits (%s)" % (w, why))
if a["owed"] > 0: print("  RED  DRY owed=%d by cio,cto: the designers owe %d cut jobs" % (a["owed"], a["owed"]))
for t, ready, age in a["overdue"]: print("  RED  OVERDUE %s ready=%d oldest=%ds: an escalation waits past %d s (fleet-queue 9)" % (t, ready, age, OVERDUE_S))
if a["short"]: print("  note  senior(s) holding exactly one row: %s (informational, not rc)" % " ".join(a["short"]))
if reds or a["starved"] or a["owed"] > 0 or a["overdue"]:
    print("RED: %d suite(s) below 100 percent with no seat holding a row; %d worker(s) starved, DRY owed %d, %d escalation tube(s) overdue" % (len(reds), len(a["starved"]), a["owed"], len(a["overdue"]))); sys.exit(1)
print("GREEN: every suite below 100 percent has a row a seat holds, or Lon's hold; no worker starved; no cut job owed; no escalation past %d s" % OVERDUE_S); sys.exit(0)
