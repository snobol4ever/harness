#!/usr/bin/env python3
# util_steps_unique.py STEPS.tsv -- rc 0 when every step number of a DESIGN-PLAN step table names one row; rc 1 with one STEPS_DUP line per number used twice;
# rc 2 when the table cannot be read or holds no step. officer_01 2026-11-08 under CIO-10: the unicon table carried two rows numbered 48 and --step 48 graded the first.
import sys
if len(sys.argv) != 2:
    print("REFUSE(2): usage: util_steps_unique.py STEPS.tsv", file=sys.stderr); sys.exit(2)
try:
    lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except OSError as e:
    print("REFUSE(2): cannot read %s: %s" % (sys.argv[1], e), file=sys.stderr); sys.exit(2)
seen = {}
for ln, line in enumerate(lines, 1):
    if not line or line.startswith("#"):
        continue
    f = line.split("\t")
    if len(f) < 2 or f[0] == "step":
        continue
    seen.setdefault(f[0], []).append(ln)
if not seen:
    print("REFUSE(2): no step rows in %s" % sys.argv[1], file=sys.stderr); sys.exit(2)
dup = [(k, v) for k, v in seen.items() if len(v) > 1]
for k, v in dup:
    print("STEPS_DUP step=%s lines=%s" % (k, ",".join(str(x) for x in v)))
if dup:
    print("GATE FAIL [util_steps_unique]: %d step number(s) name more than one row in %s" % (len(dup), sys.argv[1])); sys.exit(1)
print("GATE OK [util_steps_unique]: %d steps, each number names one row (%s)" % (len(seen), sys.argv[1]))
