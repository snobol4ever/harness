#!/usr/bin/env python3
"""util_logtalk_coinduction_cases.py -- the Logtalk ISO cases that exist only because coinduction is supported.

Row prolog-rational-trees-cyclic-term-unification-comparison-copy-and-write-so-the-logtalk-coinduction-branch-is-graded-as-supported
(cto, 2026-10-07). util_logtalk_extract.py decides `current_logtalk_flag(coinduction, supported)` TRUE (CEO-1518), so the
supported branch of every `:- if(...)` that names it is graded and its else branch is lgtunit-skipped. THE POPULATION is
DERIVED, never listed: parse the suite twice, once as shipped and once with that one conjunct answered FALSE; the cases the
second parse loses are the coinduction cases (68 at .github 179f31397 / corpus 044bbe6b9). A hand list would go stale the
day the suite moves.

    --list                 print group:case per line and the count
    --grade SCRIP [MODES]  grade every group holding one of them (util_logtalk_grade.py --group, a development aid, never a
                           board) in each mode (default m3,m4), each run under its own TMPDIR so its per-case rows are its
                           own; rc 0 when every coinduction case reads PASS in every mode, rc 1 naming each one that does
                           not, rc 2 when the population is empty or a group's rows cannot be read.
"""
import glob
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import util_logtalk_extract as ex  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "SCRIP", "..", "corpus", "packages", "prolog", "logtalk_iso"))
_COIND = re.compile(r"current_logtalk_flag\(\s*coinduction\s*,\s*supported\s*\)$")


def _cases():
    out = set()
    for p in sorted(glob.glob(os.path.join(ROOT, "**", "tests.lgt"), recursive=True)):
        fc = ex.parse_file(p)
        for c in fc.cases:
            out.add((fc.group, c.name))
    return out


def coinduction_cases():
    shipped = _cases()
    orig = ex._conjunct_value

    def answered_false(t):
        u = t.strip()
        while u.startswith("(") and ex._close_paren(u[1:]) == len(u) - 2:
            u = u[1:-1].strip()
        return False if _COIND.match(u) else orig(t)
    ex._conjunct_value = answered_false
    try:
        without = _cases()
    finally:
        ex._conjunct_value = orig
    return sorted(shipped - without)


def grade(scrip, modes):
    want = coinduction_cases()
    if not want:
        print("REFUSE(2): no coinduction case derived from %s" % ROOT)
        return 2
    seen = {}
    for g in sorted({g for g, _ in want}):
        with tempfile.TemporaryDirectory() as td:
            env = dict(os.environ, TMPDIR=td)
            subprocess.run([sys.executable, os.path.join(HERE, "util_logtalk_grade.py"), "--suite", ROOT, "--scrip", scrip,
                            "--modes", modes, "--group", g, "--jobs", "6"], env=env, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, timeout=900)
            rows = os.path.join(td, "logtalk_progress_rows.tsv")
            if not os.path.exists(rows):
                print("REFUSE(2): group %s wrote no per-case rows" % g)
                return 2
            for line in open(rows):
                f = line.rstrip("\n").split("\t")
                if len(f) >= 6:
                    seen[(f[3].split("#")[0], f[4])] = f[5]
    bad = []
    for g, c in want:
        for m in modes.split(","):
            v = seen.get(("%s:%s" % (g, c), m), "NO-ROW")
            if v != "PASS":
                bad.append("%s:%s:%s=%s" % (g, c, m, v))
    npass = len(want) * len(modes.split(",")) - len(bad)
    print("coinduction cases: %d; PASS %d of %d case-mode pairs (%s)" % (len(want), npass, len(want) * len(modes.split(",")), modes))
    for b in bad:
        print("  RED " + b)
    return 1 if bad else 0


def main(argv):
    if len(argv) >= 2 and argv[1] == "--list":
        w = coinduction_cases()
        for g, c in w:
            print("%s:%s" % (g, c))
        print("count %d" % len(w))
        return 0 if w else 2
    if len(argv) >= 3 and argv[1] == "--grade":
        return grade(argv[2], argv[3] if len(argv) > 3 else "m3,m4")
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
