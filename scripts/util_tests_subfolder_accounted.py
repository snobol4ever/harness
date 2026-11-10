#!/usr/bin/env python3
"""util_tests_subfolder_accounted.py -- A SUBFOLDER OF A LANGUAGE FOLDER HAS LEFT, AND EVERY PROGRAM THAT STOOD IN IT IS ACCOUNTED FOR (officer_02
2026-11-10, CIO-56 (1) and (b): "a subfolder leaves in ONE landing together with every script the fate table names for it"; the criterion of each
subfolder row of the six clean-ups, so that a deletion alone cannot satisfy it).

usage: util_tests_subfolder_accounted.py --lang L --sub S --at COMMIT [--root S4E_HOME]
  COMMIT is a corpus commit at which corpus/tests/L/S held tracked files (the row's own measured base). Read at COMMIT and at the corpus HEAD:
  REMAINING   a file tracked under tests/L/S at HEAD                                         (each is RED)
  NAMING      a line of harness/scripts/* or SCRIP/Makefile that still names tests/L/S/       (each is RED)
  each PROGRAM tracked under tests/L/S at COMMIT is accounted by the first of
    ENTRY     a row of tests/L/ALL.csv (read by column name) whose entry is S__<stem> or whose family is S and whose entry or origin ends in <stem>
    OMIT      a key of tests/L/ALL.omit equal to <stem> or S_<stem> or ending _<stem>, its reason the builder's and not a KEEPER or DEFERRED
              deferral contract (CIO-24: a deferral contract ends; it accounts for nothing)
    MOVED     a file of the same name and the same bytes under harness/designs/, or harness/fixtures/ (a design's table, a fixture)
    DELETED   its path tests/L/S/<rel> written in a corpus commit message after COMMIT (the landing message names what it deletes)
    else UNACCOUNTED                                                                          (each is RED)
rc 0 GREEN: nothing remains, nothing names it, every program accounted; rc 1 RED, naming each; rc 2 REFUSE: no such commit, nothing tracked
there at COMMIT, no ALL.csv. It reads; it writes nothing and runs no program."""
import argparse, csv, os, subprocess, sys

PROG = {"icon": (".icn",), "snobol4": (".sno", ".spt", ".inc"), "prolog": (".pl", ".P", ".lgt"), "pascal": (".pas", ".pp", ".p"),
        "raku": (".raku", ".t", ".rakumod"), "snocone": (".sc",), "rebus": (".reb",)}


def refuse(m):
    print("REFUSE(2): " + m)
    sys.exit(2)


def git(repo, *a):
    p = subprocess.run(["git", "-C", repo] + list(a), capture_output=True, text=True)
    return p.returncode, p.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", required=True, choices=sorted(PROG))
    ap.add_argument("--sub", required=True)
    ap.add_argument("--at", required=True)
    ap.add_argument("--root", default=os.environ.get("S4E_HOME") or os.getcwd())
    a = ap.parse_args()
    root, sub = os.path.abspath(a.root), a.sub.strip("/")
    corpus = os.path.join(root, "corpus")
    rel = "tests/%s/%s/" % (a.lang, sub)
    rc, _ = git(corpus, "cat-file", "-e", a.at + "^{commit}")
    if rc:
        refuse("no corpus commit %s in %s" % (a.at, corpus))
    _, was = git(corpus, "ls-tree", "-r", "--name-only", a.at, "--", rel)
    was = [l for l in was.splitlines() if l]
    if not was:
        refuse("nothing was tracked under corpus/%s at %s" % (rel, a.at))
    _, now = git(corpus, "ls-files", "--", rel)
    now = [l for l in now.splitlines() if l]
    master = os.path.join(corpus, "tests", a.lang)
    idx = os.path.join(master, "ALL.csv")
    if not os.path.isfile(idx):
        refuse("no %s" % idx)
    with open(idx, newline="", encoding="utf-8", errors="replace") as f:
        rows = list(csv.DictReader(f))
    omit = {}
    op = os.path.join(master, "ALL.omit")
    if os.path.isfile(op):
        for l in open(op, encoding="utf-8", errors="replace"):
            if l.strip() and not l.startswith("#"):
                k, _, r = l.rstrip("\n").partition("\t")
                omit[k] = r
    moved = {}
    for d in (os.path.join(root, "harness", "designs"), os.path.join(root, "harness", "fixtures")):
        for dp, _, fs in os.walk(d):
            for x in fs:
                moved.setdefault(x, []).append(os.path.join(dp, x))
    _, msgs = git(corpus, "log", "--format=%B", a.at + "..HEAD")
    naming = []
    for base in (os.path.join(root, "harness", "scripts"),):
        for dp, _, fs in os.walk(base):
            for fn in fs:
                p = os.path.join(dp, fn)
                try:
                    for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
                        if rel in line:
                            naming.append("%s:%d" % (os.path.relpath(p, root), n))
                except OSError:
                    pass
    mk = os.path.join(root, "SCRIP", "Makefile")
    if os.path.isfile(mk):
        for n, line in enumerate(open(mk, encoding="utf-8", errors="replace"), 1):
            if rel in line:
                naming.append("SCRIP/Makefile:%d" % n)
    cnt = {"ENTRY": 0, "OMIT": 0, "MOVED": 0, "DELETED": 0, "UNACCOUNTED": 0}
    red = []
    for path in was:
        name = os.path.basename(path)
        stem, ext = os.path.splitext(name)
        if ext not in PROG[a.lang]:
            continue
        how = None
        for r in rows:
            e, fam, org = r.get("entry", ""), r.get("family", ""), r.get("origin", "")
            if e == "%s__%s" % (sub, stem) or (fam == sub and (e.endswith(stem) or org.endswith(stem))):
                how = "ENTRY " + e
                break
        if not how:
            for k in omit:
                if (k in (stem, "%s_%s" % (sub, stem)) or k.endswith("_" + stem)) and not omit[k].startswith(("KEEPER", "DEFERRED")):
                    how = "OMIT " + k
                    break
        if not how:
            b = subprocess.run(["git", "-C", corpus, "show", "%s:%s" % (a.at, path)], capture_output=True).stdout
            for q in moved.get(name, ()):
                if open(q, "rb").read() == b:
                    how = "MOVED " + os.path.relpath(q, root)
                    break
        if not how and path in msgs:
            how = "DELETED " + path
        kind = how.split()[0] if how else "UNACCOUNTED"
        cnt[kind] += 1
        if not how:
            red.append("UNACCOUNTED %s" % path)
    red += ["REMAINING %s" % p for p in now] + ["NAMING %s" % p for p in naming]
    _, head = git(corpus, "rev-parse", "--short=9", "HEAD")
    print("SUBFOLDER_BOARD lang=%s sub=%s at=%s programs=%d entry=%d omit=%d moved=%d deleted=%d unaccounted=%d remaining=%d naming=%d (corpus %s)"
          % (a.lang, sub, a.at, sum(cnt.values()), cnt["ENTRY"], cnt["OMIT"], cnt["MOVED"], cnt["DELETED"], cnt["UNACCOUNTED"], len(now), len(naming),
             head.strip()))
    for l in red:
        print(l)
    if red:
        print("GATE FAIL [util_tests_subfolder_accounted]: corpus/%s has not left, or a program of it is unaccounted" % rel)
        return 1
    print("GATE OK [util_tests_subfolder_accounted]: corpus/%s has left and every program of it is accounted" % rel)
    return 0


if __name__ == "__main__":
    sys.exit(main())
