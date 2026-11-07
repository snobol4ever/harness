#!/usr/bin/env python3
# fleet_check.py -- THE FLEET CHECK: Lon's on-demand grid of the thirty seats (Lon, in the coo's window, 2026-11-07, verbatim: "what's the fleet
# doing? how's each going? in a grid, terse, no gibberish. fill the screen with a 6x5 matrix of info about each seat." / "a display in a grid
# using boxes, words, and color" / "ensure you do not use HTML and web browsers" / "never use dark blue on black again" / "nice square type
# shapes"; handed to the cto the same morning). Prints MARKDOWN for the asked seat to paste AS IT IS into its reply: a six-column table, one seat
# per cell, a coloured square, the seat's name and a few words. NEVER inside a code fence (that is the dark blue on black), never HTML, never a
# page. Every reading is measured here and now; nothing is hand-kept:
#   working   the seat's transcript (~/.claude/projects/-home-claude-<seat>/*.jsonl) was written in the last LIVE seconds
#   the row   QUEUE.tsv: CLAIMED/MEASURING/ASSIGNED naming the seat; GRANT-NEEDED/BLOCKED-ON owned by the seat with its baton touched today
#   asleep    the controller's sleeping list (S4E_BOX_S/sleeping)
#   last did  CLAIMS.log's last claim by the seat today, and the seat's newest test-request verdict today (test_requests/done)
#   python3 harness/scripts/fleet_check.py            the grid, its legend and one line of totals
#   python3 harness/scripts/fleet_check.py --live N   a seat counts as working when its transcript moved within N seconds (default 180)
import os, re, sys, glob, time, calendar
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PO = os.environ.get("S4E_POST", "/home/resources/postoffice"); V = os.environ.get("S4E_BOX_S", "/home/claude_coo/.scratch/verifier")
TIERS = os.environ.get("S4E_TIERS", S4E + "/.github/TIERS.tsv"); PROJ = os.path.join(os.environ.get("HOME", "/home/satirical"), ".claude", "projects")
LIVE = int(sys.argv[sys.argv.index("--live") + 1]) if "--live" in sys.argv else 180
DAY = 12 * 3600; NOW = time.time()

def rd(p):
    try: return open(p, encoding="utf-8", errors="replace").read()
    except OSError: return ""
def mtime(p):
    try: return os.stat(p).st_mtime
    except OSError: return 0

seats = []
for l in rd(TIERS).split("\n"):
    f = l.split("\t")
    if l and l[0] != "#" and f[0] != "seat" and len(f) >= 3: seats.append((f[0], f[1], f[2]))
if not seats: print("REFUSE(2): no seats read from " + TIERS); sys.exit(2)
names = {s: n for s, n, _ in seats}
def nice(n):
    if n.startswith("WORKER_"): return "Worker " + n[7:]
    return n if len(n) <= 3 else n.replace("_", " ").replace("-", " ").title()

WORDS = (("icon-unicon-step-", "UniTests "), ("unicon-step-", "UniTests "), ("test-cycle-", "test-cycle "), ("fleet-queue-step-", "fleet-queue "),
         ("box-scheduler-step-", "box-sched "), ("zeta-layout-step-", "zeta "), ("headers-step-", "headers "))
SUITES = {"logtalk": "Logtalk", "rosetta-prolog": "ProRosetta", "trealla": "Trealla", "swi": "SWI", "inria": "INRIA", "xsb": "XSB", "gnu": "GNU",
          "ipl": "IPL", "arizona": "Arizona", "jcon": "Jcon", "unitests": "UniTests", "roast": "Roast", "pat": "PAT", "fpc": "FPC"}
PREFIX = (("prolog-logtalk", "Logtalk"), ("prolog-rosetta", "ProRosetta"), ("prolog-xsbtests", "XsbTests"), ("prolog-xsb", "XSB"), ("prolog-swi", "SWI"),
          ("prolog-trealla", "Trealla"), ("prolog-", "Prolog"), ("icon-ipl", "IPL"), ("icon-", "Icon"), ("snobol4-", "SNOBOL4"), ("pascal-", "Pascal"),
          ("raku-", "Raku"), ("bus-gate", "bus gate"), ("bus-", "bus"), ("census-", "census"), ("fleet-health", "health check"),
          ("fleet-preflight", "preflight"), ("fleet-bus-skill", "fleet-bus skill"), ("fleet-the-jupyter", "kernel gate"), ("fleet-inventory", "inventory"), ("fleet-", "fleet"), ("tick-", "tick"), ("sweep-", "sweep"),
          ("mint-", "mint"), ("zsm-", "ZSM"), ("sitting-sync", "sitting sync"), ("spawn-fleet", "seat scopes"), ("records-", "records"))
def label(t):
    for p, w in WORDS:
        if t.startswith(p):
            m = re.match(r"([0-9]+[a-z]?)", t[len(p):]); return w + (m.group(1) if m else "")
    m = re.match(r"fix25-([a-z]+-prolog|[a-z]+)-", t)
    if m: return SUITES.get(m.group(1), m.group(1)) + " red"
    for p, w in PREFIX:
        if t.startswith(p): return w
    return " ".join(t.split("-")[:3])

hold, wait = {}, {}
for l in rd(os.path.join(PO, "QUEUE.tsv")).split("\n"):
    f = l.split("\t")
    if not l or l[0] == "#" or len(f) < 4: continue
    topic, owner, state = f[1], f[2], f[3]; kind = state.split(":")[0]
    if kind in ("CLAIMED", "MEASURING", "ASSIGNED"):
        for s, _, _ in seats:
            if re.search(":%s(:|$)" % re.escape(s), state):
                r = {"MEASURING": 0, "CLAIMED": 1, "ASSIGNED": 2}[kind]
                if s not in hold or r < hold[s][0]: hold[s] = (r, kind, topic)
    elif kind in ("GRANT-NEEDED", "BLOCKED-ON") and owner in names:
        t = 0
        for m in re.finditer(r"^- (20\d\d-\d\d-\d\dT\d\d:\d\dZ) \*\*STATE -> (?:GRANT-NEEDED|BLOCKED-ON)", rd(os.path.join(PO, "tasks", topic + ".task.md")), re.M):
            t = calendar.timegm(time.strptime(m.group(1), "%Y-%m-%dT%H:%MZ"))
        if t and NOW - t < DAY and (owner not in wait or t > wait[owner][0]): wait[owner] = (t, state, topic)
def who(state, own=""):
    kind, _, rest = state.partition(":"); tok = rest.split("-")[0]
    if kind == "BLOCKED-ON": return "blocked on " + ("a row" if label(rest) == own else label(rest))
    return "waits " + tok if tok in names else "waits a grant"

last, landed, seen = {}, set(), {}
for l in rd(os.path.join(PO, "CLAIMS.log")).split("\n"):
    f = l.split("\t")
    if len(f) < 3: continue
    try: t = calendar.timegm(time.strptime(f[0], "%Y-%m-%dT%H:%M:%SZ"))
    except ValueError: continue
    if NOW - t < DAY and t >= seen.get(f[1], 0): last[f[1]] = f[2]; seen[f[1]] = t
for p in glob.glob(os.path.join(PO, "claims", "*.claim")):
    t = mtime(p); body = rd(p).split("\n"); s = body[0].strip() if body else ""
    if s in names and NOW - t < DAY and t >= seen.get(s, 0):
        last[s] = os.path.basename(p)[:-6]; seen[s] = t
        if "DONE" in body or any(b.startswith("RECEIPT done rc=0") for b in body): landed.add(s)
        else: landed.discard(s)
verdict, pending = {}, {}
for p in sorted(glob.glob(os.path.join(PO, "test_requests", "done", "*.req"))):
    if NOW - mtime(p) > DAY: continue
    d = dict(l.partition("=")[::2] for l in rd(p).split("\n") if "=" in l)
    if d.get("seat"): verdict[d["seat"]] = (d.get("suite", "?"), d.get("rc", "?"))
for p in glob.glob(os.path.join(PO, "test_requests", "*.req")):
    d = dict(l.partition("=")[::2] for l in rd(p).split("\n") if "=" in l)
    if d.get("seat"): pending[d["seat"]] = d.get("suite", "?")
sleeping = set(rd(os.path.join(V, "sleeping")).split())

def transcript_age(root):
    newest = max((mtime(p) for p in glob.glob(os.path.join(PROJ, root.replace("/", "-").replace("_", "-"), "*.jsonl"))), default=0)
    return NOW - newest if newest else None
def graded(s, text=""):
    v = verdict.get(s)
    if not v: return ""
    suite = SUITES.get(v[0], v[0]); word = "green" if v[1] == "0" else "red"
    return ", " + word if suite.lower() in text.lower() else ", %s %s" % (suite, word)
def cell(s, n, root):
    a = transcript_age(root); live = a is not None and a < LIVE; h = hold.get(s); w = wait.get(s); nm = "**%s**" % nice(n)
    if live:
        if h: return "🟩 %s %s, %s" % (nm, label(h[2]), {"MEASURING": "gate running", "CLAIMED": "working", "ASSIGNED": "starting"}[h[1]])
        if s in pending: return "🟩 %s %s, being graded" % (nm, pending[s])
        if w: return "🟩 %s %s, %s" % (nm, label(w[2]), who(w[1], label(w[2])))
        txt = ("after " + label(last[s])) if s in last else "working"; return "🟩 %s %s%s" % (nm, txt, graded(s, txt))
    if w: return "🟥 %s %s, %s" % (nm, label(w[2]), who(w[1], label(w[2])))
    if h: return "🟨 %s %s, held" % (nm, label(h[2]))
    did = (("landed " if s in landed else "last ") + label(last[s])) if s in last else ""; did += graded(s, did)
    if s in sleeping: return "⬛ %s %s" % (nm, did or "asleep")
    return "⬜ %s %s" % (nm, did or "idle")

cells = [cell(s, n, r) for s, n, r in seats]
cols = 6; rows = [cells[i:i + cols] for i in range(0, len(cells), cols)]
mode = (rd(os.path.join(PO, "MODE")).split("\n") or [""])[0].strip()
try: load = open("/proc/loadavg").read().split()[0]
except OSError: load = "?"
print("**FLEET CHECK %s · MODE %s · load %s on %s cores**" % (time.strftime("%Y-%m-%d %H:%M %Z"), mode or "?", load, os.cpu_count() or "?"))
print()
print("| " + " | ".join(rows[0]) + " |"); print("|" + "---|" * cols)
for r in rows[1:]: print("| " + " | ".join(r) + " |")
print()
c = lambda sq: sum(1 for x in cells if x.startswith(sq))
print("🟩 working %d · 🟥 blocked, waits a ruling %d · 🟨 holds a row, held %d · ⬜ awake, idle %d · ⬛ asleep %d" % (c("🟩"), c("🟥"), c("🟨"), c("⬜"), c("⬛")))
