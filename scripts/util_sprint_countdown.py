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
SEVERAL SPRINTS, ONE FILE (Lon 2026-11-17 17:0x CST, in the cio's window, verbatim: "Okay then, get the banner to show 3 sprints: SNOBOL4, Icon, and Unicon."): each name= line opens a sprint of its own, with its own
lang, start and started, and two optional lines that pick its suites by their key in the suite table: keys=REGEX (the key must match) and nokeys=REGEX (the key must not), so the Icon suites and the
Unicon suites, which share the language icon, are two sprints (keys=^(uni|rosetta-unicon) and nokeys= the same). The show line is the file's, for every sprint. A file with one name= reads as before.
ONE DB (Lon 2026-11-12, skill suites-and-grading section 3): the count is read from the same rows the grid and the summary by language read,
/home/resources/progress/SUITES.tsv: a bug is an entry of a suite of the language that the row's newest reading does not pass, today_total less
today_pass, so the countdown moves when the cycle rewrites a row and never before, and it can go up as well as down. Read only, nothing run.
  python3 -I util_sprint_countdown.py SEAT      the two lines, or nothing; rc 0
  python3 -I util_sprint_countdown.py --probe   five arms on a scratch table and a scratch switch; rc 0 green, rc 1 red"""
import os, sys, tempfile, time

CONF = os.environ.get("S4E_SPRINT_CONF", "/home/resources/postoffice/SPRINT.conf")
SUITES = os.environ.get("S4E_SUITES_TSV", "/home/resources/progress/SUITES.tsv")


def read_conf(path):
    """-> (the file's own keys, [one dict a sprint]); a name= line opens a sprint, a key before the first name= is the file's, and show is the file's wherever it stands"""
    top, sprints, cur = {}, [], None
    try:
        for ln in open(path, encoding="utf-8", errors="replace"):
            ln = ln.strip()
            if ln and not ln.startswith("#") and "=" in ln:
                k, _, v = ln.partition("=")
                k, v = k.strip(), v.strip()
                if k == "name":
                    cur = {}
                    sprints.append(cur)
                if k == "show" or cur is None:
                    top[k] = v
                else:
                    cur[k] = v
    except OSError:
        return {}, []
    if not sprints and top.get("lang"):
        sprints = [dict(top)]
    return top, sprints


def read_rows(path, lang, keys="", nokeys=""):
    import re
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
        if (keys and not re.search(keys, r.get("key", ""))) or (nokeys and re.search(nokeys, r.get("key", ""))):
            continue
        try:
            p, t = int(r.get("today_pass") or 0), int(r.get("today_total") or 0)
        except ValueError:
            continue
        rows.append((r.get("nick") or r.get("key", "?"), p, t))
    return rows


BOLD = str.maketrans("0123456789", "𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵")   # Lon 2026-11-17 14:4x CST, in the cqo's window: "Make the numbers denominator and numerator more visible"; bold sans digits, no escape code, so any terminal shows them


def bold(n):
    return str(n).translate(BOLD)


def bar(done, total, width=20):
    k = max(0, min(width, round(width * done / total))) if total > 0 else 0
    return "█" * k + "░" * (width - k)


def lines(seat, conf_path=None, suites_path=None, stamp=True):
    top, sprints = read_conf(conf_path or CONF)
    if seat not in top.get("show", "").split():
        return []
    out = []
    for c in sprints:
        out += one_sprint(c, suites_path, stamp)
    return out


def one_sprint(c, suites_path=None, stamp=True):
    lang, name = c.get("lang", ""), c.get("name", "")
    if not lang:
        return []
    rows = read_rows(suites_path or SUITES, lang, c.get("keys", ""), c.get("nokeys", ""))
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
    npass, ntot = sum(p for _, p, _ in rows), sum(t for _, _, t in rows)
    head = f"▌ {bold(togo)} FAILING TESTS LEFT, of {bold(start)} at the start ▐" if start.isdigit() else f"▌ {bold(togo)} FAILING TESTS LEFT ▐"
    fixed = f"   {bar(int(start) - togo, int(start))}  {int(start) - togo} closed (cured or declared out)" if start.isdigit() else ""
    return [f"⏬ {name} SPRINT  {head}{fixed}  ·  {npass} of {ntot} {name} tests pass  ·  {at100} of {len(rows)} suites at 100%  ·  since {c.get('started', '?')}{when}",
            "   failing tests by suite: " + " · ".join(f"{n} {k}" for k, n in left)]


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
    want0 = "⏬ SNOBOL4 SPRINT  ▌ 𝟱 FAILING TESTS LEFT, of 𝟵 at the start ▐   █████████░░░░░░░░░░░  4 closed (cured or declared out)  ·  10 of 15 SNOBOL4 tests pass  ·  0 of 2 suites at 100%  ·  since 11-17 13:01"
    if o != [want0, "   failing tests by suite: Alpha 3 · Beta 2"]:
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
    if not (o and "▌ 𝟰 FAILING TESTS LEFT, of 𝟵 at the start ▐" in o[0] and "1 of 2 suites at 100%" in o[0] and o[1] == "   failing tests by suite: Beta 4"):
        bad.append(("up_again", o))                     # arm 5: a suite that falls back is counted again
    open(tsv, "w").write("# a comment line\n" + head + "\n" + "alpha\tSnoAlpha\tx\tsnobol4\td\t0\t0\td\t10\t10\th\n" + "gamma\tIcnGamma\tx\ticon\td\t0\t0\td\t8\t9\th\n"
                         + "uni_one\tUniOne\tx\ticon\td\t0\t0\td\t4\t7\th\n" + "rosetta-unicon\tUniRosetta\tx\ticon\td\t0\t0\td\t2\t2\th\n")
    open(conf, "w").write("show=cio coo\nname=SNOBOL4\nlang=snobol4\nstart=9\nstarted=13:01\nname=ICON\nlang=icon\nnokeys=^(uni|rosetta-unicon)\nstart=5\nstarted=12:5x\n"
                          "name=UNICON\nlang=icon\nkeys=^(uni|rosetta-unicon)\nstart=10\nstarted=15:01\n")
    o = lines("cio", conf, tsv, stamp=False)
    ok = (len(o) == 5 and o[0].startswith("🏁 SNOBOL4 SPRINT: ZERO.") and "▌ 𝟭 FAILING TESTS LEFT, of 𝟱 at the start ▐" in o[1] and "8 of 9 ICON tests pass" in o[1]
          and o[2] == "   failing tests by suite: IcnGamma 1" and "▌ 𝟯 FAILING TESTS LEFT, of 𝟭𝟬 at the start ▐" in o[3] and "6 of 9 UNICON tests pass" in o[3] and "1 of 2 suites at 100%" in o[3]
          and o[4] == "   failing tests by suite: One 3")
    if not ok:
        bad.append(("three_sprints", o))                # arm 6: three sprints in one file, two of them splitting one language by the suite key
    if lines("officer_04", conf, tsv, stamp=False) != []:
        bad.append(("three_sprints_seat_not_shown", "printed"))
    for name, got in bad:
        print(f"SPRINT_COUNTDOWN_PROBE RED arm={name} got={got!r}")
    print(f"SPRINT_COUNTDOWN_PROBE arms=6 red={len(bad)}")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--probe":
        sys.exit(probe())
    try:
        for ln in lines(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("S4E_SEAT", "")):
            print(ln)
    except Exception as ex:   # the banner is never lost to a countdown that could not be read
        print(f"Sprint countdown: unreadable ({type(ex).__name__})")
