#!/usr/bin/env python3
"""WHICH DESCRIPTOR KINDS CARRY A HEAP PAYLOAD -- ONE FACT, FIVE SPELLINGS IN ONE FILE, GRADED AGAINST ITS AUTHORITY.

THE ASK THIS ANSWERS, verbatim from the cfo (CFO-141, 2026-09-20, to the cto): "Build it as A DECLARED SUBSET
instead: the stack recognizer's kind set must be a subset of the heap visitor's, every kind in the heap visitor
must be either PRESENT in the stack recognizer or NAMED IN A DECLARED EXCLUSION LIST WITH ITS REASON, and an
unexplained divergence refuses.  That gets you one authority per fact without forcing false symmetry, and it makes
the DT_SNUL exclusion a written, reviewable fact instead of an absence the next reader reads as an oversight --
which is exactly how this one was born."

⛔ AND THE READING IS WIDER THAN THE ASK WAS.  hq_snobol4 found the divergence and described TWO copies; the cfo
added a third (gc_sniff_would_take) and said the same two kinds were missing from it.  Measured here rather than
counted from the telegrams: the fact is spelled FIVE times and the divergences are of four different widths --
gc_sniff_would_take is short by SIX kinds, not two, and gc_type_says_ref by five.  Those two are the INSTRUMENT
halves that the maps reporter's own divergence census is computed from, so a kind missing there does not lose a
value; it makes the census that would have found the loss read agreement.  That is the same class as an rc-shaped
arm over a silent wrong answer: an instrument reporting success while it is not looking.

WHY A DECLARATION AND NOT A DEMAND FOR EQUAL SETS.  The cfo's ruling of the same day (DT_X alone, not DT_SNUL)
turns on the roles being different: gc_visit_one is HANDED a descriptor and reads its type, while gc_cell_visit
GUESSES whether a word pair on the emitted stack is a descriptor at all.  Admitting the zero tag to a speculative
recognizer makes any zero word pair whose second word resolves into the arena look like a cell, on a stack where
zero is the commonest byte -- and rt_gc_visit_descr then REGISTERS THAT SLOT FOR FORWARDING, so the collector
would not merely mark something spurious, it would later REWRITE a word it guessed about.  A gate demanding equal
sets would force exactly that defect and then enforce it.  So: a subset, plus a written reason for every kind the
authority has and a copy does not.

⛔ AN EXCLUSION IS NOT A PARKING SPACE.  A kind recorded UNDER-CURE must name an owner and a row, and the day the
cure lands the entry is STALE and this instrument goes red until it is removed -- so the bookkeeping cannot be
skipped in either direction.
"""
import re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
GC_HEAP = os.path.join(os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP"), "src", "runtime", "rt", "gc_heap.c")
RTX_ALLOC = os.path.join(os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP"), "src", "runtime", "rtx", "rtx_alloc.s")
ASM_SPELLING = "rt_gc_mark_run"
ASM_ROLE = ("the ASM MARK RUN's class table (.Lmk_class in rtx_alloc.s) -- its push filter and its dispatch, used in place "
            "of gc_tag_bears_ptr and gc_visit_one's switch for every entry the run drains; it has no exclusions, so it "
            "must equal the authority")
KIND_RX = re.compile(r"\bDT_[A-Z0-9_]+\b")
CALL_RX = re.compile(r"\b(gc_[a-z0-9_]+)\s*\(")
AUTHORITY = "gc_visit_one"

ROLES = {
    "gc_visit_one": "THE AUTHORITY -- the heap visitor, handed a descriptor that IS one, reads its type field",
    "gc_cell_visit": "the EMITTED-STACK cell recognizer -- guesses whether a word pair is a descriptor at all",
    "gc_tag_bears_ptr": "the PRECEDING-TAG test in gc_walk_words and gc_walk_dump -- classifies a heap word as cell or raw",
    "gc_sniff_would_take": "an INSTRUMENT half -- the maps reporter's model of what the old sniff would have taken",
    "gc_type_says_ref": "an INSTRUMENT half -- the maps reporter's model of what a type says, the other side of its divergence count",
}

DECLARED = {
    ("gc_cell_visit", "DT_SNUL"): ("EXCLUDED", "cfo CFO-141: a speculative recognizer must not admit the zero tag. "
                                   "DT_SNUL is 0x00 and bulk memset mints null strings for free, so admitting it "
                                   "makes any zero word pair whose second word resolves into the arena look like a "
                                   "cell and get REGISTERED FOR FORWARDING. A DT_SNUL that owns heap bytes is a "
                                   "contradiction in terms: if adding it ever changed an outcome, the defect is one "
                                   "level up in whatever minted that descriptor."),
    ("gc_sniff_would_take", "DT_SNUL"): ("EXCLUDED", "same reason as gc_cell_visit's: this function MODELS the "
                                         "speculative recognizer, so it must diverge from the authority exactly "
                                         "where the recognizer does or the census stops describing it."),
    ("gc_type_says_ref", "DT_SNUL"): ("EXCLUDED", "same reason, other side of the same census."),
}


def bodies(text):
    """{function name: body text} for every `static ... name(...) { ... }` in the file, braces balanced"""
    out = {}
    for m in re.finditer(r"^static\s[^\n(]*?\b([a-z_0-9]+)\s*\([^;{]*\)\s*\{", text, re.M):
        i, depth = m.end() - 1, 0
        for j in range(i, len(text)):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    out[m.group(1)] = text[i:j + 1]
                    break
    return out


def kinds_of(name, bods, depth=2):
    """the DT_* kinds a function tests, expanding same-file helpers it calls; returns (kinds, helpers expanded)"""
    body = bods.get(name)
    if body is None:
        return None, None
    ks, helpers = set(KIND_RX.findall(body)), set()
    if depth:
        for callee in set(CALL_RX.findall(body)) - {name}:
            if callee in bods and callee not in ROLES:
                sub, subh = kinds_of(callee, bods, depth - 1)
                if sub:
                    ks |= sub
                    helpers.add(callee)
                    helpers |= subh or set()
    return ks, helpers


def asm_kinds(text):
    """the DT_* kinds the asm class table gives a nonzero class: every `.org .Lmk_class + DT_X` followed by its
    `.byte`, from the label to the table's `.org .Lmk_class + 256`; None when the table is not there"""
    a = text.find(".Lmk_class:")
    b = text.find(".org .Lmk_class + 256", a)
    if a < 0 or b < 0:
        return None
    ks, cur = set(), None
    for ln in text[a:b].splitlines():
        ln = ln.strip()
        m = re.match(r"\.org \.Lmk_class \+ (DT_[A-Z0-9_]+)$", ln)
        if m:
            cur = m.group(1)
        elif ln.startswith(".byte ") and cur:
            if ln.split()[1] not in ("0", "MK_NONE"):
                ks.add(cur)
            cur = None
    return ks


def report(path=GC_HEAP, out=print, asm_path=RTX_ALLOC):
    """rc 0 clean, 1 an undeclared or stale divergence (named), 2 refused"""
    if not os.path.exists(path):
        out(f"KINDSETS REFUSED(2): {path} is missing -- nothing to grade")
        return 2
    asm = asm_kinds(open(asm_path, encoding="utf-8", errors="replace").read()) if os.path.exists(asm_path) else None
    if asm is None:
        out(f"KINDSETS REFUSED(2): the class table .Lmk_class of {ASM_SPELLING} is not in {asm_path} -- a moved table "
            "reads as agreement, which is the failure this instrument exists to catch")
        return 2
    bods = bodies(open(path, encoding="utf-8", errors="replace").read())
    missing = [f for f in ROLES if f not in bods]
    if missing:
        out(f"KINDSETS REFUSED(2): {', '.join(sorted(missing))} not found in {os.path.basename(path)} -- a renamed "
            "spelling reads as agreement, which is the failure this instrument exists to catch")
        return 2
    auth, auth_h = kinds_of(AUTHORITY, bods)
    out(f"KINDSETS AUTHORITY {AUTHORITY} kinds={len(auth)} {' '.join(sorted(auth))}"
        + (f" (expanded: {' '.join(sorted(auth_h))})" if auth_h else ""))
    bad = 0
    for fn in sorted(ROLES):
        if fn == AUTHORITY:
            continue
        ks, hs = kinds_of(fn, bods)
        out(f"KINDSETS SPELLING {fn} kinds={len(ks)} role={ROLES[fn]}"
            + (f" (expanded: {' '.join(sorted(hs))})" if hs else ""))
        for k in sorted(auth - ks):
            state, why = DECLARED.get((fn, k), (None, None))
            if state is None:
                bad += 1
                out(f"KINDSETS UNDECLARED {fn} lacks {k} -- the authority {AUTHORITY} has it and no reason is on "
                    "the record. An absence the next reader takes for an oversight is how this class was born.")
            else:
                out(f"KINDSETS DECLARED {state} {fn} lacks {k}: {why}")
        for k in sorted(ks - auth):
            bad += 1
            out(f"KINDSETS NOT-A-SUBSET {fn} takes {k} and the authority {AUTHORITY} does not -- a copy that goes "
                "BEYOND its authority visits something the heap visitor cannot follow")
        for k in sorted(ks):
            if (fn, k) in DECLARED:
                bad += 1
                state = DECLARED[(fn, k)][0]
                out(f"KINDSETS STALE {fn} HAS {k} and it is still declared {state} -- the cure landed and the "
                    "declaration did not move; remove the entry in the landing that earns it")
    out(f"KINDSETS SPELLING {ASM_SPELLING} kinds={len(asm)} role={ASM_ROLE}")
    for k in sorted(auth - asm):
        bad += 1
        out(f"KINDSETS UNDECLARED {ASM_SPELLING} lacks {k} -- the authority {AUTHORITY} has it and the asm mark run "
            "drops every such descriptor at its push, so the block it points at is swept while the heap visitor would mark it")
    for k in sorted(asm - auth):
        bad += 1
        out(f"KINDSETS NOT-A-SUBSET {ASM_SPELLING} takes {k} and the authority {AUTHORITY} does not -- a copy that goes "
            "BEYOND its authority visits something the heap visitor cannot follow")
    out(f"KINDSETS NOT IN THIS POPULATION AND SAID SO: gc_tag_known answers a DIFFERENT question (is this byte a "
        f"plausible tag at all, including DT_I, DT_R and the DT_P..DT_MAP block) and is not a payload test; "
        f"rt_gc_visit_descr dispatches on {AUTHORITY}'s own switch and is not a second spelling.")
    out(f"KINDSETS file={os.path.basename(path)} authority={AUTHORITY} spellings={len(ROLES) + 1} undeclared_or_stale={bad}")
    return 1 if bad else 0


def selftest():
    """the extraction and the refusals, against hand-built inputs"""
    ok = [0, 0]

    def arm(name, cond):
        ok[1] += 1
        ok[0] += 1 if cond else 0
        print(f"  {'ok  ' if cond else 'FAIL'} {name}")

    src = ("static int gc_helper(const DESCR_t *d) { return d->v == DT_DATA; }\n"
           "static void gc_visit_one(DESCR_t *d) { switch (d->v) { case DT_S: case DT_X: return; } }\n"
           "static int gc_cell_visit(DESCR_t *d) { if (d->v == DT_S) return 1; return gc_helper(d); }\n")
    b = bodies(src)
    arm("bodies finds every static function", set(b) == {"gc_helper", "gc_visit_one", "gc_cell_visit"})
    arm("kinds_of reads the authority's switch", kinds_of("gc_visit_one", b)[0] == {"DT_S", "DT_X"})
    arm("kinds_of expands a same-file helper rather than losing its kinds",
        kinds_of("gc_cell_visit", b)[0] == {"DT_S", "DT_DATA"})
    arm("kinds_of names the helper it expanded", kinds_of("gc_cell_visit", b)[1] == {"gc_helper"})
    arm("kinds_of refuses a name that is not there", kinds_of("nosuch", b)[0] is None)
    arm("report REFUSES a missing file", report("/nonexistent/gc_heap.c", out=lambda *_: None) == 2)
    tab = (".Lmk_class:\n.org .Lmk_class + DT_SNUL\n.byte MK_PLAIN_I\n.org .Lmk_class + DT_P\n.byte 0\n"
           ".org .Lmk_class + DT_X\n.byte MK_PLAIN_I\n.org .Lmk_class + 256\n")
    arm("asm_kinds reads the class table and skips a zero class", asm_kinds(tab) == {"DT_SNUL", "DT_X"})
    arm("asm_kinds refuses a table that is not there", asm_kinds("rt_gc_mark_run:\n    ret\n") is None)
    tmp = os.path.join(os.environ.get("TMPDIR", "/tmp"), "kindsets_selftest.c")
    open(tmp, "w", encoding="utf-8").write(src)
    arm("report REFUSES when a spelling is missing from the file", report(tmp, out=lambda *_: None) == 2)
    arm("report REFUSES when the asm class table is missing", report(GC_HEAP, out=lambda *_: None, asm_path=tmp) == 2)
    os.unlink(tmp)
    print(f"SELFTEST {ok[0]}/{ok[1]} arms green")
    return 0 if ok[0] == ok[1] else 1


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv[1:] else report(*(sys.argv[1:2] or [GC_HEAP])))
