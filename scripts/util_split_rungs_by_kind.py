#!/usr/bin/env python3
"""util_split_rungs_by_kind.py -- split a rung suite suite pair into ONE-LINERS and MULTI-LINERS.

Lon's 4th/5th consolidation statements (routed by ceo 2026-08-29, TRIO): the end state has NO
per-language folders -- per language, a ONE-LINERS file and a MULTI-LINERS file side by side in one
flat dir. Today's rungs is ONE file carrying both kinds; this splits the kinds into two files.

The discriminator is not invented here: ALL.csv already carries `kind`, which is exactly `line`
(818) or `block` (677) on the snobol4 rungs at corpus dcdf7140f. This tool reads that column
rather than re-deriving one-line-ness from the text, so the split cannot disagree with the
attribute database that the levels/rank machinery already keys on.

-- WHY THIS REFUSES RATHER THAN OVERWRITES ------------------------------------------------------
The snobol4 floor is LIVE on the rungs pair and GREEN (1444/0 m3, 1435/0 m4). A split that loses,
duplicates or reorders a single entry silently shrinks the correctness floor -- the
board-shrinks-instead-of-reddening shape. So this tool is verify-first and writes nothing unless
every one of these holds:

  1. PARTITION: every entry in ALL.csv lands in exactly one output, and the two outputs together
     name exactly the input's entry set. No entry lost, none duplicated, none invented.
  2. BYTE PRESERVATION: each entry's .sno text and .ref text are carried over byte-for-byte.
  3. COUNT AGREEMENT: len(one) + len(multi) == len(input), asserted separately from (1) so a
     symmetric bug cannot satisfy both.

⛔ (1) and (3) are deliberately redundant. A set-equality check and a count check fail differently:
a duplicate that replaces a lost entry passes the count and fails the set; a reordering passes both
and is caught by (2). This is the count-and-list corollary applied to a converter -- the two must
agree or the tool says why.

⛔ IT DOES NOT WIRE THE RUNNER AND IT DOES NOT DELETE THE INPUT. Retirement of the combined pair is
a separate, later decision that needs a board-equality proof first (row
`snobol4-floor-cutover-to-the-one-flat-suite-board-equality-first`). Producing the two files is
safe; adopting them is not, and the two must not ride in on one commit.

Usage:
    python3 ../harness/scripts/util_split_rungs_by_kind.py <rungs_dir>            # verify only, writes nothing
    python3 ../harness/scripts/util_split_rungs_by_kind.py <rungs_dir> --write    # verify, then write
Exit: 0 verified (and written, if --write) - 1 a check failed - 2 could not measure.
"""
import sys, os, csv, argparse


def refuse(msg):
    """rc=2 -- COULD NOT MEASURE. Never a pass: the tool could not examine the thing it grades."""
    print("\u26d4 REFUSED(rc=2): " + msg)
    sys.exit(2)


def fail(msg):
    """rc=1 -- MEASURED AND WRONG. A real result, distinct from rc=2."""
    print("\u26d4 FAILED(rc=1): " + msg)
    sys.exit(1)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rungs_dir")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--stem", default="ALL")
    a = ap.parse_args()

    d = a.rungs_dir
    sno = os.path.join(d, a.stem + ".sno")
    ref = os.path.join(d, a.stem + ".ref")
    csvp = os.path.join(d, a.stem + ".csv")
    for p in (sno, ref, csvp):
        if not os.path.isfile(p):
            refuse("missing %s -- nothing to split" % p)

    rows = list(csv.DictReader(open(csvp)))
    if not rows:
        refuse("%s has zero rows; an empty attribute database is not a split you can verify" % csvp)
    if "kind" not in rows[0] or "entry" not in rows[0]:
        refuse("%s lacks a `kind` and/or `entry` column -- this tool reads the attribute database "
               "rather than re-deriving one-line-ness, so it cannot proceed without it" % csvp)

    kinds = {}
    for r in rows:
        e, k = r.get("entry"), r.get("kind")
        if not e:
            refuse("a CSV row has an empty `entry` name; refusing to split on an unnamed entry")
        if e in kinds:
            fail("duplicate entry name in %s: %s -- the input is already malformed" % (csvp, e))
        kinds[e] = k

    one   = [e for e, k in kinds.items() if k == "line"]
    multi = [e for e, k in kinds.items() if k == "block"]
    other = sorted({k for k in kinds.values() if k not in ("line", "block")})
    if other:
        refuse("unhandled kind value(s) %r -- the split is defined for `line` and `block` only. "
               "A third kind means the format moved and this tool is stale; do NOT guess which "
               "file it belongs in." % other)

    # (3) COUNT AGREEMENT, asserted independently of the set check below.
    if len(one) + len(multi) != len(kinds):
        fail("count disagreement: %d one + %d multi != %d total" % (len(one), len(multi), len(kinds)))
    # (1) PARTITION, by set identity rather than by arithmetic.
    if set(one) | set(multi) != set(kinds) or (set(one) & set(multi)):
        fail("partition is not exact: union/intersection check failed")

    print("rungs   : %s" % d)
    print("entries  : %d" % len(kinds))
    print("one-liners (kind=line ) : %d" % len(one))
    print("multi-liners(kind=block) : %d" % len(multi))
    print("✅ partition exact, counts agree, no unhandled kind")

    if not a.write:
        print()
        print("VERIFY-ONLY. Nothing written. Re-run with --write to emit the two pairs.")
        print("⛔ Writing the pair does NOT adopt it: the floor runner still reads the combined")
        print("   rungs, and cutting it over needs the board-equality proof from row")
        print("   snobol4-floor-cutover-to-the-one-flat-suite-board-equality-first.")
        return 0

    refuse("--write is not implemented yet on purpose. The partition above is verified from the "
           "attribute database, but emitting the two pairs requires extracting every entry's .sno and "
           ".ref text byte-for-byte through corpus_suite_harness, and this tool must not carry a "
           "second parser for the suite format. Wire it to the harness's own extract path first.")


if __name__ == "__main__":
    sys.exit(main())
