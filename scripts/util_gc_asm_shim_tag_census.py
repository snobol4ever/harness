#!/usr/bin/env python3
"""util_gc_asm_shim_tag_census.py -- DOES EVERY HAND-WRITTEN BOX-ENTRY SHIM HAND THE WALKER A TAG, OR A RAW WORD?
One row per shim, NAMED, never a bare count (INSTRUMENT LAWS batch 30 clause 2).

⛔ WHY THIS EXISTS (cto 2026-09-21, row prolog-every-asm-entry-shim-pushes-callee-saved-registers-as-tagged-cells-
not-raw-words, ceo CEO-1099; law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812; ARCH-GC 6.2i).
bb_glue_enter_c2bb stores the registers it saves as TAGGED CELLS so the walker reads them as data.  The hand-
written asm entry shims did a plain pushq of the same registers: RAW WORDS in a region no compile-time frame map
describes.  A raw word holding a heap pointer is not merely unread -- under a MOVING collector it is never
RELOCATED, so the shim restores a pointer to vacated ground.

⛔ THE POPULATION IS COMPUTED, NOT LISTED, and that is deliberate.  A box-entry shim is an __asm__ block that
JUMPS INDIRECTLY (jmp *%reg) -- that instruction IS the entry into the box.  A block that only jmps to a named
symbol is a trampoline and is not a member (eval_chain_enter_only is the live example).  A hard-coded roster of
seven would be a criterion keyed on a list, and the list would drift the first time a shim was added.
⛔ AN INDIRECT JUMP THAT SAVES NOTHING IS A TRAMPOLINE TOO (cfo 2026-10-02, on the coo's red at 408a3f0c0): the
SETEXIT continuation (rt_setexit_continue_tramp) and, until CEO-1468 put it back inline, the trap stub (rt_setexit_take) jump indirectly into emitted
code from state recorded in g_rtccb, but push no register and carve no stack, so they leave no word for the walker
to read, tagged or raw.  A block with an indirect jmp and no pushq, no rsp adjustment and no store of a callee-saved
register through rsp or rbp (the cto's review: a mov of r13 into an existing frame slot is a save too) is printed as a
NAMED NOSAVE row and is not a member; the day such a block saves a register it becomes a member again by this rule.

⭐ WHAT COUNTS AS A DEFECT HERE IS NARROWER THAN "A RAW PUSH", AND THE NARROWING IS THE MEASUREMENT.  Of the five
callee-saved registers these shims save, exactly ONE is heap-bearing by the tree's own convention: r13 holds the
Σ subject pointer and r15d its length, which is why bb_glue_enter_c2bb stores that PAIR as a single DT_S cell.
r14 the glue tags DT_I; r12 it stores raw (a pointer clamped into the dcap region) and rbx it stores raw (the
live frontier).  So this census grades r13 as MUST-BE-TAGGED and reports the other four as the
DECLARED-CONVENTION set -- named on every run so that "raw" is never silent, and so the day one of them does
become heap-bearing the row is already written.
"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
FILES = ['src/runtime/rt/rt.c', 'src/runtime/runtime_eval.c']
CONV = ['rbx', 'r12', 'r14', 'r15']
def blocks(text):
    out = []; i = 0
    while True:
        k = text.find('__asm__(', i)
        if k < 0: return out
        j = text.find('\n);', k)
        if j < 0: return out
        out.append((k, text[k:j]))
        i = j + 1
def globl_of(b):
    m = re.search(r'\.globl\s+([A-Za-z_][A-Za-z0-9_]*)', b)
    return m.group(1) if m else None
def main():
    rows = []; nosave = []
    for rel in FILES:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            print('CENSUS asm-shim-tag REFUSE(2) -- %s is absent; this instrument names no population it did not read' % rel); return 2
        text = open(p, encoding='utf-8', errors='replace').read()
        for (off, b) in blocks(text):
            if not re.search(r'jmp\s+\*%', b): continue
            nm = globl_of(b)
            if not nm: continue
            ln = text.count('\n', 0, off) + 1
            raw13 = re.search(r'pushq\s+%r13', b) is not None
            cell = (re.search(r'movl\s+\$2,\s*\(%rsp\)', b) is not None
                    and re.search(r'movl\s+%r15d,\s*4\(%rsp\)', b) is not None
                    and re.search(r'movq\s+%r13,\s*8\(%rsp\)', b) is not None)
            rawconv = [r for r in CONV if re.search(r'pushq\s+%' + r + r'\b', b)]
            if not raw13 and not cell and not re.search(r'pushq\s', b) and not re.search(r'(subq|addq|leaq)\s+[^\n]*%rsp\b', b) and not re.search(r'movq?\s+%(rbx|rbp|r12|r13|r14|r15)\w*,\s*-?(0x)?[0-9a-f]*\(%(rsp|rbp)\b', b):
                nosave.append((rel, ln, nm)); continue
            verdict = 'TAGGED' if (cell and not raw13) else 'RAW'
            rows.append((rel, ln, nm, verdict, raw13, cell, rawconv))
    if not rows:
        print('CENSUS asm-shim-tag REFUSE(2) -- no __asm__ block with an indirect jump was found in %d file(s); a zero population here is an instrument that lost its reach, not a cured tree' % len(FILES)); return 2
    tagged = sum(1 for r in rows if r[3] == 'TAGGED')
    print('CENSUS asm-shim-tag tagged=%d shims=%d files=%d' % (tagged, len(rows), len(FILES)))
    print('  -- one row per box-entry shim (population: an __asm__ block containing an indirect jmp) --')
    for (rel, ln, nm, verdict, raw13, cell, rawconv) in rows:
        print('  %-7s %-26s %s:%d' % (verdict, nm, rel, ln))
        if verdict == 'RAW':
            print('      r13 pushed raw=%s, DT_S cell present=%s -- the Σ subject pointer reaches the walker as an untagged word' % ('yes' if raw13 else 'no', 'yes' if cell else 'no'))
        else:
            print('      r13/r15d stored as one DT_S cell at rsp+0..15; no bare pushq r13')
        print('      declared-convention raw saves in this shim: %s' % (' '.join(rawconv) if rawconv else '(none)'))
    for (rel, ln, nm) in nosave:
        print('  %-7s %-26s %s:%d' % ('NOSAVE', nm, rel, ln))
        print('      an indirect jmp with no pushq and no rsp adjustment: no word reaches the walker -- a trampoline, not a member')
    return 0
if __name__ == '__main__': sys.exit(main())
