#!/usr/bin/env python3
"""THE UNMAPPED-STORE CENSUS -- every emitted safe point whose shielded store lands outside its graph's frame map.

ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 3 has read, since the page was written, that a safe point is
"placed AFTER the call's result has been stored to its mapped slot".  Section 3b (CEO-996) is the finding that
NOTHING HAS EVER ENFORCED THE CLAUSE, and section 3c (CFO-134, CEO-1006) splits the population into four storage
classes.  This is the instrument the row owes first: the clause made checkable, per graph, NAMING EVERY MEMBER.

WHY A STATIC READ OF EMITTED CODE AND NOT AN rc-SHAPED ARM (CEO-997, CEO-556).  The failure this class produces is
a quiet whole-match failure that exits 0 with a plausible wrong answer -- the collector sweeps a live block, the
arena re-issues it in place, and the program prints something.  No rc can tell a cure from a silencing, so the
CURE is graded by ORACLE DIFF on the witness and the POPULATION is graded here, off the emitted text.

THE UNREAD ROAD, AND WHY IT IS COUNTED HERE RATHER THAN LEFT TO THE READER'S MEMORY (cto 2026-09-20).  This
census grades stores to [rsp+D] and [rbp+D].  A value can also be shielded across a safe point by spilling it to
a FIXED SYMBOL -- the emitter does exactly that in x86_asm.h, saving r8/r10/r11 into the runtime's caller-saved
block `g_rtccb` on either side of the poll -- and no frame map can ever cover one of those, because a frame map
describes memory in a frame.  REFUSING to grade them is correct and the selftest has always held it.  ⛔ WHAT WAS
WRONG IS THAT THE REFUSAL WAS SILENT: the store was dropped on the floor, so a language whose shielding rides this
road printed `members=0 undecidable=0`, which is spelled exactly like clean.  Raku was published as CLEAN and
DECIDED COMPLETELY in three cursor entries on the strength of EIGHT graded frame stores, while 207 of its shielded
stores went unread and its rungs was losing 65 gradings at SCRIP_GC_STRESS=16 the same evening.  MEASURED over
the shared witness set: 2230 safe points, 972 frame stores graded, 6690 shielded into `g_rtccb` -- this census reads
about an eighth of the shielding at its own safe points, and every run now says so.  THE SAFETY OF THAT ROAD IS A
ROOT-SET QUESTION AND NOT A MAP QUESTION, and it is open: rtcc_init.c registers the block with
rt_gc_root_range_add_seamsafe, and the only walk over the root-range table in gc_heap.c begins
`if (g_gc_rrng[i].hi) continue;` -- which is precisely how that range is registered, so nothing visits it.
Measured 47 witnesses at SCRIP_HEAP_MB=1 SCRIP_GC_STRESS=3: the runtime's own [GC-RTCCB] reporter counts ZERO
slots holding a heap block pointer at any collection, so the hole is LATENT AND NOT LIVE TODAY.  gc_heap.c is the
cfo's file; this is an ASK with a measurement, never a cure cut from here.

THE DECISION PROCEDURE, and every term in it is read from the tree rather than assumed:
  * A graph's map cell is written by its prologue as `lea rX,[rip+.Lgcmap_<g>]` / `mov [base + D], rX`, with the
    DT_MAP tag stored at [base + D-8].  The cell therefore starts at D-8.
  * gc_heap.c's gc_walk_range computes `base = cell - value_bytes` and walks [base, base+value_bytes) through the static
    layout table.  Below that it walks [p, base) as WORDS: gc_walk_words tries gc_cell_visit on each one first and
    only counts what that recognizer REFUSES into s_raw_heap, printed as [GC-WALK-SPINE].  So REGION BASE = the
    value of the cell's base register at the cell store.
  * ⛔ A STORE BELOW THE BASE IS THEREFORE NOT THE SAME FACT AS A LOST VALUE, and this census does not claim it is
    (hq_snobol4 2026-09-20, verified A/B/A by the cto; the cfo refuted the sign rule twice before that, CFO-114 and
    CFO-136 -- a negative offset is where spine words live BY CONSTRUCTION and was never the discriminator).  What
    a member means is exactly this: the safe point's correctness rests on gc_cell_visit RECOGNISING the tag that
    lands there, instead of on the frame map that ARCH-GC section 3 says should cover it.  The row's witness is
    NO LONGER lost: gc_cell_visit was missing DT_X while gc_visit_one had it, and the cfo landed DT_X into the
    recognizer and into three further spellings of the same fact on 2026-09-20 (measured: a 17-point stress band
    out to 50 in both modes at SCRIP_HEAP_MB=1, base 6 red, head 0, nothing traded).  DT_SNUL is NOT part of that
    cure and must not be added -- see the frozen exclusion in ../harness/scripts/util_gc_kind_sets.py, and the falsifier that
    measured it: DT_SNUL planted beside DT_X leaves 218 of 218 outputs byte-identical, so it buys nothing and it
    would make a speculative recognizer admit the zero tag.  ⛔ THE POINT FOR THIS CENSUS IS THAT ITS MEMBERS DID
    NOT MOVE: the witness now answers its oracle at every stress point WITH ITS STORE STILL OUTSIDE THE MAP, which
    is exactly what arm (h) of the gate predicted, and that surviving 162 is the residual this census exists to
    name.  A member is still a safe point whose correctness rests on the recognizer rather than on the frame map;
    curing the recognizer changed WHICH tags it recognises, never whether the map covers the store.
  * The rsp displacement from the cell store to each safe point is recovered by a set-valued forward fixpoint over
    the emitted CFG.  A site the fixpoint cannot pin to ONE displacement is UNDECIDABLE and is named as such; it is
    never folded into the green count, because a census that guesses is the defect this row exists to remove.

THE ARITHMETIC IS CONFIRMED AGAINST THE RUNTIME ON THE ROW'S WITNESS.  hq_snobol4's SNO$MKEXPR program emits
`mov [rsp+0],rax / mov [rsp+8],rdx / call rt_gc_poll` at .Lcall_alpha_76_240; this census reads the poll's spine
displacement as -32, so the pointer word at [rsp+8] sits at -24 -- and SCRIP_GC_MAPS=1 prints
`[GC-WALK-SPINE] graph=main off=-24 ... text=EXPR$0$lvl1` at the same site.  Two independent roads, same byte.
Since af773a80e (CEO-1251) the call sits behind the inline pending test -- push rax, the load and test of
g_gc_pending, pop rax, je 1f -- and shielded_stores() steps over that six-instruction preamble as the poll's own
(gate_preamble_ending_at): the je skips only the poll body, so both paths passed the stores.

VERDICTS a store target k (relative to the region base) can take:
  MAPPED         -- inside a GC_LAY_DESCR or GC_LAY_PTR_GC layout entry; the collector visits it typed.
  RAW-SLOT       -- inside a GC_LAY_RAW entry: the map tells the collector this word is never a pointer.  A heap
                    pointer stored here is a LIE to the collector, not merely an omission.
  BELOW-REGION   -- k < 0.  Class 1 of section 3c: a call result in a spine scratch cell below the region base.
  ABOVE-REGION   -- k >= value_bytes: the map cell, the wire header and the return address.
  GAP            -- inside the region but covered by no layout entry.
  NO-MAP         -- the graph has no map at all.  Class 2, and NOT this row's residual: it is reported as ONE
                    whole-graph entry attributed to the owning language's row (hq_raku, hq_prolog, hq_snobol4).
  UNDECIDABLE    -- the spine displacement at the site is multi-valued or unknown.  Named, never counted green.

NOT MEASURED HERE AND SAID SO RATHER THAN READ AS ZERO: class 3 of section 3c, a raw heap pointer returned in a
REGISTER PAIR (the cfo's CFO-134).  A frame map describes memory, so no store target exists to classify; this
census cannot see the class and does not claim to.  Blob frames (GC_FRAME_MAP_BLOB, section 6.2b's named
exclusion) are rbp-anchored and are classified against their own layout, not against a spine displacement.
"""
import sys, os, re, subprocess, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
sys.path.insert(0, HERE)
import util_gc_callee_saved_census as CS
import util_gc_census as GCC

GCMAP_LAYOUT_RX = re.compile(r"\[GC-MAP-LAYOUT\] graph=(\S+) n=(\d+) (.*?) gaps=(\d+) conflicts=(\d+)")
LEA_MAP_RX = re.compile(r"\[rip \+ (\.Lgcmap_[A-Za-z0-9_$.]+)\]")
MEM_RX = re.compile(r"\[\s*(rsp|rbp)\s*([+-]\s*-?\d+)?\s*\]")
STATIC_RX = re.compile(r"\[\s*rip\s*\+\s*([A-Za-z_][A-Za-z0-9_.$]*?)\s*(?:\+\s*(\d+))?\s*\]")
IMM_RX = re.compile(r"^-?\d+$")
POLL_NAMES = ("rt_gc_poll", "rt_gc_point_arr_probe_c")
DELTA_CAP = 8


def disp_of(operand):
    """the (base register, byte displacement) of a simple frame operand, or (None, None)"""
    m = MEM_RX.search(operand)
    if not m:
        return None, None
    return m.group(1), int((m.group(2) or "0").replace(" ", "").replace("+-", "-"))


def read_layouts(text):
    """[GC-MAP-LAYOUT] graph=<g> n=<k> off:kind:size ... -> {graph: [(off, kind, size), ...]}"""
    out = {}
    for m in GCMAP_LAYOUT_RX.finditer(text):
        ents = []
        for tok in m.group(3).split():
            parts = tok.split(":")
            if len(parts) == 3:
                ents.append((int(parts[0]), int(parts[1]), int(parts[2])))
        out[m.group(1)] = ents
    return out


def find_anchors(insns):
    """each graph's frame anchor: {graph: (insn index, base register, cell offset from that register)}.

    The emitter (emit_gc_map_register) stores nothing at the frame's reserved cell since ARCH-GC section 13 STEP B; it leaves a
    text-only note `GCANCHOR <.Lgcmap_label> <operand of the cell's pointer word>` on the next instruction, and the cell starts
    8 below that word, exactly where the old marker store's pointer half sat."""
    anchors = {}
    for i, ins in enumerate(insns):
        if not ins.note.startswith("GCANCHOR "):
            continue
        parts = ins.note.split(None, 2)
        if len(parts) < 3 or not parts[1].startswith(".Lgcmap_"):
            continue
        base, d = disp_of(parts[2].replace("$", ""))
        if base is not None:
            anchors.setdefault(parts[1][len(".Lgcmap_"):], (i, base, d - 8))
    return anchors


def mangle(name):
    """bb_ab_sym_name (src/templates/bb/bb_define.cpp:40) in Python.

    ARCH-GC section 6.2d: mode 4 passes an assembler-legal prefix through this function while the map carries the
    graph's TRUE name, so a Prolog graph is `.Lgcmap_main$2F0` in the text and `main/0` in the report.  The match
    is made by MANGLING the true name, never by inverting the label: the inverse is ambiguous (a name that already
    contains a dollar followed by two hex digits demangles to a different name) and this direction is exact."""
    out = []
    for ch in name:
        if ch.isascii() and (ch.isalnum() or ch in "_$."):
            out.append(ch)
        else:
            for b in ch.encode("utf-8"):
                out.append("$%02X" % b)
    return shorten(out, name.encode("utf-8"))


def shorten(units, raw):
    """past 48 bytes the symbol is its whole units up to 31 bytes, a dollar and the FNV-1a of the raw name (bb_ab_sym_name)"""
    if sum(len(u) for u in units) <= 48:
        return "".join(units)
    h, keep = 1469598103934665603, ""
    for b in raw:
        h = ((h ^ b) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    for u in units:
        if len(keep) + len(u) > 31:
            break
        keep += u
    return "%s$%016x" % (keep, h)


def rsp_move(ins):
    """how one instruction moves rsp: an int, or None when the move is not a compile-time constant"""
    mn, ops = ins.mnem, ins.ops
    if mn == "push":
        return -8
    if mn == "pop":
        return 8
    if mn in ("sub", "add") and len(ops) == 2 and ops[0] == "rsp":
        v = ops[1].strip()
        if IMM_RX.match(v):
            return -int(v) if mn == "sub" else int(v)
        return None
    if ops and ops[0] == "rsp" and mn in ("mov", "lea", "xchg", "and", "or", "xor", "imul"):
        return None
    return 0


NOT_AN_ASSIGNMENT = object()

SHADOW_REGS = ("rax", "rbx", "rcx", "rdx", "rsi", "rdi",
               "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15")

WRITES_MEMORY = ("mov", "add", "sub", "and", "or", "xor", "inc", "dec", "neg", "not",
                 "shl", "shr", "sar", "imul")


def rsp_slot_of(operand):
    """the rsp-relative offset of a `qword ptr [rsp + K]` operand, else None -- a FULL-WIDTH slot only.

    A `dword ptr [rsp + K]` writes four bytes of the cell at K and is NOT a parked spine word; it is read by
    slot_effect() below as an invalidation of K, never as a store of one."""
    base, d = disp_of(operand)
    return d if base == "rsp" and "qword" in operand else None


def rbp_slot_of(operand):
    """the rbp-relative offset of a `qword ptr [rbp + K]` operand, else None -- a FULL-WIDTH slot only.

    THE TWIN OF rsp_slot_of AND THE REASON THERE ARE TWO (cto 2026-09-21).  A slot named off rbp has an
    ANCHOR-RELATIVE ADDRESS the moment rbp's displacement is known, which rsp-named slots inside an alignment
    window do not: there rsp is unknown at the store, so the only knowable thing is a distance.  That difference
    is the whole reason the anchor-keyed shadow is simpler than the rsp-keyed one -- absolute keys need no
    re-keying on an rsp move and survive across basic blocks."""
    base, d = disp_of(operand)
    return d if base == "rbp" and "qword" in operand else None


def reg_written(ins):
    """the shadowed register this instruction OVERWRITES, else None.

    `push rcx` names rcx as its first operand and writes nothing, which is why the read-only mnemonics are
    excluded by name: a push read as a write drops the very shadow x86_align_call_enter's window depends on."""
    if not ins.ops or ins.mnem in ("push", "cmp", "test", "jmp", "call", "ret", "je", "jne", "jl", "jg"):
        return None
    r = ins.ops[0].strip()
    return r if r in SHADOW_REGS else None


GOTPCREL_RX = re.compile(r"\[\s*rip\s*\+\s*[A-Za-z_][A-Za-z0-9_.$]*@GOTPCREL\s*\]")
LEA_RIP_RX = re.compile(r"\[\s*rip\s*[+\-]")
CALLER_SAVED = ("rax", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11")
_REG_ALIASES = {"rax": "rax|eax|ax|al|ah", "rcx": "rcx|ecx|cx|cl|ch", "rdx": "rdx|edx|dx|dl|dh",
                "rsi": "rsi|esi|si|sil", "rdi": "rdi|edi|di|dil", "rbx": "rbx|ebx|bx|bl|bh"}
for _r in ("r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"):
    _REG_ALIASES[_r] = "|".join((_r, _r + "d", _r + "w", _r + "b"))
REG_MENTION = {r: re.compile(r"\b(?:%s)\b" % a) for r, a in _REG_ALIASES.items()}
MEM_BASE_RX = re.compile(r"\[\s*([a-z][a-z0-9]*)")


def base_is_fixed_symbol(insns, i, reg):
    """does the base register of the store at i provably hold the ADDRESS OF A FIXED DATA SYMBOL?

    ⛔⭐ THE THIRD FACT ABOUT THE ADDRESS SPACE, AND IT IS NOT A RELAXATION OF THE ALIASING DISCIPLINE (cto
    2026-09-21).  slot_effect places exactly two writes rather than fearing them, both because of what they
    ADDRESS and not because of what the program does: a `[rip + sym]` store names a fixed data symbol, and an
    `[rsp + K]` store names the stack itself.  This is the same fact reached through one indirection: the System V
    small-PIC form of "the address of a global" is a load from that global's GOT slot, so

        mov rax, qword ptr [rip + g_line@GOTPCREL]   |   mov qword ptr [rax + 0], 4

    is `[rip + g_line]` spelled in two instructions.  A GOT slot holds the address of a DEFINED SYMBOL; no
    symbol is defined on a machine stack, so the store cannot alias one.  `lea r, [rip + sym]` is the same fact
    with no load at all.

    ⛔ WHY THIS IS THE ROAD AND THE ALLOCATOR-RETURN POINTS-TO FACT WAS NOT, MEASURED BEFORE A LINE WAS CUT.  The
    prior NEXT named a different claim -- a store through a register holding a NAMED ALLOCATOR'S RETURN cannot
    alias the stack -- and proposed to check it against the runtime.  A second pass over all 52 witnesses says
    that population is EMPTY: of 2044 unplaceable stores, the base register is defined by a call ZERO times.  It
    is a GOTPCREL address load 1303 times and a rip-relative `lea` 284 times.  The allocator road would have been
    built, checked and landed for nobody.

    ⛔ AND THE FOUR SITES THAT PROVE THE DISTINCTION IS LOAD-BEARING RATHER THAN DECORATIVE: `lea r, [rsp + K]`
    and `lea r, [rbp + K]` put a STACK address in a general register, and there are FOUR of them in the same
    population.  A rule that placed every `lea` base, or every non-rsp base, would be unsound at exactly those
    four and would compute wrong depths there while printing them as discoveries -- which is the shape of the 15
    OFF-GRID readings the blanket relaxation produced.  So the walk accepts TWO forms by name and fears
    everything else, including a plain rip-relative LOAD, which reads a global's VALUE and not its address."""
    mention = REG_MENTION.get(reg)
    if mention is None:
        return False
    caller_saved = reg in CALLER_SAVED
    for j in range(i - 1, -1, -1):
        ins = insns[j]
        if ins.mnem == "call":
            if caller_saved:
                return False
        elif ins.ops and len(ins.ops) == 2 and mention.fullmatch(ins.ops[0].strip()):
            if ins.mnem == "lea":
                return bool(LEA_RIP_RX.search(ins.ops[1]))
            if ins.mnem == "mov":
                return bool(GOTPCREL_RX.search(ins.ops[1]))
            return False
        elif mention.search(ins.text):
            return False
        if ins.labels:
            return False
    return False


def fixed_symbol_store_bases(insns):
    """the id() of every store whose base register provably holds a fixed data symbol's address.

    KEYED BY id(ins) AND NOT BY LINE NUMBER because CS.parse splits a `;`-separated source line into several
    Insn objects that share one line number, and marking one of those would mark its neighbour.  The set is
    computed once per asm file in build_frames and lives exactly as long as the insns list it indexes."""
    out = set()
    for i, ins in enumerate(insns):
        if ins.mnem not in WRITES_MEMORY or not ins.ops or "[" not in ins.ops[0]:
            continue
        if "rip" in ins.ops[0]:
            continue
        m = MEM_BASE_RX.search(ins.ops[0])
        reg = m.group(1) if m else None
        if reg is None or reg in ("rsp", "rbp"):
            continue
        if base_is_fixed_symbol(insns, i, reg):
            out.add(id(ins))
    return frozenset(out)


def slot_effect(ins, slots, fixed=False):
    """what this instruction does to the parked-slot shadow BEFORE the store of a known value is applied.

    ⛔ THE ALIASING DISCIPLINE, WHICH IS THE WHOLE REASON THIS SHADOW IS TRUSTWORTHY (cto 2026-09-21).  A slot
    shadow that survives a store it cannot place is a guess, and this census exists to remove guesses.  So ANY
    memory write this reader cannot place relative to rsp CLEARS THE WHOLE SHADOW -- measured on the 41-witness
    set, that is 8856 `[rbp + K]` stores, 1259 `[rax + ...]`, 194 `[r9 + ...]` and an absolute `[1879048192]`,
    every one of them wiping it.  The cure survives that discipline intact (858 -> 1666 graded call sites)
    because x86_align_call_enter's window is four instructions and a call, and contains no such store.

    EXACTLY TWO WRITES ARE PLACED RATHER THAN FEARED, and both are facts about the address space rather than
    inferences about the program: a `[rip + sym]` store addresses a FIXED DATA SYMBOL and can never alias the
    machine stack (7179 of them on the witness set, and leaving them in the feared set costs the entire cure),
    and an `[rsp + K]` store of any width invalidates the cells it overlaps AND NOTHING ELSE."""
    if ins.mnem not in WRITES_MEMORY or not ins.ops or "[" not in ins.ops[0]:
        return dict(slots)
    if "rip" in ins.ops[0]:
        return dict(slots)
    base, d = disp_of(ins.ops[0])
    if base != "rsp":
        return dict(slots) if fixed else {}
    out = dict(slots)
    out.pop(d, None)
    out.pop(d - 8, None)
    return out


def anchor_slot_effect(ins, aslots, rsp, rbp, fixed=False):
    """what this instruction does to the ANCHOR-KEYED shadow before a placeable store of a known rsp is applied.

    THE SAME ALIASING DISCIPLINE AS slot_effect, TAKEN ON THE OTHER KEY: a write this reader cannot place
    relative to the ANCHOR clears the whole shadow, and a write it can place invalidates the cells it overlaps
    and nothing else.  Because the key is an absolute anchor-relative address, an `[rsp + K]` write at a KNOWN
    rsp and an `[rbp + K]` write at a KNOWN rbp are both placeable here -- the two bases meet in one address
    space -- where the rsp-keyed shadow could only ever place the first.

    ⛔ THE ONE ASSUMPTION, NAMED RATHER THAN LEFT IMPLICIT, because this shadow spans calls where the rsp-keyed
    one spanned a four-instruction window: a `call` is taken NOT to clobber its caller's frame slots.  That is
    already the standing assumption of the landed rsp-keyed arm (x86_align_call_enter parks, calls, restores),
    and it is widened here from one window to a whole activation.  It is not asserted into safety: every site
    this arm newly decides is cross-checked against the reading that preceded it -- zero disagreements where
    both decide, and off_grid 0 -- which is what would break first if a callee were writing through a caller
    frame slot.  A `push` and the cell below it are invalidated explicitly, since push writes memory while
    naming no memory operand and would otherwise slip past the WRITES_MEMORY test."""
    if ins.mnem == "push":
        return {} if rsp is None else {k: v for k, v in dict(aslots).items() if k not in (rsp - 8, rsp - 16)}
    if ins.mnem not in WRITES_MEMORY or not ins.ops or "[" not in ins.ops[0]:
        return dict(aslots)
    if "rip" in ins.ops[0]:
        return dict(aslots)
    base, d = disp_of(ins.ops[0])
    anchor_rel = rsp if base == "rsp" else (rbp if base == "rbp" else None)
    if anchor_rel is None:
        return dict(aslots) if fixed else {}
    out = dict(aslots)
    out.pop(anchor_rel + d, None)
    out.pop(anchor_rel + d - 8, None)
    return out


def rsp_assign(ins, rsp, rbp):
    """the NEW rsp displacement when this instruction ASSIGNS rsp from a base the fixpoint already knows.

    ⛔ WHY THIS EXISTS AND WHY IT IS NOT A `rsp_move` CASE (cto 2026-09-21).  rsp_move answers "how far did rsp
    MOVE", and a delta cannot express `lea rsp, [rbp - 688]`, which SETS rsp from another register.  Returning
    None for it poisoned the fixpoint: once rsp read unknown, every call downstream of it read
    SPINE-DEPTH-UNKNOWN and was dropped from the graded population -- 2215 of the 2256 undecidable call sites
    over the shared witness set, and the emitter emits exactly two forms that account for 1808 of them:

        lea rsp, [rbp - K]   1703      mov rsp, rbp   105

    Both are rbp-relative, and THIS FIXPOINT ALREADY TRACKS rbp's displacement from the anchor -- the second
    element of every state pair.  So the depth was never unknowable; it was unexpressed.  ⛔ AND THE ASSIGNMENT
    MUST BE APPLIED EVEN WHEN rsp IS ALREADY UNKNOWN, which is the load-bearing half: an assignment from a known
    rbp RE-ESTABLISHES a known rsp, and the old code returned early on `rsp is None` and never looked.

    The forms deliberately NOT handled, because they are genuinely not compile-time constants and a census that
    guesses is the defect this file exists to remove: `and rsp, -16` (an alignment mask, 176 of them),
    `mov rsp, qword ptr [...]` (a restore from memory, 227) and `mov rsp, rax` (4).

    ⭐ THE MEMORY RESTORE IS READ AS OF 2026-09-21 AND NOT HERE: it needs the parked-slot shadow, which only
    the fixpoint carries, so frame_step() below answers it and this function keeps its register-only contract."""
    mn, ops = ins.mnem, ins.ops
    if not ops or ops[0] != "rsp" or len(ops) != 2:
        return NOT_AN_ASSIGNMENT
    src = ops[1].strip()
    if mn == "mov":
        if src == "rbp":
            return rbp
        if src == "rsp":
            return rsp
        return NOT_AN_ASSIGNMENT
    if mn != "lea":
        return NOT_AN_ASSIGNMENT
    base, d = disp_of(src)
    if base is None or "qword" in src or "ptr" in src:
        return NOT_AN_ASSIGNMENT
    anchor_rel = rsp if base == "rsp" else rbp
    return None if anchor_rel is None else anchor_rel + d


def seed_rbp(insns, anchor):
    """the rbp displacement from the anchor's rsp, when the prologue established rbp before the cell store.

    Walked backwards from the cell store to the nearest function label, undoing rsp moves, so a `mov rbp, rsp`
    anywhere in the prologue is related to the anchor exactly rather than assumed to be at the same depth."""
    back = 0
    for j in range(anchor - 1, max(-1, anchor - 400), -1):
        ins = insns[j]
        if ins.mnem == "mov" and len(ins.ops) == 2 and ins.ops[0] == "rbp" and ins.ops[1] == "rsp":
            return back
        m = rsp_move(ins)
        if m is None:
            return None
        back -= m
        if ins.labels and any(not L.startswith(".L") for L in ins.labels):
            return None
    return None


def frame_fixpoint(insns, succ, start, rbp0, symbase=frozenset()):
    """set-valued forward fixpoint of (rsp, rbp) displacement from `start`; None means 'not a constant here'.

    ⛔ THE rsp EFFECT AND THE rbp EFFECT ARE COMPUTED INDEPENDENTLY, AND THE FIRST CUT DID NOT DO THAT (cto
    2026-09-21).  An instruction that WRITES rbp used to `continue` out of the loop carrying rsp unchanged, so
    `pop rbp` -- the second half of every `mov rsp, rbp / pop rbp` frame whack the SNOBOL4 emitter lays down --
    never applied its own +8 to rsp.  While the spine depth was already poisoned downstream that cost nothing
    visible.  The moment rsp_assign() un-poisoned it, the missing 8 became a SYSTEMATIC parity error and the
    census reported 142 OFF-GRID call sites at residue 8 across twelve SNOBOL4 witnesses -- a defect in the
    EMITTER, announced on the strength of an arithmetic slip in this function.  One instruction can move both
    registers and this loop now says so."""
    st = collections.defaultdict(set)
    st[start].add((0, rbp0, frozenset(), frozenset(), frozenset()))
    work = [start]
    while work:
        i = work.pop()
        ins = insns[i]
        nxt = set()
        fixed = id(ins) in symbase
        for state in st[i]:
            nxt.add(frame_step(ins, *state, fixed))
        nxt = widen(nxt)
        for t in succ.get(i, ()):
            before = len(st[t])
            st[t] = widen(st[t] | nxt)
            if len(st[t]) != before:
                work.append(t)
    return st


def widen(states):
    """bound the state set WITHOUT throwing away the two values the verdict is made of.

    ⛔⭐ THE OLD WIDENING WAS `{BOTTOM}` AND BOTTOM IS (rsp=None, rbp=None), SO GOING OVER THE CAP DESTROYED THE
    SPINE DEPTH AND THE FRAME BASE TOGETHER (cto 2026-09-21, caught by A/B before landing and not after).  The
    cap counts whole states, and a state carries two shadows that exist only to RECOVER rsp -- so enriching the
    shadows, which is what the fixed-symbol fact does, pushes more DISTINCT states through a join and used to
    collapse rbp at sites that were reading it perfectly well.  Measured on the 52 witnesses: the fact alone took
    RBP-NOT-A-FRAME-BASE-HERE from 4 to 116 shielded stores across four Icon witnesses, a REGRESSION IN REACH
    hiding underneath a 400-site improvement in the grid -- two numbers moving opposite ways in one reading,
    which is why a landing is A/B'd on every column and not on the one it aimed at.

    So the widening drops the SHADOWS first and the values only if that is not enough.  Dropping a shadow is
    always sound: a shadow can only ever turn an unknown rsp into a known one, so losing it loses precision and
    never invents a depth."""
    if len(states) <= DELTA_CAP:
        return states
    slim = {(rsp, rbp, frozenset(), frozenset(), frozenset()) for rsp, rbp, *_ in states}
    return slim if len(slim) <= DELTA_CAP else {BOTTOM}


BOTTOM = (None, None, frozenset(), frozenset(), frozenset())


def frame_step(ins, rsp, rbp, regs, slots, aslots, fixed=False):
    """one instruction's effect on (rsp, rbp, register shadow, parked-slot shadow).

    ⛔⭐ WHY THE TWO SHADOWS EXIST, AND WHAT THE MEASUREMENT SAID BEFORE A LINE OF THEM WAS WRITTEN (cto
    2026-09-21).  The row's prior cursor named `mov rsp, qword ptr [rsp + 0]` as the remaining blindness.  It is
    the right instruction and it is NOT the blocker: a blame pass over the 41-witness set -- for every
    undecidable call, the instruction that poisoned rsp on the path to it -- named ONE form for ALL 1710 of
    them, `and rsp, -16`, the alignment mask of x86_align_call_enter.  The mask and the restore are the two
    halves of ONE window:

        mov r11, rsp | and rsp, -16 | sub rsp, 16 | mov [rsp + 0], r11 | call ... | mov rsp, [rsp + 0]

    The mask poisons the depth, every call downstream of it in the graph reads SPINE-DEPTH-UNKNOWN forever, and
    the restore that would END the poison was unreadable because its source is MEMORY -- so a delta-and-assign
    fixpoint could never un-poison.  Reading it takes exactly two facts carried alongside the depth: which
    register holds a known rsp (`mov r11, rsp`), and which rsp-relative slot that register was parked in
    (`mov [rsp + 0], r11`).  Measured on the witness set: graded call sites 858 -> 1666, undecidable 1710 -> 889,
    ZERO sites lost, ZERO disagreements on any site both readings decide, and every one of the 808 newly graded
    sites ON-GRID -- which is the arithmetic re-derivation item 5 of that cursor demanded, since un-blinding an
    instrument makes its own old slips systematic.

    ⛔ THE SLOT KEY IS AN OFFSET FROM THE CURRENT rsp, NEVER AN ADDRESS FROM THE ANCHOR, and that is forced: in
    the window above rsp is UNKNOWN at the store, so the slot HAS no anchor-relative address.  What is known is
    that the slot sits at a fixed distance from rsp, so every known rsp move re-keys the shadow and an unknown
    one discards it."""
    if ins.mnem == "mov" and len(ins.ops) == 2 and ins.ops[0] == "rbp":
        new_rbp = rsp if ins.ops[1] == "rsp" else None
    elif ins.ops and ins.ops[0] == "rbp" and ins.mnem not in ("cmp", "test", "push"):
        new_rbp = None
    else:
        new_rbp = rbp
    a = rsp_assign(ins, rsp, rbp)
    if a is NOT_AN_ASSIGNMENT and ins.mnem == "mov" and len(ins.ops) == 2 and ins.ops[0] == "rsp":
        src = rsp_slot_of(ins.ops[1])
        if src is not None:
            a = dict(slots).get(src, NOT_AN_ASSIGNMENT)
        else:
            src = rbp_slot_of(ins.ops[1])
            if src is not None and rbp is not None:
                a = dict(aslots).get(rbp + src, NOT_AN_ASSIGNMENT)
    if a is not NOT_AN_ASSIGNMENT:
        new_rsp, moved = a, None
    elif rsp is None:
        new_rsp, moved = None, rsp_move(ins)
    else:
        moved = rsp_move(ins)
        new_rsp = None if moved is None else rsp + moved
    rg = dict(regs)
    w = reg_written(ins)
    if w is not None:
        if ins.mnem == "mov" and len(ins.ops) == 2 and ins.ops[1].strip() == "rsp" and rsp is not None:
            rg[w] = rsp
        else:
            rg.pop(w, None)
    sl = slot_effect(ins, slots, fixed)
    if ins.mnem == "mov" and len(ins.ops) == 2:
        off = rsp_slot_of(ins.ops[0])
        if off is not None:
            src = ins.ops[1].strip()
            if src in rg:
                sl[off] = rg[src]
            elif src == "rsp" and rsp is not None:
                sl[off] = rsp
            else:
                sl.pop(off, None)
    if a is not NOT_AN_ASSIGNMENT or moved is None:
        sl = {}
    elif moved:
        sl = {k - moved: v for k, v in sl.items() if k - moved >= 0}
    asl = anchor_slot_effect(ins, aslots, rsp, rbp, fixed)
    if ins.mnem == "mov" and len(ins.ops) == 2 and rbp is not None:
        off = rbp_slot_of(ins.ops[0])
        if off is not None:
            src = ins.ops[1].strip()
            if src in rg:
                asl[rbp + off] = rg[src]
            elif src == "rsp" and rsp is not None:
                asl[rbp + off] = rsp
            else:
                asl.pop(rbp + off, None)
    if len(rg) > DELTA_CAP:
        rg = {}
    if len(sl) > DELTA_CAP:
        sl = {}
    if len(asl) > DELTA_CAP:
        asl = {}
    return new_rsp, new_rbp, frozenset(rg.items()), frozenset(sl.items()), frozenset(asl.items())


def shielded_stores(insns, i, skip=frozenset()):
    """the stores in the basic block that ends at the poll -- the stores this safe point was placed after.

    TWO POPULATIONS ARE RETURNED AND THEY ARE NEVER SUMMED: the FRAME stores, which this census can grade against
    the graph's frame map, and the STATIC stores, which it cannot, because a frame map describes memory IN A FRAME
    and a rip-relative store lands in a fixed symbol.  The second list is this census's own REACH BOUNDARY.  It was
    dropped on the floor until 2026-09-20 22:xx and the module docstring's UNREAD ROAD paragraph carries what that
    cost: a language whose shielding rides the static road read `members=0 undecidable=0`, which is indistinguishable
    from clean.

    The walk back stops at a control transfer (a store on the other side of a branch does not precede this poll on
    every path) and stops AFTER the instruction that carries a label, because a label is where another path enters."""
    frame, static = [], []
    j = i - 1
    while j >= 0:
        ins = insns[j]
        if CS.JCC.match(ins.mnem) or ins.mnem in ("call", "ret", "ud2"):
            n = gate_preamble_ending_at(insns, j)
            if not n:
                break
            j -= n
            if insns[j + 1].labels:
                break
            continue
        if j not in skip:
            frame.extend(_store_of(ins))
            static.extend(_static_store_of(ins))
        if ins.labels:
            break
        j -= 1
    return frame, static


GATE_PREAMBLE = ("push rax", "mov rax, qword ptr [rip + g_gc_pending@GOTPCREL]", "mov eax, dword ptr [rax + 0]",
                 "test eax, eax", "pop rax", "je 1f")


SPILL_65B_HEAD = ("sub rsp, 32", "mov qword ptr [rsp + 0], r13", "mov qword ptr [rsp + 16], rax", "mov qword ptr [rsp + 24], rdx",
                  "xor edi, edi", "xor esi, esi", "mov rdx, rsp", "lea rcx, [rsp + 16]")
SPILL_65B_TAIL = ("mov r13, qword ptr [rsp + 0]", "mov rax, qword ptr [rsp + 16]", "mov rdx, qword ptr [rsp + 24]", "add rsp, 32")
SPILL_65B_STORES = (1, 2, 3)
RTCC_WRITEBACK = re.compile(r"^mov qword ptr \[rip \+ g_rtccb\+\d+\], r(?:8|9|10|11)$")
RTCC_RELOAD = re.compile(r"^mov r(?:8|9|10|11), qword ptr \[rip \+ g_rtccb\+\d+\]$")


def _norm(ins):
    return " ".join(ins.text.split())


def spill65b_at(insns, i):
    """the positions of the three ARCH-GC 6.5b spill stores (r13 word, result cell) of the poll at insns[i], or None.

    THE SHAPE, from x86_rt_gc_poll_res in x86_asm.h (the cfo's ruling of 2026-10-04, every result-preserving poll
    shields r13 as the plain poll does): `sub rsp, 32 / mov [rsp+0], r13 / mov [rsp+16], rax / mov [rsp+24], rdx /
    xor edi, edi / xor esi, esi / mov rdx, rsp / lea rcx, [rsp+16]`, the g_rtccb write-backs of r8-r11, `call
    rt_gc_point_arr_probe_c`, the g_rtccb reloads, `mov r13, [rsp+0] / mov rax, [rsp+16] / mov rdx, [rsp+24] / add
    rsp, 32`.  The box's result lives in rax:rdx at the poll, so it is spilled as ONE DESCR cell at the sweep floor,
    swept by the collector's spine walk and relocated by its tag, and reloaded; the r13 word sits BELOW the floor
    (never swept) and is handed to the probe entry as the saved subject, which rewrites it only when it aliases
    Sigma or scan_subj.  The cell is below the frame's region BY CONSTRUCTION and holds a well-formed DESCR on
    both outcomes (a FAIL-typed one on failure).
    WHY IT IS COUNTED APART AND NEVER AS A MEMBER (the cfo's ruling of 2026-10-04 on the coo's bisect of the arm
    (e) move to c869d57c1, which turned plain polls into this form at the baked call arms): a member is a store
    whose safety rests on the recognizer rather than on the map, and so is this one -- but it is ONE known cell
    whose content is the call's own result, and folding it into the members re-keyed 71 baseline rows at once,
    which would have blessed any real below-region store that landed beside it.  So the census names it on its
    own lines, counts it, and grades every OTHER below-region store against the per-witness baseline as before.
    EVERY TEXT OF THE HEAD AND THE TAIL IS MATCHED EXACTLY and a label on any instruction of the head after its first, or anywhere in
    the tail, refuses the shape (another path entering it is not this cell), exactly as gate_preamble_ending_at
    refuses a reshaped gate; only the chain's own site labels (.Lgcsite_) are allowed on the reload after the call."""
    j = i - 1
    while j >= 0 and RTCC_WRITEBACK.match(_norm(insns[j])) and not insns[j].labels:
        j -= 1
    hn = len(SPILL_65B_HEAD)
    if j < hn - 1:
        return None
    for k, want in enumerate(SPILL_65B_HEAD):
        ins = insns[j - (hn - 1) + k]
        if _norm(ins) != want or (k and ins.labels):
            return None
    t = i + 1
    while t < len(insns) and RTCC_RELOAD.match(_norm(insns[t])):
        if insns[t].labels and not all(str(l).startswith(".Lgcsite_") for l in insns[t].labels):
            return None
        t += 1
    if t + len(SPILL_65B_TAIL) > len(insns):
        return None
    for k, want in enumerate(SPILL_65B_TAIL):
        ins = insns[t + k]
        if _norm(ins) != want:
            return None
        if ins.labels and not (t + k == i + 1 and all(str(l).startswith(".Lgcsite_") for l in ins.labels)):
            return None
    return frozenset(j - (hn - 1) + k for k in SPILL_65B_STORES)


def gate_preamble_ending_at(insns, j):
    """the length of the CEO-1251 inline pending test whose `je 1f` is insns[j], or 0.

    THE SHAPE, from x86_gc_gate in x86_asm.h (af773a80e, 2026-09-25): every poll is emitted as `push rax / mov rax,
    [rip+g_gc_pending@GOTPCREL] / mov eax,[rax] / test eax,eax / pop rax / je 1f` and then the poll body, with the
    `1:` label after it.  That je skips ONLY the poll's own body, so every path that reaches the poll also passed the
    instructions before the push -- the preamble is the poll's, not a join, and the backward walk steps over it.
    THE READING THIS CURED: for two days the walk met the je, called it a control transfer and stopped, so the frame
    stores the poll was placed after were never read; the census REFUSED with zero shielded stores over every witness
    and arms (b) and (e) of test_gate_gc_a_safe_point_stores_into_a_mapped_slot.sh were red (the cfo's bisect,
    2026-09-26).  ALL SIX INSTRUCTIONS ARE MATCHED BY TEXT: a gate that changes shape is a stop again, never a silent
    skip, and a je to any other target is the real branch it always was.  A label on any instruction after the push
    is another path entering the preamble itself and is refused as a gate."""
    if j < 5:
        return 0
    for k, want in enumerate(GATE_PREAMBLE):
        ins = insns[j - 5 + k]
        if " ".join(ins.text.split()) != want:
            return 0
        if k and ins.labels:
            return 0
    return 6


def _store_of(ins):
    """the frame store this instruction performs, as [(base register, displacement, source operand)]"""
    if ins.mnem not in ("mov", "movq") or len(ins.ops) != 2:
        return []
    if "[" not in ins.ops[0] or "rip" in ins.ops[0]:
        return []
    base, d = disp_of(ins.ops[0])
    if base is None:
        return []
    return [(base, d, ins.ops[1])]


def _static_store_of(ins):
    """the rip-relative store this instruction performs, as [(symbol, byte offset, source operand)].

    NO CURE TO THE PLANNER CAN REACH ONE OF THESE, which is exactly why they are counted rather than dropped: a
    frame map describes a frame, so a value shielded into a fixed symbol is outside every map BY CONSTRUCTION and
    its safety rests entirely on whether the collector's ROOT SET covers that symbol."""
    if ins.mnem not in ("mov", "movq") or len(ins.ops) != 2:
        return []
    if "[" not in ins.ops[0] or "rip" not in ins.ops[0]:
        return []
    m = STATIC_RX.search(ins.ops[0])
    if m is None:
        return []
    return [(m.group(1), int(m.group(2) or 0), ins.ops[1])]


def classify(k, layout, value_bytes, blob):
    """the verdict for a store target at byte offset k from the frame's layout anchor"""
    for off, kind, size in layout:
        if off <= k < off + size:
            return "MAPPED" if kind in (0, 2) else "RAW-SLOT"
    if blob:
        return "OUTSIDE-LAYOUT"
    if k < 0:
        return "BELOW-REGION"
    if k >= value_bytes:
        return "ABOVE-REGION"
    return "GAP"


def join_verdict(reached, shielded):
    """the zero-entry-map JOIN: a map with no entries is only a DEFECT in a graph that shields a value at a safe point.

    A graph the anchor walk never reached is NOT-REACHED and is never read as benign -- that is the fourth way a
    zero fails to be a zero (the population never ran the subject) applied one graph at a time."""
    if not reached:
        return "NOT-REACHED"
    return "MEMBER" if shielded else "BENIGN"


def site_label(insns, i):
    """the nearest label at or before instruction i -- what a reader greps for in the .s"""
    for j in range(i, max(-1, i - 40), -1):
        if insns[j].labels:
            return insns[j].labels[0]
    return "-"


def owner_of(base, d, i, frames):
    """(graph, offset from the frame's region base, reason-it-is-undecidable) for one store at a poll.

    The store is attributed to the graph whose map-cell anchor REACHES this instruction in the CFG. Two graphs
    reaching one site is an ambiguity that is NAMED, never a tie broken by order."""
    cand = [(g, f, f["frame"].get(i)) for g, f in frames.items() if f["frame"].get(i)]
    if not cand:
        return None, 0, "NO-ANCHOR-REACHES-SITE"
    if len(cand) > 1:
        return "+".join(c[0] for c in cand), 0, "AMBIGUOUS-OWNER"
    g, f, states = cand[0]
    if f["blob"]:
        return g, d, None if base == "rbp" else "BLOB-FRAME-NOT-RBP-ADDRESSED"
    vals = set()
    for rsp, rbp, *_shadows in states:
        anchor_rel = rsp if base == "rsp" else rbp
        vals.add(None if anchor_rel is None else anchor_rel + d - f["cell"] + f["value_bytes"])
    if None in vals:
        return g, 0, ("SPINE-DEPTH-UNKNOWN" if base == "rsp" else "RBP-NOT-A-FRAME-BASE-HERE")
    if len(vals) != 1:
        return g, 0, "FRAME-DEPTH-MULTI-VALUED"
    return g, next(iter(vals)), None


def owner_ks(base, d, i, frames):
    """(graph, every offset this store can take) for a site ONE graph's anchor reaches at MORE THAN ONE depth.

    owner_of names FRAME-DEPTH-MULTI-VALUED and stops, which is right for a MAPPED verdict -- a map cell is one
    offset -- and blind for a SPINE cell, which the walker finds by tag at every 16-aligned depth (cto 2026-09-22:
    four by-name x86_rt_gc_poll_res sites in hb_coexpr_genp_scan.icn, each reached at two depths, both on the grid,
    read UNDECIDABLE and put a blocking arm red for a poll that had ARRIVED).  A caller that can decide every
    depth gets every depth; a caller that cannot keeps owner_of's verdict.  An empty tuple means NOT DECIDED."""
    cand = [(g, f, f["frame"].get(i)) for g, f in frames.items() if f["frame"].get(i)]
    if len(cand) != 1:
        return None, ()
    g, f, states = cand[0]
    if f["blob"]:
        return g, ()
    vals = set()
    for rsp, rbp, *_shadows in states:
        anchor_rel = rsp if base == "rsp" else rbp
        if anchor_rel is None:
            return g, ()
        vals.add(anchor_rel + d - f["cell"] + f["value_bytes"])
    return g, tuple(sorted(vals))


CELL = 16


def trim_entry_fallthrough(insns, succ, label_at):
    """drop the FALLTHROUGH edge into any label a `call` names -- a call target starts a different activation.

    ⛔ MEASURED BEFORE IT WAS BELIEVED, and the first grid reading is what found it (cto 2026-09-20).  SNOBOL4
    emits `module_init` immediately after `main`'s last box in the text, and main's last arm is
    `main_ω: mov edi,1 / call exit@PLT`.  A `call` gets a fallthrough successor because a call returns -- but
    `exit` does not, and the next instruction in the text is `module_init`'s own `sub rsp, 8`.  main's rsp
    fixpoint therefore bled into a DIFFERENT function and graded its four runtime calls at a spine floor of -8,
    which read as twelve OFF-GRID sites over the SNOBOL4 witnesses.  They are not off the grid; they are not
    main's frame at all.  A frame's spine displacement describes one activation, and the edge that crosses into
    another is not a control-flow edge of that activation.  The rule is written on the call target rather than on
    `exit` because it is the structural fact and covers every emitter that lays one function after another."""
    entries = set()
    for ins in insns:
        if ins.mnem == "call" and ins.ops:
            tgt = ins.ops[0].split("@")[0].strip()
            if tgt in label_at:
                entries.add(label_at[tgt])
    for j in sorted(entries):
        if j == 0:
            continue
        prev = insns[j - 1]
        named = any(L in (prev.ops[0].split("@")[0].strip() if prev.ops else "") for L in insns[j].labels)
        if not named and j in succ.get(j - 1, ()):
            succ[j - 1] = [t for t in succ[j - 1] if t != j]
    return len(entries)


def grid_verdict(k, pad=0):
    """ON-GRID when a spine floor k bytes from the region base falls on the 16-byte descriptor-cell grid.

    ARCH-GC section 2b Rule 1a and section 7 F1 say the spine is TAGGED CELLS ONLY and that the collector "walks
    the spine from RSP to its base as an array of cells, reading tags: precise, path-independent, no map, no
    sniff, no guess".  gc_heap.c does not walk an array: gc_walk_words steps EIGHT bytes at a time and tries
    gc_cell_visit at every step, so what it finds depends on where the walk happened to land -- which is the one
    thing CEO-812 says the collector may never do.  A grid walk is only available to it if the emitter puts every
    cell start on one grid anchored at the region base, and that is a property of EMITTED CODE, which is this
    seat's lane and this census's job to measure rather than assume."""
    if k % CELL == 0:
        return "ON-GRID"
    return "PAD-ALIGNED" if pad else "OFF-GRID"


def alignment_pad_at(insns, i, k):
    """the bytes of a BRACKETED, UNSTORED ABI alignment pad that fully explains an off-grid floor at the call at i.

    ⛔⭐ WHY A THIRD VERDICT EXISTS RATHER THAN A LOOSER SECOND ONE (cto 2026-09-21).  The fixed-symbol base fact
    un-blinded 390 call sites, and the first ten of them read OFF-GRID at floor=-8 residue=8 -- the exact
    fingerprint of the arithmetic slip that once announced 142 false OFF-GRID sites, so the reading was taken to
    the emitted text before it was taken anywhere else.  It is not a slip.  All ten are one shape in one graph:

        sub rsp, 8 | <stores to FIXED SYMBOLS only> | call ... | add rsp, 8

    The floor really IS eight bytes below the grid at the call, so calling it ON-GRID would be a lie.  But the
    eight bytes are a pure System V alignment pad: the walk proves NOTHING IS STORED INTO THEM, so no descriptor
    cell lives there and the grid the collector walks is untouched.  Announcing those ten as emitter defects and
    silencing them are both wrong, and the difference between them is measurable rather than editorial -- which
    is the whole content of the coo's rule that an instrument whose own error yields a finding must separate the
    two BEFORE it speaks.  So the pad is its own verdict, and `off_grid` keeps meaning what it meant.

    THE THREE CONDITIONS, ALL REQUIRED: a `sub rsp, K` dominates the call inside its own block with no store to
    `[rsp + ...]` between it and the call; removing K puts the floor back ON the cell grid, so the pad is the
    WHOLE explanation and not a coincidence; and a matching `add rsp, K` closes it before the block ends, which
    is what makes it a pad rather than a spine the graph keeps."""
    if k is None or k % CELL == 0:
        return 0
    pad = None
    for j in range(i - 1, max(-1, i - 24), -1):
        ins = insns[j]
        if ins.mnem == "sub" and len(ins.ops) == 2 and ins.ops[0].strip() == "rsp" and IMM_RX.match(ins.ops[1].strip()):
            pad = int(ins.ops[1].strip()); break
        if ins.mnem == "call":
            return 0
        if ins.mnem in WRITES_MEMORY and ins.ops and "[" in ins.ops[0] and disp_of(ins.ops[0])[0] == "rsp":
            return 0
        if ins.mnem == "push" or (ins.mnem == "add" and ins.ops and ins.ops[0].strip() == "rsp"):
            return 0
        if ins.labels:
            return 0
    if not pad or (k + pad) % CELL != 0:
        return 0
    for j in range(i + 1, min(len(insns), i + 12)):
        ins = insns[j]
        if ins.mnem == "add" and len(ins.ops) == 2 and ins.ops[0].strip() == "rsp" and ins.ops[1].strip() == str(pad):
            return pad
        if ins.mnem == "call" or ins.labels:
            return 0
    return 0


def grid_sites(insns, frames):
    """every emitted call graded against its graph's cell grid: [(graph, insn index, floor, why-undecidable)].

    WHY EVERY CALL AND NOT ONLY THE POLLS.  A collection begins at an emitted poll (rt_gc_poll) and, until section
    7 F4's shielded rt_gc_point_arr sites retire, inside any runtime call that allocates.  Both are `call`
    instructions, so the population that decides whether the collector could walk by grid is EVERY call reached
    from the graph's own map-cell anchor -- grading only the polls would read green over the sites F4 names as
    still collecting."""
    rows = []
    for g, f in frames.items():
        for i, st in f["frame"].items():
            if insns[i].mnem != "call" or not st:
                continue
            if f["blob"]:
                rows.append((g, i, None, "BLOB-FRAME-RBP-ANCHORED"))
                continue
            vals = {None if rsp is None else rsp - f["cell"] + f["value_bytes"] for rsp, *_ in st}
            if None in vals:
                rows.append((g, i, None, "SPINE-DEPTH-UNKNOWN"))
            elif len(vals) != 1:
                rows.append((g, i, None, "SPINE-DEPTH-MULTI-VALUED"))
            else:
                rows.append((g, i, next(iter(vals)), None))
    return rows


def build_frames(asm_path, report_text, tag):
    """(insns, succ, maps, layouts, frames, refusal) -- THE ONE MAP READER, shared rather than copied.

    ⛔ WHY THIS IS A FUNCTION AND NOT A PARAGRAPH REPEATED IN THE NEXT INSTRUMENT (INSTRUMENT LAWS batch 30
    clause 1).  Every term here is a fact about the emitted text that took a landing to get right -- the entry
    fallthrough trim of trim_entry_fallthrough, the ARCH-GC 6.2d mangling, the refusal when a map label matches
    no graph, the set-valued rsp fixpoint.  A second reader that re-derives them re-derives their bugs, and the
    two would then disagree about which graph owns a site while both printed a confident number.  The safe-point
    CONTRACT checker (util_gc_safe_point_contract.py) asks a DIFFERENT question of the SAME reading, and that is
    exactly the split this function draws: the reading is shared, the question is not.

    ⛔ AND THE BOUNDARY THAT COMES WITH IT, WRITTEN HERE BECAUSE IT COST THE cto TWENTY MINUTES ON 2026-09-21.
    shielded_stores() below walks BACKWARD from a poll and stops at a control transfer, which is right for ITS
    question -- the stores that precede this poll ON EVERY PATH.  Read as the section 3 contract instead, it
    printed 1784 of 2275 call results NEVER STORED, 78 percent, a catastrophe that is not true: hb_aggt.icn
    stores rax into [rbp+752], a MAPPED slot, four instructions before its poll, with a `cmp al,104 / je`
    between -- and the branch is where the backward walk stopped.  A shared reader's REACH BOUNDARY is not the
    property being measured, and inheriting the boundary while asking a different question is how a measurement
    becomes a fiction that reads like a five-alarm fire (the ceo's CEO-1019 lesson, one level over)."""
    insns = CS.parse(asm_path)
    for ins in insns:
        if ins.labels and any(str(L).startswith(".Lgcsite_") for L in ins.labels):
            ins.labels = tuple(L for L in ins.labels if not str(L).startswith(".Lgcsite_"))
    if not insns:
        return None, None, None, None, None, f"{tag}: {asm_path} parsed to zero instructions -- not measured"
    succ, top, label_at = CS.build_cfg(insns)
    trim_entry_fallthrough(insns, succ, label_at)
    maps = GCC.read_gcmaps(report_text)
    layouts = read_layouts(report_text)
    if not maps:
        return None, None, None, None, None, f"{tag}: the emitter printed no [GC-MAP] line -- nothing to measure"
    symbase = fixed_symbol_store_bases(insns)
    by_label = {mangle(g): g for g in maps}
    by_label.update({lab[len(".Lgcmap_"):]: g for g, lab in GCC.read_gcmap_labels(report_text).items() if g in maps and lab.startswith(".Lgcmap_")})
    frames, unmatched = {}, []
    for lbl, (ai, base, cell) in find_anchors(insns).items():
        g = by_label.get(lbl)
        if g is None:
            unmatched.append(lbl)
            continue
        m = maps[g]
        frames[g] = {"base": base, "cell": cell, "value_bytes": m["value_bytes"], "frame_bytes": m["frame_bytes"],
                     "blob": bool(m["flags"] & 4), "layout": layouts.get(g, []),
                     "frame": frame_fixpoint(insns, succ, ai, seed_rbp(insns, ai), symbase)}
    if unmatched:
        return None, None, None, None, None, (f"{tag}: {len(unmatched)} map label(s) match no graph in the report "
                                        f"({', '.join(sorted(unmatched)[:4])}) -- the mangling fact of ARCH-GC 6.2d "
                                        "is not being read correctly and every site under them would read green by accident")
    return insns, succ, maps, layouts, frames, None


def census_asm(asm_path, report_text, tag, out=print):
    """read one emitted program; returns (members, undecidable, examined, refusal, grid, reach, join)"""
    insns, succ, maps, layouts, frames, refusal = build_frames(asm_path, report_text, tag)
    if refusal:
        return None, None, 0, refusal, None, None, None
    members, undecidable, examined = [], [], 0
    unread, sites, spills, spill_cells = collections.Counter(), 0, 0, []
    shield_by_graph = collections.Counter()
    for i, ins in enumerate(insns):
        if not (ins.mnem == "call" and ins.ops and any(p in ins.ops[0] for p in POLL_NAMES)):
            continue
        lbl = site_label(insns, i)
        sites += 1
        sp = spill65b_at(insns, i)
        if sp:
            spills += 1
            for jj in sorted(sp):
                for base, d, src in _store_of(insns[jj]):
                    g, k, why = owner_of(base, d, i, frames)
                    if why:
                        spill_cells.append((tag, g or "-", lbl, ins.line, f"[{base}{d:+d}]", "UNDECIDABLE", why, src))
                    else:
                        f = frames[g]
                        spill_cells.append((tag, g, lbl, ins.line, f"{k:+d}", classify(k, f["layout"], f["value_bytes"], f["blob"]), "", src))
        frame_st, static_st = shielded_stores(insns, i, sp or frozenset())
        for sym, off, _src in static_st:
            unread[(sym, off)] += 1
        for base, d, src in frame_st:
            g, k, why = owner_of(base, d, i, frames)
            if g in frames:
                shield_by_graph[g] += 1
            examined += 1
            if why:
                undecidable.append((tag, g or "-", lbl, ins.line, f"[{base}{d:+d}]", why))
                continue
            f = frames[g]
            v = classify(k, f["layout"], f["value_bytes"], f["blob"])
            if v != "MAPPED":
                members.append((tag, g, lbl, ins.line, k, v, src))
    join = []
    for g, m in maps.items():
        if layouts.get(g, []):
            continue
        reached = g in frames
        n = shield_by_graph[g] if reached else 0
        join.append((tag, g, reached, n, m["value_bytes"], join_verdict(reached, n)))
    graded = grid_sites(insns, frames)
    grid = [(tag, g, site_label(insns, i), insns[i].line, k,
             grid_verdict(k, alignment_pad_at(insns, i, k)) if k is not None else None, why)
            for g, i, k, why in graded]
    reached = {i for _, i, _, _ in graded}
    unreached = sum(1 for i, ins in enumerate(insns) if ins.mnem == "call" and i not in reached)
    return members, undecidable, examined, None, (grid, unreached), (unread, sites, spills, spill_cells), join


def emit_and_read(scrip, prog, workdir, env_extra=None):
    """compile one program to asm and capture the emitter's map report; returns (asm path, report text, error)"""
    base = os.path.basename(prog)
    asm = os.path.join(workdir, base + ".s")
    env = dict(os.environ)
    env["SCRIP_GC_MAPS_REPORT"] = "1"
    env.setdefault("SCRIP_HEAP_MB", "1")
    if env_extra:
        env.update(env_extra)
    try:
        r = subprocess.run([scrip, "--compile", prog], capture_output=True, text=False, env=env,
                           timeout=180, stdin=subprocess.DEVNULL)
        # ⛔ measured 2026-09-21: adversarial__a14_conversion and rung36_jcon_evalx deliberately embed raw
        # high-byte string literals (escape/encoding stress tests), which the emitter carries verbatim into
        # a .string directive. text=True's strict UTF-8 decode raised UnicodeDecodeError on ONE of 826
        # entries and took the whole census down before it printed a verdict line -- silently, since the
        # caller reads rc and a grep for the verdict, neither of which named a traceback. Decode leniently.
        out = r.stdout.decode("utf-8", errors="replace")
        err = r.stderr.decode("utf-8", errors="replace")
    except (OSError, subprocess.TimeoutExpired) as e:
        return None, None, f"{base}: --compile failed: {e}"
    except Exception as e:
        # cto, on this landing: this function's contract is to RETURN an error, never to raise. errors=
        # "replace" means decode itself can no longer throw, but widen the net anyway so the next
        # unforeseen failure in this block names itself in the census instead of taking it down silently.
        return None, None, f"{base}: --compile capture/decode failed unexpectedly: {e}"
    if r.returncode != 0 or not out.strip():
        return None, None, f"{base}: --compile rc={r.returncode} with {len(out)} bytes of asm -- not measured"
    with open(asm, "w", encoding="utf-8") as fh:
        fh.write(out)
    return asm, err, None


VERDICTS = ("BELOW-REGION", "RAW-SLOT", "GAP", "ABOVE-REGION", "OUTSIDE-LAYOUT", "NO-MAP")

BASELINE_HEADER = (
    "# gc_unmapped_store_baseline.tsv -- the PER-WITNESS ratchet of the unmapped-store class (cto, row\n"
    "# gc-the-planner-gives-a-call-result-live-across-a-safe-point-...).  Written by\n"
    "# `util_gc_unmapped_store_census.py <witnesses> --write-baseline <this file>` in the landing that earns a move.\n"
    "# ONE LINE PER WITNESS AND NEVER A TOTAL, on hq_snobol4's measurement of 2026-09-20: the population is a\n"
    "# directory glob, so nine witnesses arriving would move a total from 162 to 192 and the arm would print THE\n"
    "# CLASS GREW and name a compiler regression it never measured.  A witness ARRIVING is a file addition; a\n"
    "# witness's own numbers MOVING is the thing this row exists to catch, and only a name set can tell them apart.\n"
    "# THE FIFTH COLUMN IS THIS CENSUS'S OWN REACH (cto 2026-09-20): stores shielded at a safe point into a\n"
    "# FIXED SYMBOL rather than into the frame.  It is ratcheted because shielding MOVING from the graded road\n"
    "# to the unread one is a loss of coverage that every other number here reads as an improvement.\n"
    "# witness\tmembers\tundecidable\tshielded\tunread_static\n")


def clean_reading_note(mem, und, unread, shielded):
    """the sentence a language row owes when its zero rests on something it did not read.

    ⛔ A ZERO HAS TO BE A ZERO SOMEBODY COULD HAVE FAILED.  Three different things spell `members=0` and only one
    of them is clean: nothing was found over a population that was read (clean), sites were refused as undecidable
    (unmeasured there), and shielding rode a road this census does not read at all (unmeasured everywhere).  The
    third is the one raku read for a whole day."""
    if mem != 0:
        return ""
    why = []
    if und:
        why.append(f"{und} undecidable site(s)")
    if unread:
        why.append(f"{unread} store(s) shielded into a fixed symbol, which this census does not grade")
    if not shielded:
        why.append("ZERO frame stores were graded at all")
    if not why:
        return ""
    return "  -- ZERO MEMBERS HERE IS NOT A CLEAN READING: " + "; ".join(why)


def report(scrip, progs, workdir, out=print):
    """THE CENSUS.  rc 0 green, 1 red (members named), 2 refused (could not measure)."""
    if not progs:
        out("CENSUS unmapped-store REFUSED(2): no witness named -- a census over an empty population reads zero by never looking")
        return 2
    all_members, all_undec, examined, graphs_seen, all_grid = [], [], 0, set(), []
    all_join = []
    unreached_calls = 0
    per_witness = {}
    all_unread, all_sites, all_spills, spill_by, all_cells = collections.Counter(), 0, 0, {}, []
    for prog in progs:
        tag = os.path.basename(prog)
        if os.path.isdir(prog):
            out(f"CENSUS unmapped-store REFUSED(2): {prog} is a DIRECTORY and this census takes an expanded FILE "
                "LIST. A directory handed here is read as ONE witness, the compile fails with rc=3 and zero bytes "
                "of asm, and the refusal that follows names a COMPILER FAILURE for what is an argument shape "
                "(hq_snocone 2026-09-20, who paid for it). Expand the glob before passing it."); return 2
        if not os.path.exists(prog):
            out(f"CENSUS unmapped-store REFUSED(2): witness {prog} missing"); return 2
        asm, rep, err = emit_and_read(scrip, prog, workdir)
        if err:
            out(f"CENSUS unmapped-store REFUSED(2): {err}"); return 2
        members, undec, ex, refusal, grid, reach, join = census_asm(asm, rep, tag, out=out)
        if refusal:
            out(f"CENSUS unmapped-store REFUSED(2): {refusal}"); return 2
        graphs_seen |= {(tag, g) for g in GCC.read_gcmaps(rep)}
        all_members += members; all_undec += undec; examined += ex
        all_grid += grid[0]; unreached_calls += grid[1]
        all_unread += reach[0]; all_sites += reach[1]; all_join += join
        all_spills += reach[2]; spill_by[tag] = reach[2]; all_cells += reach[3]
        per_witness[tag] = (len(members), len(undec), ex, sum(reach[0].values()), reach[1])
    off = [r for r in all_grid if r[5] == "OFF-GRID"]
    on = [r for r in all_grid if r[5] == "ON-GRID"]
    pads = [r for r in all_grid if r[5] == "PAD-ALIGNED"]
    und_grid = collections.Counter(r[6] for r in all_grid if r[5] is None)
    for tag, g, lbl, line, k, v, why in sorted(off, key=lambda r: (r[0], r[1], r[3])):
        out(f"CENSUS unmapped-store GRID OFF-GRID witness={tag} graph={g} site={lbl} line={line} "
            f"floor={k:+d} residue={k % CELL}")
    for tag, g, lbl, line, k, v, why in sorted(pads, key=lambda r: (r[0], r[1], r[3])):
        out(f"CENSUS unmapped-store GRID PAD-ALIGNED witness={tag} graph={g} site={lbl} line={line} "
            f"floor={k:+d} residue={k % CELL} -- a bracketed System V alignment pad holding no store, so the "
            "floor is genuinely off the grid and NO DESCRIPTOR CELL LIVES IN IT")
    for w, n in sorted(und_grid.items(), key=lambda kv: -kv[1]):
        out(f"CENSUS unmapped-store GRID-UNDECIDABLE-REASON {w} n={n}")
    out(f"CENSUS unmapped-store GRID calls={len(all_grid)} on_grid={len(on)} off_grid={len(off)} "
        f"pad_aligned={len(pads)} undecidable={sum(und_grid.values())} unreached={unreached_calls} cell={CELL}")
    out("CENSUS unmapped-store GRID MEANS EXACTLY THIS AND NOT THAT THE CLASS IS CURED: every call graded ON-GRID "
        "begins its collection with the emitted spine floor on the 16-byte descriptor-cell grid anchored at the "
        "region base, so the walk of [floor, base) could read each cell AT ITS START by stepping the grid -- the "
        "array-of-cells walk ARCH-GC 2b Rule 1a and 7 F1 describe. It does not: gc_walk_words steps 8 bytes and "
        "tries gc_cell_visit at every step, which is a guess about where a cell begins (CEO-812 forbids exactly "
        "that) and is why a tag the recognizer does not know is a LOST value and a zero word pair could be a "
        "SPURIOUS one. An OFF-GRID call is a site where no grid walk is available at all and the guess is the "
        "only road, so it is named here rather than counted.")
    jc = collections.Counter(j[5] for j in all_join)
    for tag, g, reached, n, region, v in sorted(all_join, key=lambda j: (j[5] != "MEMBER", j[0], j[1])):
        out(f"CENSUS unmapped-store JOIN {v} witness={tag} graph={g} region_bytes={region} "
            f"shielded_at_safe_points={n}")
    if not all_join:
        out(f"CENSUS unmapped-store JOIN-SUMMARY zero_entry_map_graphs=0 over {len(progs)} witness(es) -- NO GRAPH "
            "IN THIS POPULATION REGISTERS A FRAME MAP WITH NO LAYOUT ENTRY, so this population says nothing about "
            "the class either way. An absent population is not a clean one.")
    else:
        out(f"CENSUS unmapped-store JOIN-SUMMARY zero_entry_map_graphs={len(all_join)} MEMBER={jc['MEMBER']} "
            f"BENIGN={jc['BENIGN']} NOT-REACHED={jc['NOT-REACHED']} -- THE JOIN IS THE CORRECTNESS QUESTION AND "
            "NOT THE CENSUS OF ZERO-ENTRY MAPS: a graph that registers a map with no layout entry has NO mapped "
            "slot for any offset, so EVERY frame-shielded store at a safe point in it is unmapped BY "
            "CONSTRUCTION, whatever the offset -- which is why a MEMBER here is decidable where the offset-wise "
            "census is not. A BENIGN graph shields nothing at a safe point and its empty map is correct. A "
            "NOT-REACHED graph was never examined by the anchor walk and IS NOT BENIGN: a zero over a graph "
            "nobody looked at is the fourth way a zero fails to be a zero, one graph at a time.")
    if examined == 0 and not all_cells:
        out("CENSUS unmapped-store REFUSED(2): zero shielded stores examined over "
            f"{len(progs)} witness(es) -- a zero has to be a zero somebody could have failed"); return 2
    counts = collections.Counter(m[5] for m in all_members)
    for tag, g, lbl, line, k, v, src in sorted(all_members, key=lambda m: (m[0], m[1], m[3])):
        out(f"CENSUS unmapped-store MEMBER {v} witness={tag} graph={g} site={lbl} line={line} off={k:+d} src={src}")
    for tag, g, lbl, line, at, why in sorted(all_undec, key=lambda m: (m[0], m[3])):
        out(f"CENSUS unmapped-store UNDECIDABLE {why} witness={tag} graph={g} site={lbl} line={line} at={at}")
    named = len(all_members)
    total = sum(counts.values())
    if named != total:
        out(f"CENSUS unmapped-store REFUSED(2): counted {total} member(s) and printed {named} name(s) -- a count "
            "without its names is a work list nobody can pick up (CTO-96, INSTRUMENT LAWS batch 30 clause 2)")
        return 2
    per = collections.defaultdict(lambda: [0, 0, 0, 0, 0])
    for m in all_members:
        per[m[0].rsplit(".", 1)[-1]][0] += 1
    for u in all_undec:
        per[u[0].rsplit(".", 1)[-1]][1] += 1
    for prog in progs:
        lang = os.path.basename(prog).rsplit(".", 1)[-1]
        per[lang][2] += 1
        w = per_witness.get(os.path.basename(prog))
        if w:
            per[lang][3] += w[2]
            per[lang][4] += w[3]
    for lang in sorted(per):
        mem, und, wit, shielded, unrd = per[lang]
        out(f"CENSUS unmapped-store LANG {lang} witnesses={wit} members={mem} undecidable={und} "
            f"shielded={shielded} unread_static={unrd}{clean_reading_note(mem, und, unrd, shielded)}")
    why = collections.Counter(u[5] for u in all_undec)
    for w, n in sorted(why.items(), key=lambda kv: -kv[1]):
        out(f"CENSUS unmapped-store UNDECIDABLE-REASON {w} n={n}")
    out("CENSUS unmapped-store WHY NO-ANCHOR-REACHES-SITE IS A LIMIT AND NOT A GUESS TO BE PAPERED OVER: the wired "
        "regime enters those boxes through an INDIRECT jump, so no path from the frame's own prologue reaches them "
        "in the emitted CFG. Attributing them by textual containment inside the FN__ region was tried and REFUSED "
        "on measurement -- all 159 Prolog function regions of hb_wsb_pl_atom_dup.pl re-point rbp away from their "
        "own frame at least once (mov rbp, [rbp+N] and mov rbp, rax), so containment would grade a store against a "
        "frame that is not the one it lands in. Making these sites decidable is part of the cure, not of the census.")
    for tag in sorted(per_witness):
        mem, und, ex, unrd, sites = per_witness[tag]
        out(f"CENSUS unmapped-store WITNESS {tag} members={mem} undecidable={und} shielded={ex} unread_static={unrd}")
    for tag in sorted(spill_by):
        if spill_by[tag]:
            out(f"CENSUS unmapped-store SPILL-6.5B-WITNESS witness={tag} polls={spill_by[tag]} stores={3 * spill_by[tag]}")
    for tag, g, lbl, line, at, v, why, src in sorted(all_cells, key=lambda c: (c[0], c[3], c[4])):
        out(f"CENSUS unmapped-store SPILL-6.5B {v}{(' ' + why) if why else ''} witness={tag} graph={g} site={lbl} line={line} off={at} src={src}")
    cv = collections.Counter(c[5] for c in all_cells)
    unmapped_cells = sum(n for v, n in cv.items() if v not in ("MAPPED", "UNDECIDABLE"))
    out(f"CENSUS unmapped-store SPILL-6.5B-SUMMARY polls={all_spills} stores={3 * all_spills} cells_unmapped={unmapped_cells} "
        f"cells_undecidable={cv['UNDECIDABLE']} cells_mapped={cv['MAPPED']} witnesses={sum(1 for v in spill_by.values() if v)} of {len(spill_by)} -- "
        "the ARCH-GC 6.5b spill (sub rsp,32 / the r13 word and the result cell / call rt_gc_point_arr_probe_c / three loads / add rsp,32): the box's result DESCR held "
        "across the poll below the region base and visited by the spine sweep by its tag. GRADED AND NAMED ABOVE, KEPT OUT OF THE "
        "PER-WITNESS COLUMNS the baseline ratchets (the cfo's ruling of 2026-10-04 on the c869d57c1 move: re-keying them as members "
        "would bless any real below-region store landing beside them) and NEVER FOLDED INTO GREEN: an unmapped cell keeps this census "
        "red and counts in the gate's arm (h) beside the members, because a call result held across a safe point outside the map is "
        "the very class the planner cure exists to end.")
    for (sym, off), n in sorted(all_unread.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        out(f"CENSUS unmapped-store UNREAD-ROAD symbol={sym}+{off} stores={n} -- shielded at a safe point into a "
            "FIXED SYMBOL, which no frame map can ever cover and no planner cure can reach; its safety rests "
            "entirely on whether the collector's root set covers THAT WORD, typed")
    out(f"CENSUS unmapped-store UNREAD-ROAD symbols={len({k[0] for k in all_unread})} "
        f"words={len(all_unread)} stores={sum(all_unread.values())} -- ⛔ NAMED BY WORD AND NOT BY SYMBOL SINCE "
        "2026-09-21 (ceo CEO-1042's condition on arm (h)): a criterion whose selling point is that it ADMITS the "
        "stores the old count could not see, and which then cannot READ them, is a zero over an unmeasured "
        "population. A symbol-wide count cannot say WHICH WORD a collector must visit, so it could never have "
        "adjudicated the road it was measuring the size of.")
    out(f"CENSUS unmapped-store REACH safe_points={all_sites} frame_shielded={examined} "
        f"static_shielded={sum(all_unread.values())} -- THE SECOND NUMBER IS THE ONLY ONE THIS CENSUS GRADES. "
        "⛔ THE THIRD WAS DROPPED ON THE FLOOR UNTIL 2026-09-20 AND THE SELFTEST ARM THAT PROVED IT WAS DROPPED "
        "(`disp_of refuses a rip-relative operand`) IS THE ARM THAT SHOULD HAVE COUNTED IT: the refusal was "
        "deliberate and correct, and its CONSEQUENCE -- that a language whose shielding rides the static road "
        "reads members=0 undecidable=0, which is spelled exactly like clean -- was never measured. Raku read "
        "CLEAN and DECIDED COMPLETELY in three published cursor entries on 8 frame stores while 207 of its "
        "shielded stores at safe points went unread.")
    out("CENSUS unmapped-store WHY THE PER-WITNESS LINES EXIST (hq_snobol4 2026-09-20, measured against this "
        "census before landing rather than discovered afterwards): the ratchet's population is a DIRECTORY GLOB "
        "over ../harness/scripts/gc_witnesses, so a colleague landing nine oracle-cut witnesses of their own would move a "
        "TOTAL from 162 to 192 and the arm would print THE CLASS GREW and name a cause it never measured -- a "
        "well-formed answer to a question nobody asked. A total cannot tell a compiler regression from a file "
        "arriving. These lines are the name set the arm ratchets, one per witness, which is this row's own "
        "NAME-NEVER-A-COUNT rule applied one level down from where it was first applied.")
    out("CENSUS unmapped-store THE GRAPH COUNT IS KEYED BY (witness, graph) AND NOT BY GRAPH NAME (hq_snocone "
        "2026-09-20, who read graphs=1 over 336 snocone rungs entries because EVERY entry's graph is called main "
        "and graphs_seen was a set union of NAMES). A name collision across witnesses is not a population, and a "
        "census whose denominator collapses to 1 over 336 programs is reporting the wrong denominator even where "
        "nothing in the reading rests on it.")
    out(f"CENSUS unmapped-store witnesses={len(progs)} graphs={len(graphs_seen)} shielded_stores={examined} "
        f"members={named} undecidable={len(all_undec)} "
        + " ".join(f"{v}={counts.get(v, 0)}" for v in VERDICTS))
    out("CENSUS unmapped-store NOT MEASURED HERE AND NAMED: class 3 of ARCH-GC section 3c -- a raw heap pointer "
        "returned in a REGISTER PAIR (cfo CFO-134). A frame map describes memory, so the class presents no store "
        "target to classify; this census cannot see it and does not report zero for it.")
    if named or all_undec or any(c[5] != "MAPPED" for c in all_cells):
        return 1
    return 0


def _selftest_frame_whack():
    """the floor of the call after a `mov rsp, rbp / pop rbp` frame whack, off a hand-built graph"""
    import tempfile
    asm = (".text\n"
           "main_bx:\n"
           "        sub rsp, 64\n"
           "        mov eax, 0 # GCANCHOR .Lgcmap_main qword ptr [rsp + 24]\n"
           "        push rbp\n"
           "        mov rbp, rsp\n"
           "        sub rsp, 32\n"
           "        mov rsp, rbp\n"
           "        pop rbp\n"
           "        call rt_gc_poll@PLT\n"
           "        ret\n")
    rep = ("[GC-MAP] graph=main frame_bytes=64 header_bytes=0 value_bytes=16 flags=9\n"
           "[GC-MAP-LAYOUT] graph=main n=1 0:0:16 gaps=0 conflicts=0\n")
    with tempfile.TemporaryDirectory() as wd:
        path = os.path.join(wd, "whack.s")
        open(path, "w", encoding="utf-8").write(asm)
        insns, succ, maps, layouts, frames, refusal = build_frames(path, rep, "whack")
        if refusal:
            return refusal
        for (g, i, k, why) in grid_sites(insns, frames):
            if insns[i].mnem == "call":
                return why or k
    return "NO-CALL-GRADED"


def _selftest_align_window(alias):
    """the two calls of an x86_align_call_enter window, graded off a hand-built graph.

    Returns (verdict inside the window, verdict after the restore).  `alias` plants ONE store this reader cannot
    place -- `mov qword ptr [rbp + 8], rax` -- between the park and the restore, which MUST discard the shadow and
    send the second call back to SPINE-DEPTH-UNKNOWN.  Without that negative arm the aliasing discipline in
    slot_effect() is a paragraph rather than a property: a shadow that survived an unplaceable write would grade
    the same green here and be a guess everywhere else."""
    import tempfile
    asm = (".text\n"
           "main_bx:\n"
           "        sub rsp, 64\n"
           "        mov eax, 0 # GCANCHOR .Lgcmap_main qword ptr [rsp + 24]\n"
           "        mov r11, rsp\n"
           "        and rsp, -16\n"
           "        sub rsp, 16\n"
           "        mov qword ptr [rsp + 0], r11\n"
           + ("        mov qword ptr [rbp + 8], rax\n" if alias else "") +
           "        call rt_gc_point_arr_c@PLT\n"
           "        mov rsp, qword ptr [rsp + 0]\n"
           "        call rt_gc_poll@PLT\n"
           "        ret\n")
    rep = ("[GC-MAP] graph=main frame_bytes=64 header_bytes=0 value_bytes=16 flags=9\n"
           "[GC-MAP-LAYOUT] graph=main n=1 0:0:16 gaps=0 conflicts=0\n")
    with tempfile.TemporaryDirectory() as wd:
        path = os.path.join(wd, "align.s")
        open(path, "w", encoding="utf-8").write(asm)
        insns, succ, maps, layouts, frames, refusal = build_frames(path, rep, "align")
        if refusal:
            return refusal, refusal
        got = [(why if why is not None else k) for (g, i, k, why) in grid_sites(insns, frames)
               if insns[i].mnem == "call"]
        return (got[0], got[-1]) if got else ("NO-CALL-GRADED", "NO-CALL-GRADED")


def _selftest_rbp_park_window(mid):
    """a park/restore pair keyed off rbp, graded off a hand-built graph; `mid` is one planted instruction.

    THE FOUR ARMS THIS ONE PLANT CARRIES, and none of them is a restatement of the rsp-keyed window's.  With no
    planted instruction it proves the ANCHOR key works at all: the mask poisons rsp, the call inside reads
    SPINE-DEPTH-UNKNOWN, and `mov rsp, qword ptr [rbp + 16]` re-establishes the depth a whole activation later.
    With an UNPLACEABLE store planted between park and restore (`[rax + 0]`, a base this reader cannot place
    against the anchor) the shadow must be discarded and the restore must stop being readable -- without that
    arm the aliasing discipline is a paragraph.  With a PLACEABLE store to a DIFFERENT cell the entry must
    SURVIVE, which is the precision half: a discipline that feared every write would grade the same green as
    one that places them and would be worthless on real code.  With a placeable store to the SAME cell the
    entry must DIE, which is what proves the invalidation is not a no-op."""
    import tempfile
    asm = (".text\n"
           "main_bx:\n"
           "        sub rsp, 64\n"
           "        mov eax, 0 # GCANCHOR .Lgcmap_main qword ptr [rsp + 24]\n"
           "        mov rbp, rsp\n"
           "        mov qword ptr [rbp + 16], rsp\n"
           "        and rsp, -16\n"
           "        call rt_gc_point_arr_c@PLT\n"
           + (f"        {mid}\n" if mid else "") +
           "        mov rsp, qword ptr [rbp + 16]\n"
           "        call rt_gc_poll@PLT\n"
           "        ret\n")
    rep = ("[GC-MAP] graph=main frame_bytes=64 header_bytes=0 value_bytes=16 flags=9\n"
           "[GC-MAP-LAYOUT] graph=main n=1 0:0:16 gaps=0 conflicts=0\n")
    with tempfile.TemporaryDirectory() as wd:
        path = os.path.join(wd, "rbppark.s")
        open(path, "w", encoding="utf-8").write(asm)
        insns, succ, maps, layouts, frames, refusal = build_frames(path, rep, "rbppark")
        if refusal:
            return refusal, refusal
        got = [(why if why is not None else k) for (g, i, k, why) in grid_sites(insns, frames)
               if insns[i].mnem == "call"]
        return (got[0], got[-1]) if got else ("NO-CALL-GRADED", "NO-CALL-GRADED")


def _selftest_pad_window(body, store_disp=24, value_bytes=16):
    """a hand-built graph whose call sits under a planted rsp adjustment; returns (floor, verdict)."""
    import tempfile
    asm = (".text\n"
           "main_bx:\n"
           "        sub rsp, 64\n"
           f"        mov eax, 0 # GCANCHOR .Lgcmap_main qword ptr [rsp + {store_disp}]\n"
           + body +
           "        ret\n")
    rep = (f"[GC-MAP] graph=main frame_bytes=64 header_bytes=0 value_bytes={value_bytes} flags=9\n"
           "[GC-MAP-LAYOUT] graph=main n=1 0:0:16 gaps=0 conflicts=0\n")
    with tempfile.TemporaryDirectory() as wd:
        path = os.path.join(wd, "pad.s")
        open(path, "w", encoding="utf-8").write(asm)
        insns, succ, maps, layouts, frames, refusal = build_frames(path, rep, "pad")
        if refusal:
            return refusal, refusal
        for (g, i, k, why) in grid_sites(insns, frames):
            if insns[i].mnem == "call":
                if k is None:
                    return why, why
                return k, grid_verdict(k, alignment_pad_at(insns, i, k))
    return "NO-CALL-GRADED", "NO-CALL-GRADED"


def selftest():
    """the arithmetic and the refusals, held against hand-built inputs rather than against a program's output"""
    ok = [0, 0]

    def arm(name, cond):
        ok[1] += 1
        ok[0] += 1 if cond else 0
        print(f"  {'ok  ' if cond else 'FAIL'} {name}")

    arm("disp_of reads the emitter's [rsp + -48] spelling", disp_of("qword ptr [rsp + -48]") == ("rsp", -48))
    arm("disp_of reads a bare [rsp]", disp_of("qword ptr [rsp]") == ("rsp", 0))
    arm("disp_of refuses a rip-relative operand", disp_of("qword ptr [rip + g_rtccb+40]") == (None, None))
    lay = [(0, 0, 144), (144, 1, 8), (152, 2, 16), (168, 1, 72), (240, 0, 176)]
    arm("classify: a DESCR entry is MAPPED", classify(0, lay, 416, False) == "MAPPED")
    arm("classify: a PTR_GC entry is MAPPED", classify(152, lay, 416, False) == "MAPPED")
    arm("classify: a RAW entry is a LIE, not a miss", classify(144, lay, 416, False) == "RAW-SLOT")
    arm("classify: below the region base is the witness class", classify(-24, lay, 416, False) == "BELOW-REGION")
    arm("classify: at or above value_bytes is the header", classify(416, lay, 416, False) == "ABOVE-REGION")
    arm("classify: a hole inside the region is a GAP", classify(200, [(0, 0, 16)], 416, False) == "GAP")
    arm("read_layouts parses the emitter's line",
        read_layouts("[GC-MAP-LAYOUT] graph=main n=2 0:0:16 16:1:8 gaps=0 conflicts=0")["main"] == [(0, 0, 16), (16, 1, 8)])
    arm("read_gcmaps is the harness's reader, not a copy",
        GCC.read_gcmaps("[GC-MAP] graph=main frame_bytes=432 header_bytes=0 value_bytes=416 flags=9")["main"]["value_bytes"] == 416)
    arm("report REFUSES an empty population", report("/nonexistent", [], "/tmp") == 2)
    arm("grid: a floor 32 bytes below the base is ON-GRID", grid_verdict(-32) == "ON-GRID")
    arm("grid: the witness's own pointer word at -24 is OFF-GRID as a floor", grid_verdict(-24) == "OFF-GRID")
    arm("grid: the region base itself is ON-GRID", grid_verdict(0) == "ON-GRID")
    arm("grid: an 8-byte push below the base takes the floor OFF-GRID", grid_verdict(-8) == "OFF-GRID")
    spill = CS.Insn(1, "mov qword ptr [rip + g_rtccb+40], r8", [])
    gated = [CS.Insn(1, "mov qword ptr [rsp + 0], rax", (".Lcall_a_1",)), CS.Insn(2, "mov qword ptr [rsp + 8], rdx", ()),
             CS.Insn(3, "push rax", ()), CS.Insn(4, "mov rax, qword ptr [rip + g_gc_pending@GOTPCREL]", ()),
             CS.Insn(5, "mov eax, dword ptr [rax + 0]", ()), CS.Insn(6, "test eax, eax", ()), CS.Insn(7, "pop rax", ()),
             CS.Insn(8, "je 1f", ()), CS.Insn(9, "mov qword ptr [rip + g_rtccb+40], r8", ()), CS.Insn(10, "call rt_gc_poll_asm@PLT", ())]
    arm("GATED POLL: the stores before the inline pending test are FOUND -- the je 1f skips only the poll body, so the walk steps over the six-instruction preamble as the poll's own",
        shielded_stores(gated, 9) == ([("rsp", 8, "rdx"), ("rsp", 0, "rax")], [("g_rtccb", 40, "r8")]))
    branched = list(gated); branched[7] = CS.Insn(8, "je .Lelse_1", ())
    arm("GATED POLL NEGATIVE: a real branch between the store and the poll still stops the walk -- the preamble is matched by all six texts, never by 'any je'",
        shielded_stores(branched, 9) == ([], [("g_rtccb", 40, "r8")]))
    reshaped = list(gated); reshaped[5] = CS.Insn(6, "test rax, rax", ())
    arm("GATED POLL RESHAPED: a gate whose test changed spelling is a stop again, not a silent skip",
        shielded_stores(reshaped, 9) == ([], [("g_rtccb", 40, "r8")]))
    joined = list(gated); joined[2] = CS.Insn(3, "push rax", (".Lpoll_entry",))
    arm("GATED POLL JOINED: a label on the preamble's own push is another path entering, so the walk stops after the gate and reads no store",
        shielded_stores(joined, 9) == ([], [("g_rtccb", 40, "r8")]))
    res = [CS.Insn(1, "mov qword ptr [rsp + 0], rax", (".Lcall_b_1",)), CS.Insn(2, "mov qword ptr [rsp + 8], rdx", ()),
           CS.Insn(3, "push rax", ()), CS.Insn(4, "mov rax, qword ptr [rip + g_gc_pending@GOTPCREL]", ()),
           CS.Insn(5, "mov eax, dword ptr [rax + 0]", ()), CS.Insn(6, "test eax, eax", ()), CS.Insn(7, "pop rax", ()),
           CS.Insn(8, "je 1f", ()), CS.Insn(9, "sub rsp, 32", ()), CS.Insn(10, "mov qword ptr [rsp + 0], r13", ()),
           CS.Insn(11, "mov qword ptr [rsp + 16], rax", ()), CS.Insn(12, "mov qword ptr [rsp + 24], rdx", ()),
           CS.Insn(13, "xor edi, edi", ()), CS.Insn(14, "xor esi, esi", ()), CS.Insn(15, "mov rdx, rsp", ()),
           CS.Insn(16, "lea rcx, [rsp + 16]", ()), CS.Insn(17, "mov qword ptr [rip + g_rtccb+40], r8", ()),
           CS.Insn(18, "call rt_gc_point_arr_probe_c@PLT", ()), CS.Insn(19, "mov r8,  qword ptr [rip + g_rtccb+40]", ()),
           CS.Insn(20, "mov r13, qword ptr [rsp + 0]", ()), CS.Insn(21, "mov rax, qword ptr [rsp + 16]", ()),
           CS.Insn(22, "mov rdx, qword ptr [rsp + 24]", ()), CS.Insn(23, "add rsp, 32", ()),
           CS.Insn(24, "mov qword ptr [rbp + 1280], rax", ("1",))]
    arm("6.5b SPILL: the exact shape names its three stores by POSITION, so the box's own identical result stores above the gate are still read",
        spill65b_at(res, 17) == frozenset((9, 10, 11)) and shielded_stores(res, 17, spill65b_at(res, 17)) == ([("rsp", 8, "rdx"), ("rsp", 0, "rax")], [("g_rtccb", 40, "r8")]))
    res_l = list(res); res_l[10] = CS.Insn(11, "mov qword ptr [rsp + 16], rax", (".Ljoin_9",))
    arm("6.5b NEGATIVE: a label on the result store is another path entering the shape, so it is NOT the cell and the stores are graded",
        spill65b_at(res_l, 17) is None)
    res_r = list(res); res_r[11] = CS.Insn(12, "mov qword ptr [rsp + 24], rcx", ())
    arm("6.5b NEGATIVE: a reshaped store (rcx, not rdx) is not the cell",
        spill65b_at(res_r, 17) is None)
    res_t = list(res); res_t[21] = CS.Insn(22, "mov rcx, qword ptr [rsp + 24]", ())
    arm("6.5b NEGATIVE: a spill whose tail does not reload r13, rax and rdx and release the 32 bytes is not the cell",
        spill65b_at(res_t, 17) is None)
    res_o = list(res); res_o[9] = CS.Insn(10, "mov qword ptr [rsp + 0], r12", ())
    arm("6.5b NEGATIVE: a spill that saves some other register for the subject word is not the cell",
        spill65b_at(res_o, 17) is None)
    arm("6.5b NEGATIVE: the plain gated poll (no spill) is not the cell", spill65b_at(gated, 9) is None)
    arm("a rip-relative shield is NAMED with its symbol and offset, not dropped",
        _static_store_of(spill) == [("g_rtccb", 40, "r8")])
    arm("the frame reader still REFUSES that same store -- the reach boundary is counted, never graded",
        _store_of(spill) == [])
    arm("a bare symbol with no offset reads as offset 0",
        _static_store_of(CS.Insn(1, "mov qword ptr [rip + scan_subj], rax", [])) == [("scan_subj", 0, "rax")])
    arm("a frame store is not mistaken for a static one",
        _static_store_of(CS.Insn(1, "mov qword ptr [rsp + 8], rdx", [])) == [])
    arm("ZERO MEMBERS over an UNREAD road is not a clean reading -- the raku case",
        "NOT A CLEAN READING" in clean_reading_note(0, 0, 207, 8))
    arm("ZERO MEMBERS over a read population with nothing unread IS clean",
        clean_reading_note(0, 0, 0, 242) == "")
    arm("grading NOTHING at all is named rather than read as clean",
        "ZERO frame stores" in clean_reading_note(0, 0, 0, 0))
    arm("a language with members named owes no zero-note", clean_reading_note(3, 9, 99, 99) == "")
    arm("JOIN: a zero-entry map over a graph that shields nothing at a safe point is BENIGN",
        join_verdict(True, 0) == "BENIGN")
    arm("rsp_assign reads `lea rsp, [rbp - 688]` as an ASSIGNMENT from a known rbp, never as an unknown",
        rsp_assign(CS.Insn(1, "lea rsp, [rbp - 688]", []), -16, -8) == -696)
    arm("rsp_assign reads `mov rsp, rbp`", rsp_assign(CS.Insn(1, "mov rsp, rbp", []), -16, -8) == -8)
    arm("rsp_assign RE-ESTABLISHES a known rsp from an UNKNOWN one -- undoing the poisoning is the whole point",
        rsp_assign(CS.Insn(1, "mov rsp, rbp", []), None, -8) == -8)
    arm("rsp_assign REFUSES an alignment mask, which is genuinely not a compile-time constant",
        rsp_assign(CS.Insn(1, "and rsp, -16", []), -16, -8) is NOT_AN_ASSIGNMENT)
    arm("rsp_assign REFUSES a restore from memory",
        rsp_assign(CS.Insn(1, "mov rsp, qword ptr [rsp + 0]", []), -16, -8) is NOT_AN_ASSIGNMENT)
    _win = _selftest_align_window(False)
    arm("PLANTED END TO END -- the call INSIDE an align-call window is undecidable and SAYS so, because the "
        "alignment mask is genuinely not a compile-time constant",
        _win[0] == "SPINE-DEPTH-UNKNOWN")
    arm("PLANTED END TO END -- `mov rsp, qword ptr [rsp + 0]` RESTORES the depth the mask destroyed, so the call "
        "AFTER the window reads floor=0 ON-GRID. This is the whole cure: the mask poisons every call downstream "
        "of it forever, and nothing but this read ever un-poisons (graded call sites 4487 -> 5295 over the 52 "
        "shared witnesses, off_grid 0 both sides)", _win[1] == 0)
    _alias = _selftest_align_window(True)
    arm("PLANTED NEGATIVE -- ONE store this reader cannot place inside the window DISCARDS the shadow and the "
        "restore stops being readable, so the aliasing discipline is a property and not a paragraph",
        _alias[1] == "SPINE-DEPTH-UNKNOWN")
    _park = _selftest_rbp_park_window("")
    arm("PLANTED END TO END -- the call inside the mask's poison is undecidable and says so, with the park "
        "already taken", _park[0] == "SPINE-DEPTH-UNKNOWN")
    arm("PLANTED END TO END -- `mov rsp, qword ptr [rbp + K]` RESTORES the depth from an ANCHOR-KEYED slot, so "
        "the call after it reads floor=0 ON-GRID. This form was the single blamed instruction behind 837 of the "
        "963 remaining SPINE-DEPTH-UNKNOWN sites over the 52 shared witnesses, against 107 for the still-"
        "unpaired `and rsp, -16`", _park[1] == 0)
    arm("PLANTED NEGATIVE -- an UNPLACEABLE store between park and restore discards the anchor shadow and the "
        "restore stops being readable, so the aliasing discipline is a property on this key too",
        _selftest_rbp_park_window("mov qword ptr [rax + 0], rcx")[1] == "SPINE-DEPTH-UNKNOWN")
    arm("PLANTED PRECISION -- a PLACEABLE store to a DIFFERENT cell leaves the entry standing, which is what "
        "separates placing a write from fearing it",
        _selftest_rbp_park_window("mov qword ptr [rbp + 8], rax")[1] == 0)
    arm("PLANTED INVALIDATION -- a placeable store to the SAME cell kills the entry, so the invalidation above "
        "is doing work rather than being a no-op that the precision arm would read as green",
        _selftest_rbp_park_window("mov qword ptr [rbp + 16], rax")[1] == "SPINE-DEPTH-UNKNOWN")
    _GOT = "mov rax, qword ptr [rip + g_line@GOTPCREL]\n        mov qword ptr [rax + 0], 4"
    arm("PLANTED POSITIVE -- a store through a base loaded from a GOT slot is PLACED, not feared: the address of "
        "a defined symbol is never a machine stack, so the anchor shadow survives and the restore stays readable. "
        "1303 of the 2044 unplaceable stores over the 52 witnesses are exactly this form",
        _selftest_rbp_park_window(_GOT)[1] == 0)
    arm("PLANTED POSITIVE -- `lea r, [rip + sym]` is the same fact with no load at all (284 of the 2044)",
        _selftest_rbp_park_window("lea rax, [rip + g_line]\n        mov qword ptr [rax + 0], 4")[1] == 0)
    arm("PLANTED NEGATIVE AND THIS IS THE ARM THAT MAKES THE FACT SOUND -- `lea r, [rsp + K]` puts a STACK "
        "address in a general register, so a store through it is feared exactly as before. There are FOUR of "
        "these in the same population, and a rule that placed every lea base would compute wrong depths at all "
        "four while printing them as discoveries",
        _selftest_rbp_park_window("lea rax, [rsp + 8]\n        mov qword ptr [rax + 0], 4")[1] == "SPINE-DEPTH-UNKNOWN")
    arm("PLANTED NEGATIVE -- a PLAIN rip-relative load reads a global's VALUE and not its address, so it is not "
        "the fact and is not accepted",
        _selftest_rbp_park_window("mov rax, qword ptr [rip + g_line]\n        mov qword ptr [rax + 0], 4")[1] == "SPINE-DEPTH-UNKNOWN")
    arm("PLANTED NEGATIVE -- a call between the GOT load and the store clobbers the caller-saved base, so the "
        "fact expires with it",
        _selftest_rbp_park_window("mov rax, qword ptr [rip + g_line@GOTPCREL]\n        call rt_gc_point_arr_c@PLT\n        mov qword ptr [rax + 0], 4")[1] == "SPINE-DEPTH-UNKNOWN")
    arm("GRID PAD -- a bracketed rsp pad holding no store takes the floor off the grid and reads PAD-ALIGNED, "
        "because the floor really is off the grid and NO DESCRIPTOR CELL LIVES IN THE PAD. Ten of the 400 "
        "newly graded sites are this shape, all in one graph, all at residue 8",
        _selftest_pad_window("        sub rsp, 8\n        call rt_gc_poll@PLT\n        add rsp, 8\n") == (-8, "PAD-ALIGNED"))
    arm("GRID PAD NEGATIVE -- a store INTO the pad means a cell can live there, so the site is OFF-GRID and the "
        "pad verdict is not a blanket amnesty for an 8-byte adjustment",
        _selftest_pad_window("        sub rsp, 8\n        mov qword ptr [rsp + 0], rcx\n        call rt_gc_poll@PLT\n        add rsp, 8\n") == (-8, "OFF-GRID"))
    arm("GRID PAD NEGATIVE -- an adjustment the block never closes is a spine the graph KEEPS, not a pad",
        _selftest_pad_window("        sub rsp, 8\n        call rt_gc_poll@PLT\n") == (-8, "OFF-GRID"))
    arm("GRID PAD NEGATIVE -- a pad that does not fully explain the residue leaves the site OFF-GRID, so the "
        "verdict rests on the arithmetic and not on the presence of a sub",
        _selftest_pad_window("        sub rsp, 16\n        call rt_gc_poll@PLT\n        add rsp, 16\n", store_disp=16) == (-8, "OFF-GRID"))
    arm("rsp_assign over an UNKNOWN rbp stays unknown rather than inventing a depth",
        rsp_assign(CS.Insn(1, "lea rsp, [rbp - 688]", []), -16, None) is None)
    _whack = _selftest_frame_whack()
    arm("PLANTED END TO END -- `mov rsp, rbp / pop rbp` is a frame whack and the POP's +8 lands on rsp: the call "
        "after it reads floor=0 ON-GRID. Without that the census reported 142 OFF-GRID sites at residue 8 across "
        "twelve SNOBOL4 witnesses, a defect in the EMITTER announced on an arithmetic slip in frame_fixpoint",
        _whack == 0)

    arm("JOIN: a zero-entry map in a graph that DOES shield is a MEMBER whatever the offset",
        join_verdict(True, 3) == "MEMBER")
    arm("JOIN: a graph the anchor walk never reached is NOT-REACHED and never benign",
        join_verdict(False, 0) == "NOT-REACHED")
    arm("JOIN: NOT-REACHED outranks a store count, because the count came from a walk that did not reach it",
        join_verdict(False, 5) == "NOT-REACHED")
    import tempfile as _tf
    with _tf.TemporaryDirectory(prefix="gc_join_plant_") as _d:
        _asm = os.path.join(_d, "plant.s")
        with open(_asm, "w", encoding="utf-8") as _fh:
            _fh.write("main:\n"
                      "\tmov eax, 0 # GCANCHOR .Lgcmap_main qword ptr [rsp + 8]\n"
                      "\tmov qword ptr [rsp + 16], rdx\n"
                      "\tcall rt_gc_poll\n"
                      "\tret\n")
        _rep = "[GC-MAP] graph=main frame_bytes=64 header_bytes=48 value_bytes=0 flags=1\n"
        _j = census_asm(_asm, _rep, "plant.s", out=lambda *_a, **_k: None)[6]
        arm("JOIN PLANTED END TO END: a hand-built graph with a zero-entry map and a shielded store reads MEMBER, "
            "so every BENIGN above comes from a road whose MEMBER arm has fired",
            _j == [("plant.s", "main", True, 1, 0, "MEMBER")])
        _rep2 = _rep + "[GC-MAP-LAYOUT] graph=main n=1 0:0:64 gaps=0 conflicts=0\n"
        _j2 = census_asm(_asm, _rep2, "plant.s", out=lambda *_a, **_k: None)[6]
        arm("JOIN PLANTED NEGATIVE: the same asm with ONE layout entry leaves the join population empty, so the "
            "verdict tracks the map and not the stores", _j2 == [])
    print(f"SELFTEST {ok[0]}/{ok[1]} arms green")
    return 0 if ok[0] == ok[1] else 1


def main(argv):
    import argparse, tempfile
    ap = argparse.ArgumentParser(description="census of emitted safe points whose shielded store lands outside the frame map")
    ap.add_argument("progs", nargs="*")
    ap.add_argument("--scrip", default=os.path.join(ROOT, "scrip"))
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--write-baseline", metavar="TSV",
                    help="rewrite the per-witness ratchet file from this run (the landing that earns a move writes it)")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()
    with tempfile.TemporaryDirectory(prefix="gc_unmapped_") as wd:
        if not a.write_baseline:
            return report(a.scrip, a.progs, wd)
        lines = []
        rc = report(a.scrip, a.progs, wd, out=lines.append)
        if rc == 2:
            print("\n".join(lines))
            return 2
        rows = [l.split() for l in lines if l.startswith("CENSUS unmapped-store WITNESS ")]
        with open(a.write_baseline, "w", encoding="utf-8") as fh:
            fh.write(BASELINE_HEADER)
            for r in rows:
                fh.write("\t".join([r[3]] + [f.split("=")[1] for f in r[4:8]]) + "\n")
        print(f"wrote {a.write_baseline}: {len(rows)} witness row(s)")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
