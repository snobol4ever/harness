#!/usr/bin/env python3
"""util_rtx_cfi_walk.py -- prove, from the assembled objects, that every asm leaf declares its frame to the unwinder TRUTHFULLY
at every instruction (ceo CEO-1548, row rtx-every-leaf-carries-cfi-so-the-icon-frame-walk-crosses-a-frameless-leaf-by-the-
unwinder-and-the-fourteen-word-probe-goes-ceo-1548; ARCH-ICON-RTX.md section 9.8 fact (a); ARCH-RT-CALL-PROTOCOL.md).

WHY.  rt_icn_frames (gc_heap.c) and every other C-road walk reach the first emitted frame through the system unwinder: a C
function called from an asm leaf returns into the leaf, and only the leaf's FDE says where the leaf's own return address into
emitted code sits.  A leaf with no FDE stops the walk; a leaf whose FDE lies at ONE pc (a push the CFI does not count, a stub
label reached at a deeper stack than the text before it) sends the walk to a wrong word.  CFI is metadata: zero instructions.

WHAT IT CHECKS, per object (objdump -d -r -l for the instructions, readelf --debug-dump=frames for the FDEs, the raw opcodes
interpreted here, remember/restore included):
  (1) COVERAGE -- every instruction of every executable section lies inside an FDE (alignment padding between bodies aside).
  (2) TRUTH -- every FDE is walked from each global symbol inside it (CFA = rsp+8) along every path, the stack modelled through
      push, pop, sub/add/lea rsp, the frame-pointer forms (push rbp; mov rbp,rsp ... leave) and the dynamic alignment of
      RTX_CALL_ALIGN (push rsp; push [rsp]; and rsp,-16, whose CFA is [rsp+d]+k, a DW_CFA_def_cfa_expression of exactly
      DW_OP_breg7 d; DW_OP_deref; DW_OP_plus_uconst k); at every reached instruction the FDE's CFA rule must equal the model,
      and every callee-saved register (rbx rbp r12-r15) the body has pushed must be recorded at its slot (and no other).
  (3) The model itself: two paths reaching one instruction with different stacks, an rsp write it cannot follow, or a pop
      below the entry, is UNANALYZABLE and counts as a violation -- a body the walker cannot read is never certified.

Usage: util_rtx_cfi_walk.py OBJ...     prints one VIOLATION line per defect (file:line, the instruction, the model and the
rule), then `RTX-CFI objects=N fdes=N instructions=N checked=N violations=N`.  Exit 0 = every leaf proven, 1 = violations,
2 = could not measure.
"""
import os, re, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from util_rtx_abi_walk import split_ops, rsp_disp

PAD = re.compile(r'^(nop|xchg\s+ax,ax|cs nop|data16|int3)')
CALLEE = ('rbx', 'rbp', 'r12', 'r13', 'r14', 'r15')
DWREG = {0: 'rax', 1: 'rdx', 2: 'rcx', 3: 'rbx', 4: 'rsi', 5: 'rdi', 6: 'rbp', 7: 'rsp', 8: 'r8', 9: 'r9', 10: 'r10',
         11: 'r11', 12: 'r12', 13: 'r13', 14: 'r14', 15: 'r15', 16: 'rip'}


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    if r.returncode != 0:
        print('REFUSED: %s failed: %s' % (' '.join(cmd), r.stderr.strip()[:300]))
        sys.exit(2)
    return r.stdout


def disasm(obj):
    txt = run(['objdump', '-d', '-r', '-l', '-M', 'intel', '--no-show-raw-insn', obj])
    code, order, syms, src, last = {}, [], {}, None, None
    for line in txt.split('\n'):
        if line.startswith('Disassembly of section '):
            last = None
            continue
        m = re.match(r'^([0-9a-f]+) <([^>]+)>:\s*$', line)
        if m:
            syms[m.group(2)] = int(m.group(1), 16)
            continue
        m = re.match(r'^(/\S+|\S+\.[sS]):(\d+)', line)
        if m:
            src = '%s:%s' % (os.path.basename(m.group(1)), m.group(2))
            continue
        m = re.match(r'^\s+([0-9a-f]+):\s+(R_X86_64_\S+)\s+(\S+)$', line)
        if m:
            if last is not None:
                code[last]['rel'] = (m.group(2), re.sub(r'[-+]0x[0-9a-f]+$', '', m.group(3)))
            continue
        m = re.match(r'^\s+([0-9a-f]+):\s+(.*?)\s*$', line)
        if m:
            ins = re.sub(r'\s+#.*$', '', m.group(2)).strip()
            ins = re.sub(r'^(?:notrack|bnd|ds)\s+', '', ins)
            a = int(m.group(1), 16)
            code[a] = {'ins': ins, 'rel': None, 'next': None, 'src': src or '?'}
            if last is not None:
                code[last]['next'] = a
            order.append(a)
            last = a
    return code, order, syms


def fdes(obj):
    txt = run(['readelf', '--debug-dump=frames', obj])
    out, cie_init, cur, rows, state, stack, loc, mode = [], [], None, None, None, [], 0, None

    def snap():
        rows.append((loc, dict(state)))

    for line in txt.split('\n'):
        m = re.match(r'^[0-9a-f]+ [0-9a-f]+ [0-9a-f]+ CIE', line)
        if m:
            mode, cie_init = 'cie', []
            continue
        m = re.match(r'^[0-9a-f]+ [0-9a-f]+ [0-9a-f]+ FDE .*pc=([0-9a-f]+)\.\.([0-9a-f]+)', line)
        if m:
            mode = 'fde'
            lo, hi = int(m.group(1), 16), int(m.group(2), 16)
            state = {'cfa': ('rsp', 8)}
            for op in cie_init:
                apply(state, op, [])
            rows, stack, loc = [], [], lo
            cur = (lo, hi, rows)
            out.append(cur)
            snap()
            continue
        s = line.strip()
        if not s.startswith('DW_CFA_') or s == 'DW_CFA_nop':
            continue
        if mode == 'cie':
            cie_init.append(s)
            continue
        if mode != 'fde':
            continue
        m = re.match(r'DW_CFA_advance_loc\d*: \d+ to ([0-9a-f]+)', s)
        if m:
            loc = int(m.group(1), 16)
            continue
        if s == 'DW_CFA_remember_state':
            stack.append(dict(state)); continue
        if s == 'DW_CFA_restore_state':
            if stack: state.clear(); state.update(stack.pop())
            snap(); continue
        if s == 'DW_CFA_nop':
            continue
        apply(state, s, cie_init)
        snap()
    return out


def apply(state, s, cie_init):
    m = re.match(r'DW_CFA_def_cfa: r(\d+) \(\w+\) ofs (-?\d+)', s)
    if m:
        state['cfa'] = (DWREG[int(m.group(1))], int(m.group(2))); return
    m = re.match(r'DW_CFA_def_cfa_offset(?:_sf)?: (-?\d+)', s)
    if m:
        state['cfa'] = (state['cfa'][0] if state['cfa'][0] != 'exp' else '?', int(m.group(1))); return
    m = re.match(r'DW_CFA_def_cfa_register: r(\d+)', s)
    if m:
        state['cfa'] = (DWREG[int(m.group(1))], state['cfa'][1] if state['cfa'][0] != 'exp' else None); return
    m = re.match(r'DW_CFA_def_cfa_expression \(DW_OP_breg7 \(rsp\): (-?\d+); DW_OP_deref; DW_OP_plus_uconst: (\d+)\)$', s)
    if m:
        state['cfa'] = ('exp', (int(m.group(1)), int(m.group(2)))); return
    if s.startswith('DW_CFA_def_cfa_expression'):
        state['cfa'] = ('exp', s); return
    m = re.match(r'DW_CFA_offset(?:_extended)?: r(\d+) \(\w+\) at cfa(-?\d+)', s)
    if m:
        state[DWREG[int(m.group(1))]] = int(m.group(2)); return
    m = re.match(r'DW_CFA_(?:restore|restore_extended|same_value): r(\d+)', s)
    if m:
        state.pop(DWREG[int(m.group(1))], None)
        for op in cie_init:
            m2 = re.match(r'DW_CFA_offset(?:_extended)?: r(\d+) \(\w+\) at cfa(-?\d+)', op)
            if m2 and DWREG[int(m2.group(1))] == DWREG[int(m.group(1))] and 'same_value' not in s:
                state[DWREG[int(m.group(1))]] = int(m2.group(2))
        return
    state.setdefault('unknown', []).append(s)


def rule_at(rows, a):
    r = None
    for loc, st in rows:
        if loc <= a: r = st
        else: break
    return r


def fmt_model(st):
    rsp, rbp, dyn, saves = st[0], st[1], st[2], st[3]
    parts = []
    if dyn is not None: parts.append('[rsp+%d]+%d' % dyn)
    if rsp is not None: parts.append('rsp+%d' % rsp)
    if rbp is not None: parts.append('rbp+%d' % rbp)
    s = ' = '.join(parts) or 'unknown'
    if saves: s += ' saved{%s}' % ','.join('%s@cfa-%d' % (r, o) for r, o in sorted(saves))
    return s


def fmt_rule(rule):
    c = rule['cfa']
    s = ('[rsp+%d]+%d' % c[1]) if (c[0] == 'exp' and isinstance(c[1], tuple)) else ('%s+%s' % c)
    sv = sorted((r, -o) for r, o in rule.items() if r in CALLEE)
    if sv: s += ' saved{%s}' % ','.join('%s@cfa-%d' % x for x in sv)
    return s


def matches(st, rule):
    rsp, rbp, dyn, saves = st[0], st[1], st[2], st[3]
    c = rule['cfa']
    if c[0] == 'rsp': ok = rsp is not None and c[1] == rsp
    elif c[0] == 'rbp': ok = rbp is not None and c[1] == rbp
    elif c[0] == 'exp': ok = dyn is not None and c[1] == dyn
    else: ok = False
    want = dict((r, -o) for r, o in saves)
    have = dict((r, o) for r, o in rule.items() if r in CALLEE)
    return ok and want == have


def walk_fde(lo, hi, rows, code, syms, errs):
    entries = sorted(set(a for a in syms.values() if lo <= a < hi) | {lo})
    seen, todo, checked = {}, [], set()
    for a in entries:
        todo.append((a, (8, None, None, frozenset(), (), None)))
    while todo:
        a, st = todo.pop()
        if a in seen:
            if seen[a] != st and (a, 'join') not in checked:
                checked.add((a, 'join'))
                errs.append('%s  0x%x %s: UNANALYZABLE two paths arrive with different stacks: %s / %s'
                            % (code[a]['src'] if a in code else '?', a, code[a]['ins'] if a in code else '?', fmt_model(seen[a]), fmt_model(st)))
            continue
        if a not in code or not (lo <= a < hi):
            errs.append('0x%x: flows outside its FDE [0x%x,0x%x)' % (a, lo, hi)); continue
        seen[a] = st
        c = code[a]
        rule = rule_at(rows, a)
        checked.add(a)
        if rule is None or not matches(st, rule):
            errs.append('%s  0x%x %-34s model %s  CFI %s' % (c['src'], a, c['ins'], fmt_model(st), fmt_rule(rule) if rule else 'none'))
        rsp, rbp, dyn, saves, slots, pend = st
        mn, o = split_ops(c['ins'])
        nxt = c['next']
        o0 = o[0].strip().lower() if o else ''
        def go(k, rsp=rsp, rbp=rbp, dyn=dyn, saves=saves, slots=slots, pend=None):
            if k is not None: todo.append((k, (rsp, rbp, dyn, saves, slots, pend)))
        def bad(why):
            errs.append('%s  0x%x %s: UNANALYZABLE %s' % (c['src'], a, c['ins'], why))
        def adj(n):
            return (rsp + n if rsp is not None else None), ((dyn[0] + n, dyn[1]) if dyn is not None else None)
        if mn in ('ud2', 'hlt', 'int3'):
            continue
        if mn == 'ret':
            continue
        if mn in ('push', 'pushf', 'pushfq'):
            r2, d2 = adj(8)
            sv, sl = saves, slots + ((o0 if mn == 'push' else 'flags'),)
            if mn == 'push' and o0 in CALLEE and o0 not in dict(saves) and r2 is not None:
                sv = saves | {(o0, r2)}
            p2 = None
            if mn == 'push' and o0 == 'rsp' and rsp is not None: p2 = ('rsp', rsp)
            elif mn == 'push' and pend and pend[0] == 'rsp' and rsp_disp(o[0]) == 0: p2 = ('copy', pend[1])
            go(nxt, rsp=r2, dyn=d2, saves=sv, slots=sl, pend=p2); continue
        if mn in ('pop', 'popf', 'popfq'):
            if not slots:
                bad('pop below the entry'); continue
            top = slots[-1]
            r2, d2 = adj(-8)
            sv = saves
            if top in CALLEE and top in dict(saves) and dict(saves)[top] == rsp:
                sv = frozenset(x for x in saves if x[0] != top)
            rb = None if o0 == 'rbp' else rbp
            go(nxt, rsp=r2, rbp=rb, dyn=d2, saves=sv, slots=slots[:-1]); continue
        if mn in ('sub', 'add') and o0 == 'rsp':
            m = re.fullmatch(r'0x([0-9a-f]+)', o[1].strip()) if len(o) > 1 else None
            if not m:
                bad('rsp adjusted by an unknown amount'); continue
            n = int(m.group(1), 16) * (1 if mn == 'sub' else -1)
            if n % 8:
                bad('rsp adjusted by a non-multiple of 8'); continue
            r2, d2 = adj(n)
            sl = slots + ('anon',) * (n // 8) if n > 0 else slots[:len(slots) + n // 8]
            if n < 0 and len(slots) + n // 8 < 0:
                bad('rsp raised past the entry'); continue
            go(nxt, rsp=r2, dyn=d2, slots=sl); continue
        if mn == 'lea' and o0 == 'rsp':
            m = re.fullmatch(r'\[rsp([+-])0x([0-9a-f]+)\]', o[1].strip()) if len(o) > 1 else None
            if not m:
                bad('rsp loaded by an lea the walker cannot follow'); continue
            n = int(m.group(2), 16) * (1 if m.group(1) == '-' else -1)
            r2, d2 = adj(n)
            sl = slots + ('anon',) * (n // 8) if n > 0 else slots[:len(slots) + n // 8]
            go(nxt, rsp=r2, dyn=d2, slots=sl); continue
        if mn == 'and' and o0 == 'rsp':
            if pend and pend[0] == 'copy' and rsp == pend[1] + 16 and dyn is None:
                go(nxt, rsp=None, dyn=(8, pend[1]), slots=slots + ('pad',)); continue
            if rbp is not None:
                go(nxt, rsp=None, slots=slots + ('pad',)); continue
            bad('rsp aligned with no saved copy and no frame pointer'); continue
        if mn == 'mov' and o0 == 'rbp' and len(o) > 1 and o[1].strip().lower() == 'rsp':
            go(nxt, rbp=rsp); continue
        if mn == 'mov' and o0 == 'rsp' and len(o) > 1:
            s1 = o[1].strip().lower()
            if s1 == 'rbp' and rbp is not None:
                go(nxt, rsp=rbp, dyn=None, slots=slots[:max((rbp - 8) // 8, 0)]); continue
            if dyn is not None and rsp_disp(o[1]) == dyn[0]:
                sl = slots
                if 'pad' in sl: sl = sl[:len(sl) - sl[::-1].index('pad') - 1 - 2]
                go(nxt, rsp=dyn[1], dyn=None, slots=sl); continue
            bad('rsp loaded from something the walker cannot follow'); continue
        if mn == 'leave':
            if rbp is None:
                bad('leave with no frame pointer the walker knows'); continue
            sv = frozenset(x for x in saves if x[0] != 'rbp')
            go(nxt, rsp=rbp - 8, rbp=None, dyn=None, saves=sv, slots=slots); continue
        if o0 in ('rbp', 'ebp', 'bp') and mn not in ('cmp', 'test', 'push', 'bt'):
            go(nxt, rbp=None); continue
        if o0 in ('rsp', 'esp', 'sp') and mn not in ('cmp', 'test', 'push', 'bt'):
            bad('an rsp write the walker cannot follow'); continue
        if mn == 'call':
            m = re.fullmatch(r'([0-9a-f]+) <.*>', o[0] if o else '')
            if c['rel'] is None and m and lo <= int(m.group(1), 16) < hi:
                bad('a call into its own body'); continue
            go(nxt); continue
        if mn.startswith('j'):
            tgt = o[0] if o else ''
            m = re.fullmatch(r'([0-9a-f]+) <.*>', tgt)
            local = int(m.group(1), 16) if (m and c['rel'] is None) else None
            if local is not None and not (lo <= local < hi):
                if (rsp, dyn, saves) != (8, None, frozenset()):
                    bad('a jump into another body with the stack not at its entry')
                if mn != 'jmp': go(nxt)
                continue
            if local is not None:
                if mn != 'jmp': go(nxt)
                go(local); continue
            if mn != 'jmp': go(nxt)
            continue
        go(nxt)
    return seen


def bodies(order, syms, code):
    starts = sorted(set(a for a in syms.values() if a in code))
    out = []
    for i, a in enumerate(starts):
        b = starts[i + 1] if i + 1 < len(starts) else (order[-1] + 1 if order else a)
        name = [n for n, v in syms.items() if v == a][0]
        out.append((name, a, b))
    return out


def check(obj, only=None):
    code, order, syms = disasm(obj)
    tab = fdes(obj)
    errs, checked, nf, exempt = [], 0, 0, []
    covered = set()
    body = bodies(order, syms, code)
    keep = None
    if only is not None:
        missing = sorted(set(only) - set(syms))
        if missing:
            print('REFUSED: %s defines no %s' % (obj, ', '.join(missing))); sys.exit(2)
        keep = [(n, a, b) for n, a, b in body if n in only]
        body = keep
        tab = [t for t in tab if any(t[0] <= a < t[1] for n, a, b in keep)]
    for lo, hi, rows in tab:
        nf += 1
        for rl in rows:
            if 'unknown' in rl[1]:
                errs.append('%s: FDE [0x%x,0x%x) carries an opcode the walker does not read: %s' % (os.path.basename(obj), lo, hi, rl[1]['unknown'][0]))
                break
        seen = walk_fde(lo, hi, rows, code, syms, errs)
        checked += len(seen)
        covered.update(a for a in order if lo <= a < hi)
    for name, a0, b0 in body:
        ins = [a for a in order if a0 <= a < b0]
        if not any(code[a]['ins'].split()[0] == 'call' for a in ins):
            if any(a not in covered and not PAD.match(code[a]['ins']) for a in ins): exempt.append(name)
            continue
        for a in ins:
            if a in covered or PAD.match(code[a]['ins']): continue
            errs.append('%s  0x%x %s: NO FDE covers this instruction of %s, a body that makes a call' % (code[a]['src'], a, code[a]['ins'], name))
    n_ins = sum(1 for a in order if keep is None or any(x <= a < y for n, x, y in keep))
    return errs, nf, n_ins, checked, exempt


def main(argv):
    if not argv:
        print('REFUSED: no objects named'); return 2
    tot, nv, ex = [0, 0, 0, 0], 0, []
    for arg in argv:
        obj, only = arg, None
        if ':' in arg and not os.path.exists(arg):
            obj, rest = arg.split(':', 1)
            only = [x for x in rest.split(',') if x]
        if not os.path.exists(obj):
            print('REFUSED: %s does not exist' % obj); return 2
        errs, nf, ni, nc, exempt = check(obj, only)
        for e in errs: print('  VIOLATION  %s' % e)
        tot[0] += 1; tot[1] += nf; tot[2] += ni; tot[3] += nc
        nv += len(errs)
        ex.extend(exempt)
    if ex: print('  EXEMPT (no FDE, and the body makes no call, so no return address can point into it): %s' % ' '.join(sorted(ex)))
    print('RTX-CFI objects=%d fdes=%d instructions=%d checked=%d exempt=%d violations=%d' % (tot[0], tot[1], tot[2], tot[3], len(ex), nv))
    return 1 if nv else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
