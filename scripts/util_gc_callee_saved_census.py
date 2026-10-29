#!/usr/bin/env python3
"""util_gc_callee_saved_census.py -- WHAT IS IN A CALLEE-SAVED REGISTER AT AN ALLOCATING RETURN, READ OFF THE
EMITTED CODE INSTEAD OF OFF A PARAGRAPH (cto 2026-09-18, CEO-845 row (1); design
.github/ARCH-GC-COMPILE-TIME-FRAME-MAPS.md sections 6.5 and 7 F1; law RULES.md FACT RULE THE COLLECTOR GUESSES
NOTHING, CEO-812).

THE FACT THIS INSTRUMENT EXISTS TO STOP HOLDING BY MEMORY.  Section 6.5 of the frozen design asserts, in prose,
that r13 is the ONE callee-saved register that can hold a collected-heap pointer at an allocating return and only
inside a match; that r14 and r15 are the subject CURSOR and LENGTH and therefore raw; that r12, rbx and rbp carry
a trail top, a saved RSP and a frame base.  Every one of those is a claim about EMITTED CODE, and nothing in the
tree checked any of them.  If a template ever leaves a heap pointer in r12 or r14 across an allocating call, the
collector loses a root and no gate reds.  That is the fourth instrument-shaped hole of 2026-09-18 waiting to
happen, and this census is its cure: the facts are read back out of the .s.

WHAT IT MEASURES, PER MODE-4 .s:
  (1) ALLOCATING CALL SITES.  The allocating set is DERIVED, never a hand list: every function in the runtime .so
      whose call graph reaches rt_gcheap_alloc (util_gc_census.allocating_entries_from_binary, the coo's
      derivation, imported rather than copied).  A call to one of those is a safe point's return.
  (2) LIVE ACROSS.  A real backward liveness over a CFG built from the file's labels and branches, not a forward
      window: a register is live across a call if some path from the call reads it before writing it.  Unknown
      branch targets, indirect jumps and ret are TOP (all six callee-saved registers live), so the analysis
      over-approximates liveness -- the safe direction for a question whose wrong answer is a lost root.
  (2b) OWNED vs PASSED THROUGH.  Live-across alone is nearly vacuous: the SysV contract makes every callee-saved
      register live at every ret, so a register this graph never touches reads as live across every call in it.
      The census therefore splits each live-across reading by whether a definition of that register REACHES the
      call from inside the emitted code.  OWNED means this graph put the value there and must be able to name it.
      PASSED THROUGH means the value is an ancestor's, still sitting in the register because nothing here wrote
      it -- so it is the ANCESTOR's frame that must name it, and no map of THIS graph can.
  (3) WHAT IT HOLDS.  For each OWNED live-across register the census walks back to its reaching definitions and
      classifies each by the FORM of the defining instruction, against a whitelist of forms that provably cannot
      leave a collected-heap pointer in the register:
      PROVABLY NOT A POINTER -- the form itself settles it, no other fact needed:
        RSP      mov <r>, rsp                       a stack address; the heap is not the stack
        IMM      mov <r>, <imm> / movabs / xor r,r  a constant
        D32      mov <r>d, ... / movsxd / movzx     a 32-bit define ZERO-EXTENDS: a 64-bit pointer cannot survive it
        RIP      lea <r>, [rip + <label>]           static data or code beside the program, never the heap
      A COPY OF SOMETHING ELSE -- the form settles NOTHING and the census refuses to call it raw:
        CELL     mov <r>, qword ptr [...]           a copy of a frame or spine cell
        POP      pop <r>                            a copy of whatever the matching push put on the stack
        REG      mov <r>, <other reg>               a copy of another register
        ARITH    add/sub/and/or/inc/dec <r>, ...    a value derived from one of the above
      ⛔ THE REASON THIS SPLIT IS THE POINT OF THE INSTRUMENT: a cell's own DESCR tag is the truth about the CELL,
      and it does not travel to the register.  If the cell holds a collected-heap pointer and the emitted code
      copies it into r12 before an allocating call, the collector can relocate the block, fix up the cell, and
      leave the register pointing at the old address.  "It came from a tagged cell" is therefore NOT an argument
      that the register is raw -- it is the argument that the register needs a tag OF ITS OWN at the site.
      HEAP:
        SUBJECT  mov r13, rax after a call to rt_match_enter, rt_scan_enter, rt_scan_reenter or rt_scan_reenter_live
                 (the SET, cfo CFO-149)  the one collected-heap pointer section 6.5 names by hand
      AND ITS SIBLING, PROVABLY NOT A POINTER BY THE SAME EVIDENCE (cto 2026-09-18, section 6.5c):
        LENGTH   mov <r>, rdx after a call to the same SET  the SECOND half of the ScanSubjRegs pair that call
                 returns -- gen_runtime.h declares it `uint64_t len`, the same declaration that makes the rax half
                 SUBJECT.  This form is how the DEFERRED pattern blobs seed r15, and it is NOT the 32-bit seeding
                 section 6.5a measured on the seven hermetic witnesses: that population carries no deferred
                 pattern, so a 64-bit `mov r15, rdx` read UNCLASSIFIED there and the gap was invisible.
      Anything else is UNCLASSIFIED: the census names it by site rather than guessing a class, and an
      UNCLASSIFIED reading is the census working, not the census failing.
  (4) SITE-DEPENDENCE.  For each graph, whether a register's live-across status is the SAME at every allocating
      call site of that graph.  This is the measurement that decides where the register facts belong: a fact that
      varies between two sites of one graph CANNOT be carried by a per-graph map without the map lying at one of
      them, and section 6.3's map is one per graph.

USAGE: util_gc_callee_saved_census.py <file.s>...    |    --corpus [--limit N]    |    --selftest
"""
import os, re, sys, subprocess, importlib.util
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")

CS = ("rbx", "rbp", "r12", "r13", "r14", "r15")
ALIAS = {}
for _r in CS:
    ALIAS[_r] = _r
for _a, _r in (("ebx", "rbx"), ("bx", "rbx"), ("bl", "rbx"), ("bh", "rbx"),
               ("ebp", "rbp"), ("bp", "rbp"), ("bpl", "rbp")):
    ALIAS[_a] = _r
for _r in ("r12", "r13", "r14", "r15"):
    for _s in ("d", "w", "b"):
        ALIAS[_r + _s] = _r
NARROW = set(a for a, r in ALIAS.items() if a != r)

SUBJECT_SEEDS = ("rt_match_enter", "rt_scan_enter", "rt_scan_reenter", "rt_scan_reenter_live")
def _rtx_twins():
    """\u26d4 A SEED'S REGISTERED C TWIN IS THE SEED (hq_collector 2026-10-14, row gc-blocking-gate-spill-record-red-arm-3-...-ceo-1697,
    measured on the spill-record gate's deferred witness at SCRIP ff95bdb59): since the rtx verdict road (a3e8864e0) a match
    opens as `call qword ptr [rip + rt_match_enter@GOTPCREL]; cmp rax, -1; jne L; call c_rt_match_enter@PLT; L:` -- the asm
    leaf answers -1 to hand the C twin the case it does not take -- and the walk back from the seeding `mov r13, rax` meets
    the twin's call first, so every subject seeding read a copy, the heap tally read 0 and arm 3 of the gate reddened on a
    tree where the class is present. The twin is NOT a prefix match (the planted rt_scan_enter_shadow stays refused): it is
    the exact pair src/templates/x86/rtx_twin_table.inc declares, RTX_TWIN(class, ret, leaf, c_leaf, args), read here once;
    a tree without the table reads as before."""
    tw = {}
    try:
        for ln in open(os.path.join(ROOT, "src", "templates", "x86", "rtx_twin_table.inc")):
            m = re.match(r'\s*RTX_TWIN\(\s*\w+\s*,\s*[^,]+,\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*,', ln)
            if m: tw[m.group(2)] = m.group(1)
    except OSError: pass
    return tw
RTX_TWIN_OF = _rtx_twins()
_RET_ALIAS = {"rax": ("rax", "eax", "ax", "al", "ah"), "rdx": ("rdx", "edx", "dx", "dl", "dh")}
def _call_target(text):
    """the callee of a call in EITHER spelling the emitter uses (cto 2026-09-24, the seventeen-red row): `call SYM@PLT`
    and `call SYM` for a C entry, and since af1d0e856 `call qword ptr [rip + SYM@GOTPCREL]` for every entry into the
    asm runtime -- rt_match_enter among them, so the old regex read the token `qword`, no seeding matched, 13 SNOBOL4
    subject seedings read UNCLASSIFIED and the heap tally read 0 on a tree where the class it exists to hold is present."""
    m = re.search(r"call\s+qword\s+ptr\s+\[\s*rip\s*\+\s*([A-Za-z_][A-Za-z0-9_]*)@GOTPCREL\s*\]", text)
    if m: return m.group(1)
    m = re.search(r"call\s+([A-Za-z_][A-Za-z0-9_]*)", text)
    return m.group(1) if m else None
def _defines_ret(ins, r):
    """does this instruction WRITE the return register r (rax or rdx)? use_def() is restricted to the six callee-saved
    registers on purpose, so the return pair needs its own reader: a call writes both, cqo/cdq write rdx, a read-only
    form writes nothing, and any two-operand form whose FIRST operand is the register or one of its narrow aliases
    writes it (a store of edx into memory is a read of edx, not a write)."""
    mn = ins.mnem
    if mn == "call": return True
    if mn in ("cqo", "cdq"): return r == "rdx"
    if mn in READ_ONLY or JCC.match(mn) or not ins.ops: return False
    return ins.ops[0].strip() in _RET_ALIAS[r]
def _return_seed(insns, i, r, hops=0):
    """\u26d4 THE SEED IS FOUND BY ROUTE, NOT BY A WINDOW (cfo CFO-149, 2026-09-23, measured on concord.icn.s graph
    n16_scan_enter_alpha): between `call rt_scan_enter` and `mov r13, rax` sit four g_rtccb reloads, the spill of rax and
    rdx into the poll's record, the poll, four more reloads, the two reloads out of the record, add rsp 32 and test
    rax -- fourteen instructions, never the two the old window looked back over, which is why 13 SNOBOL4 seedings
    read SUBJECT and 270 Icon seedings of the SAME ScanSubjRegs pair read UNCLASSIFIED. So: walk back from i to the
    nearest instruction that WRITES r. A call is the seed and its callee name is returned. A reload out of a stack
    slot sends the walk to the nearest store INTO that same slot above it and on to the writer of the register that
    store took, which is cell_class's see-through-the-record applied to the return pair. A change to rsp between the
    store and the reload, any other writer, or a walk deeper than three records ends the route (None): unclassified
    is the census working. The match is the whole call token, so rt_scan_enter_anything is not a seeding."""
    if hops > 3: return None
    for k in range(i - 1, max(-1, i - 80), -1):
        ins = insns[k]
        if ins.mnem == "call": return RTX_TWIN_OF.get(_call_target(ins.text), _call_target(ins.text))
        if not _defines_ret(ins, r): continue
        if ins.mnem == "pop" and ins.ops and ins.ops[0].strip() == r: return _pushed_seed(insns, k, r, hops)
        if ins.mnem == "mov" and len(ins.ops) == 2 and "[" in ins.ops[1]:
            key = slot_key(ins.ops[1])
            if key is None: return None
            for j in range(k - 1, max(-1, k - 80), -1):
                sj = insns[j]
                if sj.mnem in ("add", "sub") and sj.ops and sj.ops[0].strip() == key[0]: return None
                if sj.mnem == "mov" and len(sj.ops) == 2 and slot_key(sj.ops[0]) == key:
                    src = sj.ops[1].strip()
                    for r2, al in _RET_ALIAS.items():
                        if src in al: return _return_seed(insns, j, r2, hops + 1)
                    return None
            return None
        return None
    return None
"""----------------------------------------------------------------------------------------------------------"""
def _pushed_seed(insns, k, r, hops):
    """\u26d4 A POP IS THE PUSH IT BALANCES (cto 2026-09-25, the seventeen-red row, measured on the callee-saved gate's
    deferred witness): since af773a80e every poll site tests g_gc_pending in line, so between `call rt_match_enter` and
    `mov r13, rax` sit `push rax`, the load and test of the flag that clobber eax, `pop rax` and `je 1f`; the walk met
    the pop as a writer of rax and ended, the five subject seedings of LEN/ANY/SPAN/BREAK/TAB read UNCLASSIFIED and the
    heap tally read 0 on a tree where the class is present. So: from the pop, walk back to the push it balances (pushes
    and pops between it counted), and continue from that push with the register it saved. A call, or any other write to
    rsp between the two, ends the route (None), and so does a push of anything but the return pair."""
    depth = 0
    for j in range(k - 1, max(-1, k - 40), -1):
        sj = insns[j]
        if sj.mnem == "call": return None
        if sj.mnem == "pop": depth += 1; continue
        if sj.mnem == "push":
            if depth: depth -= 1; continue
            src = sj.ops[0].strip() if sj.ops else ""
            return _return_seed(insns, j, src, hops + 1) if src in _RET_ALIAS else None
        if sj.ops and sj.ops[0].strip() == "rsp": return None
    return None
def allocating_entries(so):
    spec = importlib.util.spec_from_file_location("_gc_census", os.path.join(HERE, "util_gc_census.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.allocating_entries_from_binary(so, out=lambda *a, **k: None)
"""----------------------------------------------------------------------------------------------------------"""
class Insn:
    __slots__ = ("line", "text", "mnem", "ops", "labels", "note")
    def __init__(self, line, text, labels, note=""):
        self.line = line; self.text = text; self.labels = labels; self.note = note
        t = text.split(None, 1)
        self.mnem = t[0].lower()
        self.ops = split_ops(t[1]) if len(t) > 1 else []

def split_ops(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "[": depth += 1
        elif ch == "]": depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip()); cur = ""
        else:
            cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def split_stmts(line):
    """GNU as takes ';' as a statement separator, and the emitter uses it to put a jcc beside its cmp. It is NOT a
    separator inside a string literal -- and a Prolog program has graphs named ';/2', whose .string would otherwise
    be sawn in half and the tail parsed as an instruction with a mnemonic of '/2\"'. Measured: that is exactly what
    happened before this splitter learned about quotes."""
    out, cur, q = [], "", False
    for ch in line:
        if ch == '"': q = not q
        if ch == ";" and not q:
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return out

LABEL_RE = re.compile(r'^([.\w$]+):')
def parse(path):
    """statements in order, each carrying the labels that immediately precede it"""
    insns, pending, in_text = [], [], True
    for ln, raw in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
        s, _hash, note = raw.partition("#")
        if not s.strip(): continue
        for part in split_stmts(s):
            p = part.strip()
            while p:
                m = LABEL_RE.match(p)
                if not m: break
                pending.append(m.group(1)); p = p[m.end():].strip()
            if not p: continue
            if p.startswith("."):
                d = p.split(None, 1)[0].lower()
                if d in (".text",): in_text = True
                elif d in (".section", ".data", ".rodata", ".bss"):
                    in_text = ".text" in p
                continue
            if not in_text: continue
            insns.append(Insn(ln, p, tuple(pending), note.strip())); pending = []; note = ""
    return insns
"""----------------------------------------------------------------------------------------------------------"""
MEM_RE = re.compile(r'\[([^\]]*)\]')
def regs_in_mem(op):
    out = set()
    for m in MEM_RE.findall(op):
        for tok in re.findall(r'\b([a-z][a-z0-9]{1,4})\b', m):
            if tok in ALIAS: out.add(ALIAS[tok])
    return out

def reg_of(op):
    o = op.strip()
    return ALIAS.get(o) if o in ALIAS else None

JCC = re.compile(r'^j(mp|e|ne|z|nz|g|ge|l|le|a|ae|b|be|s|ns|o|no|p|np|c|nc)$')
TWO_OP_RMW = {"add", "sub", "and", "or", "xor", "imul", "sar", "shl", "shr", "adc", "sbb", "lea", "movsxd", "movsx", "movzx", "mov", "cvtsi2sd", "cvtsi2ss", "movq", "movd", "movabs", "cmovne", "cmove", "cmovg", "cmovl"}
READ_ONLY = {"cmp", "test", "cmp64", "push", "ucomisd", "comisd"}
NO_GPR = {"addsd", "subsd", "mulsd", "divsd", "sqrtsd", "xorps", "xorpd", "pxor", "cvttsd2si", "cvtsd2ss", "cvtss2sd", "ret", "leave", "ud2", "nop", "cqo", "cdq", "cld", "std", "sete", "setne", "setg", "setl", "setge", "setle", "seta", "setb", "int3", "hlt", "syscall", "pause", "endbr64"}

def use_def(ins):
    """(uses, defs) restricted to the six callee-saved registers, plus a flag for 'this form is understood'"""
    mn, ops = ins.mnem, ins.ops
    uses, defs = set(), set()
    if mn == "call":
        return uses, defs, True
    if JCC.match(mn):
        for o in ops:
            r = reg_of(o)
            if r: uses.add(r)
            uses |= regs_in_mem(o)
        return uses, defs, True
    if mn == "pop":
        r = reg_of(ops[0]) if ops else None
        if r: defs.add(r)
        else: uses |= regs_in_mem(ops[0]) if ops else set()
        return uses, defs, True
    if mn in NO_GPR:
        return uses, defs, True
    if mn.startswith("rep"):
        return set(CS), set(), True
    known = mn in TWO_OP_RMW or mn in READ_ONLY or mn in ("inc", "dec", "neg", "not", "idiv", "div", "mul")
    for i, o in enumerate(ops):
        r = reg_of(o)
        uses |= regs_in_mem(o)
        if r is None: continue
        if i == 0 and mn in TWO_OP_RMW:
            defs.add(r)
            if mn not in ("mov", "lea", "movsxd", "movsx", "movzx", "movabs", "movq", "movd", "cvtsi2sd", "cvtsi2ss"):
                uses.add(r)
        elif i == 0 and mn in ("inc", "dec", "neg", "not"):
            defs.add(r); uses.add(r)
        else:
            uses.add(r)
    if mn == "xor" and len(ops) == 2 and reg_of(ops[0]) and reg_of(ops[0]) == reg_of(ops[1]):
        uses.discard(reg_of(ops[0]))
    return uses, defs, known
"""----------------------------------------------------------------------------------------------------------"""
def build_cfg(insns):
    label_at = {}
    for i, ins in enumerate(insns):
        for L in ins.labels:
            label_at.setdefault(L, i)
    succ = defaultdict(list); top = set()
    for i, ins in enumerate(insns):
        mn = ins.mnem
        if mn == "ret" or mn == "ud2":
            top.add(i); continue
        if JCC.match(mn):
            tgt = ins.ops[0] if ins.ops else ""
            uncond = (mn == "jmp")
            if tgt in label_at:
                succ[i].append(label_at[tgt])
            else:
                top.add(i)
            if not uncond and i + 1 < len(insns):
                succ[i].append(i + 1)
            continue
        if i + 1 < len(insns):
            succ[i].append(i + 1)
        else:
            top.add(i)
    return succ, top, label_at

def liveness(insns, succ, top):
    """backward fixpoint; live[i] = registers live BEFORE instruction i"""
    n = len(insns)
    ud = [use_def(ins) for ins in insns]
    live = [set() for _ in range(n)]
    changed = True
    while changed:
        changed = False
        for i in range(n - 1, -1, -1):
            out = set(CS) if i in top else set()
            for s in succ[i]:
                out |= live[s]
            u, d, _ = ud[i]
            new = u | (out - d)
            if new != live[i]:
                live[i] = new; changed = True
    return live, ud
"""----------------------------------------------------------------------------------------------------------"""
CHOICE_NOTE = re.compile(r'\bpl_(choice_open|cut_barrier|fence_commit|disj_open|header_open|choice_restore) inline\b')
def _choice_word_def(insns, i, reg):
    """THE FOUR INLINE CHOICE-WORD DEFINITIONS OF r13 (hq_prolog, SCRIP 35ed4e649, ARCH-PROLOG-C-OUT-OF-THE-BOX section 2.2;
    the cto's reading of 2026-10-03: r13 is B, the youngest choice's frame-header address, a STACK address, never a heap
    pointer). The emission DECLARES each one by name in the note it carries -- choice_open `lea r13, [rsp + kt-64]`,
    cut_barrier `mov r13, qword ptr [rbp + kt-40]` (F.B0, the saved caller's B), fence_commit `mov r13, qword ptr [frame
    slot]` (the B banked at the bound), disj_open `mov r13, rcx` where rcx is `lea rcx, [rbp + kt-64]` eight instructions
    under the sequence's note; D1 (the cto, 2026-10-14) adds header_open `lea r13, [rbp + op slot]` (a disjunction's, a bound's or a
    trailed range's own header) and choice_restore `mov r13, qword ptr [rbp + op slot]` (the B that header banked) -- and this reader
    takes the declaration ONLY when the instruction has the declared SHAPE:
    a note on a different shape, or the shape without a note (arm 7's planted form), stays UNCLASSIFIED."""
    if reg != "r13": return False
    ins = insns[i]; mn = ins.mnem; ops = ins.ops
    if len(ops) != 2 or reg_of(ops[0]) != "r13": return False
    shape = (mn == "lea" and re.fullmatch(r'\[\s*(rsp|rbp)\s*[+-]\s*\d+\s*\]', ops[1].strip()) is not None) \
         or (mn == "mov" and re.fullmatch(r'qword ptr \[\s*(rsp|rbp)\s*[+-]\s*\d+\s*\]', ops[1].strip()) is not None) \
         or (mn == "mov" and ops[1].strip() == "rcx")
    if not shape: return False
    if CHOICE_NOTE.search(ins.note or ""): return True
    if mn == "mov" and ops[1].strip() == "rcx":
        rcx_writer = None
        for k in range(i - 1, max(-1, i - 10), -1):
            sj = insns[k]
            if sj.mnem in ("call", "jmp", "ret") or (sj.ops and reg_of(sj.ops[0]) == "r13" and sj.mnem not in ("cmp", "test")): return False
            if rcx_writer is None and sj.ops and sj.ops[0].strip() in ("rcx", "ecx", "cx", "cl") and sj.mnem not in ("cmp", "test", "push"): rcx_writer = sj
            if CHOICE_NOTE.search(sj.note or "") and "disj_open" in sj.note:
                return bool(rcx_writer is not None and rcx_writer.mnem == "lea" and len(rcx_writer.ops) == 2
                            and re.fullmatch(r'\[\s*(rsp|rbp)\s*[+-]\s*\d+\s*\]', rcx_writer.ops[1].strip()) is not None)
    return False

def classify_def(insns, i, reg, depth=0):
    """the form of the instruction at i that defines reg, as a class name"""
    ins = insns[i]; mn = ins.mnem; ops = ins.ops
    if _choice_word_def(insns, i, reg): return "CHOICE"
    if mn == "pop": return "POP"
    if mn == "mov" and len(ops) == 2:
        dst, src = ops[0], ops[1]
        if dst.strip() in NARROW and ALIAS.get(dst.strip()) == reg: return "D32"
        if src.strip() == "rsp": return "RSP"
        if re.fullmatch(r'-?\d+|0x[0-9a-fA-F]+', src.strip()): return "IMM"
        if src.strip() == "rax" and reg == "r13" and _return_seed(insns, i, "rax") in SUBJECT_SEEDS: return "SUBJECT"
        if src.strip() == "rdx" and _return_seed(insns, i, "rdx") in SUBJECT_SEEDS: return "LENGTH"
        if "[" in src: return cell_class(insns, i, src, reg, depth)
        if reg_of(src): return "REG"
        return "UNCLASSIFIED"
    if mn == "movabs": return "IMM"
    if mn == "lea" and len(ops) == 2:
        return "RIP" if "rip" in ops[1] else "LEA"
    if mn == "xor" and len(ops) == 2 and reg_of(ops[0]) == reg_of(ops[1]): return "IMM"
    if mn in ("add", "sub", "and", "or", "inc", "dec"): return "ARITH"
    if mn in ("movsxd", "movsx", "movzx"): return "D32"
    return "UNCLASSIFIED"

def build_pred(succ, n):
    pred = defaultdict(list)
    for a, ss in succ.items():
        for b in ss: pred[b].append(a)
    return pred

SLOT_RE = re.compile(r'\[\s*(rbp|rsp|r12|r13|r14|r15|rbx)\s*([+-]\s*-?\d+)?\s*\]')
def slot_key(operand):
    """a frame or spine slot named by base register and constant displacement, or None if it is not one"""
    m = SLOT_RE.search(operand)
    if not m: return None
    disp = (m.group(2) or "+0").replace(" ", "")
    if disp.startswith("+-"): disp = disp[1:]
    try: return (m.group(1), int(disp))
    except ValueError: return None

def cell_class(insns, i, src, reg, depth=0):
    """\u26d4 THE ROUTE MATTERS, NOT JUST THE REGISTER. A reload out of a frame slot is not evidence that the value is
    raw -- it is evidence that the value is whatever was STORED into that slot. Measured on the SNOBOL4 witness and
    this is the whole reason the step exists: bb_match_begin seeds the subject base with `mov r13, rax` after
    rt_match_enter (class SUBJECT), stores it to [rbp-16], and the match templates reload `mov r13, qword ptr
    [rbp-16]` BEFORE an allocating call. A classifier that stopped at the reload would have called the live subject
    pointer a CELL and a whitelist that trusted CELL would have blessed a collected-heap pointer sitting in a
    callee-saved register across a collection. So: find every store into that same slot inside the SAME graph and
    classify what each one stored. All agree -> CELL:<that class>. They disagree, or the slot is not a plain
    base+displacement -> plain CELL, which is NOT in the provably-raw set and says so."""
    key = slot_key(src)
    if key is None or depth > 2: return "CELL"
    g = graph_of(insns, i)
    srcs = set()
    pj = CTX["pushes"].get(key)
    if pj is not None and graph_of(insns, pj) == g:
        r2 = reg_of(insns[pj].ops[0])
        if r2 is not None:
            for k in range(pj - 1, max(-1, pj - 400), -1):
                if r2 in use_def(insns[k])[1]:
                    srcs.add(classify_def(insns, k, r2, depth + 1)); break
            else:
                srcs.add("CALLERS")
    for j in CTX["stores"].get(key, ()):
        ins = insns[j]
        if graph_of(insns, j) != g: continue
        r2 = reg_of(ins.ops[1])
        if r2 is None:
            srcs.add("CELL"); continue
        for k in range(j - 1, max(-1, j - 400), -1):
            if r2 in use_def(insns[k])[1]:
                srcs.add(classify_def(insns, k, r2, depth + 1)); break
        else:
            srcs.add("ENTRY")
    if len(srcs) == 1:
        c = srcs.pop()
        return "CELL" if c in ("CELL", "ENTRY") else "CELL:" + c
    return "CELL"

def reaching_defs(insns, pred, ud, i, reg, limit=20000):
    """walk backwards over the reverse CFG from i, collecting the first definition of reg on each path"""
    seen, out, stack, steps = set(), set(), list(pred[i]), 0
    while stack and steps < limit:
        j = stack.pop(); steps += 1
        if j in seen: continue
        seen.add(j)
        d = ud[j][1]
        if reg in d:
            out.add(classify_def(insns, j, reg))
        else:
            stack.extend(pred[j])
    if steps >= limit: out.add("TRUNCATED")
    if not out: out.add("ENTRY")
    return out
"""----------------------------------------------------------------------------------------------------------"""
CTX = {"graph_at": [], "stores": {}, "pushes": {}}
def build_ctx(insns):
    """one forward pass for graph attribution and one for the slot-store index, so the cell tracer is
    linear instead of quadratic -- at 28000 lines of Prolog the quadratic shape was the difference between two
    seconds and not finishing"""
    ga = [None] * len(insns); cur = None
    for i, ins in enumerate(insns):
        for L in ins.labels:
            if L.startswith(".L"): continue
            m = GRAPH_LBL.match(L)
            if m: cur = m.group(1)
        ga[i] = cur
    stores = defaultdict(list); pushes = {}
    for i, ins in enumerate(insns):
        if ins.mnem == "mov" and len(ins.ops) == 2:
            k = slot_key(ins.ops[0])
            if k is not None and "[" in ins.ops[0]: stores[k].append(i)
    """\u26d4 A FRAME SLOT IS ALSO WRITTEN BY A PUSH, AND THAT IS THE FORM THE MATCH REGIME USES. bb_match_begin
    emits push rbp; mov rbp, rsp; push r12; push r13; push r14; push r15 -- so [rbp-8] is the caller's r12,
    [rbp-16] the caller's r13 and so on, which the emitter's own comments spell outer_Sigma / outer_delta /
    outer_Delta. Indexing only mov-stores made every one of those reloads read as a CELL with no source, i.e. the
    tracer stopping one instruction short of the fact. The offsets this loop derives were checked against those
    emitted comments and agree slot for slot."""
    k = 0
    for i, ins in enumerate(insns):
        if ins.mnem == "mov" and len(ins.ops) == 2 and ins.ops[0] == "rbp" and ins.ops[1] == "rsp":
            k = 0; continue
        if ins.mnem == "push" and ins.ops and reg_of(ins.ops[0]):
            k += 8; pushes[("rbp", -k)] = i
        elif ins.mnem not in ("push",) and ins.mnem != "nop":
            if ins.mnem in ("call", "jmp") or JCC.match(ins.mnem): k = -10**9
    CTX["graph_at"] = ga; CTX["stores"] = stores; CTX["pushes"] = pushes

GRAPH_LBL = re.compile(r'^([A-Za-z_][\w$]*?)_(?:\u03b1|\u03c9|\u03b3|\u03b2)$')
def graph_of(insns, i):
    """The graph a site belongs to: the nearest preceding PORT label (name followed by alpha, omega, gamma or beta),
    whose name is the same name the map table carries.
    A site with no such label in front of it is UNATTRIBUTED and is EXCLUDED from the site-dependence count rather
    than folded into a catch-all bucket -- lumping two different graphs under one name would INVENT the very
    site-dependence this census is measuring, which is the wrong direction for a number that is about to decide
    where the register facts live."""
    ga = CTX["graph_at"]
    return ga[i] if i < len(ga) else None

PROVABLY_RAW = {"RSP", "IMM", "D32", "RIP", "LENGTH", "CHOICE"}
COPY = {"CELL", "POP", "REG", "ARITH", "LEA", "CALLERS"}
CELL_PREFIX = "CELL:"
HEAP = {"SUBJECT"}
def bucket(k):
    """\u26d4 PEEL EVERY CELL: PREFIX, NOT ONE (cfo 2026-09-19).  cell_class composes its class NAME recursively --
    a reload out of a slot whose store came from a register that was itself reloaded out of a slot reads
    CELL:CELL:POP -- and this bucket stripped ONE prefix, so CELL:CELL:POP left with a tail of CELL:POP that is in
    no set and fell to "unclassified".  The SUMMARY prints unclassified as len(unc), which such a reading never
    joins (census() files it in the COPY list), so two readings at rt_dcap_land_\u03b3/\u03c9 in the SNOBOL4
    witness were counted in NEITHER of the two blocking arms: not in arm 5's copy ratchet, not in arm 3's
    unclassified.  Measured, not reasoned: the copy LIST held 289 while this tally reported 287.  The nesting is
    bounded at CELL:CELL:<leaf> by classify_def's depth>2 cut, so the loop terminates at the leaf class.
    \u26d4 AND THE LISTS ARE FILED BY THIS SAME FUNCTION (cto 2026-09-23): census() kept a SECOND classification
    for the copy/unclassified/heap LISTS, which filed CELL:UNCLASSIFIED under copies while this tally bucketed it
    unclassified, and the census REFUSED on its own disagreement -- 2021 against 1732 over the 77-file corpus, on a
    clean tree, before any edit. A reload of a value nobody could classify is not a copy of something known; it is
    unclassified, and one function now says so for both routes."""
    t = k
    while t.startswith(CELL_PREFIX): t = t[len(CELL_PREFIX):]
    if t in HEAP: return "heap"
    if t in PROVABLY_RAW or t == "ENTRY": return "raw"
    if t in COPY: return "copy"
    return "unclassified"


def census(paths, alloc, out=print):
    tot_sites = 0
    live_across = defaultdict(int); owned = defaultdict(int); passed = defaultdict(int)
    classes = defaultdict(lambda: defaultdict(int))
    unclassified = []; copies = []; heapsites = []; unattributed = [0]
    per_graph = defaultdict(lambda: defaultdict(set))
    unknown_mnem = defaultdict(int)
    for path in paths:
        insns = parse(path)
        succ, top, _ = build_cfg(insns)
        build_ctx(insns)
        live, ud = liveness(insns, succ, top)
        pred = build_pred(succ, len(insns))
        for i, ins in enumerate(insns):
            if not ins.mnem.startswith("call"): continue
            m = re.match(r'^[A-Za-z_][\w.$]*', ins.ops[0]) if ins.ops else None
            if not m: continue
            fn = m.group(0).split("@")[0]
            if alloc is not None and fn not in alloc: continue
            tot_sites += 1
            g = graph_of(insns, i)
            if g is None: unattributed[0] += 1
            after = set()
            for s in succ[i]: after |= live[s]
            if i in top: after |= set(CS)
            for r in CS:
                hot = r in after
                if g is not None: per_graph[(os.path.basename(path), g)][r].add(hot)
                if not hot: continue
                live_across[r] += 1
                cls = reaching_defs(insns, pred, ud, i, r)
                if cls == {"ENTRY"}:
                    passed[r] += 1
                    continue
                owned[r] += 1
                for c in cls:
                    classes[r][c] += 1
                    # ⛔ ONE FILING RULE AND IT IS bucket() (cfo 2026-09-23).  This chain peeled ONE `CELL:` prefix
                    # while bucket() peels every one, so the LISTS and the TALLY were two rules rather than two views of
                    # one, and they disagreed on four class shapes: CELL:*:UNCLASSIFIED was filed in the COPY list while
                    # tallied as unclassified, CELL:CELL:SUBJECT filed as a copy against a HEAP tally, CELL:CELL:RSP
                    # filed as a copy against a RAW tally.  Measured on the 77-file corpus at b9ef5f056: the tally
                    # bucketed 2021 owned readings as unclassified while the LIST held 1732 -- 289 readings in NEITHER
                    # blocking arm, which is the residual-behind-a-green-gate shape the refusal in report() names.  It
                    # was never reconcilable before now because both wired gates run only the 8-witness population,
                    # where unclassified=0 and the two routes agree trivially.  Selftest arm 15-17 plant the nine-line
                    # witness that REDS on the one-prefix peel, so the rule cannot be re-split silently.
                    rec = (os.path.basename(path), g, ins.line, r, c, insns[i].text[:60])
                    b = bucket(c)
                    if   b == "heap":         heapsites.append(rec)
                    elif b == "copy":         copies.append(rec)
                    elif b == "unclassified": unclassified.append(rec)
        for ins in insns:
            _, _, known = use_def(ins)
            if not known: unknown_mnem[ins.mnem] += 1
    return tot_sites, live_across, owned, passed, classes, unclassified, copies, heapsites, per_graph, unknown_mnem, unattributed[0]
"""----------------------------------------------------------------------------------------------------------"""
def report(paths, alloc, out=print):
    tot, la, owned, passed, classes, unc, cop, heaps, per_graph, unknown, unattr = census(paths, alloc, out)
    out(f"CALLEE-SAVED CENSUS files={len(paths)} allocating_call_sites={tot}")
    if unknown:
        out("  ⛔ UNDERSTOOD=NO for these mnemonics (the census REFUSES rather than assume they leave the six registers alone): "
            + " ".join(f"{k}={v}" for k, v in sorted(unknown.items())))
    for r in CS:
        cs = classes.get(r, {})
        detail = " ".join(f"{k}={v}" for k, v in sorted(cs.items())) or "-"
        out(f"  {r}: live_across={la.get(r,0)}/{tot} (owned={owned.get(r,0)} passed_through={passed.get(r,0)})  owned_def_classes: {detail}")
    tally = defaultdict(int)
    for r in CS:
        for k, v in classes.get(r, {}).items(): tally[bucket(k)] += v
    raw_n, copy_n, heap_n = tally["raw"], tally["copy"], tally["heap"]
    out(f"  OWNED READINGS BY WHAT THE ROUTE SETTLES: provably_not_a_pointer={raw_n}  a_copy_of_something_else={copy_n}  "
        f"A_COLLECTED_HEAP_POINTER={heap_n}  unclassified={len(unc)}")
    if heap_n:
        out(f"  \u26d4 {heap_n} OWNED reading(s) ARE A COLLECTED-HEAP POINTER SITTING IN A CALLEE-SAVED REGISTER ACROSS AN "
            f"ALLOCATING RETURN. Section 6.5 names r13 (the subject base) as the one register this can happen to, and the "
            f"census confirms the register while correcting the ROUTE: the pointer does not arrive by the seeding "
            f"mov r13, rax after rt_match_enter -- that one is dead across every allocating call -- it arrives by a RELOAD "
            f"out of the frame cell the match stashed it in. A classifier that stopped at the reload would have called it "
            f"a CELL and a whitelist that trusted CELL would have blessed it. Nothing collects through a map yet, so this "
            f"cannot bite today; it is the exact residual the spill record of section 6.5 exists to carry.")
        by = defaultdict(int)
        for c in heaps: by[(c[3], c[4])] += 1
        out("      " + "  ".join(f"{r}/{k}={v}" for (r, k), v in sorted(by.items())))
        # EVERY heap site is printed, never a sample: the spill-record gate reads this list as its COVERAGE
        # population, and a truncated list would let it report full coverage over four of five sites (cto 6.5c).
        for h in heaps:
            out(f"      {h[0]} graph={h[1]} line={h[2]} {h[3]}  [{h[5]}]")
    if copy_n:
        out(f"  ⛔ {copy_n} OWNED reading(s) are A COPY OF SOMETHING ELSE, and that is the residual this census exists "
            f"to name: the source cell's DESCR tag is the truth about the CELL and it does not travel to the register, so "
            f"if the source holds a collected-heap pointer the collector can relocate the block, fix up the cell, and leave "
            f"the register pointing at the old address. A per-graph map cannot tag these; only the site can.")
        by = defaultdict(int)
        for c in cop: by[(c[3], c[4])] += 1
        out("      " + "  ".join(f"{r}/{k}={v}" for (r, k), v in sorted(by.items())))
        # \u26d4 NAMED BY FILE AND GRAPH, because a residual nobody can attribute is a residual nobody cures: the
        # ratchet arm holds this count against a ceiling, and a seat that sees only the total cannot tell its own
        # road's copies from another seat's.  Printed as a TALLY and never as line= records -- the spill-record gate
        # reads every `<file>.s graph=... line=N rNN` line of this report as its HEAP coverage population, so a copy
        # printed in that shape would enter that gate's population and be graded as a heap site.  (cfo 2026-09-19)
        byf = defaultdict(int)
        for c in cop: byf[(c[0], c[1])] += 1
        out(f"      COPY RESIDUAL BY FILE AND GRAPH ({len(cop)} reading(s) over {len(byf)} graph(s), every one accounted for):")
        pf = defaultdict(int)
        for (f, g), v in byf.items(): pf[f] += v
        for f in sorted(pf, key=lambda x: -pf[x]):
            gs = sorted(((g, v) for (ff, g), v in byf.items() if ff == f), key=lambda x: -x[1])
            out(f"      COPY {f} total={pf[f]}: " + " ".join(f"{g}={v}" for g, v in gs))
    for u in unc[:12]:
        out(f"      ⛔ UNCLASSIFIED {u[0]} graph={u[1]} line={u[2]} {u[3]} class={u[4]}  [{u[5]}]")
    varies = [(k, r) for k, d in per_graph.items() for r, v in d.items() if len(v) > 1]
    out(f"  SITE-DEPENDENCE: {len(varies)} (graph, register) pair(s) whose live-across status DIFFERS between two "
        f"allocating call sites of the SAME graph, out of {sum(len(d) for d in per_graph.values())} pairs over "
        f"{len(per_graph)} graphs. A pair that differs cannot be carried by a per-graph map (section 6.3 is one map "
        f"per graph) without the map lying at one of its own sites. {unattr} site(s) carried no port label in front of "
        f"them and are EXCLUDED from this count rather than lumped together, because lumping two graphs under one name "
        f"would invent site-dependence.")
    for k, r in varies[:12]:
        out(f"      {k[0]} graph={k[1]} register={r}: live across one allocating return and dead across another")
    # ⛔ RECONCILE ALL THREE LISTS, NOT ONLY THE UNCLASSIFIED ONE (cfo 2026-09-23).  This check graded one bucket of
    # three, so a disagreement in the COPY or the HEAP list was unmeasurable -- and the HEAP list is the COVERAGE
    # POPULATION of test_gate_gc_the_spill_record_carries_a_callee_saved_heap_pointer_across_an_allocating_return, where
    # a short list reads as full coverage.  Widening it is what keeps the check from going INERT now that one filing
    # rule cannot disagree with itself: a future route into the tally, or a re-split of the filing, is caught in
    # whichever bucket it lands in rather than only in the one that happened to be graded.  The SUMMARY line is
    # deliberately left byte-stable -- two gates parse it by exact key and a new field is not worth the risk.
    recon = (("unclassified", tally["unclassified"], len(unc)), ("copy", tally["copy"], len(cop)),
             ("heap", tally["heap"], len(heaps)))
    bad = [(n, t, l) for n, t, l in recon if t != l]
    drift = sum(abs(t - l) for _, t, l in bad)
    if bad:
        out("  \u26d4 INSTRUMENT REFUSAL: the class tally and the named list disagree for "
            + ", ".join(f"{n} (tally {t} against list {l})" for n, t, l in bad)
            + ".  Each pair counts the SAME class by two routes and a disagreement means a class name reached the tally "
            "that the list's filing could not place -- those readings are then in neither the copy ratchet nor the "
            "unclassified arm, which is the exact shape of a residual growing behind a green gate.  The census REFUSES "
            "rather than print a number it cannot reconcile.")
    out(f"SUMMARY sites={tot} raw={raw_n} copies={copy_n} heap={heap_n} unclassified={len(unc)} bucket_unclassified={tally['unclassified']} "
        f"unknown_mnemonics={sum(unknown.values())} site_dependent_pairs={len(varies)} graphs={len(per_graph)} "
        f"unattributed_sites={unattr} files={len(paths)}")
    return tot, la, owned, passed, classes, unc, cop, varies, drift
"""----------------------------------------------------------------------------------------------------------"""
def main(argv):
    if "--selftest" in argv: return selftest()
    so = os.path.join(ROOT, "out", "libscrip_rt.so")
    alloc = allocating_entries(so) if os.path.exists(so) else None
    if alloc is None:
        print("REFUSE(2): the allocating set could not be derived from the runtime .so -- the census will not fall back to a hand list")
        return 2
    paths = [a for a in argv if a.endswith(".s")]
    if "--corpus" in argv:
        import tempfile, glob
        limit = 0
        if "--limit" in argv: limit = int(argv[argv.index("--limit") + 1])
        d = tempfile.mkdtemp(prefix="gc_callee_saved."); __import__("atexit").register(__import__("shutil").rmtree, d, True)
        srcs = []
        for ext in ("sno", "sc", "icn", "pl", "reb", "raku", "pas"):
            srcs += sorted(glob.glob(os.path.join(ROOT, "..", "corpus", "benchmarks", "*", "*." + ext)))
        if limit: srcs = srcs[:limit]
        for s in srcs:
            o = os.path.join(d, os.path.basename(s) + ".s")
            try:
                r = subprocess.run([os.path.join(ROOT, "scrip"), "--compile", f"--out={o}", s],
                                   capture_output=True, timeout=120)
                if r.returncode == 0 and os.path.exists(o) and os.path.getsize(o): paths.append(o)
            except Exception: pass
    if not paths:
        print("REFUSE(2): no .s to read (pass files, or --corpus)")
        return 2
    tot, la, owned, passed, classes, unc, cop, varies, drift = report(paths, alloc)
    if tot == 0:
        print("REFUSE(2): zero allocating call sites found -- the census measured nothing")
        return 2
    if drift:
        print("REFUSE(2): the class tally and the unclassified list disagree -- see the INSTRUMENT REFUSAL above")
        return 2
    return 1 if unc else 0
"""----------------------------------------------------------------------------------------------------------"""
def selftest():
    import tempfile
    ok = [0, 0]
    def ck(c, what):
        ok[1] += 1
        if c: ok[0] += 1
        else: print(f"  SELFTEST RED: {what}")
    d = tempfile.mkdtemp(prefix="gc_callee_saved_selftest."); __import__("atexit").register(__import__("shutil").rmtree, d, True)
    p = os.path.join(d, "t.s")
    open(p, "w").write(
        " .text\n"
        "f_α:\n"
        " push rbx\n"
        " mov rbx, rsp\n"
        " call rt_alloc_thing\n"
        " mov rsp, rbx\n"
        " pop rbx\n"
        " ret\n"
        "g_α:\n"
        " push r14\n"
        " mov r14, qword ptr [rsp + 8]\n"
        " call rt_alloc_thing\n"
        " pop r14\n"
        " ret\n")
    alloc = {"rt_alloc_thing"}
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(tot == 2, f"two allocating call sites seen, got {tot}")
    ck(owned.get("rbx", 0) == 1, f"rbx is OWNED-live across the call that reads it afterwards, got {owned.get('rbx',0)}")
    ck(passed.get("r13", 0) == 2, f"a register this witness never writes reads as PASSED THROUGH at both calls, got {passed.get('r13',0)}")
    ck(classes.get("rbx", {}).get("RSP", 0) == 1, "rbx's reaching definition classifies as RSP")
    ck(owned.get("r14", 0) == 0, f"r14 is not owned-live across its call (the pop redefines it), got {owned.get('r14',0)}")
    ck(not unk, f"every mnemonic in the witness is understood, got {dict(unk)}")
    open(p, "w").write(
        " .text\n"
        "h_α:\n"
        " push r12\n"
        " call rt_weird_producer\n"
        " mov r12, rax\n"
        " call rt_alloc_thing\n"
        " mov rdi, r12\n"
        " pop r12\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(owned.get("r12", 0) == 1, f"a register owned-live across the call is seen, got {owned.get('r12',0)}")
    ck(any(u[3] == "r12" and u[4] == "UNCLASSIFIED" for u in unc),
       f"a register defined by an un-whitelisted form reads UNCLASSIFIED rather than being assumed raw, got {unc}")
    open(p, "w").write(
        " .text\n"
        "k_α:\n"
        " call rt_match_enter\n"
        " mov r13, rax\n"
        " call rt_alloc_thing\n"
        " mov rdi, r13\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r13", {}).get("SUBJECT", 0) == 1,
       f"the one heap class is recognised by its seeding call, got {dict(classes.get('r13',{}))}")
    open(p, "w").write(
        " .text\n"
        "kl_\u03b1:\n"
        " call rt_match_enter\n"
        " mov r15, rdx\n"
        " call rt_alloc_thing\n"
        " mov edi, r15d\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r15", {}).get("LENGTH", 0) == 1 and not unc,
       f"the Delta half of the ScanSubjRegs pair reads LENGTH (provably not a pointer by the same declaration that makes the rax half SUBJECT), got {dict(classes.get('r15',{}))} unclassified={unc}")
    open(p, "w").write(
        " .text\n"
        "km_\u03b1:\n"
        " call rt_other_entry\n"
        " mov r15, rdx\n"
        " call rt_alloc_thing\n"
        " mov edi, r15d\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r15", {}).get("LENGTH", 0) == 0 and any(u[3] == "r15" for u in unc),
       f"PLANTED: the SAME copy out of rdx after a call that is NOT rt_match_enter is refused the LENGTH class and reads UNCLASSIFIED, got {dict(classes.get('r15',{}))} unclassified={unc}")
    for seed in ("rt_scan_enter", "rt_scan_reenter", "rt_scan_reenter_live"):
        open(p, "w").write(
            " .text\n"
            "ks_\u03b1:\n"
            " call " + seed + "\n"
            " mov r13, rax\n"
            " call rt_alloc_thing\n"
            " mov rdi, r13\n"
            " ret\n")
        tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
        ck(classes.get("r13", {}).get("SUBJECT", 0) == 1,
           f"the Icon scanning entry {seed} seeds r13 as SUBJECT exactly like rt_match_enter (cfo CFO-149: 270 readings sat in UNCLASSIFIED), got {dict(classes.get('r13',{}))}")
        open(p, "w").write(
            " .text\n"
            "kt_\u03b1:\n"
            " call " + seed + "\n"
            " mov r15, rdx\n"
            " call rt_alloc_thing\n"
            " mov edi, r15d\n"
            " ret\n")
        tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
        ck(classes.get("r15", {}).get("LENGTH", 0) == 1 and not unc,
           f"the rdx half after {seed} reads LENGTH, got {dict(classes.get('r15',{}))} unclassified={unc}")
    open(p, "w").write(
        " .text\n"
        "ku_\u03b1:\n"
        " call rt_scan_enter_shadow\n"
        " mov r13, rax\n"
        " call rt_alloc_thing\n"
        " mov rdi, r13\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r13", {}).get("SUBJECT", 0) == 0 and any(u[3] == "r13" for u in unc),
       f"PLANTED: a call whose name merely has a seed as its PREFIX (rt_scan_enter_shadow) is refused the SUBJECT class -- the match is the whole call token, got {dict(classes.get('r13',{}))} unclassified={unc}")
    for tag, between, want in (("the in-line g_gc_pending test", " mov rax, qword ptr [rip + g_gc_pending@GOTPCREL]\n mov eax, dword ptr [rax + 0]\n test eax, eax\n", 1),
                               ("PLANTED: a call between the push and the pop", " call rt_other_thing\n", 0)):
        open(p, "w").write(
            " .text\n"
            "kw_\u03b1:\n"
            " call qword ptr [rip + rt_match_enter@GOTPCREL]\n"
            " push rax\n" + between +
            " pop rax\n"
            " je 1f\n"
            "1: mov r13, rax\n"
            " call rt_alloc_thing\n"
            " mov rdi, r13\n"
            " ret\n")
        tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
        got = classes.get("r13", {}).get("SUBJECT", 0)
        ck(got == want and (want == 1) == (not any(u[3] == "r13" for u in unc)),
           f"{tag}: pop rax restores what its balancing push rax saved, so the seed is found through it only when nothing between the two can move the saved word (want SUBJECT={want}), got {dict(classes.get('r13',{}))} unclassified={unc}")
    open(p, "w").write(
        " .text\n"
        "kx_\u03b1:\n"
        " call qword ptr [rip + rt_match_enter@GOTPCREL]\n"
        " push rbx\n"
        " pop rax\n"
        " mov r13, rax\n"
        " call rt_alloc_thing\n"
        " mov rdi, r13\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r13", {}).get("SUBJECT", 0) == 0 and any(u[3] == "r13" for u in unc),
       f"PLANTED: a pop rax whose balancing push saved rbx is refused the SUBJECT class, got {dict(classes.get('r13',{}))} unclassified={unc}")
    open(p, "w").write(
        " .text\n"
        "kt_\u03b1:\n"
        " call qword ptr [rip + rt_match_enter@GOTPCREL]\n"
        " cmp rax, -1\n"
        " jne 2f\n"
        " call c_rt_match_enter@PLT\n"
        "2: push rax\n"
        " mov rax, qword ptr [rip + g_gc_pending@GOTPCREL]\n"
        " mov eax, dword ptr [rax + 0]\n"
        " test eax, eax\n"
        " pop rax\n"
        " je 1f\n"
        " sub rsp, 32\n"
        " mov qword ptr [rsp + 8], rax\n"
        " call rt_gc_point_arr_c\n"
        " mov rax, qword ptr [rsp + 8]\n"
        " add rsp, 32\n"
        "1: mov r13, rax\n"
        " call rt_alloc_thing\n"
        " mov rdi, r13\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r13", {}).get("SUBJECT", 0) == 1 and RTX_TWIN_OF.get("c_rt_match_enter") == "rt_match_enter",
       f"the rtx verdict road: the leaf's registered C twin c_rt_match_enter (rtx_twin_table.inc) seeds r13 as SUBJECT exactly like the leaf, through the record's reload and the push/pop, got {dict(classes.get('r13',{}))} unclassified={unc}")
    open(p, "w").write(
        " .text\n"
        "kts_\u03b1:\n"
        " call c_rt_match_enter_shadow@PLT\n"
        " mov r13, rax\n"
        " call rt_alloc_thing\n"
        " mov rdi, r13\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r13", {}).get("SUBJECT", 0) == 0 and any(u[3] == "r13" for u in unc),
       f"PLANTED: a name that merely extends a registered twin (c_rt_match_enter_shadow) is not in the twin table and is refused the SUBJECT class, got {dict(classes.get('r13',{}))} unclassified={unc}")
    open(p, "w").write(
        " .text\n"
        "kv_\u03b1:\n"
        " mov qword ptr [rbp + 96], r13\n"
        " mov qword ptr [rbp + 112], r15\n"
        " mov rdi, qword ptr [rbp + 1520]\n"
        " mov qword ptr [rip + g_rtccb+40], r8\n"
        " call rt_scan_enter\n"
        " mov r8, qword ptr [rip + g_rtccb+40]\n"
        " mov r9, qword ptr [rip + g_rtccb+48]\n"
        " mov r10, qword ptr [rip + g_rtccb+56]\n"
        " mov r11, qword ptr [rip + g_rtccb+64]\n"
        " sub rsp, 32\n"
        " mov dword ptr [rsp + 0], 2\n"
        " mov dword ptr [rsp + 4], edx\n"
        " mov qword ptr [rsp + 8], rax\n"
        " mov qword ptr [rsp + 24], rdx\n"
        " lea rdi, [rsp + 0]\n"
        " mov esi, 1\n"
        " mov edx, 0\n"
        " lea rcx, [rsp + 32]\n"
        " call rt_gc_point_arr_c\n"
        " mov r8, qword ptr [rip + g_rtccb+40]\n"
        " mov rax, qword ptr [rsp + 8]\n"
        " mov rdx, qword ptr [rsp + 24]\n"
        " add rsp, 32\n"
        " test rax, rax\n"
        " je kv_\u03c9\n"
        " mov r13, rax\n"
        " mov r15, rdx\n"
        " call rt_alloc_thing\n"
        " mov rdi, r13\n"
        " mov esi, r15d\n"
        " ret\n"
        "kv_\u03c9:\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r13", {}).get("SUBJECT", 0) == 1 and classes.get("r15", {}).get("LENGTH", 0) == 1,
       f"THE CONCORD SHAPE, VERBATIM (graph n16_scan_enter_alpha): the subject and length copies sit fourteen instructions below rt_scan_enter, reached only THROUGH the poll's spill record -- r13 reads SUBJECT and r15 reads LENGTH by route, got r13={dict(classes.get('r13',{}))} r15={dict(classes.get('r15',{}))}")
    open(p, "w").write(
        " .text\n"
        "kv_\u03b1:\n"
        " mov qword ptr [rbp + 96], r13\n"
        " mov qword ptr [rbp + 112], r15\n"
        " mov rdi, qword ptr [rbp + 1520]\n"
        " mov qword ptr [rip + g_rtccb+40], r8\n"
        " call rt_scan_enter\n"
        " mov r8, qword ptr [rip + g_rtccb+40]\n"
        " mov r9, qword ptr [rip + g_rtccb+48]\n"
        " mov r10, qword ptr [rip + g_rtccb+56]\n"
        " mov r11, qword ptr [rip + g_rtccb+64]\n"
        " sub rsp, 32\n"
        " mov dword ptr [rsp + 0], 2\n"
        " mov dword ptr [rsp + 4], edx\n"
        " mov qword ptr [rsp + 8], rax\n"
        " mov qword ptr [rsp + 24], rdx\n"
        " mov ecx, 7\n"
        " mov qword ptr [rsp + 8], rcx\n"
        " lea rdi, [rsp + 0]\n"
        " mov esi, 1\n"
        " mov edx, 0\n"
        " lea rcx, [rsp + 32]\n"
        " call rt_gc_point_arr_c\n"
        " mov r8, qword ptr [rip + g_rtccb+40]\n"
        " mov rax, qword ptr [rsp + 8]\n"
        " mov rdx, qword ptr [rsp + 24]\n"
        " add rsp, 32\n"
        " test rax, rax\n"
        " je kv_\u03c9\n"
        " mov r13, rax\n"
        " mov r15, rdx\n"
        " call rt_alloc_thing\n"
        " mov rdi, r13\n"
        " mov esi, r15d\n"
        " ret\n"
        "kv_\u03c9:\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    ck(classes.get("r13", {}).get("SUBJECT", 0) == 0 and any(u[3] == "r13" for u in unc) and classes.get("r15", {}).get("LENGTH", 0) == 1,
       f"PLANTED: the record slot OVERWRITTEN from rcx between the spill and the reload -- the route ends at that store and r13 reads UNCLASSIFIED while r15 still reads LENGTH through its own untouched slot, got r13={dict(classes.get('r13',{}))} r15={dict(classes.get('r15',{}))}")
    open(p, "w").write(
        " .text\n"
        "v_α:\n"
        " push rbx\n"
        " mov rbx, rsp\n"
        " call rt_alloc_thing\n"
        " mov rsp, rbx\n"
        " call rt_alloc_thing\n"
        " pop rbx\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    varies = [(k, r) for k, dd in pg.items() for r, v in dd.items() if len(v) > 1]
    ck(any(r == "rbx" for _, r in varies),
       f"a register live across one allocating call of a graph and dead across another is reported as site-dependent, got {varies}")
    open(p, "w").write(
        " .text\n"
        "cc_\u03b1:\n"
        " mov rbp, rsp\n"
        " pop rbx\n"
        " mov qword ptr [rbp - 40], rbx\n"
        " mov r13, qword ptr [rbp - 40]\n"
        " mov qword ptr [rbp - 48], r13\n"
        " mov r12, qword ptr [rbp - 48]\n"
        " call rt_alloc_thing\n"
        " mov rdi, r12\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    _tal = defaultdict(int)
    for r in CS:
        for k, v in classes.get(r, {}).items(): _tal[bucket(k)] += v
    ck(classes.get("r12", {}).get("CELL:CELL:POP", 0) == 1,
       f"PLANTED: a reload whose slot was stored from a register that was itself reloaded out of a slot composes the NESTED class CELL:CELL:POP, got {dict(classes.get('r12',{}))}")
    ck(bucket("CELL:CELL:POP") == "copy" and _tal["copy"] == len(cop) and _tal["unclassified"] == len(unc),
       f"PLANTED: the nested class is counted as a COPY and the tally reconciles with the lists -- one CELL: prefix peeled instead of every one hid it from BOTH blocking arms, got tally={dict(_tal)} copies={len(cop)} unclassified={len(unc)}")
    # ⛔⭐ THE FILING-RULE PLANT (cfo 2026-09-23).  Nine lines that made the two routes DISAGREE before the rule
    # was unified: a copy out of rdx after a call that is not the seeding entry reads UNCLASSIFIED, a store of it into a
    # slot and a reload out of that slot composes CELL:UNCLASSIFIED, and the one-prefix peel filed that reading in the
    # COPY list while bucket() tallied it as unclassified -- so it was in NEITHER blocking arm.  The arm 14 plant above
    # cannot catch this: CELL:CELL:POP is a shape the two routes AGREE on, so its reconciliation check passed over a
    # broken rule.  These three arms RED on the one-prefix peel and are the reason the unified rule cannot be reverted
    # without a measured refusal.
    open(p, "w").write(
        " .text\n"
        "cu_\u03b1:\n"
        " mov rbp, rsp\n"
        " call rt_other_entry\n"
        " mov r14, rdx\n"
        " mov qword ptr [rbp - 40], r14\n"
        " mov r12, qword ptr [rbp - 40]\n"
        " call rt_alloc_thing\n"
        " mov rdi, r12\n"
        " ret\n")
    tot, la, owned, passed, classes, unc, cop, heaps, pg, unk, unattr = census([p], alloc)
    _tal2 = defaultdict(int)
    for r in CS:
        for k, v in classes.get(r, {}).items(): _tal2[bucket(k)] += v
    ck(classes.get("r12", {}).get("CELL:UNCLASSIFIED", 0) == 1 and bucket("CELL:UNCLASSIFIED") == "unclassified",
       f"PLANTED: a reload out of a slot whose store came from an un-whitelisted form composes CELL:UNCLASSIFIED and "
       f"buckets as unclassified, got {dict(classes.get('r12',{}))} bucket={bucket('CELL:UNCLASSIFIED')}")
    ck(any(u[3] == "r12" and u[4] == "CELL:UNCLASSIFIED" for u in unc)
       and not any(c[4] == "CELL:UNCLASSIFIED" for c in cop),
       f"PLANTED: that reading is filed in the UNCLASSIFIED list and NOT in the copy list -- one filing rule, so the "
       f"list a reading joins is the bucket it is tallied into, got unc={[(u[3], u[4]) for u in unc]} "
       f"cop={[(c[3], c[4]) for c in cop]}")
    ck(_tal2["unclassified"] == len(unc) and _tal2["copy"] == len(cop) and _tal2["heap"] == len(heaps),
       f"PLANTED: all THREE lists reconcile with the tally on a population that DIVERGED under the one-prefix peel, "
       f"got tally={dict(_tal2)} unclassified={len(unc)} copies={len(cop)} heap={len(heaps)}")
    print(f"SELFTEST {ok[0]}/{ok[1]} arms green")
    return 0 if ok[0] == ok[1] else 1

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
