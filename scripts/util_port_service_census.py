#!/usr/bin/env python3
# util_port_service_census.py -- HOW WELL THE coo SERVES THE PORT HQs, MEASURED FROM ITS OWN REQUEST RECORDS (ceo CEO-1911; Lon 2026-10-22 14:5x CDT,
# in-chat to the ceo, verbatim: "Let's get COO to better service HQ-JVM and HQ-DOTNET."). It runs nothing and reads three records:
#   (1) TURNAROUND: every request the coo served inside the window (postoffice/test_requests/done/*.req: filed=, served=, engine=), per engine --
#       the minutes from filed to served, median, p90 and max; SCRIP's requests are printed beside the ports' for comparison and never graded here.
#   (2) WAITING: every port request still pending (postoffice/test_requests/*.req, engine= set), its age now.
#   (3) FRESHNESS: every <key>@<engine> row of progress/SUITES.tsv whose today_date is older than --stale-days (default 1).
# VERDICT, per port engine (dotnet, jvm): GREEN when its served-request p90 is at most --p90-min minutes (default 15) over the window's requests (at
# least --min-n, default 3; fewer is printed and not graded), no request of it has waited longer than --p90-min, and none of its rows is stale.
# USE: python3 harness/scripts/util_port_service_census.py [--hours 2] [--p90-min 15] [--stale-days 1] [--min-n 3]
# EXIT: 0 every port engine green; 1 a port engine red (the lines name why); 2 could not measure (a record unreadable).
import os, sys, glob, datetime as dt, statistics
PO = os.environ.get("S4E_PO", "/home/resources/postoffice")
SUITES = os.environ.get("S4E_SUITES", "/home/resources/progress/SUITES.tsv")
args = sys.argv[1:]
def opt(name, default):
    if name in args:
        i = args.index(name)
        try: return float(args[i + 1])
        except (IndexError, ValueError): print("REFUSE(2): %s takes a number" % name); sys.exit(2)
    return default
HOURS = opt("--hours", 2); P90 = opt("--p90-min", 15); STALE = opt("--stale-days", 1); MIN_N = int(opt("--min-n", 3))
PORTS = ("dotnet", "jvm")
NOW = dt.datetime.now()
def kv(path):
    d = {}
    try:
        for ln in open(path, encoding="utf-8", errors="replace"):
            k, sep, v = ln.rstrip("\n").partition("=")
            if sep and k not in d: d[k] = v
    except OSError: return None
    return d
def when(s):
    try: return dt.datetime.strptime(s.strip()[:19], "%Y-%m-%d %H:%M:%S")
    except (ValueError, AttributeError): return None
reqdir = os.path.join(PO, "test_requests")
if not os.path.isdir(reqdir): print("REFUSE(2): no request store at %s" % reqdir); sys.exit(2)
served = {"scrip": [], "dotnet": [], "jvm": []}
for f in glob.glob(os.path.join(reqdir, "done", "*.req")):
    d = kv(f)
    if d is None: continue
    t0 = when(d.get("filed", "")); t1 = when(d.get("served", ""))
    if t0 is None or t1 is None or (NOW - t1).total_seconds() > HOURS * 3600: continue
    served.setdefault(d.get("engine") or "scrip", []).append((t1 - t0).total_seconds() / 60)
waiting = {e: [] for e in PORTS}
for f in glob.glob(os.path.join(reqdir, "*.req")):
    d = kv(f)
    if d is None or d.get("engine") not in PORTS: continue
    t0 = when(d.get("filed", ""))
    if t0: waiting[d["engine"]].append(((NOW - t0).total_seconds() / 60, os.path.basename(f)))
try:
    rows = [l.rstrip("\n").split("\t") for l in open(SUITES, encoding="utf-8") if not l.startswith("#")]
except OSError as e: print("REFUSE(2): %s unreadable: %s" % (SUITES, e)); sys.exit(2)
head = rows[0]; stale = {e: [] for e in PORTS}
for r in rows[1:]:
    d = dict(zip(head, r)); key = d.get("key", ""); eng = key.partition("@")[2]
    if eng not in PORTS: continue
    try: day = dt.datetime.strptime(d.get("today_date", ""), "%Y-%m-%d")
    except ValueError: stale[eng].append("%s (no reading)" % key); continue
    if (NOW.date() - day.date()).days > STALE: stale[eng].append("%s (%s)" % (key, d["today_date"]))
def p90(v): v = sorted(v); return v[min(len(v) - 1, int(round(0.9 * (len(v) - 1))))]
print("PORT SERVICE at %s, window %g h, bar p90 <= %g min, rows written within %g day(s)" % (NOW.strftime("%Y-%m-%d %H:%M"), HOURS, P90, STALE))
red = False
for e in ("scrip",) + PORTS:
    v = served.get(e, [])
    line = "  %-7s served=%3d" % (e, len(v))
    if v: line += "  turnaround median=%6.1f p90=%6.1f max=%6.1f min" % (statistics.median(v), p90(v), max(v))
    if e == "scrip": print(line + "  (comparison, not graded)"); continue
    why = []
    if len(v) >= MIN_N and p90(v) > P90: why.append("p90 %.1f min over the bar" % p90(v))
    if len(v) < MIN_N: line += "  (fewer than %d served: turnaround not graded)" % MIN_N
    old = [w for w in waiting[e] if w[0] > P90]
    if old: why.append("%d request(s) waiting over %g min, oldest %.0f min" % (len(old), P90, max(w[0] for w in old)))
    if stale[e]: why.append("%d stale row(s): %s" % (len(stale[e]), ", ".join(stale[e])))
    print(line + "  waiting=%d" % len(waiting[e]) + ("  RED: " + "; ".join(why) if why else "  GREEN"))
    red = red or bool(why)
print("PORT_SERVICE %s" % ("RED" if red else "GREEN"))
sys.exit(1 if red else 0)
