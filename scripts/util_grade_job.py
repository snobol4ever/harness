#!/usr/bin/env python3
# util_grade_job.py -- THE GRADE JOB (DESIGN-PLAN test-cycle step 1, CTO-522; the cio 2026-11-05; skill suites-and-grading section 7). One job in tube `grade` is
# ONE CELL: suite key, cell (core | shell:F | chunk:NN | entry:a,b,... | all for a small suite), modes, tree, requester; its priority is its band (100 request, 200 smoke, 500 impact,
# 900 lap); its TTR is the cell's declared budget: the launch (120 s) plus every row's timeout_s from the suite's ALL.csv (60 s when the table declares none yet, test-cycle
# step 6 declares them). The table is the one harness/scripts/SUITE_RUNNERS.tsv names for the key (step 5a): kind master or port -> corpus/tests/<lang>; kind pkg -> the row's
# table column; kind small -> its table column, or no table (TTR 3600 s). The body is one JSON object; util_queue.py is the one client underneath (never a second socket).
#   util_grade_job.py put --suite KEY --cell CELL --band request|smoke|impact|lap [--modes m3,m4] [--tree HASH] [--requester SEAT] [--ttr S] [--tube T]   prints the GRADE_JOB line and the job id (--tube T: a scratch tube for a probe, default grade; step 4b)
#   util_grade_job.py put-many --band B [--tree H] [--tube T] [--requester S] --stdin   one line per cell, "suite<TAB>cell"; ONE connection, one GRADE_JOB line and one "job=N tube=T" line per cell (step 5a)
#   util_grade_job.py budget --suite KEY --cell CELL                      prints "BUDGET suite= cell= entries=N ttr_s=N declared=N"
#   util_grade_job.py --probe                                             puts one request-band core job of a snobol4 suite at origin's tree, prints its line, deletes it
#   util_grade_job.py --probe-many                                        puts three cells through put-many under strace, reads the python3 execve count, deletes every job (step 5a)
# rc 0 ok, 1 nothing/red, 2 refuse (unknown suite, unreadable table, daemon unreachable).
import os, sys, json, csv, re, shutil, subprocess
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SUITES = "/home/resources/progress/SUITES.tsv"
RUNNERS = os.path.join(S4E, "harness", "scripts", "SUITE_RUNNERS.tsv")
BAND = {"request": 100, "smoke": 200, "impact": 500, "lap": 900}
LAUNCH_S = 120; DEFAULT_TIMEOUT_S = 60; SMALL_TTR_S = 3600
def refuse(m, rc=2): print("REFUSE(%d) [util_grade_job]: %s" % (rc, m)); sys.exit(rc)
def suite_lang(key):
    try:
        for l in open(SUITES):
            f = l.rstrip("\n").split("\t")
            if len(f) > 3 and f[0] == key: return f[3]
    except OSError as e: refuse("no suite table: %s" % e)
    refuse("unknown suite key %r (column 1 of %s)" % (key, SUITES))
def runner_row(key):
    try:
        for l in open(RUNNERS):
            if l.startswith("#"): continue
            f = l.rstrip("\n").split("\t")
            if len(f) >= 5 and f[0] == key: return f[1], f[2], f[4]
    except OSError as e: refuse("no runner table %s: %s" % (RUNNERS, e))
    refuse("suite key %r has no row in %s" % (key, RUNNERS))
def table_dir(key):
    kind, lang, table = runner_row(key)
    if kind in ("master", "port"): return os.path.join(S4E, "corpus", "tests", lang)
    if kind in ("pkg", "small"): return None if table == "-" else os.path.join(S4E, table)
    refuse("suite %r kind %r has no table (master|port|pkg|small)" % (key, kind))
def cell_entries(key, cell):
    if runner_row(key)[0] == "small":
        if cell != "all": refuse("small suite %r takes cell all only" % key)
        return ["all"]
    d = table_dir(key)
    if d is None: refuse("suite %r has no partition table" % key)
    part = os.path.join(d, "PARTITION.tsv")
    try:
        rows = [l.rstrip("\n").split("\t") for l in open(part) if not l.startswith("#")]
    except OSError: refuse("no partition table %s" % part)
    head = rows[0]; rows = rows[1:]; ie = head.index("entry"); ip = head.index("part"); ish = head.index("shells") if "shells" in head else None
    if cell == "core": return [r[ie] for r in rows if r[ip] == "core"]
    if cell.startswith("shell:"):
        f = cell[6:]; return [r[ie] for r in rows if ish is not None and f in r[ish].split()]
    if cell.startswith("chunk:"): return [r[ie] for r in rows if r[ip] == cell]
    if cell.startswith("entry:"): return cell[6:].split(",")
    refuse("cell %r is not core | shell:F | chunk:NN | entry:a,b" % cell)
def _all_rows(d):
    p = os.path.join(d, "ALL.csv")
    try:
        with open(p, newline="") as fh: return list(csv.DictReader(fh))
    except OSError: refuse("no master table %s" % p)
def timeouts(key):
    d = table_dir(key); out = {}; declared = 0
    if d is None: return out, declared
    for r in _all_rows(d):
        t = r.get("timeout_s")
        if t and t.strip().isdigit(): out[r["entry"]] = int(t); declared += 1
        else: out[r["entry"]] = DEFAULT_TIMEOUT_S
    return out, declared
def budget(key, cell):
    lang = suite_lang(key); ents = cell_entries(key, cell)
    if runner_row(key)[0] == "small":
        d = table_dir(key)
        ttr = SMALL_TTR_S if d is None else LAUNCH_S + DEFAULT_TIMEOUT_S * len(_all_rows(d))
        return lang, ents, ttr, 0
    to, declared = timeouts(key)
    ttr = LAUNCH_S + sum(to.get(e, DEFAULT_TIMEOUT_S) for e in ents)
    return lang, ents, ttr, sum(1 for e in ents if e in to and declared)
def origin_tree():
    try: return subprocess.run(["git", "-C", os.path.join(S4E, "SCRIP"), "rev-parse", "--short=9", "origin/main"], capture_output=True, text=True, check=True).stdout.strip()
    except Exception: return "0000000"
def line(j): return "GRADE_JOB suite=%s cell=%s modes=%s tree=%s pri=%d ttr_s=%d requester=%s entries=%d" % (j["suite"], j["cell"], j["modes"], j["tree"], j["pri"], j["ttr_s"], j["requester"], j["entries"])
def job_for(suite, cell, band, tree, requester, ttr=None, modes="m3,m4"):
    if band not in BAND: refuse("band %r" % band)
    lang, ents, bttr, declared = budget(suite, cell)
    return {"suite": suite, "cell": cell, "modes": modes, "tree": tree, "requester": requester, "pri": BAND[band], "ttr_s": int(ttr or bttr), "entries": len(ents)}
def q(*args):
    r = subprocess.run([sys.executable, os.path.join(S4E, "harness", "scripts", "util_queue.py")] + list(args), capture_output=True, text=True)
    if r.returncode != 0: refuse("util_queue.py %s: %s" % (args[0], (r.stdout + r.stderr).strip()[:200]), r.returncode if r.returncode in (1, 2) else 2)
    return r.stdout.strip()
def put(j, tube="grade"):
    jid = q("put", tube, json.dumps(j, sort_keys=True), "--pri", str(j["pri"]), "--ttr", str(j["ttr_s"])); return int(jid)
def queue_client():
    sys.path.insert(0, os.path.join(S4E, "harness", "scripts"))
    import util_queue
    return util_queue.client()
def put_many(opts):
    band = opts.get("band") or refuse("put-many needs --band request|smoke|impact|lap")
    if band not in BAND: refuse("band %r" % band)
    tree = opts.get("tree") or origin_tree()
    requester = opts.get("requester") or os.environ.get("S4E_SEAT", "?")
    tube = opts.get("tube", "grade")
    jobs = []
    for n, raw in enumerate(sys.stdin, 1):
        raw = raw.rstrip("\n")
        if not raw.strip() or raw.startswith("#"): continue
        f = raw.split("\t")
        if len(f) != 2 or not f[0] or not f[1]: refuse("put-many line %d: want suite<TAB>cell, got %r" % (n, raw))
        jobs.append(job_for(f[0], f[1], band, tree, requester, opts.get("ttr"), opts.get("modes", "m3,m4")))
    if not jobs: refuse("put-many: no cells on stdin")
    gs, c = queue_client()
    try:
        c.use(tube)
        for j in jobs:
            jid = c.put(json.dumps(j, sort_keys=True), priority=j["pri"], ttr=j["ttr_s"])
            print(line(j)); print("job=%d tube=%s" % (jid, tube))
    finally:
        c.close()
def probe_many():
    if not shutil.which("strace"): refuse("strace is not installed (the execve count needs it)")
    seat = os.environ.get("S4E_SEAT", "probe")
    tube = "grade-many-%d" % os.getpid()
    scratch = os.path.join("/tmp/s4e", seat, "grade-many-probe"); os.makedirs(scratch, exist_ok=True)
    trace = os.path.join(scratch, "execve-%d.trace" % os.getpid())
    cells = ["sno-rungs\tcore", "sno-rungs\tchunk:01", "logtalk\tcore"]
    cmd = ["strace", "-f", "-e", "trace=execve", "-o", trace, sys.executable, "-I", os.path.abspath(__file__),
           "put-many", "--band", "request", "--tube", tube, "--requester", "probe-many", "--stdin"]
    r = subprocess.run(cmd, input="\n".join(cells) + "\n", capture_output=True, text=True)
    if r.returncode != 0: refuse("put-many under strace rc=%d: %s" % (r.returncode, (r.stdout + r.stderr).strip()[:200]))
    jobs = [int(l[4:].split()[0]) for l in r.stdout.splitlines() if l.startswith("job=")]
    execs = 0
    try:
        with open(trace) as fh:
            for l in fh:
                if re.search(r'execve\("[^"]*python3[^"]*",.*\) = 0$', l): execs += 1
    except OSError as e: refuse("no execve trace %s: %s" % (trace, e))
    gs, c = queue_client(); deleted = 0
    try:
        for jid in jobs:
            try: c.delete(jid); deleted += 1
            except gs.NotFoundError: pass
    finally:
        c.close()
    ok = 1 if jobs and len(jobs) == len(cells) and deleted == len(jobs) and execs == 1 else 0
    print("PUT_MANY cells=%d put=%d python_execs=%d deleted=%d ok=%d" % (len(cells), len(jobs), execs, deleted, ok))
    sys.exit(0 if ok else 1)
def main(a):
    if not a: refuse("usage: util_grade_job.py put|put-many|budget|--probe|--probe-many ...")
    if a[0] == "--probe":
        key = next((l.split("\t")[0] for l in open(SUITES) if l.split("\t")[3:4] == ["snobol4"] and not l.startswith("#")), None) or refuse("no snobol4 suite in the table")
        lang, ents, ttr, declared = budget(key, "core")
        j = {"suite": key, "cell": "core", "modes": "m3,m4", "tree": origin_tree(), "requester": os.environ.get("S4E_SEAT", "probe"), "pri": BAND["request"], "ttr_s": ttr, "entries": len(ents)}
        jid = put(j); print(line(j)); q("delete", str(jid)); print("probe job=%d deleted=1 declared_timeouts=%d" % (jid, declared)); sys.exit(0 if ents else 1)
    if a[0] == "--probe-many": return probe_many()
    opts = {}; i = 1
    while i < len(a):
        if a[i] == "--stdin": opts["stdin"] = "1"; i += 1
        elif a[i].startswith("--") and i + 1 < len(a): opts[a[i][2:]] = a[i + 1]; i += 2
        else: refuse("bad argument " + a[i])
    if a[0] == "budget":
        lang, ents, ttr, declared = budget(opts["suite"], opts["cell"]); print("BUDGET suite=%s cell=%s lang=%s entries=%d ttr_s=%d declared=%d" % (opts["suite"], opts["cell"], lang, len(ents), ttr, declared)); return
    if a[0] == "put-many": return put_many(opts)
    if a[0] == "put":
        band = opts.get("band") or refuse("put needs --band request|smoke|impact|lap")
        if band not in BAND: refuse("band %r" % band)
        j = job_for(opts["suite"], opts["cell"], band, opts.get("tree") or origin_tree(), opts.get("requester") or os.environ.get("S4E_SEAT", "?"), opts.get("ttr"), opts.get("modes", "m3,m4"))
        tube = opts.get("tube", "grade")
        jid = put(j, tube); print(line(j)); print("job=%d tube=%s" % (jid, tube)); return
    refuse("unknown verb " + a[0])
main(sys.argv[1:])
