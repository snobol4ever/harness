#!/usr/bin/env python3
"""util_rtx_abi_walk.py -- prove, from the assembled objects, that every RTX entry keeps the RTCC four.

THE CONTRACT (src/runtime/rtx/rtx_abi.inc, ARCH-SNOBOL4-RTX.md section 2; Lon 2026-09-23, CEO-1224):
emitted code calls an asm-runtime entry BARE, so the entry returns r8, r10 and r11 exactly as it
received them and r9 as the GVA base. This walker reads `objdump -d -r` of each object built from
src/runtime/rtx/*.s -- the instruction stream after cpp AND gas macros, with the relocations that
name every external target -- and abstract-interprets every entry along every path:

  state  = the four registers, each E (the value the entry received), G (the GVA base, r9 only)
           or X (anything else), plus the stack in 8-byte slots (the return address, saved
           registers, anonymous slots, a dynamic-alignment pad).
  call   = into another RTX entry through the GOT: r8/r10/r11 kept, r9 := G.
           into another RTX entry through a PLT slot: r10/r11 := X (a lazily bound slot resolves
           through _dl_runtime_resolve, which jumps through r11), r9 := G.
           into anything else (C, libc): all four := X.
  align  = every call is made with rsp 16-aligned: an even number of slots since the entry (whose one slot is
           the return address) or since the last `and rsp, -16`.
  ret    = the stack must hold only the return address; r8, r10, r11 must be E; r9 must be E or G,
           and G alone when the entry reads r9 before writing it (it came in as an argument), EXCEPT a ret reached
           right after mov eax,0xff: that is a DECLINE (ARCH-RT-CALL-PROTOCOL.md section 15), the entry hands every
           argument back as received, so r9 may be its sixth argument; the emitted site's twin call reloads it.
  tail   = a jump to another RTX entry through the GOT is judged like a ret; a jump into C or
           through a PLT slot is a violation (the callee returns to our caller with the four gone).

Anything the walker cannot model (an unknown stack adjustment, a pop below the frame, a pad it
cannot see through, a local call) is reported UNANALYZABLE and counts as a violation: the gate
refuses to certify a body it could not read.

Usage: util_rtx_abi_walk.py OBJ... [--entries FILE] [--table TABLE]   (FILE: one name per line, the registry; every
global function the objects define must be in it; TABLE: the generated src/templates/x86/rtx_clobber_table.inc --
under it a register an entry's row records is the contract (ARCH-RT-CALL-PROTOCOL.md section 15: the emitted site
re-establishes it), a nested call takes on its callee's recorded set, and an unrecorded write stays a violation). Exit 0 = every entry proven, 1 = violations,
2 = could not measure.
"""
import re, subprocess, sys

REGS = ('r8', 'r9', 'r10', 'r11')
CLOB_TABLE = {}
RECORDED = None
ALIAS = {}
for base in REGS:
    for sfx in ('', 'd', 'w', 'b'):
        ALIAS[base + sfx] = base
READ_ONLY = {'cmp', 'test', 'bt', 'push', 'ucomisd', 'comisd', 'ucomiss', 'comiss', 'ptest'}
PURE_WRITE = {'mov', 'movabs', 'lea', 'movzx', 'movsx', 'movsxd', 'pop', 'movq', 'movd'}
MAXDEPTH = 96


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    if r.returncode != 0:
        print('REFUSED: %s failed: %s' % (' '.join(cmd), r.stderr.strip()[:300]))
        sys.exit(2)
    return r.stdout


def load(objs):
    code, funcs = {}, {}
    for obj in objs:
        txt = run(['objdump', '-d', '-r', '-M', 'intel', '--no-show-raw-insn', obj])
        sec, last = None, None
        for line in txt.split('\n'):
            m = re.match(r'^Disassembly of section (\S+):', line)
            if m:
                sec, last = m.group(1), None
                continue
            m = re.match(r'^([0-9a-f]+) <([^>]+)>:\s*$', line)
            if m:
                funcs.setdefault(m.group(2), (obj, sec, int(m.group(1), 16)))
                continue
            m = re.match(r'^\s+([0-9a-f]+):\s+(R_X86_64_\S+)\s+(\S+)$', line)
            if m:
                if last is not None:
                    code[last]['rel'] = (m.group(2), re.sub(r'[-+]0x[0-9a-f]+$', '', m.group(3)))
                continue
            m = re.match(r'^\s+([0-9a-f]+):\s+(.*?)\s*$', line)
            if m and sec is not None:
                ins = re.sub(r'\s+#.*$', '', m.group(2)).strip()
                ins = re.sub(r'^(?:notrack|bnd|ds)\s+', '', ins)
                key = (obj, sec, int(m.group(1), 16))
                code[key] = {'ins': ins, 'rel': None, 'next': None}
                if last is not None:
                    code[last]['next'] = key
                last = key
    return code, funcs


def split_ops(ins):
    parts = ins.split(None, 1)
    mn = parts[0].lower() if parts else ''
    rest = parts[1] if len(parts) > 1 else ''
    out, depth, cur = [], 0, ''
    for ch in rest:
        if ch == '[': depth += 1
        if ch == ']': depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip(): out.append(cur.strip())
    return mn, out


def regof(op):
    return ALIAS.get(op.strip().lower())


def rsp_disp(op):
    m = re.fullmatch(r'(?:QWORD|DWORD|WORD|BYTE) PTR \[rsp(?:\+0x([0-9a-f]+))?\]', op.strip())
    if not m: return None
    return int(m.group(1), 16) if m.group(1) else 0


def reads(mn, o, reg):
    if mn == 'push' or not o: return False
    if mn in ('xor', 'sub') and len(o) == 2 and o[0].strip().lower() == o[1].strip().lower(): return False
    pat = re.compile(r'\b' + reg + r'[dwb]?\b')
    pure = mn in PURE_WRITE or mn.startswith('set')
    for i, op in enumerate(o):
        if i == 0 and pure and regof(op) == reg: continue
        if pat.search(op): return True
    return False


def slotval(r, v):
    if v == 'E': return 'E' + r[1:]
    if v == 'G' and r == 'r9': return 'G9'
    return 'X'


def regval(r, slot):
    if slot == 'E' + r[1:]: return 'E'
    if slot == 'G9' and r == 'r9': return 'G'
    return 'X'


def gotrel(rel):
    return rel is not None and ('GOTPC' in rel[0])


_PREV = {}
def prev_ins(code, key):
    if id(code) not in _PREV:
        _PREV[id(code)] = {c['next']: k for k, c in code.items() if c.get('next') is not None}
    k = _PREV[id(code)].get(key)
    return code[k]['ins'] if k else ''
def walk(name, code, funcs, rtx, clob=None):
    if name not in funcs: return ['%s: no body found in the objects' % name]
    obj, sec, base = funcs[name]
    errs, seen, rets, r9_input = [], set(), [], []
    own = set((RECORDED or {}).get(name, ()))
    todo = [((obj, sec, base), (('E', 'E', 'E', 'E'), ('RA',), -1, False))]
    while todo:
        key, st = todo.pop()
        if (key, st) in seen: continue
        seen.add((key, st))
        if len(seen) > 400000:
            errs.append('%s: state space exploded' % name); break
        if key not in code:
            errs.append('%s: flows off the end of its section' % name); continue
        c = code[key]; mn, o = split_ops(c['ins'])
        regs, stack, rbpd, r9w = list(st[0]), list(st[1]), st[2], st[3]
        where = '%s+0x%x  %s' % (name, key[2] - base, c['ins'])
        nxt = c['next']
        def getr(r): return regs[REGS.index(r)]
        def setr(r, v): regs[REGS.index(r)] = v
        def push_state(k, **kw):
            todo.append((k, (tuple(kw.get('regs', regs)), tuple(kw.get('stack', stack)), kw.get('rbpd', rbpd), kw.get('r9w', r9w))))
        if not r9w and reads(mn, o, 'r9'):
            r9_input.append(where)
        if getr('r9') in ('KX', 'GK', 'RTCCK') and reads(mn, o, 'r9') and not (getr('r9') == 'RTCCK' and re.fullmatch(r'QWORD PTR \[r9\+0x30\]', o[1].strip() if len(o) > 1 else '')):
            msg = '%s: reads r9 after a call or a GVA reload destroyed the value the body kept in it (contract point 2)' % where
            if msg not in errs: errs.append(msg)
        for kr in ('r8', 'r10', 'r11'):
            if getr(kr) == 'K' and (reads(mn, o, kr) or (mn == 'push' and o and regof(o[0]) == kr)):
                msg = '%s: reads %s after a call clobbered it -- a value the body still needs after a call lives in its own frame (contract point 2)' % (where, kr)
                if msg not in errs: errs.append(msg)
        if mn == 'ud2' or mn == 'hlt':
            continue
        if mn in ('endbr64', 'cld', 'nop') or mn.startswith('nop') or mn.startswith('rep') or mn in ('movsb', 'cmpsb', 'stosb', 'lodsb', 'scasb'):
            push_state(nxt); continue
        if mn == 'push':
            r = regof(o[0]) if o else None
            if r: stack.append(slotval(r, getr(r)))
            elif o and o[0].strip().lower() == 'rsp': stack.append('SP%d' % len(stack))
            elif o and rsp_disp(o[0]) is not None:
                k = rsp_disp(o[0]) // 8
                stack.append(stack[-1 - k] if k < len(stack) and 'PAD' not in stack[len(stack) - 1 - k:] else 'X')
            else: stack.append('X')
            if len(stack) > MAXDEPTH:
                errs.append('UNANALYZABLE %s: stack deeper than %d slots' % (where, MAXDEPTH)); continue
            push_state(nxt); continue
        if mn in ('pushfq', 'pushf'):
            stack.append('X'); push_state(nxt); continue
        if mn in ('pop', 'popfq', 'popf'):
            if len(stack) <= 1 or stack[-1] == 'PAD':
                errs.append('UNANALYZABLE %s: pop below the frame' % where); continue
            v = stack.pop()
            r = regof(o[0]) if (mn == 'pop' and o) else None
            if r:
                setr(r, regval(r, v))
                if r == 'r9': r9w = True
            push_state(nxt); continue
        if mn in ('sub', 'add') and o and o[0].lower() == 'rsp':
            m = re.fullmatch(r'0x([0-9a-f]+)', o[1]) if len(o) > 1 else None
            if not m or int(m.group(1), 16) % 8:
                errs.append('UNANALYZABLE %s: rsp adjusted by an unknown amount' % where); continue
            n = int(m.group(1), 16) // 8
            if mn == 'sub':
                stack.extend(['X'] * n)
            else:
                if n >= len(stack) or 'PAD' in stack[len(stack) - n:]:
                    errs.append('UNANALYZABLE %s: rsp raised past the frame' % where); continue
                del stack[len(stack) - n:]
            push_state(nxt); continue
        if mn == 'lea' and o and o[0].lower() == 'rsp':
            m = re.fullmatch(r'\[rsp([+-])0x([0-9a-f]+)\]', o[1].strip()) if len(o) > 1 else None
            if not m or int(m.group(2), 16) % 8:
                errs.append('UNANALYZABLE %s' % where); continue
            n = int(m.group(2), 16) // 8
            if m.group(1) == '-': stack.extend(['X'] * n)
            else:
                if n >= len(stack) or 'PAD' in stack[len(stack) - n:]:
                    errs.append('UNANALYZABLE %s: rsp raised past the frame' % where); continue
                del stack[len(stack) - n:]
            push_state(nxt); continue
        if mn == 'and' and o and o[0].lower() == 'rsp':
            stack.append('PAD'); push_state(nxt); continue
        if mn == 'mov' and len(o) == 2 and o[0].lower() == 'rbp' and o[1].lower() == 'rsp':
            push_state(nxt, rbpd=len(stack)); continue
        if mn == 'mov' and o and o[0].lower() == 'rsp':
            src = o[1].strip() if len(o) > 1 else ''
            if src.lower() == 'rbp' and 0 <= rbpd <= len(stack):
                del stack[rbpd:]; push_state(nxt); continue
            if rsp_disp(src) == 8 and stack and stack[-1] == 'PAD':
                vals = set(stack[i] for i in (len(stack) - 2, len(stack) - 3) if i >= 0)
                if len(vals) == 1 and next(iter(vals)).startswith('SP'):
                    del stack[int(next(iter(vals))[2:]):]; push_state(nxt); continue
            errs.append('UNANALYZABLE %s: rsp loaded from something the walker cannot follow' % where); continue
        if mn == 'ret':
            bad = []
            decl = re.fullmatch(r'mov\s+(eax,0xff|eax,0xfffffffe|rax,0xffffffffffffffff)', prev_ins(code, key)) is not None
            if stack != ['RA']: bad.append('%d slot(s) left above the return address' % (len(stack) - 1))
            if clob is not None:
                for r in ('r8', 'r10', 'r11'):
                    if getr(r) != 'E': clob.add(r)
                if getr('r9') not in ('E', 'G', 'GK'): clob.add('r9')
                if bad: errs.append('%s: %s' % (where, '; '.join(bad)))
                else: rets.append((where, 'G' if decl else getr('r9')))
                continue
            for r in ('r8', 'r10', 'r11'):
                if getr(r) != 'E' and r not in own: bad.append('%s not returned' % r)
            if getr('r9') not in ('E', 'G', 'GK') and 'r9' not in own: bad.append('r9 not returned as GVA')
            if bad: errs.append('%s: %s' % (where, '; '.join(bad)))
            else: rets.append((where, 'G' if decl else getr('r9')))
            continue
        if mn == 'call' or mn.startswith('j'):
            tgt = o[0] if o else ''
            rel = c['rel']
            m = re.fullmatch(r'([0-9a-f]+) <.*>', tgt)
            local = (obj, sec, int(m.group(1), 16)) if (m and rel is None) else None
            if mn == 'call':
                if local is not None:
                    errs.append('UNANALYZABLE %s: a local call' % where); continue
                above = stack[::-1].index('PAD') if 'PAD' in stack else len(stack)
                if above % 2:
                    errs.append('%s: the call is made with rsp misaligned (%d slot(s) since the last 16-byte point)' % (where, above))
                if rel is not None and rel[1] in rtx:
                    setr('r9', 'GK' if getr('r9') in ('X', 'E', 'KX', 'GK', 'RTCCK') else 'G')
                    if not gotrel(rel):
                        setr('r10', 'K'); setr('r11', 'K')
                    if clob is not None:
                        for r in CLOB_TABLE.get(rel[1], ()): setr(r, 'K' if r != 'r9' else 'X')
                    elif RECORDED is not None:
                        for r in RECORDED.get(rel[1], ()): setr(r, 'K' if r != 'r9' else 'X')
                else:
                    r9own = getr('r9') in ('X', 'E', 'KX', 'GK', 'RTCCK')
                    for r in REGS: setr(r, 'K' if r != 'r9' else ('KX' if r9own else 'X'))
                push_state(nxt); continue
            if local is not None:
                if mn != 'jmp': push_state(nxt)
                push_state(local); continue
            if mn == 'jmp' and rel is not None and rel[1] in rtx and gotrel(rel):
                bad = []
                if stack != ['RA']: bad.append('tail jump with %d slot(s) above the return address' % (len(stack) - 1))
                if clob is not None:
                    for r in ('r8', 'r10', 'r11'):
                        if getr(r) != 'E': clob.add(r)
                    if getr('r9') not in ('E', 'G', 'GK'): clob.add('r9')
                    for r in CLOB_TABLE.get(rel[1], ()): clob.add(r)
                    if bad: errs.append('%s: %s' % (where, '; '.join(bad)))
                    continue
                for r in ('r8', 'r10', 'r11'):
                    if getr(r) != 'E' and r not in own: bad.append('%s not intact at the tail jump' % r)
                for r in sorted(set((RECORDED or {}).get(rel[1], ())) - own):
                    bad.append('%s written by the tail callee %s and not recorded for this entry' % (r, rel[1]))
                if bad: errs.append('%s: %s' % (where, '; '.join(bad)))
                continue
            what = rel[1] if rel is not None else tgt
            how = 'through a PLT slot into another RTX entry' if (rel is not None and rel[1] in rtx) else 'into C'
            if clob is not None and mn == 'jmp':
                for r in REGS: clob.add(r)
                continue
            errs.append('%s: tail exit %s (%s) -- it returns to our caller with the four unrestored' % (where, how, what))
            if mn != 'jmp': push_state(nxt)
            continue
        if mn == 'syscall':
            setr('r11', 'X'); push_state(nxt); continue
        if o:
            d = regof(o[0])
            if d and mn not in READ_ONLY:
                if mn in ('mov', 'movq') and len(o) > 1 and rsp_disp(o[1]) is not None:
                    k = rsp_disp(o[1]) // 8
                    ok = k < len(stack) and 'PAD' not in stack[len(stack) - 1 - k:]
                    setr(d, regval(d, stack[-1 - k]) if ok else 'X')
                elif d == 'r9' and mn == 'mov' and c['rel'] is not None and c['rel'][1] == 'rtccb':
                    setr('r9', 'RTCCK' if getr('r9') in ('KX', 'GK', 'RTCCK') else 'RTCC')
                elif d == 'r9' and mn == 'mov' and getr('r9') in ('RTCC', 'RTCCK') and re.fullmatch(r'QWORD PTR \[r9\+0x30\]', o[1].strip() if len(o) > 1 else ''):
                    setr('r9', 'GK' if getr('r9') == 'RTCCK' else 'G')
                else:
                    setr(d, 'X')
                if d == 'r9': r9w = True
            if mn == 'xchg' and len(o) > 1 and regof(o[1]):
                setr(regof(o[1]), 'X')
            if mn in ('mov', 'movq') and rsp_disp(o[0]) is not None and len(o) > 1:
                k = rsp_disp(o[0]) // 8
                if k < len(stack) and 'PAD' not in stack[len(stack) - 1 - k:]:
                    r = regof(o[1])
                    stack[-1 - k] = slotval(r, getr(r)) if r else 'X'
        push_state(nxt)
    if r9_input:
        for where, v in rets:
            if v == 'E':
                if clob is not None: clob.add('r9')
                elif 'r9' in own: pass
                else: errs.append('%s: r9 came in as an argument (%s) and goes back unrestored' % (where, r9_input[0]))
    return errs


def load_recorded(path):
    bit = {'RTCC_C_R8': 'r8', 'RTCC_C_R9': 'r9', 'RTCC_C_R10': 'r10', 'RTCC_C_R11': 'r11'}
    t = {}
    for m in re.finditer(r'\{\s*"([^"]+)",\s*([A-Z0-9_|]+)\s*\}', open(path, encoding='utf-8').read()):
        t[m.group(1)] = tuple(sorted(bit[b] for b in m.group(2).split('|') if b in bit))
    return t


def main(argv):
    global RECORDED
    objs, entries_file, clobber = [], None, False
    i = 0
    while i < len(argv):
        if argv[i] == '--entries':
            entries_file = argv[i + 1]; i += 2; continue
        if argv[i] == '--clobber-table':
            clobber = True; i += 1; continue
        if argv[i] == '--table':
            RECORDED = load_recorded(argv[i + 1]); i += 2; continue
        objs.append(argv[i]); i += 1
    if not objs:
        print('REFUSED: no objects named'); return 2
    code, funcs = load(objs)
    if not code:
        print('REFUSED: objdump produced no instructions'); return 2
    defined = set()
    for obj in objs:
        for line in run(['nm', '--defined-only', '-g', obj]).split('\n'):
            p = line.split()
            if len(p) == 3 and p[1] == 'T': defined.add(p[2])
    entries = [l.strip() for l in open(entries_file, encoding='utf-8') if l.strip()] if entries_file else sorted(defined)
    rtx = set(entries) | defined
    all_errs, proven = [], 0
    if clobber:
        for _round in range(8):
            changed = False
            for e in entries:
                c = set(CLOB_TABLE.get(e, ()))
                errs = walk(e, code, funcs, rtx, c)
                if errs: all_errs.extend(errs)
                if c != set(CLOB_TABLE.get(e, ())): CLOB_TABLE[e] = tuple(sorted(c)); changed = True
            if not changed: break
            all_errs = []
        for e in entries:
            print('RTX-CLOBBER %s %s' % (e, ','.join(CLOB_TABLE.get(e, ())) or '-'))
        for x in sorted(set(all_errs)): print('  UNANALYZABLE  ' + x)
        print('RTX-CLOBBER-TABLE entries=%d clobbering=%d unanalyzable=%d' % (len(entries), sum(1 for e in entries if CLOB_TABLE.get(e)), len(set(all_errs))))
        return 2 if all_errs else 0
    for e in entries:
        errs = walk(e, code, funcs, rtx)
        if errs: all_errs.extend(errs)
        else: proven += 1
    if entries_file:
        for u in sorted(defined - set(entries)):
            all_errs.append('%s: a global function in an RTX object that the entry registry does not name' % u)
        for u in sorted(set(entries) - defined):
            all_errs.append('%s: named by the entry registry but defined by no RTX object' % u)
    for e in all_errs: print('  VIOLATION  ' + e)
    print('RTX ENTRIES WALKED: %d   PROVEN: %d   VIOLATIONS: %d   (objects: %d, instructions: %d)'
          % (len(entries), proven, len(all_errs), len(objs), len(code)))
    return 1 if all_errs else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
