#!/usr/bin/env python3
"""util_c_allocator_census.py -- THE CENSUS THAT PROVES ZERO, AND SAYS WHERE EACH SITE WENT (coo, CEO-842/843).

LON'S ACCEPTANCE TEST IS TEXTUAL AND IT IS HIS (2026-09-18, in-chat to ceo, verbatim: "Eradicate ALL usage of
malloc, calloc, free, and realloc.  At the end ensure 0 instances found in the SCRIP source base."), so half of
this tool is a count of four names that must reach 0 over the WHOLE tree -- src/parsers and the checked-in
generated flex/bison output included, because a generated file that is committed is source.

⛔⭐ THE OTHER HALF IS THE ceo's OWN WARNING AND IT IS WHY THIS IS NOT A grep (CEO-843, verbatim): "a census that
only counts the four names would read green on a tree where half the runtime quietly lives outside the
collector."  The rule names THREE destinations and only one of them is right for a given site:

  ROOTED-HEAP   rt_wsb_alloc / rt_ws_alloc_descr / rt_wsb_realloc / rt_pvec_alloc / rt_pvec_realloc / rt_pl_struct_alloc / rt_pm_struct_alloc -- anything the RUNNING PROGRAM can reach, walked like everything
                else, with a root.  If you are unsure, this is the answer (CEO-842).
                rt_wsb_alloc is ON THIS LIST AND IS NOT AN EVASION, which this gate correctly demanded be settled:
                it is rt_gcheap_alloc of kind HB_WSB, the SAME collected heap, and the block is marked, forwarded
                and RELOCATED exactly like HB_WS.  The only thing that differs is that its interior is never
                SCANNED, because the kind's contract is that it holds no pointers.  The proof is not this comment:
                test_gate_gc_the_decidable_test grades HB_WSB with its own witness and reports SENSITIVITY
                DETECTED at skip=2, i.e. the witness fails when the collector is denied a forwarding address.
  ARENA         ct_alloc / ct_zalloc / ct_grow / ct_strdup / ct_strndup / ct_drop -- anything only the COMPILER
                touches, dead before the emitted program runs.
  MMAP          the collector's OWN bookkeeping (page map, mark worklist, live-block array) reserves address
                space directly.  mmap is not one of the four names and a region whose lifetime rule is stated is
                the opposite of handing an object to an allocator the collector cannot see.

⛔ THE ANTI-EVASION CLAUSE IS THE POPULATION THIS TOOL EXISTS FOR: THE ARENA MAY NOT HOLD ANYTHING THE RUNTIME
CAN REACH -- that is the same evasion as malloc or a pin, one name further out, reverted on sight.  So an ARENA
call site under src/runtime/ is counted as a VIOLATION and named, with gc_heap.c's own bookkeeping the one place
MMAP is expected.  A tree can satisfy Lon's grep exactly while failing this, which is the whole point.

⛔ IT COUNTS CALLS, NOT WORDS.  Comments and string literals are stripped, a declaration or prototype is not a
call, and `ct_free` / `rt_wsb_realloc` are not `free` / `realloc` -- the word-boundary does that, and an arm plants
it.  Evasions the rule names by hand are counted too: `#define X malloc`, a typedef'd pointer assigned one of the
four, and a wrapper whose body calls one.

⛔ IT REFUSES RATHER THAN PASSING VACUOUSLY.  No source tree, no readable file, or a tree where the four names
read 0 AND no destination symbol appears anywhere -- which would mean nothing in this compiler allocates at all
-- is rc=2, NOT GREEN.  A zero from a tool that read nothing is not a zero.

rc: 0 forbidden=0 and no arena-in-runtime violation; 1 either remains; 2 could not measure.
Usage: python3 ../harness/scripts/util_c_allocator_census.py [--root DIR] [--ratchet FILE] [--write-baseline FILE]
                                                  [--by-dir] [--sites] [--selftest]
"""
import argparse, functools, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP"))

FORBIDDEN = ("malloc", "calloc", "realloc", "free")
DESTINATIONS = {
    "ROOTED-HEAP": ("rt_wsb_alloc", "rt_ws_alloc_descr", "rt_wsb_realloc", "rt_pvec_alloc", "rt_pvec_realloc", "rt_pl_struct_alloc", "rt_pm_struct_alloc"),
    "ARENA":       ("ct_alloc", "ct_zalloc", "ct_grow", "ct_strdup", "ct_strndup", "ct_drop", "ct_calloc", "ct_realloc"),
    "MMAP":        ("mmap",),
}
SRC_EXT = (".c", ".h", ".cpp", ".hpp", ".cc", ".S", ".s", ".y", ".l")
COUNTS = {}


def strip_comments(src):
    """comments and string literals out -- a name in prose or in a message is not a call site"""
    src = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    src = re.sub(r"//[^\n]*", "", src)
    src = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', src)
    return src


def call_rx(name):
    return re.compile(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"\s*\(")


_DECL_HEAD = re.compile(r"^\s*(?:(?:static|extern|inline|const|unsigned|signed|struct|union|enum|_Noreturn|"
                        r"register|volatile|__attribute__\s*\(\([^)]*\)\))\s+)*[A-Za-z_][A-Za-z0-9_]*\s*\**\s*$")
_HEAD_KEYWORDS = {"return", "else", "do", "while", "if", "case", "goto", "sizeof", "switch", "for"}


def is_declaration(line, upto):
    head = re.split(r"[;{}]", line[:upto])[-1]
    if not head.strip():
        return False
    m = _DECL_HEAD.match(head)
    if not m:
        return False
    last = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", head)
    return bool(last) and last[-1] not in _HEAD_KEYWORDS


def source_files(root):
    fs = []
    sd = os.path.join(root, "src")
    if not os.path.isdir(sd):
        return fs
    for d, _s, names in os.walk(sd):
        for n in sorted(names):
            if n.endswith(SRC_EXT):
                fs.append(os.path.join(d, n))
    return sorted(fs)


_DEFINE_RX = re.compile(r"^[ \t]*#[ \t]*define[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*(?:\([^)]*\))?[ \t]*(.*)$")
_CPP_RX = re.compile(r"^\s*#\s*(?:define|include|if|ifdef|ifndef|elif|else|endif|undef|pragma|error)\b")
_BARE_RX = re.compile(r"(?<![A-Za-z0-9_])(" + "|".join(FORBIDDEN) + r")(?![A-Za-z0-9_])\s*(?!\()")
_WORD_RX = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def resolve_aliases(defines):
    """⛔ THE ALIAS QUESTION IS TRANSITIVE AND THE ONE-LEVEL ANSWER IS WRONG TWICE (CEO-844 clause 1).

    bison writes `#define YYSTACK_ALLOC YYMALLOC` beside `#define YYMALLOC malloc`: a reader who only asks
    whether a define's body IS a forbidden name sees neither the chain nor the 15 calls made through it, and a
    four-name grep sees nothing at all.  And a substring reader gets a FALSE alias out of flex's
    `#define yyrealloc pascal_yyrealloc`, which renames flex's own hook and is not C realloc under any spelling.
    So: parse each define into (name, body), then ask whether the body REACHES one of the four through other
    defines, by whole word.  Returns {(rel, line, name): (forbidden_name, chain)}.
    """
    body_of = {}
    for _rel, _ln, nm, body in defines:
        body_of.setdefault(nm, []).append(body)

    def reach(nm, seen):
        if nm in FORBIDDEN:
            return (nm, [nm])
        if nm in seen or nm not in body_of:
            return None
        seen = seen | {nm}
        for body in body_of[nm]:
            for tok in _WORD_RX.findall(body):
                got = reach(tok, seen)
                if got:
                    return (got[0], [nm] + got[1])
        return None

    found = {}
    for rel, ln, nm, _body in defines:
        if nm in FORBIDDEN:
            continue
        got = reach(nm, frozenset())
        if got:
            found[(rel, ln, nm)] = got
    return found


def scan(files, root):
    """(forbidden, destinations, aliases, alias_calls, prose, bare) -- the four names, where the converted
    sites went, every spelling that reaches them, every CALL through such a spelling, and the two residues a
    textual grep hits that are not call sites at all."""
    forb, dest, defines, prose, bare = [], [], [], {}, []
    rxs = [(n, call_rx(n)) for n in FORBIDDEN]
    drx = [(d, n, call_rx(n)) for d, syms in DESTINATIONS.items() for n in syms]
    word_rx = re.compile(r"(?<![A-Za-z0-9_])(" + "|".join(FORBIDDEN) + r")(?![A-Za-z0-9_])")
    texts = {}
    for f in files:
        try:
            raw = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        rel = os.path.relpath(f, root)
        src = strip_comments(raw)
        texts[rel] = src
        # ⛔ THE PROSE RESIDUE IS MEASURED HERE AND NEVER FOLDED INTO THE COUNT (CEO-844 clause 2).  The
        # generated bison and flex files carry the GPL sentence "This program is free software"; that sentence
        # is not usage.  An instrument that counts it reads a permanent false red, and the cheapest way to
        # clear a false red is to delete a licence header -- so this population is printed APART, with its
        # files, and a reader who sees it knows why Lon's textual grep will not reach 0 on the same day the
        # call sites do.
        n_prose = len(word_rx.findall(raw)) - len(word_rx.findall(src))
        if n_prose > 0:
            prose[rel] = n_prose
        lines = src.split("\n")
        # ⛔ AND THE SAME TEST ONCE PER FILE (the cfo 2026-09-24, row instruments-the-allocator-census-preflight-arm-...):
        # a name absent from the file is absent from each of its lines, so only the names this file contains are tried
        # per line, in their original order, and a file with none of the four names cannot yield a bare reference.
        rxs_here = [(n, rx) for n, rx in rxs if n in src]
        drx_here = [(d, n, rx) for d, n, rx in drx if n in src]
        bare_here = any(n in src for n in FORBIDDEN)
        # ⛔ THE SUBSTRING TEST IS A PRE-FILTER, NOT A CRITERION (COO-80, row
        # instrument-the-nineteen-non-gc-blocking-arms). Every pattern here is call_rx(name), which cannot
        # match a line that does not contain `name` literally, so `name not in line` skips only lines the
        # regex was always going to reject. It is a pure cost cut over the same population: this loop ran
        # each of the forbidden and destination patterns against EVERY line of src/, 2.5 million finditer
        # calls on a --by-dir pass. The census output is byte-identical across the change.
        for i, line in enumerate(lines, 1):
            for name, rx in rxs_here:
                if name not in line:
                    continue
                for m in rx.finditer(line):
                    if is_declaration(line, m.start()):
                        continue
                    forb.append((rel, i, name))
            for d, name, rx in drx_here:
                if name not in line:
                    continue
                for m in rx.finditer(line):
                    if is_declaration(line, m.start()):
                        continue
                    dest.append((rel, i, name, d))
            m = _DEFINE_RX.match(line)
            if m:
                defines.append((rel, i, m.group(1), m.group(2)))
                continue
            if not bare_here:
                continue
            for m in _BARE_RX.finditer(line):
                if is_declaration(line, m.start()):
                    continue
                bare.append((rel, i, m.group(1), line.strip()[:78]))

    aliases = resolve_aliases(defines)
    # every CALL made through a spelling that reaches a forbidden name -- the population a four-name grep and a
    # one-level alias reader BOTH miss, and the one that lets a tree read 0 while still calling malloc.
    alias_calls = []
    if aliases:
        names = sorted({nm for (_r, _l, nm) in aliases})
        arx = [(nm, call_rx(nm)) for nm in names]
        for rel, src in texts.items():
            for i, line in enumerate(src.split("\n"), 1):
                if _CPP_RX.match(line):
                    continue
                for nm, rx in arx:
                    if nm not in line:
                        continue
                    for m in rx.finditer(line):
                        if is_declaration(line, m.start()):
                            continue
                        alias_calls.append((rel, i, nm, aliases_lookup(aliases, nm)))
    return forb, dest, aliases, alias_calls, prose, bare, texts


def aliases_lookup(aliases, nm):
    for (_r, _l, n), (target, _chain) in aliases.items():
        if n == nm:
            return target
    return "?"


def runtime_reachable(rel):
    """the question CEO-842 says to ask: can the emitted program still reach this after the compile ends?
    src/runtime is the directory where the answer is yes by construction."""
    return rel.startswith("src/runtime" + os.sep) or rel.startswith("src/runtime/")


def is_collector_bookkeeping(rel):
    return os.path.basename(rel) in ("gc_heap.c", "gc_heap.h")


SITES_BASELINE = os.path.join(HERE, "c_allocator_sites_baseline.tsv")
RULED_PERMANENT = os.path.join(HERE, "c_allocator_ruled_permanent.tsv")
# The class-3 citation record, overridable ONLY as a test seam (see ruling_resolves).
RECORD_OVERRIDE = None

_GLOBAL_DECL = re.compile(r"^(?:static\s+|extern\s+)?(?:const\s+)?[A-Za-z_][A-Za-z0-9_]*\s+(\**)\s*"
                          r"([A-Za-z_][A-Za-z0-9_]*)\s*(\[|=|;)", re.M)
_ROOTS_FN = re.compile(r"^(?:static\s+)?void\s+([A-Za-z_][A-Za-z0-9_]*_gc_roots)\s*\([^)]*\)\s*\{", re.M)
_INDEXED = re.compile(r"(?<![A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)\s*(?:\[|->)")
_ADDR_OF = re.compile(r"&\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?![\w\[])")


# ⛔⭐ WHO OWNS THE BLOCK (RULES.md line 29 as amended by CEO-850; the hazard named in CEO-850's last clause).
# libc hands ownership out through more doors than the four names, and a block libc owns may not be handed to
# OUR bookkeeping under any of them.  Two shapes, one root cause:
#   ct_drop / ct_grow on a libc-owned pointer -- the arena reads the 32 bytes BEFORE the block looking for its
#     magic header, which is memory it does not own.  ⛔ THAT READ IS NOT SAFE, MEASURED (the cfo, CFO-153, on the
#     parent of a35750d9b): under ASLR the 32 bytes below a libc block can sit in an UNMAPPED gap and the read
#     SEGFAULTS (rc 139); where they are mapped, the magic never matches, the drop returns silently and the buffer
#     LEAKS (8 KB a call on the memstream sites).  The MAGIC guard makes it neither safe nor correct -- this line
#     said "safe, not correct" until that measurement.
#   a collector root over a libc-owned pointer -- the ceo's named hazard: the next getline reallocs it through
#     libc and the root then names memory the collector never moved and libc has freed.
_LIBC_OUT_PARAM = ("getline", "getdelim", "posix_memalign", "asprintf", "vasprintf", "open_memstream", "open_wmemstream")
_LIBC_RETURNS = ("strdup", "strndup", "strdupa", "malloc", "calloc", "realloc", "aligned_alloc",
                 "memalign", "valloc", "reallocarray")
_OURS = {"ct_drop": "the arena's free", "ct_grow": "the arena's realloc", "ct_realloc": "the arena's realloc",
         "rt_gc_visit_raw": "a collector root", "rt_gc_visit_descr": "a collector root",
         "rt_gc_root_range_add": "a collector root", "rt_wsb_realloc": "the collected heap's realloc"}
_LVALUE = (r"[A-Za-z_][A-Za-z0-9_]*(?:\s*\[[^\]]*\]|\s*\.\s*[A-Za-z_][A-Za-z0-9_]*"
           r"|\s*->\s*[A-Za-z_][A-Za-z0-9_]*)*")
_PTR_DECL = re.compile(r"(?:^|[{;])\s*(?:static\s+)?(?:const\s+)?[A-Za-z_][A-Za-z0-9_]*\s*\*\s*"
                       r"([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|;)", re.M)
_STATIC_ARR = re.compile(r"^static\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*\[", re.M)


# ⛔⭐ THE PATTERNS ARE BUILT ONCE, NOT ONCE PER SCOPE (COO-80, 2026-09-19, row
# instrument-the-nineteen-non-gc-blocking-arms). libc_ownership_census interpolated re.escape(sym) and each
# table name into a fresh pattern string inside its per-scope loop, so every one of the ~10,000 declaration
# scopes recompiled about seven regexes: a cProfile run read 71,202 compilations, 14.5s of the census's 24.9s,
# because Python's internal re cache holds 512 entries and this blew through it on every file. That cost put
# test_gate_c_allocators_are_eradicated_and_say_where_they_went.sh (which runs the census three times) at
# 23.7s against the 5s per-arm preflight budget, which is the SLOW arm that kept
# test_gate_preflight_arms_stay_cheap red. ⛔ NOTHING HERE CHANGES WHAT IS MEASURED -- the criterion is frozen
# (MODE line 2) and the output of --by-dir, --sites, --selftest and the plain run is byte-identical across
# this change, which is the only reason a speed edit to a frozen instrument is allowed at all. Two mechanisms:
# the _OURS patterns carry no symbol so they are compiled at import; the two libc tables are memoised per
# (name, symbol) pair, and every loop is guarded by a plain substring test first, because a pattern demanding
# the literal name cannot match a segment the name does not occur in.
_OURS_RX = {ours: re.compile(ours + r"\s*\(\s*(?:\([^()]*\)\s*)?&?\s*(" + _LVALUE + r")\s*\)")
            for ours in _OURS}
_LEADING_IDENT_RX = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


@functools.lru_cache(maxsize=None)
def _libc_outparam_rx(fn, esym):
    return re.compile(fn + r"\s*\(\s*&\s*" + esym + r"(?![A-Za-z0-9_])"
                      r"(?:\s*\[[^\]]*\]|\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*\s*,")


@functools.lru_cache(maxsize=None)
def _libc_returns_rx(fn, esym):
    return re.compile(r"(?<![A-Za-z0-9_])" + esym + r"\s*=\s*(?:\([^)]*\)\s*)?" + fn + r"\s*\(")


# ⛔ THE CANDIDATE PASS (cfo 2026-09-24, row instruments-the-allocator-census-preflight-arm-runs-7-to-14-s-...): the two
# patterns above with the symbol GENERALISED to any identifier, wrapped in a zero-width lookahead so finditer tries every
# position and no overlapping occurrence is skipped. A match inside a scope is a match in its file -- a scope starts at
# its declared name, which follows `*` or whitespace, or at 0 -- so an identifier absent from this set can never be given
# an owner, and its scope need not be built or searched. That was 1146 regex searches and 8044 block walks per pass.
@functools.lru_cache(maxsize=None)
def _libc_returns_any_rx(fns):
    return re.compile(r"(?=(?<![A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:\([^)]*\)\s*)?(?:" + "|".join(fns) + r")\s*\()")


@functools.lru_cache(maxsize=None)
def _libc_outparam_any_rx(fns):
    return re.compile(r"(?=(?:" + "|".join(fns) + r")\s*\(\s*&\s*([A-Za-z_][A-Za-z0-9_]*)(?![A-Za-z0-9_])"
                      r"(?:\s*\[[^\]]*\]|\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*\s*,)")


def _libc_owner_syms(src, out_fns, ret_fns):
    syms = set()
    if ret_fns:
        syms.update(m.group(1) for m in _libc_returns_any_rx(tuple(ret_fns)).finditer(src))
    if out_fns:
        syms.update(m.group(1) for m in _libc_outparam_any_rx(tuple(out_fns)).finditer(src))
    return syms


def _norm_lvalue(e):
    return re.sub(r"\[[^\]]*\]", "[]", re.sub(r"\s+", "", e))


def _enclosing_block(src, p):
    """⛔ THE SCOPE IS THE DECLARATION'S BLOCK, NOT THE FUNCTION, AND THAT IS WHAT MAKES THIS ARM HONEST.
    by_name_dispatch.c declares `ln` twice inside one giant dispatch function -- once from getline() at 7177
    and once from ct_alloc() at 7716.  A function-scoped reader merges them and convicts three CORRECT
    ct_drop()s of the arena-owned one.  Measured: that reader reported 5 sites in that file; this one reports
    the 2 that are real."""
    # ⛔ BRACE-STEPPED, NOT CHARACTER-STEPPED (COO-80, 2026-09-19, row
    # instrument-the-nineteen-non-gc-blocking-arms). Both scans below used to walk one Python character at a
    # time, and the forward one re-evaluated len(src) on every step: cProfile read 22.5 MILLION len() calls
    # over the 10,135 scopes of a --by-dir pass, 2.8s of the census, on a tree whose largest file is a few
    # hundred KB. str.find/str.rfind do the same walk in C and stop only on the braces that can change the
    # depth, so the loops now step once per BRACE rather than once per byte. ⛔ The semantics are unchanged
    # and deliberately so: the backward scan still stops at the first unmatched "{" at or before p (or index
    # 0 when the file has none before it), the forward scan still leaves j ONE PAST the matching "}" (or at
    # len(src) when the block never closes), and the same (start, end) pair comes back. The census output is
    # byte-identical across this change in every mode, which is the only warrant for touching a frozen
    # instrument at all.
    n = len(src)
    d, i = 0, p
    while i > 0:
        k = max(src.rfind("{", 0, i), src.rfind("}", 0, i))
        if k < 0:
            i = 0
            break
        i = k
        if src[k] == "}":
            d += 1
        elif d == 0:
            break
        else:
            d -= 1
    start, d, j = i, 1, i + 1
    while j < n and d:
        b_open = src.find("{", j)
        b_close = src.find("}", j)
        if b_open < 0 and b_close < 0:
            j = n
            break
        if b_open >= 0 and (b_close < 0 or b_open < b_close):
            d += 1
            j = b_open + 1
        else:
            d -= 1
            j = b_close + 1
    return start, (j if j > p else n)


def libc_ownership_census(texts, out=print):
    """Every site where a block libc owns is handed to our allocator or our collector."""
    hits = []
    # ⛔ CHEAP, AND EXACTLY AS BLIND AS BEFORE (row instruments-the-allocator-census-preflight-arm-runs-7-to-14-s-...,
    # the cfo 2026-09-24): every test below asks whether a name occurs inside a scope, and a scope is a slice of its
    # file, so a name absent from the file is absent from every scope in it. A file with no libc owner name or none
    # of our bookkeeping names can yield no hit and is skipped before its scopes are built -- 336 of 386 files today,
    # the whole cost of this arm being over the preflight budget. The name lists keep their order, so the last
    # matching owner still wins and the output is byte-identical in every mode.
    for rel, src in sorted(texts.items()):
        out_fns = [fn for fn in _LIBC_OUT_PARAM if fn in src]
        ret_fns = [fn for fn in _LIBC_RETURNS if fn in src]
        ours_here = [(ours, what) for ours, what in _OURS.items() if ours in src]
        if not (out_fns or ret_fns) or not ours_here:
            continue
        cand = _libc_owner_syms(src, out_fns, ret_fns)
        if not cand:
            continue
        scopes = [(m.group(1), m.start(1), _enclosing_block(src, m.start(1))[1]) for m in _PTR_DECL.finditer(src)
                  if m.group(1) in cand]
        scopes += [(m.group(1), 0, len(src)) for m in _STATIC_ARR.finditer(src) if m.group(1) in cand]
        for sym, a, b in scopes:
            seg = src[a:b]
            owner = None
            esym = re.escape(sym)
            if sym not in seg:
                continue
            for fn in out_fns:
                if fn in seg and _libc_outparam_rx(fn, esym).search(seg):
                    owner = fn
            for fn in ret_fns:
                if fn in seg and _libc_returns_rx(fn, esym).search(seg):
                    owner = fn
            if not owner:
                continue
            for ours, what in ours_here:
                # ⛔ THE CAST IS NOT OPTIONAL TO HANDLE: every root in core.c is written
                # rt_gc_visit_raw((const char **)&X), so a reader that only matches a bare &X misses the
                # exact hazard it was built for.  A planted arm caught this before it shipped.
                if ours not in seg:
                    continue
                for mm in _OURS_RX[ours].finditer(seg):
                    got = _norm_lvalue(mm.group(1))
                    if _LEADING_IDENT_RX.match(got).group(0) == sym:
                        hits.append((rel, src.count("\n", 0, a + mm.start()) + 1, ours, got, owner, what))
    uniq = sorted({(h[0], h[1]): h for h in hits}.values())
    out(f"CENSUS c-allocators LIBC-OWNED-MISUSE={len(uniq)} want=0 -- a block LIBC owns handed to OUR "
        f"bookkeeping (RULES.md line 29 as amended, CEO-850: the test is WHO OWNS THE BLOCK, never what the "
        f"function is called). ct_drop on a libc pointer reads the 32 bytes BEFORE the block hunting a magic "
        f"header it does not own: under ASLR that read can land in an UNMAPPED gap and SEGFAULT (measured, the cfo "
        f"CFO-153), and where it is mapped the magic never matches and the buffer LEAKS -- the MAGIC guard makes "
        f"it neither safe nor correct. A collector root over one is the same error "
        f"wearing the opposite coat: the next getline reallocs it through libc and the root names memory the "
        f"collector never moved")
    for rel, ln, ours, expr, owner, what in uniq:
        out(f"  ⛔ LIBC-OWNED-MISUSE {rel}:{ln} {ours}({expr}) is {what}, but {expr} is owned by {owner}()")
    out(f"  ⛔ LIMIT: block-scoped and syntactic. It reads the declaration's OWN block, not the function -- "
        f"a function-scoped reader merges by_name_dispatch.c's two `ln` variables and convicts the "
        f"arena-owned one -- but it cannot follow a pointer through a helper or across a struct assignment.")
    return uniq


# ⛔⭐ THE LIBC DOORS (row instruments-the-c-allocator-census-knows-open-memstream-as-libc-owned-..., the coo 2026-09-23, the
# cfo's CFO-153 item 4, ceo CEO-1208).  Lon's four names are not the only way a block reaches libc's heap: CEO-850 named the
# other doors for the OWNERSHIP test above, but only a door whose block is later handed to OUR bookkeeping was ever counted --
# a bare strdup kept in a static table (by_name_dispatch.c, 6a6983d9e) was in no count at all, and open_memstream was not even
# a door, so four ct_drop()s on its buffers read LIBC-OWNED-MISUSE=0 while each leaked 8 KB a call and segfaulted under ASLR.
# This is the twelve-name census the ownership arm's selftest promised, grown to thirteen: every CALL of a libc HEAP door
# under src/ other than the four names FORBIDDEN already counts, named and ratcheted toward zero (Lon 2026-09-23 14:5x: "We,
# of course, are using 100% GC heap and private arenas now").  strdupa is NOT a heap door -- alloca memory, freed with its
# frame -- so it is not counted here; it stays in the ownership test, where a stack block handed to ct_drop is still the
# wrong owner.  Comments and string literals are already blanked (strip_comments) and a prototype is not a call.
_LIBC_HEAP_DOORS = ("strdup", "strndup", "aligned_alloc", "memalign", "valloc", "reallocarray", "getline", "getdelim",
                    "posix_memalign", "asprintf", "vasprintf", "open_memstream", "open_wmemstream")
_DOOR_RX = re.compile(r"(?<![A-Za-z0-9_])(" + "|".join(_LIBC_HEAP_DOORS) + r")\s*\(")


def libc_doors_census(texts, out=print):
    """Every call of a libc HEAP door other than the four forbidden names, one row each."""
    hits = []
    for rel, src in sorted(texts.items()):
        doors_here = [d for d in _LIBC_HEAP_DOORS if d in src]
        if not doors_here:
            continue
        for ln, line in enumerate(src.split("\n"), 1):
            if not any(d in line for d in doors_here):
                continue
            for m in _DOOR_RX.finditer(line):
                if not is_declaration(line, m.start()):
                    hits.append((rel, ln, m.group(1)))
    out(f"CENSUS c-allocators LIBC-DOORS={len(hits)} want=0 -- a CALL of a libc HEAP door other than the four names "
        f"({', '.join(_LIBC_HEAP_DOORS)}): a block libc's heap owns, outside the collector and every arena; ratcheted and "
        f"named, driven to zero (strdupa is stack, not a door)")
    for rel, ln, fn in hits:
        out(f"  ⛔ LIBC-DOOR {rel}:{ln} {fn}()")
    return hits


def container_census(texts, out=print):
    """⛔⭐ MARK THE CONTAINER, NOT ONLY WHAT IT POINTS AT (CEO-846; the cfo's CFO-96/97 find).

    A root walk that visits a container's CONTENTS but never marks the CONTAINER READS AS ROOTED TO EVERY
    CENSUS EVER WRITTEN -- including this one's destination column, which only asks where an allocation went.
    g_name_save was reclaimed under a live call while its walk existed and was being called.  So this asks a
    different question of each `*_gc_roots` function: which globals does it index or dereference, and does it
    ever pass the ADDRESS OF THE CONTAINER ITSELF to a visitor?

    ⛔ THE DECLARATION DECIDES WHETHER A MISS IS LIVE OR LATENT, and getting this backwards is how the arm
    becomes noise: `static NV_t *_var_buckets[VAR_BUCKETS]` is an ARRAY of pointers in static storage -- there
    is no container block to mark, and marking each slot with `&_var_buckets[b]` is correct and sufficient.
    `static DESCR_t *g_pas_heap` is a POINTER AT A BLOCK: visiting `&g_pas_heap[n]` marks the contents and
    leaves the block itself unmarked, which is the g_name_save shape exactly.  A fixed array is reported as
    LATENT rather than clean, because it becomes the live defect the moment its storage moves to the collected
    heap -- which is what this whole sweep is doing.

    ⛔ AND THE HONEST HALF: this is a SYNTACTIC read of the root walks, not a proof.  It cannot see a container
    marked through a helper function, an alias, or a walk not named `*_gc_roots`, and it says so rather than
    certifying the tree.
    """
    gdecl = {}
    for rel, src in texts.items():
        for m in _GLOBAL_DECL.finditer(src):
            star, sym, tail = m.group(1), m.group(2), m.group(3)
            kind = "array" if tail == "[" else ("pointer" if star else "scalar")
            gdecl.setdefault(sym, set()).add(kind)
    live, latent, walks = [], [], 0
    for rel, src in sorted(texts.items()):
        for fm in _ROOTS_FN.finditer(src):
            walks += 1
            name = fm.group(1)
            i, depth = fm.end(), 1
            while i < len(src) and depth:
                depth += 1 if src[i] == "{" else (-1 if src[i] == "}" else 0)
                i += 1
            body = src[fm.end():i]
            indexed = {x for x in _INDEXED.findall(body) if x in gdecl}
            marked = set(_ADDR_OF.findall(body))
            for sym in sorted(indexed - marked):
                kinds = gdecl[sym]
                row = (rel, name, sym, "/".join(sorted(kinds)))
                (live if ("pointer" in kinds and "array" not in kinds) else latent).append(row)
    out(f"CENSUS c-allocators CONTAINER-UNMARKED LIVE={len(live)} want=0 LATENT={len(latent)} over {walks} root "
        f"walk(s) -- MARK THE CONTAINER, NOT ONLY WHAT IT POINTS AT (CEO-846, CFO-96/97). A walk that visits a "
        f"container's contents and never the container reads as ROOTED to every census ever written, this one's "
        f"destination column included: g_name_save was reclaimed under a live call while its walk existed and "
        f"was called")
    for rel, fn, sym, kind in live:
        out(f"  ⛔ CONTAINER-UNMARKED-LIVE {rel} {fn}() indexes {sym} ({kind} at a heap block) and never marks the "
            f"block -- visiting {sym}[i] marks the CONTENTS and leaves the container collectable")
    for rel, fn, sym, kind in latent[:10]:
        out(f"  CONTAINER-UNMARKED-LATENT {rel} {fn}() indexes {sym} ({kind}) -- static storage today, so there "
            f"is no block to mark and marking each slot is sufficient; it becomes the live defect the moment "
            f"that storage moves to the collected heap")
    out(f"  ⛔ LIMIT, STATED RATHER THAN CERTIFIED: this is a SYNTACTIC read of functions named *_gc_roots. It "
        f"cannot see a container marked through a helper, through an alias, or by a walk under another name, "
        f"and a LIVE=0 from it is not a proof that every container in the tree is marked.")
    return live, latent


def per_file(forb, dest):
    """{relpath: {forbidden, rooted_heap, arena, mmap}} -- the shape the provenance split is keyed on."""
    agg = {}
    def cell(rel):
        return agg.setdefault(rel, {"forbidden": 0, "rooted_heap": 0, "arena": 0, "mmap": 0})
    for rel, _l, _n in forb:
        cell(rel)["forbidden"] += 1
    for rel, _l, _n, d in dest:
        cell(rel)[{"ROOTED-HEAP": "rooted_heap", "ARENA": "arena", "MMAP": "mmap"}[d]] += 1
    return agg


def read_sites_baseline(path):
    if not os.path.exists(path):
        return None
    base = {}
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) >= 5:
            base[f[0]] = {"forbidden": int(f[1]), "rooted_heap": int(f[2]), "arena": int(f[3]), "mmap": int(f[4])}
    return base


def read_ruled_permanent(path):
    """CLASS 3, RULED-PERMANENT (ceo CEO-856, the cfo's shape). Rows are file<TAB>symbol<TAB>sites<TAB>ruling<TAB>reason.
    ⛔ A MISSING FILE IS AN EMPTY REGISTRY, NOT A REFUSAL -- no site is ruled permanent until one is written down, and
    that is the correct resting state. An unreadable or malformed row is dropped LOUDLY by the caller, never silently."""
    rows, bad = [], []
    if not os.path.exists(path):
        return rows, bad
    for ln, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.startswith("#") or not line.strip():
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) < 5 or not f[2].strip().isdigit():
            bad.append((ln, line.rstrip("\n")[:120])); continue
        rows.append({"file": f[0].strip(), "symbol": f[1].strip(), "sites": int(f[2]),
                     "ruling": f[3].strip(), "reason": f[4].strip()})
    return rows, bad


def ruling_resolves(ruling, root=None):
    """⛔⭐ THE CITATION IS A HARD ARM, NOT A COURTESY FIELD (ceo CEO-856, quoting the cfo's own sentence: the citation
    is the only thing standing between a third class and a hiding place). A class-3 entry whose cited ruling does not
    resolve is a CLASS 1 EVASION IN DISGUISE and REDS.

    ⛔ THREE ANSWERS, NOT TWO: True it resolves, False it does not, None THE RECORD COULD NOT BE READ -- an unmerged or
    absent .github cannot resolve a ruling landed this morning, and convicting an honest entry because the reader is
    behind is the same fault as passing a dishonest one. None is carried to the caller as rc=2, could-not-measure.

    ⛔⭐ THE SEAM (ceo CEO-560): every guard ships a sanctioned way to be TRIPPED that does not require doing the
    forbidden thing. RECORD_OVERRIDE names the record explicitly, so the rc=2 branch can be proved by pointing the
    reader at a path that is not there -- without deleting anybody's .github. Without a seam that branch would be
    unreachable from a test and would sit here unexecuted, which is the precise shape this census exists against."""
    if RECORD_OVERRIDE is not None:
        record = RECORD_OVERRIDE
        if not os.path.exists(record):
            return None, record
    else:
        cands = []
        if root:
            cands.append(os.path.join(root, ".github", "GOAL-CEO.md"))
        if os.environ.get("S4E_HOME"):
            cands.append(os.path.join(os.environ["S4E_HOME"], ".github", "GOAL-CEO.md"))
        cands.append(os.path.join(os.path.dirname(os.path.dirname(HERE)), ".github", "GOAL-CEO.md"))
        record = next((c for c in cands if os.path.exists(c)), cands[-1])
        if not os.path.exists(record):
            return None, record
    try:
        st = os.stat(record)
        text = _read_record(record, st.st_mtime_ns, st.st_size)
    except Exception:
        return None, record
    return (ruling in text), record


@functools.lru_cache(maxsize=8)
def _read_record(path, mtime_ns, size):
    """The record is read ONCE per process for a given (path, mtime, size): the selftest resolves 35 rulings against
    a 2.8 MB GOAL-CEO.md, and decoding it 35 times was 0.6 s of the preflight arm's budget (cfo 2026-09-24). A record
    that changes on disk changes its key, so no stale text is ever graded."""
    return open(path, encoding="utf-8", errors="replace").read()


def split_ruled_permanent(viol, rows):
    """Partition the ARENA-IN-RUNTIME sites into class 3 and the rest, keyed on (file, allocator symbol) and CAPPED at
    the row's site count. ⛔ THE CAP IS WHAT STOPS A ROW BECOMING A BLANKET AMNESTY FOR A FILE: an extra site beyond
    what the ruling licensed falls straight back into class 1/2 and is graded exactly as before."""
    budget = {}
    for r in rows:
        budget[(r["file"], r["symbol"])] = budget.get((r["file"], r["symbol"]), 0) + r["sites"]
    perm, rest = [], []
    for rel, ln, sym in viol:
        k = (rel, sym)
        if budget.get(k, 0) > 0:
            budget[k] -= 1
            perm.append((rel, ln, sym))
        else:
            rest.append((rel, ln, sym))
    return perm, rest


def provenance(now, base):
    """⛔⭐ THE SPLIT CEO-846 ORDERED, AND IT TURNS ENTIRELY ON WHAT A SITE WAS BEFORE.

    The clause `the arena may not hold anything the runtime can reach` was written as one rule over two
    different acts, and only one of them is the evasion:

      CLASS 1 -- a site that was on the COLLECTED HEAP and is now in the ARENA.  That is moving an object out
        of the collector's sight to avoid rooting it: the cfo's f62a33aed shape under a new name.  HARD RED,
        named, never ratcheted, never transitional.
      CLASS 2 -- a site that was a libc `malloc` and is now in the ARENA.  Not a cure and not an evasion: the
        lifetime is identical to the malloc it replaced (never moves, never freed), so it is exactly as safe
        as what it replaced AND it removes a forbidden call.  DEBT.  Counted, ratcheted to zero as each
        holder is rooted, may only FALL.

    ⛔ THE RESOLUTION OF THIS INSTRUMENT IS THE FILE, NOT THE SITE, and saying so is the honest half: line
    numbers do not survive a sweep that rewrites 79 files, so the discriminator is a CONSERVATION ARGUMENT per
    file.  If a file's rooted-heap count FELL while its arena count ROSE, that many sites moved off the
    collected heap into the arena and it is class 1 -- whatever the intervening edits were.  The rest of the
    arena growth is attributed to the forbidden calls the same file lost, which is class 2.  A file that both
    roots a new holder and arenas an old malloc in one landing is reported at its NET, and a class-1 site
    hidden under a same-file class-2 credit is the one shape this cannot see; it is named in the output so
    nobody reads the number as site-exact.
    """
    ev, debt, unknown = [], [], []
    for rel, cur in sorted(now.items()):
        if not runtime_reachable(rel) or cur["arena"] == 0:
            continue
        was = base.get(rel)
        if was is None:
            unknown.append((rel, cur["arena"]))
            continue
        d_arena = cur["arena"] - was["arena"]
        d_rooted = was["rooted_heap"] - cur["rooted_heap"]
        d_forb = was["forbidden"] - cur["forbidden"]
        if d_arena <= 0:
            continue
        n_ev = min(d_rooted, d_arena) if d_rooted > 0 else 0
        if n_ev > 0:
            ev.append((rel, n_ev, was["rooted_heap"], cur["rooted_heap"], was["arena"], cur["arena"]))
        n_debt = d_arena - n_ev
        if n_debt > 0:
            debt.append((rel, n_debt, d_forb))
    return ev, debt, unknown


def tracked_sources_outside_src(root):
    """⛔⭐ THE POPULATION LON'S ACCEPTANCE TEST GRADES IS THE SOURCE BASE, NOT src/ (coo 2026-09-18, on the cto's
    finding; CEO-842's census clause).  CEO-842 splits the work by directory -- ceo src/parsers, cfo src/runtime,
    cto the middle, coo src/driver and src/tools -- and TOP-LEVEL tools/ IS NAMED IN NONE OF THEM.  But the
    acceptance test is TEXTUAL and it is Lon's: a grep for the four names over the SCRIP source base returns ZERO.
    A census scoped to src/ prints ZERO and PASSES while that grep prints seventeen.

    ⛔ THAT IS THIS INSTRUMENT COMMITTING THE DEFECT IT EXISTS TO CATCH: the population the order sweeps and the
    population the acceptance test grades are not the same population, and the gap is invisible from inside any
    single lane because each seat greps only its own directory.  It is counted and NAMED here so the denominator
    question is answerable; whether these sites must be CONVERTED is a RULING (they are outside every named lane)
    and this instrument does not rule -- it refuses to be silent.

    ⛔ GIT-TRACKED ONLY, and that is not a convenience: the working tree carries .scratch/wt-bisect* worktrees
    holding whole copies of src/, which a naive walk counts as 3314 sites of other people's history.  What ships
    is what git tracks."""
    # ⛔ THE REASON TRAVELS WITH THE REFUSAL (coo 2026-09-18, caught in this function within the hour of writing
    # it).  The first cut swallowed every exception into a bare `return None`, and the caller printed "git could
    # not list the tracked source base" -- which was FALSE: git was fine, the module had never imported
    # subprocess, and a NameError was wearing a misdiagnosis that would have sent the next reader to their git
    # install.  An instrument that reports the wrong cause is worse than one that reports none.
    try:
        r = subprocess.run(["git", "-C", root, "ls-files", "--", "*.c", "*.h", "*.cpp"],
                           capture_output=True, text=True, timeout=30)
    except Exception as e:
        return None, [("<could not run git>", 0, "%s: %s" % (type(e).__name__, e))]
    if r.returncode != 0:
        # ⛔ NOT A GIT CHECKOUT IS NOT A FAILURE, IT IS NOT-APPLICABLE (coo 2026-09-18).  A scratch fixture tree has
        # no tracked source base at all, so there is no half of Lon's acceptance test for it to be missing -- and
        # refusing there would make every hermetic fixture in this file unmeasurable to prove a point about the
        # real tree.  A git that failed for ANY OTHER reason is still a refusal, because then the population
        # exists and could not be read, which is the case that matters.
        err = (r.stderr or "").strip()
        if "not a git repository" in err.lower():
            return -1, []
        return None, [("<git refused>", r.returncode, err[:200])]
    rels = [x for x in r.stdout.split("\n") if x.strip() and not x.startswith("src/")]
    hits = []
    for rel in rels:
        path = os.path.join(root, rel)
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        for i, line in enumerate(text.split("\n"), 1):
            for m in re.finditer(r"\b(malloc|calloc|realloc|free)[ \t]*\(", line):
                hits.append((rel, i, m.group(1)))
    return len(rels), hits


def census(root, by_dir=False, sites=False, out=print):
    files = source_files(root)
    if not files:
        out(f"CENSUS c-allocators REFUSED(2): no source files under {os.path.join(root, 'src')} -- a zero from a "
            f"tool that read nothing is not a zero")
        return 2
    forb, dest, aliases, alias_calls, prose, bare, texts_for_container = scan(files, root)
    out(f"CENSUS c-allocators SCOPE files={len(files)} under src/ (every {'/'.join(SRC_EXT)} file, generated flex "
        f"and bison output INCLUDED -- a generated file that is checked in is source, CEO-842)")

    # ⛔⭐ AND THE SCOPE LINE ABOVE IS NOT LON'S SCOPE.  See tracked_sources_outside_src.
    n_outside, outside_hits = tracked_sources_outside_src(root)
    if n_outside == -1:
        out("CENSUS c-allocators OUTSIDE-SRC NOT-APPLICABLE: this root is not a git checkout, so it has no tracked "
            "source base outside src/. Stated rather than skipped -- a check that goes quiet is indistinguishable "
            "from a check that passed")
        COUNTS["outside_src_sites"] = 0
        outside_refused = False
    elif n_outside is None:
        why = outside_hits[0][2] if outside_hits else "no reason returned"
        out(f"CENSUS c-allocators OUTSIDE-SRC REFUSED(2): the tracked source base could not be listed ({why}), so "
            f"the population Lon's acceptance test grades was not read. A src/-only zero is NOT that test.")
        COUNTS["outside_src_sites"] = None
        outside_refused = True
    else:
        COUNTS["outside_src_sites"] = len(outside_hits)
        byf = {}
        for rel, _ln, _nm in outside_hits:
            byf[rel] = byf.get(rel, 0) + 1
        out(f"CENSUS c-allocators OUTSIDE-SRC={len(outside_hits)} in {len(byf)} of {n_outside} tracked "
            f"{'/'.join(SRC_EXT)} file(s) OUTSIDE src/ -- ⛔ LON'S ACCEPTANCE TEST IS A GREP OVER THE SOURCE BASE "
            f"AND THIS IS THE PART OF IT src/ DOES NOT COVER. CEO-842 splits the work by directory and TOP-LEVEL "
            f"tools/ AND ../harness/scripts/ ARE NAMED IN NO LANE, so these survived every seat's sweep while every seat's "
            f"census read zero. NAMED, not ruled: whether they convert is the ceo's call, not this instrument's")
        for rel, n in sorted(byf.items(), key=lambda kv: -kv[1]):
            out(f"  OUTSIDE-SRC {rel} {n} site(s)")
        outside_refused = False

    per = {n: sum(1 for s in forb if s[2] == n) for n in FORBIDDEN}
    total = len(forb)
    out("CENSUS c-allocators FORBIDDEN total=%d (%s) want=0 -- Lon's acceptance test, CEO-842" %
        (total, " ".join(f"{n}={per[n]}" for n in FORBIDDEN)))
    # ⛔ THE DECOMPOSITION IS PRINTED BECAUSE TWO HONEST TOOLS GET TWO DIFFERENT TOTALS HERE AND THE DIFFERENCE IS
    # NOT AN ERROR.  A grammar's action code is COPIED into its generated twin, so `raku.y` and `raku.tab.c` hold
    # the same call twice -- and BOTH are checked in, so Lon's "0 instances in the SCRIP source base" binds on
    # both.  A cure applied only to the generated file is undone by the next regeneration; a cure applied only to
    # the grammar leaves the shipped file dirty until someone regenerates.  Neither half is optional, and a reader
    # comparing this total against one taken over .c/.h alone needs the split rather than a discrepancy.
    gen = [x for x in forb if ".lex.c" in x[0] or ".tab.c" in x[0]]
    gram = [x for x in forb if x[0].endswith((".y", ".l"))]
    hand = total - len(gen) - len(gram)
    out(f"CENSUS c-allocators SPLIT hand_written={hand} generated_lex_tab={len(gen)} grammar_y_l={len(gram)} -- the "
        f"last two OVERLAP by construction (a grammar's action code is copied into its generated twin) and both "
        f"are checked in, so both must reach zero: a cure in only one of the pair is undone by the next regeneration")
    out(f"CENSUS c-allocators ALIASES={len(aliases)} ALIAS-CALLS={len(alias_calls)} want=0/0 -- the rule forbids "
        f"these four under ANY spelling (CEO-844): a define whose body REACHES a forbidden name, through however "
        f"many other defines, is that name, and every CALL through such a spelling is a call site a four-name "
        f"grep cannot see")
    for (rel, ln, nm), (target, chain) in sorted(aliases.items())[:12]:
        out(f"  ALIAS {rel}:{ln} {nm} -> {target}   via {' -> '.join(chain)}")
    agg_ac = {}
    for rel, _ln, nm, target in alias_calls:
        agg_ac.setdefault((nm, target), []).append(rel)
    for (nm, target), rels in sorted(agg_ac.items(), key=lambda kv: -len(kv[1]))[:12]:
        out(f"  ALIAS-CALL {nm}() -> {target}  {len(rels)} call(s) in {len(set(rels))} file(s): "
            f"{', '.join(sorted(set(rels))[:4])}")

    dper = {}
    for _rel, _ln, _sym, d in dest:
        dper[d] = dper.get(d, 0) + 1
    out("CENSUS c-allocators DESTINATIONS " + " ".join(f"{d}={dper.get(d, 0)}" for d in DESTINATIONS) +
        " -- where the converted sites went; a count of the four names alone would read green on a tree where "
        "half the runtime quietly lives outside the collector (CEO-843)")

    # ⛔ THE ANTI-EVASION POPULATION
    viol = [(r, l, s) for (r, l, s, d) in dest if d == "ARENA" and runtime_reachable(r)]
    mmap_out = [(r, l, s) for (r, l, s, d) in dest if d == "MMAP" and not is_collector_bookkeeping(r)]
    out(f"CENSUS c-allocators ARENA-IN-RUNTIME={len(viol)} -- the arena holding runtime-reachable memory. ⛔ THIS "
        f"TOTAL IS NOT A VERDICT ON ITS OWN (CEO-846): it is split below by WHAT EACH SITE WAS BEFORE, because "
        f"the clause was one rule over two different acts and only one of them is the evasion")
    for rel, ln, sym in viol[:15]:
        out(f"  ARENA-IN-RUNTIME {rel}:{ln} {sym}")

    # ⛔⭐ THE CLASS SPLIT (CEO-846).  Class 1 is the evasion and is a hard red; class 2 is transitional debt
    # that the ratchet drives to zero.  The discriminator is the per-file provenance baseline, and WITHOUT IT
    # THE SPLIT IS NOT COMPUTABLE -- so it REFUSES rather than guessing, and never silently calls debt an
    # evasion (which would red an honest landing) or an evasion debt (which would admit the very thing the
    # clause exists to stop).
    libc_misuse = libc_ownership_census(texts_for_container, out=out)
    COUNTS["libc_owned_misuse"] = len(libc_misuse)
    COUNTS["libc_doors"] = len(libc_doors_census(texts_for_container, out=out))
    live_c, latent_c = container_census(texts_for_container, out=out)
    COUNTS["container_unmarked_live"] = len(live_c)

    # ⛔⭐ CLASS 3, RULED-PERMANENT (ceo CEO-856 on the cfo's proposal, cfo-859).  Class 2 DEBT means "was a libc
    # malloc, now in the arena, HOLDER NOT YET ROOTED", and its whole meaning is that it ratchets to zero as each
    # holder is rooted.  That model assumes every arena-in-runtime site is a holder waiting to be rooted.  Some are
    # not: CEO-854 ruled all five getline buffers PERMANENTLY and CORRECTLY arena -- the program is handed a copy and
    # no buffer pointer enters anything the collector walks, so there is no future landing in which rooting them
    # becomes correct.  Counting those as debt makes the ratchet's target of zero UNREACHABLE BY CONSTRUCTION, which
    # is how a ratchet stops being believed.  Class 3 is COUNTED, PRINTED, and NOT driven to zero -- and it is the
    # CITATION, graded hard below, that stops it becoming the one hiding place in the census.
    rp_rows, rp_bad = read_ruled_permanent(RULED_PERMANENT)
    perm, viol_rest = split_ruled_permanent(viol, rp_rows)
    rp_unresolved, rp_unreadable = [], None
    for r in rp_rows:
        ok, where = ruling_resolves(r["ruling"])
        if ok is None:
            rp_unreadable = where
        elif not ok:
            rp_unresolved.append(r)
    COUNTS["arena_in_runtime_ruled_permanent"] = len(perm)
    COUNTS["arena_in_runtime_ratcheted"] = len(viol) - len(perm)
    out(f"CENSUS c-allocators CLASS-3-RULED-PERMANENT={len(perm)} of ARENA-IN-RUNTIME={len(viol)} in "
        f"{len(rp_rows)} registry row(s) -- runtime memory PROVEN unreachable by the collector and ruled arena BY "
        f"NAME. Counted and printed, NOT driven to zero: there is no landing in which rooting it becomes correct, so "
        f"carrying it as debt would make the ratchet's target unreachable by construction. ⛔ THE RATCHETED NUMBER IS "
        f"ARENA-IN-RUNTIME MINUS THIS = {len(viol) - len(perm)}")
    for rel, ln, sym in perm[:12]:
        cite = next((r["ruling"] for r in rp_rows if r["file"] == rel and r["symbol"] == sym), "?")
        out(f"  CLASS-3-RULED-PERMANENT {rel}:{ln} {sym} -- ruled by {cite}")
    used = set()
    for rel, _ln, sym in perm:
        used.add((rel, sym))
    for r in rp_rows:
        if (r["file"], r["symbol"]) not in used:
            out(f"  CLASS-3 UNUSED ROW {r['file']} {r['symbol']} ({r['ruling']}) licences {r['sites']} site(s) that "
                f"this tree does not have -- NAMED, not red: a licence outliving its site is stale, and a stale "
                f"licence nobody can see is how the next one gets written for a site that never existed")
    for ln_, raw in rp_bad:
        out(f"  \u26d4 CLASS-3 MALFORMED ROW {RULED_PERMANENT}:{ln_} -- five tab-separated fields are required "
            f"(file, symbol, sites, ruling, reason) and sites must be a number: {raw}")
    for r in rp_unresolved:
        out(f"  \u26d4 CLASS-3 CITATION DOES NOT RESOLVE: {r['file']} {r['symbol']} cites {r['ruling']}, which is not "
            f"in the record. AN ENTRY IN CLASS 3 WITH NO RULING BEHIND IT IS A CLASS 1 EVASION IN DISGUISE -- that is "
            f"the cfo's own sentence and it is the only thing standing between a third class and a hiding place")
    if rp_unreadable:
        out(f"  \u26d4 CLASS-3 CITATIONS NOT MEASURABLE: the record at {rp_unreadable} could not be read, so no "
            f"citation was checked either way. Merge .github and re-run -- convicting an honest entry because the "
            f"reader is behind is the same fault as passing a dishonest one")

    sbase = read_sites_baseline(SITES_BASELINE)
    now_pf = per_file(forb, dest)
    COUNTS["arena_in_runtime"] = len(viol)
    if sbase is None:
        out(f"CENSUS c-allocators ARENA-SPLIT REFUSED(2): no per-file provenance baseline at {SITES_BASELINE} -- "
            f"the discriminator is what each site WAS, and without it this instrument cannot tell the evasion "
            f"(collected heap -> arena) from transitional debt (malloc -> arena). It does not guess.")
        COUNTS["arena_in_runtime_evasion"] = None
        COUNTS["arena_in_runtime_debt"] = None
        prov_refused = True
    else:
        prov_refused = False
        # ⛔ CLASS 3 IS SUBTRACTED FROM THE ARENA COUNT PROVENANCE SEES, so a ruled-permanent site is never ALSO
        # counted as class-2 debt -- one site, one class, or the debt number can never reach zero.
        perm_pf = {}
        for rel, _ln, _sym in perm:
            perm_pf[rel] = perm_pf.get(rel, 0) + 1
        now_pf_np = {}
        for rel, cur in now_pf.items():
            c = dict(cur)
            c["arena"] = max(0, c.get("arena", 0) - perm_pf.get(rel, 0))
            now_pf_np[rel] = c
        ev, debt, unknown = provenance(now_pf_np, sbase)
        n_ev = sum(x[1] for x in ev)
        n_debt = sum(x[1] for x in debt)
        n_unk = sum(x[1] for x in unknown)
        COUNTS["arena_in_runtime_evasion"] = n_ev + n_unk
        COUNTS["arena_in_runtime_debt"] = n_debt
        out(f"CENSUS c-allocators ARENA-SPLIT CLASS-1-EVASION={n_ev} want=0 HARD CLASS-2-DEBT={n_debt} ratcheted "
            f"UNATTRIBUTABLE={n_unk} -- class 1 is a site that was on the COLLECTED HEAP and is now in the arena "
            f"(moving an object out of the collector's sight to avoid rooting it, reverted on sight); class 2 was "
            f"a libc malloc and is now in the arena, the same lifetime it already had, debt and not a cure. ⛔ THE "
            f"RESOLUTION IS THE FILE, NOT THE SITE: a class-1 site hidden under a same-file class-2 credit in the "
            f"same landing is the one shape this cannot see, so read the number as per-file NET, not site-exact")
        for rel, n, r0, r1, a0, a1 in ev[:15]:
            out(f"  ⛔ CLASS-1-EVASION {rel} {n} site(s): rooted_heap {r0} -> {r1} while arena {a0} -> {a1} -- "
                f"THE CURE FOR AN UNROOTED HOLDER IS A ROOT, NEVER A DIFFERENT ALLOCATOR")
        for rel, n, d_forb in debt[:12]:
            out(f"  CLASS-2-DEBT {rel} {n} site(s) (the file lost {d_forb} forbidden call(s)) -- ratcheted to 0 as "
                f"the holder is rooted")
        for rel, n in unknown[:12]:
            out(f"  ⛔ UNATTRIBUTABLE {rel} {n} arena site(s) in a file the provenance baseline does not name -- "
                f"counted WITH the evasion, because a site whose history this instrument cannot read is not "
                f"given the benefit of the doubt")
    out(f"CENSUS c-allocators MMAP-OUTSIDE-GC_HEAP={len(mmap_out)} NAMED, not a verdict -- mmap belongs to the "
        f"collector's own bookkeeping; elsewhere it wants a reason in its commit")
    for rel, ln, sym in mmap_out[:10]:
        out(f"  MMAP-OUTSIDE {rel}:{ln} {sym}")

    # ⛔ THE TWO RESIDUES A TEXTUAL GREP HITS THAT ARE NOT CALL SITES.  Lon's acceptance test is a grep, so the
    # day the call sites reach 0 his grep will still print these -- and a reader who has not been told why will
    # either call the instrument a liar or delete a licence header to make the number move.  Both are worse than
    # the residue.  Printed APART, never folded into FORBIDDEN, never ratcheted as a defect.
    n_prose = sum(prose.values())
    out(f"CENSUS c-allocators PROSE-RESIDUE={n_prose} in {len(prose)} file(s) -- NOT call sites and NOT in the "
        f"count above: the four names inside comments and string literals, most of them the GPL sentence "
        f"'This program is free software' that bison and flex write into every generated file. ⛔ A LICENCE "
        f"HEADER IS NEVER EDITED TO MAKE A GREP READ ZERO (CEO-844 clause 2)")
    for rel, n in sorted(prose.items(), key=lambda kv: (-kv[1], kv[0]))[:12]:
        out(f"  PROSE {rel} {n}")
    out(f"CENSUS c-allocators NON-CALL-REFS={len(bare)} -- NOT call sites and NOT in the count above: the four "
        f"names in preprocessor guards and #include <malloc.h>, which a grep hits and a compiler never calls; a "
        f"genuine function-pointer hand-off (`= free`, `, free)`) would land here too and IS a site to convert")
    for rel, ln, nm, txt in bare[:10]:
        out(f"  NON-CALL-REF {rel}:{ln} {nm} | {txt}")

    if total == 0 and not dest:
        out("CENSUS c-allocators REFUSED(2): the four names read 0 AND no destination symbol appears anywhere -- "
            "that would mean nothing in this compiler allocates at all, which is not a tree, it is a tool that "
            "read the wrong thing. A vacuous zero is not a pass.")
        return 2

    if by_dir:
        agg = {}
        for rel, _l, n in forb:
            d = os.path.dirname(rel)
            agg.setdefault(d, {})[n] = agg.setdefault(d, {}).get(n, 0) + 1
        for d in sorted(agg, key=lambda k: -sum(agg[k].values())):
            out(f"  BY-DIR {d:32s} " + " ".join(f"{n}={agg[d].get(n, 0)}" for n in FORBIDDEN) +
                f"  total={sum(agg[d].values())}")
    if sites:
        for rel, ln, n in forb:
            out(f"  FORBIDDEN-SITE {rel}:{ln} {n}")

    COUNTS["__per_file__"] = now_pf
    COUNTS["forbidden_total"] = total
    for n in FORBIDDEN:
        COUNTS[n] = per[n]
    COUNTS["aliases"] = len(aliases)
    COUNTS["alias_calls"] = len(alias_calls)
    COUNTS["prose_residue"] = n_prose
    # ⛔ A CLASS-3 ENTRY WHOSE CITATION DOES NOT RESOLVE REDS (ceo CEO-856): it is a class-1 evasion in disguise, so
    # it joins the evasion in the verdict rather than being a note under a green line.  A MALFORMED ROW REDS TOO -- a
    # row this reader dropped is a licence nobody granted.  ⛔ AND AN UNREADABLE RECORD REFUSES rc=2 AHEAD OF BOTH:
    # could-not-measure is never green and never red, and an unmerged .github is exactly that case.
    # ⛔ AND A PRINTED REFUSAL THAT DOES NOT REACH THE VERDICT IS A NOTE UNDER A GREEN LINE (coo 2026-09-18,
    # caught in my own addition the same hour: OUTSIDE-SRC printed REFUSED(2) and the census still returned GREEN).
    if outside_refused:
        out("CENSUS c-allocators REFUSED(2): the OUTSIDE-SRC population -- the half of Lon's acceptance test that "
            "src/ does not cover -- was not read, so this run cannot speak to that test at all")
        return 2
    if rp_unreadable:
        out(f"CENSUS c-allocators REFUSED(2): {len(rp_rows)} class-3 citation(s) could not be checked against "
            f"{rp_unreadable}")
        return 2
    red = (total > 0 or aliases or alias_calls or COUNTS.get("arena_in_runtime_evasion") or prov_refused
           or rp_unresolved or rp_bad)
    out(f"CENSUS c-allocators {'RED' if red else 'GREEN'}")
    return 1 if red else 0


# ⛔ prose_residue is MEASURED and PRINTED but deliberately NOT ratcheted: it is licence text, it is not ours to
# drive to zero, and a ratchet on it is an instruction to edit a copyright header.  alias_calls IS ratcheted --
# that one is ours and it is the half a four-name grep cannot see.
# ⛔ arena_in_runtime is the TOTAL and is PRINTED, but what is RATCHETED is arena_in_runtime_ratcheted -- the total
# MINUS class 3 (ceo CEO-856, 2026-09-18).  Ratcheting the raw total was correct while every arena-in-runtime site was
# a holder waiting to be rooted; CEO-854 ruled five of them permanently and correctly arena, so the raw total can no
# longer reach zero and a ratchet with an unreachable target teaches the fleet to raise baselines.  ⭐ THIS IS NOT A
# WEAKENING: evasion is still a HARD 0, debt still only falls, and every site that leaves the ratchet must be named in
# c_allocator_ruled_permanent.tsv with a ruling that RESOLVES -- an unresolved citation reds the census outright.
# ⛔ outside_src_sites IS RATCHETED BUT IS NOT A HARD ZERO (coo 2026-09-18, the cto's finding).  Whether the 20
# sites in tools/rakugram and ../harness/scripts/monitor must CONVERT is a ruling nobody has made -- CEO-842 splits the work
# by directory and top-level tools/ and ../harness/scripts/ are named in no lane.  So the instrument does what an instrument
# may do without a ruling: it counts them, names them, and refuses to let the number GROW while the question is
# open.  If the ceo rules them in, the count falls to 0 and the ratchet reds asking for the win to be recorded.
RATCHET_KEYS = ["forbidden_total", "malloc", "calloc", "realloc", "free", "aliases", "alias_calls",
                "arena_in_runtime_ratcheted", "arena_in_runtime_evasion", "arena_in_runtime_debt",
                "container_unmarked_live", "libc_owned_misuse", "libc_doors", "outside_src_sites"]


def ratchet(path, out=print):
    if not os.path.exists(path):
        out(f"RATCHET REFUSED(2): no baseline at {path}"); return 2
    base = {}
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            if line.startswith("# CRITERION CHANGED"):
                out("RATCHET " + line.rstrip()[2:])
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) >= 2:
            base[f[0]] = int(f[1])
    worse, better, unmeasured = [], [], []
    for k in RATCHET_KEYS:
        want, got = base.get(k), COUNTS.get(k)
        if want is None:
            unmeasured.append(f"{k} (not in the baseline)"); continue
        if got is None:
            unmeasured.append(f"{k} (not measured this run)"); continue
        mark = "="
        if got > want:
            worse.append(f"{k} {want} -> {got}"); mark = "WORSE"
        elif got < want:
            better.append(f"{k} {want} -> {got}"); mark = "BETTER"
        out(f"RATCHET {k} baseline={want} now={got} {mark}")
    out(f"population: {len(RATCHET_KEYS)} ratcheted count(s), {len(worse)} worse, {len(better)} better, "
        f"{len(unmeasured)} not measured")
    for u in unmeasured:
        out(f"  NOT-MEASURED {u}")
    for w in worse:
        out(f"  ⛔ WORSE {w} -- the rule drives these to 0; a landing may not add one")
    for b in better:
        out(f"  ⭐ BETTER {b} -- lower the baseline in the landing that earned it")
    if unmeasured:
        out("RATCHET REFUSED(2): a count the baseline names was not measured -- not green"); return 2
    if worse:
        out("RATCHET RED(1): a forbidden or arena-in-runtime count went UP"); return 1
    if better:
        out("RATCHET RED(1): a count FELL and the baseline still names the old number -- record the win"); return 1
    out("RATCHET GREEN: every ratcheted count is exactly its baseline"); return 0


ARMS_FLOOR = 41   # 38 + the three door arms of row instruments-the-c-allocator-census-knows-open-memstream-... (coo 2026-09-23)


def selftest():
    fails = arms = 0
    def ck(ok, label):
        nonlocal fails, arms
        arms += 1
        print(("  ok    " if ok else "  FAIL  ") + label)
        if not ok:
            fails += 1
    w = tempfile.mkdtemp(prefix="c_alloc_census."); __import__("atexit").register(__import__("shutil").rmtree, w, True)
    sd = os.path.join(w, "src", "runtime"); os.makedirs(sd)
    ld = os.path.join(w, "src", "lower"); os.makedirs(ld)
    gd = os.path.join(w, "src", "runtime", "rt"); os.makedirs(gd)

    open(os.path.join(ld, "clean.c"), "w").write(
        "void *f(void) { return ct_alloc(8); }\n"
        "/* malloc( in a comment is not a call */\n"
        'void g(void) { log("malloc(3) failed"); }\n'
        "void h(void) { ct_drop(p); }\n")
    buf = []
    rc = census(w, out=buf.append)
    j = "\n".join(buf)
    ck("FORBIDDEN total=0" in j, "a comment mention and a string literal are not call sites")
    ck("ARENA=2" in j, "ct_alloc and ct_drop in src/lower count as ARENA, the right destination for compile-time data")
    ck(rc == 0, "a clean compile-time file reads GREEN")

    open(os.path.join(ld, "dirty.c"), "w").write(
        "void *f(void) { void *p = malloc(8); p = realloc(p, 16); free(p); return calloc(2, 4); }\n"
        "extern void *malloc(size_t);\n")
    buf.clear(); rc = census(w, out=buf.append)
    j = "\n".join(buf)
    ck(rc == 1 and "FORBIDDEN total=4 (malloc=1 calloc=1 realloc=1 free=1)" in j,
       "four planted calls are counted one each, and the extern PROTOTYPE beside them is not a fifth")

    open(os.path.join(ld, "alias.c"), "w").write("#define MYALLOC malloc\nvoid *f(void){return MYALLOC(8);}\n")
    buf.clear(); census(w, out=buf.append)
    j = "\n".join(buf)
    ck("ALIASES=1" in j, "a #define alias of a forbidden name is counted -- the rule binds under any spelling")
    ck("ALIAS-CALL MYALLOC() -> malloc" in j, "and the CALL through that alias is counted and named with what it reaches")
    os.remove(os.path.join(ld, "alias.c"))
    os.remove(os.path.join(ld, "dirty.c"))

    # ⛔ CEO-844 clause 1: bison's chain, which one level of alias reading does not see and a grep never sees.
    open(os.path.join(ld, "chain.c"), "w").write(
        "#define YYMALLOC malloc\n#define YYSTACK_ALLOC YYMALLOC\n"
        "void *f(void) { return YYSTACK_ALLOC(8); }\n")
    buf.clear(); rc = census(w, out=buf.append)
    j = "\n".join(buf)
    ck("YYSTACK_ALLOC -> malloc   via YYSTACK_ALLOC -> YYMALLOC -> malloc" in j,
       "A TWO-LEVEL ALIAS CHAIN IS RESOLVED AND ITS ROUTE PRINTED -- bison writes exactly this, and one level of reading calls it clean")
    ck("ALIAS-CALLS=1" in j and rc == 1,
       "a call through the chain is a call site and REDS the census although the four names read zero in that file")
    os.remove(os.path.join(ld, "chain.c"))

    # ⛔ the false positive a substring reader produces out of flex's own hook rename.
    open(os.path.join(ld, "rename.c"), "w").write(
        "#define yyrealloc pascal_yyrealloc\n#define yyfree pascal_yyfree\nvoid f(void){ ct_drop(p); }\n")
    buf.clear(); census(w, out=buf.append)
    j = "\n".join(buf)
    ck("ALIASES=0" in j,
       "flex's `#define yyrealloc pascal_yyrealloc` RENAMES flex's hook and is NOT an alias of C realloc -- a substring reader calls it one and mislabels it `yy`")
    os.remove(os.path.join(ld, "rename.c"))

    # ⛔ CEO-844 clause 2: the licence sentence is not usage.
    open(os.path.join(ld, "gpl.c"), "w").write(
        "/* This program is free software; you can redistribute it and/or modify\n"
        "   it under the terms of the GNU General Public License.  free free */\n"
        "void f(void) { ct_drop(p); }\n")
    buf.clear(); rc = census(w, out=buf.append)
    j = "\n".join(buf)
    ck("FORBIDDEN total=0" in j and "PROSE-RESIDUE=5 in 2 file(s)" in j and "PROSE src/lower/gpl.c 3" in j,
       "A LICENCE HEADER IS PROSE RESIDUE, NAMED WITH ITS FILE AND KEPT OUT OF THE COUNT -- folding it in reads a permanent false red, and the cheapest way to clear a false red is to delete a copyright header")
    ck(rc == 0, "and a tree whose only remaining hits are licence prose reads GREEN -- the residue is not a defect")
    os.remove(os.path.join(ld, "gpl.c"))

    open(os.path.join(sd, "near_miss.c"), "w").write(
        "void f(void) { ct_free(p); rt_wsb_realloc(q, 8); my_free(r); }\n")
    buf.clear(); rc = census(w, out=buf.append)
    j = "\n".join(buf)
    ck("FORBIDDEN total=0" in j, "ct_free is not free and rt_wsb_realloc is not realloc -- the word boundary decides, not a substring")
    ck("ROOTED-HEAP=1" in j, "rt_wsb_realloc is counted as the ROOTED-HEAP destination")

    open(os.path.join(sd, "evade.c"), "w").write("void *f(void) { return ct_alloc(8); }\n")
    buf.clear(); rc = census(w, out=buf.append)
    j = "\n".join(buf)
    ck(rc == 1 and "ARENA-IN-RUNTIME=1" in j and "src/runtime/evade.c" in j,
       "AN ARENA ALLOCATION UNDER src/runtime IS A VIOLATION AND IS NAMED -- the evasion one name further out, which a four-name grep reads as green")
    os.remove(os.path.join(sd, "evade.c"))

    open(os.path.join(gd, "gc_heap.c"), "w").write("void *f(void){ return mmap(0, n, 3, 34, -1, 0); }\n")
    open(os.path.join(ld, "elsewhere.c"), "w").write("void *g(void){ return mmap(0, n, 3, 34, -1, 0); }\n")
    buf.clear(); census(w, out=buf.append)
    j = "\n".join(buf)
    ck("MMAP-OUTSIDE-GC_HEAP=1" in j and "src/lower/elsewhere.c" in j,
       "mmap in gc_heap.c is the collector's own bookkeeping and passes; mmap elsewhere is NAMED, not silently allowed")

    empty = tempfile.mkdtemp(prefix="c_alloc_empty."); __import__("atexit").register(__import__("shutil").rmtree, empty, True)
    buf.clear(); rc = census(empty, out=buf.append)
    ck(rc == 2 and "REFUSED(2)" in "\n".join(buf), "a tree with no source files REFUSES rc=2 -- it does not report a clean zero")

    vac = tempfile.mkdtemp(prefix="c_alloc_vac."); __import__("atexit").register(__import__("shutil").rmtree, vac, True); os.makedirs(os.path.join(vac, "src"))
    open(os.path.join(vac, "src", "a.c"), "w").write("int main(void){return 0;}\n")
    buf.clear(); rc = census(vac, out=buf.append)
    ck(rc == 2 and "A vacuous zero is not a pass" in "\n".join(buf),
       "zero forbidden names AND zero destination symbols REFUSES rc=2 -- that is a tool reading the wrong thing, not a cured tree")

    # ⛔⭐ CEO-850: WHO OWNS THE BLOCK.  Tested on both sides, because the arm's whole value is telling a
    # libc-owned pointer from an arena-owned one that is spelled identically two hundred lines away.
    def lc(src_):
        b2 = []
        return libc_ownership_census({"src/runtime/t.c": src_}, out=b2.append)
    h = lc("void f(void){ char *ln = NULL; size_t cap = 0; getline(&ln, &cap, stdin); ct_drop(ln); }\n")
    ck(len(h) == 1 and h[0][2] == "ct_drop" and h[0][4] == "getline",
       "A getline-OWNED BUFFER HANDED TO ct_drop IS NAMED -- the arena reads the bytes before a block it does not own, hunting a magic header in memory it does not own -- under ASLR that read can segfault, and where it is mapped the magic never matches and the buffer leaks (CFO-153: neither safe nor correct)")
    h = lc("void f(void){ size_t cap = 128; char *ln = (char *)ct_alloc(cap); ct_drop(ln); }\n")
    ck(len(h) == 0,
       "and an ARENA-owned buffer of the same name handed to the same ct_drop is CLEAN -- this is the by_name_dispatch.c pair, where a function-scoped reader convicts the correct one")
    h = lc("void f(void){ char *b = NULL; size_t c = 0; getline(&b, &c, stdin); "
           "rt_gc_visit_raw((const char **)&b); }\n")
    ck(len(h) == 1 and h[0][5] == "a collector root",
       "A COLLECTOR ROOT LAID OVER A getline-OWNED BUFFER IS NAMED -- the ceo's hazard on holder 12: the next getline reallocs it through libc and the root names memory the collector never moved. This shape is NOT in the tree today and the arm reds the moment it is added")
    h = lc("static char *tbuf = NULL;\nvoid f(void){ static size_t tc = 0; getline(&tbuf, &tc, fp); }\n")
    ck(len(h) == 0,
       "a getline-owned static that is never handed to our bookkeeping is NOT a misuse hit -- libc owns it and keeps it; the doors census below counts its getline() as a LIBC-DOOR instead")
    h = lc("void f(void){ char *buf = NULL; size_t len = 0; FILE *m = open_memstream(&buf, &len); fclose(m); ct_drop(buf); }\n")
    ck(len(h) == 1 and h[0][2] == "ct_drop" and h[0][4] == "open_memstream",
       "AN open_memstream-OWNED BUFFER HANDED TO ct_drop IS NAMED -- the four memstream capture sites on a35750d9b's parent, each a ct_drop that leaked 8 KB a call and segfaulted under ASLR, read LIBC-OWNED-MISUSE=0 while this door was missing (CFO-153)")

    # ⛔⭐ THE DOORS (row instruments-the-c-allocator-census-knows-open-memstream-...): a libc heap block handed to NOTHING of
    # ours was in no count; planted on both sides, like the ownership arms above.
    def dc(src_):
        b2 = []
        return libc_doors_census({"src/runtime/t.c": strip_comments(src_)}, out=b2.append)
    d = dc("static char *nm_tab[8];\nvoid f(const char *nm){ char *persist = strdup(nm); nm_tab[0] = persist; }\n")
    ck(len(d) == 1 and d[0][2] == "strdup",
       "A BARE strdup IS A LIBC DOOR -- kept in a static table and handed to nothing of ours, it was in no count (by_name_dispatch.c, 6a6983d9e); the doors census names it")
    d = dc('extern char *strdup(const char *);\nvoid f(const char *s){ char *a = ct_strdup(s); char *b = strdupa(s); '
           'log("strdup(x) failed"); /* strdup( */ (void)a; (void)b; }\n')
    ck(len(d) == 0,
       "and a prototype, ct_strdup (our arena), strdupa (stack, freed with its frame), a string literal and a comment are NOT doors")

    # ⛔⭐ CEO-846: the class split is the arm that decides whether an honest sweep lands or a cfo-f62a33aed
    # shaped evasion does, so it is tested on BOTH sides -- a debt that must NOT red as an evasion, and an
    # evasion that must NOT be excused as debt.
    B = {"src/runtime/a.c": {"forbidden": 4, "rooted_heap": 0, "arena": 0, "mmap": 0},
         "src/runtime/b.c": {"forbidden": 0, "rooted_heap": 3, "arena": 0, "mmap": 0},
         "src/lower/c.c":   {"forbidden": 9, "rooted_heap": 0, "arena": 0, "mmap": 0}}
    N = {"src/runtime/a.c": {"forbidden": 0, "rooted_heap": 0, "arena": 4, "mmap": 0},
         "src/runtime/b.c": {"forbidden": 0, "rooted_heap": 0, "arena": 3, "mmap": 0},
         "src/lower/c.c":   {"forbidden": 0, "rooted_heap": 0, "arena": 9, "mmap": 0}}
    ev, debt, unk = provenance(N, B)
    ck(sum(x[1] for x in debt) == 4 and any(r == "src/runtime/a.c" for r, _n, _d in debt)
       and not any(r == "src/runtime/a.c" for r, *_ in ev),
       "CLASS 2: four libc mallocs that became arena sites are DEBT, not an evasion -- the lifetime is the one they already had, and reading them as an evasion would red an honest sweep")
    ck(sum(x[1] for x in ev) == 3 and any(r == "src/runtime/b.c" for r, *_ in ev),
       "CLASS 1: three COLLECTED-HEAP sites that became arena sites are the EVASION and are NAMED -- the cure for an unrooted holder is a root, never a different allocator")
    ck(not any(r == "src/lower/c.c" for r, *_ in ev) and not any(r == "src/lower/c.c" for r, *_ in debt),
       "and src/lower is not runtime-reachable, so its nine arena sites are the arena doing its job, not a violation")
    ev2, _d2, unk2 = provenance({"src/runtime/z.c": {"forbidden": 0, "rooted_heap": 0, "arena": 2, "mmap": 0}}, B)
    ck(sum(x[1] for x in unk2) == 2,
       "a runtime arena site in a file the provenance baseline does not name is UNATTRIBUTABLE and is counted WITH the evasion -- a history this instrument cannot read gets no benefit of the doubt")

    # ⛔⭐ CEO-846 / CFO-96-97: the container arm, tested on the shape that fooled every census before it.
    def cc(body_src):
        buf2 = []
        lv, lt = container_census({"src/runtime/t.c": body_src}, out=buf2.append)
        return lv, lt
    lv, lt = cc("static DESCR_t *g_blk = (DESCR_t *)0;\n"
                "void t_gc_roots(void) { for (long n = 0; n < top; n++) rt_gc_visit_descr(&g_blk[n]); }\n")
    ck(len(lv) == 1 and lv[0][2] == "g_blk",
       "A POINTER CONTAINER WHOSE CONTENTS ARE VISITED AND WHOSE BLOCK IS NEVER MARKED IS LIVE AND NAMED -- that walk exists, is called, and reads as rooted to every census ever written; it is how g_name_save was reclaimed under a live call")
    lv, lt = cc("static DESCR_t *g_blk = (DESCR_t *)0;\n"
                "void t_gc_roots(void) { rt_gc_visit_raw((const char **)&g_blk); "
                "for (long n = 0; n < top; n++) rt_gc_visit_descr(&g_blk[n]); }\n")
    ck(len(lv) == 0, "and the same walk with the CONTAINER marked as well reads clean -- the arm grades the cure, not the shape")
    lv, lt = cc("static NV_t *g_tab[64];\n"
                "void t_gc_roots(void) { for (int b = 0; b < 64; b++) for (NV_t *e = g_tab[b]; e; e = e->next) "
                "rt_gc_visit_descr(&e->val); }\n")
    ck(len(lv) == 0 and any(x[2] == "g_tab" for x in lt),
       "a FIXED ARRAY of pointers is LATENT, not LIVE -- its storage is static so there is no block to mark, and calling that a defect is how this arm would become noise (it is exactly _var_buckets, which core_gc_roots marks per slot and marks correctly)")

    # ⛔⭐ CLASS 3, RULED-PERMANENT, PROVED ON BOTH SIDES (ceo CEO-856).  A class whose citation arm has never been
    # seen to RED is a hiding place with a comment on it, so every one of these arms plants the failure rather than
    # asserting the success: an entry with a bogus ruling must RED, an entry beyond its licensed count must fall back
    # to the ordinary grading, and a stale row must be NAMED.  The same shape as the fingerprint gate's planted arm.
    global RULED_PERMANENT
    _rp_saved = RULED_PERMANENT
    try:
        open(os.path.join(sd, "perm.c"), "w").write("void *f(void){ return ct_alloc(8); }\n")
        reg = os.path.join(w, "ruled.tsv")
        RULED_PERMANENT = reg

        open(reg, "w").write("# f\nsrc/runtime/perm.c\tct_alloc\t1\tCEO-854\tproven unreachable, ruled arena\n")
        buf.clear(); rc = census(w, out=buf.append); j = "\n".join(buf)
        ck("CLASS-3-RULED-PERMANENT=1" in j and "ruled by CEO-854" in j and "MINUS THIS = 0" in j,
           "A RULED-PERMANENT SITE IS COUNTED IN CLASS 3, NAMED WITH ITS RULING, AND TAKEN OUT OF THE RATCHETED NUMBER -- which is the whole point: it can never be rooted, so carrying it as debt makes the ratchet's target unreachable by construction")
        ck(COUNTS.get("arena_in_runtime") == 1 and COUNTS.get("arena_in_runtime_ratcheted") == 0,
           "and the RAW TOTAL is still measured and printed beside it -- two numbers, the honest total and the one the ratchet drives, neither replacing the other")
        ck(COUNTS.get("arena_in_runtime_debt") == 0,
           "a class-3 site is NOT also counted as class-2 debt -- one site, one class, or the debt number could never reach zero")

        open(reg, "w").write("src/runtime/perm.c\tct_alloc\t1\tCEO-999999\tno such ruling\n")
        buf.clear(); rc = census(w, out=buf.append); j = "\n".join(buf)
        ck(rc == 1 and "CITATION DOES NOT RESOLVE" in j and "CEO-999999" in j,
           "⛔ AN ENTRY WHOSE CITED RULING DOES NOT RESOLVE REDS -- an entry in class 3 with no ruling behind it is a CLASS 1 EVASION IN DISGUISE, and this arm is the only thing standing between a third class and a hiding place")

        open(os.path.join(sd, "perm2.c"), "w").write("void *g(void){ return ct_alloc(8); }\nvoid *h(void){ return ct_alloc(9); }\n")
        open(reg, "w").write("src/runtime/perm2.c\tct_alloc\t1\tCEO-854\tone site only\n")
        buf.clear(); census(w, out=buf.append); j = "\n".join(buf)
        ck("CLASS-3-RULED-PERMANENT=1" in j and COUNTS.get("arena_in_runtime_ratcheted") == 2,
           "A ROW LICENCES A COUNT, NOT A FILE: the second ct_alloc in the same file beyond the licensed 1 falls straight back into the ordinary grading, so a row can never become a blanket amnesty")
        os.remove(os.path.join(sd, "perm2.c"))

        open(reg, "w").write("src/runtime/nowhere.c\tct_alloc\t1\tCEO-854\tstale\n")
        buf.clear(); census(w, out=buf.append); j = "\n".join(buf)
        ck("CLASS-3 UNUSED ROW" in j and "nowhere.c" in j,
           "a row licensing a site the tree does not have is NAMED rather than silently carried -- a stale licence nobody can see is how the next one gets written for a site that never existed")

        open(reg, "w").write("src/runtime/perm.c\tct_alloc\tnotanumber\tCEO-854\tbad row\n")
        buf.clear(); rc = census(w, out=buf.append); j = "\n".join(buf)
        ck(rc == 1 and "MALFORMED ROW" in j,
           "and a MALFORMED row REDS rather than being dropped -- a row this reader silently skipped is a licence nobody granted and an evasion nobody would see")

        open(reg, "w").write("src/runtime/perm.c\tct_alloc\t1\tCEO-854\tok\n")
        global RECORD_OVERRIDE
        RECORD_OVERRIDE = os.path.join(w, "no-such-record", "GOAL-CEO.md")
        buf.clear(); rc = census(w, out=buf.append); j = "\n".join(buf)
        RECORD_OVERRIDE = None
        ck(rc == 2 and "NOT MEASURABLE" in j,
           "⛔ AND A RECORD THAT CANNOT BE READ REFUSES rc=2 AHEAD OF BOTH VERDICTS -- an unmerged .github cannot resolve a ruling landed this morning, and convicting an honest entry because the reader is behind is the same fault as passing a dishonest one")
        os.remove(os.path.join(sd, "perm.c"))
    finally:
        RULED_PERMANENT = _rp_saved

    # ⛔⭐ THE OUTSIDE-SRC READER, PROVED ON BOTH SIDES (coo 2026-09-18, the cto's finding).  This arm exists
    # because the reader's whole job is to NOT read zero over a population it never opened -- so it is planted
    # with a real git checkout carrying a malloc outside src/, and separately with a root that is not a checkout
    # at all, and both answers are asserted.  An instrument added to cure a vacuous population must not ship one.
    gw = tempfile.mkdtemp(prefix="c_alloc_git."); __import__("atexit").register(__import__("shutil").rmtree, gw, True)
    os.makedirs(os.path.join(gw, "src", "runtime"))
    os.makedirs(os.path.join(gw, "tools"))
    open(os.path.join(gw, "src", "runtime", "ok.c"), "w").write("void *f(void){ return ct_alloc(8); }\n")
    open(os.path.join(gw, "tools", "outside.c"), "w").write("void *g(void){ return malloc(8); }\n")
    _q = {"capture_output": True, "text": True}
    subprocess.run(["git", "-C", gw, "init", "-q"], **_q)
    subprocess.run(["git", "-C", gw, "config", "user.email", "t@t"], **_q)
    subprocess.run(["git", "-C", gw, "config", "user.name", "t"], **_q)
    subprocess.run(["git", "-C", gw, "add", "-A"], **_q)
    subprocess.run(["git", "-C", gw, "commit", "-qm", "i"], **_q)
    n_out, hits_out = tracked_sources_outside_src(gw)
    ck(n_out == 1 and len(hits_out) == 1 and hits_out[0][0] == "tools/outside.c",
       "A TRACKED malloc OUTSIDE src/ IS FOUND AND NAMED -- the population Lon's acceptance test greps is the source base, and a census scoped to src/ reads ZERO over it while his grep does not")
    _nogit = tempfile.mkdtemp(prefix="c_alloc_nogit."); __import__("atexit").register(__import__("shutil").rmtree, _nogit, True)
    n_na, _ = tracked_sources_outside_src(_nogit)
    ck(n_na == -1,
       "and a root that is NOT a git checkout answers NOT-APPLICABLE rather than refusing -- a fixture tree has no tracked source base to be missing, and refusing there would make every hermetic fixture unmeasurable to prove a point about the real tree")

    saved = dict(COUNTS)
    try:
        COUNTS.clear(); COUNTS.update({k: 0 for k in RATCHET_KEYS})
        b = os.path.join(w, "base.tsv")
        open(b, "w").write("".join(f"{k}\t0\n" for k in RATCHET_KEYS))
        buf.clear(); ck(ratchet(b, buf.append) == 0, "ratchet: every count exactly its baseline reads GREEN")
        COUNTS["malloc"] = 1
        buf.clear(); ck(ratchet(b, buf.append) == 1 and "WORSE" in "\n".join(buf),
                        "ratchet: a planted INCREASE is named and RED")
    finally:
        COUNTS.clear(); COUNTS.update(saved)

    print(f"population: {arms} selftest arm(s), {fails} FAIL")
    if arms < ARMS_FLOOR:
        print(f"SELFTEST REFUSED(2): {arms} arm(s) ran, below the recorded floor {ARMS_FLOOR}")
        return 2
    print("SELFTEST PASS" if fails == 0 else "SELFTEST FAIL")
    return 0 if fails == 0 else 1


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--ratchet", default="")
    ap.add_argument("--write-baseline", default="")
    ap.add_argument("--write-sites-baseline", default="", help="the PER-FILE provenance baseline the CEO-846 "
                    "class split is keyed on -- what each file held BEFORE the sweep")
    ap.add_argument("--by-dir", action="store_true", help="the four-name count per directory, for the split")
    ap.add_argument("--sites", action="store_true", help="name every remaining forbidden call site")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()
    rc = census(a.root, a.by_dir, a.sites)
    if a.write_baseline:
        # ⛔⭐ THE CRITERION NOTES SURVIVE THE REWRITE (coo 2026-09-18, caught by destroying them).  This writer
        # opened the file with "w" and a fixed three-line header, so EVERY prior comment -- including every
        # `# CRITERION CHANGED` note explaining why a number moved -- was silently deleted on each regeneration.
        # The cfo preserved them through their last landing BY HAND, which is the fragile path: a convention that
        # depends on each caller remembering is a convention that fails on the run that matters, and I proved it
        # within the hour by regenerating and wiping both of ours.
        # ⭐ THE NOTES ARE THE ONLY RECORD OF WHY A COUNT MOVED WITHOUT AN EDIT BEHIND IT (the cfo's libc_owned_misuse
        # 6 -> 0 is exactly that shape: not one of the six named lines changed, the declarations did).  A reader six
        # months out who finds a count drop with no note suspects the instrument.  So they are CARRIED, never pruned.
        carried = []
        _std = ("# c_allocator_baseline.tsv", "# Written by", "# rewrites this file")
        if os.path.exists(a.write_baseline):
            for line in open(a.write_baseline, encoding="utf-8"):
                if line.startswith("#") and not line.startswith(_std):
                    carried.append(line.rstrip("\n"))
        with open(a.write_baseline, "w", encoding="utf-8") as fh:
            fh.write("# c_allocator_baseline.tsv -- the counts Lon's eradication order drives to 0 (coo, CEO-842/843).\n"
                     "# Written by `util_c_allocator_census.py --write-baseline`; the landing that lowers a count\n"
                     "# rewrites this file in the same sitting.  key\tcount\n")
            for c in carried:
                fh.write(c + "\n")
            for k in RATCHET_KEYS:
                v = COUNTS.get(k)
                if v is not None:
                    fh.write(f"{k}\t{v}\n")
        print(f"baseline written: {a.write_baseline} ({len(carried)} criterion note line(s) carried forward)")
    if a.write_sites_baseline:
        pf = COUNTS.get("__per_file__") or {}
        import subprocess
        try:
            tree = subprocess.run(["git", "-C", a.root, "rev-parse", "--short", "HEAD"],
                                  capture_output=True, text=True, timeout=20).stdout.strip() or "unknown"
            dirty = subprocess.run(["git", "-C", a.root, "status", "--porcelain"],
                                   capture_output=True, text=True, timeout=20).stdout.strip()
        except Exception:
            tree, dirty = "unknown", ""
        with open(a.write_sites_baseline, "w", encoding="utf-8") as fh:
            fh.write("# c_allocator_sites_baseline.tsv -- WHAT EACH FILE HELD BEFORE THE SWEEP (coo, CEO-846).\n"
                     "#\n"
                     "# ⛔ THIS FILE IS THE DISCRIMINATOR AND IT IS THE WHOLE POINT OF THE SPLIT.  The clause `the\n"
                     "# arena may not hold anything the runtime can reach` covers two different acts: a site that\n"
                     "# was on the COLLECTED HEAP and is now in the arena is the EVASION (hard red, reverted on\n"
                     "# sight), and a site that was a libc malloc and is now in the arena is transitional DEBT (the\n"
                     "# same lifetime it already had, ratcheted to zero).  Nothing in the post-sweep tree can tell\n"
                     "# those apart -- only what the site WAS can -- so this file is cut from the PRE-SWEEP tree and\n"
                     "# a landing is graded against it.  Rewriting it from a post-sweep tree destroys the only\n"
                     "# evidence that separates a cure from an evasion, and reads GREEN forever after.\n"
                     f"# CUT FROM: SCRIP {tree}{'-DIRTY' if dirty else ''}  (forbidden_total={COUNTS.get('forbidden_total')})\n"
                     "# file\tforbidden\trooted_heap\tarena\tmmap\n")
            for rel in sorted(pf):
                c = pf[rel]
                fh.write(f"{rel}\t{c['forbidden']}\t{c['rooted_heap']}\t{c['arena']}\t{c['mmap']}\n")
        print(f"sites baseline written: {a.write_sites_baseline} ({len(pf)} file(s), tree {tree})")
    if a.ratchet:
        rc = 2 if 2 in (rc, ratchet(a.ratchet)) else max(rc, ratchet(a.ratchet))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
