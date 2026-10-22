#!/usr/bin/env python3
# util_suite_table_freshness.py -- IS THE SUITE TABLE A READING OF TODAY'S TREE? (ceo CEO-1920; Lon 2026-10-22 16:1x CDT, in-chat to the ceo, verbatim:
# "Do not wait for HQs to re-start to get test suite banner up-to-date."). A SUITE TABLE row's `tree` is the OLDEST reading it was assembled from
# (util_score_row.py from-progress stamps "the oldest reading's tree"), so a row written today can still carry a reading of a week-old compiler. This
# reads every SCRIP row of progress/SUITES.tsv (a port engine's <key>@<engine> row is its HQ's and is skipped), resolves its tree in SCRIP, and names
# the rows whose oldest reading is older than --hours (default 24) by that tree's commit time; an unresolvable tree (a -dirty stamp, a hash SCRIP
# does not hold) is stale. Measured 2026-10-22 16:1x: 43 of 44 rows held a reading from before that day; the Pascal rows read 10-14's compiler
# although the Pascal frame switch had landed that afternoon.
# USE: python3 harness/scripts/util_suite_table_freshness.py [--hours H]
# EXIT: 0 every row's oldest reading is within H hours; 1 a row is staler (listed, oldest first); 2 could not measure.
import os, sys, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.normpath(os.path.join(HERE, "..", "..", "SCRIP"))
TSV = os.environ.get("S4E_SUITES", "/home/resources/progress/SUITES.tsv")
args = sys.argv[1:]
hours = 24.0
if "--hours" in args:
    try: hours = float(args[args.index("--hours") + 1])
    except (IndexError, ValueError): print("REFUSE(2): --hours takes a number"); sys.exit(2)
if not os.path.isdir(os.path.join(SCRIP, ".git")): print("REFUSE(2): no SCRIP checkout at %s" % SCRIP); sys.exit(2)
try: rows = [l.rstrip("\n").split("\t") for l in open(TSV, encoding="utf-8") if not l.startswith("#")]
except OSError as e: print("REFUSE(2): %s unreadable: %s" % (TSV, e)); sys.exit(2)
head = rows[0]; now = time.time(); cut = now - hours * 3600; out = []
for r in rows[1:]:
    d = dict(zip(head, r)); key = d.get("key", "")
    if not key or "@" in key: continue
    tree = (d.get("tree") or "").strip()
    t = None
    if tree and "-" not in tree:
        p = subprocess.run(["git", "-C", SCRIP, "log", "-1", "--format=%ct", tree], capture_output=True, text=True)
        if p.returncode == 0 and p.stdout.strip().isdigit(): t = int(p.stdout.strip())
    out.append((t if t is not None else 0, key, d.get("nick", ""), d.get("today_pass", ""), d.get("today_total", ""), tree or "-"))
if not out: print("REFUSE(2): no SCRIP row in %s" % TSV); sys.exit(2)
stale = sorted(x for x in out if x[0] < cut)
for t, key, nick, p, n, tree in stale:
    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(t)) if t else "unresolvable"
    print("  STALE %-20s %-12s %5s/%-5s oldest reading on %s (tree %s)" % (key, nick, p, n, when, tree))
print("SUITE_TABLE_FRESHNESS rows=%d stale=%d bar=oldest-reading-within-%gh" % (len(out), len(stale), hours))
sys.exit(1 if stale else 0)
