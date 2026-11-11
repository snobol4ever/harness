#!/usr/bin/env python3
"""util_gen_raku_setting.py -- THE RAKU SETTING AS EMBEDDED SOURCE (ARCH-RAKU-TO-100.md section 1.2 (c) and section 6 step 0, R-2044,
the cao's row raku-ladder-step-1-the-setting-in-raku-the-loader-and-test-rakumod-as-its-first-file-r-2044).
The setting is Raku source under src/parsers/raku/setting/, one module per file, its name read from its path (Test.rakumod is Test,
Test/Util.rakumod is Test::Util). This writes src/parsers/raku/raku_setting.inc, a committed table of the sources the Raku front end's
module road (import_module in rk_syntax.c) reads when no file on the program's lib path names the module, exactly as the Pascal prelude
units (util_gen_pascal_prelude_units.py) and the Prolog prelude libraries are embedded: { name, source, exports } triples ending in { 0, 0, 0 }.
exports is the space-padded list of the sub and proto names the module declares (CTO-517 step 1: an undeclared routine used by a program is
imported from the module that exports it, CORE for the core prelude; rk_syntax.c core_export_has reads this column).
  python3 ../harness/scripts/util_gen_raku_setting.py            write the .inc
  python3 ../harness/scripts/util_gen_raku_setting.py --check    rc 1 when the committed .inc differs from a fresh generation, 0 when equal
  --dir D and --out F read the setting from D and write or check F (a gate's plant on scratch copies); rc 2 refuses.
"""
import os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
SET = os.path.join(ROOT, "src", "parsers", "raku", "setting")
OUT = os.path.join(ROOT, "src", "parsers", "raku", "raku_setting.inc")


def c_line(line):
    return '    "' + line.replace("\\", "\\\\").replace('"', '\\"').replace("??", "?\\?") + '\\n"'


def exports_of(src):
    names = []
    for m in re.finditer(r"^[ \t]*(?:(?:proto|multi)[ \t]+)*sub[ \t]+([A-Za-z_][A-Za-z0-9_-]*)", src, re.M):
        if m.group(1) not in names:
            names.append(m.group(1))
    for m in re.finditer(r"^my[ \t]+(\$\*[A-Za-z_][A-Za-z0-9_-]*)", src, re.M):
        if m.group(1) not in names:
            names.append(m.group(1))
    return " " + " ".join(names) + " " if names else ""


def modules(d):
    found = []
    for base, _dirs, files in os.walk(d):
        for f in files:
            if f.endswith(".rakumod"):
                rel = os.path.relpath(os.path.join(base, f), d)[:-len(".rakumod")]
                found.append(("::".join(rel.split(os.sep)), os.path.join(base, f)))
    return sorted(found)


def generate(d):
    if not os.path.isdir(d):
        print("REFUSED(2): no setting directory " + d)
        sys.exit(2)
    mods = modules(d)
    if not mods:
        print("REFUSED(2): no .rakumod under " + d)
        sys.exit(2)
    out = ["typedef struct { const char *name; const char *src; const char *exports; } rk_setting_module_t;"]
    exp = []
    for i, (_n, path) in enumerate(mods):
        text = open(path, encoding="utf-8").read()
        exp.append(exports_of(text))
        src = text.split("\n")
        if src and src[-1] == "":
            src = src[:-1]
        out.append("static const char RK_SETTING_MODULE_%d_SRC[] =" % i)
        out.extend(c_line(l) for l in src)
        out[-1] += ";"
    out.append("static const rk_setting_module_t RK_SETTING_MODULES[] = {")
    out.extend('    { "%s", RK_SETTING_MODULE_%d_SRC, "%s" },' % (n, i, exp[i]) for i, (n, _p) in enumerate(mods))
    out.append("    { 0, 0, 0 }")
    out.append("};")
    return "\n".join(out) + "\n"


def main():
    av = sys.argv[1:]
    d = av[av.index("--dir") + 1] if "--dir" in av else SET
    out = av[av.index("--out") + 1] if "--out" in av else OUT
    txt = generate(d)
    if "--check" in av:
        cur = open(out, encoding="utf-8").read() if os.path.isfile(out) else ""
        if cur != txt:
            print("STALE: %s differs from a fresh generation from %s -- run python3 ../harness/scripts/util_gen_raku_setting.py" % (out, d))
            return 1
        print("GREEN: %s matches its %d setting module(s)" % (os.path.relpath(out, ROOT), len(modules(d))))
        return 0
    open(out, "w", encoding="utf-8").write(txt)
    print("wrote " + os.path.relpath(out, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
