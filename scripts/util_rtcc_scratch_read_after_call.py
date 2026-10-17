#!/usr/bin/env python3
"""util_rtcc_scratch_read_after_call.py -- DOES EMITTED CODE READ r8, r10 OR r11 AFTER A CALL BEFORE IT WRITES IT?

The cto's ruling ruling-retire-the-r8-r10-r11-writeback-yes-with-a-standing-reader-gate (2026-10-09), condition (1): the
write-back of r8, r10 and r11 into rtccb before a C call or a poll and their reload after it retire, and this reader
is the standing proof that nothing in emitted code reads one of them after a call before a write.  A read there would
see whatever the callee left, so after the retirement a single one is a defect, named by file and instruction.

THE WALK: from every call instruction in an emitted stream, along every control-flow path (the CFG reader of
util_gc_poll_register_liveness.py, reused), for each of r8, r10, r11 and their 32/16/8-bit names, the first
instruction that touches the register decides: a WRITE ends the path, a READ is a finding.  A contiguous rtcc reload
run right after the call is skipped and not counted as a write, because it is the thing being retired: the question is
asked of the stream as it reads without it.  A path also ends at ret, ud2, an indirect jmp, or another call (that call
is a site of its own).  A self-xor or self-sub is a write.  A 16- or 8-bit write leaves the upper bits stale and is
counted a READ, never a write.

THE LIMIT, NAMED: a later call that takes r8 as its fifth argument without writing it first is a read this reader
cannot see, because a call's arity is not in the stream.

THE ENTRY: --entry also asks the question at every global function label (where C enters emitted code), the driver's
initial load of the three registers at program entry being the other half of the ruling, condition (3).  A mode-3
slab's first byte is its entry (the driver's trampoline jumps there), so --entry grades it too.

USAGE
  util_rtcc_scratch_read_after_call.py --asm FILE.s [--asm FILE2.s ...] [--entry] [--list]
  util_rtcc_scratch_read_after_call.py --objdump FILE.dis ...   a mode-3 slab disassembled by objdump -D -b binary
  util_rtcc_scratch_read_after_call.py --selftest
Prints RTCC_SCRATCH_READS sites=<n> reads=<n> files=<n>, then one READ line per finding; rc 0 when reads=0, rc 1 when
a read is found, rc 2 when nothing was graded.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from util_gc_poll_register_liveness import parse_asm, successors, reload_block, reg_tokens, mem_operands

REGS = ("r8", "r10", "r11")
FAMILY = {r: {r, r + "d", r + "w", r + "b"} for r in REGS}
WRITE_OPS = ("mov", "movabs", "lea", "movzx", "movsx", "movsxd", "pop", "movq", "movd", "cmove", "setz")
SELF_ZERO = ("xor", "sub")
CALL_RX = re.compile(r"^call$")
END_RX = re.compile(r"^(ret|ud2|hlt)$")
GLOBAL_RX = re.compile(r"^\s*\.globl\s+([\w.$]+)", re.M)


WB_RX = re.compile(r"^qword ptr \[rip \+ rtccb\+\d+\]\s*,\s*(r8|r9|r10|r11)$")
RL_RX = re.compile(r"^(r8|r9|r10|r11)\s*,\s*qword ptr \[rip \+ rtccb\+\d+\]$")


def touch(mnem, ops, reg):
    fam = FAMILY[reg]
    if mnem == "mov" and (WB_RX.match(ops.strip()) or RL_RX.match(ops.strip())):
        return None
    toks = reg_tokens(ops)
    if not (fam & toks):
        return None
    mems = mem_operands(ops)
    if any(fam & reg_tokens(m) for m in mems):
        return "R"
    fields = [f.strip() for f in ops.split(",")]
    if mnem in SELF_ZERO and len(fields) == 2 and fields[0] == fields[1] and fields[0] in fam:
        return "W"
    if mnem == "pop" and fields[0] in fam:
        return "W" if fields[0] in (reg, reg + "d") else "R"
    if mnem in WRITE_OPS and len(fields) >= 2:
        dst, src = fields[0], ",".join(fields[1:])
        if dst in fam and not (fam & reg_tokens(src)):
            return "W" if dst in (reg, reg + "d") else "R"
    return "R"


def first_reads(prog, labels, start, reg, budget=20000):
    seen, work, found, steps = set(), [start], [], 0
    while work:
        i = work.pop()
        if i is None or i in seen or i >= len(prog):
            continue
        seen.add(i)
        steps += 1
        if steps > budget:
            return found, True
        mnem, ops, raw = prog[i]
        if CALL_RX.match(mnem):
            continue
        t = touch(mnem, ops, reg)
        if t == "R":
            found.append((i, raw.strip()[:100]))
            continue
        if t == "W":
            continue
        if mnem == "jmp" and not re.match(r"^[\w.$]+$", ops.strip()):
            continue
        if END_RX.match(mnem):
            continue
        work.extend(successors(prog, labels, i))
    return found, False


def live_in(prog, labels):
    """one backward pass to a fixpoint: live[i] is the set of the three registers some path from i reads before it
    writes, under the walk's rules (a call, ret, ud2, hlt or an indirect jmp ends a path)."""
    n = len(prog)
    succ, preds, eff = [None] * n, [[] for _ in range(n)], [None] * n
    for i, (m, o, raw) in enumerate(prog):
        if CALL_RX.match(m) or END_RX.match(m) or (m == "jmp" and not re.match(r"^[\w.$]+$", o.strip())):
            succ[i] = []
        else:
            succ[i] = [s for s in successors(prog, labels, i) if s is not None and s < n]
        for s2 in succ[i]:
            preds[s2].append(i)
        eff[i] = {r: touch(m, o, r) for r in REGS}
    live = [frozenset()] * n
    work = list(range(n - 1, -1, -1))
    queued = set(work)
    while work:
        i = work.pop()
        queued.discard(i)
        if CALL_RX.match(prog[i][0]):
            continue
        out = set()
        for s2 in succ[i]:
            out |= live[s2]
        new = set()
        for r in REGS:
            t = eff[i][r]
            if t == "R" or (t is None and r in out):
                new.add(r)
        new = frozenset(new)
        if new != live[i]:
            live[i] = new
            for p in preds[i]:
                if p not in queued:
                    queued.add(p)
                    work.append(p)
    return live


NUM_RX = re.compile(r"(?m)(^|;)(\s*)(\d+):|\b(\d+)([fb])\b")


def name_numeric_labels(text):
    """GNU local labels (1: ... jne 1f / jmp 1b) to unique names parse_asm reads; unhandled, every instruction behind
    one parses with the label as its mnemonic and reads as a register read."""
    seen = {}
    def sub(m):
        if m.group(3) is not None:
            n = m.group(3)
            k = seen.get(n, 0)
            seen[n] = k + 1
            return "%s%s.Lnum%s_%d:" % (m.group(1), m.group(2), n, k)
        n, d = m.group(4), m.group(5)
        k = seen.get(n, 0)
        return ".Lnum%s_%d" % (n, k if d == "f" else k - 1)
    return NUM_RX.sub(sub, text)


def grade(text, name, entry=False):
    prog, labels = parse_asm(name_numeric_labels(text))
    sites = []
    for i, (m, o, raw) in enumerate(prog):
        if CALL_RX.match(m):
            after, _defined = reload_block(prog, i + 1)
            sites.append(("call", i, after))
    if entry:
        for g in GLOBAL_RX.findall(text):
            if g in labels:
                sites.append(("entry", labels[g], labels[g]))
    live = live_in(prog, labels) if prog else []
    reads, budget_hit = [], 0
    for kind, i, start in sites:
        if start >= len(prog):
            continue
        for r in REGS:
            if r not in live[start]:
                continue
            found, hit = first_reads(prog, labels, start, r)
            budget_hit += hit
            for j, raw in found[:1]:
                reads.append((name, kind, i, prog[i][2].strip()[:60], r, j, raw))
    return len(sites), reads, budget_hit


OBJ_RX = re.compile(r"^\s*([0-9a-f]+):\s+(?:[0-9a-f]{2} )+\s*(.*)$")


def objdump_to_asm(text):
    """objdump -D -b binary -M intel lines to the label form parse_asm reads: every address is a label L_<hex>, and a
    direct jump or call to an address names that label. A literal word the emitter plants inline (a rip-relative load whose
    address lies between a forward jmp and its target) is data a linear disassembly misreads as code; its lines are dropped."""
    rows = []
    for line in text.split("\n"):
        m = OBJ_RX.match(line)
        if not m:
            continue
        addr, ins = m.group(1), m.group(2).strip()
        if not ins or ins.startswith("(bad)"):
            continue
        rows.append((int(addr, 16), ins))
    skips = []
    for i, (a, ins) in enumerate(rows):
        j = re.match(r"^jmp\s+0x([0-9a-f]+)", ins)
        if not j or i + 1 >= len(rows):
            continue
        end, tgt = rows[i + 1][0], int(j.group(1), 16)
        for _, prev in rows[max(0, i - 3):i]:
            r = re.search(r"#\s*0x([0-9a-f]+)", prev)
            if r and end <= int(r.group(1), 16) < tgt:
                skips.append((end, tgt))
    out = []
    for a, ins in rows:
        if any(lo <= a < hi for lo, hi in skips):
            continue
        ins = re.sub(r"\s+0x([0-9a-f]+)(\s*<[^>]*>)?$", lambda q: " L_" + q.group(1).lstrip("0").rjust(1, "0"), ins) \
            if re.match(r"^(j\w+|call)\s+0x[0-9a-f]+", ins) else ins
        ins = re.sub(r"\b(QWORD|DWORD|WORD|BYTE) PTR\b", lambda q: q.group(1).lower() + " ptr", ins)
        out.append("L_%x: %s" % (a, ins))
    return (".globl L_0\n" if out else "") + "\n".join(out)


def selftest():
    fails = 0
    def ck(cond, msg):
        nonlocal fails
        print(("  ok    " if cond else "  FAIL  ") + msg)
        fails += 0 if cond else 1
    base = "f:\n  mov qword ptr [rip + rtccb+40], r8\n  call rt_x\nL1:\n  mov r8, 5\n  add r8, 1\n  ret\n"
    n, reads, _ = grade(base, "clean")
    ck(n == 1 and not reads, "a write before any read reads clean")
    plant = "f:\n  call rt_x\n  mov rax, r8\n  ret\n"
    _, reads, _ = grade(plant, "plant")
    ck(len(reads) == 1 and reads[0][4] == "r8", "a planted read of r8 after a call is a finding")
    reload = "f:\n  call rt_x\n  mov r8,  qword ptr [rip + rtccb+40]\n  mov r10, qword ptr [rip + rtccb+56]\n  mov rax, r10\n  ret\n"
    _, reads, _ = grade(reload, "reload")
    ck(len(reads) == 1 and reads[0][4] == "r10", "the rtcc reload run is skipped, never taken as the write (the fail-once)")
    branch = "f:\n  call rt_x\n  test eax, eax\n  je L2\n  mov r11, 1\n  ret\nL2:\n  cmp r11d, 3\n  ret\n"
    _, reads, _ = grade(branch, "branch")
    ck(len(reads) == 1 and reads[0][4] == "r11", "a read on the taken branch only is a finding")
    narrow = "f:\n  call rt_x\n  mov r10b, 1\n  mov rax, r10\n  ret\n"
    _, reads, _ = grade(narrow, "narrow")
    ck(len(reads) == 1, "an 8-bit write is not a write")
    xz = "f:\n  call rt_x\n  xor r8d, r8d\n  mov rax, r8\n  ret\n"
    _, reads, _ = grade(xz, "xor")
    ck(not reads, "a self-xor is a write")
    wb = "f:\n  call rt_x\n  mov qword ptr [rip + rtccb+40], r8\n  call rt_y\n  ret\n"
    _, reads, _ = grade(wb, "wb")
    ck(not reads, "the rtcc write-back store before the next call is transparent (it is what retires)")
    base_reg = "f:\n  call rt_x\n  mov rax, qword ptr [r8 + 8]\n  ret\n"
    _, reads, _ = grade(base_reg, "base")
    ck(len(reads) == 1, "r8 as a memory base is a read")
    ent = ".globl g\ng:\n  mov rax, r11\n  ret\n"
    _, reads, _ = grade(ent, "entry", entry=True)
    ck(len(reads) == 1 and reads[0][1] == "entry", "--entry: a read before the first write at a global entry is a finding")
    od = "   0:\te8 00 00 00 00       \tcall   0x5\n   5:\t4c 89 c0             \tmov    rax,r8\n   8:\tc3                   \tret\n"
    _, reads, _ = grade(objdump_to_asm(od), "objdump")
    ck(len(reads) == 1, "an objdump slab is graded the same way")
    isl = "   0:\t48 8b 05 01 00 00 00 \tmov    rax,QWORD PTR [rip+0x1]        # 0x8\n   7:\te9 08 00 00 00       \tjmp    0x14\n   c:\te8 00 00 00 00       \tcall   0x11\n  11:\t4c 89 c0             \tmov    rax,r8\n  14:\tc3                   \tret\n"
    isl = isl.replace("[rip+0x1]        # 0x8", "[rip+0x1]        # 0xc")
    _, reads, _ = grade(objdump_to_asm(isl), "island")
    ck(not reads, "an inline literal word skipped by a forward jmp is data, not a call and a read")
    num = "f:\n  call rt_x\n  jne 1f\n  mov r10, 1\n1:  mov r10, qword ptr [rbp + 8]\n  ret\n"
    _, reads, _ = grade(num, "num")
    ck(not reads, "a GNU numeric label is a label, not a mnemonic")
    numb = "f:\n  call rt_x\n  jne 1f\n  ret\n1:  mov rax, r10\n  ret\n"
    _, reads, _ = grade(numb, "numb")
    ck(len(reads) == 1, "a read behind a numeric label reached by 1f is a finding")
    print("selftest: %d FAIL" % fails)
    return 1 if fails else 0


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--asm", action="append", default=[])
    ap.add_argument("--objdump", action="append", default=[])
    ap.add_argument("--entry", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()
    total_sites, total_reads, files, budget = 0, [], 0, 0
    for path, conv in [(p, False) for p in a.asm] + [(p, True) for p in a.objdump]:
        try:
            text = open(path, errors="replace").read()
        except OSError as e:
            print("REFUSED %s: %s" % (path, e))
            return 2
        if conv:
            text = objdump_to_asm(text)
        n, reads, b = grade(text, os.path.basename(path), entry=a.entry)
        total_sites += n
        total_reads += reads
        budget += b
        files += 1
    if files == 0 or total_sites == 0:
        print("RTCC_SCRATCH_READS REFUSED: nothing graded (files=%d sites=%d)" % (files, total_sites))
        return 2
    print("RTCC_SCRATCH_READS sites=%d reads=%d files=%d budget_exhausted=%d" % (total_sites, len(total_reads), files, budget))
    for name, kind, i, site, r, j, raw in total_reads[: (len(total_reads) if a.list else 40)]:
        print("  READ %s %s@%d [%s] %s -> %s" % (name, kind, i, site, r, raw))
    if budget:
        print("  BUDGET %d walk(s) exhausted -- not placed, never counted clean" % budget)
        return 1
    return 1 if total_reads else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
