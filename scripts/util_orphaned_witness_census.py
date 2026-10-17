"""Census the WITNESS PAIRS that no denominator contains.

A witness pair is a loose `<name><ext>` beside a `<name>.ref` under `corpus/tests/<lang>/`.
It is ORPHANED when its name appears NOWHERE in that language's `ALL.csv`, `ALL.xfail` or
`ALL.excluded.txt` -- so it is not passing, not expected-failing, and not excluded: no
denominator contains it, and no board has ever run it.

WHY THIS IS ITS OWN SHAPE, worse than an xfail (ceo CEO-414, hq_P 2026-09-08):
an xfail is at least censused by test_gate_no_xfail_survives.sh.  An orphan appears in NO
count we keep, because every count starts from ALL.csv.  The SNOBOL4 rungs read 1894/1894
FAIL=0 with a SEGFAULTING witness (nested_arbno_rpos) sitting in the tree beside it.

MEMBERSHIP IS DELIBERATELY GENEROUS -- a name counts as KNOWN if it appears anywhere in any
of the three files, not merely in the `entry` column.  Absorbed entries are often renamed and
carry the loose filename only in `origin`, so a strict column match would manufacture orphans.
Being generous means this census UNDER-reports; every name it does report is one that three
files never mention at all.  ⛔ That direction is the safe one for a ratchet and it is why the
gate built on this can refuse growth without ever firing on a rename.
"""
import os, sys, glob, json
EXT = {'snobol4':'.sno','icon':'.icn','prolog':'.pl','pascal':'.pas','raku':'.raku','rebus':'.reb','snocone':'.sc'}
def census(root):
    out = {}
    for lang, ext in sorted(EXT.items()):
        d = os.path.join(root,'tests',lang)
        if not os.path.isdir(d): continue
        blob = ''
        for f in ('ALL.csv','ALL.xfail','ALL.excluded.txt'):
            p = os.path.join(d,f)
            if os.path.exists(p): blob += open(p, errors='replace').read()
        loose, orph = 0, []
        for s in sorted(glob.glob(os.path.join(d,'**','*'+ext), recursive=True)):
            b = os.path.basename(s)[:-len(ext)]
            if b.startswith('ALL'): continue
            loose += 1
            if not os.path.exists(s[:-len(ext)]+'.ref'): continue
            if b not in blob: orph.append((b, os.path.relpath(s, root)))
        out[lang] = {'loose': loose, 'orphans': orph}
    return out
if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','corpus')
    root = os.path.abspath(root)
    c = census(root)
    if '--counts' in sys.argv:
        for lang in sorted(c): print("%s\t%d" % (lang, len(c[lang]['orphans'])))
        sys.exit(0)
    print("# ORPHANED WITNESS PAIRS -- a correct <name><ext> + <name>.ref that NO denominator contains.")
    print("# Regenerate: python3 harness/scripts/util_orphaned_witness_census.py corpus > corpus/tests/ORPHANED-WITNESSES.tsv")
    print("# Gated by harness/scripts/test_gate_orphaned_witnesses_do_not_grow.sh -- the count may FALL, never rise.")
    print("# ⛔ The cure is to ABSORB them into ALL.<ext> once they are green, NOT to delete them.")
    print("#")
    print("lang\tname\tpath")
    for lang in sorted(c):
        for name, path in c[lang]['orphans']: print("%s\t%s\t%s" % (lang, name, path))
    tot = sum(len(c[l]['orphans']) for l in c)
    print("#")
    print("# TOTALS  " + "  ".join("%s=%d/%d" % (l, len(c[l]['orphans']), c[l]['loose']) for l in sorted(c)))
    print("# TOTAL ORPHANED PAIRS: %d" % tot)
