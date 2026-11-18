#!/usr/bin/env python3
"""util_sprint_countdown.py SEAT -- THE SPRINT'S COUNTDOWN TO ZERO, two lines of the Stop banner (Lon 2026-11-17 14:3x CST, in the cio's window,
verbatim: "Since all the bugs are accounted for and assigned, install a stop-turn banner to show the countdown to ZERO."). The one banner script
every seat runs, s4e_banner_cached.sh, calls it with the seat's name and shows what it prints under the verdict word.
ONE FILE IS THE SWITCH: /home/resources/postoffice/SPRINT.conf, key=value a line, the cio's to set (skill fleet-bus section 1, a sprint):
    name=SNOBOL4               what the line calls the sprint
    lang=snobol4               the language column of the suite table whose rows are counted (SCRIP's rows only, never a port's key@engine row)
    start=107                  the bugs measured when the sprint was opened
    started=11-17 13:01        when that was measured (free text)
    show=chairman president grader cqo    the seats whose banner carries the lines; any other seat prints nothing
With no file, no lang, or a seat the show line does not name, it prints nothing and the banner is as it was. To end the countdown delete the file.
SEVERAL SPRINTS, ONE FILE (Lon 2026-11-17 17:0x CST, in the cio's window, verbatim: "Okay then, get the banner to show 3 sprints: SNOBOL4, Icon, and Unicon."): each name= line opens a sprint of its own, with its own
lang, start and started, and two optional lines that pick its suites by their key in the suite table: keys=REGEX (the key must match) and nokeys=REGEX (the key must not), so the Icon suites and the
Unicon suites, which share the language icon, are two sprints (keys=^(uni|rosetta-unicon) and nokeys= the same). The show line is the file's, for every sprint. A file with one name= reads as before.
ONE DB (Lon 2026-11-12, skill suites-and-grading section 3): the count is read from the same rows the grid and the summary by language read,
/home/resources/progress/SUITES.tsv: a bug is an entry of a suite of the language that the row's newest reading does not pass, today_total less
today_pass, so the countdown moves when the cycle rewrites a row and never before, and it can go up as well as down. Read only, nothing run.
THE WHOLE COUNT (Lon 2026-11-18 11:5x CST, in the chairman's window; he had asked "Figure out why the Icon and Unicon will not converge to zero failures. Do we have a design flaw?", was shown that
the count of failing entries rises each time excluded programs are released into the suites while cures hold (Icon 134 cures against 6 passing tests gone red, Unicon 278 against 3, since 11-17 noon), and
said, verbatim: "do as you suggest regarding reporting." and "since they are NOT actually sprints add Prolog."): a name= block that carries a debt= line is shown in the whole form, three piles and their sum:
    failing           entries whose newest mode 3 reading in the store (results.tsv) is not PASS, never more than the suite row's total less pass
    not yet graded    the rest of total less pass: entries on the suite table the cycle has not read since they were cut
    excluded          the row's today_excluded, less the rows of the package's EXCLUDED.tsv whose class is settled (settled= of the switch file, or SETTLED below: a cross-reference to another
                      package's entry, a program no oracle answers, a ruling of Lon's by name); a suite with no class file counts every excluded program
TO GO is their sum, so a program released from the excluded pile moves between two piles and the sum does not move; it falls at a cure and rises only when a program is added, said beside it as added.
    debt=402 all=3801 debt_started=11-18 12:1x      the sum, and total plus counted excluded, when the whole count was opened (python3 -I util_sprint_countdown.py --baseline prints the lines)
A block with no debt= line reads in the old form, byte for byte. The word SPRINT is not said in the whole form.
  python3 -I util_sprint_countdown.py SEAT      the two lines, or nothing; rc 0
  python3 -I util_sprint_countdown.py --baseline   each block's debt= all= line as measured now; rc 0
  python3 -I util_sprint_countdown.py --probe   seven arms on a scratch table and a scratch switch; rc 0 green, rc 1 red"""
import os, sys, tempfile, time

CONF = os.environ.get("S4E_SPRINT_CONF", "/home/resources/postoffice/SPRINT.conf")
SUITES = os.environ.get("S4E_SUITES_TSV", "/home/resources/progress/SUITES.tsv")
STORE = os.environ.get("S4E_RESULTS_TSV", "/home/resources/progress/results.tsv")
RUNNERS = os.environ.get("S4E_SUITE_RUNNERS", os.path.join(os.path.dirname(os.path.abspath(__file__)), "SUITE_RUNNERS.tsv"))
CORPUS = os.environ.get("S4E_CORPUS", "/home/corpus")
SETTLED = "GRADED_IN_ANOTHER_PACKAGE NO_ORACLE_ANSWER NOT_SPITBOL_DIALECT SCRIP_EXTENSION_KEPT_BY_LON SCRIP_EXCEEDS_ORACLE FAKEABLE_NO_OBSERVABLE *_BY_LON"


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
    if "debt" in c:
        return whole_count(c, suites_path, stamp)
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


def read_suites(path, lang, keys="", nokeys=""):
    """-> [(key, nick, pass, total, excluded)] of the language's own rows"""
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
        k = r.get("key", "")
        if r.get("lang") != lang or "@" in k or (keys and not re.search(keys, k)) or (nokeys and re.search(nokeys, k)):
            continue
        try:
            p, t = int(r.get("today_pass") or 0), int(r.get("today_total") or 0)
        except ValueError:
            continue
        x = (r.get("today_excluded") or "").strip()
        rows.append((k, r.get("nick") or k, p, t, int(x) if x.isdigit() else 0))
    return rows


_RED = {}


def store_reds(path):
    """-> {suite key: entries whose mode 3 reading is neither PASS nor a named leave (UNGRADED, SKIP)}; read once a process, {} when the store cannot be read"""
    if path not in _RED:
        d = {}
        try:
            for ln in open(path, encoding="utf-8", errors="replace"):
                c = ln.split("\t", 10)
                if len(c) > 9 and c[8] == "m3" and c[9] not in ("PASS", "UNGRADED", "SKIP", "outcome"):
                    d[c[5]] = d.get(c[5], 0) + 1
        except OSError:
            pass
        _RED[path] = d
    return _RED[path]


_DIR = {}


def settled_count(key, words, runners=None, corpus=None):
    """-> the rows of the suite's EXCLUDED.tsv whose class is one of words (a word *TAIL matches by its end); 0 when the suite has no class file"""
    runners, corpus = runners or RUNNERS, corpus or CORPUS
    if runners not in _DIR:
        d = {}
        try:
            for ln in open(runners, encoding="utf-8", errors="replace"):
                c = ln.rstrip("\n").split("\t")
                if not ln.startswith("#") and len(c) >= 5 and c[4].startswith("corpus/"):
                    d[c[0]] = c[4][len("corpus/"):]
        except OSError:
            pass
        _DIR[runners] = d
    rel = _DIR[runners].get(key)
    if not rel:
        return 0
    n = 0
    try:
        for ln in open(os.path.join(corpus, rel, "EXCLUDED.tsv"), encoding="utf-8", errors="replace"):
            c = ln.split("\t")
            if ln.startswith("#") or len(c) < 2:
                continue
            k = c[1].strip()
            if any(k == w or (w.startswith("*") and k.endswith(w[1:])) for w in words):
                n += 1
    except OSError:
        return 0
    return n


def piles(c, suites_path=None, store=None, runners=None, corpus=None):
    """-> [(nick, pass, total, failing, not yet graded, excluded counted, excluded settled)] a suite"""
    words = (c.get("settled") or SETTLED).split()
    red = store_reds(store or STORE)
    out = []
    for key, nick, p, t, x in read_suites(suites_path or SUITES, c.get("lang", ""), c.get("keys", ""), c.get("nokeys", "")):
        f = min(max(t - p, 0), red.get(key, 0))
        s = min(x, settled_count(key, words, runners, corpus))
        out.append((nick, p, t, f, max(t - p, 0) - f, x - s, s))
    return out


def whole_count(c, suites_path=None, stamp=True, store=None, runners=None, corpus=None):
    name = c.get("name") or c.get("lang", "")
    rows = piles(c, suites_path, store, runners, corpus)
    if not rows:
        return [f"{name}: the suite table holds no row of language {c.get('lang', '')}"]
    fail, wait, excl, aside = (sum(r[i] for r in rows) for i in (3, 4, 5, 6))
    togo, allnow = fail + wait + excl, sum(r[2] for r in rows) + excl
    npass, ntot = sum(r[1] for r in rows), sum(r[2] for r in rows)
    at100 = sum(1 for r in rows if r[1] == r[2] and r[2] > 0)
    when = time.strftime("   [%m-%d %H:%M %Z]") if stamp else ""
    d0, a0 = c.get("debt", ""), c.get("all", "")
    since = c.get("debt_started", "?")
    added = max(0, allnow - int(a0)) if a0.isdigit() else 0
    prog = ""
    if d0.isdigit():
        base = int(d0) + added
        done = base - togo
        prog = f"   {bar(done, base)}  {done} done of {base} since {since}" + (f" (+{added} programs added)" if added else "")
    side = f" ({aside} more set aside by ruling)" if aside else ""
    if togo == 0:
        return [f"🏁 {name}: ZERO. Nothing failing, nothing waiting to be graded, nothing excluded{side}; {npass} of {ntot} tests pass in {len(rows)} suites.{prog}{when}"]
    pre = os.path.commonprefix([r[0] for r in rows]) if len(rows) > 1 else ""
    def by(i, most=6):
        v = sorted(((r[i], r[0][len(pre):] or r[0]) for r in rows if r[i] > 0), key=lambda x: (-x[0], x[1]))
        return (" · ".join(f"{n} {k}" for k, n in v[:most]) + (f" · {len(v) - most} more suites {sum(k for k, _ in v[most:])}" if len(v) > most else "")) or "none"
    return [f"⏬ {name}  ▌ {bold(togo)} TO GO ▐  failing {bold(fail)} · not yet graded {bold(wait)} · excluded {bold(excl)}{side}{prog}  ·  {npass} of {ntot} graded tests pass  ·  {at100} of {len(rows)} suites at 100%{when}",
            f"   failing: {by(3)}  |  not yet graded: {by(4)}  |  excluded: {by(5)}"]


def baseline(conf_path=None, suites_path=None):
    """the debt= all= line of each block as measured now, for the switch file"""
    _, sprints = read_conf(conf_path or CONF)
    for c in sprints:
        rows = piles(c, suites_path)
        excl = sum(r[5] for r in rows)
        print(f"name={c.get('name', '')}\tdebt={sum(r[3] + r[4] for r in rows) + excl}\tall={sum(r[2] for r in rows) + excl}\tfailing={sum(r[3] for r in rows)}\tnot_yet_graded={sum(r[4] for r in rows)}\texcluded={excl}\tset_aside={sum(r[6] for r in rows)}")
    return 0


def probe():
    d = tempfile.mkdtemp(prefix="sprint_countdown_probe_")
    tsv, conf = os.path.join(d, "SUITES.tsv"), os.path.join(d, "SPRINT.conf")
    head = "key\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree"
    def table(a, b):
        open(tsv, "w").write("# a comment line\n" + head + "\n" + f"alpha\tSnoAlpha\tx\tsnobol4\td\t0\t0\td\t{a}\t10\th\n" + f"beta\tSnoBeta\tx\tsnobol4\td\t0\t0\td\t{b}\t5\th\n"
                             + "alpha@jvm\tSnoAlpha\tx\tsnobol4\td\t0\t0\td\t0\t10\th\n" + "gamma\tIcnGamma\tx\ticon\td\t0\t0\td\t1\t9\th\n")
    open(conf, "w").write("# the switch\nname=SNOBOL4\nlang=snobol4\nstart=9\nstarted=11-17 13:01\nshow=chairman president\n")
    bad = []
    table(7, 3)
    o = lines("chairman", conf, tsv, stamp=False)
    want0 = "⏬ SNOBOL4 SPRINT  ▌ 𝟱 FAILING TESTS LEFT, of 𝟵 at the start ▐   █████████░░░░░░░░░░░  4 closed (cured or declared out)  ·  10 of 15 SNOBOL4 tests pass  ·  0 of 2 suites at 100%  ·  since 11-17 13:01"
    if o != [want0, "   failing tests by suite: Alpha 3 · Beta 2"]:
        bad.append(("counts", o))                       # arm 1: the count, the port row and the other language left out, the names shortened
    if lines("officer_04", conf, tsv, stamp=False) != []:
        bad.append(("seat_not_shown", "printed"))       # arm 2: a seat the show line does not name prints nothing
    if lines("chairman", os.path.join(d, "none.conf"), tsv, stamp=False) != []:
        bad.append(("no_switch", "printed"))            # arm 3: no switch file, nothing
    table(10, 5)
    o = lines("president", conf, tsv, stamp=False)
    if o != ["🏁 SNOBOL4 SPRINT: ZERO. Every one of the 2 suites reads 100% of 9 at the start (11-17 13:01)."]:
        bad.append(("zero", o))                         # arm 4: zero is said as zero
    table(10, 1)
    o = lines("chairman", conf, tsv, stamp=False)
    if not (o and "▌ 𝟰 FAILING TESTS LEFT, of 𝟵 at the start ▐" in o[0] and "1 of 2 suites at 100%" in o[0] and o[1] == "   failing tests by suite: Beta 4"):
        bad.append(("up_again", o))                     # arm 5: a suite that falls back is counted again
    open(tsv, "w").write("# a comment line\n" + head + "\n" + "alpha\tSnoAlpha\tx\tsnobol4\td\t0\t0\td\t10\t10\th\n" + "gamma\tIcnGamma\tx\ticon\td\t0\t0\td\t8\t9\th\n"
                         + "uni_one\tUniOne\tx\ticon\td\t0\t0\td\t4\t7\th\n" + "rosetta-unicon\tUniRosetta\tx\ticon\td\t0\t0\td\t2\t2\th\n")
    open(conf, "w").write("show=chairman president\nname=SNOBOL4\nlang=snobol4\nstart=9\nstarted=13:01\nname=ICON\nlang=icon\nnokeys=^(uni|rosetta-unicon)\nstart=5\nstarted=12:5x\n"
                          "name=UNICON\nlang=icon\nkeys=^(uni|rosetta-unicon)\nstart=10\nstarted=15:01\n")
    o = lines("chairman", conf, tsv, stamp=False)
    ok = (len(o) == 5 and o[0].startswith("🏁 SNOBOL4 SPRINT: ZERO.") and "▌ 𝟭 FAILING TESTS LEFT, of 𝟱 at the start ▐" in o[1] and "8 of 9 ICON tests pass" in o[1]
          and o[2] == "   failing tests by suite: IcnGamma 1" and "▌ 𝟯 FAILING TESTS LEFT, of 𝟭𝟬 at the start ▐" in o[3] and "6 of 9 UNICON tests pass" in o[3] and "1 of 2 suites at 100%" in o[3]
          and o[4] == "   failing tests by suite: One 3")
    if not ok:
        bad.append(("three_sprints", o))                # arm 6: three sprints in one file, two of them splitting one language by the suite key
    if lines("officer_04", conf, tsv, stamp=False) != []:
        bad.append(("three_sprints_seat_not_shown", "printed"))
    # arm 7, the whole count: three piles and their sum; a release moves a program between piles and the sum stands; a cure lowers it; an added program is said; zero is said as zero
    store, runners, corp = os.path.join(d, "results.tsv"), os.path.join(d, "RUNNERS.tsv"), os.path.join(d, "corpus")
    os.makedirs(os.path.join(corp, "packages/icon/gamma"))
    open(runners, "w").write("# the runner table\ngamma\tpkg\ticon\tcorpus_suite_harness.py\tcorpus/packages/icon/gamma\n")
    open(os.path.join(corp, "packages/icon/gamma/EXCLUDED.tsv"), "w").write("# classes\na\tGRADED_IN_ANOTHER_PACKAGE\tgraded as ipl entry a\nb\tNOT_A_UNIT_TEST\tx\nc\tNEEDS_NETWORK\tx\nd\tTHREADS_EXCLUDED_BY_LON\tx\n")
    h2 = head + "\tcriterion_changed\ttoday_excluded"
    def whole(p, t, x, reds, conf_more=""):
        open(tsv, "w").write(h2 + "\n" + f"gamma\tIcnGamma\tx\ticon\td\t0\t0\td\t{p}\t{t}\th\t\t{x}\n" + "delta\tIcnDelta\tx\ticon\td\t0\t0\td\t5\t5\th\t\t\n")
        open(store, "w").write("ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\n" + "".join(f"t\ts\tc\tg\tpkg\tgamma\ticon\tp{i}\tm3\tFAIL\t1\n" for i in range(reds))
                          + "t\ts\tc\tg\tpkg\tgamma\ticon\tq\tm4\tFAIL\t1\n" + "t\ts\tc\tg\tpkg\tgamma\ticon\tu\tm3\tUNGRADED\t1\n")
        _RED.clear(); _DIR.clear()
        _, sp = read_conf(conf)
        return whole_count(sp[0], tsv, False, store, runners, corp)
    open(conf, "w").write("show=chairman\nname=ICON\nlang=icon\ndebt=7\nall=16\ndebt_started=11-18 12:1x\n")
    o1 = whole(6, 9, 4, 2)          # 3 not passing: 2 measured, 1 not yet graded; 4 excluded, 2 of them settled
    w1 = "⏬ ICON  ▌ 𝟱 TO GO ▐  failing 𝟮 · not yet graded 𝟭 · excluded 𝟮 (2 more set aside by ruling)   ██████░░░░░░░░░░░░░░  2 done of 7 since 11-18 12:1x  ·  11 of 14 graded tests pass  ·  1 of 2 suites at 100%"
    if o1 != [w1, "   failing: Gamma 2  |  not yet graded: Gamma 1  |  excluded: Gamma 2"]:
        bad.append(("whole_count", o1))
    o2 = whole(6, 10, 3, 2)         # one excluded program released into the suite, not yet graded: the sum stands at 5
    if not (o2 and "▌ 𝟱 TO GO ▐  failing 𝟮 · not yet graded 𝟮 · excluded 𝟭" in o2[0] and "2 done of 7" in o2[0]):
        bad.append(("release_moves_no_sum", o2))
    o3 = whole(6, 11, 3, 3)         # a program added to the suite, failing: said as added, the sum up by one and the done count as it was
    if not (o3 and "▌ 𝟲 TO GO ▐" in o3[0] and "2 done of 8 since 11-18 12:1x (+1 programs added)" in o3[0]):
        bad.append(("added_is_said", o3))
    os.remove(os.path.join(corp, "packages/icon/gamma/EXCLUDED.tsv"))
    open(os.path.join(corp, "packages/icon/gamma/EXCLUDED.tsv"), "w").write("a\tGRADED_IN_ANOTHER_PACKAGE\tgraded as ipl entry a\n")
    o4 = whole(9, 9, 1, 0)
    if not (len(o4) == 1 and o4[0].startswith("🏁 ICON: ZERO. Nothing failing, nothing waiting to be graded, nothing excluded (1 more set aside by ruling); 14 of 14 tests pass in 2 suites.")):
        bad.append(("whole_zero", o4))
    for name, got in bad:
        print(f"SPRINT_COUNTDOWN_PROBE RED arm={name} got={got!r}")
    print(f"SPRINT_COUNTDOWN_PROBE arms=7 red={len(bad)}")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--probe":
        sys.exit(probe())
    if len(sys.argv) > 1 and sys.argv[1] == "--baseline":
        sys.exit(baseline())
    try:
        for ln in lines(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("S4E_SEAT", "")):
            print(ln)
    except Exception as ex:   # the banner is never lost to a countdown that could not be read
        print(f"Sprint countdown: unreadable ({type(ex).__name__})")
