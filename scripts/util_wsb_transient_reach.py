#!/usr/bin/env python3
"""util_wsb_transient_reach.py -- DOES A REGEX ROAD REACH A SAFE POINT? (hq_runtime, ceo-2079; the TRANSIENT rows of gc_wsb_producers.tsv; ARCH-GC-COMPILE-TIME-FRAME-MAPS 13.14)

WHAT IT MEASURES.  The eleven TRANSIENT rows of gc_wsb_producers.tsv say that rx.c's graph (RxNode, RxSet, RxCap, RxProg and their vectors, all HB_WSB blocks that point at each
other) lives inside one rx_compile or rx_exec call, and that this machine collects only at an emitted poll after an allocating runtime call returns, so no collection finds the
graph live.  The second half is a statement about the runtime's call graph, so it is measured there: from the built libscrip_rt.so, with util_gc_census's own reverse-reach
derivation (the one util_gen_gc_allocating_table.py builds the allocating set from, IMPORTED and not copied), no ROOT may reach a SAFE POINT.
  ROOTS      every function the ELF symbol table places in rx.c (the local symbols after its FILE entry, readelf -s) and every global rx.c defines, plus the host callbacks the source assigns into an RxEnv (rk_rx_rule; fold and prop are NULL on the road).
             rx.c reaches its own continuations (k->fn) and the RxEnv callbacks only by indirect calls, which a call graph cannot follow; taking every rx.c symbol as a root and the
             callbacks by name is what makes those targets part of the graph.
  SAFE POINTS  the collection entries (gc_point_arr_run, rt_gc_poll_slow, rt_gc_poll_asm, rt_gc_poll, gc_collect_ex, gc_collect_ex_c, rt_gc_collect, rt_gc_collect_c) and the two
             dispatchers that run arbitrary named code (try_call_builtin_by_name, rt_call_arr_impl): a collection, or user code that may collect, inside the call.
  THE CUT    rt_heap_out_of_memory, the allocator's out-of-memory exit.  It is the ONE route from the regex roads to a collection entry (rx_alloc0 -> rt_wsb_alloc -> rt_gcheap_alloc ->
             rt_heap_out_of_memory -> the error and SETEXIT machinery -> try_call_builtin_by_name -> rt_gc_collect), and it never returns into the allocator's caller: its only call
             site (gc_heap.c) is followed by abort(), and the function itself ends in exit(1).  The error it raises ABANDONS the regex call; nothing after reads the graph.  The cut
             is therefore the declared no-return edge, checked in the source on every run (a call site that is not followed by abort() reads RED), and its body (and .cold part) is
             dropped from the disassembly before the reverse reach.
THE DAY IT TURNS RED.  A regex road reaches a safe point the day rx.c or an RxEnv callback calls (directly, by tail jump or through a GOT slot) anything whose call graph reaches a
collection entry or a dispatcher, other than across the cut: a callback that evaluates a rule body through the dispatcher, a fold or prop hook that allocates a collected block and
polls, a regex capture that builds a heap string by a polling runtime call.  From that day a collection can find the regex graph mid-build with no root holding it, and the
TRANSIENT rows must become typed rows with a validator row.
THE LIMIT.  A call graph sees direct calls, tail jumps and GOT slots.  An indirect call is followed only through the roots above (every rx.c symbol, the callbacks the source scan
names).  A function pointer stored into an RxEnv by a form the scan does not read is REFUSED (an initializer), and one stored anywhere else and called from outside rx.c is invisible.
rc 0 no root reaches a safe point; rc 1 one does (or the cut is not a no-return); rc 2 could not measure (no .so, a named function gone, fewer roots than --min-roots: a blind instrument
reads zero too, so it refuses instead)."""
import argparse, collections, importlib.util, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
SAFE = ("gc_collect_ex", "rt_gc_collect", "try_call_builtin_by_name", "rt_call_arr_impl", "gc_point_arr_run", "rt_gc_poll_slow", "rt_gc_poll_asm", "rt_gc_poll", "gc_collect_ex_c", "rt_gc_collect_c")
CUT = "rt_heap_out_of_memory"
HDR = re.compile(r"^[0-9a-f]+ <([^>]+)>:$")
ASSIGN = re.compile(r"(?:->|\.)(rule|fold|prop)\s*=\s*([A-Za-z_]\w*)\s*;")
INIT = re.compile(r"\bRxEnv\s+\w+\s*=")


def load_census():
    spec = importlib.util.spec_from_file_location("gc_census", os.path.join(HERE, "util_gc_census.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def refuse(msg):
    print(f"REFUSED(2): {msg}")
    sys.exit(2)


def drop_bodies(txt, cut):
    if not cut:
        return txt
    out, skip = [], False
    for ln in txt.split("\n"):
        m = HDR.match(ln)
        if m:
            nm = m.group(1)
            skip = nm == cut or nm.startswith(cut + ".")
            out.append(ln)
        elif not skip:
            out.append(ln)
    return "\n".join(out)


def rx_symbols(so, src):
    try:
        txt = subprocess.run(["readelf", "-sW", so], capture_output=True, text=True, errors="replace", check=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        refuse(f"readelf -s on {so} failed: {e}")
    cur, locs = None, set()
    for ln in txt.splitlines():
        f = ln.split()
        if len(f) < 8 or not f[0].endswith(":"):
            continue
        if f[3] == "FILE":
            cur = f[7]
        elif f[3] == "FUNC" and f[4] == "LOCAL" and cur == "rx.c":
            locs.add(f[7])
    glob = set()
    try:
        for ln in open(os.path.join(src, "runtime", "rx.c"), encoding="utf-8", errors="replace"):
            if ln[:1].isspace() or re.match(r"(static\b|typedef\b|#|enum\b|struct\b|union\b|/|\}|$)", ln) or not re.search(r"\)\s*\{", ln):
                continue
            m = re.match(r"[^(]*?\b([A-Za-z_]\w*)\s*\(", ln)
            if m:
                glob.add(m.group(1))
    except OSError as e:
        refuse(f"cannot read rx.c: {e}")
    return sorted(locs | glob)


def host_callbacks(src):
    names, inits = set(), []
    base = os.path.join(src, "runtime")
    for dp, _dn, fns in os.walk(base):
        for fn in fns:
            if not fn.endswith((".c", ".h", ".inc")) or fn in ("rx.c", "rx.h"):
                continue
            p = os.path.join(dp, fn)
            try:
                t = open(p, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if "RxEnv" not in t:
                continue
            for _f, ident in ASSIGN.findall(t):
                if ident not in ("NULL", "0"):
                    names.add(ident)
            if INIT.search(t):
                inits.append(p)
    return names, inits


def cut_is_no_return(src, cut):
    bad = []
    pat = re.compile(r"(?<![\w])" + re.escape(cut) + r"\s*\(")
    for dp, _dn, fns in os.walk(os.path.join(src, "runtime")):
        for fn in fns:
            if not fn.endswith(".c"):
                continue
            p = os.path.join(dp, fn)
            t = open(p, encoding="utf-8", errors="replace").read()
            for m in pat.finditer(t):
                head = t[max(0, m.start() - 20):m.start()]
                if re.search(r"\bvoid\s+$", head):
                    continue
                end = t.find(";", m.end())
                rest = t[end + 1:end + 80] if end >= 0 else ""
                if not re.match(r"\s*(\}\s*)*abort\s*\(\s*\)\s*;", rest):
                    bad.append(f"{fn}:{t.count(chr(10), 0, m.start()) + 1}")
    return bad


SYN = "__safe_points__"


def reach(txt, got, census, roots, safe):
    syn = "\n0000000000000000 <" + SYN + ">:\n       0:\tret\n" + "".join(f"\n0000000000000000 <{s}>:\n       0:\tcall   0 <{SYN}>\n" for s in safe)
    seen, funcs = census._alloc_reach_from_disasm(txt + syn, seed=SYN, got=got)
    names = set(re.findall(r"^[0-9a-f]+ <([^>]+)>:$", txt, re.M))
    defined = names.__contains__
    for s in safe:
        if not defined(s):
            refuse(f"the safe point {s} is not defined in the disassembly (renamed? tell this instrument)")
    for r in roots:
        if not defined(r):
            refuse(f"the root {r} is not defined in the disassembly")
    hits = [r for r in roots if r in seen and r not in safe]
    if not hits:
        return []
    for s in safe:
        one, _f = census._alloc_reach_from_disasm(txt, seed=s, got=got)
        named = [r for r in hits if r in one]
        if named:
            return [(r, s) for r in named]
    return [(r, "a safe point") for r in hits]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--so", default=os.path.join(SCRIP, "out", "libscrip_rt.so"))
    ap.add_argument("--src", default=None, help="the source tree (default SCRIP/src; with --disasm only the cut call-site check runs, and only when given)")
    ap.add_argument("--disasm", help="a fixture: objdump -d text instead of the .so (then --roots is required and no source scan is made)")
    ap.add_argument("--roots", default="")
    ap.add_argument("--safe", default=",".join(SAFE))
    ap.add_argument("--cut", default=CUT)
    ap.add_argument("--min-roots", type=int, default=20)
    a = ap.parse_args(argv)
    census = load_census()
    safe = [s for s in a.safe.split(",") if s]
    if a.disasm:
        txt = open(a.disasm, encoding="utf-8").read()
        roots = [r for r in a.roots.split(",") if r]
        got = None
        note = "fixture"
        bad = cut_is_no_return(a.src, a.cut) if a.src and a.cut else []
        if bad:
            print(f"RED the cut {a.cut} is called where abort() does not follow: {', '.join(bad)}")
            return 1
    else:
        a.src = a.src or os.path.join(SCRIP, "src")
        if not os.path.isfile(a.so):
            refuse(f"no {a.so} -- run make")
        try:
            txt = subprocess.run(["objdump", "-d", "--no-show-raw-insn", a.so], capture_output=True, text=True, errors="replace", check=True).stdout
        except (OSError, subprocess.CalledProcessError) as e:
            refuse(f"objdump on {a.so} failed: {e}")
        got = census._got_slots(a.so)
        rxs = rx_symbols(a.so, a.src)
        cbs, inits = host_callbacks(a.src)
        if inits:
            refuse(f"an RxEnv initializer form this instrument does not read: {', '.join(inits)}")
        roots = sorted(set(rxs) | cbs)
        note = f"rx.c symbols={len(rxs)} host callbacks={','.join(sorted(cbs)) or 'none'}"
        bad = cut_is_no_return(a.src, a.cut) if a.cut else []
        if bad:
            print(f"RED the cut {a.cut} is called where abort() does not follow: {', '.join(bad)}")
            return 1
    if len(roots) < a.min_roots:
        refuse(f"{len(roots)} root(s), under --min-roots {a.min_roots}: a blind instrument reads zero too")
    if a.cut and ("\n" + txt).find(" <" + a.cut + ">:\n") < 0:
        refuse(f"the cut {a.cut} is not defined in the disassembly (renamed? tell this instrument)")
    hits = reach(drop_bodies(txt, a.cut), got, census, roots, safe)
    cutsay = a.cut or "none"
    if hits:
        r, s = hits[0]
        print(f"RED a regex road reaches a safe point: {r} reaches {s} ({len(hits)} root/safe-point pair(s); {note}; cut={cutsay})")
        return 1
    print(f"transient-reach roots={len(roots)} ({note}) safe-points={len(safe)} reached=0 cut={cutsay}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as e:
        refuse(f"the instrument itself failed: {type(e).__name__}: {e}")
