#!/usr/bin/env python3
"""util_icon_library_drivers.py -- A DRIVER FOR EVERY ICON OR UNICON LIBRARY FILE (the coo 2026-11-11, COO-516; Lon the same morning, in the coo's
window, verbatim: "Somebody better get to grading these new test suites. Make drivers for library ones, and run the others. Let's get these
GRADED."). A library file has no procedure main, so nothing runs it and a suite of libraries grades nothing. For each such file NAME.icn under ROOT
this tool writes NAME_driver.icn beside it: a program that loads the library (link NAME, or import PACKAGE when the file declares a package) and
writes one line for every procedure, record and class the file declares: its kind, its name, image(NAME) and args(NAME) as the running system
answers them. The oracle's run of the driver is the answer; an engine that does not load the library, or loads it wrong (a name missing, a record
taken for a procedure, another arity, another package name), prints other lines. It does not call the library's code: what a procedure does is
the next driver, written by hand, as the Arizona and IPL packages have them.

    python3 util_icon_library_drivers.py ROOT            write the drivers under ROOT; prints one DRIVER line a file and a board line
    python3 util_icon_library_drivers.py ROOT --check    write nothing; rc 1 when a driver is missing or would change

A file is skipped, by name, when it declares procedure main (it is a program), when it declares nothing this tool can name, or when it is itself a
driver (NAME_driver.icn). ROOT is a copy the caller owns, never a collection read in place. Exit 0 written or current, 1 --check found a
difference, 2 could not measure (no ROOT, no .icn under it)."""
import os
import re
import sys

DECL = re.compile(r"^[ \t]*(procedure|record|class)[ \t]+([A-Za-z_][A-Za-z0-9_]*)", re.M)
PACKAGE = re.compile(r"^[ \t]*package[ \t]+([A-Za-z_][A-Za-z0-9_]*)", re.M)
MAIN = re.compile(r"^[ \t]*procedure[ \t]+main[ \t]*\(", re.M)
DEFINE = re.compile(r"^[ \t]*\$define[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+(\S.*?)[ \t]*$", re.M)
INHERIT = re.compile(r"^[ \t]*class[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*((?::[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*)+)\(", re.M)
INHSPLIT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
INCLUDE = re.compile(r'^[ \t]*\$include[ \t]+"([A-Za-z_][A-Za-z0-9_]*)\.icn"', re.M)


def strip_comments(text):
    """The text with every # comment removed (a # inside a string or a cset literal stays), so a commented-out declaration names nothing."""
    out = []
    for line in text.split("\n"):
        i, q, keep = 0, "", len(line)
        while i < len(line):
            c = line[i]
            if q:
                if c == "\\":
                    i += 2
                    continue
                if c == q:
                    q = ""
            elif c in "\"'":
                q = c
            elif c == "#":
                keep = i
                break
            i += 1
        out.append(line[:keep])
    return "\n".join(out)


RESERVED = frozenset("abstract break by case class create critical default do else end every fail global if import initial initially invocable link local method next not of package procedure record repeat return static suspend then thread to until while".split())


def _link_word(name):
    """A link name that is a Unicon reserved word is written as a string, link "package": the bare word is the keyword and the translator reads link list expected (MEASURED 2026-11-17 on unicon 13.3: unidoc/parlett/package.icn; the quoted form translates and answers)."""
    return f'"{name}"' if name in RESERVED or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) else name


CONDITIONAL = re.compile(r"^[ \t]*\$(ifdef|ifndef|if)\b")
ENDIF = re.compile(r"^[ \t]*\$endif\b")


def outside_conditionals(code):
    """CODE with every line between a $ifdef, $ifndef or $if line and its $endif blanked (the nesting counted): what the translator reads when no symbol
    of the preprocessor line is defined for it. A library's standalone test main stands in such a block (MEASURED on unicon_uni lib/json.icn: two
    `procedure main` under $ifdef MAIN and $ifdef SCAN, and unicon 13.3 reads the file as a library: Run-time error 117, missing main procedure)."""
    out, depth = [], 0
    for line in code.split("\n"):
        if CONDITIONAL.match(line):
            depth += 1
            out.append("")
        elif ENDIF.match(line) and depth:
            depth -= 1
            out.append("")
        else:
            out.append(line if depth == 0 else "")
    return "\n".join(out)


def driver_text(name, text, via=None, needs=()):
    """The driver of the library NAME.icn whose source is TEXT, or None with the reason it has none. VIA is None for a file that stands alone, else
    (the name of the library file that $includes NAME.icn, and the package that file declares or None): such a file is a FRAGMENT, a piece of a
    larger library that no translator can load alone (MEASURED on unicon_uni lib: unicon's icont cannot resolve `link checkbox`, the class
    CheckBox inheriting Button from the file that includes it), so its driver loads the file that includes it."""
    code = strip_comments(text)
    if MAIN.search(outside_conditionals(code)):
        return None, "a program (procedure main)"
    seen, decls = set(), []
    for kind, ident in DECL.findall(code):
        if ident not in seen and ident != "main":
            seen.add(ident)
            decls.append((kind, ident))
    if not decls:
        defs, seen_d = [], set()
        for ident, _value in DEFINE.findall(outside_conditionals(code)):
            if ident not in seen_d:
                seen_d.add(ident)
                defs.append(ident)
        if not defs:
            return None, "declares no procedure, record or class, and defines no name"
        # A DEFINE-ONLY FILE (the cto 2026-11-17: unicon_uni lib/guiconst.icn, lib/threadh.icn): its driver includes the file and writes each name it defines with the image of its
        # value, one line a define, so the oracle's preprocessor and SCRIP's are graded on every constant. A macro with parameters and a define with no value are no name to print.
        body = "".join(f'   write("define {ident} ", image({ident}));\n' for ident in defs)
        return (f"# {name}_driver.icn -- generated by util_icon_library_drivers.py: includes {name}.icn and writes each name it defines and its value; not a file of the collection\n"
                f'$include "{name}.icn"\nprocedure main()\n{body}end\n'), ""
    pkg = PACKAGE.search(code)
    if via:
        head = f"import {via[1]}" if via[1] else f"link {_link_word(via[0])}"
    else:
        head = f"import {pkg.group(1)}" if pkg else f"link {_link_word(name)}"
    # A CLASS THAT INHERITS A CLASS OF ANOTHER LIBRARY FILE (the cto 2026-11-17, row icon-unicon-library-drivers-unicon-uni-udb-xml-parser-uflex; MEASURED on udb/lib: counter_deref
    # is class EventCounterDeref : Listener and unicon's translator reads "can't read spec for class Listener" until listener.icn has been compiled): the driver links the files that
    # hold its superclasses first, each before the file that needs it.
    head = "".join(f"link {_link_word(n)}\n" for n in needs) + head
    body = "".join(f'   write("{kind} {ident} ", image({ident}), " ", image(args({ident})) | "no-args");\n' for kind, ident in decls)
    what = f"{via[0]}.icn, which includes {name}.icn," if via else f"{name}.icn"
    return (f"# {name}_driver.icn -- generated by util_icon_library_drivers.py: loads {what} and writes what it declares; not a file of the collection\n"
            f"{head}\nprocedure main()\n{body}end\n"), ""


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    check = "--check" in argv
    if len(args) != 1 or not os.path.isdir(args[0]):
        print("REFUSE(2) [icon-library-drivers]: usage: util_icon_library_drivers.py ROOT [--check], ROOT a folder")
        return 2
    root = args[0]
    files = sorted(os.path.join(d, n) for d, _, ns in os.walk(root) for n in ns if n.endswith(".icn") and not n.endswith("_driver.icn"))
    if not files:
        print(f"REFUSE(2) [icon-library-drivers]: no .icn under {root}")
        return 2
    texts = {}
    for f in files:
        with open(f, encoding="utf-8", errors="replace") as fh:
            texts[f] = fh.read()
    # THE FRAGMENTS: a file that another library file of ROOT $includes by name is loaded through that file, and through the file that includes that one in turn
    # (a cycle is cut where it closes); a file that has a main is a program and loads nothing.
    includer, codes = {}, {f: strip_comments(texts[f]) for f in files}
    for f in files:
        if MAIN.search(outside_conditionals(codes[f])):
            continue
        for inc in INCLUDE.findall(codes[f]):
            includer.setdefault(inc, os.path.basename(f)[:-4])
    cls_file = {}
    for f in files:
        if not MAIN.search(outside_conditionals(codes[f])):
            for k, ident in DECL.findall(codes[f]):
                if k == "class":
                    cls_file.setdefault(ident, os.path.basename(f)[:-4])
    supers = {os.path.basename(f)[:-4]: [m.group(1) for m in INHERIT.finditer(codes[f])] for f in files}
    supers = {n: [cls_file[s] for ss in L for s in INHSPLIT.findall(ss) if s in cls_file and cls_file[s] != n] for n, L in supers.items()}
    def needs_of(n, depth=0):
        out = []
        if depth > 8: return out
        for s in supers.get(n, []):
            for x in needs_of(s, depth + 1) + [s]:
                if x not in out and x != n: out.append(x)
        return out
    pkg_of = {os.path.basename(f)[:-4]: (PACKAGE.search(codes[f]).group(1) if PACKAGE.search(codes[f]) else None) for f in files}
    wrote = same = skipped = differ = 0
    for f in files:
        name = os.path.basename(f)[:-4]
        text = texts[f]
        top, hops = name, 0
        while top in includer and includer[top] != top and hops < 20:
            top, hops = includer[top], hops + 1
        drv, why = driver_text(name, text, via=(top, pkg_of.get(top)) if top != name else None, needs=needs_of(name))
        rel = os.path.relpath(f, root)
        out = f[:-4] + "_driver.icn"
        if drv is None:
            skipped += 1
            print(f"SKIP\t{rel}\t{why}")
            continue
        old = None
        if os.path.isfile(out):
            with open(out, encoding="utf-8", errors="replace") as fh:
                old = fh.read()
        if old == drv:
            same += 1
            continue
        if check:
            differ += 1
            print(f"DIFFERS\t{rel}\t{'no driver' if old is None else 'the driver would change'}")
            continue
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(drv)
        wrote += 1
        print(f"DRIVER\t{rel}\t{drv.count(chr(10)) - 4} name(s)")
    print(f"ICON_LIBRARY_DRIVERS_BOARD root={root} files={len(files)} written={wrote} current={same} skipped={skipped} differ={differ}")
    return 1 if differ else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
