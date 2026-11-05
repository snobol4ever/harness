#!/usr/bin/env python3
"""util_gen_gencat_table.py -- generate src/runtime/rk_gencat_table.inc, the General_Category ranges the Raku regex boxes (by_name_dispatch.c) consult for <:Lu>, <:L>, <:Nd> and the long names.

Usage: python3 ../harness/scripts/util_gen_gencat_table.py --unicode-data UnicodeData.txt [--out PATH] [--check]

  --unicode-data  the UnicodeData.txt of the Unicode version the Raku lane is graded against (rakudo 2026.05 ships 17.0.0 at t/3rdparty/Unicode/17.0.0/UnicodeData.txt).
  --check         write nothing; exit 0 when the checked-in file equals what would be generated.

A code point missing from the table is Cn (unassigned); a "First>/Last>" pair in UnicodeData.txt is one range. Adjacent code points of one category are one row {lo, hi, category index}.
The category index is the position in rk_gc_short (and rk_gc_long); the generated file is byte-stable under util_reflow_200.py --apply.
"""
import argparse, os, subprocess, sys

SHORT = ["Cc", "Cf", "Cn", "Co", "Cs", "Ll", "Lm", "Lo", "Lt", "Lu", "Mc", "Me", "Mn", "Nd", "Nl", "No", "Pc", "Pd", "Pe", "Pf", "Pi", "Po", "Ps", "Sc", "Sk", "Sm", "So", "Zl", "Zp", "Zs"]
LONG = ["Control", "Format", "Unassigned", "Private_Use", "Surrogate", "Lowercase_Letter", "Modifier_Letter", "Other_Letter", "Titlecase_Letter", "Uppercase_Letter", "Spacing_Mark",
        "Enclosing_Mark", "Nonspacing_Mark", "Decimal_Number", "Letter_Number", "Other_Number", "Connector_Punctuation", "Dash_Punctuation", "Close_Punctuation", "Final_Punctuation",
        "Initial_Punctuation", "Other_Punctuation", "Open_Punctuation", "Currency_Symbol", "Modifier_Symbol", "Math_Symbol", "Other_Symbol", "Line_Separator", "Paragraph_Separator", "Space_Separator"]

def parse(path):
    cats = {}
    first = None
    for line in open(path, encoding="utf-8"):
        f = line.rstrip("\n").split(";")
        if len(f) < 3: continue
        cp, name, gc = int(f[0], 16), f[1], f[2]
        if gc not in SHORT: sys.exit("unknown General_Category %s at U+%04X" % (gc, cp))
        if name.endswith(", First>"): first = cp; continue
        if name.endswith(", Last>"):
            for c in range(first, cp + 1): cats[c] = gc
            first = None
            continue
        cats[cp] = gc
    return cats

def render(cats):
    rows = []
    for cp in sorted(cats):
        g = SHORT.index(cats[cp])
        if g == 2: continue
        if rows and rows[-1][1] + 1 == cp and rows[-1][2] == g: rows[-1][1] = cp
        else: rows.append([cp, cp, g])
    out = ["static const unsigned int rk_gc_rng[][3] = {"]
    line = "   "
    for r in rows:
        item = " {0x%X,0x%X,%d}," % tuple(r)
        if len(line) + len(item) > 180: out.append(line); line = "   "
        line += item
    out.append(line.rstrip(","))
    out.append("};")
    out.append("static const int rk_gc_nrng = %d;" % len(rows))
    out.append("static const char *const rk_gc_short[] = { %s };" % ", ".join('"%s"' % s for s in SHORT))
    long_line = "static const char *const rk_gc_long[] = { %s };" % ", ".join('"%s"' % s for s in LONG)
    if len(long_line) > 190:
        parts = ['"%s"' % s for s in LONG]
        long_line = "static const char *const rk_gc_long[] = {\n    " + ",\n    ".join(", ".join(parts[i:i + 5]) for i in range(0, len(parts), 5)) + " };"
    out.append(long_line)
    return "\n".join(out) + "\n"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--unicode-data", required=True)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "SCRIP", "src", "runtime", "rk_gencat_table.inc"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    text = render(parse(a.unicode_data))
    tmp = a.out[:-4] + "_new.inc"
    open(tmp, "w", encoding="utf-8").write(text)
    refl = os.path.join(os.path.dirname(os.path.abspath(__file__)), "util_reflow_200.py")
    subprocess.run([sys.executable, refl, "--apply", tmp], check=True, stdout=subprocess.DEVNULL)
    text = open(tmp, encoding="utf-8").read()
    os.unlink(tmp)
    if a.check:
        have = open(a.out, encoding="utf-8").read() if os.path.exists(a.out) else None
        if have == text: print("rk_gencat_table.inc current"); return 0
        print("rk_gencat_table.inc STALE"); return 1
    open(a.out, "w", encoding="utf-8").write(text)
    print("wrote", a.out, "rows", text.count("{0x"))
    return 0

if __name__ == "__main__":
    sys.exit(main())
