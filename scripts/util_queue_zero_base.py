#!/usr/bin/env python3
"""util_queue_zero_base.py [--apply] [--timeout S] [--no-run] -- A ROW EXISTS ONLY WHILE A MEASUREMENT SAYS THE PROBLEM EXISTS (ceo, CEO-1386).

Lon 2026-10-01 09:3x CDT, in-chat to the ceo, verbatim: "So it appears the work list is out of date with reality. How can we
tighten up what work items actually exist for real, i.e. are necessary?" and "So get your findings=0 or whatever you need to get
your act together and the fleet working real needed work." and "Do everything you suggest to modify your protocol, standard
operating procedure, mode of operation, ways to communicate, etc. You are the CEO."

THE PRINCIPLE: a live row names a red that an instrument shows TODAY. Every row of QUEUE.tsv is classified and the live file is
rebuilt from the classes; nothing is deleted -- an archived or retired row keeps its task file and comes back only by being
re-minted from a current red (mint refuses a placeholder DONE-WHEN since this ruling).

  KEEP      CLAIMED or ASSIGNED (a live claim is never touched by script, CEO-755c); PARKED-LON-HOLD; PARKED-UMBRELLA (an HQ's
            own steps under its one thing); BLOCKED-ON / PARKED-AWAITING whose blocker is itself live after the sweep.
  DELETE    a DONE row still in the live file: its line, its baton and its claim are removed; nothing is archived.
  RETIRE    SUPERSEDED and RETIRED rows -> QUEUE.retired.tsv; PARKED-EXECUTIVE-NO-SEAT (parked by a mode flip, never by a
            judgement), PARKED-REBUS-CLOSED, plain PARKED, orphaned BLOCKED/AWAITING -> QUEUE.retired.tsv as
            RETIRED:zero-base-<reason>; a FREE row whose DONE-WHEN is the mint placeholder (no finish line) or RUNS A BOARD
            (cannot close through done, CEO-1342 clause 5) -> retired likewise: the red it meant lives on the SUITE TABLE, and
            its owner re-mints one row per cause with a reader of the coo's row as the criterion.
  RUN       every other FREE row's DONE-WHEN is executed as the bus executes it (cwd $S4E_HOME, S4E_HOME exported, the progress
            and score writes off): rc 0 -> GREEN, the work is done, archived as DONE:zero-base-green; rc 1 -> RED, kept, and
            re-ranked to 2 (urgency is the board's to say; an every-suite-to-100 row keeps its rank); rc 2 -> CANNOT MEASURE,
            retired; a timeout -> kept at rank 2 and named.
  LOAD GUARD (ceo CEO-1574, 2026-10-08, closing the coo's row instruments-the-sweep-keeps-a-row-whose-finish-line-refused-on-a-
            load-guard-instead-of-retiring-it-ceo-1562; Lon's two-number law, CEO-743: a multiple is not load-invariant). An rc 2
            whose output names the load guard -- the words "load-guard" (or "loadavg") on a line, which the four bench bars
            (bench_{icon,pascal,prolog,snobol4}_bar.sh) print through perf_load_guard on a timing-shaped refusal (angles that
            DISAGREE, a harness that printed no row or no time twin) when the box reads at or above BENCH_LOAD_GUARD_PER_CORE
            (default 0.5) per core -- is NOT a measurement of the row: the row is KEPT exactly as a TIMEOUT is kept (never
            retired; PARKED-EXPIRED only when its baton was unwritten for 7 days), its refusal line and the sweep's own load
            reading go to the baton as a LEDGER line that does NOT restart the expiry clock (the baton's mtime is put back, so a
            quiet sweep measures it), and the salvage log names the class LOAD-GUARD-kept. A plain rc 2 (no oracle, no binary,
            a wrong answer, a refusal on a quiet box) stays CANNOT MEASURE and retires. Before this rule, the sweeps of 10-07
            20:16 and 10-08 15:18 and 19:17 retired fourteen live performance rows under the fleet's builds, each re-minted by hand.
            The gate is SCRIP ../harness/scripts/test_gate_sweep_keeps_a_load_guard_refusal_and_retires_a_cannot_measure_one.sh.
  KNIT      (ceo CEO-1574, 2026-10-08 23:0x, measured on the first sweep under the load guard): every criterion runs in the ceo's
            root, and a criterion that BUILDS there and is killed at the timeout leaves the tree half-built, so every later
            criterion that runs the binary refuses rc 2 -- nine rows were retired as cannot-measure after the 88th criterion's make
            was killed at 240 s, and every one of the three sampled read RED on the re-knit tree. So the tree is KNIT (ZB_KNIT_CMD,
            default make -s -C $S4E_HOME/SCRIP, 900 s) once before the run phase and again after every kill, each knit printed as a
            KNIT line with its rc and seconds; a knit that fails HALTS the run phase (the remaining criteria are left as they were,
            written UNTOUCHED, never retired), because every rc 2 after it would be false. The gate plants a criterion that sleeps
            past --timeout and reads two KNIT lines.

The three files are written ONLY with --apply, against a FRESH read of QUEUE.tsv at write time: a row whose state moved while the
criteria ran (a claim, a done) is left as the fleet left it. Backups are written beside the files; every decision is written to
postoffice/salvage/zero-base-<stamp>.tsv (topic, owner, old state, class, rc, new place). Without --apply the classes and counts are
printed and nothing is written; --no-run skips the execution and reports the static classes only.
"""
import json, os, re, shutil, signal, subprocess, sys, tempfile, time
PO = os.environ.get("S4E_POSTOFFICE", "/home/resources/postoffice")
Q, QR, TASKS = PO + "/QUEUE.tsv", PO + "/QUEUE.retired.tsv", PO + "/tasks"
S4E = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # the coo 2026-11-04: the root that holds this .github (the ceo root is gone; the default crashed every sweep since 11-01)
if "--help" in sys.argv or "-h" in sys.argv: print(__doc__); sys.exit(0)
apply = "--apply" in sys.argv; norun = "--no-run" in sys.argv
_m = re.search(r"^ROSTER:\s*(.*)$", open("/home/resources/postoffice/MODE", encoding="utf-8").read(), re.M); SEATED = set(_m.group(1).split()) if _m else set()   # MODE's keyed ROSTER line: the seated seats (the coo 2026-11-04)
tmo = int(sys.argv[sys.argv.index("--timeout") + 1]) if "--timeout" in sys.argv else 240
stamp = time.strftime("%Y%m%d-%H%M%S")
PLACEHOLDER = ("NOT MEASURED", "minted with no acceptance criterion", "NOT EXPRESSED")
LOAD_GUARD = re.compile(r"load-guard|loadavg|load guard", re.I)

def rows_of(path):
    return open(path, encoding="utf-8").read().split("\n") if os.path.exists(path) else []

def donewhen(topic):
    f = os.path.join(TASKS, topic + ".task.md")
    if not os.path.exists(f): return None
    for ln in open(f, encoding="utf-8", errors="replace"):
        if ln.startswith("DONE-WHEN:"): return ln[len("DONE-WHEN:"):].strip()
    return ""

def board_topics():
    xc = S4E + "/harness/scripts/util_donewhen_exemption_census.py"
    try:
        p = subprocess.run([sys.executable, xc, "--json"], capture_output=True, text=True, timeout=600, env=dict(os.environ, S4E_TASKS=TASKS))
        d = json.loads(p.stdout or "{}")
        return {r["topic"] for r in d.get("rows", []) if r.get("live") and r.get("class") in ("BOARD", "GUARD")}
    except Exception as e:
        print("WARNING: the exemption census could not be read (%s); no BOARD class" % e); return set()

def descendants(pid):
    kids = {}
    for d in os.listdir("/proc"):
        if not d.isdigit(): continue
        try: st = open("/proc/%s/stat" % d).read()
        except Exception: continue
        try: pp = int(st[st.rindex(")") + 2:].split()[1])
        except Exception: continue
        kids.setdefault(pp, []).append(int(d))
    out, todo = [], [pid]
    while todo:
        x = todo.pop(); ch = kids.get(x, []); out.extend(ch); todo.extend(ch)
    return out

def kill_tree(p):
    # GNU timeout(1) puts its child in a process group of its own, so killpg alone leaks a runner (measured 2026-10-01: a
    # ladder run outlived its 45 s criterion by minutes); every descendant is killed by pid, deepest first, then the group.
    for d in reversed(descendants(p.pid)):
        try: os.kill(d, signal.SIGKILL)
        except Exception: pass
    try: os.killpg(os.getpgid(p.pid), signal.SIGKILL)
    except Exception: pass
    try: p.kill()
    except Exception: pass
    p.wait()

def run_dw(dw):
    # the criterion's output is kept (its last 8 KB) because the LOAD GUARD is read from the criterion's own words: a bar that
    # refuses under load says so on its refusal line, and nothing else distinguishes that rc 2 from a cannot-measure one.
    env = dict(os.environ, S4E_HOME=S4E, S4E_PROGRESS_OFF="1", S4E_SCORE_NO_WRITE="1", S4E_DONE_WHEN_RUN="1")
    with tempfile.TemporaryFile() as fh:
        # THE CHECK CACHE (ARCH-SHARED-DEVELOPMENT 3.3, shared-dev step 7): a criterion that names only cacheable test_gate_*.sh goes through
        # util_check_cache.sh under the same name s4e_msg.sh done uses, so the sweep and done share one verdict per tree.
        cc = os.path.join(S4E, "harness", "scripts", "util_check_cache.sh")
        cacheable = os.path.isfile(cc) and subprocess.run(["bash", cc, "--cacheable-text", dw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        argv = ["bash", cc, "done-when", "--", "bash", "-c", dw] if cacheable else ["bash", "-c", dw]
        p = subprocess.Popen(argv, cwd=S4E, env=env, stdin=subprocess.DEVNULL, stdout=fh, stderr=subprocess.STDOUT, start_new_session=True)
        try: rc = p.wait(timeout=tmo)
        except subprocess.TimeoutExpired:
            kill_tree(p); rc = "timeout"
        fh.seek(0, 2); n = fh.tell(); fh.seek(max(0, n - 8192)); tail = fh.read().decode("utf-8", "replace")
    return rc, tail

def load_now():
    try: la = open("/proc/loadavg").read().split()[0]
    except Exception: la = "?"
    return la, str(os.cpu_count() or "?")

KNIT_CMD = os.environ.get("ZB_KNIT_CMD", "make -s -C %s/SCRIP" % S4E)
def knit(why):
    # the ceo's root is where every criterion runs; a criterion that builds there and is killed at the timeout leaves it half-built,
    # and every later criterion that runs the binary refuses rc 2 (2026-10-08 22:07: nine rows retired as cannot-measure after the
    # 88th criterion's make was killed, each one RED on the re-knit tree). So the tree is knit before the run phase and after a kill.
    t1 = time.time()
    try: rc = subprocess.run(["bash", "-c", KNIT_CMD], cwd=S4E, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900).returncode
    except subprocess.TimeoutExpired: rc = "timeout"
    print("KNIT %s: %s -> rc %s in %ds" % (why, KNIT_CMD, rc, time.time() - t1), flush=True)
    return rc == 0

def baton_age_days(topic):
    f = os.path.join(TASKS, topic + ".task.md")
    try: return (time.time() - os.path.getmtime(f)) / 86400.0
    except Exception: return None
EXPIRE_FREE_DAYS, EXPIRE_PARKED_DAYS = 7, 30

live = [ln for ln in rows_of(Q)]
boards = board_topics()
decisions = {}   # topic -> (class, rc, place) ; place in KEEP/DONE/RETIRED
guard_lines = {}  # topic -> (the refusal line that named the load guard, load1 as it ran, cores)
topics_live = set()
parsed = []
for ln in live:
    f = ln.split("\t")
    if len(f) < 4 or ln.startswith("#"): continue
    parsed.append(f); topics_live.add(f[1])
def stt(s): return s.split(":")[0]
# pass 1: static classes
for f in parsed:
    rank, topic, owner, state = f[0], f[1], f[2], f[3]
    s = stt(state)
    if s.startswith("CLAIMED") or s.startswith("ASSIGNED"): decisions[topic] = ("KEEP-LIVE-CLAIM", "", "KEEP"); continue
    if s.startswith("DONE"): decisions[topic] = ("ARCHIVE-DONE", "", "DONE"); continue
    if s.startswith("SUPERSEDED") or s.startswith("RETIRED"): decisions[topic] = ("RETIRE-ALREADY", "", "RETIRED"); continue
    # ⛔ AN UMBRELLA THAT NAMES NO LIVE ROW IS NO UMBRELLA (ceo CEO-2083): 25 prolog rows sat PARKED-UMBRELLA:prolog-construct-ladder-old-
    # machine-defect-re-measured-when-its-rung-lands, a topic with no row anywhere, and this sweep kept them forever; re-measured 10-31, ten
    # read green, four red, two past 240 s and nine could not measure. Such a row is swept as FREE: its own DONE-WHEN decides it.
    if s == "PARKED-UMBRELLA" and ":" in state and state.split(":", 1)[1] not in topics_live: s = "FREE"
    if s == "PARKED-LON-HOLD" or s == "PARKED-UMBRELLA": decisions[topic] = ("KEEP-" + s, "", "KEEP"); continue
    if s == "PARKED": decisions[topic] = ("KEEP-PARKED-SEATED" if owner in SEATED else "KEEP-PARKED-STOOD-DOWN", "", "KEEP"); continue   # the coo 2026-11-04: a seated seat's plain PARKED row is live work
    # (a cure waiting on its grade, a design step), not litter: retiring it lost the cto's euler14 and predicate_property rows in a dry run. A stood-down seat's is kept too: MODE parks its rows in place until Lon's word (CEO-755c, no re-lane).
    if s in ("PARKED-EXECUTIVE-NO-SEAT", "PARKED-REBUS-CLOSED", "PARKED"): decisions[topic] = ("RETIRE-" + s.lower(), "", "RETIRED"); continue
    if s in ("PARKED-SUPERSEDED-BY", "PARKED-DUPLICATE-OF"): decisions[topic] = ("RETIRE-" + s.lower(), "", "RETIRED"); continue
    if s == "PARKED-EXPIRED":
        a = baton_age_days(topic)
        decisions[topic] = ("RETIRE-expired-%dd-parked" % EXPIRE_PARKED_DAYS, "", "RETIRED") if a is not None and a > EXPIRE_PARKED_DAYS else ("KEEP-PARKED-EXPIRED", "", "KEEP"); continue
    if s.startswith("PARKED-AWAITING") or s.startswith("BLOCKED-ON"): decisions[topic] = ("BLOCKER?", "", None); continue
    if s == "FREE":
        dw = donewhen(topic)
        if dw is None: decisions[topic] = ("RETIRE-no-task-file", "", "RETIRED"); continue
        if not dw or any(k in dw for k in PLACEHOLDER): decisions[topic] = ("RETIRE-placeholder-done-when", "", "RETIRED"); continue
        if topic in boards: decisions[topic] = ("RETIRE-board-done-when", "", "RETIRED"); continue
        decisions[topic] = ("RUN", dw, None); continue
    decisions[topic] = ("KEEP-other:" + s, "", "KEEP")
# pass 1b: blockers (ceo CEO-1569, 2026-10-08). A row BLOCKED-ON or PARKED-AWAITING a LIVE row is never touched (CEO-755c). A row
# whose blocker has CLOSED (DONE), was RETIRED, or is absent from the live queue is UNBLOCKED: its own measurement decides it, exactly
# as a FREE row's does -- GREEN closes it, RED returns it to FREE at its rank. Before this pass existed, pass 3 retired every such row
# as blocker-not-live: prolog-every-suite-to-100-under-nonet-ceo-1266 died that way on 10-03 when the rewrite-plan row it waited on
# closed, and the Prolog lane ran five days with no rank-0 row under four red suites.
def blocker_of(state):
    m = re.match(r"(?:PARKED-AWAITING|BLOCKED-ON):(.*)", state); return m.group(1) if m else None
unblocked = set()
for f in parsed:
    topic, state = f[1], f[3]
    if decisions.get(topic, ("",))[0] != "BLOCKER?": continue
    b = blocker_of(state); db = decisions.get(b)
    live_b = db is not None and (db[2] == "KEEP" or db[0] in ("RUN", "BLOCKER?"))
    if live_b: decisions[topic] = ("KEEP-blocked-on-live", "", "KEEP"); continue
    dw = donewhen(topic)
    if dw is None: decisions[topic] = ("RETIRE-no-task-file", "", "RETIRED"); continue
    if not dw or any(k in dw for k in PLACEHOLDER): decisions[topic] = ("RETIRE-placeholder-done-when", "", "RETIRED"); continue
    if topic in boards: decisions[topic] = ("RETIRE-board-done-when", "", "RETIRED"); continue
    decisions[topic] = ("RUN", dw, None); unblocked.add(topic)
# pass 2: run the FREE and the unblocked criteria
todo = [t for t, d in decisions.items() if d[0] == "RUN"]
print("static classes:", {k: v for k, v in sorted(__import__("collections").Counter(d[0] for d in decisions.values()).items())})
print("criteria to run:", len(todo), "(timeout %ss each)" % tmo, flush=True)
if not norun:
    t0 = time.time(); tally = {"GREEN": 0, "RED": 0, "CANNOT": 0, "TIMEOUT": 0, "LOADGUARD": 0}
    halt = not knit("before the run phase")
    if halt: print("HALT: the tree does not build, so no criterion is run -- every rc 2 would be false; the %d criteria are left as they were" % len(todo), flush=True)
    for i, t in enumerate(todo, 1):
        if halt: break
        print("RUNNING %s" % t, flush=True)
        rc, tail = run_dw(decisions[t][1])
        if rc == 0: decisions[t] = ("GREEN-now", 0, "DONE"); tally["GREEN"] += 1; v = "GREEN"
        elif rc == 1: decisions[t] = ("RED-now", 1, "KEEP"); tally["RED"] += 1; v = "RED"
        elif rc == "timeout":
            a = baton_age_days(t); exp = a is not None and a > EXPIRE_FREE_DAYS
            decisions[t] = ("TIMEOUT-expired-parked" if exp else "TIMEOUT-kept", "timeout", "KEEP"); tally["TIMEOUT"] += 1; v = "TIMEOUT" + ("-EXPIRED" if exp else "")
            halt = not knit("after the killed criterion %s" % t[:60])
            if halt: print("HALT: the tree does not re-knit after the kill; the remaining %d criteria are left as they were" % (len(todo) - i), flush=True)
        elif rc == 2 and LOAD_GUARD.search(tail):
            a = baton_age_days(t); exp = a is not None and a > EXPIRE_FREE_DAYS
            words = [l.strip() for l in tail.splitlines() if LOAD_GUARD.search(l)]; la, nc = load_now(); guard_lines[t] = (words[-1][:240] if words else "", la, nc)
            decisions[t] = ("LOAD-GUARD-expired-parked" if exp else "LOAD-GUARD-kept", 2, "KEEP"); tally["LOADGUARD"] += 1; v = "LOAD-GUARD" + ("-EXPIRED" if exp else "")
        else: decisions[t] = ("RETIRE-cannot-measure-rc%s" % rc, rc, "RETIRED"); tally["CANNOT"] += 1; v = "CANNOT-MEASURE"
        el = time.time() - t0; eta = el / i * (len(todo) - i)
        print("COUNTDOWN %d left of %d | %d done | %dm%02ds elapsed, ~%dm%02ds to go | GREEN %d RED %d CANNOT %d TIMEOUT %d LOAD-GUARD %d | last: %s -> %s" % (len(todo) - i, len(todo), i, el // 60, el % 60, eta // 60, eta % 60, tally["GREEN"], tally["RED"], tally["CANNOT"], tally["TIMEOUT"], tally["LOADGUARD"], t[:70], v), flush=True)
# pass 3: the unblocked rows that were not run (--no-run) stay as they are; nothing here retires a row for its blocker's state
if unblocked: print("unblocked (blocker closed, retired or absent; their own criterion decides): %d" % len(unblocked)); [print("   " + t) for t in sorted(unblocked)]
cnt = __import__("collections").Counter(d[0] for d in decisions.values())
print("final classes:"); [print("  %-36s %d" % (k, v)) for k, v in sorted(cnt.items())]
print("live rows after: %d  archived DONE: %d  retired: %d" % (sum(1 for d in decisions.values() if d[2] == "KEEP"), sum(1 for d in decisions.values() if d[2] == "DONE"), sum(1 for d in decisions.values() if d[2] == "RETIRED")))
greens = [t for t, d in decisions.items() if d[0] == "GREEN-now"]
if greens: print("GREEN now (archived as done):"); [print("   " + t) for t in greens]
if not apply: print("DRY RUN: nothing written"); sys.exit(0)
# ⛔ THE BUS'S QUEUE LOCK (ceo CEO-1708, 2026-10-14): every s4e_msg.sh verb that rewrites QUEUE.tsv takes the mkdir lock $PO/.mint.lock
# (s4e_set_row_state, mint, ...); this sweep wrote QUEUE.tsv and QUEUE.retired.tsv without it, so a bus verb landing
# between its fresh read and its write was lost. The write phase below holds the SAME lock -- never while a DONE-WHEN runs -- waits up
# to 10 s for it, and REFUSES rc 2 with nothing written when it cannot take it; atexit releases it if the write phase dies.
LK = PO + "/.mint.lock"
for _i in range(100):
    try:
        os.mkdir(LK); break
    except FileExistsError:
        time.sleep(0.1)
else:
    print("REFUSE(2): %s is held by a bus verb for 10 s -- nothing written; re-run --apply" % LK); sys.exit(2)
import atexit
def _release_lock():
    try:
        os.rmdir(LK)
    except OSError:
        pass
atexit.register(_release_lock)
# write against a fresh read
fresh = rows_of(Q); out, done_rm, ret_add, log, ledger_add, guard_add = [], [], [], [], [], []
old_state = {f[1]: f[3] for f in parsed}
for ln in fresh:
    f = ln.split("\t")
    if len(f) < 4 or ln.startswith("#"): out.append(ln); continue
    topic = f[1]; d = decisions.get(topic)
    if d is None or f[3] != old_state.get(topic): out.append(ln); log.append((topic, f[2], f[3], "UNTOUCHED-moved-meanwhile", "", "KEEP")); continue
    cls, rc, place = d
    if place is None: out.append(ln); log.append((topic, f[2], f[3], cls + "-not-run", "", "KEEP")); continue
    if place == "KEEP":
        if cls == "RED-now" and "-every-suite-to-100-" not in topic and f[0] in ("0", "1"): f[0] = "2"
        if cls in ("TIMEOUT-expired-parked", "LOAD-GUARD-expired-parked"): f[3] = "PARKED-EXPIRED"
        elif topic in unblocked and cls in ("RED-now", "TIMEOUT-kept", "LOAD-GUARD-kept"): f[3] = "FREE"
        if cls == "RED-now": ledger_add.append((topic, f[0]))
        if cls.startswith("LOAD-GUARD"): guard_add.append((topic, f[0]))
        out.append("\t".join(f))
    elif place == "DONE":
        done_rm.append(topic)
        for _p in (os.path.join(TASKS, topic + ".task.md"), os.path.join(PO, "claims", topic + ".claim")):
            try: os.remove(_p)
            except FileNotFoundError: pass
    else:
        f[3] = f[3] if cls == "RETIRE-ALREADY" else "RETIRED:zero-base-r-1386-" + cls.replace("RETIRE-", ""); ret_add.append("\t".join(f))
    log.append((topic, f[2], old_state[topic], cls, str(rc), place))
for p in (Q, QR):
    if os.path.exists(p): shutil.copyfile(p, p + ".bak.%s-zero-base-ceo-1386" % stamp)
open(Q, "w", encoding="utf-8", newline="\n").write("\n".join(out))
def append(p, rows):
    if not rows: return
    cur = rows_of(p); txt = "\n".join([r for r in cur if r != ""] + rows) + "\n"; open(p, "w", encoding="utf-8", newline="\n").write(txt)
append(QR, ret_add)
_release_lock(); atexit.unregister(_release_lock)
when = time.strftime("%Y-%m-%d %H:%M %Z")
for topic, rank in ledger_add:
    f = os.path.join(TASKS, topic + ".task.md")
    try:
        with open(f, "a", encoding="utf-8", newline="\n") as fh:
            fh.write("\n- %s zero-base (ceo, CEO-1386): the DONE-WHEN ran RED (rc=1) in %s under a %ss limit; the row stays live at rank %s. A measured red is the only reason this row exists; the clock for PARKED-EXPIRED restarts here.\n" % (when, S4E, tmo, rank))
    except Exception as e: print("WARNING: ledger line not written for %s: %s" % (topic, e))
for topic, rank in guard_add:
    f = os.path.join(TASKS, topic + ".task.md"); line, la, nc = guard_lines.get(topic, ("", "?", "?"))
    try:
        st = os.stat(f)
        with open(f, "a", encoding="utf-8", newline="\n") as fh:
            fh.write("\n- %s zero-base (ceo, CEO-1574 under CEO-1386): the DONE-WHEN REFUSED (rc=2) on a LOAD GUARD in %s, the box at load %s on %s cores as it ran: %s. KEPT at rank %s as a TIMEOUT is kept, never retired on a timing refusal (a multiple is not load-invariant, CEO-743); this line does not restart the PARKED-EXPIRED clock -- a quiet sweep measures the row.\n" % (when, S4E, la, nc, line, rank))
        os.utime(f, (st.st_atime, st.st_mtime))
    except Exception as e: print("WARNING: load-guard ledger line not written for %s: %s" % (topic, e))
os.makedirs(PO + "/salvage", exist_ok=True)
with open(PO + "/salvage/zero-base-%s-ceo-1386.tsv" % stamp, "w", encoding="utf-8", newline="\n") as fh:
    fh.write("topic\towner\told_state\tclass\trc\tplace\n")
    for l in log: fh.write("\t".join(l) + "\n")
print("WRITTEN: live %d rows, +%d done, +%d retired, %d kept on the load guard; log postoffice/salvage/zero-base-%s-ceo-1386.tsv; backups beside the files" % (sum(1 for l in out if l and not l.startswith("#")), len(done_rm), len(ret_add), len(guard_add), stamp))
