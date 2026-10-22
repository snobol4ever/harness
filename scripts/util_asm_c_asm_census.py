#!/usr/bin/env python3
# util_asm_c_asm_census.py — ⛔ THE NO-ASM->C->ASM CENSUS (Lon 2026-08-20 s194, in-chat: "You must guarantee that no ASM -> C -> ASM.").
#
# WHY THE RULE EXISTS, MEASURED (FINDING-2026-08-20-s194c): the Byrd wire contract puts gamma in r10 and omega in r11
# (Lon s55) while RTCC banks r10/r11 as VM globals in g_rtccb[32] (x86_asm.h:12 "R10=7, R11=8"; bank/reload at :427/:428/
# :440/:441).  g_rtccb is a FLAT GLOBAL -- one slot per register, program-wide, WITH NO NESTING.  So when emitted asm calls
# a C function and that C function re-enters asm, the INNER activation banks its wires into the SAME two slots and the
# OUTER activation's continuations are lost.  beauty's M1 SIGSEGV is exactly this: at the fault r11 = rip = &g_rtccb.
# The shape is the defect; forbidding the shape retires the whole class instead of defending against instances.
#
# WHAT IT COMPUTES: the intersection of
#   (a) C functions CALLED FROM EMITTED ASM   -- the x86("call*", ...) callees and the baked addresses of src/templates/**
#       and src/emitter/** (asm_callees)
#   (b) C functions that TRANSITIVELY REACH an asm activation entry  -- rt_proc_enter & siblings, computed (asm_entries)
# Anything in both is an ASM -> C -> ASM road.
# PRINTS one line per road (its shortest path to an asm entry), then BY_ENTRY entry=E roads=N witness=F per asm entry a
# shortest road ends at, largest class first (the cto 2026-10-09: each class is rowed with its witness), then COUNT=N.
# --roads-by-entry (the ceo 2026-10-09, for the C-to-BB removal): instead, for EVERY asm entry, every emitted callee that
# reaches THAT entry (a road reaching two entries is listed under both), as ROAD entry=E from=F path=F -> ... -> E, then
# CALLER entry=E caller=C roads=N per C function that calls E directly on those paths (the caller a removal converts or
# leaves as a bomb), then ENTRY entry=E roads=N; the selftest and COUNT are the same as the default mode's.
#
# ⛔ LIMITATIONS, STATED SO NOBODY READS THIS AS COMPLETE.  It is a STATIC, NAME-BASED call graph over src/runtime/**.c:
#   1. INDIRECT CALLS ARE INVISIBLE.  A call through a function pointer (p->fn, a dtp slot, a jump table) is not an edge
#      here.  That is a REAL hole and it is the direction the machine actually uses most, so a count of 0 from this tool
#      would NOT prove the property -- it would prove only that no NAMED road remains.
#   2. It does not model the killswitches; a road refused at runtime still counts as a road.
#   3. It parses C by regex.  It is validated on every run against a PLANTED road (SELFTEST_C / SELFTEST_CPP: a synthetic
#      asm entry, a C body that calls it, an emitted call to that body, and two decoys that only take the entry's address)
#      and REFUSES to report unless it finds the road, skips the decoys, and counts exactly one more than the tree; the
#      gate also plants two roads (--plant DIR) and requires both -- an analysis that cannot find a road put there on
#      purpose has no business grading the tree.
import re, sys, glob, os, collections, tempfile
BOGUS = {"DESCR_t","fn","code","if","for","while","switch","return","sizeof","do","else","static","extern","inline",
         "void","int","long","char","unsigned","struct","union","typedef","const","goto","case","default","break","continue"}
# ⛔ THE SELFTEST IS A PLANTED ROAD, NOT A FOUND ONE (CEO-554, CEO-1576).  It was a MEASURED road (beauty's s194 M1
# path, then the Raku APPLY of an indirect name ending at rt_proc_enter on SCRIP 7016f6e25); CEO-1576 landing 3 deleted
# rt_proc_enter and every sibling C could reach, the road ceased to exist, and an instrument anchored on its witness died
# the day the witness was cured.  The fixture below is the shape the census exists to see, written down once: an asm
# entry that jumps through a register, a one-line C body that calls it, a multi-line C body the emitter calls by name,
# and two decoys (one-line and multi-line) the emitter also calls that only DECLARE the entry in its body and returns its address -- the shape of
# rt_goto_resolve_x handing back rt_setexit_continue_tramp, which the census once read as a call and counted as 112 roads.
SELFTEST_C = (
    '__asm__(".text\\n.globl rt_zz_selftest_entry\\nrt_zz_selftest_entry:\\n  jmp *%rdi\\n");\n'
    'extern void rt_zz_selftest_entry(void *fn);\n'
    'void rt_zz_selftest_mid(void *fn) { rt_zz_selftest_entry(fn); }\n'
    'void rt_zz_selftest_road(long n) {\n'
    '    if (n) rt_zz_selftest_mid((void *)0);\n'
    '}\n'
    'void *rt_zz_selftest_decoy(void) { extern void rt_zz_selftest_entry(void *fn); return (void *)rt_zz_selftest_entry; }\n'
    'void *rt_zz_selftest_decoy_block(long n) {\n'
    '    extern void rt_zz_selftest_entry(void *fn);\n'
    '    return n ? (void *)rt_zz_selftest_entry : (void *)0;\n'
    '}\n')
SELFTEST_CPP = 'static std::string zz_selftest(void) { return x86("call", "rt_zz_selftest_road", 0) + x86("call", "rt_zz_selftest_decoy", 0) + x86("call", "rt_zz_selftest_decoy_block", 0); }\n'
SELFTEST_ROAD = ["rt_zz_selftest_road", "rt_zz_selftest_mid", "rt_zz_selftest_entry"]
DEF  = re.compile(r'^(?:static\s+|inline\s+|extern\s+)*[A-Za-z_][A-Za-z_0-9]*[ \*]+\**([A-Za-z_][A-Za-z_0-9]*)\s*\(')
CALL = re.compile(r'\b([A-Za-z_][A-Za-z_0-9]*)\s*\(')
# NO LEADING WHITESPACE: a forward declaration in this tree sits at COLUMN 0; a body statement is indented.  The first
# cut allowed leading space and therefore ate `    return rt_proc_enter(...);` -- caught by the selftest, which is what
# the selftest is for.
PROTO = re.compile(r'^(?:extern\s+)?[A-Za-z_][A-Za-z_0-9 \*]*\**[A-Za-z_][A-Za-z_0-9]*\s*\([^;{]*\)\s*;\s*$')
STRLIT = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
# ⛔ A BLOCK-SCOPE DECLARATION IS NOT A CALL.  `{ extern void rt_setexit_continue_tramp(void); return (void *)rt_setexit_continue_tramp; }`
# names the trampoline to take its address; read as a call it manufactured 112 roads through rt_goto_resolve_x (CEO-1576).
LOCALDECL = re.compile(r'\bextern\s+[A-Za-z_][A-Za-z_0-9 \*]*?\**\s*[A-Za-z_][A-Za-z_0-9]*\s*\([^;{}()]*\)\s*;')
INDIRECT = re.compile(r'\b(?:jmp|call)q?\s+\*')
def asm_entries(root, plants=()):
    """⛔ THE ASM ACTIVATION ENTRIES ARE COMPUTED, NOT TYPED (CEO-1573).  The typed set had fallen behind the code:
    rt_proc_enter_named, rt_proc_enter_frag, rt_genp_spine_enter_n2 and rt_tiny_glue_enter all enter emitted code and
    none was in it.  An entry is a global symbol DEFINED IN ASM -- a .globl inside an __asm__ block of a C file under
    src/runtime or src/driver, or a .globl / RTX_FUNC / RTX_ENTRY region of a .s/.S file under src/runtime -- whose own
    text jumps or calls THROUGH A REGISTER OR MEMORY (jmp *, call *): that indirect transfer is the step into emitted
    code.  An asm leaf that only calls named C is not an entry."""
    out = set()
    cs = glob.glob(os.path.join(root,'src/runtime/**/*.c'), recursive=True) + glob.glob(os.path.join(root,'src/driver/**/*.c'), recursive=True)
    cs += [f for d in plants for f in sorted(glob.glob(os.path.join(d,'*.c')))]
    for path in cs:
        txt = open(path, encoding='utf-8', errors='ignore').read()
        for m in re.finditer(r'__asm__\s*\((.*?)\)\s*;', txt, re.S):
            body = m.group(1)
            if INDIRECT.search(body): out |= set(re.findall(r'\.globl\s+([A-Za-z_][A-Za-z_0-9]*)', body))
    ss = [f for e in ('s','S') for f in glob.glob(os.path.join(root,'src/runtime/**/*.'+e), recursive=True)]
    opener = re.compile(r'^\s*(?:\.globl\s+([A-Za-z_][A-Za-z_0-9]*)|RTX_(?:FUNC|ENTRY)\s*\(\s*([A-Za-z_][A-Za-z_0-9]*))')
    for path in ss:
        cur = None
        for line in open(path, encoding='utf-8', errors='ignore'):
            m = opener.match(line)
            if m: cur = m.group(1) or m.group(2); continue
            if cur and INDIRECT.search(line): out.add(cur)
    return out
def build(root, entries, plants=()):
    """⛔ BODIES ARE BRACE-BOUNDED, NOT 'UNTIL THE NEXT DEFINITION'.  The naive form absorbed everything after a
    function -- including the forward declaration `DESCR_t rt_proc_enter(void *fn);` and the __asm__ string blocks --
    and manufactured an edge rt_proc_call_epilogue_ret -> rt_proc_enter that DOES NOT EXIST (its real body calls only
    rt_proc_call_epilogue_omega/gamma).  That single fake edge sat on 18 of 26 reported roads.  This codebase writes
    `}` at column 0 with zero blank lines, so the closing brace is a reliable terminator."""
    bodies = collections.defaultdict(list)
    for path in sorted(glob.glob(os.path.join(root,'src/runtime/**/*.c'), recursive=True)) + [f for d in plants for f in sorted(glob.glob(os.path.join(d,'*.c')))]:
        cur = None
        for line in open(path, encoding='utf-8', errors='ignore'):
            if cur is not None:
                if line.startswith('}'): cur = None; continue
                if not PROTO.match(line) and not line.lstrip().startswith('"'): bodies[cur].append(LOCALDECL.sub('', STRLIT.sub('""', line)))
                continue
            m = DEF.match(line)
            if not m or m.group(1) in BOGUS: continue
            head = line.rstrip()
            if '{' in head and head.endswith('}'):
                bodies[m.group(1)].append(LOCALDECL.sub('', STRLIT.sub('""', head[head.index('{') + 1:])))
            elif ';' not in head and head.endswith(('{',')')):
                cur = m.group(1); bodies[cur]  # touch so a body-less definition still registers
    g = {f: {c for ln in b for c in CALL.findall(ln)} - BOGUS for f,b in bodies.items()}
    known = set(g) | entries
    return {f: (cs & known) for f,cs in g.items()}
def asm_callees(root, plants=()):
    """The callee of every x86("call*", ...) the emitter and the templates write: EVERY identifier literal in the
    call's second argument, so `cond ? "a" : "b"` names both.  The templates live in subdirectories (src/templates/bb,
    x86, xa) and the emitter writes calls too; the old flat glob over src/templates/*.cpp matched no file at all.
    A C function whose ADDRESS the emitter bakes into emitted code is reached from asm as well, whatever helper writes
    the instruction (bb_glue_try_enter("rt_call_arr_bl_try", (uint64_t)(uintptr_t)(void *)rt_call_arr_bl_try, ...)):
    every `(void *)NAME` and `TEMPLATE_FN_ADDR(NAME)` there is a callee too."""
    out = set()
    srcs = [f for d in ('src/templates','src/emitter') for e in ('cpp','h') for f in glob.glob(os.path.join(root,d,'**','*.'+e), recursive=True)]
    srcs += [f for d in plants for f in sorted(glob.glob(os.path.join(d,'*.cpp')))]
    for p in srcs:
        txt = open(p, encoding='utf-8', errors='ignore').read()
        for m in re.finditer(r'x86\(\s*"call[^"]*"\s*,', txt):
            i, depth, arg = m.end(), 0, []
            while i < len(txt):
                c = txt[i]
                if c == '"':
                    j = STRLIT.match(txt, i)
                    if not j: break
                    arg.append(j.group(0)); i = j.end(); continue
                if c in '([{': depth += 1
                elif c in ')]}':
                    if depth == 0: break
                    depth -= 1
                elif c in ',;' and depth == 0: break
                i += 1
            out |= {a[1:-1] for a in arg if re.fullmatch(r'"[A-Za-z_][A-Za-z_0-9]*"', a)}
        out |= set(re.findall(r'\(\s*void\s*\*\s*\)\s*([A-Za-z_][A-Za-z_0-9]*)\b(?!\s*[(\[.]|\s*->)', txt))
        out |= set(re.findall(r'TEMPLATE_FN_ADDR\(\s*([A-Za-z_][A-Za-z_0-9]*)\s*\)', txt))
    return out
def main():
    root = os.environ.get('S4E_SCRIP') or os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
    args = sys.argv[1:]
    per_entry = '--roads-by-entry' in args
    args = [a for a in args if a != '--roads-by-entry']
    plant = args[1] if len(args) == 2 and args[0] == '--plant' else None
    if args and not (plant and os.path.isdir(plant)):
        print("usage: util_asm_c_asm_census.py [--roads-by-entry] [--plant DIR]  (DIR's *.c read as runtime C, its *.cpp as emitter source)")
        return 2
    def analyse(plants):
        entries = asm_entries(root, plants)
        g = build(root, entries, plants)
        callees = asm_callees(root, plants)
        reach, ch = {f for f in g if g[f] & entries}, True
        while ch:
            ch = False
            for f,cs in g.items():
                if f not in reach and (cs & reach): reach.add(f); ch = True
        return entries, g, callees, reach, sorted(callees & set(g) & reach)
    entries, g, callees, reach, bad = analyse((plant,) if plant else ())
    with tempfile.TemporaryDirectory() as fx:
        open(os.path.join(fx, 'zz_selftest.c'), 'w').write(SELFTEST_C)
        open(os.path.join(fx, 'zz_selftest.cpp'), 'w').write(SELFTEST_CPP)
        s_entries, s_g, _, _, s_bad = analyse((fx,) + ((plant,) if plant else ()))
    missing = [a+" -> "+b for a,b in zip(SELFTEST_ROAD, SELFTEST_ROAD[1:]) if b not in s_g.get(a,())]
    if SELFTEST_ROAD[-1] not in s_entries: missing.append(SELFTEST_ROAD[-1] + " is not an asm entry")
    if SELFTEST_ROAD[0] not in s_bad: missing.append("the planted road " + SELFTEST_ROAD[0] + " is not reported")
    for d in ("rt_zz_selftest_decoy", "rt_zz_selftest_decoy_block"):
        if d in s_bad: missing.append("the decoy %s, which only takes the entry's address, is reported as a road" % d)
    if len(s_bad) != len(bad) + 1: missing.append("the planted fixture moved the count by %d, not 1" % (len(s_bad) - len(bad)))
    if missing:
        print("⛔ SELFTEST FAILED — the census cannot find the PLANTED road; refusing to report.")
        for m in missing: print("   MISSING EDGE:", m)
        return 3
    def path(f, goal=None, through=None):
        goal, through = goal or entries, through or reach
        prev, q = {f: None}, collections.deque([f])
        while q:
            u = q.popleft()
            for c in sorted(g.get(u, ())):
                if c in prev: continue
                prev[c] = u
                if c in goal:
                    p = [c]
                    while prev[p[-1]] is not None: p.append(prev[p[-1]])
                    return p[::-1]
                if c in through: q.append(c)
        return None
    print("=== NO-ASM->C->ASM CENSUS (selftest OK: the planted road is found and its decoys are not) ===")
    print("    C functions parsed %d · asm entries %d · reaching an asm entry %d · called from emitted asm %d" %
          (len(g), len(entries), len(reach), len(callees)))
    print("    ASM -> C -> ASM roads: %d" % len(bad))
    if per_entry:
        for e in sorted(entries):
            re_, ch = {f for f in g if e in g[f]}, True
            while ch:
                ch = False
                for f,cs in g.items():
                    if f not in re_ and (cs & re_): re_.add(f); ch = True
            roads = sorted(callees & set(g) & re_)
            if not roads: continue
            callers = collections.Counter()
            for f in roads:
                p = path(f, {e}, re_)
                print("ROAD entry=%s from=%s path=%s" % (e, f, " -> ".join(p) if p else "?"))
                if p and len(p) >= 2: callers[p[-2]] += 1
            for c, n in sorted(callers.items(), key=lambda x: (-x[1], x[0])):
                print("CALLER entry=%s caller=%s roads=%d" % (e, c, n))
            print("ENTRY entry=%s roads=%d" % (e, len(roads)))
        print("COUNT=%d" % len(bad))
        return 0
    by = collections.defaultdict(list)
    for f in bad:
        p = path(f)
        print("  ⛔ %-30s %s" % (f, " -> ".join(p) if p else "?"))
        by[p[-1] if p else "?"].append(f)
    for e in sorted(by, key=lambda e: (-len(by[e]), e)):
        print("BY_ENTRY entry=%s roads=%d witness=%s" % (e, len(by[e]), by[e][0]))
    print("COUNT=%d" % len(bad))
    return 0
if __name__ == "__main__": sys.exit(main())
