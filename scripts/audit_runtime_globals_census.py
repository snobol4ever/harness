#!/usr/bin/env python3
"""audit_runtime_globals_census.py -- THE RUNTIME GLOBALS CENSUS (Lon 2026-10-08, in-chat to the ceo, verbatim: "Take an inventory of all
global variables use at runtime. Ask the question, can that global live on one of the 3 ZETAS? If so make a task to move it and remove the
global variable." -- "Regarding the global variable census, do not consider the parser code, nor the lower nor the emitter for now. Just
the runtime." -- "Do all the global variables start with prefix "g_", if not, make it so."; CEO-1561). THE POPULATION is measured, never
typed: every writable data symbol (nm classes B D b d) the built runtime library defines in a translation unit under src/runtime/, read
with its defining file and line from the -g debug information of out/libscrip_rt.so. A symbol spelled name.NN is a function-scope static
(a cached-getenv seam, a once flag, a local buffer); a file-scope global is any other.
THE SECTIONS (ceo CEO-1575, 2026-10-09: "a table never written is not state"): nm's d and D also cover .data.rel.ro, so each symbol's
section is read from objdump -t by its address and name, and only a WRITABLE section counts -- .data, .bss, their TLS twins .tdata and
.tbss, COMMON -- never .rodata or .data.rel.ro, as test_gate_pl_no_new_global.sh reads them since 9e50691a0. A table const-qualified to
the pointer (static const char *const t[]) leaves the count; one with a writable slot (static const char *t[]) stays, because it is state.
A defined data symbol objdump cannot place is REFUSED rc=2, never guessed into either side.
    --tree runtime|compiler  the population: src/runtime (the default) or the compiler stages src/parsers src/lower src/emitter
                           src/templates src/ir src/optimizer src/driver (Lon: "You could put all the parser globals, lower globals,
                           emitter driver globals, template globals (g_emit), in SEPERATE global structs. g_parser, g_lower,
                           g_emitter, g_template.")
    --list                 every symbol by file (file, line, size, nm class, name)
    --file F [--max N]     the symbols defined in file F (a path suffix); rc 1 while more than N (default 0) file-scope globals remain
    --all [--max N]        rc 1 while more than N (default 0) file-scope globals remain in the whole population; lists them
    --gone NAME...         rc 1 while any named symbol is still defined; rc 0 when every one is gone
    --prefix               THE g_ RULE: rc 1 while any file-scope global of the population does not start with g_; lists them
    --root DIR             read DIR/out/libscrip_rt.so and DIR/src/ instead of this tree (the self-test's fixture library)
    rc 2 (REFUSED) when the library is missing or carries no debug file names: a census that cannot see its population says so.
"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
TREES = {"runtime": ("runtime",), "compiler": ("parsers", "lower", "emitter", "templates", "ir", "optimizer", "driver")}


WRITABLE = re.compile(r"^(\.data(?!\.rel\.ro)|\.bss|\.tdata|\.tbss|\*COM\*)")


def sections(lib):
    sec = {}
    for line in subprocess.run(["objdump", "-t", lib], capture_output=True, text=True).stdout.split("\n"):
        f = line.split()
        if len(f) < 5 or "O" not in f[1:3]:
            continue
        sec[(int(f[0], 16), f[-1])] = f[f.index("O") + 1]
    return sec


def population(tree, root=ROOT):
    lib = os.path.join(root, "out", "libscrip_rt.so")
    if not os.path.isfile(lib):
        print("REFUSED (rc=2): %s is missing -- build first" % lib); sys.exit(2)
    dirs = tuple(os.path.join(root, "src", d) + os.sep for d in TREES[tree])
    out = subprocess.run(["nm", "-l", "-S", "--defined-only", lib], capture_output=True, text=True).stdout
    sec = sections(lib)
    rows, unplaced, const = [], [], 0
    for line in out.split("\n"):
        p = line.split()
        if len(p) < 5 or p[2] not in ("B", "D", "b", "d"):
            continue
        f, _, ln = p[4].partition(":")
        if not f.startswith(dirs):
            continue
        s = sec.get((int(p[0], 16), p[3]))
        if s is None:
            unplaced.append("%s %s" % (p[3], p[4])); continue
        if not WRITABLE.match(s):
            const += 1; continue
        rows.append({"name": p[3], "size": int(p[1], 16), "cls": p[2], "sect": s, "file": f[len(root) + 1:], "line": int(ln) if ln.isdigit() else 0,
                     "scope": "function" if re.search(r"\.\d+$", p[3]) else "file"})
    if unplaced:
        for u in unplaced[:10]:
            print("  unplaced: %s" % u)
        print("REFUSED (rc=2): objdump -t places no section for %d defined data symbol(s) of src/%s in %s" % (len(unplaced), "|".join(TREES[tree]), lib)); sys.exit(2)
    if not rows and not const:
        print("REFUSED (rc=2): nm found no data symbol with a src/%s file name in %s (no -g debug information?)" % ("|".join(TREES[tree]), lib)); sys.exit(2)
    rows.sort(key=lambda r: (r["file"], r["line"], r["name"]))
    print("(%d constant data symbol(s) in .rodata/.data.rel.ro not counted, CEO-1575)" % const)
    return rows


def main(argv):
    tree = argv[argv.index("--tree") + 1] if "--tree" in argv else "runtime"
    if tree not in TREES:
        print("REFUSED (rc=2): --tree takes runtime or compiler"); return 2
    root = os.path.abspath(argv[argv.index("--root") + 1]) if "--root" in argv else ROOT
    rows = population(tree, root)
    if "--all" in argv:
        mx = int(argv[argv.index("--max") + 1]) if "--max" in argv else 0
        fs = [r for r in rows if r["scope"] == "file"]
        for r in fs:
            print("  %-40s %8d %-6s %s:%d" % (r["name"], r["size"], r["sect"], r["file"], r["line"]))
        verdict = "GREEN" if len(fs) <= mx else "RED"
        print("%s: the %s tree defines %d file-scope globals in %d files (%d function-scope statics beside them); the bar is %d" % (verdict, tree, len(fs), len({r["file"] for r in fs}), len(rows) - len(fs), mx))
        return 0 if verdict == "GREEN" else 1
    if "--list" in argv:
        for r in rows:
            print("%-40s %5d %8d %-6s %s" % (r["file"], r["line"], r["size"], r["sect"], r["name"]))
        print("runtime globals: %d (%d file-scope, %d function-scope) in %d files" % (len(rows), sum(r["scope"] == "file" for r in rows), sum(r["scope"] == "function" for r in rows), len({r["file"] for r in rows})))
        return 0
    if "--file" in argv:
        f = argv[argv.index("--file") + 1]
        mx = int(argv[argv.index("--max") + 1]) if "--max" in argv else 0
        sel = [r for r in rows if r["file"].endswith(f)]
        fs = [r for r in sel if r["scope"] == "file"]
        for r in sel:
            print("  %-36s %8d %-6s :%d%s" % (r["name"], r["size"], r["sect"], r["line"], "" if r["scope"] == "file" else "  (function-scope static)"))
        verdict = "GREEN" if len(fs) <= mx else "RED"
        print("%s: %s defines %d file-scope globals (%d function-scope statics beside them); the bar is %d" % (verdict, f, len(fs), len(sel) - len(fs), mx))
        return 0 if verdict == "GREEN" else 1
    if "--gone" in argv:
        names = argv[argv.index("--gone") + 1:]
        names = [n for n in names if not n.startswith("--")]
        have = {r["name"]: r for r in rows}
        still = [n for n in names if n in have]
        for n in still:
            r = have[n]; print("  still defined: %-36s %s:%d" % (n, r["file"], r["line"]))
        if still:
            print("RED: %d of %d named globals still defined under src/runtime" % (len(still), len(names))); return 1
        print("GREEN: none of the %d named globals is defined under src/runtime" % len(names)); return 0
    if "--prefix" in argv:
        bad = [r for r in rows if r["scope"] == "file" and not r["name"].startswith("g_")]
        for r in bad:
            print("  %-40s %s:%d" % (r["name"], r["file"], r["line"]))
        tot = sum(r["scope"] == "file" for r in rows)
        if bad:
            print("RED: %d of %d file-scope %s globals do not start with g_ (Lon 2026-10-08: make it so)" % (len(bad), tot, tree)); return 1
        print("GREEN: every one of the %d file-scope %s globals starts with g_" % (tot, tree)); return 0
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
