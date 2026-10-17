#!/usr/bin/env python3
"""util_gc_poll_register_liveness.py -- AT EVERY EMITTED SAFE POINT, IS A REGISTER READ AS A POINTER BEFORE IT IS
NEXT WRITTEN?  (ceo, row gc-a-fast-witness-detector-grades-a-safe-point-conversion-batch-in-seconds-proven-against-
the-known-bad-insertion; design .github/ARCH-GC-COMPILE-TIME-FRAME-MAPS.md; law RULES.md FACT RULE THE COLLECTOR
GUESSES NOTHING.)

⛔ WHY THIS EXISTS, NAMED BY THE GATE IT CONTINUES.  test_gate_gc_the_caller_saved_spill_block_never_holds_a_heap_
reference.sh arm (i) measured the standing population and then wrote down its own next step verbatim: "The step
after this one is to ask, per member, whether the reloaded register is read as a pointer before it is next
written."  That gate proved 806 heap references sit in rtccb across collections and that 161 of them name a block
THE COLLECTOR MOVED AND ARE LEFT UNREPAIRED, because nothing visits that block and nothing can (32 untagged words;
visiting them is a conservative scan and CEO-812 froze that out).  A wrong word is only SPENT when the reload's
register is then used as a pointer -- so the unrepaired count is an upper bound and this reader is what turns it
into a defect list or closes the class.

⛔ AND IT IS THE DISCRIMINATOR THE SITE CONVERSIONS NEED, WHICH IS THE MORE EXPENSIVE HALF.  CEO-1107: choosing
polls by the callee's DECLARED RETURN CLASS put 77 in and cost 57 Icon programs, because the return class says what
the callee RETURNS and nothing about what is ALREADY LIVE in a register across the site.  CEO-1110: a 54-witness
6.8-second sweep cleared 14 sites that still cost 7 programs, so THE SWEEP IS NOT SUFFICIENT EITHER.  Both
instruments ask about the program's OUTPUT.  This one asks about the emitted instruction stream, which is where the
defect is, and it is static: no arena, no stress, no load, no rungs -- so it never competes for the board channel
two seats share (MODE line 2, DUO).

THE READING, and the conservative direction is the whole design.  Everything on the emitted stack is a DESCR and a
register is not on the stack, so a register live across a poll is relocated by NOTHING unless the poll spills it as
a tagged cell (x86_rt_gc_poll_res for rax:rdx, the _rec_sigma family for r13/r15).  The wrong answer here is A LOST
ROOT, so a read is POINTER unless it is PROVABLY too narrow to hold one -- the callee-saved census's own D32 rule
(a 32-bit read zero-extends: a 64-bit pointer cannot survive it), reused rather than reinvented.  Four verdicts per
(safe point, register), and PROPAGATED is its own bucket rather than folded into either answer, because a count
that hides its undecidables is the defect this file exists against:

  POINTER     the register is read as a memory base or index, or handed to a call in a pointer argument slot,
              before any path writes it.  A collection at this safe point spends a stale pointer here.
  SPILLED     the register is stored to memory before any other classified use.  Reported separately because a
              store into a MAPPED FRAME SLOT is the designed cure (ARCH-GC 3), not a defect -- but this reader
              cannot tell a mapped slot from a scratch cell, so it says where the value went and stops.
  NARROW      every read before the next write is provably narrow -- a 32-bit subregister, or a compare or an
              add/sub against an immediate.  Harmless BY MECHANISM rather than by luck.
  PROPAGATED  the register is copied onward past this reader's hop budget, so it cannot place it.  Named, never
              counted clean.
  DEAD        every path writes the register before reading it.  Nothing to protect.

⛔⭐ A POINTER USE IS NOT A DEFECT UNLESS THE POINTEE IS COLLECTABLE, AND THAT COST ME 19 OF MY FIRST 26 FINDINGS.
The first full reading named 19 POINTER findings on r12, all one instruction (`mov qword ptr [r12 + 0], rcx` in
bb_match_capture phase 1), and every one is a FALSE POSITIVE: frame_layout.c calls head.dcap_mark "ZK_RAW -- points
into the base-pinned dcap island, never GC-moved", and pattern_match.c:685 backs that with rt_slab_region() at the
FIXED VA RT_DCAP_TOP = 0x70000000 (pinned by pin_va.h and hardcoded as an absolute disp32 in rtx_match.s).  A fixed-VA
slab reserve is not the collected heap and is NOT the retired hb_pinned/rt_pinned_alloc heap pinning GC-5 rung 2
deletes, so no collection can invalidate r12 there.  DECLARED_NONCOLLECTED is therefore its own bucket with its reason
printed at the exclusion, never a silent subtraction: a register is excluded only where a declaration in the tree says
where it points, and the POINTER total is printed BOTH ways so a reader cannot lose the difference.

⛔⛔ THE ARTIFACT THIS READER WAS BORN WITH, WRITTEN DOWN BECAUSE IT READ AS A CLEAN BILL OF HEALTH.  The rtcc
reload (x86_asm.h 395-398) is the FIRST instruction after the poll call and it is itself a WRITE of r8.  A walk that
starts at the call's next instruction therefore stops at once and calls r8 DEAD -- and the first reading over 54
witnesses said exactly that, r8 DEAD at all 2889 safe points, which would have retired a standing 161-unrepaired
finding on an artifact.  A DETECTOR ARM FAILS OPEN: it reads as "there was never a bug here" (CLAUDE.md, ceo
CEO-480/481).  So for a register the reload DEFINES, the walk begins AFTER the reload block, because the gate's
question is about the RELOADED value.  Arm (g) of --selftest is that fail-once and it is the arm that matters.

USAGE
  util_gc_poll_register_liveness.py [PROG ...]        one or more corpus programs (default: the witness set)
  util_gc_poll_register_liveness.py --asm FILE.s      grade an already-emitted .s
  util_gc_poll_register_liveness.py --selftest        fail-once and pass-once on a planted stream
  --regs r8,r12,...       which registers to follow (default: the anchor, the three sigma pins, r12
                          and rbx).  ⛔ r12 AND rbx ARE IN THE DEFAULT BECAUSE LEAVING THEM OUT WAS
                          THE FIRST READING'S MISS: bb_match_end passes r12 as a const char * and
                          hb_blob_span_defer WRITES through it at four existing safe points, all four
                          invisible to a reader that followed only r8 and the sigma pins.
  --by-site               one line per safe point instead of the per-register totals
"""
import argparse
import collections
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
DEFAULT_REGS = ["r8", "r12", "r13", "r14", "r15", "rbx"]
POLL_RX = re.compile(r"\bcall\b.*\brt_gc_poll(?:_asm)?\b|\bcall\b.*\brt_gc_point_arr_c\b|\bcall\b.*\brt_gc_point_arr_probe_c\b")
LABEL_RX = re.compile(r"^([A-Za-z_.$][\w.$]*):")
JUMP_RX = re.compile(r"^\s*(jmp|je|jne|jz|jnz|jg|jge|jl|jle|ja|jae|jb|jbe|js|jns|jo|jno|jp|jnp)\s+([\w.$]+)")
CALL_RX = re.compile(r"^\s*call\b")
RET_RX = re.compile(r"^\s*(ret|ud2|hlt)\b")
ARG_REGS = ("rdi", "rsi", "rdx", "rcx", "r8", "r9")
SUB32 = {"r8": "r8d", "r9": "r9d", "r10": "r10d", "r11": "r11d", "r12": "r12d",
         "r13": "r13d", "r14": "r14d", "r15": "r15d", "rax": "eax", "rcx": "ecx",
         "rdx": "edx", "rsi": "esi", "rdi": "edi", "rbx": "ebx"}
SUB16_8 = {"r8": ("r8w", "r8b"), "r13": ("r13w", "r13b"), "r14": ("r14w", "r14b"),
           "r15": ("r15w", "r15b"), "rax": ("ax", "al"), "rcx": ("cx", "cl"),
           "rdx": ("dx", "dl"), "rsi": ("si", "sil"), "rdi": ("di", "dil")}
NARROW_OPS = ("cmp", "test", "add", "sub", "and", "or", "xor", "shl", "shr", "sar", "inc", "dec", "imul")
WRITE_FIRST_OPS = ("mov", "movabs", "lea", "movzx", "movsx", "movsxd", "pop", "xchg", "setz", "setne")


def strip_comment(text):
    out = []
    for piece in text.split("\n"):
        out.append(piece)
    return "\n".join(out)


def parse_asm(text):
    """[(label_or_None, mnemonic, operand_text)] plus {label: index} -- ; separates instructions in our output"""
    prog, labels = [], {}
    for raw in text.split("\n"):
        line = raw.rstrip()
        if not line.strip():
            continue
        pending_label = None
        m = LABEL_RX.match(line.strip())
        if m:
            pending_label = m.group(1)
            line = line.strip()[len(m.group(0)):]
        for piece in line.split(";"):
            piece = piece.strip()
            if not piece:
                continue
            if piece.startswith("."):
                if pending_label is not None and pending_label not in labels:
                    labels[pending_label] = len(prog)
                pending_label = None
                continue
            m2 = LABEL_RX.match(piece)
            if m2 and pending_label is None:
                pending_label = m2.group(1)
                piece = piece[len(m2.group(0)):].strip()
                if not piece:
                    continue
            parts = piece.split(None, 1)
            mnem = parts[0].lower()
            ops = parts[1] if len(parts) > 1 else ""
            if pending_label is not None:
                labels.setdefault(pending_label, len(prog))
                pending_label = None
            prog.append((mnem, ops, piece))
        if pending_label is not None:
            labels.setdefault(pending_label, len(prog))
    return prog, labels


def successors(prog, labels, i):
    mnem, ops, _raw = prog[i]
    line = mnem + " " + ops
    m = JUMP_RX.match(" " + line)
    if m:
        tgt = labels.get(m.group(2))
        if m.group(1) == "jmp":
            return [tgt] if tgt is not None else []
        nxt = [i + 1] if i + 1 < len(prog) else []
        return nxt + ([tgt] if tgt is not None else [])
    if RET_RX.match(" " + line):
        return []
    return [i + 1] if i + 1 < len(prog) else []


def mem_operands(ops):
    return re.findall(r"\[([^\]]*)\]", ops)


def reg_tokens(text):
    return set(re.findall(r"\b(r[0-9]{1,2}[dwb]?|[er]?[abcd]x|[er]?[sd]i|[abcd][lh]|sil|dil|spl|bpl)\b", text))


RELOAD_RX = re.compile(r"^\s*mov\s+(r8|r9|r10|r11)\s*,\s*qword ptr \[rip \+ rtccb\+\d+\]\s*$")


def reload_block(prog, i):
    """(index after the contiguous rtcc reload run at i, {regs that run DEFINES}) -- the reload IS the definition"""
    j, defined = i, set()
    while j < len(prog):
        mnem, ops, _raw = prog[j]
        m = RELOAD_RX.match(" " + mnem + " " + ops)
        if not m:
            break
        defined.add(m.group(1))
        j += 1
    return j, defined


def classify_use(mnem, ops, reg):
    """POINTER / SPILLED / NARROW / COPY:<reg> / None for one instruction's READ of reg -- None means no read"""
    wide = reg
    narrow = {SUB32.get(reg, "")} | set(SUB16_8.get(reg, ()))
    narrow.discard("")
    mems = mem_operands(ops)
    for m in mems:
        if wide in reg_tokens(m):
            return "POINTER"
    outside = ops
    for m in mems:
        outside = outside.replace("[" + m + "]", " ")
    toks = reg_tokens(outside)
    reads_wide = wide in toks
    reads_narrow = bool(narrow & toks)
    if not reads_wide and not reads_narrow:
        return None
    if mnem == "call":
        return "POINTER"
    fields = [f.strip() for f in outside.split(",")]
    if reads_wide and mnem in WRITE_FIRST_OPS and len(fields) > 1:
        dst, src = fields[0], fields[-1]
        if reg_tokens(dst) == {wide} and wide not in reg_tokens(src):
            return None
        if reg_tokens(src) == {wide} and mems:
            return "SPILLED"
        dt = reg_tokens(dst)
        if reg_tokens(src) == {wide} and len(dt) == 1:
            return "COPY:" + list(dt)[0]
        return "PROPAGATED"
    if reads_wide and mnem in NARROW_OPS:
        rhs = fields[-1]
        if re.match(r"^-?(0x)?[0-9a-fA-F]+$", rhs) or rhs.isdigit():
            return "NARROW"
        return "PROPAGATED"
    if reads_wide:
        return "PROPAGATED"
    return "NARROW"


def writes_reg(mnem, ops, reg):
    if mnem not in WRITE_FIRST_OPS and mnem not in NARROW_OPS and mnem != "xor":
        return False
    dst = ops.split(",")[0].strip()
    if dst.startswith("["):
        return False
    toks = reg_tokens(dst)
    if reg in toks:
        return True
    if SUB32.get(reg) in toks:
        return True
    return False


ORDER = {"POINTER": 5, "BUDGET": 4, "PROPAGATED": 3, "SPILLED": 2, "NARROW": 1}
BUCKETS = ("POINTER", "PROBED", "BUDGET", "PROPAGATED", "SPILLED", "NARROW", "DEAD")
PROBED_REASON = ("rt_gc_poll_slow saves r13 into its own frame and hands that word to the shield as its PROBE (r8d=1), and "
                 "gc_heap.c's r0 branch forwards it ONLY when it equals the runtime's Σ or scan_subj -- an equality test against "
                 "a pointer the collector already roots, never a guess (fa1dc84a5).  So an r13 read after a BARE asm poll is "
                 "safe exactly when r13 was the subject base at the poll, which is the scan spine's convention and which "
                 "hb_scan_subject_across_allocating_poll.icn holds under relocation at stress 1..8.  It is NOT a clearance: an "
                 "r13 that is not the subject (an interior cursor, a stale value the box will re-derive) is not forwarded and this "
                 "reader cannot tell the two apart statically, so the bucket is COUNTED and NAMED, never folded into DEAD.")
WALK_BUDGET = 10000
DECIDED_FLOOR = 95
"""⛔⭐ WALK_BUDGET IS MEASURED, NOT CHOSEN, AND THE FIRST VALUE I SHIPPED WAS A GUESS THAT DECIDED HALF THE
POPULATION.  The first published version of this reader capped the CFG walk at 400 steps and reported a finding
count as its headline.  Measured over 10 witnesses and four registers, 2152 (site, register) pairs:
    budget    400 -> decided 1059/2152 = 49%, budget-exhausted 1073, POINTER 4, 2.1s
    budget   2000 -> decided 2030/2152 = 94%, budget-exhausted   98, POINTER 4, 4.5s
    budget  10000 -> decided 2128/2152 = 99%, budget-exhausted    0, POINTER 4, 4.8s
    budget 200000 -> decided 2128/2152 = 99%, budget-exhausted    0, POINTER 4, 4.9s
So 10000 is the PLATEAU: the first value at which no pair is undecidable for want of steps, and it costs 2.7
seconds more than the guess.  ⛔ POINTER stayed 4 at every budget, which means the findings were ROBUST -- BUT
THAT WAS LUCK AND NOT A PROPERTY, because a reader deciding 49% of its population cannot know whether the other
51% holds findings.  A count over a half-decided population is a lower bound with an unnamed denominator, and
the file's own docstring already forbade exactly that: a count that hides its undecidables is the defect this
file exists against.  BUDGET is therefore its own bucket, never folded into PROPAGATED, and DECIDED_FLOOR makes
the reader REFUSE rather than publish a count it cannot stand behind."""
NONCOLLECTED = {"r12": "frame_layout.c head.dcap_mark declares it ZK_RAW pointing into the base-pinned dcap island, "
                       "never GC-moved, and pattern_match.c:685 reserves that island with rt_slab_region() at the "
                       "fixed VA RT_DCAP_TOP 0x70000000 -- a fixed-VA reserve is not the collected heap"}


def verdict_at(prog, labels, start, reg, budget=WALK_BUDGET, hops=2):
    """forward CFG walk from start: the first classified READ on any path, or DEAD when every path writes first.

    A COPY is followed for `hops` more registers rather than answered, because `mov rbx, r13` then a dereference of
    rbx spends the same stale pointer -- stopping at the copy is how 78% of the first reading read PROPAGATED."""
    seen, work, best = set(), [(start, reg, hops)], None
    copy_fallback = None
    steps = 0
    while work:
        i, r, h = work.pop()
        if i is None or (i, r) in seen or i >= len(prog):
            continue
        seen.add((i, r))
        steps += 1
        if steps > budget:
            return "BUDGET", "walk budget %d exhausted -- NOT PLACED for want of steps, which is a limit of THIS READER and not a fact about the program" % budget
        mnem, ops, raw = prog[i]
        use = classify_use(mnem, ops, r)
        if use is not None:
            if use.startswith("COPY:"):
                nxt = use.split(":", 1)[1]
                if h > 0:
                    if copy_fallback is None:
                        copy_fallback = ("PROPAGATED", raw.strip()[:88] + "   (copy, following %s)" % nxt)
                    work.append((i + 1, nxt, h - 1))
                    continue
                use = "PROPAGATED"
            tag = raw.strip()[:88] + ("" if r == reg else "   (via %s)" % r)
            if best is None or ORDER[use] > ORDER[best[0]]:
                best = (use, tag)
            if use == "POINTER":
                return best
            continue
        if writes_reg(mnem, ops, r):
            continue
        for s in successors(prog, labels, i):
            work.append((s, r, h))
    if best is not None:
        return best
    if copy_fallback is not None:
        return copy_fallback
    return ("DEAD", "every path writes %s before reading it" % reg)


def grade_asm(text, regs, budget=WALK_BUDGET, hops=2):
    prog, labels = parse_asm(text)
    sites = [i for i, (m, o, raw) in enumerate(prog) if POLL_RX.search(raw)]
    rows = []
    for i in sites:
        after, defined = reload_block(prog, i + 1)
        per = {}
        for r in regs:
            per[r] = verdict_at(prog, labels, after if r in defined else i + 1, r, budget=budget, hops=hops)
            if r == "r13" and per[r][0] == "POINTER" and "rt_gc_poll_asm" in prog[i][2]:
                per[r] = ("PROBED",) + tuple(per[r][1:])
        rows.append((i, per))
    return prog, sites, rows


def emit_asm(prog_path, scrip=None):
    scrip = scrip or os.path.join(ROOT, "scrip")
    fd, out = tempfile.mkstemp(suffix=".s"); __import__("atexit").register(lambda p=out: os.path.exists(p) and os.unlink(p))
    os.close(fd)
    r = subprocess.run([scrip, "--compile", "-o", out, prog_path], stdin=subprocess.DEVNULL,
                       capture_output=True, text=True, timeout=120)
    if r.returncode != 0 or not os.path.exists(out) or os.path.getsize(out) == 0:
        return None, (r.stderr or r.stdout or "").strip().splitlines()[-1:] or ["no asm produced"]
    return out, None


PLANT_CLEAN = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              r8,  qword ptr [rip + rtccb+40]
                        cmp              r13, 5
                        mov              r13, 0
                        ret
"""
PLANT_BAD = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              r8,  qword ptr [rip + rtccb+40]
                        mov              rax, qword ptr [r13 + 8]
                        mov              r13, 0
                        ret
"""
PLANT_JUMP = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              r11, qword ptr [rip + rtccb+64];     jmp   other_α
                        mov              r13, 0
other_α:                mov              rcx, qword ptr [r13 + 16]
                        ret
"""
PLANT_R8_BAD = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              r8,  qword ptr [rip + rtccb+40]
                        mov              r9,  qword ptr [rip + rtccb+48]
                        mov              r9,  0
                        mov              rax, qword ptr [r8 + 24]
                        ret
"""
PLANT_COPY_DEREF = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              rbx, r13
                        mov              r13, 0
                        mov              rax, qword ptr [rbx + 8]
                        ret
"""
PLANT_SPILL = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              qword ptr [rbp - 48], r13
                        mov              r13, 0
                        ret
"""
PLANT_COPY_SPILL = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              rbx, r13
                        mov              r13, 0
                        mov              qword ptr [rbp - 48], rbx
                        ret
"""
PLANT_COPY_NARROW = """
main_bx:                call             rt_gc_poll_asm@PLT
                        mov              rbx, r13
                        mov              r13, 0
                        cmp              ebx, 5
                        ret
"""


def R_verdict_budget1(text, reg):
    prog, labels = parse_asm(text)
    sites = [i for i, (m, o, raw) in enumerate(prog) if POLL_RX.search(raw)]
    after, defined = reload_block(prog, sites[0] + 1)
    return verdict_at(prog, labels, sites[0] + 1, reg, budget=1)[0]


def C_POLL(plant):
    """the same plant at the C poll, which has no probe: what a POINTER arm must plant now that the asm poll PROBES r13"""
    return plant.replace("rt_gc_poll_asm@PLT", "rt_gc_poll@PLT")


def selftest():
    fails = []

    def ck(cond, msg):
        print(("  ok   " if cond else "  FAIL ") + msg)
        if not cond:
            fails.append(msg)

    _p, s, rows = grade_asm(PLANT_CLEAN, ["r13"])
    ck(len(s) == 1, "(a) the reader finds the one planted safe point in the clean stream (found %d)" % len(s))
    ck(rows and rows[0][1]["r13"][0] == "NARROW",
       "(b) a compare against an immediate reads NARROW, so the D32 rule is applied and not merely quoted (read %s)"
       % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_BAD, ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "PROBED",
       "(c0) r13 used as a memory base after the BARE ASM poll reads PROBED, not POINTER and not DEAD -- the poll's own "
       "probe forwards it when it is the subject, and the bucket is counted and named (read %s)"
       % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(C_POLL(PLANT_BAD), ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "POINTER",
       "(c) FAIL-ONCE: r13 used as a memory base after the C poll, which probes nothing, reads POINTER (read %s)"
       % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(C_POLL(PLANT_JUMP), ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "POINTER",
       "(d) the walk FOLLOWS THE JUMP -- our polls sit before an rtcc reload that ends in jmp, so a reader that "
       "stopped at the jump would clear every site by never looking (read %s)"
       % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_BAD, ["r14"])
    ck(rows and rows[0][1]["r14"][0] == "DEAD",
       "(e) a register no path reads reads DEAD rather than clean-by-absence (read %s)"
       % (rows[0][1]["r14"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_CLEAN.replace("cmp              r13, 5",
                                                "mov              rbx, r13\n                        ret"), ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "PROPAGATED",
       "(f) a copy whose destination is never used runs out of hops and reads PROPAGATED, its own bucket, never "
       "folded into an answer (read %s)" % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_R8_BAD, ["r8"])
    ck(rows and rows[0][1]["r8"][0] == "POINTER",
       "(g) FAIL-ONCE ON THE ARTIFACT THAT ALMOST SHIPPED: the rtcc reload is the first instruction after the poll "
       "and is itself a write of r8, so a walk starting there calls r8 DEAD and clears every site by never looking. "
       "The RELOADED r8 dereferenced afterwards must read POINTER (read %s)"
       % (rows[0][1]["r8"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_R8_BAD, ["r9"])
    ck(rows and rows[0][1]["r9"][0] == "DEAD",
       "(h) a reloaded register the stream then overwrites is DEAD, so arm (g) is discriminating rather than "
       "painting every reload red (read %s)" % (rows[0][1]["r9"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(C_POLL(PLANT_COPY_DEREF), ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "POINTER",
       "(i) a copy THEN a dereference of the copy reads POINTER -- the same stale pointer is spent either way "
       "(read %s)" % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_SPILL, ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "SPILLED",
       "(j) a store of the register into memory reads SPILLED and is not claimed clean, because this reader cannot "
       "tell a mapped frame slot from a scratch cell (read %s)" % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_JUMP, ["r13"])
    v = R_verdict_budget1(PLANT_JUMP, "r13")
    ck(v == "BUDGET",
       "(k) FAIL-ONCE ON THE BUCKET THAT ALMOST HID ITSELF: at budget=1 the walk cannot reach the dereference and "
       "must read BUDGET, not DEAD and not PROPAGATED. The first shipped reader folded budget exhaustion into "
       "PROPAGATED, so a cap I chose was indistinguishable from a dataflow limit of the program (read %s)" % v)
    ck(WALK_BUDGET == 10000 and DECIDED_FLOOR == 95,
       "(l) the budget is the MEASURED plateau (10000, the first value with zero exhaustion over 2152 pairs) and "
       "the decided floor is declared (95%%), both constants rather than inline guesses -- read %d and %d"
       % (WALK_BUDGET, DECIDED_FLOOR))
    _p, s, rows = grade_asm(PLANT_COPY_SPILL, ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "SPILLED",
       "(m) FAIL-ONCE ON THE BUCKET THAT COULD NOT BE CLEARED: a copy THEN a spill of the copy reads SPILLED. "
       "PROPAGATED outranks SPILLED and NARROW, so seeding it at the first copy made every followed copy "
       "UNRESOLVABLE -- decided stuck at 88%% and `--hops` was inert from 1 to 12, which made the reader's own "
       "advice to widen the hops impossible to act on (read %s)" % (rows[0][1]["r13"][0] if rows else "nothing"))
    _p, s, rows = grade_asm(PLANT_COPY_NARROW, ["r13"])
    ck(rows and rows[0][1]["r13"][0] == "NARROW",
       "(n) the same cure discriminates rather than painting every followed copy SPILLED: a copy then a D32 "
       "compare of the copy reads NARROW (read %s)" % (rows[0][1]["r13"][0] if rows else "nothing"))
    import contextlib, io as _io, tempfile as _tf, os as _os
    _plant = PLANT_BAD + PLANT_CLEAN.replace("main_bx:", "main_cx:").replace(
        "cmp              r13, 5", "mov              rbx, r13\n                        ret")
    _fd, _path = _tf.mkstemp(suffix=".s")
    with _os.fdopen(_fd, "w") as _f:
        _f.write(_plant)
    _buf = _io.StringIO()
    with contextlib.redirect_stdout(_buf):
        _rc = main(["--asm", _path, "--regs", "r13"])
    _os.unlink(_path)
    _out = _buf.getvalue()
    ck(_rc == 2 and "REFUSE(2)" in _out and "POINTER" in _out and "LOWER BOUND" in _out,
       "(o) FAIL-ONCE ON A REFUSAL THAT COULD NOT REJECT: under the decided floor the reader still NAMES its "
       "POINTER findings. It used to return before the findings block, so on a sub-floor population it could "
       "neither clear nor reject -- a screen with no reachable verdict (rc=%s, named=%s)"
       % (_rc, "POINTER" in _out))
    print("SELFTEST arms=15 fail=%d" % len(fails))
    return 1 if fails else 0


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("progs", nargs="*", default=[])
    ap.add_argument("--asm", default="")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--regs", default=",".join(DEFAULT_REGS))
    ap.add_argument("--by-site", action="store_true")
    ap.add_argument("--budget", type=int, default=WALK_BUDGET)
    ap.add_argument("--hops", type=int, default=2)
    ap.add_argument("--scrip", default="")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()
    regs = [r.strip() for r in a.regs.split(",") if r.strip()]
    targets = []
    if a.asm:
        targets = [(a.asm, a.asm)]
    else:
        progs = a.progs
        if not progs:
            wd = os.path.join(ROOT, "..", "harness", "scripts", "gc_witnesses")
            progs = sorted(os.path.join(wd, f) for f in os.listdir(wd)
                           if f.endswith((".sno", ".icn", ".pl", ".raku")))
        for p in progs:
            s, err = emit_asm(p, a.scrip or None)
            if s is None:
                print("REFUSE %-44s could not emit asm: %s" % (os.path.basename(p), "; ".join(err)))
                continue
            targets.append((p, s))
    if not targets:
        print("REFUSE(2) no program produced asm -- a denominator of zero is a refusal, not a clean reading")
        return 2
    tot = collections.Counter()
    sites_tot = 0
    worst = []
    for src, asm in targets:
        text = open(asm, encoding="utf-8", errors="replace").read()
        _prog, sites, rows = grade_asm(text, regs, budget=a.budget, hops=a.hops)
        sites_tot += len(sites)
        per_prog = collections.Counter()
        for idx, per in rows:
            for r in regs:
                v = per[r][0]
                tot[(r, v)] += 1
                per_prog[v] += 1
                if v == "POINTER":
                    worst.append((os.path.basename(src), idx, r, per[r][1]))
        if a.by_site:
            print("%-40s safe_points=%-4d %s" % (os.path.basename(src), len(sites),
                  " ".join("%s=%d" % (k, per_prog[k]) for k in BUCKETS)))
    print("POLL-REG-LIVENESS programs=%d safe_points=%d regs=%s" % (len(targets), sites_tot, ",".join(regs)))
    short = 0
    for r in regs:
        per = [tot[(r, b)] for b in BUCKETS]
        print("   %-5s %s  total=%d" % (r, " ".join("%s=%-5d" % (b, n) for b, n in zip(BUCKETS, per)), sum(per)))
        if sum(per) != sites_tot:
            short += 1
            print("   ⛔ %s buckets sum to %d over %d safe points -- a bucket is being dropped and every number "
                  "above it is short by the difference" % (r, sum(per), sites_tot))
    if short:
        print("REFUSE(2) the per-register buckets do not cover the printed denominator for %d register(s)" % short)
        return 2
    ndec = sum(tot[(r, b)] for r in regs for b in BUCKETS if b not in ("BUDGET", "PROPAGATED"))
    nall = sites_tot * len(regs)
    pct = (100.0 * ndec / nall) if nall else 0.0
    print("   DECIDED %d of %d (site, register) pair(s) = %.0f%%  -- BUDGET %d, COPY %d.  ⛔ THIS IS THE FIRST "
          "NUMBER BECAUSE A FINDING COUNT OVER A PARTLY-DECIDED POPULATION IS A LOWER BOUND WITH AN UNNAMED "
          "DENOMINATOR" % (ndec, nall, pct,
                           sum(tot[(r, "BUDGET")] for r in regs), sum(tot[(r, "PROPAGATED")] for r in regs)))
    if pct < DECIDED_FLOOR:
        under = [w for w in worst if w[2] not in NONCOLLECTED]
        for w in under[:25]:
            print("   POINTER %-34s site=%-6d %-4s %s" % w)
        if len(under) > 25:
            print("   ... %d more POINTER finding(s)" % (len(under) - 25))
        print("   NAMED ABOVE AS A LOWER BOUND, NEVER AS A COUNT: %d POINTER finding(s) survive a %.0f%%-decided "
              "reading. This reader REJECTS and never CLEARS, so a name it prints is a finding and its silence "
              "is not a clearance." % (len(under), pct))
        print("REFUSE(2) decided %.0f%% is below the declared floor of %d%% -- this reader will not publish a "
              "finding COUNT it cannot stand behind, and the names above are the reject signal it can. BUDGET is "
              "%d and the copy hops SATURATE at 2 on this population, so neither knob lifts the residue: the "
              "PROPAGATED that remain are copies whose destination no path reads in a classified way."
              % (pct, DECIDED_FLOOR, sum(tot[(r, "BUDGET")] for r in regs)))
        return 2
    npointer = sum(tot[(r, "POINTER")] for r in regs)
    ndecl = sum(tot[(r, "POINTER")] for r in regs if r in NONCOLLECTED)
    print("   POINTER total=%d over %d safe point(s), of which %d are DECLARED_NONCOLLECTED -- %d POINTER finding(s) "
          "name a register the collector relocates by nothing AND whose pointee it can move"
          % (npointer, sites_tot, ndecl, npointer - ndecl))
    for r in regs:
        if r in NONCOLLECTED and tot[(r, "POINTER")]:
            print("   DECLARED_NONCOLLECTED %s x%d: %s" % (r, tot[(r, "POINTER")], NONCOLLECTED[r]))
    if tot[("r13", "PROBED")]:
        print("   PROBED r13 x%d -- r13 read after a BARE asm poll, forwarded by the poll's own probe when it is the subject: %s"
              % (tot[("r13", "PROBED")], PROBED_REASON))
    live = [w for w in worst if w[2] not in NONCOLLECTED]
    for w in live[:25]:
        print("   POINTER %-34s site=%-6d %-4s %s" % w)
    if len(live) > 25:
        print("   ... %d more POINTER finding(s)" % (len(live) - 25))
    return 1 if (npointer - ndecl) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
