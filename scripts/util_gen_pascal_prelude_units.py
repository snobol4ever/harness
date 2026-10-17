#!/usr/bin/env python3
"""util_gen_pascal_prelude_units.py -- SCRIP'S OWN PASCAL RTL UNITS AS PRELUDE SOURCES (row pascal-uses-and-units-..., Lon 2026-10-10,
CEO-1611: "Certainly we should allow the "uses" feature for Pascal since SNOBOL4 has INCLUDE, and Snocone will have import.").
The units a program names in a uses clause and no file beside it supplies -- sysutils, math, strutils, strings -- are SCRIP's own
Pascal, one file each under src/parsers/pascal/prelude/, and the driver (pascal_driver.c) parses one only when a program names it,
exactly as a unit beside the program. This writes src/parsers/pascal/pascal_prelude_units.inc, a committed table of the sources, the
way util_gen_prolog_prelude_libs.py writes the Prolog prelude libraries' (CEO-1473): { name, source } pairs ending in { 0, 0 }.
  python3 ../harness/scripts/util_gen_pascal_prelude_units.py            write the .inc
  python3 ../harness/scripts/util_gen_pascal_prelude_units.py --check    rc 1 when the committed .inc differs from a fresh generation, 0 when equal
  --dir D and --out F read the units from D and write or check F (the sync gate's self-test plants on scratch copies); rc 2 refuses.
"""
import os, sys
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
PRE = os.path.join(ROOT, "src", "parsers", "pascal", "prelude")
OUT = os.path.join(ROOT, "src", "parsers", "pascal", "pascal_prelude_units.inc")


def c_line(line):
    return '    "' + line.replace("\\", "\\\\").replace('"', '\\"') + '\\n"'


def generate(pre):
    if not os.path.isdir(pre):
        print("REFUSED(2): no prelude directory " + pre)
        sys.exit(2)
    names = sorted(f[:-4] for f in os.listdir(pre) if f.endswith(".pas"))
    if not names:
        print("REFUSED(2): no prelude units under " + pre)
        sys.exit(2)
    out = ["typedef struct { const char *name; const char *src; } pas_prelude_unit_t;"]
    for i, n in enumerate(names):
        src = open(os.path.join(pre, n + ".pas"), encoding="utf-8").read().split("\n")
        if src and src[-1] == "":
            src = src[:-1]
        out.append("static const char PAS_PRELUDE_UNIT_%d_SRC[] =" % i)
        out.extend(c_line(l) for l in src)
        out[-1] += ";"
    out.append("static const pas_prelude_unit_t PAS_PRELUDE_UNITS[] = {")
    out.extend('    { "%s", PAS_PRELUDE_UNIT_%d_SRC },' % (n, i) for i, n in enumerate(names))
    out.append("    { 0, 0 }")
    out.append("};")
    return "\n".join(out) + "\n"


def main():
    av = sys.argv[1:]
    pre = av[av.index("--dir") + 1] if "--dir" in av else PRE
    out = av[av.index("--out") + 1] if "--out" in av else OUT
    txt = generate(pre)
    if "--check" in av:
        cur = open(out, encoding="utf-8").read() if os.path.isfile(out) else ""
        if cur != txt:
            print("STALE: %s differs from a fresh generation from %s -- run python3 ../harness/scripts/util_gen_pascal_prelude_units.py" % (out, pre))
            return 1
        print("GREEN: %s matches its %d prelude unit(s)" % (os.path.relpath(out, ROOT), txt.count("PAS_PRELUDE_UNIT_") // 2))
        return 0
    open(out, "w", encoding="utf-8").write(txt)
    print("wrote " + os.path.relpath(out, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
