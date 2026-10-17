#!/usr/bin/env python3
"""audit_second_stacks_census.py -- the census of per-construct global stacks (RULES.md FACT RULE -- NO GLOBAL HOLDS A STACK, CEO-1542;
the plan is .github/ARCH-GLOBAL-STACKS-TO-THE-ZETAS.md, CEO-1543). A second stack is a global, static or growable structure holding one
entry per live call, activation, match, scan, generator or nested construct; the machine stack is the stack.

    python3 ../harness/scripts/audit_second_stacks_census.py             the table: every named stack, its lane, and how many source references remain
    python3 ../harness/scripts/audit_second_stacks_census.py --name X    rc 0 GREEN when no reference to X remains under src/, rc 1 RED while any does,
                                                              rc 2 when X is not a censused name (add --any to census an arbitrary identifier)
A reference is a whole-word match in src/{runtime,templates,emitter,ir,driver} (.c .h .cpp .s .S .inc); the bomb strings a deletion leaves
count as references, so a bomb-only landing stays RED. A row's DONE-WHEN pairs --name with the language's smoke.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP"), "src")
DIRS = ("runtime", "templates", "emitter", "ir", "driver")
EXTS = (".c", ".h", ".cpp", ".s", ".S", ".inc")

# name, lane, language, smoke, placement (ARCH-GLOBAL-STACKS-TO-THE-ZETAS.md section 2)
TABLE = [
    ("g_icn_act",        "hq_icon",    "icon",    "test_smoke_icon.sh",    "the frame (ARCH-ICON-RTX.md section 9); deleted ca33ff82a, bombs remain"),
    ("rt_stno_stack",    "hq_zetas",   "snobol4", "test_smoke_snobol4.sh", "activation frame + the code map"),
    ("g_name_save",      "hq_zetas",   "snobol4", "test_smoke_snobol4.sh", "spine, DESCR cells pushed by the callee prologue"),
    ("g_rk_cb_hold",     "hq_raku",    "raku",    "test_smoke_raku.sh",    "LANDED (ceo, CEO-1560): the Raku block-callback holds (sort, reduce, map/grep, first) are a C-local record on each builtin's own frame, rk_cbh_t, chained from one head cell g_rk_cbh_cur and root-visited through the chain in bnd_gc_roots, the rk_redisp_t shape; the two errjmp catch sites restore the head; the holder, its three leaves and rt_gc_ws_roots are gone"),
    ("g_lvl_own",        "hq_zetas",   "snobol4", "test_smoke_snobol4.sh", "activation frame, one RAW word"),
    ("g_core_errjmp_stk", "cfo",       "snobol4", "test_smoke_snobol4.sh", "already a chain through C frames; the head cell to zeta-STANDING"),
    ("g_eval_frames",    "cfo",        "snobol4", "test_smoke_snobol4.sh", "the EVAL chain's activation frame or rt_eval's C local"),
    ("g_capo",           "hq_snobol4", "snobol4", "test_smoke_snobol4.sh", "spine record of the capture-call box"),
    ("g_dcf",            "hq_snobol4", "snobol4", "test_smoke_snobol4.sh", "the match frame: the CAS mark at entry"),
    ("g_dfx",            "hq_snobol4", "snobol4", "test_smoke_snobol4.sh", "the defer frame bb_match_defer pins"),
    ("call_stack_v",     "cfo",        "snobol4", "test_smoke_snobol4.sh", "the callee's activation frame, or deleted with the c2bb road"),
    ("_nstack",          "hq_snocone", "snocone", "test_smoke_snocone.sh", "DELETED OUTRIGHT with the five builtins nPush/nInc/nDec/nTop/nPop (Lon 2026-10-08 15:3x CDT, verbatim: Delete the built-in nPush, etc. We do not want them.; CEO-1559): no graded program reached them, the parsers and every corpus speller define their own over counter.sc; an undefined call is error 22 as in SPITBOL"),
    ("g_scan_stack",     "hq_icon",    "icon",    "test_smoke_icon.sh",    "two cells per scan in the enclosing procedure's frame"),
    ("g_icn_bi_top",     "hq_icon",    "icon",    "test_smoke_icon.sh",    "already a chain through C frames; the head cell to zeta-STANDING"),
    ("g_icn_gen_ret",    "hq_icon",    "icon",    "test_smoke_icon.sh",    "the generator header: the retained frame is the entry"),
    ("g_redispv",        "hq_raku",    "raku",    "test_smoke_raku.sh",    "spine, a counted region carved at dispatch entry, reached by a frame word"),
    ("_core_abort_stack", "cfo",       "snobol4", "test_smoke_snobol4.sh", "dead: no callers; deleted"),
    ("g_ctx_current",    "cfo",        "snobol4", "test_smoke_snobol4.sh", "dead: reaches only the eval_node abort; deleted"),
    ("rt_cap_stk_t",     "cfo",        "snobol4", "test_smoke_snobol4.sh", "dead: its C push is already a bomb; deleted"),
    ("pl_trace_stk",     "cfo",        "prolog",  "test_smoke_prolog.sh",  "RT_DIAG only; deleted"),
]
KEPT = [
    ("RT_DCAP_TOP / the CAS island (r12)", "the conditional-assignment stack: Lon 2026-10-07, kept in its mmap'd slab island"),
    ("cx->tr / the Prolog trail arena (r12)", "the trail and choice points: Lon 2026-10-07, kept in their mmap'd slab arena"),
]


def source_files():
    for d in DIRS:
        root = os.path.join(SRC, d)
        for dp, dn, fn in os.walk(root):
            for f in fn:
                if f.endswith(EXTS):
                    yield os.path.join(dp, f)


def count_refs(name, files):
    rx = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])")
    hits = []
    for p in files:
        try:
            with open(p, "rb") as fh:
                data = fh.read().decode("utf-8", "replace")
        except OSError:
            continue
        n = len(rx.findall(data))
        if n:
            hits.append((os.path.relpath(p, os.path.dirname(HERE)), n))
    return hits


def main(argv):
    if not os.path.isdir(SRC):
        print("REFUSED (rc=2): %s is not a directory -- cannot census" % SRC)
        return 2
    files = list(source_files())
    if not files:
        print("REFUSED (rc=2): no source files under %s -- cannot census" % SRC)
        return 2
    names = [t[0] for t in TABLE]
    if "--name" in argv:
        i = argv.index("--name")
        if i + 1 >= len(argv):
            print("REFUSED (rc=2): --name needs an identifier")
            return 2
        name = argv[i + 1]
        if name not in names and "--any" not in argv:
            print("REFUSED (rc=2): %s is not a censused second stack (add --any to census an arbitrary identifier; the table is in this script)" % name)
            return 2
        hits = count_refs(name, files)
        total = sum(n for _, n in hits)
        if total:
            print("RED: %s has %d reference(s) in %d file(s) under src/:" % (name, total, len(hits)))
            for p, n in sorted(hits, key=lambda h: -h[1])[:12]:
                print("  %5d  %s" % (n, p))
            return 1
        print("GREEN: no reference to %s remains under src/ (%d files censused)" % (name, len(files)))
        return 0
    print("SECOND STACKS CENSUS (%d source files under src/{%s}) -- RULES.md FACT RULE NO GLOBAL HOLDS A STACK, CEO-1542/1543" % (len(files), ",".join(DIRS)))
    print("%-20s %-11s %-8s %6s  %s" % ("name", "lane", "lang", "refs", "placement"))
    for name, lane, lang, smoke, place in TABLE:
        total = sum(n for _, n in count_refs(name, files))
        print("%-20s %-11s %-8s %6d  %s" % (name, lane, lang, total, place))
    for k, why in KEPT:
        print("%-20s %-11s %-8s %6s  %s" % ("KEPT", "-", "-", "-", k + " -- " + why))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
