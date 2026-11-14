#!/usr/bin/env python3
# util_grade_cell.py -- THE DECLARED BUDGET OF A GRADING CELL (DESIGN-PLAN test-cycle step 6; CTO-522; skill suites-and-grading section 7).
# --night-only  reads the seven masters and the 25 package tables and the LAST reading of every (lang, program, mode) in the progress
#               store, then prints  NIGHT_ONLY over_s=300 programs=K of M  (M the entries of every table, K those whose last reading in
#               either mode took over 300 s) and one NIGHT_ONLY_ENTRY line per night-only entry. rc 0 measured; rc 2 cannot read.
# --stamp       writes the timeout_s column, the third declared size beside heap_kb and stack_kb: 3600 for a night-only entry, 300 for
#               every other. A table that already carries the column has its values replaced; every other cell is read back and compared
#               before the file is written, so a stamp that would change a cell refuses rc 2 and writes nothing.
import csv
import io
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harness_paths as HP

DAY_S = 300
NIGHT_S = 3600
MASTERS = ("snobol4", "icon", "prolog", "pascal", "raku", "snocone", "rebus")
MODES = ("m3", "m4")


def refuse(msg):
    print("REFUSE(2) [util_grade_cell]: " + msg, file=sys.stderr)
    sys.exit(2)


def tables(corpus):
    out = []
    for lang in MASTERS:
        p = corpus / "tests" / lang / "ALL.csv"
        if not p.is_file():
            refuse(f"no master table {p}")
        out.append((lang, p))
    for p in sorted((corpus / "packages").glob("*/*/ALL.csv")):
        out.append((p.parent.parent.name, p))
    if len(out) != 32:
        refuse(f"expected 7 masters and 25 package tables, found {len(out)}")
    return out


def last_readings(progress):
    if not progress.is_file():
        refuse(f"no progress store at {progress}")
    last = {}
    with open(progress, encoding="utf-8", errors="replace") as f:
        next(f, None)
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) < 11 or c[8] not in MODES:
                continue
            try:
                last[(c[6], c[7], c[8])] = float(c[10])
            except ValueError:
                continue
    return last


def night_set(last):
    return {(lang, prog) for (lang, prog, _mode), secs in last.items() if secs > DAY_S}


def read_table(p):
    with open(p, newline="", encoding="utf-8") as f:
        return list(csv.reader(f))


def report(corpus, progress):
    night = night_set(last_readings(progress))
    m = 0
    k = []
    for lang, p in tables(corpus):
        rows = read_table(p)
        head = rows[0]
        if "entry" not in head:
            refuse(f"{p} has no entry column")
        ei = head.index("entry")
        for r in rows[1:]:
            m += 1
            if (lang, r[ei]) in night:
                k.append(f"NIGHT_ONLY_ENTRY {lang} {p.parent.relative_to(corpus)} {r[ei]}")
    print(f"NIGHT_ONLY over_s={DAY_S} programs={len(k)} of {m}")
    for line in k:
        print(line)
    return 0


def stamp(corpus, progress):
    night = night_set(last_readings(progress))
    plan = []
    stamped_night = []
    for lang, p in tables(corpus):
        rows = read_table(p)
        head = rows[0]
        if "entry" not in head:
            refuse(f"{p} has no entry column")
        ei = head.index("entry")
        if "timeout_s" in head:
            ti = head.index("timeout_s")
            new_head, new_rows = list(head), [list(r) for r in rows[1:]]
        else:
            anchors = [head.index(c) for c in ("heap_kb", "stack_kb") if c in head]
            ti = (max(anchors) + 1) if anchors else len(head)
            new_head = head[:ti] + ["timeout_s"] + head[ti:]
            new_rows = [r[:ti] + [""] + r[ti:] for r in rows[1:]]
        if any(len(r) != len(head) for r in rows[1:]):
            refuse(f"{p}: a row does not carry the header's {len(head)} cells")
        for r in new_rows:
            r[ti] = str(NIGHT_S if (lang, r[ei]) in night else DAY_S)
        stamped_night.append(sum(1 for r in new_rows if r[ti] == str(NIGHT_S)))
        back = [new_head[:ti] + new_head[ti + 1:]] + [r[:ti] + r[ti + 1:] for r in new_rows]
        base = [head[:ti] + head[ti + 1:]] + [r[:ti] + r[ti + 1:] for r in rows[1:]] if "timeout_s" in head else rows
        if back != base:
            refuse(f"{p}: the stamp would change a cell other than timeout_s; nothing written")
        plan.append((p, new_head, new_rows))
    buf = {}
    for p, new_head, new_rows in plan:
        out = io.StringIO()
        w = csv.writer(out, lineterminator="\n")
        w.writerow(new_head)
        w.writerows(new_rows)
        buf[p] = out.getvalue()
    for p, text in buf.items():
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(text)
    n = sum(len(r) for _p, _h, r in plan)
    print(f"STAMPED tables={len(plan)} entries={n} night_only={sum(stamped_night)} timeout_s day={DAY_S} night={NIGHT_S}")
    return 0


def main(argv):
    corpus = HP.corpus()
    progress = Path(os.environ.get("S4E_PROGRESS_RESULTS", "/home/resources/progress/results.tsv"))
    if "--night-only" in argv:
        return report(corpus, progress)
    if "--stamp" in argv:
        return stamp(corpus, progress)
    print("usage: util_grade_cell.py --night-only | --stamp", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
