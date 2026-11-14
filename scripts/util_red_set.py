#!/usr/bin/env python3
"""util_red_set.py [--at REF] [--results FILE] [--suite KEY] [--reds] [--vs REF] -- THE RED SET PER ORIGIN HASH, READ IN ONE COMMAND
(box-scheduler step 20, CTO-496; the cause of 'the same arm red for hours before anyone claimed it').

Reads the coo's loop record /home/resources/progress/results.tsv and writes nothing (the coo alone writes a progress row). REF is resolved in
the SCRIP checkout (S4E_SCRIP, else the seat's clone) to a commit. The readings of that commit are the rows whose
scrip column is a prefix of its hash (the loop writes 7 and 9 characters); a row on a dirty tree (scrip ending -dirty) is unread (CEO-2060).
When the loop has not yet graded REF itself, the newest ancestor it graded is read and the line says so (behind=N commits), never a silence.
Per (suite, program, mode) the newest reading counts. A red is FAIL CRASH HANG REJECT OOM ABORT UNPROVEN SKIP; UNGRADED UNGRADABLE OUTSIDE are
completeness, counted beside and never red (the same split as util_red_coverage.py).
Prints   RED-SET scrip=<graded hash> arms=<readings> red=<n> pass=<n> completeness=<n> other=<n> at=<REF> head=<hash> behind=<n> corpus=<hash>
         RED-SET-SUITE <suite> arms=<n> red=<n>            one per suite with a red
         RED <suite> <program> <mode> <outcome>            one per red, with --reds
         RED-VS vs=<graded hash> behind=<n> new=<n> still=<n> unread=<n>   with --vs REF: the reds against REF's graded hash (unread = REF's hash never read that arm)
         RED-NEW <suite> <program> <mode> <outcome>        one per red that REF's graded hash read non-red (the culprit window); an arm it never read is never blamed
rc 0 the line printed · rc 2 could not measure (no results file, no SCRIP checkout, REF unresolvable, no ancestor of REF graded, --vs unreadable).
"""
import sys, os, subprocess
RESULTS = "/home/resources/progress/results.tsv"
REDS = {"FAIL", "CRASH", "HANG", "REJECT", "OOM", "ABORT", "UNPROVEN", "SKIP"}
COMPLETENESS = {"UNGRADED", "UNGRADABLE", "OUTSIDE"}
DEPTH = 20000
def refuse(msg):
    print("REFUSE(2): " + msg, file=sys.stderr); sys.exit(2)
def scrip_dir():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import harness_paths
    d = str(harness_paths.scrip(os.environ.get("S4E_HOME")))
    if not os.path.isdir(d): refuse("no SCRIP checkout at " + d)
    return d
def git(d, *a):
    r = subprocess.run(["git", "-C", d] + list(a), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return r.returncode, r.stdout
def load(path):
    try: raw = open(path, "rb").read().decode("utf-8", "replace")
    except OSError as e: refuse("cannot read %s: %s" % (path, e))
    rows = []
    for ln in raw.split("\n"):
        f = ln.split("\t")
        if len(f) < 10 or f[0] == "ts_utc": continue
        if f[1].endswith("-dirty") or not f[1]: continue
        rows.append(f)
    return rows
def graded_hash(d, ref, hashes):
    rc, out = git(d, "rev-parse", "--verify", "-q", ref + "^{commit}")
    if rc != 0: refuse("%s does not resolve to a commit in %s" % (ref, d))
    head = out.strip()
    rc, out = git(d, "rev-list", "-n", str(DEPTH), head)
    if rc != 0: refuse("git rev-list failed in " + d)
    for i, h in enumerate(out.split()):
        for k in hashes:
            if h.startswith(k): return head, h, k, i
    refuse("no ancestor of %s (%d commits read) has a clean reading in the results file" % (ref, DEPTH))
def readings(rows, key):
    cur = {}
    for f in rows:
        if f[1] != key: continue
        k = (f[5], f[7], f[8])
        if k not in cur or f[0] >= cur[k][0]: cur[k] = f
    return cur
def main(argv):
    ref = "origin/main"; res = RESULTS; only = None; reds = False; vs = None; i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--at": ref = argv[i + 1]; i += 2
        elif a == "--results": res = argv[i + 1]; i += 2
        elif a == "--suite": only = argv[i + 1]; i += 2
        elif a == "--vs": vs = argv[i + 1]; i += 2
        elif a == "--reds": reds = True; i += 1
        elif a in ("-h", "--help"): print(__doc__); return 0
        else: refuse("unknown argument " + a)
    d = scrip_dir(); rows = load(res)
    if not rows: refuse("no clean reading in " + res)
    hashes = sorted({f[1] for f in rows}, key=len, reverse=True)
    head, full, key, behind = graded_hash(d, ref, hashes)
    cur = readings(rows, key)
    if only: cur = {k: v for k, v in cur.items() if k[0] == only}
    red = {k: v for k, v in cur.items() if v[9] in REDS}
    comp = sum(1 for v in cur.values() if v[9] in COMPLETENESS)
    npass = sum(1 for v in cur.values() if v[9] == "PASS")
    other = len(cur) - len(red) - comp - npass
    corp = max(cur.values(), key=lambda v: v[0])[2] if cur else "-"
    print("RED-SET scrip=%s arms=%d red=%d pass=%d completeness=%d other=%d at=%s head=%s behind=%d corpus=%s" % (key, len(cur), len(red), npass, comp, other, ref, head[:9], behind, corp))
    per = {}
    for k in cur:
        s = per.setdefault(k[0], [0, 0]); s[0] += 1
        if k in red: s[1] += 1
    for s in sorted(per):
        if per[s][1]: print("RED-SET-SUITE %s arms=%d red=%d" % (s, per[s][0], per[s][1]))
    if reds:
        for k in sorted(red): print("RED %s %s %s %s" % (k[0], k[1], k[2], red[k][9]))
    if vs:
        h2, full2, key2, b2 = graded_hash(d, vs, hashes)
        old = readings(rows, key2); new = []; still = 0; unread = 0
        for k in sorted(red):
            if k not in old: unread += 1
            elif old[k][9] in REDS: still += 1
            else: new.append(k)
        print("RED-VS vs=%s behind=%d new=%d still=%d unread=%d" % (key2, b2, len(new), still, unread))
        for k in new: print("RED-NEW %s %s %s %s" % (k[0], k[1], k[2], red[k][9]))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
