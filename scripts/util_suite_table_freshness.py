#!/usr/bin/env python3
# util_suite_table_freshness.py -- IS THE SUITE TABLE A READING OF TODAY'S TREE? (ceo CEO-1920; Lon 2026-10-22 16:1x CDT, in-chat to the ceo, verbatim:
# "Do not wait for HQs to re-start to get test suite banner up-to-date."). A SUITE TABLE row's `tree` is the OLDEST reading it was assembled from
# (util_score_row.py from-progress stamps "the oldest reading's tree"), so a row written today can still carry a reading of a week-old compiler. This
# reads every SCRIP row of progress/SUITES.tsv (a port engine's <key>@<engine> row is its HQ's and is skipped), resolves its tree in SCRIP, and names
# the rows whose oldest reading is older than --hours (default 24) by that tree's commit time; an unresolvable tree (a -dirty stamp, a hash SCRIP
# does not hold) is stale. Measured 2026-10-22 16:1x: 43 of 44 rows held a reading from before that day; the Pascal rows read 10-14's compiler
# although the Pascal frame switch had landed that afternoon.
# THE TWO-TIER BAR (ceo CEO-2078, 2026-10-31, on the coo's numbers: four rows hold 65 percent of the engine time and one full cycle four wide cannot
# carry them inside 24 hours): --long KEY,KEY... --long-hours H gives the named rows the bar H instead of --hours. A named key the table does not
# hold REFUSES rc 2, so a renamed or deleted row cannot pass by leaving the long arm; the summary line prints both bars and each arm's count.
# USE: python3 harness/scripts/util_suite_table_freshness.py [--hours H] [--long KEY,KEY... --long-hours H2]
#      the CEO-1920 row's bar: --hours 24 --long logtalk,swi,roast,xsb --long-hours 72
# EXIT: 0 every row's oldest reading is within its bar; 1 a row is staler (listed, oldest first); 2 could not measure.
import os, sys, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.normpath(os.path.join(HERE, "..", "..", "SCRIP"))
TSV = os.environ.get("S4E_SUITES", "/home/resources/progress/SUITES.tsv")
args = sys.argv[1:]
def num(flag, dflt):
    if flag not in args: return dflt
    try: return float(args[args.index(flag) + 1])
    except (IndexError, ValueError): print("REFUSE(2): %s takes a number" % flag); sys.exit(2)
hours = num("--hours", 24.0)
long_hours = num("--long-hours", None)
long_keys = []
if "--long" in args:
    try: long_keys = [k for k in args[args.index("--long") + 1].split(",") if k]
    except IndexError: long_keys = []
    if not long_keys: print("REFUSE(2): --long takes KEY,KEY..."); sys.exit(2)
if bool(long_keys) != (long_hours is not None): print("REFUSE(2): --long and --long-hours go together"); sys.exit(2)
if not os.path.exists(os.path.join(SCRIP, ".git")): print("REFUSE(2): no SCRIP checkout at %s" % SCRIP); sys.exit(2)
try: rows = [l.rstrip("\n").split("\t") for l in open(TSV, encoding="utf-8") if not l.startswith("#")]
except OSError as e: print("REFUSE(2): %s unreadable: %s" % (TSV, e)); sys.exit(2)
head = rows[0]; now = time.time(); out = []
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
missing = [k for k in long_keys if k not in {x[1] for x in out}]
if missing: print("REFUSE(2): --long names %s, which %s does not hold as a SCRIP row" % (",".join(missing), TSV)); sys.exit(2)
def bar(key): return long_hours if key in long_keys else hours
stale = sorted(x for x in out if x[0] < now - bar(x[1]) * 3600)
for t, key, nick, p, n, tree in stale:
    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(t)) if t else "unresolvable"
    print("  STALE %-20s %-12s %5s/%-5s oldest reading on %s (tree %s, bar %gh)" % (key, nick, p, n, when, tree, bar(key)))
if long_keys:
    ls = sum(1 for x in stale if x[1] in long_keys)
    print("SUITE_TABLE_FRESHNESS rows=%d stale=%d bar=oldest-reading-within-%gh short=%d/%d long=%d/%d long-bar=%gh long-keys=%s" % (len(out), len(stale), hours, len(stale) - ls, len(out) - len(long_keys), ls, len(long_keys), long_hours, ",".join(long_keys)))
else:
    print("SUITE_TABLE_FRESHNESS rows=%d stale=%d bar=oldest-reading-within-%gh" % (len(out), len(stale), hours))
sys.exit(1 if stale else 0)
