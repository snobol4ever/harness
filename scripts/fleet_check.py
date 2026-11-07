#!/usr/bin/env python3
# fleet_check.py -- THE FLEET CHECK: Lon's on-demand grid of the thirty seats (Lon, in the coo's window, 2026-11-07, verbatim: "what's the fleet
# doing? how's each going? in a grid, terse, no gibberish. fill the screen with a 6x5 matrix of info about each seat." / "a display in a grid
# using boxes, words, and color" / "ensure you do not use HTML and web browsers" / "never use dark blue on black again" / "nice square type
# shapes"; on the first cut: "your banner is pure gibberish, and those are rectangles not squares." / "You'll need to use color coding to encode
# state." / "You'll need various attributes of each seat and display small icons to represent the value of each attribute." / "You'll need to put
# useful info not gibberish." / "how much disk is each seat taking? how much memory and other resources? what percentage complete estimate are
# they with their task."; CTO-541, redone CTO-542). Prints MARKDOWN for the asked seat to paste AS IT IS into its reply: one table, six seats
# across, five seat rows down, EVERY SEAT A SQUARE SEVEN LINES TALL (seven table rows per seat, no rule between them): a big coloured square (three
# emoji wide, three lines tall) whose colour is the seat's STATE, the seat's name, the LANGUAGE OR AREA it works on and ONE PLAIN VERB beside it,
# then a progress bar with the percent and the stage, then three counters as icons (mail, escalations, landings) and the resources (cpu, memory,
# disk) as a meter glyph plus the number. NEVER a row name, a job number or a step number. NEVER inside a code fence (dark blue on black), never
# HTML, never a page. Every reading is measured here and now; a source that cannot be read prints a dash, never a guess:
#   colour     🟩 working (transcript moved in the last LIVE s)  🟧 the row sits at the grader (test request pending or MEASURING, seat idle)
#              🟨 holds a row but stopped  🟥 blocked (needs a ruling, or waits on another row; the dated STATE line under 12 h old)
#              ⬜ awake and idle  ⬛ on the controller's sleeping list
#   area/verb  the live row's family (QUEUE.tsv CLAIMED/MEASURING/ASSIGNED naming the seat) or the last claim today (claims/, CLAIMS.log)
#   progress   the stage the live row has reached, each a fifth: not started, started (CLAIMED), reproduced (PREMISE-WHEN exit 0 in the LEDGER),
#              cured (the ledger's cure tree is ahead of origin or dirty), proving (MEASURING or a pending test request), landed (DONE receipt)
#   📬 📭      unread telegrams in <postoffice>/<seat>/inbox      🚩 escalations the seat raised today (the batons' ESCALATION lines)
#   ✅         rows the seat landed today (claims carrying DONE)   cpu  cores now (BOX.state seat_cpu, else sampled over half a second); quota 4
#   mem        resident set of the seat's claude process tree (ps)  disk  du -sxm of the seat's root and /tmp/s4e/<seat>, cached when du is slow
#   python3 harness/scripts/fleet_check.py            the grid, its legend and the totals
#   python3 harness/scripts/fleet_check.py --live N   a seat counts as working when its transcript moved within N seconds (default 180)
#   python3 harness/scripts/fleet_check.py --fast     disk from the last cache, no du
import os, re, sys, glob, time, calendar, subprocess
from concurrent.futures import ThreadPoolExecutor
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PO = os.environ.get("S4E_POST", "/home/resources/postoffice"); V = os.environ.get("S4E_BOX_S", "/home/claude_coo/.scratch/verifier")
PROG = os.environ.get("S4E_PROGRESS", "/home/resources/progress"); TIERS = os.environ.get("S4E_TIERS", S4E + "/.github/TIERS.tsv")
PROJ = os.path.join(os.environ.get("HOME", "/home/satirical"), ".claude", "projects"); DU_CACHE = "/tmp/s4e/fleet_check_du.tsv"
LIVE = int(sys.argv[sys.argv.index("--live") + 1]) if "--live" in sys.argv else 180; FAST = "--fast" in sys.argv
DAY = 12 * 3600; NOW = time.time(); CPU_QUOTA = 4.0; MEM_CAP_MB = 8192.0; DISK_FULL_MB = 40960.0
METER = "▁▂▃▄▅▆▇█"; STAGES = ("not started", "started", "reproduced", "cured", "proving", "landed")

def rd(p):
    try: return open(p, encoding="utf-8", errors="replace").read()
    except OSError: return ""
def mtime(p):
    try: return os.stat(p).st_mtime
    except OSError: return 0
def meter(x, full):
    if x is None: return "–"
    return METER[min(7, int(8 * x / full))] if x >= 0 else "–"
def when(s):
    for f in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%MZ"):
        try: return calendar.timegm(time.strptime(s, f))
        except ValueError: pass
    return 0

seats = []
for l in rd(TIERS).split("\n"):
    f = l.split("\t")
    if l and l[0] != "#" and f[0] != "seat" and len(f) >= 3: seats.append((f[0], f[1], f[2]))
if not seats: print("REFUSE(2): no seats read from " + TIERS); sys.exit(2)
names = {s: n for s, n, _ in seats}; by_name = {n.upper(): s for s, n, _ in seats}
def nice(n):
    if n.startswith("WORKER_"): return "Worker " + n[7:]
    if n == "VICE-PRESIDENT": return "Vice-Pres"
    return n if len(n) <= 3 else n.replace("_", " ").title()

SUITES = {"logtalk": "Logtalk", "rosetta-prolog": "ProRosetta", "trealla": "Trealla", "swi": "SWI", "inria": "INRIA", "xsb": "XSB", "gnu": "GNU",
          "ipl": "IPL", "arizona": "Arizona", "jcon": "Jcon", "unitests": "UniTests", "roast": "Roast", "pat": "PAT", "fpc": "FPC"}
AREAS = (("icon-unicon", "Unicon"), ("unicon", "Unicon"), ("icon", "Icon"), ("prolog", "Prolog"), ("snobol4", "SNOBOL4"), ("snocone", "SNOBOL4"),
         ("rebus", "SNOBOL4"), ("pascal", "Pascal"), ("raku", "Raku"), ("test-cycle", "test cycle"), ("gc-", "SCRIP"), ("zeta", "SCRIP"), ("headers", "SCRIP"),
         ("zsm", "SCRIP"), ("scrip", "SCRIP"), ("census", "SCRIP"), ("skills", "skills"), ("records", "records"), ("fleet", "fleet"), ("bus", "fleet"),
         ("box", "fleet"), ("tick", "fleet"), ("sweep", "fleet"), ("mint", "fleet"), ("sitting", "fleet"), ("spawn", "fleet"), ("seat", "fleet"))
def area(t):
    m = re.match(r"fix25-([a-z]+-prolog|[a-z]+)-", t)
    if m: return SUITES.get(m.group(1), m.group(1).title()) + " red"
    for p, w in AREAS:
        if t.startswith(p): return w
    return "a row"

hold, wait, awaiting = {}, {}, {}
for l in rd(os.path.join(PO, "QUEUE.tsv")).split("\n"):
    f = l.split("\t")
    if not l or l[0] == "#" or len(f) < 4: continue
    topic, owner, state = f[1], f[2], f[3]; kind = state.split(":")[0]
    if kind in ("CLAIMED", "MEASURING", "ASSIGNED"):
        for s in names:
            if re.search(":%s(:|$)" % re.escape(s), state):
                r = {"MEASURING": 0, "CLAIMED": 1, "ASSIGNED": 2}[kind]
                if s not in hold or r < hold[s][0]: hold[s] = (r, kind, topic)
    elif kind == "PARKED-AWAITING" and owner in names: awaiting[owner] = topic
    elif kind in ("GRANT-NEEDED", "BLOCKED-ON") and owner in names:
        t = 0
        for m in re.finditer(r"^- (20\d\d-\d\d-\d\dT\d\d:\d\dZ) \*\*STATE -> (?:GRANT-NEEDED|BLOCKED-ON)", rd(os.path.join(PO, "tasks", topic + ".task.md")), re.M): t = when(m.group(1))
        if t and NOW - t < DAY and (owner not in wait or t > wait[owner][0]): wait[owner] = (t, state, topic)
def blocked_words(state):
    kind, _, rest = state.partition(":")
    if kind == "BLOCKED-ON": return "blocked by " + area(rest)
    return "needs a ruling"

last, landed_n, seen = {}, {}, {}
for l in rd(os.path.join(PO, "CLAIMS.log")).split("\n"):
    f = l.split("\t")
    if len(f) < 3: continue
    t = when(f[0])
    if t and NOW - t < DAY and t >= seen.get(f[1], 0): last[f[1]] = (f[2], False); seen[f[1]] = t
for p in glob.glob(os.path.join(PO, "claims", "*.claim")):
    t = mtime(p); body = rd(p).split("\n"); s = body[0].strip() if body else ""
    if s not in names or NOW - t >= DAY: continue
    done = "DONE" in body or any(b.startswith("RECEIPT done rc=0") for b in body)
    if done: landed_n[s] = landed_n.get(s, 0) + 1
    if t >= seen.get(s, 0): last[s] = (os.path.basename(p)[:-6], done); seen[s] = t
verdict, pending = {}, {}
for p in sorted(glob.glob(os.path.join(PO, "test_requests", "done", "*.req"))):
    if NOW - mtime(p) > DAY: continue
    d = dict(l.partition("=")[::2] for l in rd(p).split("\n") if "=" in l)
    if d.get("seat"): verdict[d["seat"]] = (d.get("suite", "?"), d.get("rc", "?"))
for p in glob.glob(os.path.join(PO, "test_requests", "*.req")):
    d = dict(l.partition("=")[::2] for l in rd(p).split("\n") if "=" in l)
    if d.get("seat"): pending[d["seat"]] = d.get("suite", "?")
sleeping = set(rd(os.path.join(V, "sleeping")).split())
mail = {s: len(glob.glob(os.path.join(PO, s, "inbox", "*.msg"))) if os.path.isdir(os.path.join(PO, s, "inbox")) else None for s in names}

today = time.strftime("%Y-%m-%d", time.gmtime(NOW)); esc, esc_topic = {}, {}
for p in glob.glob(os.path.join(PO, "tasks", "*.task.md")):
    if NOW - mtime(p) > DAY: continue
    for m in re.finditer(r"^- rung \d+ from seat-([a-z_0-9]+) to \S+ at (20\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ)", rd(p), re.M):
        if NOW - when(m.group(2)) < DAY: esc[m.group(1)] = esc.get(m.group(1), 0) + 1; esc_topic[m.group(1)] = os.path.basename(p)[:-8]

def stage_of(s):
    h = hold.get(s)
    if s in pending or s in awaiting: return 4, "at the grader"
    if not h: return (5, "landed") if (s in last and last[s][1]) else (None, "no task")
    if h[1] == "MEASURING": return 4, "proving"
    if h[1] == "ASSIGNED": return 0, "not started"
    led = rd(os.path.join(PO, "tasks", h[2] + ".task.md")).partition("## LEDGER")[2]; st = 1
    if re.search(r"PREMISE-WHEN exit 0|reproduc|RED on the cure tree", led, re.I): st = 2
    for m in re.finditer(r"[Cc]ure tree (/\S+?)[\s,;)]", led):
        d = m.group(1)
        if os.path.isdir(d):
            try:
                ahead = subprocess.run(["git", "-C", d, "rev-list", "--count", "origin/main..HEAD"], capture_output=True, text=True, timeout=10).stdout.strip()
                dirty = subprocess.run(["git", "-C", d, "status", "--porcelain"], capture_output=True, text=True, timeout=10).stdout.strip()
            except (OSError, subprocess.SubprocessError): ahead, dirty = "0", ""
            if (ahead.isdigit() and int(ahead) > 0) or dirty: st = max(st, 3)
    return st, STAGES[st]

procs = {}; kids = {}; roots = {}
try:
    for l in subprocess.run(["ps", "-eo", "pid=,ppid=,rss=,args="], capture_output=True, text=True, timeout=10).stdout.split("\n"):
        f = l.split(None, 3)
        if len(f) < 4: continue
        pid, ppid, rss = int(f[0]), int(f[1]), int(f[2]); procs[pid] = rss; kids.setdefault(ppid, []).append(pid)
        m = re.match(r"claude --name (\S+)", f[3])
        if m and m.group(1).upper() in by_name: roots.setdefault(by_name[m.group(1).upper()], []).append(pid)
except (OSError, subprocess.SubprocessError): pass
def tree(pids):
    out, todo = [], list(pids)
    while todo:
        p = todo.pop(); out.append(p); todo.extend(kids.get(p, []))
    return out
mem_mb = {s: sum(procs.get(p, 0) for p in tree(roots[s])) / 1024.0 for s in roots}

cpu = {}; box = dict(l.partition("=")[::2] for l in rd(os.path.join(PROG, "BOX.state")).split("\n") if "=" in l)
try: box_age = NOW - calendar.timegm(time.strptime(box.get("ts", "")[:19], "%Y-%m-%dT%H:%M:%S")) - time.timezone
except ValueError: box_age = None
if box_age is not None and abs(box_age) < 120 and box.get("seat_cpu"):
    for kv in box["seat_cpu"].split(","):
        k, _, v = kv.partition(":")
        try: cpu[k] = float(v)
        except ValueError: pass
else:
    def ticks(pids):
        n = 0
        for p in pids:
            f = rd("/proc/%d/stat" % p).rpartition(")")[2].split()
            if len(f) > 13: n += int(f[11]) + int(f[12])
        return n
    trees = {s: tree(roots[s]) for s in roots}; a = {s: ticks(trees[s]) for s in trees}; t0 = time.time(); time.sleep(0.5); dt = time.time() - t0
    hz = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100
    for s in trees: cpu[s] = (ticks(trees[s]) - a[s]) / float(hz) / dt

disk = {}; cache = {}
for l in rd(DU_CACHE).split("\n"):
    f = l.split("\t")
    if len(f) == 2 and f[1].isdigit(): cache[f[0]] = int(f[1])
def du(seat_root):
    s, root = seat_root
    try:
        out = subprocess.run(["du", "-sxm", root, "/tmp/s4e/" + s], capture_output=True, text=True, timeout=25).stdout
        return s, sum(int(l.split("\t")[0]) for l in out.split("\n") if l.split("\t")[0].isdigit())
    except (OSError, subprocess.SubprocessError, ValueError): return s, None
if not FAST:
    with ThreadPoolExecutor(8) as ex:
        for s, mb in ex.map(du, [(s, r) for s, _, r in seats]):
            if mb is not None: disk[s] = mb
    if len(disk) == len(seats):
        try:
            os.makedirs(os.path.dirname(DU_CACHE), exist_ok=True); open(DU_CACHE + ".tmp", "w").write("".join("%s\t%d\n" % (s, disk[s]) for s in disk)); os.replace(DU_CACHE + ".tmp", DU_CACHE)
        except OSError: pass
for s in names:
    if s not in disk and s in cache: disk[s] = cache[s]

def transcript_age(root):
    newest = max((mtime(p) for p in glob.glob(os.path.join(PROJ, root.replace("/", "-").replace("_", "-"), "*.jsonl"))), default=0)
    return NOW - newest if newest else None
def gb(mb): return "–" if mb is None else ("%.1fG" % (mb / 1024.0) if mb < 10240 else "%dG" % round(mb / 1024.0))
def square(s, root):
    a = transcript_age(root); live = a is not None and a < LIVE; h = hold.get(s); w = wait.get(s)
    did = "landed" if s in last and last[s][1] else ("escalated" if esc.get(s) else ("working" if s in last else "awake, no row"))
    if live: col, verb = "🟩", {"MEASURING": "proving", "CLAIMED": "working", "ASSIGNED": "starting"}[h[1]] if h else ("at the grader" if s in pending or s in awaiting else (blocked_words(w[1]) if w else did))
    elif s in pending or s in awaiting or (h and h[1] == "MEASURING"): col, verb = "🟧", "at the grader"
    elif h: col, verb = "🟨", "stopped"
    elif w: col, verb = "🟥", blocked_words(w[1])
    elif s in sleeping: col, verb = "⬛", "asleep"
    else: col, verb = "⬜", "idle"
    topic = h[2] if h else (awaiting.get(s) or (w[2] if w else (last[s][0] if s in last else esc_topic.get(s, ""))))
    ar = area(topic) if topic else "no row"
    v = verdict.get(s)
    if v and not h and not live and s not in pending and s not in awaiting: verb = "%s %s" % (SUITES.get(v[0], v[0]), "green" if v[1] == "0" else "red")
    st, word = stage_of(s); bar = ("■" * st + "□" * (5 - st) + " %d%% " % (st * 20)) if st is not None else "□□□□□ "
    m = mail.get(s); c = cpu.get(s); mm = mem_mb.get(s); d = disk.get(s)
    return [col * 3 + " **%s**" % nice(names[s]), col * 3 + " " + ar, col * 3 + " " + verb, bar + word,
            "%s %s · 🚩 %d · ✅ %d" % ("📬" if m else "📭", "–" if m is None else m, esc.get(s, 0), landed_n.get(s, 0)),
            "cpu %s%s · mem %s%s" % (meter(c, CPU_QUOTA), "–" if c is None else "%.1f" % c, meter(mm, MEM_CAP_MB), gb(mm)), "disk %s %s" % (meter(d, DISK_FULL_MB), gb(d))]

cells = [square(s, r) for s, _, r in seats]; cols = 6; H = len(cells[0])
mode = (rd(os.path.join(PO, "MODE")).split("\n") or [""])[0].strip()
tally = {}
for c in cells: tally[c[0][0]] = tally.get(c[0][0], 0) + 1
busy = box.get("busy", "–") if box_age is not None and abs(box_age) < 120 else "–"
head = ["🕒 " + time.strftime("%H:%M %Z"), "MODE " + (mode or "–"), "cpu %s of %s busy" % (busy, os.cpu_count() or "–"),
        "mem %s free" % (gb(float(box["memavail_mb"])) if box.get("memavail_mb", "").isdigit() else "–"),
        "/home %s%% full" % box.get("home_pct", "–"), "✅ %d landed today" % sum(landed_n.values())]
print("| " + " | ".join(head) + " |"); print("|" + "---|" * cols)
for r in range(0, len(cells), cols):
    for i in range(H): print("| " + " | ".join(c[i] for c in cells[r:r + cols]) + " |")
print()
print("🟩 working %d · 🟧 at the grader %d · 🟨 stopped on a row %d · 🟥 blocked %d · ⬜ idle %d · ⬛ asleep %d" % tuple(tally.get(k, 0) for k in "🟩🟧🟨🟥⬜⬛"))
print()
print("■□ how far the seat's task has come · 📬 unread telegrams · 🚩 escalations raised today · ✅ rows landed today · cpu in cores of a 4-core quota · mem resident of an 8G cap · disk root plus scratch")
