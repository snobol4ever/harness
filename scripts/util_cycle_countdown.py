#!/usr/bin/env python3
"""util_cycle_countdown.py -- THE CYCLE'S STATUS LINE AND THE BUG COUNTDOWN, the two lines the Stop banner shows above the suite grid of a seat that
shows the grid (the coo and the grader: s4e_msg.sh banner's own choice), printed by the ONE banner script every seat runs from its own root
(s4e_banner_cached.sh; the grader 2026-11-13, row one-banner-script-seat-aware-run-from-each-seats-own-root; Lon, in the grader's window, verbatim:
"do not reach into another's root folder and run a script." / "All seats should be running the SAME banner script with code that know WHO the HELL
you ARE."). Moved here from the coo's root, where coo_stop_banner.py and coo_bug_countdown.py printed them for the coo alone: the status line is
the coo's (Lon 2026-11-11 10:40 CST, in the coo's window: "Fix your banner to show the status aonly with the test banner."), the countdown the
coo's (Lon 2026-11-12 16:2x CST: "counters ready for junior, seniors, officers, and COO boss (bosses: CIO, CTO, or CFO)? I want to see a total
running count also."; 2026-11-13 14:4x CST: "You silly BUG COUNTDOWN is TOTALLY BOGUS.", so FIXED counts bug rows closed by their batons). Read
only, nothing run: CYCLE.state and CYCLE.log for the status; SUITES.tsv through util_suite_banner.py's own load() and _scrip() for the open reds
(ONE DB, Lon 2026-11-12 19:2x: "If you have banners grading DIFFERENT things, then DON'T!!! We want one DB."); QUEUE.tsv, QUEUE.done.tsv, the
batons, the claims and the escalations for the rows.
  python3 -I util_cycle_countdown.py            the status line, then the countdown lines; rc 0"""
import calendar, datetime, glob, os, re, sys, time

P = os.environ.get("S4E_PROGRESS", "/home/resources/progress")
PO = os.environ.get("S4E_POST", "/home/resources/postoffice")
HERE = os.path.dirname(os.path.abspath(__file__))


def cycle_status():
    st = {}
    try:
        for ln in open(os.path.join(P, "CYCLE.state"), encoding="utf-8", errors="replace"):
            k, _, v = ln.rstrip("\n").partition("=")
            st[k] = v
    except OSError:
        return "Cycle: no state file"
    pid = (st.get("pid") or "").strip()
    try:
        pid = pid or open(os.path.join(P, "CYCLE.pid")).read().strip()
    except OSError:
        pass
    alive = bool(pid) and os.path.isdir("/proc/" + pid)
    lap = st.get("lap", "?")
    graded = refused = died = 0
    try:
        for ln in open(os.path.join(P, "CYCLE.log"), encoding="utf-8", errors="replace"):
            m = re.search(r" CELL lap=(\d+) \d+/\d+ \S+ \S+ rc=(\S+) ", ln)
            if m and m.group(1) == lap:
                if m.group(2) in ("0", "1"):
                    graded += 1
                elif m.group(2) == "2":
                    refused += 1
                else:
                    died += 1
    except OSError:
        pass
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})", st.get("since", ""))
    at = time.strftime("%H:%M", time.localtime(calendar.timegm(tuple(int(x) for x in m.groups()) + (0, 0, 0)))) if m else "?"
    done = graded + refused + died
    cell = (st.get("suite", "") + " " + st.get("cell", "")).strip()
    s = f"Cycle {'running' if alive else 'NOT RUNNING'}: lap {lap}, {done} of {st.get('total', '?')} cells done ({graded} graded, {refused} refused" + (f", {died} died or timed out" if died else "") + ")"
    if alive and cell:
        s += f"; oldest cell in flight {cell} since {at}"
    elif not alive:
        s += f"; last state {st.get('status', '?')} at {at}" + ("; STOP file present" if os.path.exists(os.path.join(P, "CYCLE.STOP")) else "")
    return s + time.strftime("   [%m-%d %H:%M %Z]")


START_REDS = 3098   # the banner rows' open reds at 2026-11-12 19:2x CST, the baseline of one DB
SINCE = datetime.datetime(2026, 11, 12, 16, 40, tzinfo=datetime.timezone.utc).timestamp()
T = ["junior", "senior", "officer", "coo", "bosses"]


def tier(seat):
    s = seat.lstrip("@")
    if s.startswith("junior") or s == "haiku": return "junior"
    if s.startswith("senior") or s == "sonnet": return "senior"
    if s.startswith("officer") or s == "opus": return "officer"
    if s == "coo": return "coo"
    if s in ("cio", "cto", "cfo", "grader", "fable"): return "bosses"
    return None


def countdown():
    esc = dict.fromkeys(T, 0); held = dict.fromkeys(T, 0)
    for p in glob.glob(PO + "/escalations/*-red-*.rung*.md"):
        if os.path.getmtime(p) < SINCE: continue
        n = int(re.search(r"\.rung(\d+)\.md$", p).group(1)); esc[{2: "junior", 3: "senior", 4: "officer"}.get(n, "coo")] += 1
    try:
        for l in open(PO + "/QUEUE.tsv", encoding="utf-8", errors="replace"):
            f = l.rstrip("\n").split("\t")
            if len(f) < 4 or "-red-" not in f[1] or f[3].startswith(("DONE", "RETIRED")): continue
            m = re.match(r"(?:CLAIMED|ASSIGNED):(\S+)", f[3]); t = tier(m.group(1)) if m else None
            if t is None:
                m = re.match(r"QUEUED:(?:seat|tier)-(\S+)", f[3]); t = tier(m.group(1)) if m else tier(f[2])
            if t: held[t] += 1
    except OSError:
        pass
    sys.path.insert(0, HERE)
    import util_suite_banner as b
    _h, rows = b.load(); rows = b._scrip(rows)
    p = t_ = ndone = nsuites = 0
    for r in rows:
        nsuites += 1
        try: tp, tt = int(r["today_pass"]), int(r["today_total"])
        except (ValueError, KeyError): continue
        p += tp; t_ += tt; ndone += (tt > 0 and tp >= tt)
    seats = {"junior": 0, "senior": 0, "officer": 0}
    try:
        roster = next((l for l in open(PO + "/MODE", encoding="utf-8", errors="replace") if l.startswith("ROSTER:")), "")
    except OSError:
        roster = ""
    for s in re.findall(r"\b(junior|senior|officer)_\d+\b", roster):
        seats[s] += 1
    name = {"junior": "Juniors %d" % seats["junior"], "senior": "Seniors %d" % seats["senior"], "officer": "Officers %d" % seats["officer"], "coo": "COO (boss)", "bosses": "CIO/CTO/CFO/GRADER"}
    # FIXED IS A ROW CLOSED, COUNTED BY ITS BATON (the coo 2026-11-13, on Lon's 14:4x word above: the receipt count missed every row retired green): a
    # bug row counts FIXED when its baton's STATE is DONE or RETIRED:done-green*, by the day its baton was last written, credited to its OWNER's tier
    day0 = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
    cl_today = dict.fromkeys(T, 0); fixed = dict.fromkeys(T, 0)
    for bp in glob.glob(PO + "/tasks/*-red-*.task.md"):
        try:
            mt = os.path.getmtime(bp)
            if mt < SINCE: continue
            txt = open(bp, encoding="utf-8", errors="replace").read(4000)
        except OSError:
            continue
        st = re.search(r"^STATE: (\S+)", txt, re.M); ow = re.search(r"^OWNER: (\S+)", txt, re.M)
        if not st or not re.match(r"(DONE|RETIRED:done-green)", st.group(1)): continue
        tr = (tier(ow.group(1)) if ow else None) or "coo"
        fixed[tr] += 1
        if mt >= day0: cl_today[tr] += 1
    out = ["BUG COUNTDOWN   %d of %d suites at 100%%   OPEN REDS %d of %d entries (%d pass)" % (ndone, nsuites, t_ - p, t_, p),
           "  FIXED (bug rows closed DONE or retired green, by their batons): %d today since 00:00 CST, %d since the sweep began 11-12 10:4x CST" % (sum(cl_today.values()), sum(fixed.values())),
           "  %-20s %6s %6s %6s" % ("rows since 11-12 10:4x", "closed", "up", "held")]
    for k in T:
        out.append("  %-20s %6d %6s %6d" % (name[k], fixed[k], esc[k] if k != "bosses" else "-", held[k]))
    out.append("  %-20s %6d %6d %6d" % ("ALL", sum(fixed.values()), sum(esc.values()), sum(held.values())))
    return out


if __name__ == "__main__":
    try:
        print(cycle_status())
    except Exception as ex:   # the banner is never lost to a status that could not be read
        print(f"Cycle: status unreadable ({type(ex).__name__})")
    try:
        print("\n".join(countdown()))
    except Exception as ex:
        print(f"BUG COUNTDOWN: unreadable ({type(ex).__name__})")
