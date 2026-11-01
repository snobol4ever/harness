#!/usr/bin/env python3
"""util_seat_census.py -- THE LEDGER: WHO LOADS THE BOX, FROM THE CGROUP SCOPES (ARCH-SHARED-DEVELOPMENT.md sections 2 and 8 step 1, CEO-2041;
the cao's row shared-dev-step-1-the-seat-census-reads-the-cgroup-scopes-and-the-ledger-load-tsv-is-written-every-five-minutes-ceo-2041).

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
  --proc-check                         RED by name: a fleet process orphaned to the user manager 10 min or more, box memory pressure avg60 >= 10, a seat scope at 90%% of memory.high
  --watch-check                        RED when the coo's loop, tier1 (the fleet watch) or the seat watch is not running, or the fleet watch has not passed in 15 min
  --health                             --check, --memory-check, --cpu-check, --tmp-check, --proc-check and --watch-check together; rc the worst
  --memory-check                       step 8's DONE-WHEN: every live seat scope's memory.max below the box, the sessions' slice and the two s4e slices
                                       capped, S4E_SEAT in each session and both runners placing TMPDIR=/tmp/s4e/<seat>, /tmp under 60, no oom_kill in 24 h
  util_seat_census.py --grader-rate S  step 5's DONE-WHEN (default 7200): 200 distinct programs per hour or more among results.tsv's rr=1 rows while the ledger's
                                       cores_busy mean read 12 or more; rc 2 when the box was not busy (the rate under no contention measures nothing)
  util_seat_census.py --acceptance S   step 9's DONE-WHEN (default 86400): over the busy runs (twelve at least) the grader at 2.0 cores or more, no seat's
                                       ten-minute mean above 4.0 while another seat waited for a slot, pressure some avg300 under 30, builds FETCHED ten
                                       times the BUILT (BUILDS.tsv, written by util_build_cache.sh), landings on origin/main at 10 an hour or more
  --load F --seats F --root DIR        read and write these instead (the gate's fixtures)
  --results F --waits F --builds F --repos DIR   the other ledgers and the repo root, for the fixtures
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
BUILDS = "/home/resources/progress/BUILDS.tsv"
TERM = "user@1000.service/app.slice/app-org.gnome.Terminal.slice/"


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
    for d in sorted(glob.glob(os.path.join(app, "app-s4e.slice", "app-s4e-*.slice"))):
        m = re.match(r"app-s4e-([a-z0-9_]+)\.slice", os.path.basename(d))
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
            print("%-8s %-6s %-14s %6s cores %6s MB peak %6s oom %s pids %s cc %s run %s tmp %s" % tuple(l[1:]) if l[1] != "BOX" else "BOX %s" % l[4])
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


TMP_SEAT_MB = 4096   # ARCH-SHARED-DEVELOPMENT 2.3, /tmp move (2): a seat over 4 GB of /tmp is named; the banner shows each seat its own figure against it (the coo 2026-11-01, CEO-2095)


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
    gaps, seen = [], 0
    for seat, (cls, sc) in sorted(seat_map(arg("--seats", SEATS)).items()):
        d = os.path.join(root, sc)
        if cls != "SEAT" or not os.path.isdir(d):
            continue
        seen += 1
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
    while the run and cc pools together hold half their slots or fewer (the load runs outside the doors); for every SEAT line over 2 cores holding no run
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
    if busy >= 0.85 * n and held <= pools / 2:
        gaps.append("the box is busy (%.1f of %d cores) while the pools hold %d of %d slots: the load runs OUTSIDE the doors" % (busy, n, held, pools))
    for r in rows:
        if r[1] == "UNIT" and r[2] == "SEAT" and len(r) > 10:
            try:
                c, cc, rn = float(r[4]), int(r[9] or 0), int(r[10] or 0)
            except ValueError:
                continue
            if c > 2.0 and cc == 0 and rn == 0:
                gaps.append("seat %s runs %.2f cores holding no run slot and no cc slot: throttle it (nice, -j2, the pools) or cap its scope" % (r[3], c))
    gr = next((float(r[4]) for r in rows if r[1] == "CLASS" and r[2] == "GRADER"), None)
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
    every fleet process (a harness script, a scrip, as, gcc, make, a runner) whose parent is the user manager and that is ten minutes old or more, not one of
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
    keep = re.compile(r"(loop8\.sh|tier1\.sh|seatwatch\.sh|swap[A-Za-z0-9]*\.sh|util_seat_census\.py run|util_tmp_sweep\.sh|util_git_maintenance\.sh)")
    orphans = []
    for pid, ppid, et, rss, cg, a in rows:
        if ppid in mgr and int(et) >= 600 and work.search(a) and not keep.search(a):
            sc = os.path.basename(cg.split("::")[-1].rstrip("/"))
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
    for d in sorted(glob.glob(os.path.join(term, "*.scope"))):
        cur, high = rd(os.path.join(d, "memory.current")).strip(), rd(os.path.join(d, "memory.high")).strip()
        if cur.isdigit() and high.isdigit() and int(high) > 0 and int(cur) >= 0.9 * int(high):
            gaps.append("seat %s's scope holds %d of its %d MB memory.high (90 percent is the bar): the kernel throttles it -- find what it is running" % (by_scope.get(os.path.basename(d), "?"), int(cur) // 1048576, int(high) // 1048576))
    print("PROC CHECK orphans=%d mem_pressure_avg60=%s gaps=%d" % (len(orphans), "%.1f" % mp if mp is not None else "-", len(gaps)))
    if gaps:
        for g in gaps:
            print("  RED  " + g)
        return 1
    print("  GREEN no orphaned fleet process, box memory pressure under 10, every seat scope under 90 percent of its memory.high")
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
    if not fl.isdigit():
        gaps.append("the fleet watch has never recorded a pass (no %s/fleet.last)" % vd)
    elif time.time() - int(fl) > 900:
        gaps.append("the fleet watch's last pass is %d min old (15 is the bar): tier1's watch loop is stuck or dead" % ((time.time() - int(fl)) // 60))
    print("WATCH CHECK verifier=%s gaps=%d" % (vd, len(gaps)))
    if gaps:
        for g in gaps:
            print("  RED  " + g)
        return 1
    print("  GREEN the loop, tier1 with its fleet watch and the seat watch are running, and the fleet watch passed within fifteen minutes")
    return 0


def health():
    """--health: the ledger (--check), memory and /tmp (--memory-check), CPU (--cpu-check) and each seat's /tmp (--tmp-check) in one call; rc is the worst of the three, so a GREEN arm
    can never stand in for a RED one (the 2026-11-01 lesson: --check alone read GREEN on a saturated box)."""
    rcs = []
    for fn in (check, memory_check, cpu_check, tmp_check, proc_check, watch_check):
        rcs.append(fn())
    return 2 if 2 in rcs else (1 if 1 in rcs else 0)


def main():
    av = sys.argv[1:]
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
