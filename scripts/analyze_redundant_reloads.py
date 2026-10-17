#!/usr/bin/env python3
# Count redundant store/reload round-trips in SCRIP .s output:
#   mov [M], R   ...   mov R, [M]      with no write to R and no call in between.
# These are the copy-propagation targets the paper's Fig-2 removes (PEEP-0).
# Reports per file and flags whether the redundancy sits in a back-edge target
# (hot-loop) block. Conservative: any intervening write to R, or any call (R
# caller-saved), disqualifies — so reported reloads are safely removable.
import os as _os
S4E = _os.environ.get("S4E_HOME") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", ".."))   # D-17 sibling root
import sys, re, glob, os

CALLER_SAVED = {'rax','rcx','rdx','rsi','rdi','r8','r9','r10','r11',
                'eax','ecx','edx','esi','edi','r8d','r9d','r10d','r11d'}

def reg_family(r):
    m = {'eax':'rax','ecx':'rcx','edx':'rdx','ebx':'rbx','esi':'rsi','edi':'rdi',
         'r8d':'r8','r9d':'r9','r10d':'r10','r11d':'r11','r12d':'r12','r13d':'r13',
         'r14d':'r14','r15d':'r15'}
    return m.get(r, r)

def parse_blocks(path):
    section_code = True
    blocks = []          # list of (label, [instr,...])
    cur_lbl = None; cur = []
    def flush():
        nonlocal cur_lbl, cur
        if cur_lbl is not None:
            blocks.append((cur_lbl, cur))
        cur_lbl, cur = None, []
    for raw in open(path, encoding='utf-8', errors='replace'):
        s = raw.strip()
        if not s or s.startswith('#'): continue
        if s.startswith('.section') or s.startswith('.text') or s.startswith('.data') or s.startswith('.bss') or s.startswith('.rodata'):
            section_code = ('.text' in s) or (s == '.text'); continue
        if s.startswith('.'): continue
        m = re.match(r'^([A-Za-z_.$][\w.$]*)\s*:\s*$', s)
        if m:
            flush(); cur_lbl = m.group(1); continue
        if section_code and cur_lbl is not None:
            cur.append(s)
    flush()
    return blocks

ST = re.compile(r'^mov\s+(?:qword ptr |dword ptr )?\[([^\]]+)\]\s*,\s*(\w+)\s*$')
LD = re.compile(r'^mov\s+(\w+)\s*,\s*(?:qword ptr |dword ptr )?\[([^\]]+)\]\s*$')

def writes_reg(ins, fam):
    # does this instruction write register family `fam` as a destination?
    mm = re.match(r'^(\w+)\s+([%\w]+)', ins)
    if not mm: return False
    op, dst = mm.group(1), mm.group(2)
    if op in ('cmp','test','push','jmp','je','jne','jl','jg','jle','jge','ja','jb','jae','jbe','js','jns'): return False
    return reg_family(dst) == fam

def count_block(instrs):
    n = 0
    hits = []
    for i, ins in enumerate(instrs):
        ms = ST.match(ins)
        if not ms: continue
        mem, sreg = ms.group(1), ms.group(2)
        fam = reg_family(sreg)
        # scan forward for a reload of the same mem into the same reg family
        for j in range(i+1, len(instrs)):
            nxt = instrs[j]
            ml = LD.match(nxt)
            if ml and reg_family(ml.group(1)) == fam and ml.group(2) == mem:
                n += 1; hits.append((mem, sreg)); break
            if nxt.startswith('call'):
                if fam in {reg_family(x) for x in CALLER_SAVED}: break
            if writes_reg(nxt, fam): break
    return n, hits

def analyze(path):
    blocks = parse_blocks(path)
    targets = set()
    for lbl, ins in blocks:
        for s in ins:
            mm = re.match(r'^(?:jmp|je|jne|jl|jg|jle|jge|ja|jb|jae|jbe|js|jns)\s+([\w.$]+)\s*$', s)
            if mm: targets.add(mm.group(1))
    total = 0; hot = 0
    for lbl, ins in blocks:
        n, _ = count_block(ins)
        total += n
        # crude hot signal: block is a branch target (reachable in a loop body)
        if n and lbl in targets: hot += n
    return os.path.basename(path), total, hot

def main():
    pats = sys.argv[1:] or [f'{S4E}/corpus/benchmarks/snobol4/*.s']
    files = []
    for p in pats: files += sorted(glob.glob(p))
    print(f"{'file':28} {'redundant_reloads':>18} {'in_targeted_block':>18}")
    print('-'*68)
    T = 0; H = 0
    for f in files:
        name, n, hot = analyze(f)
        T += n; H += hot
        print(f"{name:28} {n:18} {hot:18}")
    print('-'*68)
    print(f"{'TOTAL':28} {T:18} {H:18}")

if __name__ == '__main__':
    main()
