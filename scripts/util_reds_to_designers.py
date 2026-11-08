#!/usr/bin/env python3
"""util_reds_to_designers.py -- DESIGN GOES DOWN BY ITSELF (COO-488, Lon 2026-11-08 13:4x: "Is this "design assign" and "task help escalation"
automatic? if not it needs be." / "the former goes down and the ladder goe up."; designed by officer_05).

After a grading of the ONE THING suite, every red entry that no live row reads becomes one design job in its area officer's seat tube.
  INPUTS   the reds:  util_score_row.py from-progress --suite SUITE --reds (S4E_MODES=m3), its SUITE_ROW board line first, then SUITE_ROW_RED lines;
           the areas: AREAS.tsv (entry_prefix TAB officer TAB note; first match wins; the line whose prefix is * is the fallback), kept by the
                      design's owner (officer_01 for UniTests, corpus/tests/icon/unicon/AREAS.tsv);
           the rows:  QUEUE.tsv and the batons: an entry is ROWED when a row whose state is not DONE has a DONE-WHEN: line naming the entry.
  OUTPUT   one line per unrowed red:  DESIGN_JOB entry=<e> officer=<o> topic=<t> reading=<mode>=<outcome>@<tree>
           then DOWN_BOARD suite=<s> reds=N rowed=N jobs=N (tree <harness hash>).
  --apply  mints each job: s4e_msg.sh mint <topic> 1 --to <officer> --stdin (the mint prints the WAKE line, which the caller sends).
           A topic already in QUEUE.tsv (any state but DONE) is never minted twice.
  --probe  runs the whole reading on planted inputs in a scratch dir and prints DOWN_PROBE; rc 0 only when it reads as designed.
rc 0 read; 1 never; 2 REFUSE (no board line from the score writer, no AREAS.tsv, no fallback line).
"""
import os, re, subprocess, sys, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PO = os.environ.get("S4E_POST", "/home/resources/postoffice")


def refuse(why):
    print("REFUSE(2): " + why); sys.exit(2)


def arg(name, default):
    a = sys.argv[1:]
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else default


def read_reds(text):
    if not re.search(r"^SUITE_ROW suite=", text, re.M): refuse("the score writer printed no SUITE_ROW board line: no reading, no jobs")
    reds = []
    for l in text.splitlines():
        m = re.match(r"^SUITE_ROW_RED (\S+) (.*)$", l)
        if m: reds.append((m.group(1), m.group(2).strip()))
    return reds


def read_areas(path):
    if not os.path.isfile(path): refuse("no area table %s" % path)
    rows = []
    for l in open(path, encoding="utf-8"):
        if not l.strip() or l.startswith("#"): continue
        c = l.rstrip("\n").split("\t")
        if len(c) < 2 or not c[0] or not c[1]: refuse("malformed area line in %s: %r" % (path, l))
        rows.append((c[0], c[1]))
    if not any(p == "*" for p, _ in rows): refuse("%s has no fallback line (prefix *)" % path)
    return rows


def officer_of(entry, areas):
    for p, o in areas:
        if p != "*" and entry.startswith(p): return o
    return [o for p, o in areas if p == "*"][0]


def live_rows(po):
    q = os.path.join(po, "QUEUE.tsv"); live = set(); topics = set()
    if not os.path.isfile(q): refuse("no %s" % q)
    for l in open(q, encoding="utf-8", errors="replace"):
        c = l.rstrip("\n").split("\t")
        if len(c) < 4 or l.startswith("#") or c[3].startswith("DONE"): continue
        topics.add(c[1]); live.add(c[1])
    dw = {}
    for t in live:
        try:
            for l in open(os.path.join(po, "tasks", t + ".task.md"), encoding="utf-8", errors="replace"):
                if l.startswith("DONE-WHEN:"): dw[t] = l; break
        except OSError: pass
    return topics, dw


def topic_of(suite, entry):
    return "%s-red-%s" % (suite, re.sub(r"[^a-z0-9]+", "-", entry.lower()).strip("-"))


def plan(suite, reds, areas, topics, dw):
    jobs, rowed = [], 0
    for e, reading in reds:
        pat = re.compile(r"(^|[^A-Za-z0-9_/])" + re.escape(e) + r"($|[^A-Za-z0-9_/])")
        t = topic_of(suite, e)
        if t in topics or any(pat.search(l) for l in dw.values()): rowed += 1; continue
        jobs.append((e, officer_of(e, areas), t, reading))
    return jobs, rowed


def body(suite, e, o, reading):
    q = '"${S4E_HOME:?REFUSE(2): S4E_HOME unset}"'
    rd = 'o="$(S4E_MODES=m3 python3 -I harness/scripts/util_score_row.py from-progress --suite %s --reds 2>&1)"' % suite
    have = "printf '%%s\\n' \"$o\" | grep -q '^SUITE_ROW suite=%s '" % suite
    red = "printf '%%s\\n' \"$o\" | grep -qE '^SUITE_ROW_RED %s '" % re.escape(e)
    return ("GOAL: DESIGN JOB, MADE BY ITSELF (COO-488): the %s entry %s reads red (%s) and no live row reads it. %s (its area officer by the area table) "
            "diagnoses it and cuts it under THE HAIKU BAR into tier-haiku, or parks this row BLOCKED-ON the row that already carries it.\n"
            "DONE-WHEN: cd %s && %s; %s && ! %s\n"
            "PREMISE-WHEN: cd %s && %s; %s && %s\n"
            "## NEXT\nDiagnose %s (monitor_run.sh against the oracle), then cut its cure under THE HAIKU BAR and queue it to tier-haiku with its WAKE.\n"
            % (suite, e, reading, o, q, rd, have, red, q, rd, have, red, e))


def run(suite, reds_text, areas_path, po, apply):
    reds = read_reds(reds_text); areas = read_areas(areas_path); topics, dw = live_rows(po)
    jobs, rowed = plan(suite, reds, areas, topics, dw)
    for e, o, t, rd in jobs: print("DESIGN_JOB entry=%s officer=%s topic=%s reading=%s" % (e, o, t, rd))
    tree = subprocess.run(["git", "-C", os.path.join(ROOT, "harness"), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    print("DOWN_BOARD suite=%s reds=%d rowed=%d jobs=%d (tree %s)" % (suite, len(reds), rowed, len(jobs), tree or "?"))
    if apply:
        for e, o, t, rd in jobs:
            p = subprocess.run(["bash", os.path.join(HERE, "s4e_msg.sh"), "mint", t, "1", "--to", o, "--stdin"], input=body(suite, e, o, rd),
                               capture_output=True, text=True)
            for l in (p.stdout + p.stderr).splitlines():
                if l.startswith(("minted ", "WAKE:", "queued ", "⛔")): print(l)
    return jobs, rowed


def probe():
    d = tempfile.mkdtemp(prefix="down_probe_")
    try:
        os.makedirs(os.path.join(d, "tasks"))
        with open(os.path.join(d, "AREAS.tsv"), "w") as f:
            f.write("# entry_prefix\tofficer\tnote\nthread/\tofficer_03\t\nposix/mcast\tofficer_08\t\ngeneral/\tofficer_07\t\n*\tofficer_01\tfallback\n")
        with open(os.path.join(d, "QUEUE.tsv"), "w") as f:
            f.write("# probe\n1\tlive-row\tjunior_02\tCLAIMED:junior_02\n1\tdone-row\tjunior_02\tDONE\n1\tunitests-red-pattern-p1\tofficer_02\tFREE\n")
        open(os.path.join(d, "tasks", "live-row.task.md"), "w").write("# TASK live-row\nDONE-WHEN: grep -q '^SUITE_ROW_RED general/ck ' x\n")
        open(os.path.join(d, "tasks", "done-row.task.md"), "w").write("# TASK done-row\nDONE-WHEN: grep -q '^SUITE_ROW_RED thread/t1 ' x\n")
        text = ("SUITE_ROW suite=unitests pass=5 total=10\nSUITE_ROW_RED general/ck m3=FAIL@a\nSUITE_ROW_RED general/ckx m3=FAIL@a\n"
                "SUITE_ROW_RED thread/t1 m3=ABORT@a\nSUITE_ROW_RED posix/mcast m3=FAIL@a\nSUITE_ROW_RED pattern/p1 m3=FAIL@a\nSUITE_ROW_RED unicon/u m3=FAIL@a\n")
        jobs, rowed = run("unitests", text, os.path.join(d, "AREAS.tsv"), d, False)
        got = sorted((e, o) for e, o, _, _ in jobs)
        want = sorted([("general/ckx", "officer_07"), ("thread/t1", "officer_03"), ("posix/mcast", "officer_08"), ("unicon/u", "officer_01")])
        ok = got == want and rowed == 2
        print("DOWN_PROBE jobs=%d rowed=%d first_match=%d fallback=%d done_row_ignored=%d ok=%d"
              % (len(jobs), rowed, int(("posix/mcast", "officer_08") in got), int(("unicon/u", "officer_01") in got), int(("thread/t1", "officer_03") in got), int(ok)))
        return ok
    finally:
        shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
    if "--probe" in sys.argv[1:]: sys.exit(0 if probe() else 1)
    suite = arg("--suite", "unitests")
    areas = arg("--areas", os.path.join(ROOT, "corpus", "tests", "icon", "unicon", "AREAS.tsv"))
    env = dict(os.environ, S4E_MODES="m3")
    p = subprocess.run([sys.executable, "-I", os.path.join(HERE, "util_score_row.py"), "from-progress", "--suite", suite, "--reds"],
                       capture_output=True, text=True, env=env, timeout=900)
    run(suite, p.stdout + p.stderr, areas, PO, "--apply" in sys.argv[1:])
    sys.exit(0)
