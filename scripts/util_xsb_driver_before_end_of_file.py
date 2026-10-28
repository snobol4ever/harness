#!/usr/bin/env python3
"""util_xsb_driver_before_end_of_file.py -- THE DRIVER THE VENDORING APPENDS MUST COME BEFORE THE PROGRAM'S OWN `end_of_file.` (hq_icon 2026-10-28,
row prolog-xsbtests-to-100-the-58-failing-programs-ceo-1926).

THE DEFECT, MEASURED: 80 of the xsb_tests package's vendored programs end their own text with a clause `end_of_file.` -- XSB's consult stops reading at it,
and so does SCRIP's. The vendoring (CEO-700) appended each program's driver (`:- initialization(xsb_sorted_output((test)))`) AFTER that line, so SCRIP never
read it: the program ran no goal, printed nothing, and read FAIL against XSB's answer. Moving the driver to stand where `end_of_file.` stood runs the
goal exactly as XSB's `[FILE]. test.` does (the file's text up to the clause, then the goal); 17 programs (nine incremental_tests, three nonmt_tests, two
sub_tests and prolog_tests test_cleanup, uwoc, sub_tests test_answer_abstraction) read PASS in both modes from the move alone, with no other change.

  --check [PKGDIR]   read-only: name every vendored program, and every ALL.pl entry, whose driver follows an `end_of_file.` clause; rc 1 when any,
                     rc 0 when none, rc 2 when the package cannot be read (a census that cannot see its population never prints 0)
  --apply [PKGDIR]   move the driver in each such vendored file AND each such ALL.pl entry (the container is the files' text, entry for entry, so
                     the two change together and ALL.csv, ALL.ref and PARTITION.tsv do not: no entry is added, renamed or re-cut)

PKGDIR defaults to the sibling corpus: <harness>/../corpus/packages/prolog/xsb_tests.
"""
import argparse, csv, re, sys
from pathlib import Path

MARK = "\n% DRIVER (appended by the vendoring"
EOF_CLAUSE = re.compile(r"(?m)^end_of_file\.[ \t]*$")


def moved(text):
    """text with its appended driver standing where the program's first `end_of_file.` clause stood; text itself when the driver already precedes it,
    when there is no driver, or when the program has no such clause."""
    k = text.find(MARK)
    if k < 0:
        return text
    body, drv = text[:k + 1], text[k + 1:]
    m = EOF_CLAUSE.search(body)
    if not m:
        return text
    return body[:m.start()] + drv.rstrip("\n") + "\n" + body[m.start():]


def entries(pkg):
    """[(name, start, end)] spans of each entry's text inside ALL.pl, walked in ALL.csv's order by the exact separator `%-----... <n> <name>` (a program's own
    comment that resembles one cannot split it: the next separator expected is named)."""
    rows = list(csv.reader((pkg / "ALL.csv").open(encoding="utf-8", newline="")))
    names = [r[1] for r in rows[1:] if len(r) > 1]
    text = (pkg / "ALL.pl").read_text(encoding="utf-8", errors="surrogateescape")
    spans, pos = [], 0
    for i, n in enumerate(names, 1):
        m = re.compile(r"(?m)^%-+ " + str(i) + " " + re.escape(n) + r"\n").search(text, pos)
        if not m:
            print(f"⛔ REFUSE(rc=2): ALL.pl has no separator for entry {i} {n} after offset {pos}", file=sys.stderr)
            sys.exit(2)
        spans.append((n, m.start(), m.end()))
        pos = m.end()
    out = []
    for j, (n, s, e) in enumerate(spans):
        end = spans[j + 1][1] if j + 1 < len(spans) else len(text)
        out.append((n, e, end))
    return text, out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pkgdir", nargs="?", default=str(Path(__file__).resolve().parent.parent.parent / "corpus" / "packages" / "prolog" / "xsb_tests"))
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", action="store_true")
    g.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    pkg = Path(a.pkgdir)
    if not (pkg / "ALL.pl").is_file() or not (pkg / "ALL.csv").is_file():
        print(f"⛔ REFUSE(rc=2): {pkg} holds no ALL.pl / ALL.csv -- nothing measured")
        return 2
    text, ents = entries(pkg)
    todo_files, todo_entries, rebuilt = [], [], []
    last = 0
    for n, s, e in ents:
        rebuilt.append(text[last:s])
        body = text[s:e]
        nb = moved(body)
        if nb != body:
            todo_entries.append(n)
        rebuilt.append(nb)
        last = e
    rebuilt.append(text[last:])
    for f in sorted(pkg.glob("*.pl")):
        if f.name == "ALL.pl":
            continue
        t = f.read_text(encoding="utf-8", errors="surrogateescape")
        nt = moved(t)
        if nt != t:
            todo_files.append((f, nt))
    for f, _ in todo_files:
        print(f"driver follows end_of_file: {f.name}")
    for n in todo_entries:
        print(f"driver follows end_of_file: ALL.pl entry {n}")
    print(f"{len(todo_files)} vendored file(s), {len(todo_entries)} ALL.pl entr(ies) carry the driver after the program's end_of_file.")
    if a.check:
        return 1 if (todo_files or todo_entries) else 0
    for f, nt in todo_files:
        f.write_text(nt, encoding="utf-8", errors="surrogateescape")
    if todo_entries:
        (pkg / "ALL.pl").write_text("".join(rebuilt), encoding="utf-8", errors="surrogateescape")
    print(f"moved: {len(todo_files)} file(s), {len(todo_entries)} entr(ies)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
