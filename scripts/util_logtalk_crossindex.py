#!/usr/bin/env python3
"""util_logtalk_crossindex.py -- THE PREDICATE-TO-GROUP CROSS-INDEX, and the denominator a family verdict
should actually be read against (cto ruling to hq_C, 2026-09-13).

⛔⭐ WHY THIS EXISTS, MEASURED, NOT ARGUED. On 2026-09-13 hq_C cured two real defects in atom_concat/3 and
put_code/2. predicates/atom_concat_3 read 28 of 28 BEFORE and 28 of 28 AFTER. predicates/put_code_2 read
10 of 16 before and 10 of 16 after. Neither eponymous group could have gone red no matter how wrong its
predicate was, because every case in both is ASCII and byte indexing and character indexing AGREE ON EVERY
ASCII ATOM. The only cases in 3,268 that could see either defect live in unicode/builtins -- a directory
named for the INGREDIENT and not for the predicate -- so the evidence for a defect in atom_concat/3 was
filed under neither atom_concat nor concatenation, and a seat walking predicates/ group by group can close
every one of them and ship both bugs.

⭐ AN INSTRUMENT THAT CANNOT PRODUCE THE RED IS INDISTINGUISHABLE FROM ONE THAT FOUND NONE, AND ONLY THE
SECOND IS EVIDENCE. A green eponymous group is a claim about a POPULATION, and the population that matters
is every case that CALLS the predicate, wherever it is filed.

WHAT IT READS. The suite's own ALL.csv feature-attribute table (../harness/scripts/util_prolog_iso_attributes.py),
whose ~170 0/1 columns already record, per case, every ISO builtin the case's goal text names. So the
cross-index is DERIVED MECHANICALLY from the case sources and never hand-maintained -- a hand list would
go stale in the flattering direction the first time a case moved directories.

⭐⭐ --strict IS ARMED AGAINST THE CLAIM AND NOT AGAINST THE WORK (cto ruling to hq_C, 2026-09-13). A big-bang
--strict over the grading path would have stopped 40 live rows across two lanes in order to remove a false
confidence nobody was acting on -- a cure that trades one thing for another, which CEO-589 forbids in the
suite and which is no better as process. So an unwitnessed group stays WORKABLE and stays able to read
GREEN; what it loses is the right to be DECLARED DONE. A seat may cure every case in compare_3 and read
30 of 30; it may not record compare_3 as a family closed, because nothing in that population could have
told it otherwise. That refuses the claim, which is what is actually wrong, and refuses nothing else.

⛔⭐ THE TWO REFUSALS ARE DIFFERENT DEFECTS AND MUST NOT SHARE A SENTENCE, and the populations are not
nested: 40 groups have outside=0 and 10 have inside=0, but only 7 are both -- plus_1, plus_2 and power_2
are MIS-POPULATED while HAVING outside evidence, so an outside-witness switch alone would never have named
them. For an UNWITNESSED group the eponymous number is a LOWER BOUND on a real population. For a
MIS-POPULATED one it is A COUNT OF SOMETHING ELSE: not one case in discontiguous_1, dynamic_1,
ensure_loaded_1, include_1 or initialization_1 names its own predicate in callable position, because they
are DIRECTIVES and the extractor's callable-position rule sets no flag for a directive. A reader told "no
independent evidence" goes looking for more cases; a reader told "this denominator counts something else"
goes and fixes the extractor. Sending the second reader after the first errand is the whole cost of one
shared sentence.

⭐ AND IT EXPIRES BY ITSELF. Both classes are recomputed from ALL.csv on every run and nothing is
declared anywhere: the moment a group gains an outside witness its refusal disappears with no seat
remembering to lift it, and the moment a group that HAD one loses it the refusal comes back. A carve-out
that must be lifted by hand goes stale in the flattering direction; this one cannot.

    --group G [G...]   print each group's eponymous denominator beside its cross-indexed one
    --strict           REFUSE(2) THE DONE CLAIM for a group that is UNWITNESSED (no case outside it calls
                       its predicate) or MIS-POPULATED (no case inside it calls its predicate), each with
                       its own sentence. Grading is not refused and a red group is not stopped. Measured
                       on the suite as vendored 2026-09-13: 144 eponymous groups, 101 clean, 33
                       unwitnessed, 10 mis-populated.
    --census           print the whole table: every eponymous group, inside and outside populations
Machine-readable: one `CROSSINDEX_CLAIM <group> CLEAN|UNWITNESSED|MIS-POPULATED` line per named group, for
a caller that must decide about a DONE verdict without re-deriving the classification.
rc 0 nothing impedes a DONE claim · 1 an impediment was printed (ordinary run) · 2 with --strict, the DONE
claim is REFUSED; also 2 when the index could not be measured at all
"""
import csv
import os
import sys


def load(suite):
    p = os.path.join(suite, "ALL.csv")
    if not os.path.isfile(p):
        sys.stderr.write("⛔ REFUSE(2): no ALL.csv at %s -- the feature-attribute table this index is derived from\n" % p)
        sys.exit(2)
    r = list(csv.reader(open(p, encoding="utf-8")))
    if len(r) < 2:
        sys.stderr.write("⛔ REFUSE(2): %s has no rows\n" % p)
        sys.exit(2)
    hdr = r[0]
    return hdr, {h: i for i, h in enumerate(hdr)}, r[1:]


def group_of(row):
    return row[1].split(":")[0] if len(row) > 1 else ""


def predicate_of(g, idx):
    """The predicate column a group is NAMED for: strip a trailing _<arity>, else the bare name."""
    parts = g.rsplit("_", 1)
    if len(parts) == 2 and parts[1].isdigit() and parts[0] in idx:
        return parts[0]
    return g if g in idx else None


def report(suite, groups, strict, census):
    hdr, idx, rows = load(suite)
    allg = sorted(set(group_of(x) for x in rows))
    bypred = {}
    for g in allg:
        p = predicate_of(g, idx)
        if p:
            bypred.setdefault(p, []).append(g)
    names = allg if census else groups
    rc = 0
    unwitnessed, mispopulated = [], []
    for g in names:
        p = predicate_of(g, idx)
        pop = sum(1 for x in rows if group_of(x) == g)
        if not p:
            print("  %-34s eponymous=%-4d cross-indexed=--    NOT NAMED FOR ONE PREDICATE -- this group is"
                  " OUTSIDE evidence for others, never a denominator of its own" % (g, pop))
            continue
        c = idx[p]
        inside = sum(1 for x in rows if group_of(x) == g and len(x) > c and x[c] == "1")
        outside = [x[1] for x in rows if group_of(x) != g and len(x) > c and x[c] == "1"]
        where = sorted(set(n.split(":")[0] for n in outside))
        print("  %-34s eponymous=%-4d calls-it=%-4d  cross-indexed=%-4d  outside=%-4d %s"
              % (g, pop, inside, inside + len(outside), len(outside), ("in " + ", ".join(where)) if where else ""))
        # \u26d4 MIS-POPULATED FIRST AND IT DOES NOT FALL THROUGH: a group whose own cases never call its own
        # predicate is not weakly witnessed, it is counting something else, and the two readings send a
        # reader on different errands. plus_1, plus_2 and power_2 are mis-populated WITH outside evidence,
        # so the classes are not nested and neither can be derived from the other.
        if inside == 0:
            mispopulated.append((g, p))
            print("      \u26d4 MIS-POPULATED: NOT ONE CASE IN THIS GROUP NAMES %s. The group is named for a"
                  " predicate its own cases never call in callable position -- a directive, or a flag"
                  " ../harness/scripts/util_prolog_iso_attributes.py does not set -- so its eponymous denominator is"
                  " not a weak count of %s, it is A COUNT OF SOMETHING ELSE. The extractor is what is"
                  " wrong here, not the group and not the cure." % (p, p))
            rc = max(rc, 1)
        elif not outside:
            unwitnessed.append((g, p))
            print("      \u26d4 UNWITNESSED: NO CASE OUTSIDE THIS GROUP CALLS %s. A green here is UNFALSIFIABLE"
                  " from anywhere else in the suite: the group is its own only witness, so it cannot"
                  " distinguish a correct predicate from one whose defect its population cannot vary."
                  " The eponymous number is a LOWER BOUND on the real population." % p)
            rc = max(rc, 1)
        sibs = [x for x in bypred.get(p, []) if x != g]
        if sibs:
            print("      \u26a0 NAME-LEVEL, NOT NAME/ARITY: ALL.csv's feature columns are keyed by NAME, so this"
                  " count also contains every case calling %s at another arity (%s has its own group%s: %s)."
                  " Read the outside figure as an UPPER bound on independent evidence for this arity."
                  % (p, p, "s" if len(sibs) > 1 else "", ", ".join(sibs)))
        print("CROSSINDEX_CLAIM %s %s" % (g, "MIS-POPULATED" if inside == 0 else ("UNWITNESSED" if not outside else "CLEAN")))
    sys.stdout.flush()
    if strict and (unwitnessed or mispopulated):
        # \u2b50 THE REFUSAL IS OF THE DONE CLAIM, NOT OF THE GRADING RUN. Nothing above was suppressed and no
        # case was dropped; what is refused is recording these groups as a family closed.
        for g, p in mispopulated:
            sys.stderr.write("\u26d4 REFUSE(2) THE DONE CLAIM -- %s IS MIS-POPULATED: this denominator counts something"
                             " else. No case in %s calls %s in callable position, so \"every case passes\" is a"
                             " verdict over a population that was never about %s. Fix"
                             " ../harness/scripts/util_prolog_iso_attributes.py so a directive sets its flag; do not record"
                             " this group as closed and do not read its number as evidence for %s.\n" % (g, g, p, p, p))
        for g, p in unwitnessed:
            sys.stderr.write("\u26d4 REFUSE(2) THE DONE CLAIM -- %s HAS NO OUTSIDE WITNESS: it may be cured, it may read"
                             " GREEN, and it may not be recorded as a family closed. No case outside %s calls %s,"
                             " so nothing in the population this verdict was taken over could have told it"
                             " otherwise. Keep working it; declare it closed when %s is exercised from somewhere"
                             " that is not %s.\n" % (g, g, p, p, g))
        sys.stderr.write("\u2b50 Both readings are recomputed from ALL.csv on every run: the refusal lifts itself the"
                         " moment the evidence exists, and returns by itself the moment it is lost.\n")
        return 2
    return rc


def main(argv):
    suite = os.environ.get("LOGTALK_SUITE")
    if not suite:
        here = os.path.dirname(os.path.abspath(__file__))
        suite = os.path.join(here, "..", "..", "SCRIP", "..", "corpus", "packages", "prolog", "logtalk_iso")
    strict = "--strict" in argv
    census = "--census" in argv
    groups = []
    if "--group" in argv:
        i = argv.index("--group") + 1
        while i < len(argv) and not argv[i].startswith("--"):
            groups.append(argv[i]); i += 1
    if not groups and not census:
        sys.stderr.write(__doc__)
        return 2
    return report(suite, groups, strict, census)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
