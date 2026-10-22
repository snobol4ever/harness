#!/usr/bin/env python3
"""util_attribute_coverage.py [--lang L] [--table T] [--min PCT] -- HOW MUCH OF EACH SUITE THE FEATURE ATTRIBUTES DESCRIBE (Lon 2026-10-22, in-chat to
the ceo, verbatim: "Is the system using the attribute files with each program listed with which feature that program uses. Go check the coverage for
each language."; ceo CEO-1892).

Reads every suite table (corpus/tests/<lang>/ALL.csv and corpus/packages/<lang>/<pkg>/ALL.csv). A FEATURE COLUMN is a column outside
util_suite_partition.py's FIXED set whose every value is a non-negative integer, minus the bookkeeping columns package, want_rc, stdin, section,
err and err_arg (which the partition builder still counts as features -- named on each table's line as `bogus=`). A program is TAGGED when at least
one feature column is non-zero for it. Prints one line per table and one per language, plus the source files of SCRIP/src that the area smoke's
carrier map (area_map.tsv) sends to a specific feature, to the `*` widening (every feature of every table), or nowhere.
  ATTR_COVERAGE table=<t> lang=<l> programs=<n> features=<f> tagged=<k> pct=<p> bogus=<cols>
  ATTR_COVERAGE_LANG lang=<l> programs=<n> tagged=<k> pct=<p> untagged_tables=<t,...>
  ATTR_COVERAGE_CARRIERS files=<n> specific=<s> star=<w> unmapped=<u>
With --min PCT it exits 1 when any table read (narrowed by --lang/--table) is under PCT tagged or has no feature column; rc 0 otherwise; rc 2 when
nothing could be read.
"""
import csv, glob, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
C = os.path.join(ROOT, "corpus")
BOOK = {"package", "want_rc", "stdin", "section", "err", "err_arg"}
def fixed():
    src = open(os.path.join(HERE, "util_suite_partition.py"), encoding="utf-8").read()
    m = re.search(r"FIXED = (\{.*?\})", src, re.S)
    return eval(m.group(1)) if m else set()
def main(a):
    lang = a[a.index("--lang") + 1] if "--lang" in a else None
    table = a[a.index("--table") + 1] if "--table" in a else None
    minp = float(a[a.index("--min") + 1]) if "--min" in a else None
    FIX = fixed()
    tabs = sorted(glob.glob(C + "/tests/*/ALL.csv") + glob.glob(C + "/packages/*/*/ALL.csv"))
    if not tabs: print("REFUSE(2): no suite table under %s" % C); return 2
    per = {}; bad = 0; read = 0
    for t in tabs:
        name = t[len(C) + 1:-len("/ALL.csv")]
        l = name.split("/")[1]
        if (lang and l != lang) or (table and table not in name): continue
        rows = list(csv.DictReader(open(t, encoding="utf-8", errors="replace")))
        if not rows: continue
        read += 1
        cand = [c for c in rows[0].keys() if c and c not in FIX]
        feats = [c for c in cand if c not in BOOK and all(re.fullmatch(r"\d*", (r.get(c) or "").strip()) for r in rows)]
        bogus = [c for c in cand if c in BOOK]
        tagged = sum(1 for r in rows if any((r.get(f) or "0").strip() not in ("", "0") for f in feats))
        pct = 100.0 * tagged / len(rows)
        p = per.setdefault(l, [0, 0, []]); p[0] += len(rows); p[1] += tagged
        if not feats or pct < (minp if minp is not None else 100.0): p[2].append(name.split("/")[-1])
        if minp is not None and (not feats or pct < minp): bad += 1
        print("ATTR_COVERAGE table=%s lang=%s programs=%d features=%d tagged=%d pct=%.0f bogus=%s" % (name, l, len(rows), len(feats), tagged, pct, ",".join(bogus) or "-"))
    for l, (n, k, un) in sorted(per.items()):
        print("ATTR_COVERAGE_LANG lang=%s programs=%d tagged=%d pct=%.0f untagged_tables=%s" % (l, n, k, 100.0 * k / n, ",".join(un) or "-"))
    am = os.path.join(HERE, "area_map.tsv")
    if os.path.isfile(am) and not table:
        rows = [x.rstrip("\n").split("\t") for x in open(am, encoding="utf-8") if x.strip() and not x.startswith("#")]
        fo = {}
        for r in rows:
            if len(r) >= 2: fo.setdefault(r[1], set()).add(r[0])
        files = [f[len(ROOT) + len("/SCRIP/"):] for f in glob.glob(ROOT + "/SCRIP/src/**/*", recursive=True) if os.path.isfile(f) and re.search(r"\.(c|cpp|h|inc|s|y|l|pl|sc|icn)$", f)]
        sp = st = un = 0
        for f in files:
            fs = set()
            for car, ff in fo.items():
                if car == f or (car.endswith("/") and f.startswith(car)): fs |= ff
            if not fs: un += 1
            elif "*" in fs: st += 1
            else: sp += 1
        print("ATTR_COVERAGE_CARRIERS files=%d specific=%d star=%d unmapped=%d" % (len(files), sp, st, un))
    if not read: print("REFUSE(2): no table matched"); return 2
    return 1 if bad else 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
