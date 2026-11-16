#!/usr/bin/env python3
"""util_icon_xwin_interface.py -- THE WINDOW OBJECT'S INTERFACE, written down (the cto 10:0x CST 2026-11-16, on Lon's ruling of
09:5x CST, verbatim: "Keep Unicon graphics as a separate replaceable library."; officer_07).

The boundary between SCRIP's runtime and a window object is the whole contract a replaceable library is built against. This
script reads it from the built object and the sources, never guesses it, and writes ROOT/src/runtime/xwin_interface.tsv, in the
SCRIP clone beside the object's sources (the cto 10:1x CST: a table derived from SCRIP's build lives in the SCRIP clone and lands
with the code, skill seat-conduct section 2), so the seat that changes the interface regenerates it in its own landing:

  export  every name the object exports (nm -D of out/libscrip_xwin.so): its C signature read from the source that defines it,
          the file, what in SCRIP calls it, and its contract (a bt_ entry's from xwin_functions.tsv)
  import  every name the object takes from the runtime (nm -D -u of the object met by nm -D of out/libscrip_rt.so): its C
          signature read from the runtime source that defines it, the file, the object's files that use it, and its contract
  offer   every name the hand-written contract table lists that the object neither exports nor imports: a name SCRIP's runtime
          offers to any window library (a Unicon object binds it, Arizona's does not), its C signature read from the runtime source
          that defines it, the file, and its contract; libscrip_rt.so must define and export it (the cto 12:1x CST 2026-11-16, on
          officer_07's ask from the Unicon object's step U3)
  form    the data that crosses: the descriptor, the file block, the cset, large-integer and real blocks in the oracle's layout,
          the layout word, the roots and how they are registered, each as its C text read from the source
  library each system library the object needs (readelf NEEDED) and how many of its names the object calls

The contract lines of exports and imports are hand-written in ROOT/src/runtime/xwin_interface_contract.tsv beside it; a name with
none is red.

  --write [ROOT]   regenerate the table from ROOT (default S4E_SCRIP), its out/ objects and its sources
  --check [ROOT]   rc 0 the table says what the object and the sources say; rc 1 the object exports or imports a name the table
                   lacks or no longer does, a signature or a form changed, a name has no contract, or an offered name is one
                   libscrip_rt.so does not export (each named); rc 2 REFUSE:
                   no ROOT, no out/libscrip_xwin.so or out/libscrip_rt.so in it, or no table or contract file in it
"""
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.dirname(HERE)
OBJECT = "out/libscrip_xwin.so"
TABLE = "src/runtime/xwin_interface.tsv"
CONTRACT = "src/runtime/xwin_interface_contract.tsv"
RUNTIME = "out/libscrip_rt.so"
TREE = "src/runtime/xwin"
OBJECT_SOURCES = ["src/runtime/xwin", "src/runtime/xwin_shim.c", "src/runtime/xwin_shim.h", "src/runtime/xwin_lang.c"]
FORMS = [
    ("descriptor", "src/runtime/icn_extfn.c", r"typedef struct \{ icnx_word_t dword, vword; \} icnx_descr_t;"),
    ("descriptor-shim", "src/runtime/xwin_shim.h", r"typedef struct xwin_descr \{"),
    ("descriptor-oracle", "src/runtime/xwin/h/rstructs.h", r"struct descrip \{"),
    ("file-block", "src/runtime/icn_extfn.c", r"typedef struct \{ icnx_word_t title; FILE \*fp;"),
    ("file-block-shim", "src/runtime/xwin_shim.h", r"typedef struct xwin_file \{"),
    ("file-block-oracle", "src/runtime/xwin/h/rstructs.h", r"struct b_file \{"),
    ("cset-block-oracle", "src/runtime/xwin/h/rstructs.h", r"struct b_cset \{"),
    ("large-integer-block", "src/runtime/xwin_shim.h", r"typedef struct xwin_bignum \{"),
    ("large-integer-block-oracle", "src/runtime/xwin/h/rstructs.h", r"struct b_bignum \{"),
    ("real-block-oracle", "src/runtime/xwin/h/rstructs.h", r"struct b_real \{"),
    ("layout-word", "src/runtime/xwin/xwin_alloc.h", r"#define XWIN_LW\("),
    ("roots-words", "src/runtime/xwin/xwin_gen.c", r"const char \*const \*const xwin_root_words\[\]"),
    ("roots-descriptors", "src/runtime/xwin/xwin_gen.c", r"struct descrip \*const xwin_root_descrs\[\]"),
    ("roots-function", "src/runtime/xwin_shim.c", r"void xwin_gc_roots\(void\)"),
    ("roots-registration", "src/runtime/xwin_shim.c", r"__attribute__\(\(constructor\)\) static void xwin_shim_load"),
]
HEADER = ("# xwin_interface.tsv -- the boundary between SCRIP's runtime and the window object, read from the built object and the sources by "
          "util_icon_xwin_interface.py --write ROOT (regenerated, never edited; the contracts are xwin_interface_contract.tsv beside it); "
          "util_icon_xwin_interface.py --check holds it equal to the object.\n"
          "# kind <tab> name <tab> C signature or C text <tab> defined in <tab> called by (export), used by (import) or offered (offer) <tab> contract\n")


class Refuse(Exception):
    pass


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise Refuse("%s rc=%d: %s" % (" ".join(cmd[:3]), r.returncode, r.stderr.strip()[:200]))
    return r.stdout


def nm_defined(so):
    out = set()
    for line in run(["nm", "-D", "--defined-only", so]).split("\n"):
        f = line.split()
        if len(f) == 3 and f[1] in "TDBRVW":
            out.add(f[2].split("@")[0])
    return out


def nm_undefined(so):
    out = set()
    for line in run(["nm", "-D", "-u", so]).split("\n"):
        f = line.split()
        if f:
            out.add(f[-1].split("@")[0])
    return out


def needed(so):
    return [m.group(1) for m in re.finditer(r"\(NEEDED\)\s+Shared library: \[([^\]]+)\]", run(["readelf", "-d", so]))]


def lib_path(so, name):
    for line in run(["ldd", so]).split("\n"):
        m = re.match(r"\s*%s => (\S+)" % re.escape(name), line)
        if m:
            return m.group(1)
    return None


def source_files(root, paths, exclude=()):
    out = []
    for p in paths:
        full = os.path.join(root, p)
        if os.path.isfile(full):
            out.append(full)
            continue
        for dp, dn, fn in os.walk(full):
            if any(os.path.join(dp, "").startswith(os.path.join(root, e, "")) for e in exclude):
                continue
            for n in sorted(fn):
                if n.endswith((".c", ".h", ".inc", ".S", ".s")):
                    out.append(os.path.join(dp, n))
    return sorted(out)


_TEXT = {}


def read(path):   # each source is read once: the table has some eighty names and the tree some eight hundred files (MEASURED 2026-11-16: 61,107 reads and regex searches, 45 s of CPU, before this)
    t = _TEXT.get(path)
    if t is None:
        t = _TEXT[path] = open(path, errors="replace").read()
    return t


def signature(name, files, root):
    defn = re.compile(r"^(?:__attribute__\(\([^)]*\)\)\)\s*)?(?:static\s+)?([A-Za-z_][\w \t\*]*?[\s\*])%s\s*\(([^;{]*)\)\s*\{" % re.escape(name), re.M)
    decl = re.compile(r"^(?:extern\s+)?([A-Za-z_][\w \t\*]*?[\s\*])%s\s*\(([^;{]*)\)\s*;" % re.escape(name), re.M)
    data = re.compile(r"^(?:extern\s+)?((?:const\s+)?[A-Za-z_][\w \t\*]*?[\s\*])%s\s*(=|;|\[)" % re.escape(name), re.M)
    for rx, kind in ((defn, "definition"), (decl, "declaration"), (data, "data")):
        for f in files:
            t = read(f)
            m = rx.search(t) if name in t else None   # a file that does not hold the bare name cannot match
            if m:
                if kind == "data":
                    sig = " ".join((m.group(1) + name).split())
                else:
                    sig = " ".join((m.group(1) + name + "(" + m.group(2) + ")").split())
                return sig, os.path.relpath(f, root) + (" (" + kind + ")" if kind != "definition" else "")
    return None, None


def users(name, files, root):
    rx = re.compile(r"\b%s\b" % re.escape(name))
    return sorted(set(os.path.relpath(f, root) for f in files if name in read(f) and rx.search(read(f))))


def form_text(root, path, start):
    full = os.path.join(root, path)
    if not os.path.isfile(full):
        return None
    text = read(full)
    m = re.search(start, text)
    if not m:
        return None
    s = text.rfind("\n", 0, m.start()) + 1
    depth, i = 0, s
    while i < len(text):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        elif c in ";\n" and depth == 0 and i > m.end() - 1:
            if c == "\n" and text[s:i].rstrip().endswith(("\\", ",")):
                i += 1
                continue
            end = i + 1 if c == ";" else i
            return " ".join(re.sub(r"/\*.*?\*/", " ", text[s:end], flags=re.S).split())
        i += 1
    return None


def contracts(root):
    path = os.path.join(root, CONTRACT)
    if not os.path.isfile(path):
        raise Refuse("no contract file %s" % path)
    out = {}
    if os.path.isfile(path):
        for line in open(path):
            if line.strip() and not line.startswith("#"):
                k, _, v = line.rstrip("\n").partition("\t")
                out[k] = v
    return out


def bt_contracts(root):
    out = {}
    path = os.path.join(root, TREE, "xwin_functions.tsv")
    for line in open(path):
        if line.startswith("#") or not line.strip():
            continue
        f = line.rstrip("\n").split("\t")
        name, entry, res, nparams, susp = f[0], f[1], f[2], f[3], f[4]
        e = "bt_%s_h" % name if susp == "yes" else "bt_%s" % name
        out[e] = "the Icon builtin %s: hands its arguments to %s through rt_xwin_call_h (%s), its result sequence {%s}%s" % (
            name, entry, "any number of arguments" if nparams == "-1" else "%s argument(s)" % nparams, res,
            ", a generator through the resume slot" if susp == "yes" else "")
    return out


def measure(root):
    so, rt = os.path.join(root, OBJECT), os.path.join(root, RUNTIME)
    for p in (so, rt):
        if not os.path.isfile(p):
            raise Refuse("%s is absent: build the root first (make -j8)" % p)
    obj_files = source_files(root, OBJECT_SOURCES)
    rt_files = [f for f in source_files(root, ["src"], exclude=[TREE]) if f not in obj_files]
    caller_files = [f for f in rt_files if not os.path.relpath(f, root).startswith("src/runtime/xwin")]
    exports = sorted(nm_defined(so) - {"_init", "_fini"})
    rt_def = nm_defined(rt)
    imports = sorted(n for n in nm_undefined(so) if n in rt_def)
    con = contracts(root)
    con.update(bt_contracts(root))
    rows, problems = [], []
    for n in exports:
        sig, where = signature(n, obj_files, root)
        if not sig:
            problems.append("export %s: no definition in the object's sources" % n)
        rows.append(("export", n, sig or "-", where or "-", ", ".join(users(n, caller_files, root)) or "none in SCRIP's runtime yet", con.get(n, "")))
    for n in imports:
        sig, where = signature(n, rt_files, root)
        if not sig:
            problems.append("import %s: no definition or declaration in the runtime's sources" % n)
        rows.append(("import", n, sig or "-", where or "-", ", ".join(users(n, obj_files, root)) or "-", con.get(n, "")))
    hand = contracts(root)
    for n in sorted(set(hand) - set(exports) - set(imports)):
        if n not in rt_def:
            problems.append("offer %s: the contract table lists it, but libscrip_rt.so does not define and export it" % n)
        sig, where = signature(n, rt_files, root)
        if not sig:
            problems.append("offer %s: no definition or declaration in the runtime's sources" % n)
        rows.append(("offer", n, sig or "-", where or "-", "offered to a window library; Arizona's object does not import it", hand[n]))
    for name, path, start in FORMS:
        t = form_text(root, path, start)
        if t is None:
            problems.append("form %s: no text matching %s in %s" % (name, start, path))
        rows.append(("form", name, t or "-", path, "-", "-"))
    rt_name = os.path.basename(rt)
    und = nm_undefined(so)
    for lib in needed(so):
        p = lib_path(so, lib)
        n = len(und & nm_defined(p)) if p else 0
        rows.append(("library", lib, "%d names" % n, p or "-", "-", "-"))
    for r in rows:
        if r[0] in ("export", "import") and not r[5]:
            problems.append("%s %s has no contract line in %s" % (r[0], r[1], CONTRACT))
    return rows, problems


def fmt(rows):
    return HEADER + "".join("\t".join(r) + "\n" for r in rows)


def main():
    ap = argparse.ArgumentParser(description="The window object's interface, written down and checked.")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--write", nargs="?", const="", metavar="ROOT")
    g.add_argument("--check", nargs="?", const="", metavar="ROOT")
    a = ap.parse_args()
    root = (a.write if a.write is not None else a.check) or os.environ.get("S4E_SCRIP", "")
    try:
        if not root or not os.path.isdir(root):
            raise Refuse("no SCRIP root (give one, or set S4E_SCRIP)")
        root = os.path.abspath(root)
        table = os.path.join(root, TABLE)
        rows, problems = measure(root)
        counts = "exports=%d imports=%d offers=%d forms=%d libraries=%d" % tuple(sum(1 for r in rows if r[0] == k) for k in ("export", "import", "offer", "form", "library"))
        if a.write is not None:
            if problems:
                for p in problems:
                    print("XWIN-IFACE PROBLEM %s" % p)
                print("XWIN-IFACE FAIL not written: %d problem(s)" % len(problems))
                return 1
            with open(table, "w") as f:
                f.write(fmt(rows))
            print("XWIN-IFACE WROTE %s %s" % (table, counts))
            return 0
        if not os.path.isfile(table):
            raise Refuse("no table %s" % table)
        want = {}
        for line in open(table):
            if line.startswith("#") or not line.strip():
                continue
            f = line.rstrip("\n").split("\t")
            want[(f[0], f[1])] = f
        got = {(r[0], r[1]): r for r in rows}
        for k in sorted(set(got) - set(want)):
            problems.append("%s %s is in the object, not in the table" % k)
        for k in sorted(set(want) - set(got)):
            problems.append("%s %s is in the table, not in the object" % k)
        for k in sorted(set(want) & set(got)):
            if want[k][2] != got[k][2]:
                problems.append("%s %s changed: table %r, source %r" % (k[0], k[1], want[k][2][:90], got[k][2][:90]))
        for p in problems:
            print("XWIN-IFACE RED %s" % p)
        if problems:
            print("XWIN_IFACE_BOARD %s %s CHECK FAIL (%d)" % (os.path.abspath(root), counts, len(problems)))
            return 1
        print("XWIN_IFACE_BOARD %s %s CHECK OK" % (os.path.abspath(root), counts))
        return 0
    except Refuse as e:
        print("REFUSE(2): %s" % e)
        return 2


if __name__ == "__main__":
    sys.exit(main())
