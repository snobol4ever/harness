#!/usr/bin/env python3
# util_grade_job.py -- THE GRADE JOB (DESIGN-PLAN test-cycle step 1, CTO-522; the cio 2026-11-05; skill suites-and-grading section 7). One job in tube `grade` is
# ONE CELL: suite key, cell (core | shell:F | chunk:NN | entry:a,b,...), modes, tree, requester; its priority is its band (100 request, 200 smoke, 500 impact,
# 900 lap); its TTR is the cell's declared budget: the launch (120 s) plus every row's timeout_s from ALL.csv (60 s when the table declares none yet, test-cycle
# step 6 declares them). The body is one JSON object; util_queue.py is the one client underneath (never a second socket).
#   util_grade_job.py put --suite KEY --cell CELL --band request|smoke|impact|lap [--modes m3,m4] [--tree HASH] [--requester SEAT] [--ttr S]   prints the GRADE_JOB line and the job id
#   util_grade_job.py budget --suite KEY --cell CELL                      prints "BUDGET suite= cell= entries=N ttr_s=N declared=N"
#   util_grade_job.py --probe                                             puts one request-band core job of a snobol4 suite at origin's tree, prints its line, deletes it
# rc 0 ok, 1 nothing/red, 2 refuse (unknown suite, unreadable table, daemon unreachable).
import os, sys, json, csv, subprocess
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SUITES = "/home/resources/progress/SUITES.tsv"
BAND = {"request": 100, "smoke": 200, "impact": 500, "lap": 900}
LAUNCH_S = 120; DEFAULT_TIMEOUT_S = 60
def refuse(m, rc=2): print("REFUSE(%d) [util_grade_job]: %s" % (rc, m)); sys.exit(rc)
def suite_lang(key):
    try:
        for l in open(SUITES):
            f = l.rstrip("\n").split("\t")
            if len(f) > 3 and f[0] == key: return f[3]
    except OSError as e: refuse("no suite table: %s" % e)
    refuse("unknown suite key %r (column 1 of %s)" % (key, SUITES))
def cell_entries(lang, cell):
    part = os.path.join(S4E, "corpus", "tests", lang, "PARTITION.tsv")
    try:
        rows = [l.rstrip("\n").split("\t") for l in open(part) if not l.startswith("#")]
    except OSError: refuse("no partition table %s" % part)
    head = rows[0]; rows = rows[1:]; ie = head.index("entry"); ip = head.index("part"); ish = head.index("shells") if "shells" in head else None
    if cell == "core": return [r[ie] for r in rows if r[ip] == "core"]
    if cell.startswith("shell:"):
        f = cell[6:]; return [r[ie] for r in rows if ish is not None and f in r[ish].split(",")]
    if cell.startswith("chunk:"): return [r[ie] for r in rows if r[ip] == cell]
    if cell.startswith("entry:"): return cell[6:].split(",")
    refuse("cell %r is not core | shell:F | chunk:NN | entry:a,b" % cell)
def timeouts(lang):
    p = os.path.join(S4E, "corpus", "tests", lang, "ALL.csv"); out = {}; declared = 0
    try:
        with open(p, newline="") as fh:
            for r in csv.DictReader(fh):
                t = r.get("timeout_s")
                if t and t.strip().isdigit(): out[r["entry"]] = int(t); declared += 1
                else: out[r["entry"]] = DEFAULT_TIMEOUT_S
    except OSError: refuse("no master table %s" % p)
    return out, declared
def budget(key, cell):
    lang = suite_lang(key); ents = cell_entries(lang, cell); to, declared = timeouts(lang)
    ttr = LAUNCH_S + sum(to.get(e, DEFAULT_TIMEOUT_S) for e in ents)
    return lang, ents, ttr, sum(1 for e in ents if e in to and declared)
def origin_tree():
    try: return subprocess.run(["git", "-C", os.path.join(S4E, "SCRIP"), "rev-parse", "--short=9", "origin/main"], capture_output=True, text=True, check=True).stdout.strip()
    except Exception: return "0000000"
def line(j): return "GRADE_JOB suite=%s cell=%s modes=%s tree=%s pri=%d ttr_s=%d requester=%s entries=%d" % (j["suite"], j["cell"], j["modes"], j["tree"], j["pri"], j["ttr_s"], j["requester"], j["entries"])
def q(*args):
    r = subprocess.run([sys.executable, os.path.join(S4E, "harness", "scripts", "util_queue.py")] + list(args), capture_output=True, text=True)
    if r.returncode != 0: refuse("util_queue.py %s: %s" % (args[0], (r.stdout + r.stderr).strip()[:200]), r.returncode if r.returncode in (1, 2) else 2)
    return r.stdout.strip()
def put(j):
    jid = q("put", "grade", json.dumps(j, sort_keys=True), "--pri", str(j["pri"]), "--ttr", str(j["ttr_s"])); return int(jid)
def main(a):
    if not a: refuse("usage: util_grade_job.py put|budget|--probe ...")
    if a[0] == "--probe":
        key = next((l.split("\t")[0] for l in open(SUITES) if l.split("\t")[3:4] == ["snobol4"] and not l.startswith("#")), None) or refuse("no snobol4 suite in the table")
        lang, ents, ttr, declared = budget(key, "core")
        j = {"suite": key, "cell": "core", "modes": "m3,m4", "tree": origin_tree(), "requester": os.environ.get("S4E_SEAT", "probe"), "pri": BAND["request"], "ttr_s": ttr, "entries": len(ents)}
        jid = put(j); print(line(j)); q("delete", str(jid)); print("probe job=%d deleted=1 declared_timeouts=%d" % (jid, declared)); sys.exit(0 if ents else 1)
    opts = {}; i = 1
    while i < len(a):
        if a[i].startswith("--") and i + 1 < len(a): opts[a[i][2:]] = a[i + 1]; i += 2
        else: refuse("bad argument " + a[i])
    if a[0] == "budget":
        lang, ents, ttr, declared = budget(opts["suite"], opts["cell"]); print("BUDGET suite=%s cell=%s lang=%s entries=%d ttr_s=%d declared=%d" % (opts["suite"], opts["cell"], lang, len(ents), ttr, declared)); return
    if a[0] == "put":
        band = opts.get("band") or refuse("put needs --band request|smoke|impact|lap")
        if band not in BAND: refuse("band %r" % band)
        lang, ents, ttr, declared = budget(opts["suite"], opts["cell"])
        j = {"suite": opts["suite"], "cell": opts["cell"], "modes": opts.get("modes", "m3,m4"), "tree": opts.get("tree") or origin_tree(), "requester": opts.get("requester") or os.environ.get("S4E_SEAT", "?"), "pri": BAND[band], "ttr_s": int(opts.get("ttr") or ttr), "entries": len(ents)}
        jid = put(j); print(line(j)); print("job=%d tube=grade" % jid); return
    refuse("unknown verb " + a[0])
main(sys.argv[1:])
