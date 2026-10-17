#!/usr/bin/env python3
"""util_gen_gc_allocating_table.py -- THE ALLOCATING SET AS A GENERATED TABLE THE EMITTER CAN READ, DERIVED FROM
THE RUNTIME BINARY AND GATED AGAINST IT (cto 2026-09-18, row gc-the-emitter-emits-the-poll-not-the-template,
the ceo's CEO-898 proposal; design .github/ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 6.5d; law RULES.md FACT
RULE THE COLLECTOR GUESSES NOTHING, CEO-812).

WHY THIS FILE EXISTS.  The poll is placed by hand at 97 remaining call sites, one judgement each, and that method
has now cost four broken batches -- most recently a void-returning site that emptied the output of four frontends
with rc=0.  The cure is for THE EMITTER to emit the poll, because the emitter already routes every named runtime
call through one function (x86_rtcc_call) whose FIRST ACT is a symbol-keyed table lookup (x86_rtcc_clob).  The
only thing the emitter cannot do today is know WHICH callees allocate: that set is derived from the built
libscrip_rt.so by objdump, and the emitter is compiled INTO that .so, so it cannot consult a derivation of
itself.  This script closes that by generating the set as a checked-in table, and the gate beside it refuses a
table that disagrees with the binary's own call graph.

⛔ THE TABLE IS NOT A HAND LIST AND MUST NEVER BECOME ONE.  Both columns are DERIVED:

  (1) ALLOCATES -- every function whose call graph reaches rt_gcheap_alloc, from the SAME derivation the coo's
      safe-point census uses (util_gc_census.allocating_entries_from_binary, IMPORTED rather than copied, so the
      two instruments cannot drift apart).

  (2) RETURN CLASS -- read out of the binary's own DWARF, because the poll's SHAPE depends on it and reading it
      off a paragraph is what section 6.5a was cured of.  Four classes, and the reason each one is a separate
      class is a different emitted sequence:
        VOID    nothing is live in rax:rdx at the return; the bare poll is enough.
        DESCR   the callee returns a DESCR_t, so the pair MAY be spilled as a descriptor cell into the swept
                range and relocated -- ARCH-GC 6.5b's x86_rt_gc_poll_res().
        OTHER   the callee returns a long, an int, a pointer or some other struct.  ⛔ THIS IS NOT A DESCR AND
                SPILLING IT AS ONE IS THE CORRUPTION: gc_zeta_frame visits any word inside a heap block RAW and
                rewrites it when the block slides, so an untagged integer in the swept range comes back a
                relocated address.  It goes BELOW the poll's floor -- ARCH-GC 6.5c.
        UNKNOWN the DWARF does not settle it, or two translation units disagree.  ⛔ THE EMITTER EMITS NO POLL
                FOR AN UNKNOWN.  A guess here is the one thing Lon's rule forbids, and an UNKNOWN row is this
                instrument working, not failing.

⛔ AND DISAGREEMENT IS A FINDING, NOT A TIE TO BREAK.  A symbol defined in hand-written asm carries
DW_TAG_unspecified_type in its own translation unit (rt_gcheap_alloc is one), so the C prototype is taken from
the DECLARATION DIEs instead; but if two units give two DIFFERENT resolvable classes for one symbol, the row is
UNKNOWN and the symbol is named, because that is a real inconsistency in the tree and not a coin to flip.

USAGE: util_gen_gc_allocating_table.py [--so PATH] [--out PATH] | --check | --selftest
"""
import argparse, collections, importlib.util, os, re, subprocess, sys, tempfile
import difflib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
DEFAULT_SO = os.path.join(ROOT, "out", "libscrip_rt.so")
DEFAULT_OUT = os.path.join(ROOT, "src", "templates", "x86", "gc_allocating_table.inc")

RC_VOID, RC_DESCR, RC_OTHER, RC_UNKNOWN = "VOID", "DESCR", "OTHER", "UNKNOWN"
RC_ENUM = {RC_VOID: "GC_RET_VOID", RC_DESCR: "GC_RET_DESCR", RC_OTHER: "GC_RET_OTHER", RC_UNKNOWN: "GC_RET_UNKNOWN"}

def load_census():
    spec = importlib.util.spec_from_file_location("gc_census", os.path.join(HERE, "util_gc_census.py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m

DIE_RX = re.compile(r'^\s*<\d+><([0-9a-f]+)>:\s+Abbrev Number:\s+\d+\s+\((DW_TAG_\w+)\)')
AT_RX  = re.compile(r'^\s*<[0-9a-f]+>\s+(DW_AT_\w+)\s*:\s*(.*)$')
REF_RX = re.compile(r'<0x([0-9a-f]+)>')
TYPE_TAGS = {"DW_TAG_typedef", "DW_TAG_base_type", "DW_TAG_pointer_type", "DW_TAG_structure_type",
             "DW_TAG_const_type", "DW_TAG_volatile_type", "DW_TAG_enumeration_type", "DW_TAG_union_type",
             "DW_TAG_array_type", "DW_TAG_subroutine_type", "DW_TAG_unspecified_type", "DW_TAG_restrict_type"}

def dwarf_return_classes(so, out=print):
    """symbol -> return class, read out of the binary's own DWARF; disagreement between units reads UNKNOWN"""
    try:
        p = subprocess.Popen(["objdump", "--dwarf=info", so], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, text=True, errors="replace")
    except OSError as e:
        out(f"REFUSED(2): objdump --dwarf=info on {so} failed: {e}"); return None
    types = {}
    seen_by_name = collections.defaultdict(set)
    off = tag = None; cur = {}
    def flush():
        nonlocal off, tag, cur
        if off is not None:
            if tag in TYPE_TAGS:
                types[off] = (tag, cur.get("name"), cur.get("type"))
            if tag == "DW_TAG_subprogram" and cur.get("name"):
                seen_by_name[cur["name"]].add((cur.get("type"), "def" if cur.get("low_pc") else "decl"))
        off = tag = None; cur = {}
    for line in p.stdout:
        m = DIE_RX.match(line)
        if m:
            flush(); off, tag, cur = m.group(1), m.group(2), {}; continue
        if off is None: continue
        m = AT_RX.match(line)
        if not m: continue
        k, v = m.group(1)[6:], m.group(2).strip()
        if k == "name":
            cur["name"] = v.split("): ")[-1] if v.startswith("(indirect") else v
        elif k == "type":
            r = REF_RX.match(v); cur["type"] = r.group(1) if r else None
        elif k == "low_pc":
            cur["low_pc"] = v
    flush(); p.stdout.close(); p.wait()
    if not types:
        out(f"REFUSED(2): {so} carries no DWARF type information -- build it with -g or this table cannot be derived"); return None

    def resolve(t):
        hops = 0; walked = set()
        while t is not None and hops < 64:
            if t in walked: return RC_UNKNOWN
            walked.add(t)
            e = types.get(t)
            if e is None: return RC_UNKNOWN
            tg, nm, nxt = e
            if tg == "DW_TAG_pointer_type" or tg == "DW_TAG_array_type" or tg == "DW_TAG_subroutine_type": return RC_OTHER
            if tg == "DW_TAG_structure_type" or tg == "DW_TAG_union_type": return RC_DESCR if nm == "DESCR_t" else RC_OTHER
            if tg == "DW_TAG_base_type" or tg == "DW_TAG_enumeration_type": return RC_OTHER
            if tg == "DW_TAG_unspecified_type": return RC_UNKNOWN
            t = nxt; hops += 1
        return RC_UNKNOWN

    cls = {}
    for name, refs in seen_by_name.items():
        got = set()
        for tref, _kind in refs:
            got.add(RC_VOID if tref is None else resolve(tref))
        settled = got - {RC_UNKNOWN}
        cls[name] = settled.pop() if len(settled) == 1 else (RC_UNKNOWN if len(settled) != 1 else RC_UNKNOWN)
    return cls

def build_rows(so, out=print):
    census = load_census()
    alloc = census.allocating_entries_from_binary(so, out=lambda *_a, **_k: None)
    if alloc is None:
        out(f"REFUSED(2): the allocating set could not be derived from {so}"); return None
    cls = dwarf_return_classes(so, out=out)
    if cls is None: return None
    return sorted((s, cls.get(s, RC_UNKNOWN)) for s in alloc)

BANNER = "gc_allocating_table.inc"

NAME_W = 64
def render(rows, so):
    # CEO-1787: NO COUNT IN THE FILE. The table used to open with GC_ALLOC_TAB_N and four per-class counts, so
    # every landing that added a runtime function rewrote the same five lines and any two such landings conflicted
    # on rebase (46 regenerations in 30 hours on 10-14/15). The array is sized by its own rows and the length is one
    # fixed line after it; a new function is ONE inserted row, which git merges beside another seat's row. The gate
    # counts the classes from the rows.
    L = []
    L.append("#ifndef GC_ALLOCATING_TABLE_INC")
    L.append("#define GC_ALLOCATING_TABLE_INC")
    # INLINE NAMES (cto 2026-10-17): a const char * per row was one relative relocation per row in .data.rel.ro, which
    # ld.so applied and dirtied in every process of every language (about 2,850 rows, 45 kB); a fixed char[64] per row
    # is clean shared .rodata. The width is a constant so the line never changes; a longer symbol refuses below.
    long_names = [s for s, c in rows if len(s) >= NAME_W]
    if long_names:
        raise SystemExit("REFUSED(2): %d symbol(s) need more than %d bytes inline (first: %s) -- rename it or raise NAME_W deliberately" % (len(long_names), NAME_W - 1, long_names[0]))
    L.append("static const struct { char n[%d]; unsigned char rc; } GC_ALLOC_TAB[] = {" % NAME_W)
    for s, c in rows:
        L.append('    { "%s", %s },' % (s, RC_ENUM[c]))
    L.append("};")
    L.append("#define GC_ALLOC_TAB_N ((int)(sizeof GC_ALLOC_TAB / sizeof GC_ALLOC_TAB[0]))")
    L.append("#endif")
    return "\n".join(L) + "\n"

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--so", default=DEFAULT_SO)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true", help="regenerate and compare with the checked-in table; rc=1 if stale")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)
    if a.selftest: return selftest()
    if not os.path.exists(a.so):
        print(f"REFUSED(2): no runtime binary at {a.so} -- build first; a table generated from nothing measures nothing")
        return 2
    rows = build_rows(a.so)
    if rows is None: return 2
    txt = render(rows, a.so)
    by = collections.Counter(c for _s, c in rows)
    print("GC-ALLOC-TABLE symbols=%d VOID=%d DESCR=%d OTHER=%d UNKNOWN=%d so=%s"
          % (len(rows), by.get(RC_VOID, 0), by.get(RC_DESCR, 0), by.get(RC_OTHER, 0), by.get(RC_UNKNOWN, 0), a.so))
    if a.check:
        if not os.path.exists(a.out):
            print(f"STALE: {a.out} does not exist"); return 1
        have = open(a.out, encoding="utf-8").read()
        if have == txt:
            print("FRESH: the checked-in table is byte-identical to the one the binary's call graph and DWARF produce now")
            return 0
        hl, tl = have.split("\n"), txt.split("\n")
        diff = [i for i in range(max(len(hl), len(tl)))
                if (hl[i] if i < len(hl) else None) != (tl[i] if i < len(tl) else None)]
        print("STALE: the checked-in table disagrees with the binary at %d line(s); first at %d" % (len(diff), diff[0] + 1 if diff else -1))
        for i in diff[:6]:
            print("   have: %s" % (hl[i] if i < len(hl) else "<absent>"))
            print("   want: %s" % (tl[i] if i < len(tl) else "<absent>"))
        return 1
    open(a.out, "w", encoding="utf-8").write(txt)
    print("wrote %s" % a.out)
    return 0

def selftest():
    fails = []
    def ck(c, m):
        print(("  ok   " if c else "  FAIL ") + m)
        if not c: fails.append(m)
    rows = [("a_void", RC_VOID), ("b_descr", RC_DESCR), ("c_other", RC_OTHER), ("d_unknown", RC_UNKNOWN)]
    txt = render(rows, "x.so")
    ck("GC_ALLOC_TAB[] = {" in txt and "#define GC_ALLOC_TAB_N ((int)(sizeof GC_ALLOC_TAB / sizeof GC_ALLOC_TAB[0]))" in txt,
       "the rendered table is sized by its own rows and its length is one fixed line (CEO-1787)")
    ck(not re.search(r"#define GC_ALLOC_TAB_N\S* \d", txt), "no count is rendered -- a count line is rewritten by every landing that adds a function")
    grown = render(sorted(rows + [("bb_new", RC_VOID)]), "x.so")
    dl = [l for l in difflib.unified_diff(txt.split("\n"), grown.split("\n"), lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
    ck(dl == ['+    { "bb_new", GC_RET_VOID },'], "adding one allocating function changes exactly one line, an inserted row -- two seats' additions merge on rebase")
    ck('{ "b_descr", GC_RET_DESCR },' in txt, "a DESCR-returning symbol renders with the DESCR class")
    ck('{ "d_unknown", GC_RET_UNKNOWN },' in txt, "an UNSETTLED symbol renders as UNKNOWN rather than being dropped or guessed")
    ck(txt.count(", GC_RET_UNKNOWN },") == 1, "the UNKNOWN population is its own rows, which the gate counts, so a reader cannot miss it")
    lines = txt.split("\n")[:-1]
    ck(all(l.strip() for l in lines) and not any(("/*" in l) or ("//" in l) for l in lines),
       "no comment and no blank line is rendered into a src/ file (RULES.md ABSOLUTE: zero comments in C, LF, and "
       "the pre-commit hook refuses a staged src/ file carrying one) -- the provenance lives in this script and in "
       "the gate, never in the generated text")
    ck(render(sorted(rows), "x.so") == render(sorted(rows, reverse=True) and sorted(rows), "x.so"),
       "the rendering is a pure function of the sorted rows -- a regenerated table cannot differ by ordering alone")
    d = tempfile.mkdtemp(prefix="gc_allocating_selftest."); __import__("atexit").register(__import__("shutil").rmtree, d, True)
    p = os.path.join(d, "t.inc"); open(p, "w").write(txt)
    ck(open(p).read() == txt, "a written table reads back byte-identical, which is what --check compares")
    planted = txt.replace('{ "c_other", GC_RET_OTHER },\n', "")
    ck(planted != txt and "c_other" not in planted,
       "PLANTED: a symbol deleted from the table changes the text, so --check's byte comparison sees a dropped symbol")
    planted2 = txt.replace("GC_RET_OTHER", "GC_RET_DESCR")
    ck(planted2 != txt,
       "PLANTED: a symbol whose return class is silently widened from OTHER to DESCR changes the text -- that is the "
       "mutation that would spill an untagged long as a descriptor cell, so --check must be able to see it")
    print("SELFTEST %d/%d arms green" % (9 - len(fails), 9))
    return 1 if fails else 0

if __name__ == "__main__":
    sys.exit(main())
