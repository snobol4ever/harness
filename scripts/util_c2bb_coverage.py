#!/usr/bin/env python3
"""util_c2bb_coverage.py -- IS EVERY C->BB TRANSFER VISIBLE IN A TRACE?  One number, with a denominator
that is the SAME population test_gate_no_c_to_bb.sh names.

⛔ WHY THIS EXISTS (ceo CEO-1091, on Lon's 2026-09-21 order to fix the broken gauges).  util_gc_acceptance.py
printed a line called "C->BB entry sites carrying rt_c2bb_hit" whose NUMERATOR counted occurrences of
rt_c2bb_hit in THREE NAMED FILES (by_name_dispatch.c, core/core.c, runtime_eval.c) and whose DENOMINATOR was
the INBOUND+OUTBOUND CALLBACK SITE count.  Those are not the same population, so the fraction was not a
coverage reading of anything -- and the 11 hooks that DO exist, all in rt/rt.c, were excluded BY CONSTRUCTION,
so the zero meant "the instrument does not look where the hooks are" (CEO-1041/1071).

⛔ THE DEFINITION OF A TRANSFER IS NOT RE-DERIVED HERE.  It is read from test_gate_no_c_to_bb.sh's own site
lines, exactly as test_gate_no_c_to_bb_ratchet.sh reads them, for the reason that gate's header gives: a second
grep would fork the definition and the two instruments would drift on what a transfer IS.

⛔⭐ WHAT HOOKED MEANS IS A **PROXIMITY** TEST AND NOT A FUNCTION-BODY TEST, AND THAT IS A CORRECTION THIS
FILE EARNED THE HARD WAY.  The first version asked "does the deciding FUNCTION call rt_c2bb_hit anywhere".
It was proven NOT TO FAIL ONCE: deleting the gen_h.callregime hook from rt_proc_call_gen_h left the number at
5 of 10, because that function carries a SECOND hook for a different road and the body test cannot tell two
sites apart.  A criterion that cannot go red when the defect is planted is not a criterion (INSTRUMENT LAWS).
⭐ THE CONVENTION THE TREE ACTUALLY HOLDS, measured over every hook on 2026-09-21: the hook sits on the SAME
LINE as the transfer or within two lines above it -- maximum observed distance 1.  So HOOKED means A
rt_c2bb_hit CALL WITHIN %d LINES AT OR ABOVE THE TRANSFER LINE.  It is a convention, it is enforced here, and
it is why a landing must put its hook next to its transfer rather than anywhere in the function.
⭐ WHAT HOOKED MEANS, STATED RATHER THAN ASSUMED, because the two shapes are not symmetric:
  (a) A C transfer is HOOKED when a rt_c2bb_hit call sits within the window at or above ITS OWN line.
  ⛔ A PROTOTYPE AND A CALL LIVE ON ONE LINE IN THIS TREE, and the first version of this reader skipped the
      whole line when it matched a declaration -- which turned rt_tiny_record_enter, whose two callers BOTH hook,
      into a false "no C caller found".  Declarations are STRIPPED from the line and the remainder is tested, so
      one line can carry both.  Found by reading this instrument's own output, not by it going quiet.
  (b) An __asm__ ENTRY SHIM cannot hook itself -- it has no C in it and makes no decision; the decision is at
      its CALLERS.  A shim is HOOKED only when EVERY C function that calls it also calls rt_c2bb_hit.  One
      unhooked caller makes the shim unhooked, because a trace that misses one road misses the transfer.
⛔ A SHIM WITH NO C CALLER AT ALL IS UNHOOKED, NOT VACUOUSLY HOOKED: "nobody calls it" is a claim about the
tree that this instrument cannot make (the caller may be emitted code or another shim), so it refuses to count
it as covered.  DARK is worse than RED.
"""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
SITE_RE = re.compile(r'^\s+(src/[A-Za-z0-9_./-]+):(\d+)\s+\(([^,]+),\s*([^)]+)\)\s*$')
FNHDR_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_ *]*\**\s*[A-Za-z_][A-Za-z0-9_]*\s*\(')
WINDOW = 3
def hooked_at(lines, ln):
    for k in range(ln - 1, max(-1, ln - 1 - WINDOW), -1):
        if 0 <= k < len(lines) and 'rt_c2bb_hit(' in lines[k] and 'void rt_c2bb_hit' not in lines[k]:
            return (ln - 1) - k
    return None
def readlines(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8', errors='replace') as f: return f.read().split('\n')
def enclosing_fn(lines, ln):
    for k in range(ln - 1, -1, -1):
        t = lines[k]
        if not t or t[0] in ' \t#}/': continue
        if t.rstrip().endswith(';'): continue
        if FNHDR_RE.match(t): return k
    return None
def fn_span(lines, start):
    depth = 0; seen = False
    for k in range(start, len(lines)):
        depth += lines[k].count('{') - lines[k].count('}')
        if '{' in lines[k]: seen = True
        if seen and depth <= 0: return k
    return len(lines) - 1
def asm_block_symbol(lines, ln):
    for k in range(ln - 1, -1, -1):
        if lines[k].lstrip().startswith('__asm__('):
            for j in range(k, min(k + 40, len(lines))):
                m = re.search(r'\.globl\s+([A-Za-z_][A-Za-z0-9_]*)', lines[j])
                if m: return m.group(1)
            return None
        if lines[k].rstrip() == ');': 
            if k < ln - 1: return None
    return None
def c_sources():
    out = []
    for d, _, fs in os.walk(os.path.join(ROOT, 'src')):
        for f in fs:
            if f.endswith('.c'): out.append(os.path.relpath(os.path.join(d, f), ROOT))
    return sorted(out)
def main():
    gate = os.path.join(HERE, 'test_gate_no_c_to_bb.sh')
    if not os.path.exists(gate):
        print('C2BB_COVERAGE REFUSE(2) -- test_gate_no_c_to_bb.sh is absent; this instrument measures ITS site list and invents no census of its own'); return 2
    p = subprocess.run(['bash', gate, '--informational'], cwd=ROOT, capture_output=True, text=True, timeout=900)
    out = p.stdout + p.stderr
    pop = re.search(r'population: examined (\d+) source files', out)
    if not pop:
        print('C2BB_COVERAGE REFUSE(2) -- the gate printed no population line, so it did not measure and neither did this'); return 2
    sites = []
    for line in out.split('\n'):
        m = SITE_RE.match(line)
        if m: sites.append((m.group(1), int(m.group(2)), m.group(3).strip(), m.group(4).strip()))
    if not sites:
        print('C2BB_COVERAGE hooked=0 sites=0 population=%s' % pop.group(1))
        print('  ⭐ ZERO TRANSFERS: the gate names none outside the sanctioned initial start, so there is nothing to hook.')
        return 0
    cache = {}
    def lines_of(rel):
        if rel not in cache: cache[rel] = readlines(rel)
        return cache[rel]
    srcs = c_sources()
    rows = []
    for (f, ln, fn, shape) in sites:
        L = lines_of(f)
        if shape == 'asm-shim':
            sym = asm_block_symbol(L, ln)
            if not sym:
                rows.append((f, ln, shape, sym or '?', 'UNHOOKED', 'the asm block declares no .globl this reader can find')); continue
            callers, unhooked = [], []
            syms = [sym]
            for _hop in range(3):
                more = []
                for _sy in syms:
                    for s in srcs:
                        SL = lines_of(s)
                        for k, t in enumerate(SL):
                            if not re.search(r'jmp\s+' + re.escape(_sy) + r'\\n', t): continue
                            up = asm_block_symbol(SL, k + 1)
                            if up and up not in syms and up not in more: more.append(up)
                if not more: break
                syms += more
            for _sy in syms:
              for s in srcs:
                  SL = lines_of(s)
                  for k, t in enumerate(SL):
                      if not re.search(r'\b%s\s*\(' % re.escape(_sy), t): continue
                      if '.globl' in t or t.lstrip().startswith('"'): continue
                      t2 = re.sub(r'\b(?:extern\s+)?[A-Za-z_][A-Za-z0-9_ *]*\b%s\s*\([^;()]*\)\s*;' % re.escape(_sy), ' ', t)
                      if not re.search(r'\b%s\s*\(' % re.escape(_sy), t2): continue
                      h = enclosing_fn(SL, k + 1)
                      if h is None: continue
                      name = re.sub(r'\s*\(.*', '', SL[h]).split()[-1].lstrip('*')
                      if name in syms: continue
                      callers.append('%s:%d' % (name, k + 1))
                      if hooked_at(SL, k + 1) is None: unhooked.append('%s:%d' % (name, k + 1))
            if not callers:
                rows.append((f, ln, shape, sym, 'UNHOOKED', 'no C caller found -- DARK, not vacuously covered'))
            elif unhooked:
                rows.append((f, ln, shape, sym, 'UNHOOKED', '%d of %d C call site(s) have no hook in the window: %s' % (len(unhooked), len(callers), ' '.join(sorted(set(unhooked))))))
            else:
                rows.append((f, ln, shape, sym, 'HOOKED', 'all %d C call site(s) hook within the window: %s' % (len(callers), ' '.join(sorted(set(callers))))))
        else:
            h = enclosing_fn(L, ln)
            name = re.sub(r'\s*\(.*', '', L[h]).split()[-1].lstrip('*') if h is not None else fn
            d = hooked_at(L, ln)
            if d is None: rows.append((f, ln, shape, name, 'UNHOOKED', 'no rt_c2bb_hit within %d line(s) at or above the transfer' % WINDOW))
            else: rows.append((f, ln, shape, name, 'HOOKED', 'rt_c2bb_hit %d line(s) above the transfer' % d))
    hooked = sum(1 for r in rows if r[4] == 'HOOKED')
    print('C2BB_COVERAGE hooked=%d sites=%d population=%s' % (hooked, len(rows), pop.group(1)))
    print('  -- per transfer site (denominator: the site lines test_gate_no_c_to_bb.sh itself prints) --')
    for (f, ln, shape, name, verdict, why) in rows:
        print('  %-9s %-34s %-12s %s:%d' % (verdict, name, shape, f, ln))
        print('      %s' % why)
    return 0
if __name__ == '__main__': sys.exit(main())
