#!/usr/bin/env python3
"""util_suite_row_owner_census.py [--suites F] [--queue F] [--tasks DIR] [--mode F] [--holder KEY] -- EVERY SUITE BELOW 100 PERCENT HAS A ROW A SEAT
HOLDS, AND EVERY ROSTER SEAT HAS A ROW QUEUED BEHIND ITS CURRENT ONE (the seat arm, SEAT_QUEUE_BOARD, below the suite arm; either RED is rc 1).

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
# THE SEAT ARM (Lon 2026-11-01 16:0x CST, in the coo's window, verbatim: "ensure you have work queued for all seats."): every seat MODE's ROSTER:
# line names, the coo excepted, holds at least QUEUE_MIN live rows CLAIMED or ASSIGNED to it -- the row it works and the next one behind it, so a
# seat that finishes is never idle for want of a row (R-2107: the coo assigns the next row AHEAD). PARKED and BLOCKED-ON rows do not count.
MODE = arg("--mode", "/home/resources/postoffice/MODE"); QUEUE_MIN = 2
try: roster = next((l.split(":", 1)[1].split() for l in open(MODE, encoding="utf-8") if l.startswith("ROSTER:")), None)
except OSError as e: refuse("%s unreadable: %s" % (MODE, e))
if not roster: refuse("%s has no ROSTER: line" % MODE)
held_by = {}
for f in queue:
    if len(f) >= 4 and f[0].isdigit() and f[3].startswith(("CLAIMED:", "ASSIGNED:")): held_by.setdefault(f[3].split(":", 1)[1], []).append(f[1])
# CTO-485 (Lon 2026-11-04, in the cto's window: HQ-COLLECTOR is ON CALL): a seat on MODE's keyed ON-CALL: line is seated but serves only when woken
# for its own class of red, so an empty queue behind it is correct and never short; no ON-CALL: line means no seat is on call.
try: oncall = set(next((l.split(":", 1)[1].split() for l in open(MODE, encoding="utf-8") if l.startswith("ON-CALL:")), []))
except OSError as e: refuse("%s unreadable: %s" % (MODE, e))
seats = [s for s in roster if s != "coo" and s not in oncall]; short = []
for s in seats:
    h = held_by.get(s, [])
    if len(h) < QUEUE_MIN: short.append("  RED  seat %s holds %d live row(s)%s: nothing queued behind it -- assign its best FREE row ahead (s4e_msg.sh assign %s <topic>)" % (s, len(h), (" (" + h[0] + ")") if h else "", s))
print("SEAT_QUEUE_BOARD seats=%d queued=%d short=%d min=%d" % (len(seats), len(seats) - len(short), len(short), QUEUE_MIN))
for x in short: print(x)
if reds or short: print("RED: %d suite(s) below 100 percent with no seat holding a row; %d seat(s) with nothing queued" % (len(reds), len(short))); sys.exit(1)
print("GREEN: every suite below 100 percent has a row a seat holds, or Lon's hold; every roster seat has a row queued behind its current one"); sys.exit(0)
