#!/usr/bin/env python3
# lib_split_units.py -- THE READER OF A CUT UNIT (DESIGN-PLAN cache-tree, CTO-636, law C8; harness/designs/cache_tree/SPLITS.tsv).
# unit_files(src_root, rel) -> the files that now hold what SCRIP/src/<rel> held (the pieces first, by name, then the head and the export headers, so a
# reader that takes a function's first match meets its definition before its prototype), or [rel's own path] when
# the unit was never cut; [] when neither exists. unit_text(src_root, rel) -> their text joined, or None. A reader that greps or parses a unit by its old
# path calls these, so a cut never leaves it reading a missing file as an empty one.
#   python3 lib_split_units.py SRC_ROOT REL        prints the files, one per line (rc 2 when none exists)
import glob, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, '..', 'designs', 'cache_tree', 'SPLITS.tsv')


def splits():
    out = {}
    if os.path.exists(TABLE):
        for ln in open(TABLE, encoding='utf-8'):
            if ln.strip() and not ln.startswith('#'):
                p = ln.rstrip('\n').split('\t')
                out[p[0]] = (p[1], p[2])
    return out


def unit_files(src_root, rel):
    own = os.path.join(src_root, rel)
    if os.path.exists(own):
        return [own]
    s = splits().get(rel)
    if not s:
        return []
    d, pre = os.path.join(src_root, s[0]), s[1]
    head = os.path.join(d, pre + 'head.h')
    hs = sorted(x for x in glob.glob(os.path.join(d, pre + '*.h')) if x != head)
    cs = sorted(glob.glob(os.path.join(d, pre + '*' + os.path.splitext(rel)[1])))
    return cs + ([head] if os.path.exists(head) else []) + hs


def unit_text(src_root, rel):
    fs = unit_files(src_root, rel)
    if not fs:
        return None
    return '\n'.join(open(f, encoding='utf-8', errors='replace').read() for f in fs)


if __name__ == '__main__':
    fs = unit_files(sys.argv[1], sys.argv[2])
    if not fs:
        print('REFUSE(2): %s holds no %s and SPLITS.tsv names no cut of it' % (sys.argv[1], sys.argv[2]), file=sys.stderr)
        sys.exit(2)
    print('\n'.join(fs))
