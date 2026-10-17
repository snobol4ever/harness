#!/usr/bin/env python3
"""util_census_bb_label_families.py -- census every label DEFINITION in one or more emitted TEXT-mode
.s files, split into greek-port-suffixed (conforming shape: name ends in alpha/beta/gamma/omega) vs
everything else, and bucket the "everything else" into FAMILIES (digits/graph-names generalized) so a
census reads as ~40 shapes instead of thousands of individual label names.

Row: bb-label-prefix-uniform (Lon's widened ruling, 2026-08-28: "ALL labels emitted in the ALPHA and
BETA block must change... EVERY variation of labels gets unified into ONE COMMON PREFIX for all in
each block"). This is step 1 (CENSUS) of that row's ## NEXT plan.

⛔ WHY THIS EXISTS RATHER THAN A ONE-LINE grep: an ASCII-only pattern (`[A-Za-z0-9_]*:`) silently drops
every Greek-suffixed label -- RULES.md INSTRUMENT LAW #15 ("an ASCII regex over UTF-8-labeled emission
is not a narrower measurement, it is a wrong one") documents this exact class already, and building
this census with grep the naive way reproduced it (seat03, 2026-08-29): a first attempt read the
massive nN_<kind>_bx family as if it were the whole non-conforming population, having silently
discarded every real n<N>_<kind>_alpha/beta label because the regex's character class stopped at the
first Greek byte. Verified against the fixed version by checking actual UTF-8 byte sequences directly
(grep -P '\\xce\\xb1' etc.) before trusting either count.

Usage: python3 ../harness/scripts/util_census_bb_label_families.py file1.s [file2.s ...]
  (compile witnesses first: ./scrip --compile some.sno > file1.s)
"""
import re
import sys
import collections

GREEK = "αβγω"
# A label DEFINITION line starts at column 0 (no leading whitespace -- every instruction line in this
# codebase's TEXT emission is indented) and is `NAME:` optionally followed by more content on the same
# line (a data directive, e.g. `.Lgvan0:  .string "PATTERN_BT"`, or nothing but trailing whitespace).
LABEL_DEF = re.compile(r'^([^\s:]+):(?:\s|$)')


def label_defs(path):
    defs = []
    with open(path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            m = LABEL_DEF.match(line.rstrip('\n'))
            if m:
                defs.append((lineno, m.group(1)))
    return defs


def classify(name):
    n = name[1:] if name.startswith('.') else name  # strip GAS local-label leading '.'
    return any(g in n for g in GREEK), n


def generalize(name):
    fam = re.sub(r'\$[^_.]+', '$GRAPH', name)  # graph-name tokens like PAT$0, EXPR$3 -> $GRAPH
    fam = re.sub(r'[0-9]+', 'N', fam)          # any digit run -> N
    return fam


def main(argv):
    for path in argv:
        defs = label_defs(path)
        print(f"=== {path}: {len(defs)} label definitions ===")
        greek_ct = 0
        families = collections.Counter()
        examples = {}
        for lineno, name in defs:
            has_greek, n = classify(name)
            if has_greek:
                greek_ct += 1
                continue
            fam = generalize(n)
            families[fam] += 1
            examples.setdefault(fam, (lineno, name))
        print(f"  greek-suffixed defs: {greek_ct}")
        print(f"  non-greek families ({sum(families.values())} defs total):")
        for fam, ct in families.most_common():
            ln, ex = examples[fam]
            print(f"    {ct:5d}  {fam:30s}  e.g. line {ln}: {ex}")
        print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: util_census_bb_label_families.py file1.s [file2.s ...]", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1:])
