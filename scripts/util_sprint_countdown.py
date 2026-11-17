#!/usr/bin/env python3
"""util_sprint_countdown.py SEAT -- THE SPRINT'S COUNTDOWN TO ZERO, two lines of the Stop banner (Lon 2026-11-17 14:3x CST, in the cio's window,
verbatim: "Since all the bugs are accounted for and assigned, install a stop-turn banner to show the countdown to ZERO."). The one banner script
every seat runs, s4e_banner_cached.sh, calls it with the seat's name and shows what it prints under the verdict word.
ONE FILE IS THE SWITCH: /home/resources/postoffice/SPRINT.conf, key=value a line, the cio's to set (skill fleet-bus section 1, a sprint):
    name=SNOBOL4               what the line calls the sprint
    lang=snobol4               the language column of the suite table whose rows are counted (SCRIP's rows only, never a port's key@engine row)
    start=107                  the bugs measured when the sprint was opened
    started=11-17 13:01        when that was measured (free text)
    show=cio coo grader cqo    the seats whose banner carries the lines; any other seat prints nothing
With no file, no lang, or a seat the show line does not name, it prints nothing and the banner is as it was. To end the countdown delete the file.
ONE DB (Lon 2026-11-12, skill suites-and-grading section 3): the count is read from the same rows the grid and the summary by language read,
/home/resources/progress/SUITES.tsv: a bug is an entry of a suite of the language that the row's newest reading does not pass, today_total less
today_pass, so the countdown moves when the cycle rewrites a row and never before, and it can go up as well as down. Read only, nothing run.
  python3 -I util_sprint_countdown.py SEAT      the two lines, or nothing; rc 0
  python3 -I util_sprint_countdown.py --probe   five arms on a scratch table and a scratch switch; rc 0 green, rc 1 red"""
import os, sys, tempfile, time

CONF = os.environ.get("S4E_SPRINT_CONF", "/home/resources/postoffice/SPRINT.conf")
SUITES = os.environ.get("S4E_SUITES_TSV", "/home/resources/progress/SUITES.tsv")


def read_conf(path):
    c = {}
    try:
        for ln in open(path, encoding="utf-8", errors="replace"):
            ln = ln.strip()
            if ln and not ln.startswith("#") and "=" in ln:
                k, _, v = ln.partition("=")
                c[k.strip()] = v.strip()
    except OSError:
        return {}
    return c


def read_rows(path, lang):
    rows, head = [], None
    for ln in open(path, encoding="utf-8", errors="replace"):
        if ln.startswith("#") or not ln.strip():
            continue
        cells = ln.rstrip("\n").split("\t")
        if head is None:
            head = cells
            continue
        r = dict(zip(head, cells))
        if r.get("lang") != lang or "@" in r.get("key", ""):
            continue
        try:
            p, t = int(r.get("today_pass") or 0), int(r.get("today_total") or 0)
        except ValueError:
            continue
        rows.append((r.get("nick") or r.get("key", "?"), p, t))
    return rows


def lines(seat, conf_path=None, suites_path=None, stamp=True):
    c = read_conf(conf_path or CONF)
    lang, name = c.get("lang", ""), c.get("name", "")
    if not lang or seat not in c.get("show", "").split():
        return []
    rows = read_rows(suites_path or SUITES, lang)
    if not rows:
        return [f"{name or lang} SPRINT COUNTDOWN: the suite table holds no row of language {lang}"]
    togo = sum(t - p for _, p, t in rows)
    at100 = sum(1 for _, p, t in rows if p == t and t > 0)
    when = time.strftime("   [%m-%d %H:%M %Z]") if stamp else ""
    start = c.get("start", "")
    since = f" of {start} at the start ({c.get('started', '?')})" if start.isdigit() else ""
    gone = f", {int(start) - togo} gone" if start.isdigit() else ""
    if togo == 0:
        return [f"🏁 {name} SPRINT: ZERO. Every one of the {len(rows)} suites reads 100%{since}.{when}"]
    pre = os.path.commonprefix([n for n, _, _ in rows]) if len(rows) > 1 else ""
    left = sorted(((t - p, n[len(pre):] or n) for n, p, t in rows if t - p > 0), key=lambda x: (-x[0], x[1]))
    return [f"⏬ {name} SPRINT, COUNTDOWN TO ZERO: {togo} to go{since}{gone}; {at100} of {len(rows)} suites at 100%{when}",
            "   to go: " + " · ".join(f"{n} {k}" for k, n in left)]


def probe():
    d = tempfile.mkdtemp(prefix="sprint_countdown_probe_")
    tsv, conf = os.path.join(d, "SUITES.tsv"), os.path.join(d, "SPRINT.conf")
    head = "key\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree"
    def table(a, b):
        open(tsv, "w").write("# a comment line\n" + head + "\n" + f"alpha\tSnoAlpha\tx\tsnobol4\td\t0\t0\td\t{a}\t10\th\n" + f"beta\tSnoBeta\tx\tsnobol4\td\t0\t0\td\t{b}\t5\th\n"
                             + "alpha@jvm\tSnoAlpha\tx\tsnobol4\td\t0\t0\td\t0\t10\th\n" + "gamma\tIcnGamma\tx\ticon\td\t0\t0\td\t1\t9\th\n")
    open(conf, "w").write("# the switch\nname=SNOBOL4\nlang=snobol4\nstart=9\nstarted=11-17 13:01\nshow=cio coo\n")
    bad = []
    table(7, 3)
    o = lines("cio", conf, tsv, stamp=False)
    want0 = "⏬ SNOBOL4 SPRINT, COUNTDOWN TO ZERO: 5 to go of 9 at the start (11-17 13:01), 4 gone; 0 of 2 suites at 100%"
    if o != [want0, "   to go: Alpha 3 · Beta 2"]:
        bad.append(("counts", o))                       # arm 1: the count, the port row and the other language left out, the names shortened
    if lines("officer_04", conf, tsv, stamp=False) != []:
        bad.append(("seat_not_shown", "printed"))       # arm 2: a seat the show line does not name prints nothing
    if lines("cio", os.path.join(d, "none.conf"), tsv, stamp=False) != []:
        bad.append(("no_switch", "printed"))            # arm 3: no switch file, nothing
    table(10, 5)
    o = lines("coo", conf, tsv, stamp=False)
    if o != ["🏁 SNOBOL4 SPRINT: ZERO. Every one of the 2 suites reads 100% of 9 at the start (11-17 13:01)."]:
        bad.append(("zero", o))                         # arm 4: zero is said as zero
    table(10, 1)
    o = lines("cio", conf, tsv, stamp=False)
    if not (o and "4 to go" in o[0] and "1 of 2 suites at 100%" in o[0] and o[1] == "   to go: Beta 4"):
        bad.append(("up_again", o))                     # arm 5: a suite that falls back is counted again
    for name, got in bad:
        print(f"SPRINT_COUNTDOWN_PROBE RED arm={name} got={got!r}")
    print(f"SPRINT_COUNTDOWN_PROBE arms=5 red={len(bad)}")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--probe":
        sys.exit(probe())
    try:
        for ln in lines(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("S4E_SEAT", "")):
            print(ln)
    except Exception as ex:   # the banner is never lost to a countdown that could not be read
        print(f"Sprint countdown: unreadable ({type(ex).__name__})")
