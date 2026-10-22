#!/usr/bin/env python3
"""audit_result_text_vla_census.py -- THE ESCAPING TEXT IS BUILT IN ITS HEAP HOME AT BIRTH (cto 2026-10-22 17:2x, the
lifetime rule read for a RESULT, ARCH-PROLOG-ACTIVATION-LIFETIME; cfo's row prolog-every-c-builder-...).

A C builder that stages its RESULT text in a stack array sized by the result's length, then copies it to the heap,
holds a second copy of an escaping value on the machine stack: a 4 MB text on the shipped 4 MB stack is a fatal
stack overflow (ERROR 246) where the cap's one catchable road should answer. The rule: compute the length, take the
heap block of exactly that size through the one allocator, fill it in place.

THE CENSUS: every function under SCRIP/src/runtime that declares a char array whose size is a computed expression
(a VLA, `char b[n]` with anything but a literal or a sizeof/macro constant) or takes a char buffer from alloca, and
passes that buffer by name to a heap sink in the same function: plc_text_out(_n), plc_make_atom_cell(_n), pl_mk_atom,
pl_mk_atom_dup, pl_mk_string_dup, rt_heap_strdup_c, prolog_atom_intern(_n). A lexical census: a function is the span from a
column-0 line ending in `{` (or a PL_CX_LEAF_HEAD line) to the next column-0 `}` (or PL_CX_LEAF_TAIL); a sink use
is a statement naming the sink and the buffer on one line, which the 200-column layout keeps together.

    python3 audit_result_text_vla_census.py            # one line per site, then the count
    python3 audit_result_text_vla_census.py --count    # the count alone
EXIT 0 when the count is 0, 1 when sites remain, 2 when it cannot read the tree.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "SCRIP", "src", "runtime"))
SINKS = ("plc_text_out_n", "plc_text_out", "plc_make_atom_cell_n", "plc_make_atom_cell", "pl_mk_atom_dup", "pl_mk_string_dup", "pl_mk_atom", "rt_heap_strdup_c",
         "prolog_atom_intern_n", "prolog_atom_intern")
VLA = re.compile(r"\bchar\s+(\w+)\s*\[([^\]]+)\]")
ALLOCA = re.compile(r"\bchar\s*\*\s*(\w+)\s*=\s*(?:\(\s*char\s*\*\s*\)\s*)?(?:__builtin_)?alloca\s*\(")
CONST = re.compile(r"^\s*(\d+|sizeof\s*\(?[\w .*>-]+\)?|[A-Z][A-Z0-9_]*(\s*[-+*]\s*(\d+|[A-Z][A-Z0-9_]*))*)\s*$")
SINK_RE = re.compile(r"\b(" + "|".join(SINKS) + r")\s*\(")


def functions(lines):
    start = None
    for i, ln in enumerate(lines):
        if start is None:
            if (ln[:1] not in (" ", "\t", "#", "/", "}", "") and ln.rstrip().endswith("{")) or ln.startswith("PL_CX_LEAF_HEAD("):
                start = i
            continue
        if ln.startswith("}") or ln.startswith("PL_CX_LEAF_TAIL"):
            yield start, i
            start = None


def census():
    if not os.path.isdir(ROOT):
        print("REFUSE(2): no SCRIP/src/runtime beside harness at %s" % ROOT, file=sys.stderr)
        sys.exit(2)
    sites = []
    for dp, _, fns in os.walk(ROOT):
        for fn in sorted(fns):
            if not fn.endswith(".c"):
                continue
            path = os.path.join(dp, fn)
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
            for a, b in functions(lines):
                decls = []
                for k in range(a, b + 1):
                    for m in VLA.finditer(lines[k]):
                        if not CONST.match(m.group(2)):
                            decls.append((m.group(1), k, m.group(2).strip()))
                    for m in ALLOCA.finditer(lines[k]):
                        decls.append((m.group(1), k, "alloca"))
                for i, (name, k0, size) in enumerate(decls):
                    k1 = next((d[1] for d in decls[i + 1:] if d[0] == name), b + 1)
                    word = re.compile(r"\b" + re.escape(name) + r"\b")
                    for k in range(k0, k1):
                        sm = SINK_RE.search(lines[k])
                        if sm and word.search(lines[k][sm.start():]):
                            sites.append((os.path.relpath(path, os.path.join(ROOT, "..", "..")), k0 + 1, name, size, sm.group(1)))
                            break
    return sites


def main():
    sites = census()
    if "--count" not in sys.argv[1:]:
        for rel, line, name, size, sink in sites:
            print("%s:%d  %s[%s] -> %s" % (rel, line, name, size, sink))
    print("RESULT-TEXT-VLA sites=%d" % len(sites))
    sys.exit(0 if not sites else 1)


if __name__ == "__main__":
    main()
