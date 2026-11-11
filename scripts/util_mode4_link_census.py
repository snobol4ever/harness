#!/usr/bin/env python3
# util_mode4_link_census.py -- THE MODE-4 LINK CENSUS (row instruments-no-pie-s1-one-helper-owns-the-mode-4-link-line-and-a-census-counts-the-rest, s1 of
# instruments-the-866-mode-4-link-lines-in-820-harness-scripts-drop-no-pie; R-1536). A LINK LINE is a non-comment line of a harness script (*.sh, *.py) that
# holds -lscrip_rt on a gcc or cc command (a word gcc or cc, or $CC). lib_mode4_link.sh is the one helper that owns the line and is not counted; so are the
# parent's three exempt builds: bench_startup_touch_ab.sh's scrip_driver.o line, util_gc_dead_oracle.sh's OBJ line, build_spitbol_archive.sh's CFLAGS line.
# Families by file name: pl (test_gate_pl_*), pas (test_gate_pas_*), sno (test_gate_sno_*), icn (test_gate_icn_*), rest (all others).
# usage: util_mode4_link_census.py                 one count line per family and the total; rc 1 when the total is above 0
#        util_mode4_link_census.py --family F      that family's lines (file:line); rc 0 when none, else rc 1
#        util_mode4_link_census.py --selftest      plants a raw link line and a helper caller in a scratch dir; rc 0 when the census reads 1 and 0
import re
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
FAMILIES = ("pl", "pas", "sno", "icn", "rest")
PREFIXES = (("test_gate_pl_", "pl"), ("test_gate_pas_", "pas"), ("test_gate_sno_", "sno"), ("test_gate_icn_", "icn"))
LIB = "lib_mode4_link.sh"
SELF = "util_mode4_link_census.py"
EXEMPT = (("bench_startup_touch_ab.sh", "scrip_driver.o"), ("util_gc_dead_oracle.sh", "OBJ"), ("build_spitbol_archive.sh", "CFLAGS"))
CC = re.compile(r"(?<![\w./])(gcc|cc|\$\{?CC\}?)(?![\w.-])")


def family(name):
    for prefix, fam in PREFIXES:
        if name.startswith(prefix):
            return fam
    return "rest"


def is_link(line):
    s = line.strip()
    return bool(s) and not s.startswith("#") and "-lscrip_rt" in s and CC.search(s) is not None


def exempt(name, line):
    return name in (LIB, SELF) or any(name == f and tok in line for f, tok in EXEMPT)


def scan(d):
    hits = []
    for p in sorted(Path(d).iterdir()):
        if not p.is_file() or p.suffix not in (".sh", ".py"):
            continue
        for i, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if is_link(line) and not exempt(p.name, line):
                hits.append((family(p.name), p.name, i, line.strip()))
    return hits


def selftest():
    d = tempfile.mkdtemp(prefix="m4link_selftest.")
    try:
        Path(d, LIB).write_text('s4e_m4_link() {\n  "${S4E_M4_CC:-gcc}" -m64 -no-pie "$1" -o "$2" -L"$3" -lscrip_rt -lm\n}\n', encoding="utf-8")
        Path(d, "test_gate_x_raw.sh").write_text("gcc -m64 -no-pie w.s -o w -L. -lscrip_rt -lm\n", encoding="utf-8")
        Path(d, "test_gate_x_helper.sh").write_text('. "$HERE/lib_mode4_link.sh"\ns4e_m4_link w.s w .\n', encoding="utf-8")
        hits = scan(d)
        raw = sum(1 for h in hits if h[1] == "test_gate_x_raw.sh")
        helper = sum(1 for h in hits if h[1] == "test_gate_x_helper.sh")
        if len(hits) == 1 and raw == 1 and helper == 0:
            print("M4_LINK_CENSUS selftest ok")
            return 0
        print("M4_LINK_CENSUS selftest RED: raw=%d helper=%d total=%d" % (raw, helper, len(hits)))
        return 1
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main(argv):
    if argv == ["--selftest"]:
        return selftest()
    hits = scan(HERE)
    if not argv:
        counts = {f: 0 for f in FAMILIES}
        for h in hits:
            counts[h[0]] += 1
        for f in FAMILIES:
            print("M4_LINK_CENSUS family=%s lines=%d" % (f, counts[f]))
        print("M4_LINK_CENSUS total=%d" % len(hits))
        return 0 if not hits else 1
    if len(argv) == 2 and argv[0] == "--family" and argv[1] in FAMILIES:
        rows = [h for h in hits if h[0] == argv[1]]
        for _, name, i, text in rows:
            print("%s:%d: %s" % (name, i, text))
        print("M4_LINK_CENSUS family=%s lines=%d" % (argv[1], len(rows)))
        return 0 if not rows else 1
    print("usage: util_mode4_link_census.py [--family {%s} | --selftest]" % ",".join(FAMILIES), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
