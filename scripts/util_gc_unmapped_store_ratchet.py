#!/usr/bin/env python3
"""THE PER-WITNESS RATCHET of the unmapped-store class: reads a census run on stdin, grades it against a baseline.

⛔ WHY THIS IS NOT A TOTAL (hq_snobol4, 2026-09-20, measured against the gate BEFORE landing rather than discovered
afterwards).  The census's population is a DIRECTORY GLOB over ../harness/scripts/gc_witnesses.  Nine oracle-cut witnesses
arriving from another seat's row would move the total from 162 to 192, and a total-shaped arm prints THE CLASS
GREW and names a compiler regression it never measured -- over nine files that had just been added.  A total
cannot tell a compiler regression from a file arriving.  Only a name set can, and that is this row's own
NAME-NEVER-A-COUNT rule applied one level down from where the census first applied it.

THE THREE VERDICTS ARE DIFFERENT FACTS AND ARE NEVER SUMMED: MOVED is a witness whose OWN reading changed, which
is the thing the row exists to catch; GONE is a baseline line whose witness left the population, so the floor is
grading something it can no longer see; NEW is a file addition, which must be recorded but is NOT a regression and
must not be reported as one.

THE FIFTH COLUMN, ADDED 2026-09-20 BY THE cto: stores shielded at a safe point into a FIXED SYMBOL instead
of into the frame.  It is ratcheted for a reason the other four cannot express -- when shielding MOVES from
the road this census grades to the road it does not, `members` and `shielded` both FALL and every arm reads
an improvement, while the truth is that coverage was lost."""
import sys


def main(argv):
    if len(argv) != 1:
        print("RATCHET REFUSED(2): one argument, the baseline tsv")
        return 2
    base = {}
    for ln in open(argv[0], encoding="utf-8"):
        if ln.startswith("#") or not ln.strip():
            continue
        f = ln.rstrip("\n").split("\t")
        if len(f) >= 5:
            base[f[0]] = tuple(f[1:5])
        elif len(f) >= 4:
            print("RATCHET REFUSED(2): baseline row " + f[0] + " carries four columns and this ratchet "
                  "grades five -- the fifth is the census's own REACH (stores shielded into a fixed "
                  "symbol). A four-column floor cannot see shielding MOVE from the graded road to the "
                  "unread one, which every other number in the row reads as an improvement. Rewrite the "
                  "file with --write-baseline in this landing.")
            return 2
    now = {}
    for ln in sys.stdin:
        if ln.startswith("CENSUS unmapped-store WITNESS "):
            f = ln.split()
            now[f[3]] = tuple(x.split("=")[1] for x in f[4:8])
    if not now:
        print("RATCHET REFUSED(2): the census run carried no WITNESS line -- a ratchet over an empty reading "
              "holds by never looking")
        return 2
    moved = [(w, base[w], now[w]) for w in sorted(base) if w in now and base[w] != now[w]]
    gone = sorted(set(base) - set(now))
    new = sorted(set(now) - set(base))
    for w, b, n in moved:
        print(f"MOVED {w} baseline members={b[0]} undecidable={b[1]} shielded={b[2]} unread_static={b[3]} now members={n[0]} undecidable={n[1]} shielded={n[2]} unread_static={n[3]}")
    for w in gone:
        print(f"GONE {w} -- in the baseline and not in the population")
    for w in new:
        print("NEW " + w + "\t" + "\t".join(now[w]))
    print(f"RATCHET witnesses={len(now)} baseline={len(base)} moved={len(moved)} gone={len(gone)} new={len(new)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
