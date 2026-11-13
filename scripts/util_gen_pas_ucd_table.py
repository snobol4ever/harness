#!/usr/bin/env python3
"""util_gen_pas_ucd_table.py -- THE GENERATOR of SCRIP/src/runtime/pas_ucd_table.inc, the Unicode property table the Pascal builtin __pas_ucd reads.

The data is cut from the oracle, never from Unicode files (the cto 2026-11-13, row fpc-ucd-table-generator-and-the-pas-ucd-builtin): a Pascal program
over fpc 3.2.2's own unicodedata unit asks GetProps for every code point 0 to $10FFFF and prints what it reads; this script compiles it with the oracle
(fpc_bin() of lib_oracle_flags.sh, never a bare path), runs it, and writes the include. So the table is exactly 3.2.2's Unicode version, whatever that is.

  (no argument)   regenerate and write SCRIP/src/runtime/pas_ucd_table.inc
  --check         regenerate in memory and compare with the file: rc 0 equal, rc 1 differs or missing, rc 2 the oracle is absent
The include is regenerated, never edited (harness/scripts/generated_tables.tsv).
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "SCRIP", "src", "runtime", "pas_ucd_table.inc")
LIB = os.path.join(HERE, "lib_oracle_flags.sh")

SWEEP = """program ucdsweep;
{$mode objfpc}{$H+}
uses SysUtils, unicodedata;
var cp, first, cur, t: Cardinal; p: PUC_Prop; v: Double; bits: QWord;
begin
  first := 0; cur := GetProps(Cardinal(0))^.Category;
  for cp := 0 to $10FFFF do begin
    p := GetProps(cp);
    if p^.Category <> cur then begin
      writeln('C ', first, ' ', cp - 1, ' ', cur);
      first := cp; cur := p^.Category;
    end;
    t := Cardinal(p^.SimpleUpperCase);
    if t <> 0 then writeln('U ', cp, ' ', t);
    t := Cardinal(p^.SimpleLowerCase);
    if t <> 0 then writeln('L ', cp, ' ', t);
    if p^.WhiteSpace then writeln('W ', cp);
    v := p^.NumericValue;
    if v <> 0 then begin bits := PQWord(@v)^; writeln('N ', cp, ' ', IntToHex(bits, 16)); end;
  end;
  writeln('C ', first, ' ', $10FFFF, ' ', cur);
end.
"""


def oracle():
    r = subprocess.run(["bash", "-c", 'source "%s" && fpc_bin' % LIB], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def sweep(fpc):
    with tempfile.TemporaryDirectory(prefix="ucdsweep_") as d:
        src = os.path.join(d, "ucdsweep.pas")
        with open(src, "w") as f:
            f.write(SWEEP)
        c = subprocess.run([fpc, "-Mobjfpc", "-O1", "-FU" + d, "-FE" + d, src], capture_output=True, text=True)
        exe = os.path.join(d, "ucdsweep")
        if c.returncode != 0 or not os.path.isfile(exe):
            sys.stderr.write("REFUSE(2): the sweep did not compile under %s:\n%s\n" % (fpc, (c.stdout + c.stderr)[-600:]))
            sys.exit(2)
        r = subprocess.run([exe], capture_output=True, text=True)
        if r.returncode != 0:
            sys.stderr.write("REFUSE(2): the sweep run failed rc=%d\n" % r.returncode)
            sys.exit(2)
        return r.stdout


def rows(lines, key, width):
    return [tuple(l.split()[1:1 + width]) for l in lines if l.startswith(key + " ")]


def wrap(items, per):
    out = []
    for i in range(0, len(items), per):
        out.append("    " + ", ".join(items[i:i + per]))
    return ",\n".join(out)


def build(text):
    lines = text.splitlines()
    cat = rows(lines, "C", 3)
    upper = rows(lines, "U", 2)
    lower = rows(lines, "L", 2)
    ws = rows(lines, "W", 1)
    num = rows(lines, "N", 2)
    if not cat or cat[0][0] != "0" or cat[-1][1] != str(0x10FFFF):
        sys.stderr.write("REFUSE(2): the category runs do not cover 0 to 10FFFF\n")
        sys.exit(2)
    parts = []
    parts.append("static const unsigned int pas_ucd_cat[][3] = {\n" + wrap(["{%s,%s,%s}" % r for r in cat], 6) + " };")
    parts.append("static const unsigned int pas_ucd_upper[][2] = {\n" + wrap(["{%s,%s}" % r for r in upper], 8) + " };")
    parts.append("static const unsigned int pas_ucd_lower[][2] = {\n" + wrap(["{%s,%s}" % r for r in lower], 8) + " };")
    parts.append("static const unsigned int pas_ucd_ws[] = {\n" + wrap([r[0] for r in ws], 12) + " };")
    parts.append("static const struct { unsigned int cp; unsigned long long bits; } pas_ucd_num[] = {\n" + wrap(["{%s,0x%sULL}" % r for r in num], 4) + " };")
    parts.append("#define PAS_UCD_NCAT %d\n#define PAS_UCD_NUPPER %d\n#define PAS_UCD_NLOWER %d\n#define PAS_UCD_NWS %d\n#define PAS_UCD_NNUM %d" % (len(cat), len(upper), len(lower), len(ws), len(num)))
    return "\n".join(parts) + "\n"


def main(argv):
    fpc = oracle()
    if not fpc:
        sys.stderr.write("REFUSE(2): the fpc oracle is absent (fpc_bin of lib_oracle_flags.sh)\n")
        return 2
    want = build(sweep(fpc))
    if "--check" in argv:
        have = open(OUT).read() if os.path.isfile(OUT) else None
        if have == want:
            print("PAS_UCD_TABLE CURRENT: %s" % OUT)
            return 0
        print("PAS_UCD_TABLE STALE: %s differs from a regeneration -- run: python3 harness/scripts/util_gen_pas_ucd_table.py" % OUT)
        return 1
    with open(OUT, "w") as f:
        f.write(want)
    print("WROTE %s (%d bytes)" % (OUT, len(want)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
