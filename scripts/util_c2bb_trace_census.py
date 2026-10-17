#!/usr/bin/env python3
"""util_c2bb_trace_census.py -- WHICH C-TO-BOX ENTRIES A POPULATION STILL TAKES, COUNTED BY MARK, ONE WITNESS EACH (the coo 2026-10-09,
the cfo's ask for the rank-0 row gc-rt-c-c-to-bb-entries-leave-no-emitted-code-...).

rt_c2bb_hit (src/runtime/rt/rt.c, RT_DIAG) appends one line per box entered from C to the file SCRIP_C2BB_TRACE names:
    <site> TAB <name> TAB <caller> TAB <caller's caller>
corpus_suite_harness.py, run with S4E_ENTRY_TRACE_DIR=<dir>, gives every entry and mode its own <dir>/<entry>.<mode>.trace. This reads such
a directory (or several, one per suite) and prints, per mark (the site), the hits, the entries and modes that took it, and one witness
entry and mode; --by-name splits each mark by its name column, and --callers prints the caller pair under each mark.

A directory with no trace file at all is REFUSE(2): either the build has no RT_DIAG or the run never set the directory -- never a census
of zero. An entry that ran and entered nothing from C leaves no file, which is the answer the row wants.
EXIT: 0 counted · 2 could not read.
"""
import argparse
import collections
import sys
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("dirs", nargs="+", help="trace directories (S4E_ENTRY_TRACE_DIR of each run)")
    ap.add_argument("--by-name", action="store_true", help="count site/name pairs instead of sites")
    ap.add_argument("--callers", action="store_true", help="print the caller pairs seen under each mark")
    a = ap.parse_args()
    hits = collections.Counter()
    where = collections.defaultdict(set)
    callers = collections.defaultdict(collections.Counter)
    files = 0
    for d in a.dirs:
        p = Path(d)
        if not p.is_dir():
            print("REFUSE(2): %s is not a directory" % d)
            return 2
        for f in sorted(p.glob("*.trace")):
            files += 1
            entry, mode = f.name[: -len(".trace")].rsplit(".", 1)
            for ln in f.read_text(errors="replace").splitlines():
                c = ln.split("\t")
                if not c or not c[0]:
                    continue
                mark = c[0] + ("/" + c[1] if a.by_name and len(c) > 1 else "")
                hits[mark] += 1
                where[mark].add((p.name, entry, mode))
                if a.callers and len(c) > 3:
                    callers[mark][c[2] + " <- " + c[3]] += 1
    if files == 0:
        print("REFUSE(2): no *.trace file under %s -- a build without RT_DIAG, or a run without S4E_ENTRY_TRACE_DIR, is not a census of zero" % " ".join(a.dirs))
        return 2
    print("%-48s %8s %8s %6s %6s  %s" % ("mark", "hits", "entries", "m3", "m4", "witness (suite entry mode)"))
    for mark, n in sorted(hits.items(), key=lambda kv: (-kv[1], kv[0])):
        w = where[mark]
        ents = {(s, e) for s, e, _m in w}
        m3 = sum(1 for _s, _e, m in w if m == "m3")
        m4 = sum(1 for _s, _e, m in w if m == "m4")
        ws, we, wm = sorted(w)[0]
        print("%-48s %8d %8d %6d %6d  %s %s %s" % (mark[:48], n, len(ents), m3, m4, ws, we, wm))
        if a.callers:
            for cp, k in callers[mark].most_common(4):
                print("      %6d  %s" % (k, cp[:120]))
    print("population: %d trace file(s) in %d director(y/ies); %d mark(s), %d hit(s)" % (files, len(a.dirs), len(hits), sum(hits.values())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
