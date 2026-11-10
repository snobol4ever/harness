#!/usr/bin/env python3
# util_grade_job.py -- THE CELL BUDGET (DESIGN-PLAN test-cycle step 1, CTO-522; the cio 2026-11-05; skill suites-and-grading section 7). The grade tube, its jobs and
# their puts are RETIRED (bus-one-queue, CIO-82, 2026-11-10: the cycle is the one grading road and serves the test requests itself); what stays is the budget a
# cell is run under: the launch (120 s) plus every row's timeout_s of the cell's entries from the suite's ALL.csv (60 s when the table declares none). The table
# is the one harness/scripts/SUITE_RUNNERS.tsv names for the key: kind master or port -> corpus/tests/<lang>; kind pkg -> the row's table column; kind small ->
# its table column, or no table (3600 s). A cell is core | shell:F | chunk:NN | entry:a,b,... | all for a small suite.
#   util_grade_job.py budget --suite KEY [--cell CELL]  (no cell: core)  prints "BUDGET suite= cell= entries=N ttr_s=N declared=N"
# rc 0 ok, 2 refuse (unknown suite, unreadable table).
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
def main(a):
    if not a or a[0] != "budget": refuse("usage: util_grade_job.py budget --suite KEY [--cell CELL] (the grade tube's put, put-many and probes are retired, CIO-82)")
    opts = {}; i = 1
    while i < len(a):
        if a[i].startswith("--") and i + 1 < len(a): opts[a[i][2:]] = a[i + 1]; i += 2
        else: refuse("bad argument " + a[i])
    if "suite" not in opts: refuse("budget needs --suite KEY [--cell CELL]")
    opts.setdefault("cell", "core")   # a suite with no cell reads its core cell (the cio 2026-11-10: the crash at the old line 171 was reaching for it)
    lang, ents, ttr, declared = budget(opts["suite"], opts["cell"]); print("BUDGET suite=%s cell=%s lang=%s entries=%d ttr_s=%d declared=%d" % (opts["suite"], opts["cell"], lang, len(ents), ttr, declared))
main(sys.argv[1:])
