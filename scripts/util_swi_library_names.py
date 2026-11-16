#!/usr/bin/env python3
"""util_swi_library_names.py -- write the names of every library file of the oracle swipl 9.0.4, with its folder (DESIGN J16 of
the prolog-xpce plan, the cfo 2026-11-16: which names are SWI libraries is a fact of the dialect, written once from the oracle's
install into one committed text file beside SCRIP's prelude sources, and embedded by util_gen_prolog_prelude_libs.py; no build
and no run reads the oracle).

USAGE: util_swi_library_names.py [--home DIR] [--out PATH] [--check]
  --home   the oracle's home (default: the home swipl reports); its library/ folder is read
  --out    default $S4E_SCRIP/src/parsers/prolog/prelude/SWI_LIBRARY_NAMES.txt
  --check  compare with the committed file; rc 1 if it differs
rc 0 written / in sync; 1 differs (--check); 2 refused (no swipl, not 9.0.4, no library folder).
"""
import argparse, os, subprocess, sys
VERSION = "9.0.4"
def swipl_home():
    r = subprocess.run(["swipl", "--dump-runtime-variables"], capture_output=True, text=True, timeout=60)
    for ln in r.stdout.splitlines():
        if ln.startswith("PLBASE="): return ln.split("=", 1)[1].strip().strip('";')
    return None
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    scrip = os.environ.get("S4E_SCRIP") or os.environ.get("S4E_HOME") or os.getcwd()
    ap.add_argument("--home", default=None)
    ap.add_argument("--out", default=os.path.join(scrip, "src", "parsers", "prolog", "prelude", "SWI_LIBRARY_NAMES.txt"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    try:
        v = subprocess.run(["swipl", "--version"], capture_output=True, text=True, timeout=60).stdout
    except (OSError, subprocess.SubprocessError) as e:
        print("REFUSED(2) util_swi_library_names: no swipl (%s)" % e, file=sys.stderr); return 2
    if (" version %s " % VERSION) not in v:
        print("REFUSED(2) util_swi_library_names: the oracle is not swipl %s: %s" % (VERSION, v.strip()), file=sys.stderr); return 2
    home = a.home or swipl_home()
    lib = os.path.join(home or "", "library")
    if not home or not os.path.isdir(lib):
        print("REFUSED(2) util_swi_library_names: no library folder under %s" % home, file=sys.stderr); return 2
    names = sorted(os.path.relpath(os.path.join(d, f), lib)[:-3] for d, _, fs in os.walk(lib) for f in fs if f.endswith(".pl"))
    txt = "# the library files of swipl %s with their folders, written by util_swi_library_names.py from %s; regenerated, never edited\n" % (VERSION, lib)
    txt += "".join(n + "\n" for n in names)
    if a.check:
        cur = open(a.out).read() if os.path.exists(a.out) else ""
        if cur == txt: print("SWI_LIBRARY_NAMES in sync: %d names" % len(names)); return 0
        print("SWI_LIBRARY_NAMES STALE: %s differs from the oracle's %d names" % (a.out, len(names))); return 1
    with open(a.out, "w") as f: f.write(txt)
    print("WROTE %s: %d names" % (a.out, len(names)))
    return 0
if __name__ == "__main__":
    sys.exit(main())
