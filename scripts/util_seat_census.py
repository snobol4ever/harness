#!/usr/bin/env python3
"""util_seat_census.py -- THE LEDGER: WHO LOADS THE BOX, FROM THE CGROUP SCOPES (ARCH-SHARED-DEVELOPMENT.md sections 2 and 8 step 1, R-2041;
the cao's row shared-dev-step-1-the-seat-census-reads-the-cgroup-scopes-and-the-ledger-load-tsv-is-written-every-five-minutes-r-2041).

The load average says THAT the box is busy, never WHO. Every cgroup under user-1000.slice is a ledger line the kernel keeps exactly: cpu.stat's
usage_usec counts every descendant, short-lived compilers included, which a ps sampler undercounts. This walks them, samples cpu.stat twice ten seconds
apart, reads memory.current, memory.peak, memory.events (oom_kill) and pids.current, maps each scope to its seat and class (a s4e-mem-<seat>-* scope inside s4e-batch.slice or
s4e-grader.slice is a BATCH or GRADER line NAMED BY ITS SEAT TOKEN, the cfo's note of 16:5x; the slice's remainder is the line named batch or grader), and appends to
/home/resources/progress/LOAD.tsv one line per seat and per class, plus one BOX line.

THE SEAT'S RUNS (the fleet test, 2026-11-01): app.slice/app-s4e.slice/app-s4e-<seat>.slice is the seat's run slice (systemd nests by the dashes) (util_mem_scope.py puts every classless run there);
its cpu.stat keeps the total of every child it ever held, so a graded entry that lived three seconds between two samples still counts for its seat;
a run placed straight under app.slice by an older harness is counted while it lives and lost when it ends inside the window.
THE CLASSES (2.1): SEAT, a Claude session scope (app-org.gnome.Terminal.slice/vte-spawn-*.scope) whose newest SEATS.tsv line names a seat, with the
board-run scopes app.slice/s4e-mem-<seat>-*.scope added to that seat; GRADER, s4e.slice/s4e-grader.slice; BATCH, s4e.slice/s4e-batch.slice; LON, Lon's
own session scope (SEATS.tsv class LON, or an unmapped session scope) and the desktop's app-gnome-*/Chrome scopes; CRON, a session-*.scope directly
under user-1000.slice; SYSTEM, everything else there, one line, never acted on.
SLOTS: a compile or run slot is held by the process that keeps /tmp/s4e-cc-slots/slotN or /tmp/s4e-run-slots/slotN open (util_cc_slot.sh holds it on
fd 9 for the compiler's whole life), so the holders are read from /proc/*/fd and mapped to a seat by the holder's cgroup: kernel truth, never stale.
SLOT SEATS (the cto's ruling 16:1x): a taker under step 3 also holds /tmp/s4e-{cc,run}-slots/seat/<seat>/<k>; when the holder's cgroup is a
shared scope (batch, grader), the seat is read from that path.
TMP: one du of /tmp/claude-1000/-home-claude-<seat>* and /tmp/s4e/<seat> per seat, cached for fifteen minutes in /home/resources/progress/LOAD_TMP.tsv.

  util_seat_census.py run              sample, append to LOAD.tsv, print nothing (cron, every five minutes, in s4e-batch.slice)
  util_seat_census.py now              sample and print the table, append nothing
  util_seat_census.py banner [SEAT]    ONE line from the newest LOAD.tsv run, never sampling (s4e_msg.sh banner)
  util_seat_census.py --check          step 1's DONE-WHEN: rc 0 when the newest run is under ten minutes old, every seat whose newest SEATS.tsv scope is live
                                       has a SEAT line, no live session scope is unmapped, and the SEAT and LON lines' cores sum to within ten percent of
                                       app.slice's own delta; rc 1 RED naming the gap; rc 2 no ledger or no cgroup tree
  --cpu-check                          RED on cpu pressure avg300 >= 30, a busy box with idle pools, a seat over 2 cores holding no slot, the grader under 2 cores while it waits, Lon's terminal waiting
  --tmp-check                          RED by name, largest first, for every seat whose /tmp (session scratchpads and /tmp/s4e/<seat>) is over TMP_SEAT_MB
  --proc-check                         RED by name: a fleet process, or any process of a seat session scope, orphaned to the user manager 5 min or more, box memory pressure avg60 >= 10, a seat scope at 90%% of memory.high
                                       whose ANON is at 90%% of it; a scope there by its file pages is RECLAIMED (memory.reclaim swappiness=0), never alarmed (box-budget step 7)
  --watch-check                        RED when the coo's loop, tier1 (the fleet watch) or the seat watch is not running, or the fleet watch has not passed in 15 min
  --health                             --check, --memory-check, --cpu-check, --tmp-check, --proc-check and --watch-check together; rc the worst
  --memory-check                       step 8's DONE-WHEN (it prints each live seat scope's cur, high, anon and file, box-budget step 7): every live seat scope's memory.max below the box, the sessions' slice and the two s4e slices
                                       capped, S4E_SEAT in each session and both runners placing TMPDIR=/tmp/s4e/<seat>, /tmp under 60, no oom_kill in 24 h
  util_seat_census.py --grader-rate S  step 5's DONE-WHEN (default 7200): 200 distinct programs per hour or more among results.tsv's rr=1 rows while the ledger's
                                       cores_busy mean read 12 or more; rc 2 when the box was not busy (the rate under no contention measures nothing)
  util_seat_census.py --acceptance S   step 9's DONE-WHEN (default 86400): over the busy runs (twelve at least) the grader at 2.0 cores or more, no seat's
                                       ten-minute mean above 4.0 while another seat waited for a slot, pressure some avg300 under 30, builds FETCHED ten
                                       times the BUILT (BUILDS.tsv, written by util_build_cache.sh), landings on origin/main at 10 an hour or more
  util_seat_census.py --test-cycle-acceptance W BASELINE.tsv   DESIGN-PLAN test-cycle step 8: ONE line TEST_CYCLE_ACCEPTANCE over the last W seconds (entries an hour,
                                       the multiple of the baseline, instructions an entry from one perf-counted launch of a master and a package cell as the grade worker,
                                       the request verdict p50/p95, the lap by 06:00, the ready-while-idle minutes from TICK_DIR/ticks.log, the hand restarts from the
                                       journal); a field it cannot read prints '-' (rc 2). --probe: scratch ledgers read a known line (rc 0/1). --until --cells --journal
                                       --req-done --lap-file --ticks name other inputs
  util_seat_census.py --lap [S]        box-budget step 1 (CTO-474/478): the LAP line over the last S seconds (default 3600): the loop's rows per hour (the coo's
                                       readings tagged rr=1 or req=), fresh=F/T (util_round_robin_freshness.py's live population and fresh rule over 72 h), the ETA of
                                       the stale rows at that rate and the whole lap's length; LAP_SLICES each class's mean cores and share and LAP_SEATS each seat's
                                       from LOAD.tsv; LAP_WAITS the slot waits from SLOT_WAITS.tsv; `run` appends the LAP line to LOAD.tsv every tick. The population
                                       (85 s of from-progress calls) is cached an hour in LAP_POP.tsv. rc 0 printed; rc 2 no results.tsv or no live population
  util_seat_census.py --budget-check   box-budget step 2 (CTO-474/478): every row of the ONE declared budget table /home/resources/postoffice/BUDGET.tsv read against the
                                       live cgroup files (cpu.weight, cpu.max, memory.high, memory.max, memory.swap.max, pids.max): a slice by its path, @SEAT and
                                       @LON every live session scope of that class in SEATS.tsv; rc 0 all agree, 1 RED naming unit, file, live and declared, 2 no table
  util_seat_census.py --budget-props [NAME]  the systemd properties of the row NAME (its name or unit), or one `unit props...` line per slice row: what
                                       s4e_session_start.sh, util_fleet_settings.sh and the loop starters apply (systemctl --user set-property, systemd-run -p)
  --budget F                           the table (default S4E_BUDGET, else /home/resources/postoffice/BUDGET.tsv), for the fixtures
  --load F --seats F --root DIR        read and write these instead (the gate's fixtures)
  --results F --waits F --builds F --repos DIR   the other ledgers and the repo root, for the fixtures
  --loop-dir D --pop-cache F           the loop's directory (loop8.sh's ROT, idle_units) and the population cache, for --lap's fixtures
"""
import os, re, sys, time, glob, subprocess
CG = "/sys/fs/cgroup/user.slice/user-1000.slice"
LOAD = "/home/resources/progress/LOAD.tsv"
SEATS = "/home/resources/progress/SEATS.tsv"
TMPCACHE = "/home/resources/progress/LOAD_TMP.tsv"
COLS = ["utc", "kind", "class", "name", "cores", "mem_mb", "mem_peak_mb", "oom_kills", "pids", "cc_slots", "run_slots", "tmp_mb"]
BOXCOLS = ["cores_busy", "load1", "pressure_some_avg60", "pressure_some_avg300", "mem_available_mb", "swap_used_mb", "tmp_pct", "cc_held", "run_held", "slice_held", "builds_fetched", "compiles", "checks_hit", "oracle_hit"]
RESULTS = "/home/resources/progress/results.tsv"
WAITS = "/home/resources/progress/SLOT_WAITS.tsv"
ADMISSION_WAIT_DAY_S = 300
ADMISSION_CC_BAR = 8
BUILDS = "/home/resources/progress/BUILDS.tsv"
TERM = "user@1000.service/app.slice/app-org.gnome.Terminal.slice/"
LAPPOP = "/home/resources/progress/LAP_POP.tsv"
BUDGET = "/home/resources/postoffice/BUDGET.tsv"
BUDGET_KNOBS = [("CPUWeight", "cpu.weight"), ("CPUQuota", "cpu.max"), ("MemoryHigh", "memory.high"), ("MemoryMax", "memory.max"), ("MemorySwapMax", "memory.swap.max"), ("TasksMax", "pids.max")]
LOOPDIR = "/home/claude_coo/.scratch/verifier"
FRESH_H = 72


def arg(flag, default):
    a = sys.argv
    return a[a.index(flag) + 1] if flag in a and a.index(flag) + 1 < len(a) else default


def rd(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return default


def usage_usec(d):
    m = re.search(r"^usage_usec (\d+)", rd(os.path.join(d, "cpu.stat")), re.M)
    return int(m.group(1)) if m else None


def num(d, f):
    t = rd(os.path.join(d, f)).strip()
    return int(t) if t.isdigit() else 0


def oom_kills(d):
    m = re.search(r"^oom_kill (\d+)", rd(os.path.join(d, "memory.events")), re.M)
    return int(m.group(1)) if m else 0


def seat_map(seats_path):
    live = {}
    for line in rd(seats_path).splitlines():
        f = line.split("\t")
        if len(f) < 4 or f[0] == "utc" or line.startswith("#"):
            continue
        live[f[1]] = (f[2], f[3].replace("/user.slice/user-1000.slice/", ""))
    return live


def scopes(root):
    """Every leaf-level unit this census accounts: (relative path, class, name). A unit is counted once, at the level its class is defined."""
    out = []
    svc = os.path.join(root, "user@1000.service")
    app = os.path.join(svc, "app.slice")
    term = os.path.join(app, "app-org.gnome.Terminal.slice")
    for d in sorted(glob.glob(os.path.join(term, "*.scope"))):
        out.append((os.path.relpath(d, root), "SESSION", None))
    for d in sorted(glob.glob(os.path.join(app, "s4e-mem-*.scope"))):
        m = re.match(r"s4e-mem-([a-z0-9_]+)-", os.path.basename(d))
        out.append((os.path.relpath(d, root), "BOARD", m.group(1) if m else "unknown"))
    for d in sorted(glob.glob(os.path.join(app, "app-s4e.slice", "app-s4e-*.slice")) + glob.glob(os.path.join(svc, "s4e.slice", "s4e-runs.slice", "s4e-runs-*.slice"))):   # the seat's runs: s4e-runs-<seat>.slice inside the fleet's one slice since 2026-11-13 (util_mem_scope.seat_slice), app-s4e-<seat>.slice before
        m = re.match(r"(?:app-s4e|s4e-runs)-([a-z0-9_]+)\.slice", os.path.basename(d))
        out.append((os.path.relpath(d, root), "BOARD", m.group(1) if m else "unknown"))
    for d in sorted(glob.glob(os.path.join(app, "*.scope")) + glob.glob(os.path.join(app, "*.slice"))):
        b = os.path.basename(d)
        if b.startswith("s4e-mem-") or b == "app-s4e.slice" or b == "app-org.gnome.Terminal.slice":
            continue
        out.append((os.path.relpath(d, root), "LON", "desktop"))
    for cls, sl in (("GRADER", "s4e-grader.slice"), ("BATCH", "s4e-batch.slice")):
        d = os.path.join(svc, "s4e.slice", sl)
        if os.path.isdir(d):
            out.append((os.path.relpath(d, root), cls, cls.lower()))
            for c in sorted(glob.glob(os.path.join(d, "s4e-mem-*.scope"))):
                m = re.match(r"s4e-mem-([a-z0-9_]+)-", os.path.basename(c))
                out.append((os.path.relpath(c, root), cls + "_CHILD", m.group(1) if m else "unknown"))
    for d in sorted(glob.glob(os.path.join(root, "session-*.scope"))):
        out.append((os.path.relpath(d, root), "CRON", "cron"))
    for d in [os.path.join(svc, "session.slice"), os.path.join(svc, "background.slice"), os.path.join(svc, "init.scope")]:
        if os.path.isdir(d):
            out.append((os.path.relpath(d, root), "SYSTEM", "system"))
    return out


def classify(units, live):
    by_scope = {sc: (seat, cls) for seat, (cls, sc) in live.items()}
    rows, unmapped = [], []
    for rel, kind, name in units:
        if kind == "SESSION":
            seat, cls = by_scope.get(rel, (None, None))
            if seat is None:
                unmapped.append(rel)
                rows.append((rel, "LON", "unmapped"))
            else:
                rows.append((rel, "LON" if cls == "LON" else "SEAT", seat))
        elif kind == "BOARD":
            rows.append((rel, "SEAT", name))
        elif kind.endswith("_CHILD"):
            rows.append((rel, kind[:-6], name))
        else:
            rows.append((rel, kind, name))
    return rows, unmapped


def slot_holders(root):
    """Who holds each slot: the processes with a slot file open, mapped to their seat by cgroup."""
    by_scope = {}
    for seat, (cls, sc) in seat_map(arg("--seats", SEATS)).items():
        by_scope[sc] = seat
    held = {"cc": {}, "run": {}}
    for pd in glob.glob("/proc/[0-9]*"):
        try:
            fds = os.listdir(pd + "/fd")
        except OSError:
            continue
        kinds = set()
        slots = set()
        seat_file = None
        for fd in fds:
            try:
                t = os.readlink(pd + "/fd/" + fd)
            except OSError:
                continue
            if t.startswith("/tmp/s4e-cc-slots/slot"):
                kinds.add("cc"); slots.add(("cc", t))
            elif t.startswith("/tmp/s4e-run-slots/slot"):
                kinds.add("run"); slots.add(("run", t))
            m = re.match(r"/tmp/s4e-(?:cc|run)-slots/seat/([a-z0-9_]+)/", t)
            if m:
                seat_file = m.group(1)
        if not kinds:
            continue
        cg = ""
        for line in rd(pd + "/cgroup").splitlines():
            if line.startswith("0::"):
                cg = line[3:].replace("/user.slice/user-1000.slice/", "")
        seat = None
        for sc, s in by_scope.items():
            if cg == sc or cg.startswith(sc + "/"):
                seat = s
        m = re.search(r"s4e-mem-([a-z0-9_]+)-", cg)
        seat = seat or (m.group(1) if m else seat_file or ("grader" if "s4e-grader" in cg else "batch" if "s4e-batch" in cg else "other"))
        for k, slot in slots:   # a slot is held once however many processes share its fd (gcc, cc1, as: the fleet test read cc_held=19 of 8, 2026-11-01)
            held[k].setdefault(seat, set()).add(slot)
    return {k: {s: len(v) for s, v in d.items()} for k, d in held.items()}


def tmp_sizes(seats):
    now = time.time()
    cache = {}
    for line in rd(TMPCACHE).splitlines():
        f = line.split("\t")
        if len(f) == 3:
            cache[f[0]] = (float(f[1]), int(f[2]))
    out = {}
    for s in seats:
        if s in cache and now - cache[s][0] < 900:
            out[s] = cache[s][1]
            continue
        paths = glob.glob("/tmp/claude-1000/-home-claude-%s*" % s.replace("hq_", "")) + [p for p in ["/tmp/s4e/" + s] if os.path.isdir(p)]
        kb = 0
        if paths:
            r = subprocess.run(["du", "-sk", "--"] + paths, capture_output=True, text=True, timeout=120)
            kb = sum(int(l.split()[0]) for l in r.stdout.splitlines() if l.split() and l.split()[0].isdigit())
        out[s] = kb // 1024
        cache[s] = (now, out[s])
    try:
        with open(TMPCACHE + ".tmp", "w") as f:
            for s, (t, v) in cache.items():
                f.write("%s\t%.0f\t%d\n" % (s, t, v))
        os.replace(TMPCACHE + ".tmp", TMPCACHE)
    except OSError:
        pass
    return out


def sample(root, seats_path, interval=10.0):
    live = seat_map(seats_path)
    units = scopes(root)
    rows, unmapped = classify(units, live)
    app = os.path.join(root, "user@1000.service", "app.slice")
    a = {rel: usage_usec(os.path.join(root, rel)) for rel, _, _ in rows}
    a_app = usage_usec(app)
    t0 = time.time()
    time.sleep(interval)
    dt = time.time() - t0
    b = {rel: usage_usec(os.path.join(root, rel)) for rel, _, _ in rows}
    b_app = usage_usec(app)
    acc = {}
    kids = {}
    for rel, cls, name in rows:
        if cls in ("BATCH", "GRADER") and name not in ("batch", "grader") and a.get(rel) is not None and b.get(rel) is not None:
            k = kids.setdefault(rel.rsplit("/", 1)[0], [0, 0, 0, 0])
            k[0] += max(0, b[rel] - a[rel]); dd = os.path.join(root, rel)
            k[1] += num(dd, "memory.current") // 1048576; k[2] += num(dd, "memory.peak") // 1048576; k[3] += num(dd, "pids.current")
    for rel, cls, name in rows:
        d = os.path.join(root, rel)
        if a.get(rel) is None or b.get(rel) is None:
            continue
        sub = kids.get(rel, [0, 0, 0, 0])
        cores = max(0, b[rel] - a[rel] - sub[0]) / 1e6 / dt
        k = (cls, name)
        e = acc.setdefault(k, [0.0, 0, 0, 0, 0])
        e[0] += cores
        e[1] += max(0, num(d, "memory.current") // 1048576 - sub[1])
        e[2] += max(0, num(d, "memory.peak") // 1048576 - sub[2])
        e[3] += oom_kills(d)
        e[4] += max(0, num(d, "pids.current") - sub[3])
    app_cores = (b_app - a_app) / 1e6 / dt if a_app is not None and b_app is not None else 0.0
    return acc, unmapped, live, app_cores


def oracle_hits(window):
    """hit/total of util_oracle.sh's calls in the last WINDOW seconds, from the tail of its LOG.tsv."""
    try:
        with open("/home/resources/progress/oracle/LOG.tsv", "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 262144))
            tail = f.read().decode("utf-8", "replace").splitlines()[1:]
    except OSError:
        return "0/0"
    cut = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - window))
    rows = [l.split("\t") for l in tail if l[:20] >= cut]
    return "%d/%d" % (sum(1 for r in rows if len(r) > 2 and r[2] == "hit"), len(rows))


def box_line(held, app_cores):
    la = rd("/proc/loadavg").split()
    psi = re.search(r"^some avg10=\S+ avg60=(\S+) avg300=(\S+)", rd("/proc/pressure/cpu"), re.M)
    bl = builds_in(arg("--builds", BUILDS), time.time() - 3600)
    mi = dict((l.split(":")[0], int(l.split()[1])) for l in rd("/proc/meminfo").splitlines() if len(l.split()) >= 2 and l.split()[1].isdigit())
    st = os.statvfs("/tmp")
    tmp_pct = 100.0 * (1 - st.f_bavail / st.f_blocks) if st.f_blocks else 0.0
    busy = 0.0
    try:
        s1 = rd("/proc/stat").split("\n")[0].split()[1:]
        time.sleep(0.5)
        s2 = rd("/proc/stat").split("\n")[0].split()[1:]
        d = [int(y) - int(x) for x, y in zip(s1, s2)]
        busy = (sum(d) - d[3] - d[4]) / max(1, sum(d)) * (os.cpu_count() or 1)
    except Exception:
        pass
    slice_held = "1" if os.path.exists("/tmp/s4e-quiet-slice.lock") and subprocess.run(["flock", "-n", "/tmp/s4e-quiet-slice.lock", "true"]).returncode != 0 else "0"
    v = {"cores_busy": "%.1f" % busy, "load1": la[0] if la else "0", "pressure_some_avg60": psi.group(1) if psi else "0", "pressure_some_avg300": psi.group(2) if psi else "0",
         "mem_available_mb": str(mi.get("MemAvailable", 0) // 1024), "swap_used_mb": str((mi.get("SwapTotal", 0) - mi.get("SwapFree", 0)) // 1024),
         "tmp_pct": "%.0f" % tmp_pct, "cc_held": str(sum(held["cc"].values())), "run_held": str(sum(held["run"].values())), "slice_held": slice_held,
         "builds_fetched": str(bl.get("FETCHED", 0)), "compiles": str(bl.get("BUILT", 0)), "checks_hit": "-", "oracle_hit": oracle_hits(300)}
    return v


def run(do_append, do_print):
    root = arg("--root", CG)
    if not os.path.isdir(root):
        print("REFUSED(2): no cgroup tree at %s" % root)
        return 2
    acc, unmapped, live, app_cores = sample(root, arg("--seats", SEATS))
    held = slot_holders(root)
    seats = sorted({n for (c, n) in acc if c == "SEAT"})
    tmp = tmp_sizes(seats)
    utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    lines = []
    for (cls, name), e in sorted(acc.items(), key=lambda kv: (kv[0][0] != "SEAT", -kv[1][0])):
        lines.append([utc, "UNIT", cls, name, "%.2f" % e[0], str(e[1]), str(e[2]), str(e[3]), str(e[4]),
                      str(held["cc"].get(name, 0)), str(held["run"].get(name, 0)), str(tmp.get(name, 0)) if cls == "SEAT" else "-"])
    cls_sum = {}
    for (cls, name), e in acc.items():
        cls_sum[cls] = cls_sum.get(cls, 0.0) + e[0]
    for cls in sorted(cls_sum):
        lines.append([utc, "CLASS", cls, cls.lower(), "%.2f" % cls_sum[cls], "-", "-", "-", "-", "-", "-", "-"])
    lines.append([utc, "APP", "APP", "app.slice", "%.2f" % app_cores, "-", "-", "-", "-", "-", "-", "-"])
    for u in unmapped:
        lines.append([utc, "UNMAPPED", "LON", u.rsplit("/", 1)[-1], "-", "-", "-", "-", "-", "-", "-", "-"])
    box = box_line(held, app_cores)
    lines.append([utc, "BOX", "BOX", "box", " ".join("%s=%s" % (k, box[k]) for k in BOXCOLS), "-", "-", "-", "-", "-", "-", "-"])
    try:
        lp, _ = lap_lines(3600)
        if lp:
            lines.append([utc, "LAP", "LAP", "lap", lp[0][4:], "-", "-", "-", "-", "-", "-", "-"])
    except Exception:
        pass
    if do_append:
        path = arg("--load", LOAD)
        new = not os.path.exists(path) or os.path.getsize(path) == 0
        with open(path, "a") as f:
            if new:
                f.write("\t".join(COLS) + "\n")
            for l in lines:
                f.write("\t".join(l) + "\n")
    if do_print:
        for l in lines:
            print("%-8s %-6s %-14s %6s cores %6s MB peak %6s oom %s pids %s cc %s run %s tmp %s" % tuple(l[1:]) if l[1] not in ("BOX", "LAP") else "%s %s" % (l[1], l[4]))
    return 0


def utc_s(s):
    """Seconds since the epoch of a ledger stamp, 2026-11-01T11:35:29 with or without the Z."""
    return __import__("calendar").timegm(time.strptime(s[:19], "%Y-%m-%dT%H:%M:%S"))


def runs_in(path, since):
    """The LOAD.tsv runs (each a list of rows sharing one stamp) at or after `since`, oldest first."""
    by = {}
    for l in rd(path).splitlines():
        if not l or l.startswith("utc"):
            continue
        r = l.split("\t")
        try:
            if utc_s(r[0]) >= since:
                by.setdefault(r[0], []).append(r)
        except ValueError:
            continue
    return [by[k] for k in sorted(by)]


def box_of(run):
    return dict(kv.split("=", 1) for r in run if r[1] == "BOX" for kv in r[4].split() if "=" in kv)


def builds_in(path, since):
    """BUILDS.tsv events at or after `since`: {event: count} (FETCHED, BUILT, PUBLISHED, MISS, DIRTY, INPLACE, OFF, NO-CACHE-DIR)."""
    n = {}
    for l in rd(path).splitlines():
        r = l.split("\t")
        if len(r) >= 3 and not l.startswith("#"):
            try:
                if utc_s(r[0]) >= since:
                    n[r[2]] = n.get(r[2], 0) + 1
            except ValueError:
                continue
    return n


def grader_rate(window):
    """Step 5's DONE-WHEN: the grader read 200 programs per hour or more (distinct suite and program among results.tsv's rr=1 rows) over the
    window while the box was busy (the ledger's BOX cores_busy mean at 12 or more); rc 2 when the box was not busy, because the rate under no
    contention measures nothing."""
    now = time.time(); since = now - window
    progs = set()
    for l in rd(arg("--results", RESULTS)).splitlines():
        r = l.split("\t")
        if len(r) >= 14 and "rr=1" in r[13] and not l.startswith("ts_utc"):
            try:
                if utc_s(r[0]) >= since:
                    progs.add((r[5], r[7]))
            except ValueError:
                continue
    runs = runs_in(arg("--load", LOAD), since)
    if not runs:
        print("REFUSED(2): no ledger run in the last %d s (%s)" % (window, arg("--load", LOAD)))
        return 2
    busy = [float(box_of(r).get("cores_busy", 0)) for r in runs]; bm = sum(busy) / len(busy)
    gr = [float(x[4]) for r in runs for x in r if x[1] == "CLASS" and x[2] == "GRADER"]; gm = sum(gr) / len(gr) if gr else 0.0
    rate = len(progs) / (window / 3600.0)
    print("GRADER RATE window=%ds programs=%d per_hour=%.0f busy_mean=%.1f grader_cores_mean=%.2f runs=%d" % (window, len(progs), rate, bm, gm, len(runs)))
    if bm < 12:
        print("REFUSED(2): the box was not busy (cores_busy mean %.1f of %d, under 12): the grader's rate under contention cannot be read" % (bm, os.cpu_count() or 16))
        return 2
    if rate < 200:
        print("  RED  the grader read %d programs in %.1f h (%.0f per hour, under 200) while the box was busy at %.1f cores" % (len(progs), window / 3600.0, rate, bm))
        return 1
    print("  GREEN the grader read %.0f programs per hour while the box was busy at %.1f cores (grader %.2f cores)" % (rate, bm, gm))
    return 0


def acceptance(window):
    """Step 9's DONE-WHEN over the window (a working day): the runs with cores_busy at 12 or more are the busy runs (fewer than twelve of them,
    an hour, is REFUSED); over them the grader's mean is 2.0 cores or more; no seat's ten-minute mean is above 4.0 while another seat waited for
    a slot in that ten minutes (SLOT_WAITS.tsv); cpu pressure some avg300 mean under 30; builds FETCHED at least ten times the BUILT; landings
    (commits on origin/main of SCRIP, harness, corpus and .github beside this harness) at 10 per hour or more."""
    now = time.time(); since = now - window
    runs = runs_in(arg("--load", LOAD), since)
    busy_runs = [r for r in runs if float(box_of(r).get("cores_busy", 0)) >= 12]
    print("ACCEPTANCE window=%ds runs=%d busy_runs=%d" % (window, len(runs), len(busy_runs)))
    if len(busy_runs) < 12:
        print("REFUSED(2): %d busy run(s) of %d (cores_busy at 12 or more; twelve, an hour, are the least): the fleet was not working for long enough to read" % (len(busy_runs), len(runs)))
        return 2
    gaps = []
    gr = [float(x[4]) for r in busy_runs for x in r if x[1] == "CLASS" and x[2] == "GRADER"]; gm = sum(gr) / len(gr) if gr else 0.0
    (gaps if gm < 2.0 else []).append("the grader's mean over the busy runs is %.2f cores (under 2.0)" % gm)
    ps = [float(box_of(r).get("pressure_some_avg300", box_of(r).get("pressure_some_avg60", 0))) for r in busy_runs]; pm = sum(ps) / len(ps)
    (gaps if pm >= 30 else []).append("cpu pressure some avg300 mean over the busy runs is %.1f (30 or more)" % pm)
    waits = {}
    for l in rd(arg("--waits", WAITS)).splitlines():
        r = l.split("\t")
        if len(r) >= 4 and not l.startswith("#"):
            try:
                ts = utc_s(r[0])
            except ValueError:
                continue
            if ts >= since:
                waits.setdefault(int(ts // 600), []).append((r[1], r[3]))
    buckets = {}
    for r in busy_runs:
        b = int(utc_s(r[0][0]) // 600)
        for x in r:
            if x[1] == "UNIT" and x[2] == "SEAT":
                buckets.setdefault(b, {}).setdefault(x[3], []).append(float(x[4]))
    hogs = []
    for b, seats in sorted(buckets.items()):
        for s, v in seats.items():
            mean = sum(v) / len(v)
            others = [(w, sec) for (w, sec) in waits.get(b, []) if w != s]
            if mean > 4.0 and others:
                hogs.append("%s held %.1f cores over the ten minutes from %s while %s waited %s s for a slot" % (s, mean, time.strftime("%H:%MZ", time.gmtime(b * 600)), others[0][0], others[0][1]))
    gaps += hogs[:3]
    bl = builds_in(arg("--builds", BUILDS), since); fetched, built = bl.get("FETCHED", 0), bl.get("BUILT", 0)
    if fetched + built == 0:
        gaps.append("no build in the window (BUILDS.tsv has no FETCHED or BUILT)")
    elif fetched < 10 * built:
        gaps.append("builds FETCHED %d against BUILT %d (under ten to one)" % (fetched, built))
    repos = arg("--repos", os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    landings = 0; seen = 0
    for name in ("SCRIP", "harness", "corpus", ".github"):
        d = os.path.join(repos, name)
        if os.path.isdir(os.path.join(d, ".git")) or os.path.isfile(os.path.join(d, ".git")):
            seen += 1
            r = subprocess.run(["git", "-C", d, "log", "--since=%d" % int(since), "--format=%H", "origin/main"], capture_output=True, text=True)
            landings += len([l for l in r.stdout.splitlines() if l])
    lph = landings / (window / 3600.0)
    if seen == 0:
        gaps.append("no repo beside this harness to count landings in (%s)" % repos)
    elif lph < 10:
        gaps.append("landings on origin/main: %d in %.1f h (%.1f per hour, under 10)" % (landings, window / 3600.0, lph))
    print("  grader_mean=%.2f pressure_mean=%.1f hogs=%d fetched=%d built=%d landings=%d (%.1f/h)" % (gm, pm, len(hogs), fetched, built, landings, lph))
    for g in gaps:
        print("  RED  " + g)
    if gaps:
        return 1
    print("  GREEN over %d busy runs the grader held %.2f cores, no seat hogged while another waited, pressure %.1f, builds fetched %d to built %d, %.1f landings an hour" % (len(busy_runs), gm, pm, fetched, built, lph))
    return 0


def newest_run(path):
    rows = [l.split("\t") for l in rd(path).splitlines() if l and not l.startswith("utc")]
    if not rows:
        return None, []
    last = rows[-1][0]
    return last, [r for r in rows if r[0] == last]


def lap_population(loop_dir, cache_path, max_age=3600):
    """The live population by util_round_robin_freshness.py's own rule (never a second copy), each member's (db_suite, total) cached for an hour."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import util_round_robin_freshness as rrf
    now = time.time(); cache = {}
    for line in rd(cache_path).splitlines():
        f = line.split("\t")
        if len(f) == 4 and not line.startswith("#"):
            try:
                cache[f[0]] = (float(f[1]), None if f[2] == "-" else f[2], None if f[3] == "-" else int(f[3]))
            except ValueError:
                continue
    def popfn(key):
        if key in cache and now - cache[key][0] < max_age:
            return cache[key][1], cache[key][2]
        dbs, tot = rrf.population(key)
        cache[key] = (now, dbs, tot)
        return dbs, tot
    try:
        live, idle_n, held_n, unread = rrf.live_members(loop_dir, popfn)
    except SystemExit:
        return rrf, None, []
    try:
        with open(cache_path + ".tmp", "w") as f:
            f.write("# key\tat\tdb_suite\ttotal  -- util_seat_census.py --lap's population cache (util_score_row.py from-progress --dry-run, an hour)\n")
            for k, (t, d, n) in sorted(cache.items()):
                f.write("%s\t%.0f\t%s\t%s\n" % (k, t, d or "-", "-" if n is None else n))
        os.replace(cache_path + ".tmp", cache_path)
    except OSError:
        pass
    return rrf, live, unread


def lap_lines(window):
    """box-budget step 1: [LAP, LAP_SLICES, LAP_SEATS, LAP_WAITS] lines, or (None, reason) when it cannot measure."""
    db = arg("--results", RESULTS)
    if not os.path.exists(db):
        return None, "no results.tsv at %s" % db
    rrf, live, unread = lap_population(arg("--loop-dir", LOOPDIR), arg("--pop-cache", LAPPOP))
    if not live:
        return None, "no live rotation member resolved to a table (loop dir %s)" % arg("--loop-dir", LOOPDIR)
    now = time.time()
    fresh, outside = rrf.fresh_of(db, time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now - FRESH_H * 3600)), live)
    tests = sum(live.values()); nfresh = sum(min(len(fresh.get(k, ())), n) for k, n in live.items())
    cut = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now - window)); rows = 0; progs = set()
    with open(db, encoding="utf-8", errors="replace") as fh:
        fh.readline()
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if len(f) >= 14 and f[0] >= cut and f[3] == "coo" and (rrf.TAG_RR.search(f[13]) or rrf.TAG_REQ.search(f[13])):
                rows += 1; progs.add((f[5], rrf.stem(f[7])))
    rph = rows / (window / 3600.0); rpt = rows / len(progs) if progs else 2.0; stale = tests - nfresh
    if rph > 0:
        h = stale * rpt / rph
        eta = "+%.1fh(%s)" % (h, time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime(now + h * 3600))); laph = "%.1f" % (tests * rpt / rph)
    else:
        eta, laph = "never", "never"
    out = ["LAP window=%ds rows_per_hour=%.0f programs=%d rows_per_test=%.2f fresh=%d/%d (%.0f%%) fresh_window=%dh stale=%d eta=%s lap_h=%s outside=%d unresolved=%d"
           % (window, rph, len(progs), rpt, nfresh, tests, 100.0 * nfresh / tests, FRESH_H, stale, eta, laph, outside, len(unread))]
    runs = runs_in(arg("--load", LOAD), now - window); cls, seat = {}, {}
    for r in runs:
        for x in r:
            try:
                if x[1] == "CLASS":
                    cls[x[2]] = cls.get(x[2], 0.0) + float(x[4])
                elif x[1] == "UNIT" and x[2] == "SEAT":
                    seat[x[3]] = seat.get(x[3], 0.0) + float(x[4])
            except (ValueError, IndexError):
                continue
    n = max(1, len(runs)); tot = sum(cls.values()) / n
    out.append("LAP_SLICES window=%ds runs=%d cores=%.2f " % (window, len(runs), tot) + " ".join("%s=%.2fc(%.0f%%)" % (k, v / n, 100.0 * v / n / tot if tot else 0.0) for k, v in sorted(cls.items(), key=lambda kv: -kv[1])))
    out.append("LAP_SEATS window=%ds " % window + (" ".join("%s=%.2fc" % (k, v / n) for k, v in sorted(seat.items(), key=lambda kv: -kv[1])) or "none"))
    w = {"cc": [0, 0.0, 0.0], "run": [0, 0.0, 0.0]}; ws = {}
    for l in rd(arg("--waits", WAITS)).splitlines():
        r = l.split("\t")
        if len(r) < 4 or l.startswith("#"):
            continue
        try:
            if utc_s(r[0]) < now - window:
                continue
            sec = float(r[3])
        except ValueError:
            continue
        e = w.setdefault(r[2], [0, 0.0, 0.0]); e[0] += 1; e[1] += sec; e[2] = max(e[2], sec); ws[r[1]] = ws.get(r[1], 0.0) + sec
    out.append("LAP_WAITS window=%ds " % window + " ".join("%s=%d/%.0fs/max%.0fs" % (k, e[0], e[1], e[2]) for k, e in sorted(w.items()))
               + " by_seat=" + (",".join("%s:%.0fs" % kv for kv in sorted(ws.items(), key=lambda kv: -kv[1])) or "none"))
    return out, None


def admission_check(window):
    """box-budget step 5 (CTO-478): admission by the pools bounds every wait. Over the last window seconds: no slot wait over ADMISSION_WAIT_DAY_S
    by day (06-22 local), never more than ADMISSION_CC_BAR compilers box-wide (the cc slots held per tick), and heavy runs through the pools
    (a SEAT tick over 2 cores holding no slot is outside; the bar is 1 percent of seat ticks). rc 0 GREEN, 1 RED naming each bar, 2 no ledger."""
    now = time.time(); waits = rd(arg("--waits", WAITS))
    if not waits.strip():
        print("REFUSED(2): no slot-wait ledger at %s" % arg("--waits", WAITS)); return 2
    n = 0; mx = 0.0; mxat = ""; over_day = []; over_night = 0; refused = 0
    for l in waits.splitlines():
        r = l.split("\t")
        if len(r) < 4 or l.startswith("#"):
            continue
        try:
            at = utc_s(r[0]); sec = float(r[3])
        except ValueError:
            continue
        if at < now - window:
            continue
        if r[2].endswith("-refused"):
            refused += 1; continue
        n += 1
        if sec > mx:
            mx, mxat = sec, "%s/%s/%s" % (r[0], r[1], r[2])
        if sec > ADMISSION_WAIT_DAY_S:
            if 6 <= time.localtime(at).tm_hour < 22:
                over_day.append("%s:%s:%s:%.0fs" % (r[0][11:16], r[1], r[2], sec))
            else:
                over_night += 1
    runs = runs_in(arg("--load", LOAD), now - window); cc_max = 0; cc_at = ""; seat_ticks = 0; outside = 0; outside_who = {}
    for r in runs:
        cc = 0
        for x in r:
            try:
                if x[1] == "UNIT" and x[2] == "SEAT":
                    seat_ticks += 1; cc += int(x[9]); held = int(x[9]) + int(x[10])
                    if float(x[4]) > 2.0 and held == 0:
                        outside += 1; outside_who[x[3]] = outside_who.get(x[3], 0) + 1
            except (ValueError, IndexError):
                continue
        if cc > cc_max:
            cc_max, cc_at = cc, (r[0][0] if r and r[0] else "")
    out_bar = max(1, seat_ticks // 100); why = []
    if over_day:
        why.append("%d wait(s) over %ds by day (%s)" % (len(over_day), ADMISSION_WAIT_DAY_S, " ".join(over_day[:5])))
    if cc_max > ADMISSION_CC_BAR:
        why.append("%d compilers box-wide at %s (bar %d)" % (cc_max, cc_at, ADMISSION_CC_BAR))
    if outside > out_bar:
        why.append("%d seat ticks over 2 cores holding no slot (bar %d of %d): %s" % (outside, out_bar, seat_ticks, ",".join("%s:%d" % kv for kv in sorted(outside_who.items(), key=lambda kv: -kv[1])[:5])))
    print("ADMISSION window_s=%d waits=%d refused_at_bound=%d max_wait_s=%.0f at=%s over_%ds_day=%d over_%ds_night=%d compilers_max=%d compilers_bar=%d outside_pool_ticks=%d/%d bar=%d verdict=%s%s"
          % (window, n, refused, mx, mxat or "-", ADMISSION_WAIT_DAY_S, len(over_day), ADMISSION_WAIT_DAY_S, over_night, cc_max, ADMISSION_CC_BAR, outside, seat_ticks, out_bar,
             "GREEN" if not why else "RED", "" if not why else " :: " + "; ".join(why)))
    return 0 if not why else 1


def lap(window):
    out, why = lap_lines(window)
    if out is None:
        print("REFUSED(2): " + why)
        return 2
    print("\n".join(out))
    return 0


def budget_path():
    return arg("--budget", os.environ.get("S4E_BUDGET") or BUDGET)


def budget_rows(path=None):
    """The declared budget table: one dict per row (name, unit, the six systemd knobs, applied_by, ruling); '-' is a knob the row does not declare."""
    out = []
    for line in rd(path or budget_path()).splitlines():
        f = line.split("\t")
        if not line.strip() or line.startswith("#") or f[0] == "name" or len(f) < 8:
            continue
        r = {"name": f[0], "unit": f[1]}
        for i, (k, _) in enumerate(BUDGET_KNOBS):
            r[k] = f[2 + i].strip()
        r["applied_by"] = f[8] if len(f) > 8 else "-"; r["ruling"] = f[9] if len(f) > 9 else "-"
        out.append(r)
    return out


def budget_row(name, path=None):
    return next((r for r in budget_rows(path) if name in (r["name"], r["unit"])), None)


def budget_props(row):
    """The systemd properties a row declares, as set-property and systemd-run -p take them."""
    return ["%s=%s" % (k, row[k]) for k, _ in BUDGET_KNOBS if row and row.get(k, "-") not in ("-", "")]


def budget_knob_gap(r, k, got):
    """'' when the live file value meets row r's knob k; else the reason. A CPUQuota the controller moves (box-scheduler step 26) is a ceiling."""
    want = budget_file_value(k, r[k])
    if k == "CPUQuota" and "box_controller" in r.get("applied_by", ""):
        gn, wn = got.split()[0] if got else "", want.split()[0]
        if not gn.isdigit() or int(gn) > int(wn):
            return "reads %s, above the declared CEILING %s=%s (%s); box_controller.sh moves this knob under it (box-scheduler step 26)" % (got or "absent", k, r[k], want)
        return ""
    return "" if got == want else "reads %s, the table declares %s=%s (%s)" % (got or "absent", k, r[k], want)
def budget_file_value(knob, v):
    """The cgroup file's text for a declared systemd value: 400% -> '400000 100000', 4G -> bytes, infinity -> max."""
    v = v.strip()
    if v in ("infinity", "max"):
        return "max 100000" if knob == "CPUQuota" else "max"
    if knob == "CPUQuota":
        return "%d 100000" % round(float(v.rstrip("%")) * 1000)
    if knob in ("MemoryHigh", "MemoryMax", "MemorySwapMax"):
        m = re.fullmatch(r"(\d+)([KMGT]?)", v)
        return str(int(m.group(1)) * 1024 ** " KMGT".index(m.group(2) or " ")) if m else v
    return v


def slice_path(unit):
    """A user slice's cgroup path under user@1000.service: systemd nests a slice by the dashes of its name (s4e-grader.slice -> s4e.slice/s4e-grader.slice)."""
    parts = unit[:-len(".slice")].split("-")
    return "/".join("-".join(parts[:i + 1]) + ".slice" for i in range(len(parts)))


def budget_check():
    path = budget_path(); rows = budget_rows(path)
    if not rows:
        print("REFUSED(2): no budget table, or no row in it, at %s" % path)
        return 2
    root = arg("--root", CG)
    if not os.path.isdir(root):
        print("REFUSED(2): no cgroup tree at %s" % root)
        return 2
    live = seat_map(arg("--seats", SEATS))
    gaps, units, knobs = [], 0, 0
    for r in rows:
        if r["unit"].startswith("@"):
            targets = [("%s %s" % (r["unit"][1:].lower(), who), os.path.join(root, sc)) for who, (cls, sc) in sorted(live.items()) if cls == r["unit"][1:] and os.path.isdir(os.path.join(root, sc))]
        else:
            d = os.path.join(root, "user@1000.service", slice_path(r["unit"]))
            if not os.path.isdir(d):
                gaps.append("%s (%s): absent, no cgroup at %s" % (r["name"], r["unit"], d)); continue
            targets = [(r["unit"], d)]
        for who, d in targets:
            units += 1
            for k, f in BUDGET_KNOBS:
                if r[k] in ("-", ""):
                    continue
                knobs += 1; got = rd(os.path.join(d, f)).strip()
                bad = budget_knob_gap(r, k, got)
                if bad:
                    gaps.append("%s: %s %s" % (who, f, bad))
    print("BUDGET CHECK table=%s rows=%d units=%d knobs=%d gaps=%d" % (path, len(rows), units, knobs, len(gaps)))
    if gaps:
        for g in gaps[:20]:
            print("  RED  " + g)
        return 1
    print("  GREEN every declared knob of the %d rows reads its declared value on the %d live units" % (len(rows), units))
    return 0


def budget_print_props(name):
    if name:
        r = budget_row(name)
        if r is None:
            print("REFUSED(2): no row %s in %s" % (name, budget_path()))
            return 2
        print(" ".join(budget_props(r)))
        return 0
    rows = [r for r in budget_rows() if r["unit"].endswith(".slice")]
    if not rows:
        print("REFUSED(2): no slice row in %s" % budget_path())
        return 2
    for r in rows:
        print(" ".join([r["unit"]] + budget_props(r)))
    return 0


TMP_SEAT_MB = 4096   # ARCH-SHARED-DEVELOPMENT 2.3, /tmp move (2): a seat over 4 GB of /tmp is named; the banner shows each seat its own figure against it (the coo 2026-11-01, R-2095)


def banner(seat):
    last, rows = newest_run(arg("--load", LOAD))
    if not last:
        print("LOAD no ledger yet (util_seat_census.py run)")
        return 0
    box = dict(kv.split("=", 1) for r in rows if r[1] == "BOX" for kv in r[4].split())
    units = [r for r in rows if r[1] == "UNIT"]
    me = next((r for r in units if r[2] == "SEAT" and r[3] == seat), None)
    gr = next((r for r in rows if r[1] == "CLASS" and r[2] == "GRADER"), None)
    ba = next((r for r in rows if r[1] == "CLASS" and r[2] == "BATCH"), None)
    top = max((r for r in units if r[2] == "SEAT"), key=lambda r: float(r[4]), default=None)
    tmb = int(me[11]) if me and me[11].isdigit() else 0
    you = ("you %.1f cores %.1fG tmp %.1fG/%dG%s cc %s run %s" % (float(me[4]), int(me[5]) / 1024, tmb / 1024, TMP_SEAT_MB // 1024, " OVER" if tmb > TMP_SEAT_MB else "", me[9], me[10])) if me else "you -"
    print("BOX busy %s/%d pressure %s | %s | grader %s | batch %s | top %s %s  (%s)" % (box.get("cores_busy", "?"), os.cpu_count() or 16,
          box.get("pressure_some_avg60", "?"), you, gr[4] if gr else "0", ba[4] if ba else "0", top[3] if top else "-", top[4] if top else "", last))
    return 0


def check():
    path = arg("--load", LOAD)
    last, rows = newest_run(path)
    if not last:
        print("REFUSED(2): no ledger at %s" % path)
        return 2
    gaps = []
    age = time.time() - __import__("calendar").timegm(time.strptime(last, "%Y-%m-%dT%H:%M:%SZ"))
    if age > 600:
        gaps.append("the newest run is %d s old (over ten minutes)" % age)
    root = arg("--root", CG)
    live = seat_map(arg("--seats", SEATS))
    want = sorted(s for s, (cls, sc) in live.items() if cls == "SEAT" and os.path.isdir(os.path.join(root, sc)))
    have = {r[3] for r in rows if r[1] == "UNIT" and r[2] == "SEAT"}
    miss = [s for s in want if s not in have]
    if miss:
        gaps.append("live seats with no SEAT line: " + " ".join(miss))
    unm = [r[3] for r in rows if r[1] == "UNMAPPED"]
    if unm:
        gaps.append("live session scopes SEATS.tsv does not map: " + " ".join(unm))
    app = next((float(r[4]) for r in rows if r[1] == "APP"), None)
    board_and_desk = sum(float(r[4]) for r in rows if r[1] == "UNIT" and r[2] in ("SEAT", "LON"))
    if app is not None and app > 0.5 and abs(board_and_desk - app) > 0.10 * app:
        gaps.append("the SEAT and LON lines sum to %.2f cores where app.slice's own delta read %.2f (over ten percent apart)" % (board_and_desk, app))
    print("SEAT CENSUS run=%s age=%ds seats=%d/%d app=%s seat_and_lon=%.2f" % (last, age, len(want) - len(miss), len(want), "%.2f" % app if app is not None else "-", board_and_desk))
    if gaps:
        for g in gaps:
            print("  RED  " + g)
        return 1
    print("  GREEN the ledger is fresh, every live seat has its line, and the lines sum to app.slice's delta within ten percent")
    return 0


def mem_split(d):
    """(memory.current, memory.high or 0, anon, file) of a cgroup in bytes: memory.current counts page cache, so anon is the scope's own memory."""
    st = {}
    for l in rd(os.path.join(d, "memory.stat")).splitlines():
        k, _, v = l.partition(" ")
        if k in ("anon", "file") and v.strip().isdigit():
            st[k] = int(v)
    hi = rd(os.path.join(d, "memory.high")).strip()
    return num(d, "memory.current"), int(hi) if hi.isdigit() else 0, st.get("anon", 0), st.get("file", 0)


def reclaim_file(d, nbytes):
    """Ask the kernel to drop nbytes of the scope's file pages (memory.reclaim swappiness=0: no anon page is swapped); 'ok', 'partial' or why not."""
    try:
        with open(os.path.join(d, "memory.reclaim"), "w") as f:
            f.write("%d swappiness=0" % nbytes)
        return "ok"
    except OSError as e:
        return "partial" if e.errno == 11 else "refused (%s)" % (e.strerror or e)


def memory_check():
    """Step 8's DONE-WHEN (ARCH-SHARED-DEVELOPMENT 6): every live seat scope's memory.max set and below the box, the three slices capped, TMPDIR per seat
    in force (MEASURED 2026-10-31: Claude Code passes the settings env block's S4E_SEAT and MAKEFLAGS to its shells but drops its TMPDIR, so the per-seat
    TMPDIR is placed by the runners from S4E_SEAT: each live session carries S4E_SEAT and both runners export it), /tmp under 60 percent, and no UNIT line of the ledger's last 24 hours carrying an oom_kill
    (memory.events counts over the scope's life, so a kill is named until its scope ends)."""
    root = arg("--root", CG)
    if not os.path.isdir(root):
        print("REFUSED(2): no cgroup tree at %s" % root)
        return 2
    box = 0
    for l in rd("/proc/meminfo").splitlines():
        if l.startswith("MemTotal:"):
            box = int(l.split()[1]) * 1024
    gaps, seen, split = [], 0, []
    for seat, (cls, sc) in sorted(seat_map(arg("--seats", SEATS)).items()):
        d = os.path.join(root, sc)
        if cls != "SEAT" or not os.path.isdir(d):
            continue
        seen += 1
        cur, hi, an, fl = mem_split(d)
        split.append("  seat %s scope cur=%dMB high=%sMB anon=%dMB file=%dMB" % (seat, cur // 1048576, hi // 1048576 if hi else "max", an // 1048576, fl // 1048576))
        mx = rd(os.path.join(d, "memory.max")).strip()
        if not mx.isdigit() or int(mx) >= box:
            gaps.append("seat %s: memory.max %s is not below the box" % (seat, mx or "?"))
        pids = [p for p in rd(os.path.join(d, "cgroup.procs")).split() if p.isdigit()]
        want = "S4E_SEAT=" + seat
        envs = []
        for p in pids:
            try:
                with open("/proc/%s/environ" % p, "rb") as f:
                    envs.append(f.read().decode("utf-8", "replace").split("\0"))
            except OSError:
                pass
        if len(envs) >= 2 and not any(want in e for e in envs):   # the session process never carries the settings env; only a shell child does, so one pid is no reading (the fleet test, 2026-11-01)
            gaps.append("seat %s: its session's shells run without %s, so its runners cannot place TMPDIR=/tmp/s4e/%s" % (seat, want, seat))
    svc = os.path.join(root, "user@1000.service")
    for nm, rel, knob in (("the sessions' slice", "app.slice/app-org.gnome.Terminal.slice", "memory.high"), ("s4e-batch.slice", "s4e.slice/s4e-batch.slice", "memory.max"),
                          ("s4e-grader.slice", "s4e.slice/s4e-grader.slice", "memory.max")):
        v = rd(os.path.join(svc, rel, knob)).strip()
        if not v.isdigit() or int(v) >= box:
            gaps.append("%s: %s %s is not a cap below the box" % (nm, knob, v or "absent"))
    here = os.path.dirname(os.path.abspath(__file__))
    for f, mark in (("lib_one_runner.sh", 'export TMPDIR="/tmp/s4e/$'), ("corpus_suite_harness.py", 'os.environ["TMPDIR"] = _st')):
        if mark not in rd(os.path.join(here, f)):
            gaps.append("%s does not place TMPDIR in /tmp/s4e/<seat>" % f)
    st = os.statvfs("/tmp")
    used = 100.0 * (st.f_blocks - st.f_bfree) / max(1, st.f_blocks - st.f_bfree + st.f_bavail)
    if used >= 60:
        gaps.append("/tmp is %.0f percent used (60 is the bound)" % used)
    cut = time.time() - 86400
    ooms = set()
    for l in rd(arg("--load", LOAD)).splitlines():
        r = l.split("\t")
        if len(r) > 7 and r[1] == "UNIT" and r[7].isdigit() and int(r[7]) > 0:
            try:
                if __import__("calendar").timegm(time.strptime(r[0], "%Y-%m-%dT%H:%M:%SZ")) >= cut:
                    ooms.add("%s/%s" % (r[2], r[3]))
            except ValueError:
                pass
    if ooms:
        gaps.append("oom_kill in the last 24 h: " + " ".join(sorted(ooms)))
    print("MEMORY CHECK seats=%d box=%d MB tmp=%.0f%% gaps=%d" % (seen, box // 1048576, used, len(gaps)))
    for l in split:
        print(l)
    if gaps:
        for g in gaps:
            print("  RED  " + g)
        return 1
    print("  GREEN every seat capped below the box, the three slices capped, TMPDIR per seat in force, /tmp under 60 percent, no oom_kill in 24 h")
    return 0


def cpu_check():
    """THE CPU ARM OF THE HEALTH CHECK (the coo 2026-11-01, Lon: "why did you not catch this when I asked you to do a health check? fix that health
    check"): the --check arm read GREEN (the ledger fresh) while the box ran 16 of 16 cores at cpu pressure 41 with the pools nearly empty, because no arm
    turned those numbers into a verdict. From the newest run: RED when cpu pressure some avg300 is 30 or more; when the box is busy (85 percent of its cores)
    while the run and cc pools together hold half their slots or fewer (the load runs outside the doors, where the load is the busy cores less the grader's own, which runs inside its own door); for every SEAT line over 2 cores holding no run
    slot and no cc slot (named: the seat to throttle); when the grader reads under 2 cores on a busy box (75 percent) AND its own slice waited 10 percent or more for a CPU (under 2 cores with no wait is its own small demand); and when Lon's terminal scope waited 10 percent or more. Each RED names what to act on."""
    last, rows = newest_run(arg("--load", LOAD))
    if not last:
        print("REFUSED(2): no ledger at %s" % arg("--load", LOAD))
        return 2
    n = os.cpu_count() or 16
    box = next((dict(kv.split("=", 1) for kv in r[4].split() if "=" in kv) for r in rows if r[1] == "BOX"), {})
    def f(k):
        try:
            return float(box.get(k, "0"))
        except ValueError:
            return 0.0
    busy, p300, held = f("cores_busy"), f("pressure_some_avg300"), f("run_held") + f("cc_held")
    pools = int(os.environ.get("S4E_RUN_SLOTS", "8")) + int(os.environ.get("S4E_CC_SLOTS", "8"))
    gaps = []
    if p300 >= 30:
        gaps.append("cpu pressure some avg300 %.1f (30 is the bar): tasks waited for a CPU %.0f percent of the last five minutes" % (p300, p300))
    gr = next((float(r[4]) for r in rows if r[1] == "CLASS" and r[2] == "GRADER"), None)
    outside = busy - (gr or 0.0)
    if outside >= 0.85 * n and held <= pools / 2:
        gaps.append("the box is busy (%.1f of %d cores, the grader %.1f of them inside its own door) and %.1f cores run outside every door while the pools hold %d of %d slots: the load runs OUTSIDE the doors" % (busy, n, gr or 0.0, outside, held, pools))
    for r in rows:
        if r[1] == "UNIT" and r[2] == "SEAT" and len(r) > 10:
            try:
                c, cc, rn = float(r[4]), int(r[9] or 0), int(r[10] or 0)
            except ValueError:
                continue
            if c > 2.0 and cc == 0 and rn == 0:
                gaps.append("seat %s runs %.2f cores holding no run slot and no cc slot: throttle it (nice, -j2, the pools) or cap its scope" % (r[3], c))
    root = arg("--root", CG)
    def wait300(path):
        for l in rd(path).splitlines():
            if l.startswith("some "):
                for kv in l.split()[1:]:
                    if kv.startswith("avg300="):
                        try:
                            return float(kv[7:])
                        except ValueError:
                            return None
        return None
    gw = wait300(os.path.join(root, "user@1000.service", "s4e.slice", "s4e-grader.slice", "cpu.pressure"))   # MEASURED 2026-11-01 14:2x: the grader slice waited 0.2 percent while the sessions' slice waited 8.5 -- under 2 cores was the grader's own small demand, not starvation, so cores alone are no verdict
    if gr is not None and busy >= 0.75 * n and gr < 2.0 and gw is not None and gw >= 10:
        gaps.append("the grader reads %.2f cores and waited for a CPU %.1f percent of the last five minutes (10 is the bar): the suites starve behind the seats" % (gr, gw))
    for who, (cls, sc) in sorted(seat_map(arg("--seats", SEATS)).items()):
        lw = wait300(os.path.join(root, sc, "cpu.pressure")) if cls == "LON" else None
        if lw is not None and lw >= 10:
            gaps.append("Lon's terminal (%s) waited for a CPU %.1f percent of the last five minutes (10 is the bar): the seats crowd Lon's own session" % (who, lw))
    print("CPU CHECK run=%s busy=%.1f/%d pressure_avg300=%.1f slots_held=%d/%d grader=%s grader_wait=%s gaps=%d" % (last, busy, n, p300, held, pools, "%.2f" % gr if gr is not None else "-", "%.1f" % gw if gw is not None else "-", len(gaps)))
    if gaps:
        for g in gaps:
            print("  RED  " + g)
        return 1
    print("  GREEN cpu pressure under 30, the busy box's load inside the pools, no seat over 2 cores outside them, the grader at its floor")
    return 0


def tmp_check():
    """THE /tmp ARM OF THE HEALTH CHECK (the coo 2026-11-01, Lon: "how big is /tmp folder? why would it fill up?"): --memory-check reds /tmp past 60
    percent but names nobody, so the coo had to du the tree by hand to find the cto's live scratchpad at 19.5 GB. From the newest LOAD run (the tmp_mb
    column, one du per seat of its Claude session scratchpads and /tmp/s4e/<seat>): RED by name, largest first, for every seat over TMP_SEAT_MB -- the
    seat to ask to delete its finished outputs, since the sweeper cannot take a live session's files."""
    last, rows = newest_run(arg("--load", LOAD))
    if not last:
        print("REFUSED(2): no ledger at %s" % arg("--load", LOAD))
        return 2
    seats = []
    for r in rows:
        if r[1] == "UNIT" and r[2] == "SEAT" and len(r) > 11:
            try:
                seats.append((int(float(r[11] or 0)), r[3]))
            except ValueError:
                pass
    over = sorted((mb, s) for mb, s in seats if mb > TMP_SEAT_MB)[::-1]
    tot = sum(mb for mb, _ in seats)
    print("TMP CHECK run=%s seats=%d seat_tmp_total=%.1fG budget=%dG each over=%d" % (last, len(seats), tot / 1024.0, TMP_SEAT_MB // 1024, len(over)))
    if over:
        for mb, s in over:
            print("  RED  seat %s holds %.1fG of /tmp (its budget is %dG): ask it to delete its finished outputs; a live session's files are its own" % (s, mb / 1024.0, TMP_SEAT_MB // 1024))
        return 1
    print("  GREEN every seat's /tmp (session scratchpads and /tmp/s4e/<seat>) is within its %dG budget" % (TMP_SEAT_MB // 1024))
    return 0


def proc_check():
    """THE PROCESS AND MEMORY ARM OF THE HEALTH CHECK (the coo 2026-11-01, Lon: "So does you periodic check look for orphans and such so it can find this
    problem sooner rather than later?" -- it did not: at 14:4x CST three XSB smoke trees orphaned by timed-out assign probes ran on reparented to the user
    manager, one `as` at 1.5 GB, the coo's scope sat at 3.3 of its 4 GB memory.high, and box memory pressure read 37 percent with no arm red). RED by name:
    every fleet process (a harness script, a scrip, as, gcc, make, a runner), and any process at all in a live seat's session scope (COO-461: the cao's orphaned
    ugrep over the whole corpus ran 15 min at 1.76 cores unnamed, its command no fleet word), whose parent is the user manager and that is five minutes old or more, not one of
    the standing daemons (the loop, tier1, the seat watch, a swap, the cron census, sweep and git maintenance) -- its seat read from the cgroup it kept;
    box memory pressure some avg60 of 10 or more; and every seat scope at 90 percent or more of its memory.high (the scope the kernel is throttling)."""
    root = arg("--root", CG)
    live = seat_map(arg("--seats", SEATS))
    by_scope = {os.path.basename(sc): who for who, (cls, sc) in live.items()}
    gaps = []
    psf = arg("--ps", "")
    if psf:
        txt = rd(psf)
    else:
        txt = subprocess.run(["ps", "-eo", "pid=,ppid=,etimes=,rss=,cgroup:400=,args="], capture_output=True, text=True).stdout
    rows = []
    for l in txt.splitlines():
        f = l.split(None, 5)
        if len(f) == 6 and f[0].isdigit():
            rows.append(f)
    mgr = {r[0] for r in rows if r[5].startswith("/usr/lib/systemd/systemd --user")}
    work = re.compile(r"(/harness/scripts/|/SCRIP/scrip\b|/scrip --|\bas --64\b|^(\S*/)?gcc\b|^(\S*/)?make\b|corpus_suite_harness|^timeout )")
    keep = re.compile(r"(loop8\.sh|tier1\.sh|seatwatch\.sh|swap[A-Za-z0-9]*\.sh|util_seat_census\.py run|util_tmp_sweep\.sh|util_git_maintenance\.sh|^ssh: \S+ \[mux\]$|^xclip -selection |util_jobserver\.sh hold |util_queue\.py reserve-hold |util_queue\.py hold-job )")   # the lease holder of a reserved job (fleet-queue 5: next detaches it on purpose; killing it releases the job to its tube) is a standing daemon, never an orphan
    host = re.compile(r"^(\S*/)?(gnome-terminal-server|gnome-terminal|gnome-shell|systemd( --user)?|claude)( |$)")   # the coo 2026-11-06 09:02 (COO-478 morning): the session HOSTS are never named -- gnome-terminal-server hosts every fleet window (killing it closes thirty sessions), gnome-shell the desktop, the user systemd is the manager itself, a claude process is a seat's session; by executable path, never by pid
    orphans = []
    # a pid a live row names MEASURING:<seat>:<pid> is that seat's background measurement by handle (seat-conduct section 1: setsid, reparented BY DESIGN),
    # wanted until it exits (the coo 2026-11-08 08:0x: junior_01's lap watcher 1481355 was named an orphan while step 7 waited on it)
    measuring = set(re.findall(r"\tMEASURING:[^:\t]+:(\d+)[ \t]*$", rd(arg("--queue", "/home/resources/postoffice/QUEUE.tsv")), re.M))
    for pid, ppid, et, rss, cg, a in rows:
        sc = os.path.basename(cg.split("::")[-1].rstrip("/"))
        if pid in measuring:
            continue
        # the coo 2026-11-08 07:5x (Lon: "fix the two false reds in the census"): a process in a systemd unit's own .service cgroup is that unit's process,
        # its parent the user manager BY DESIGN (systemd units' main pids were once named orphans of seat grader); a real orphan keeps its .scope
        if ppid in mgr and int(et) >= 300 and not sc.endswith(".service") and (work.search(a) or sc in by_scope) and not keep.search(a) and not host.search(a):
            who = by_scope.get(sc) or ("grader" if "s4e-grader" in cg or "s4e-mem-" in cg else "batch" if "s4e-batch" in cg else "?")
            orphans.append((int(rss), pid, who, int(et), a))
    for rss, pid, who, et, a in sorted(orphans, reverse=True):
        gaps.append("orphan pid %s of seat %s, %d min old, %d MB, parent gone (reparented to the user manager): %s -- its seat kills it by pid" % (pid, who, et // 60, rss // 1024, a[:110]))
    mp = None
    for l in rd(arg("--pressure-memory", "/proc/pressure/memory")).splitlines():
        if l.startswith("some "):
            for kv in l.split()[1:]:
                if kv.startswith("avg60="):
                    try:
                        mp = float(kv[6:])
                    except ValueError:
                        pass
    if mp is not None and mp >= 10:
        gaps.append("box memory pressure some avg60 %.1f (10 is the bar): tasks stalled on memory %.0f percent of the last minute" % (mp, mp))
    term = os.path.join(root, "user@1000.service", "app.slice", "app-org.gnome.Terminal.slice")
    notes = []
    for d in sorted(glob.glob(os.path.join(term, "*.scope"))):
        cur, high, an, fl = mem_split(d)
        if high <= 0 or cur < 0.9 * high:
            continue
        who, mb = by_scope.get(os.path.basename(d), "?"), lambda b: b // 1048576
        if an >= 0.9 * high:
            gaps.append("seat %s's scope holds %d of its %d MB memory.high, anon=%dMB file=%dMB (its own anon at 90 percent of memory.high is the bar): the kernel throttles it -- find what it is running" % (who, mb(cur), mb(high), mb(an), mb(fl)))
            continue
        want = min(fl, max(0, cur - int(0.75 * high)))
        how = reclaim_file(d, want)
        notes.append("  RECLAIMED seat %s: its scope held %d of its %d MB memory.high by file pages (anon=%dMB file=%dMB); asked the kernel for %d MB of file pages: %s, now %d MB" % (who, mb(cur), mb(high), mb(an), mb(fl), mb(want), how, mb(num(d, "memory.current"))))
    print("PROC CHECK orphans=%d mem_pressure_avg60=%s reclaimed=%d gaps=%d" % (len(orphans), "%.1f" % mp if mp is not None else "-", len(notes), len(gaps)))
    for l in notes:
        print(l)
    if gaps:
        for g in gaps:
            print("  RED  " + g)
        return 1
    print("  GREEN no orphaned fleet process, box memory pressure under 10, no seat scope's own anon at 90 percent of its memory.high (file pages reclaimed, not alarmed)")
    return 0


def watch_check():
    """THE HEALTH CHECK OF THE HEALTH CHECK (Lon 2026-11-01: "I have a novel idea, add a health check to the healt check script."): the watchers that run
    the checks between the coo's turns can die silently (a reboot killed the loop for 11 h on 10-17). RED by name when the coo's loop (bash loop8.sh), tier1
    (bash tier1.sh, which carries the fleet watch) or the seat watch (bash seatwatch.sh) has no process and no STOP file in the verifier directory, and when
    the fleet watch's last pass (fleet.last) is over fifteen minutes old."""
    vd = arg("--verifier-dir", "/home/claude_coo/.scratch/verifier")
    psf = arg("--ps", "")
    txt = rd(psf) if psf else subprocess.run(["ps", "-eo", "pid=,ppid=,etimes=,rss=,cgroup:400=,args="], capture_output=True, text=True).stdout
    args = [l.split(None, 5)[5] for l in txt.splitlines() if len(l.split(None, 5)) == 6]
    gaps = []
    for name, script, stop in (("the loop", "loop8.sh", "STOP"), ("tier1 and its fleet watch", "tier1.sh", "STOP1"), ("the seat watch", "seatwatch.sh", "STOPSW")):
        alive = any(re.match(r"^(\S*/)?bash %s$" % re.escape(script), a.strip()) for a in args)
        if not alive and not os.path.exists(os.path.join(vd, stop)):
            gaps.append("%s is NOT RUNNING (no bash %s, no %s file in %s): restart it" % (name, script, stop, vd))
    fl = rd(os.path.join(vd, "fleet.last")).strip()
    tick = os.path.exists(os.path.join(vd, "STOP1"))   # the coo 2026-11-08 07:5x (Lon: "fix the two false reds in the census"): tier1 and its fleet watch stand
    if tick:                                           # STOPPED by design (CIO-3: the loops are gone); the watch between turns is the controller's tick now
        bs = arg("--box-state", "/home/resources/progress/BOX.state")   # box_tick.py on s4e-tick.timer (OnUnitActiveSec=60) writes it every tick
        age = time.time() - os.path.getmtime(bs) if os.path.exists(bs) else None
        if age is None:
            gaps.append("the controller tick has never written %s (box_tick.py on s4e-tick.timer)" % bs)
        elif age > 300:
            gaps.append("the controller tick last wrote %s %d min ago (5 is the bar; s4e-tick.timer runs it every 60 s): the tick is stuck or dead" % (bs, age // 60))
    elif not fl.isdigit():
        gaps.append("the fleet watch has never recorded a pass (no %s/fleet.last)" % vd)
    elif time.time() - int(fl) > 900:
        gaps.append("the fleet watch's last pass is %d min old (15 is the bar): tier1's watch loop is stuck or dead" % ((time.time() - int(fl)) // 60))
    print("WATCH CHECK verifier=%s gaps=%d" % (vd, len(gaps)))
    if gaps:
        for g in gaps:
            print("  RED  " + g)
        return 1
    if tick:
        print("  GREEN tier1 stands stopped by design (STOP1) and the controller tick wrote BOX.state within five minutes; the loop and the seat watch are running or stopped by their STOP files")
    else:
        print("  GREEN the loop, tier1 with its fleet watch and the seat watch are running, and the fleet watch passed within fifteen minutes")
    return 0


def health():
    """--health: the ledger (--check), memory and /tmp (--memory-check), CPU (--cpu-check) and each seat's /tmp (--tmp-check) in one call; rc is the worst of the three, so a GREEN arm
    can never stand in for a RED one (the 2026-11-01 lesson: --check alone read GREEN on a saturated box)."""
    rcs = []
    for fn in (check, memory_check, cpu_check, tmp_check, proc_check, watch_check):
        rcs.append(fn())
    return 2 if 2 in rcs else (1 if 1 in rcs else 0)


# ---- DESIGN-PLAN test-cycle step 8: THE ACCEPTANCE INSTRUMENT (officer_01, 2026-11-08, on the cio's re-cut of the cto's step; the design text is skill
# suites-and-grading reference.md section 7, THE ACCEPTANCE). It prints ONE line, every number read from a ledger by the command named in its comment:
#   TEST_CYCLE_ACCEPTANCE window_s=W entries_per_hour=E x_baseline=X instr_per_entry=I request_p50_min=P request_p95_min=Q lap_done_by_0600=0|1
#   idle_with_ready_min=M hand_restarts=H  then the denominators (readings, master_rows, pkg_rows, requests, ticks, ticks_unread, instr_cells).
# A field the instrument could not measure prints "-" (rc 2), so the step's grep reads RED, never a false GREEN (an absence counts only after the tool spoke).
# It judges nothing: the thresholds are the STEPS.tsv probe's grep. The window ends at --until EPOCH (default now).
TC_RESULTS = RESULTS
TC_REQ_DONE = "/home/resources/postoffice/test_requests/done"
TC_LAP = "/home/resources/progress/LAP.tsv"
TC_TICKS = os.path.join(os.environ.get("S4E_TICK_DIR") or "/tmp/s4e/cio/tick", "ticks.log")   # the controller's TICK_DIR (s4e-tick.service runs it as S4E_SEAT=cio)
TC_CELLS = "sno-rungs:chunk:01,gimpel:chunk:01"   # the two cells the cio measured per cell on 2026-11-08 07:1x (the design text): one master chunk, one package chunk
TC_EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "pascal": "pas", "raku": "raku", "rebus": "reb", "snocone": "sc"}
TC_TZ = {"CST": -6 * 3600, "CDT": -5 * 3600}
TC_TICK_COVER = 0.9   # M and H read only when ticks.log holds a tick for at least 90 percent of the window's minutes


def tc_local_s(stamp):
    """Epoch seconds of a request stamp 'YYYY-MM-DD HH:MM:SS CST|CDT' (the writers' label is the offset); None for anything else ('returned ...')."""
    m = re.match(r"(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d) (CST|CDT)\b", stamp.strip())
    if not m:
        return None
    return __import__("calendar").timegm(time.strptime(m.group(1) + "T" + m.group(2), "%Y-%m-%dT%H:%M:%S")) - TC_TZ[m.group(3)]


def tc_readings(path, since, until):
    """E's numerator: the distinct readings (ts_utc, suite, program, mode) in results.tsv in [since, until]; an exact duplicate row is one reading.
    Returns (readings, master_rows, pkg_rows): class 'package' weighs the package launch, every other class the master launch."""
    seen = set(); nm = np = 0
    for l in rd(path).splitlines():
        r = l.split("\t")
        if len(r) < 9 or not r[0][:4].isdigit():
            continue
        try:
            t = utc_s(r[0])
        except ValueError:
            continue
        if not (since <= t <= until):
            continue
        k = (r[0][:19], r[5], r[7], r[8])
        if k in seen:
            continue
        seen.add(k)
        if r[4] == "package":
            np += 1
        else:
            nm += 1
    return len(seen), nm, np


def tc_rank(xs, q):
    """Nearest-rank percentile (the ceil(q*n)-th smallest); None on an empty list."""
    if not xs:
        return None
    s = sorted(xs)
    return s[max(0, min(len(s), -(-round(q * 100) * len(s) // 100)) - 1)]


def tc_requests(d, since, until):
    """P and Q's population: minutes from a .req's filed= stamp to its served= stamp, every .req in test_requests/done/ served in [since, until]."""
    mins = []
    for f in sorted(glob.glob(os.path.join(d, "*.req"))):
        filed = served = None
        for l in rd(f).splitlines():
            if l.startswith("filed=") and filed is None:
                filed = tc_local_s(l[6:])
            elif l.startswith("served="):
                served = tc_local_s(l[7:])
        if filed is not None and served is not None and since <= served <= until and served >= filed:
            mins.append((served - filed) / 60.0)
    return mins


def tc_lap(path, since, until):
    """lap_done_by_0600: LAP.tsv's last done line in [since, until] against the first 06:00 local after the put line of the same lap and tree before it.
    LAP.tsv columns: lap tree put|done tube ts cells. 1 done by then, 0 late or no done line in the window."""
    puts, last = [], None
    for l in rd(path).splitlines():
        r = l.split("\t")
        if len(r) < 5:
            continue
        try:
            t = utc_s(r[4])
        except ValueError:
            continue
        if r[2] == "put":
            puts.append((t, r[0], r[1]))
        elif r[2] == "done" and since <= t <= until and (last is None or t >= last[0]):
            last = (t, r[0], r[1])
    if last is None:
        return 0
    put = max((p for p in puts if p[1] == last[1] and p[2] == last[2] and p[0] <= last[0]), default=None)
    if put is None:
        return 0
    lt = time.localtime(put[0])
    six = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, 6, 0, 0, 0, 0, -1))
    if six <= put[0]:
        six = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday + 1, 6, 0, 0, 0, 0, -1))
    return 1 if last[0] <= six else 0


def tc_ticks(path, since, until):
    """The controller's tick history (box_tick.py appends one JSON line a tick to TICK_DIR/ticks.log): the ticks in [since, until], the ones whose
    grader_queue could not be read (null), and the minutes M (ticks) in which grader_queue > 0 while running < want."""
    ticks, unread, idle = [], 0, 0
    for l in rd(path).splitlines():
        try:
            j = __import__("json").loads(l)
            t = utc_s(j["ts"])
        except (ValueError, KeyError, TypeError):
            continue
        if not (since <= t <= until):
            continue
        j["t"] = t; ticks.append(j)
        if j.get("grader_queue") is None:
            unread += 1
        elif j["grader_queue"] > 0 and j.get("running", 0) < j.get("want", 0):
            idle += 1
    return ticks, unread, idle


def tc_perf(cmd, env, cwd, timeout_s=300):
    """perf stat -x, -e instructions:u -o F -- CMD: (instructions, rc) of one launch; (None, rc) when perf printed no count."""
    import tempfile
    fd, out = tempfile.mkstemp(prefix="tca_perf.", dir=os.environ.get("TMPDIR") or None); os.close(fd)
    try:
        r = subprocess.run(["timeout", "-k", "5", str(timeout_s), "perf", "stat", "-x,", "-e", "instructions:u", "-o", out, "--"] + cmd,
                           cwd=cwd, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for l in rd(out).splitlines():
            f = l.split(",")
            if len(f) > 2 and "instructions" in f[2] and f[0].isdigit():
                return int(f[0]), r.returncode
        return None, r.returncode
    finally:
        os.unlink(out)


def tc_cell_instr(root, suite, cell):
    """One launch of one cell exactly as run_cell of s4e_cycle.sh launches it (as seat grader, class grader, S4E_PROGRESS_OFF=1 so it writes no reading): a master row of
    SUITE_RUNNERS.tsv runs util_run_slot.sh python3 corpus_suite_harness.py run ALL.<ext> ALL.ref --lang L --modes m3,m4 --partition CELL;
    a pkg row runs S4E_CHUNK=CELL util_run_slot.sh bash <runner>. Returns (instructions per entry, kind, entries, why); the entries are the
    table's PARTITION.tsv rows of that part. A launch that did not grade (rc not 0 or 1) or printed no count is (None, kind, n, why)."""
    sc = os.path.join(root, "harness", "scripts")
    row = next((l.rstrip("\n").split("\t") for l in rd(os.path.join(sc, "SUITE_RUNNERS.tsv")).splitlines() if l.split("\t")[0] == suite and len(l.split("\t")) == 5), None)
    if row is None or row[1] not in ("master", "pkg"):
        return None, "-", 0, "%s is not a master or pkg row of SUITE_RUNNERS.tsv" % suite
    kind, lang, words, table = row[1], row[2], row[3].split(), os.path.join(root, row[4])
    part = [l.split("\t") for l in rd(os.path.join(table, "PARTITION.tsv")).splitlines() if l and not l.startswith("#")]
    n = sum(1 for r in part[1:] if len(r) > 1 and r[1] == cell) if part and part[0][:2] == ["entry", "part"] else 0
    if n == 0:
        return None, kind, 0, "no %s rows in %s/PARTITION.tsv" % (cell, row[4])
    env = dict(os.environ, S4E_HOME=root, S4E_PROGRESS_OFF="1", S4E_SEAT="grader", S4E_CLASS="grader")   # the cycle's identity (s4e_cycle.sh exports S4E_SEAT=grader S4E_CLASS=grader)
    # the cycle): the runners admit a board only to the coo's instrument (lib_one_runner.sh); S4E_PROGRESS_OFF=1 writes no reading (the cio's 07:1x measurement)
    if kind == "master":
        alls = [os.path.join(root, "corpus", "tests", lang, "ALL." + TC_EXT.get(lang, "-"))]   # s4e_cycle.sh's ext_of table
        if not os.path.isfile(alls[0]):
            return None, kind, n, "no container %s" % alls[0]
        cmd = ["bash", os.path.join(sc, "util_run_slot.sh"), "python3", os.path.join(sc, "corpus_suite_harness.py"), "run", alls[0],
               os.path.join(os.path.dirname(alls[0]), "ALL.ref"), "--lang", lang, "--modes", "m3,m4", "--partition", cell]
    else:
        env["S4E_CHUNK"] = cell
        cmd = ["bash", os.path.join(sc, "util_run_slot.sh"), "bash", os.path.join(sc, words[0])] + words[1:]
    ins, rc = tc_perf(cmd, env, root)
    if ins is None or rc not in (0, 1):
        return None, kind, n, "the launch of %s %s did not grade (rc %s, count %s)" % (suite, cell, rc, ins)
    return ins / n, kind, n, ""


def tc_line(window, until, results, req_dir, lap_path, ticks_path, journal, base, instr):
    """The one line and its rc (0 every field measured, 2 a field read '-'). instr: {'master': G per entry or None, 'pkg': ...} and a cells note."""
    since = until - window
    hours = window / 3600.0
    readings, nm, np = tc_readings(results, since, until)                                   # awk-equivalent over results.tsv: distinct (ts, suite, program, mode) in the window
    E = readings / hours
    base_rph = next((float(l.split("\t")[1]) for l in rd(base).splitlines() if l.startswith("rows_per_hour\t")), 0.0)   # BASELINE.tsv rows_per_hour (913, the cto's)
    X = E / base_rph if base_rph > 0 else None
    im, ip = instr.get("master"), instr.get("pkg")                                           # perf stat -e instructions:u over one launch of each cell, over its entries
    I = None
    if im is not None and ip is not None:
        I = (im * nm + ip * np) / (nm + np) if nm + np else (im + ip) / 2.0                  # weighted by the window's master and package rows
    mins = tc_requests(req_dir, since, until)                                                # test_requests/done/*.req: filed= to served=
    P, Q = tc_rank(mins, 0.50), tc_rank(mins, 0.95)
    lap = tc_lap(lap_path, since, until)                                                     # LAP.tsv: the last done line against 06:00 local after its put
    ticks, unread, idle = tc_ticks(ticks_path, since, until)                                 # TICK_DIR/ticks.log: one JSON line a tick
    covered = len(ticks) >= TC_TICK_COVER * window / 60.0
    M = idle if covered else None
    H = 0   # hand restarts of grade-worker units: none can exist since the units retired (CIO-82); the field stays for test_cycle step 8's probe, which reads hand_restarts=0
    v = lambda x, f="%d": "-" if x is None else (f % x)
    vals = [X, I, P, Q, M, H]
    line = ("TEST_CYCLE_ACCEPTANCE window_s=%d entries_per_hour=%d x_baseline=%s instr_per_entry=%s request_p50_min=%s request_p95_min=%s lap_done_by_0600=%d "
            "idle_with_ready_min=%s hand_restarts=%s readings=%d master_rows=%d pkg_rows=%d requests=%d ticks=%d ticks_unread=%d instr_cells=%s"
            % (window, int(E), v(X, "%.1f"), v(I, "%.0f"), v(None if P is None else round(P)), v(None if Q is None else round(Q)), lap,
               v(M), v(H), readings, nm, np, len(mins), len(ticks), unread, instr.get("cells", "-")))
    return line, (2 if any(x is None for x in vals) else 0)


def test_cycle_acceptance(window):
    until = int(arg("--until", str(int(time.time()))))
    root = arg("--repos", os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    instr, notes = {"master": None, "pkg": None}, []
    for spec in arg("--cells", TC_CELLS).split(","):
        suite, _, cell = spec.partition(":")
        g, kind, n, why = tc_cell_instr(root, suite, cell)
        if kind in instr and instr[kind] is None:
            instr[kind] = g
        notes.append("%s:%s=%s/%d" % (suite, cell, "-" if g is None else "%.0f" % (g * n), n))
        if why:
            print("TEST_CYCLE_ACCEPTANCE_NOTE %s" % why)
    instr["cells"] = ",".join(notes)
    since = until - window
    journal = None   # the grade-worker units' journal retired with them (CIO-82)
    base = arg("--baseline-file", "")
    line, rc = tc_line(window, until, arg("--results", TC_RESULTS), arg("--req-done", TC_REQ_DONE), arg("--lap-file", TC_LAP), arg("--ticks", TC_TICKS),
                       journal, base, instr)
    print(line)
    return rc


def test_cycle_acceptance_probe():
    """--test-cycle-acceptance --probe: scratch ledgers of known rows read known numbers, through the same functions the live reading uses; one perf
    count of python3 -c pass proves the counter reads. Prints TEST_CYCLE_ACCEPTANCE_PROBE ok=N bad=M and the first wrong arm; rc 0 all as expected, 1 otherwise."""
    import tempfile, json, calendar
    os.environ["TZ"] = "America/Chicago"; time.tzset()
    d = tempfile.mkdtemp(prefix="tca_probe.", dir=os.environ.get("TMPDIR") or None)
    Z = lambda s: calendar.timegm(time.strptime(s, "%Y-%m-%dT%H:%M:%S"))
    until = Z("2026-11-08T12:00:00"); W = 7200
    hdr = "ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n"
    row = lambda ts, cls, suite, prog, mode: "\t".join([ts, "x", "y", "grader", cls, suite, "l", prog, mode, "PASS", "0.1", "-", "-", "-"]) + "\n"
    res = os.path.join(d, "results.tsv")
    with open(res, "w") as f:
        f.write(hdr)
        for ts, cls, s, p, m in [("2026-11-08T10:10:00", "rungs", "sno-rungs", "a", "m3"), ("2026-11-08T10:10:00", "rungs", "sno-rungs", "a", "m4"),
                                 ("2026-11-08T10:10:00", "rungs", "sno-rungs", "a", "m3"),          # an exact duplicate: one reading
                                 ("2026-11-08T11:00:00", "rungs", "sno-rungs", "a", "m3"),          # the same program read again: a second reading
                                 ("2026-11-08T11:00:00", "rungs", "icn-rungs", "a", "m3"),          # the same name in another suite: its own reading
                                 ("2026-11-08T11:30:00", "package", "gimpel", "p", "m3"), ("2026-11-08T11:30:00", "package", "gimpel", "p", "m4"),
                                 ("2026-11-08T11:45:00", "rungs", "icn-rungs", "b", "m4"),
                                 ("2026-11-08T11:59:59", "package", "gimpel", "q", "m3"),
                                 ("2026-11-08T09:59:59", "rungs", "sno-rungs", "old", "m3"),       # before the window
                                 ("2026-11-08T12:00:01", "rungs", "sno-rungs", "late", "m3")]:      # after it
            f.write(row(ts, cls, s, p, m))
    base = os.path.join(d, "BASELINE.tsv"); open(base, "w").write("# key\tvalue\tunit\tcommand\nrows_per_hour\t2\trows/h\tprobe\n")
    rq = os.path.join(d, "done"); os.makedirs(rq)
    for i, (filed, served) in enumerate([("2026-11-08 04:10:00 CST", "2026-11-08 04:12:00 CST"), ("2026-11-08 04:20:00 CST", "2026-11-08 04:24:00 CST"),
                                         ("2026-11-08 05:00:00 CST", "2026-11-08 05:06:00 CST"), ("2026-11-08 05:00:00 CST", "2026-11-08 05:40:00 CST"),
                                         ("2026-11-08 02:00:00 CST", "2026-11-08 03:30:00 CST"),   # served before the window
                                         ("2026-11-08 05:00:00 CST", "returned 2026-11-08 05:10:00")]):   # returned, never served
        open(os.path.join(rq, "r%d.req" % i), "w").write("seat=probe\nfiled=%s\nserved=%s tree=x rc=0 rows=1\n" % (filed, served))
    lapf = os.path.join(d, "LAP.tsv")
    open(lapf, "w").write("lap\tt1\tput\tgrade\t2026-11-08T04:00:00Z\tcells=2\nlap\tt1\tdone\tgrade\t2026-11-08T11:30:00Z\tcells=2\n")   # put 22:00 CST, done 05:30 CST
    late = os.path.join(d, "LAP_late.tsv")
    open(late, "w").write("lap\tt0\tput\tgrade\t2026-11-07T04:00:00Z\tcells=2\nlap\tt0\tdone\tgrade\t2026-11-08T11:30:00Z\tcells=2\n")   # put 22:00 CST the night before, done a day late
    tk = os.path.join(d, "ticks.log")
    with open(tk, "w") as f:
        for k in range(120):
            t = until - W + 30 + 60 * k
            j = dict(ts=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(t)), tick=k, grader_queue=5 if k in (3, 4, 50) else 0, want=8, running=7 if k in (3, 4, 50, 60) else 8, stops=[5] if k == 90 else [])
            f.write(json.dumps(j) + "\n")
    instr = {"master": 1.0e9, "pkg": 4.0e9, "cells": "planted"}
    want = ("TEST_CYCLE_ACCEPTANCE window_s=7200 entries_per_hour=4 x_baseline=2.0 instr_per_entry=2125000000 request_p50_min=4 request_p95_min=40 lap_done_by_0600=1 "
            "idle_with_ready_min=3 hand_restarts=0 readings=8 master_rows=5 pkg_rows=3 requests=4 ticks=120 ticks_unread=0 instr_cells=planted")
    arms = []
    got, rc = tc_line(W, until, res, rq, lapf, tk, None, base, instr)
    arms.append(("the known ledgers read the known line", got == want and rc == 0, got))
    got, rc = tc_line(W, until, res, rq, late, tk, None, base, instr)
    arms.append(("a lap done a day after its 06:00 reads lap_done_by_0600=0", " lap_done_by_0600=0 " in got, got))
    short = os.path.join(d, "ticks_short.log")
    open(short, "w").write("".join(l + "\n" for l in rd(tk).splitlines()[:60]))
    got, rc = tc_line(W, until, res, rq, lapf, short, None, base, instr)
    arms.append(("half the window's ticks read M as '-' and rc 2", " idle_with_ready_min=- hand_restarts=0 " in got and rc == 2, got))
    got, rc = tc_line(W, until, res, rq, lapf, tk, None, base, {"master": None, "pkg": 4.0e9, "cells": "x"})
    arms.append(("a launch that did not grade reads I as '-' and rc 2", " instr_per_entry=- " in got and rc == 2, got))
    ins, prc = tc_perf(["python3", "-I", "-c", "pass"], dict(os.environ), d, 60)
    arms.append(("perf stat counts one python3 -c pass launch", ins is not None and ins > 1000000 and prc == 0, "count %s rc %s" % (ins, prc)))
    __import__("shutil").rmtree(d, ignore_errors=True)
    bad = [a for a in arms if not a[1]]
    print("TEST_CYCLE_ACCEPTANCE_PROBE ok=%d bad=%d%s" % (len(arms) - len(bad), len(bad), (" first_bad=%r got=%r" % (bad[0][0], bad[0][2])) if bad else ""))
    return 1 if bad else 0


def main():
    av = sys.argv[1:]
    if "--test-cycle-acceptance" in av:
        if "--probe" in av:
            return test_cycle_acceptance_probe()
        v = arg("--test-cycle-acceptance", "86400")
        if not v.isdigit():
            print("REFUSE(2): usage: util_seat_census.py --test-cycle-acceptance <window_s> <BASELINE.tsv> | --test-cycle-acceptance --probe"); return 2
        nxt = sys.argv[sys.argv.index(v) + 1] if sys.argv.index(v) + 1 < len(sys.argv) else ""
        if "--baseline-file" not in sys.argv:
            if not nxt or nxt.startswith("--") or not os.path.isfile(nxt):
                print("REFUSE(2): no BASELINE.tsv named after the window (got %r)" % nxt); return 2
            sys.argv += ["--baseline-file", nxt]
        return test_cycle_acceptance(int(v))
    if "--budget-check" in av:
        return budget_check()
    if "--budget-props" in av:
        v = arg("--budget-props", "")
        return budget_print_props("" if v.startswith("--") else v)
    if "--lap" in av:
        v = arg("--lap", "3600")
        return lap(int(v) if v.isdigit() else 3600)
    if "--admission-check" in av:
        v = arg("--admission-check", "86400")
        return admission_check(int(v) if v.isdigit() else 86400)
    if "--grader-rate" in av:
        return grader_rate(int(arg("--grader-rate", "7200")))
    if "--acceptance" in av:
        return acceptance(int(arg("--acceptance", "86400")))
    if "--health" in av:
        return health()
    if "--watch-check" in av:
        return watch_check()
    if "--proc-check" in av:
        return proc_check()
    if "--tmp-check" in av:
        return tmp_check()
    if "--cpu-check" in av:
        return cpu_check()
    if "--memory-check" in av:
        return memory_check()
    if "--check" in av:
        return check()
    if av and av[0] == "banner":
        return banner(av[1] if len(av) > 1 and not av[1].startswith("--") else os.environ.get("S4E_SEAT", ""))
    if av and av[0] == "now":
        return run(False, True)
    if av and av[0] == "run":
        return run(True, False)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
