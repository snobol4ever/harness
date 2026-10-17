#!/usr/bin/env python3
"""util_suite_wall_clock_census.py -- THE WALL CLOCK OF EVERY SUITE, read from the one record (Lon 2026-10-08 16:2x CDT, in-chat to the
ceo, verbatim: "List in a grid the total time for each test suite to run. COO has been running them, so he will know."; CEO-1562, row
instruments-every-suite-board-line-carries-its-wall-clock-and-the-suite-table-shows-it-lon-2026-10-08-ceo-1562).

One line per SUITES.tsv row, in the grid's order (lang, then nickname): its today_secs -- the seconds from the runner's start
(one_runner_guard stamps S4E_RUN_T0) to its row write, carried by util_score_row.py into util_suite_banner.py --set --secs -- with the
tree and the day of that reading. A row with no today_secs is named NONE: its last write predates the column, or its writer passed none.
EXIT: 0 every row carries a wall clock; 1 a row carries none (each named); 2 the record is missing, unreadable or empty.
The record is /home/resources/progress/SUITES.tsv, or S4E_SUITES_TSV for a scratch copy.
"""
import csv, os, sys

TSV = os.environ.get("S4E_SUITES_TSV") or "/home/resources/progress/SUITES.tsv"


def human(n):
    if n < 60:
        return "%ds" % n
    if n < 3600:
        return "%dm%02ds" % (n // 60, n % 60)
    return "%dh%02dm" % (n // 3600, (n % 3600) // 60)


def main():
    try:
        lines = [ln for ln in open(TSV, encoding="utf-8").read().split("\n") if ln and not ln.startswith("#")]
    except OSError as e:
        print("REFUSE(rc=2): cannot read %s: %s" % (TSV, e))
        return 2
    rows = list(csv.DictReader(lines, delimiter="\t"))
    if not rows or "key" not in rows[0]:
        print("REFUSE(rc=2): %s holds no suite rows under a key header" % TSV)
        return 2
    rows.sort(key=lambda r: ((r.get("lang") or "").lower(), (r.get("nick") or "").lower()))
    none = []
    for r in rows:
        v = (r.get("today_secs") or "").strip()
        wall = human(int(v)) if v.isdigit() else "NONE"
        if not v.isdigit():
            none.append(r["key"])
        print("%-9s %-13s %-22s wall=%-8s secs=%-6s tree=%-10s on %s" % (r.get("lang", ""), r.get("nick", ""), r["key"], wall,
                                                                       v if v.isdigit() else "-", r.get("tree", ""), r.get("today_date", "")))
    total = sum(int((r.get("today_secs") or "0").strip() or 0) for r in rows if (r.get("today_secs") or "").strip().isdigit())
    print("population: %d suite rows in %s; %d carry a wall clock (%s summed), %d do not%s"
          % (len(rows), TSV, len(rows) - len(none), human(total), len(none), (": " + " ".join(none)) if none else ""))
    return 1 if none else 0


if __name__ == "__main__":
    sys.exit(main())
