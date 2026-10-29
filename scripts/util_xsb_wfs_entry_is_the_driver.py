#!/usr/bin/env python3
"""util_xsb_wfs_entry_is_the_driver.py -- A wfs_tests ENTRY IS THE PROGRAM XSB RUNS: THE DRIVER, WITH THE EXAMPLE CONSULTED AT RUN TIME (hq_packages 2026-10-28,
ceo CEO-2005, DESIGN-PLAN xsb-tabling-wfs step 2, ARCH-PROLOG-WFS-TABLING.md section 8 R2).

THE DEFECT, MEASURED: XSB's wfs_tests/test.sh runs `./gentest.sh wfs_test pNN "test(pNN)."`, that is `[wfs_test]. test(pNN). told.`: the driver wfs_test.P is the
program, and test/1 consults pNN.P itself. The vendoring (CEO-700) wrote each entry as the example's own clauses (query/5, the :- table, the rules) followed by
`:- initialization((consult(wfs_test), test(pNN), told))`, so the entry defined the example's predicates statically and test/1's consult(pNN) then asserted them
a second time: permission_error(modify, static_procedure, query/5) and '$tbl p'/0, the driver printed nothing, and 72 entries read FAIL against XSB's answer
(wfs_tests_p06: 0 of 4 lines). The entry is now the driver's text followed by `:- initialization((test(pNN), told)).`, the example staged beside as today (STAGED.tsv
stage=upstream, answer=temp-sorted; stage_upstream writes pNN.P and pNN.pl from the vendored file's text up to its DRIVER mark). The refs do not move: they are XSB's temp.

  --check [PKGDIR]   read-only: name every ALL.pl entry whose ORACLE_RUNS.tsv kind is wfs and whose text is not the driver form; rc 1 when any, rc 0 when none, rc 2 when the
                     package cannot be read
  --apply [PKGDIR]   rewrite those entries in ALL.pl, recompute their n_lines and feature columns in ALL.csv (the builder's own attrs_for_text), and rebuild PARTITION.tsv
                     (util_suite_partition.py build): the vendored per-file text stays, it is the staged example

util_build_package_suite.py calls wfs_entry_text() when it absorbs a wfs entry, so a rebuild writes the same text.
PKGDIR defaults to the sibling corpus: <harness>/../corpus/packages/prolog/xsb_tests.
"""
import argparse, csv, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
MARK = "\n% DRIVER (appended by the vendoring"
DRIVER_FILE = "wfs_tests_wfs_test.pl"


def wfs_runs(pkg):
    """{entry name: goal} for each ORACLE_RUNS.tsv row of kind wfs (the goal is the row's cmd without its final dot: test(p06))."""
    rf = pkg / "ORACLE_RUNS.tsv"
    out = {}
    for line in rf.read_text(encoding="utf-8").splitlines():
        f = line.split("\t")
        if len(f) == 7 and not line.startswith("#") and f[2] == "wfs":
            out[f[0]] = f[4].rstrip().rstrip(".")
    return out


def driver_source(pkg):
    """wfs_test.P's text as vendored (its appended driver, if the file carries one, cut off), ending in one newline."""
    t = (pkg / DRIVER_FILE).read_text(encoding="utf-8", errors="surrogateescape")
    k = t.find(MARK)
    if k >= 0:
        t = t[:k + 1]
    return t.rstrip("\n") + "\n"


def wfs_entry_text(pkg, name, goal):
    """The entry for wfs program NAME: the driver, then the vendoring's trailer that runs the goal and closes temp."""
    prog = name[len("wfs_tests_"):] if name.startswith("wfs_tests_") else name
    return (driver_source(pkg) + MARK + f", CEO-700; CEO-1927; R2 of ARCH-PROLOG-WFS-TABLING.md): XSB wfs_tests/test.sh runs ./gentest.sh wfs_test {prog} \"{goal}.\" -- "
            f"the driver wfs_test.P is the program and {prog}.P is consulted at run time from the staged upstream directory; the answer is the file temp (STAGED.tsv answer=temp-sorted)\n"
            f":- initialization(({goal}, told)).\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", action="store_true")
    g.add_argument("--apply", action="store_true")
    ap.add_argument("pkgdir", nargs="?", default=str(HERE.parent.parent / "corpus" / "packages" / "prolog" / "xsb_tests"))
    a = ap.parse_args()
    pkg = Path(a.pkgdir)
    try:
        import util_xsb_driver_before_end_of_file as u
        runs = wfs_runs(pkg)
        text, ents = u.entries(pkg)
    except (OSError, SystemExit) as e:
        print(f"⛔ REFUSE(rc=2): the package cannot be read: {e}", file=sys.stderr)
        return 2
    if not runs:
        print("⛔ REFUSE(rc=2): ORACLE_RUNS.tsv names no wfs run -- a census that cannot see its population never prints 0", file=sys.stderr)
        return 2
    todo = [(n, s, e) for n, s, e in ents if n in runs and text[s:e] != wfs_entry_text(pkg, n, runs[n])]
    seen = [n for n, s, e in ents if n in runs]
    print(f"WFS entries in ALL.pl: {len(seen)} of {len(runs)} runs; not the driver form: {len(todo)}")
    for n, s, e in todo[:200]:
        print("  " + n)
    if a.check:
        return 1 if todo else 0
    if not todo:
        return 0
    out, pos = [], 0
    for n, s, e in todo:
        out.append(text[pos:s])
        out.append(wfs_entry_text(pkg, n, runs[n]))
        pos = e
    out.append(text[pos:])
    (pkg / "ALL.pl").write_text("".join(out), encoding="utf-8", errors="surrogateescape")
    import util_build_rungs_suite as m
    rows = list(csv.reader((pkg / "ALL.csv").open(encoding="utf-8", newline="")))
    head = rows[0]
    col = {c: i for i, c in enumerate(head)}
    names = {n for n, s, e in todo}
    for r in rows[1:]:
        if r[col["entry"]] in names:
            body = wfs_entry_text(pkg, r[col["entry"]], runs[r[col["entry"]]])
            r[col["n_lines"]] = str(len(body.splitlines()))
            for c, v in m.attrs_for_text(body.rstrip("\n"), "prolog").items():
                if c in col:
                    r[col[c]] = str(v)
    with (pkg / "ALL.csv").open("w", encoding="utf-8", newline="") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)
    subprocess.run([sys.executable, str(HERE / "util_suite_partition.py"), "build", str(pkg / "ALL.csv")], check=True)
    print(f"rewrote {len(todo)} entries of ALL.pl, their ALL.csv rows, and PARTITION.tsv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
