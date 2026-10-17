#!/usr/bin/env python3
"""util_icon_package_units.py -- the units the three Icon package runners look up in their ALL.csv, and the rows they lack.

   python3 ../harness/scripts/util_icon_package_units.py keys    PKGDIR   # every key the runner looks up, one per line: key<TAB>unit source<TAB>graded executable
   python3 ../harness/scripts/util_icon_package_units.py missing PKGDIR   # the keys with no row, one per line; rc 1 when any, 0 when none, 2 unreadable
   python3 ../harness/scripts/util_icon_package_units.py rows    PKGDIR [--apply]   # the settings row each missing key is owed; --apply appends them

PKGDIR is corpus/packages/icon/{ipl,arizona_tests,jcon_tests} or a scratch package of the same shape; the package is read off its
basename. THE KEYS ARE THE RUNNERS' OWN (RULES.md 8 (f), CEO-1281: the runner reads each unit's command line from its row):
  ipl            test_icon_ipl_suite.sh: the compile tier looks up EVERY shipped .icn as parentdir/stem (drivers, ALL.icn and
                 *.fixtures/ out), and the run tier every .ref beside its .icn, a driver's under its library's key (CEO-1269).
  arizona_tests  test_icon_arizona_suite.sh: every .ref beside its .icn in general/ and special/ as sub/stem, a driver's under its
                 library's key; the staleness arm re-runs an outside-baseline unit by the same key.
  jcon_tests     test_icon_jcon_suite.sh: every .ref beside its .icn, flat, as the bare stem, a driver's under its library's name.
A key with no row is the gap: the runner would grade that unit at the runtime's defaults, which 8 (f) calls a false reading, and it
names it (declared_row_in_table, lib_declared_arena.sh). WHY THIS EXISTS: corpus 4d805e1bc (2026-09-25) gave every unit the runners
looked up a row, read off SCRIP_DECL_MISS_LOG over one full pass; the drivers of CEO-1269/1272 arrived after it and 382 graded units
(IPL 356, Arizona 23, Jcon 3) plus 275 IPL compile-tier files went rowless, unread until hq_icon asked where IPL iftrace's instrumentation switch
lives (2026-09-27). A settings row for an excluded unit is CEO-1261's shape: the identity check counts no row ALL.excluded.txt names.
The row a missing key is owed carries THE PACKAGE'S OWN DECLARATION, read off its table: the one (heap_kb, stack_kb, compile_args,
run_args) every row carries -- on 2026-09-27 SPITBOL's -d/-s written out (131072, 4096; corpus 4d805e1bc) and the instrumentation
switch the runners typed for every unit until SCRIP 286483382. A table whose rows disagree, or that has none, is refused: the owed
row would be a guess. Never typed here: a script that types the switch is test_gate_package_runners_read_each_units_declared_
compile_args.sh arm R's census, and this one only copies what the table already declares.
"""
import csv, glob, io, os, sys

SUBDIRS = {"arizona_tests": ("general", "special"), "jcon_tests": (".",)}


def keys(pkgdir):
    pkg = os.path.basename(os.path.normpath(pkgdir))
    want = {}
    if pkg == "ipl":
        for f in glob.glob(os.path.join(pkgdir, "*", "*.icn")):
            b = os.path.basename(f)
            if b == "ALL.icn" or b.endswith("_driver.icn") or ".fixtures" in f:
                continue
            want["%s/%s" % (os.path.basename(os.path.dirname(f)), b[:-4])] = (f, "")
        subs = sorted(s for s in os.listdir(pkgdir) if os.path.isdir(os.path.join(pkgdir, s)))
    elif pkg in SUBDIRS:
        subs = SUBDIRS[pkg]
    else:
        raise SystemExit("REFUSE(2): %s is none of ipl, arizona_tests, jcon_tests -- no runner's key rule is known for it" % pkgdir)
    for s in subs:
        for std in glob.glob(os.path.join(pkgdir, s, "*.ref")):
            b = os.path.basename(std)[:-4]
            if b == "ALL" or not os.path.exists(os.path.join(pkgdir, s, b + ".icn")):
                continue
            lib = b[:-len("_driver")] if b.endswith("_driver") else b
            key = lib if s == "." else "%s/%s" % (s, lib)
            want[key] = (os.path.join(pkgdir, s, lib + ".icn"), os.path.join(pkgdir, s, b + ".icn"))
    return pkg, want


def table(pkgdir):
    path = os.path.join(pkgdir, "ALL.csv")
    if not os.path.isfile(path):
        raise SystemExit("REFUSE(2): no attribute file at %s" % path)
    text = open(path, newline="").read()
    rows = list(csv.reader(io.StringIO(text)))
    if not rows or rows[0][:2] != ["rank", "entry"]:
        raise SystemExit("REFUSE(2): %s does not open with the rank,entry header" % path)
    return path, text, rows


def main(argv):
    if len(argv) < 3 or argv[1] not in ("keys", "missing", "rows"):
        print(__doc__.split("\n\n")[0]); return 2
    verb, pkgdir = argv[1], argv[2]
    pkg, want = keys(pkgdir)
    if verb == "keys":
        for k in sorted(want):
            print("%s\t%s\t%s" % (k, want[k][0], want[k][1]))
        return 0
    path, text, rows = table(pkgdir)
    have = {r[1] for r in rows[1:] if len(r) > 1}
    missing = sorted(k for k in want if k not in have)
    if verb == "missing":
        for k in missing:
            print(k)
        print("%s: %d looked-up unit(s), %d row(s), %d without a row" % (pkg, len(want), len(rows) - 1, len(missing)), file=sys.stderr)
        return 1 if missing else 0
    head = rows[0]
    try:
        cols = [head.index(c) for c in ("heap_kb", "stack_kb", "compile_args", "run_args")]
    except ValueError:
        raise SystemExit("REFUSE(2): %s lacks one of heap_kb, stack_kb, compile_args, run_args" % path)
    decls = {tuple(r[c] if c < len(r) else "" for c in cols) for r in rows[1:] if len(r) > 1}
    if len(decls) != 1:
        raise SystemExit("REFUSE(2): %s carries %d different declarations %s -- the row a missing unit is owed would be a guess"
                         % (path, len(decls), sorted(decls)[:4]))
    decl = decls.pop()
    rank = max([int(r[0]) for r in rows[1:] if r and r[0].isdigit()] or [0])
    out = io.StringIO()
    w = csv.writer(out, lineterminator="\n")
    for k in missing:
        src, exe = want[k]
        rank += 1
        stdin = "1" if exe and os.path.exists(exe[:-4] + ".dat") else "0"
        row = [str(rank), k, "%s__%s" % (pkg, k), pkg, str(open(src, "rb").read().count(b"\n")), stdin, "0", *decl]
        w.writerow(row + [""] * (len(head) - len(row)))
    sys.stdout.write(out.getvalue())
    if "--apply" in argv and missing:
        if not text.endswith("\n"):
            raise SystemExit("REFUSE(2): %s does not end in a newline -- appending would join two rows" % path)
        open(path, "w", newline="").write(text + out.getvalue())
        print("%s: %d settings row(s) appended" % (path, len(missing)), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
