#!/usr/bin/env python3
"""lib_rt_alloc_derive.py -- THE ALLOCATING FACT OF EVERY RUNTIME ENTRY, DERIVED FROM THE BINARY (DESIGN-PLAN zeta-layout step 5, stage 5c, the allocating half; ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md section 10;
CEO-2019).  The road util_gen_gc_allocating_table.py used to walk to write a 3,000-row file, reduced to a library that util_gen_rt_entry_table.py writes into TWO COLUMNS of rt_entries.tsv (rc and allocates) and that
the gates read.  The 3,000 C functions are not rows and not a set at run time: they are this derivation's input and nothing else's.

⛔ THE COLUMNS ARE NOT A HAND LIST AND MUST NEVER BECOME ONE.  Both are DERIVED:

  (1) ALLOCATES -- a function whose call graph reaches rt_gcheap_alloc, from the SAME derivation the coo's safe-point census uses (util_gc_census.allocating_entries_from_binary, IMPORTED rather than copied, so the two
      instruments cannot drift apart); a tail jump is an edge (rt_str_alloc and rt_agg_alloc reach the carve by jmp, and everything that reaches the heap only through them allocates).
  (2) RETURN CLASS -- read out of the binary's own DWARF, because the poll's SHAPE depends on it:
        VOID    nothing is live in rax:rdx at the return; the bare poll is enough.
        DESCR   the callee returns a DESCR_t, so the pair MAY be spilled as a descriptor cell into the swept range and relocated (ARCH-GC 6.5b).
        OTHER   a long, an int, a pointer or some other struct.  ⛔ NOT A DESCR: spilling it as one is the corruption (gc_zeta_frame rewrites any word inside a heap block when the block slides).
        UNKNOWN the DWARF does not settle it, or two translation units disagree.  ⛔ THE EMITTER EMITS NO POLL FOR AN UNKNOWN: a guess here is the one thing Lon's rule forbids.
⛔ DISAGREEMENT IS A FINDING, NOT A TIE TO BREAK: a symbol defined in hand-written asm carries DW_TAG_unspecified_type in its own unit, so the C prototype is taken from the DECLARATION DIEs; two units with two
DIFFERENT resolvable classes make the row UNKNOWN and name the symbol.

derive(so) -> {symbol: class} for every symbol of the allocating set, or None (it printed why; the caller refuses rc 2).
"""
import collections, importlib.util, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
DEFAULT_SO = os.path.join(ROOT, "out", "libscrip_rt.so")

RC_VOID, RC_DESCR, RC_OTHER, RC_UNKNOWN = "VOID", "DESCR", "OTHER", "UNKNOWN"

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


def derive(so, out=print):
    """{symbol: return class} for every function of the allocating set of the binary at so; None when it cannot be derived"""
    census = load_census()
    alloc = census.allocating_entries_from_binary(so, out=lambda *_a, **_k: None)
    if alloc is None:
        out(f"REFUSED(2): the allocating set could not be derived from {so}")
        return None
    cls = dwarf_return_classes(so, out=out)
    if cls is None:
        return None
    return {s: cls.get(s, RC_UNKNOWN) for s in alloc}
