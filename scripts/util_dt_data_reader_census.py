#!/usr/bin/env python3
"""DT_DATA READER CENSUS -- every site that tests the DT_DATA tag and then dereferences the union.

⛔ THE DISEASE THIS COUNTS (cfo 2026-09-18, CEO-887/888).  DT_DATA carried two unrelated pointed-at shapes
under one tag: the .u arm is a DATINST_t (a record instance) and the .ptr arm is a raw DESCR_t element vector
(an Icon list's frame_elems backing store).  Both were minted with slen 0, so NOTHING IN THE DESCRIPTOR SAID
WHICH, every reader guessed from context, and the collector had to strcmp an owner's field name to tell them
apart.  A reader that guessed wrong read a DATBLK_t* out of the first element of a descriptor array -- a SILENT
WRONG ANSWER, not a crash, which is the worst failure shape we have.

⭐ THE CURE IS DT_N's OWN SCHEME: slen arbitrates (DATA_INST_SLEN 0, DATA_ELEMS_SLEN 1), pinned by a
_Static_assert in descr.h beside PROCVAL's.  THIS CENSUS IS THE OTHER HALF -- the ceo's condition (2), THE
READERS ARE THE WHOLE JOB.  After the cure a tag-only reader is still a silent wrong answer, so the population
that must read ZERO is: a site that tests DT_DATA and dereferences .u or .ptr with no slen arbitration in the
same expression.

⛔ COMMENTS AND STRING LITERALS ARE STRIPPED FIRST.  descr.h's own assert message names DT_DATA and .u in
prose; a syntactic grep convicts the cure's documentation, which is how a census teaches a seat to delete the
explanation rather than the defect.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP"))
EXT = (".c", ".h", ".cpp", ".hpp", ".cc")
ARB = ("slen", "IS_DATA_INST_fn", "IS_DATA_ELEMS_fn", "DATA_INST_SLEN", "DATA_ELEMS_SLEN", "DATA_ELEMS(")
DEREF = re.compile(r"(?:\.|->)\s*(?:u|ptr)\b")
TAG = re.compile(r"\bDT_DATA\b")


def strip(src):
    src = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    src = re.sub(r"//[^\n]*", "", src)
    src = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', src)
    return src


def census(root):
    hits = []
    for dp, dn, fn in os.walk(os.path.join(root, "src")):
        dn[:] = [d for d in dn if d not in (".git",)]
        for f in sorted(fn):
            if not f.endswith(EXT):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, root)
            try:
                lines = strip(open(p, encoding="utf-8", errors="replace").read()).split("\n")
            except OSError:
                continue
            for i, ln in enumerate(lines, 1):
                if not TAG.search(ln) or not DEREF.search(ln):
                    continue
                if any(a in ln for a in ARB):
                    continue
                hits.append((rel, i, ln.strip()[:160]))
    return hits


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else ROOT
    hits = census(root)
    for rel, i, ln in hits:
        print("  DT_DATA-TAG-ONLY %s:%d %s" % (rel, i, ln))
    print("CENSUS dt-data tag-only readers TOTAL=%d want=0 -- a site that tests the DT_DATA tag and "
          "dereferences the union with no slen arbitration reads a DESCR_t array as a DATINST_t, or the "
          "reverse, and returns a wrong answer instead of crashing" % len(hits))
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
