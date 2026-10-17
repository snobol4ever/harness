#!/usr/bin/env python3
"""util_suite_table_language_verdict.py <lang> <base-scrip-hash> [--home DIR]

The home-stretch criterion (Lon 2026-09-23 14:1x, in-chat to the ceo, verbatim: "Each HQ should be on that same
task. The one task is all test suites to 100% for each language."): reads THE SUITE TABLE's machine record
(/home/resources/progress/SUITES.tsv, written by each runner through util_score_row.py) as it stands now
under the seat root, and grades ONE language: every row of that language must read today_pass == today_total > 0
AND carry a tree that is <base> or a descendant of it on the SCRIP clone's origin/main, so a stale full reading
cannot close the row and a fresh partial reading cannot either.  It runs no suite.  rc 0 GREEN, 1 RED, 2 REFUSE
(no row for the language, an unreadable table, or a missing clone).  Both clones are fetched first: a DONE-WHEN
is graded on origin/main, never on a working copy.
"""
import os
import re
import subprocess
import sys


def refuse(msg):
    print("REFUSE(2): " + msg)
    sys.exit(2)


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    home = os.environ.get("S4E_HOME") or os.path.dirname(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"))
    if "--home" in argv:
        home = argv[argv.index("--home") + 1]
    if len(args) != 2:
        refuse("usage: util_suite_table_language_verdict.py <lang> <base-scrip-hash>")
    lang, base = args
    scrip = os.path.join(home, "SCRIP")
    if not os.path.isdir(os.path.join(scrip, ".git")):
        refuse("no git clone at " + scrip)
    subprocess.run(["git", "-C", scrip, "fetch", "-q", "origin"], capture_output=True)
    if subprocess.run(["git", "-C", scrip, "rev-parse", "--verify", "-q", base + "^{commit}"], capture_output=True).returncode != 0:
        refuse("base " + base + " is not a commit in " + scrip)
    suites = os.environ.get("S4E_SUITES_TSV") or ("/home/resources/progress/SUITES.tsv" if re.fullmatch(r"/home/claude_[A-Za-z0-9_]+", os.path.realpath(home)) else os.path.join(home, ".github", "SUITES.tsv"))
    if not os.path.isfile(suites):
        refuse("cannot read the suite table at " + suites)
    rows = [l.split("\t") for l in open(suites, encoding="utf-8").read().splitlines() if l and not l.startswith("#")]
    rows = [r for r in rows if len(r) >= 11 and r[3] == lang]
    if not rows:
        refuse("no row of language " + lang + " in " + suites)
    bad = 0
    for r in rows:
        nick = r[1]
        try:
            p, t = int(r[8] or 0), int(r[9] or 0)
        except ValueError:
            p, t = -1, 0
        tree = r[10].strip()
        full = t > 0 and p == t
        fresh = bool(tree) and subprocess.run(["git", "-C", scrip, "merge-base", "--is-ancestor", base, tree], capture_output=True).returncode == 0
        print("SUITE %-8s %5d/%-5d tree=%-10s full=%s fresh=%s" % (nick, p, t, tree or "-", "yes" if full else "NO", "yes" if fresh else "NO"))
        if not (full and fresh):
            bad += 1
    if bad:
        print("RED: %d of %d %s suite(s) read below 100 percent or were graded on a tree before %s -- re-measure on origin HEAD and rewrite the row through util_score_row.py" % (bad, len(rows), lang, base))
        return 1
    print("GREEN: every %s suite (%d rows) reads 100 percent on a tree at or after %s" % (lang, len(rows), base))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
