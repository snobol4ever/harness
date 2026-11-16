#!/usr/bin/env python3
"""util_cycle_countdown.py -- THE CYCLE'S STATUS LINE, the one line the Stop banner shows above the suite grid of a seat that shows the grid (the coo
and the grader: s4e_msg.sh banner's own choice), printed by the ONE banner script every seat runs from its own root (s4e_banner_cached.sh; the
grader 2026-11-13, row one-banner-script-seat-aware-run-from-each-seats-own-root; Lon, in the grader's window, verbatim: "do not reach into
another's root folder and run a script." / "All seats should be running the SAME banner script with code that know WHO the HELL you ARE."). The
status line is the coo's (Lon 2026-11-11 10:40 CST, in the coo's window: "Fix your banner to show the status aonly with the test banner.").
THE BUG COUNTDOWN IS GONE (Lon 2026-11-16 11:1x CST, in the coo's window, verbatim: "Remove the BUG COUNTDOWN from the stop-turn banner."): the
table of rows closed, sent up and held a seat, which this file printed under the status line since 2026-11-12, is deleted with its code; the
file keeps its name for its one caller. Read only, nothing run: CYCLE.state and CYCLE.log.
  python3 -I util_cycle_countdown.py            the status line; rc 0"""
import calendar, os, re, time

P = os.environ.get("S4E_PROGRESS", "/home/resources/progress")


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


if __name__ == "__main__":
    try:
        print(cycle_status())
    except Exception as ex:   # the banner is never lost to a status that could not be read
        print(f"Cycle: status unreadable ({type(ex).__name__})")
