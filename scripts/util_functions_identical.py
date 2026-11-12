#!/usr/bin/env python3
# util_functions_identical.py -- THE FUNCTION-IDENTITY PROOF OF DESIGN-PLAN cache-tree, step 1 (the cto, 2026-11-12, CTO-636; skill scrip-build reference section 4, law C8).
# A split moves functions between objects, so no object stays byte-identical; what must not change is the code of every function and the data of every
# variable, over the UNION of the objects on each side.
#   util_functions_identical.py --parent OBJ... --child OBJ... [--show N]      (the two lists are separated by the flags; a glob is expanded)
# Each object is read by lib_elf_noncomdat.canon (the disassembly without addresses, every relocation by the symbol or the pool entry it reaches), then the
# forms a split changes and the program cannot see are made equal:
#   - a static that became a hidden extern: its local or global binding, the numbered suffix of a function-local static (x.1, x.2), the call that was
#     resolved inside the unit and is now a relocation to the same name, the leading endbr64 a global function gains under -fcf-protection (and the 4-byte
#     shift of its own branch targets and relocation offsets), a reference to an exported constant string by its symbol where the unit reached its bytes;
#   - FILELINE: an instruction whose immediate is a __LINE__ and a relocation whose string is __FILE__, where the parent's string names the unit and the
#     child's names the piece that now holds the function (the gc callback ledger records the piece, which is where the code is).
# A symbol on one side only, a writable variable (.data, .bss) that the child defines more than once (a static the head would duplicate), or any other
# difference is RED. Prints FUNC_IDENTITY_BOARD symbols=N identical=N fileline=N header_copies=N differing=N, then one DIFF line per differing symbol.
# rc 0 identical (FILELINE allowed), rc 1 a difference, rc 2 could not read an object.
import argparse, collections, glob, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_elf_noncomdat as L
_reloc_desc = L.reloc_desc


def _reloc_desc_named(e, roff, rinfo, add, adj=None):
    """lib_elf_noncomdat names a reference into .data.rel.ro by its section alone; a split moves a static table of pointers into a unit of its own, where it is
    reached by its symbol, so the reference is named here by the symbol the section offset falls in, as a reference into any other section is."""
    d = _reloc_desc(e, roff, rinfo, add, adj)
    if d[1] == 'A':
        sym = rinfo >> 32
        sy = e.syms[sym] if sym < len(e.syms) else None
        if sy is not None and 0 < sy['shndx'] < len(e.sec):
            hit = e.symbol_at(sy['shndx'], add + (adj(roff) if adj and (rinfo & 0xffffffff) in L.PCREL else 0))
            if hit:
                return (d[0], 'V', d[2], (hit[0], add + (adj(roff) if adj and (rinfo & 0xffffffff) in L.PCREL else 0) - hit[1]))
    return d


L.reloc_desc = _reloc_desc_named
PC={2,4}
def norm(name):
    """A symbol's comparable name: no numbered suffix of a function-local static (x.1), no parameter list (a C++ function a split exported is
    demangled with its signature where the unit's local copy was keyed by its bare name), one name for every unit's static-initializer function."""
    name = re.sub(r'\.\d+$', '', name)
    if name.startswith('_GLOBAL__sub_I_'):
        return '_GLOBAL__sub_I_'
    prev = None
    while prev != name:
        prev, name = name, re.sub(r'\((?:[^()]|\([^()]*\))*\)( const)?(?=$|::|\[)', '', name)
    return name
_DEM = {}


def dem(name):
    if not name.startswith('_Z'):
        return name
    if name not in _DEM:
        _DEM[name] = subprocess.run(['c++filt', name], capture_output=True, text=True).stdout.strip() or name
    return _DEM[name]


def nrel(r):
    roff,typ,cls,a,b=r
    if cls=='V' and isinstance(b,tuple): return (roff,'sym',norm(b[0]),b[1])
    if cls=='N' and typ in PC: return (roff,'sym',norm(dem(a)),b+4,'pc')
    if cls=='N': return (roff,'sym',norm(dem(a)),b)
    return (roff,cls,a,b)


def reconcile(ra, rb):
    """A pc-relative relocation against a named symbol (the child's, an exported static) and the parent's resolved reference to the same symbol at
    the same offset are one reference when they differ by the bytes of an immediate that follows the displacement (0, 1, 2 or 4): the assembler
    knew the instruction's length for the parent, lib_elf_noncomdat assumes 4 for a named relocation."""
    ra, rb = set(ra), set(rb)
    for x in [r for r in ra - rb if len(r) == 5]:
        for y in [r for r in rb - ra if len(r) == 4 and r[0] == x[0] and r[2] == x[2] and isinstance(r[3], int) and r[3] - x[3] in (0, 1, 2, 4)]:
            ra.discard(x); rb.discard(y); break
    for x in [r for r in rb - ra if len(r) == 5]:
        for y in [r for r in ra - rb if len(r) == 4 and r[0] == x[0] and r[2] == x[2] and isinstance(r[3], int) and r[3] - x[3] in (0, 1, 2, 4)]:
            rb.discard(x); ra.discard(y); break
    return ra == rb
def ninsn(t):
    t=re.sub(r'<([^>]*?)(\+0x[0-9a-f]+)?>', lambda m: '<%s%s>' % (norm(m.group(1)), m.group(2) or ''), t)
    t=re.sub(r'^(call|jmp)q?\s+<([^>+]+)>$',r'\1 \2',t)
    t=re.sub(r'^(call|jmp)q?\s+(.+)$',lambda m: '%s %s' % (m.group(1), norm(m.group(2))),t)
    t=re.sub(r' @\S+$','',t)
    return re.sub(r'\.\d+\b','',t)
def nval(v, name):
    (kind,body),rl=v
    shift=0
    if kind=='insns':
        body=[ninsn(x) for x in body]
        if body and body[0]=='endbr64':
            body=body[1:]; shift=4
            def fix(m):
                return '<%s+0x%x>' % (m.group(1), int(m.group(2),16)-4)
            body=[re.sub(r'<(%s)\+0x([0-9a-f]+)>' % re.escape(norm(name)), fix, x) for x in body]
        called={m.group(2) for x in body for m in [re.match(r'^(call|jmp) (.+)$',x)] if m}
        body=tuple(body)
    else:
        called=set()
    out=[]
    for r in rl:
        n=nrel(r)
        if n[1]=='sym' and r[1] in PC and n[2] in called: continue
        out.append((n[0]-shift,)+n[1:])
    return (kind,body,tuple(sorted(out)))
def load(files):
    raw=[]
    strs={}
    for f in files:
        for k,v in L.canon(f,set()).items():
            raw.append((k,v))
            (kind,body),rl=v
            if k[0].startswith('.rodata') and kind=='bytes' and not rl:
                strs[norm(k[1])]=body.split(b'\0',1)[0]
    M=collections.defaultdict(list)
    for k,v in raw:
        kind,body,rl=nval(v,k[1])
        rl=tuple(sorted((r[0],'R','.rodata',strs[r[2]]) if r[1]=='sym' and r[3]==0 and r[2] in strs else r for r in rl))
        rl=tuple(sorted((r[0],'R',r[2],r[3][:8]) if r[1]=='R' and isinstance(r[3],bytes) and re.search(rb'[\x00-\x08\x0e-\x1f\x7f-\xff]',r[3]) else r for r in rl))
        M[(k[0],norm(k[1]))].append((kind,body,rl))
    return M


def rip_lea_targets(obj, fn):
    """The target of every rip-relative lea of function fn in obj, in order, by name: the relocation's symbol where the assembler left one, else the
    symbol objdump names for the displacement it resolved (a function of the same object reached without a relocation)."""
    out = subprocess.run(['objdump', '-dr', '--no-show-raw-insn', '--disassemble=' + fn, obj], capture_output=True, text=True).stdout.split('\n')
    t = []
    for i, ln in enumerate(out):
        m = re.search(r'\slea\s+(-?0x[0-9a-f]+)\(%rip\),%\w+(?:\s+# [0-9a-f]+ <([^>]+)>)?', ln)
        if not m:
            continue
        nxt = out[i + 1] if i + 1 < len(out) else ''
        r = re.search(r'R_X86_64_\w+\s+([A-Za-z_][\w.]*)([+-]0x[0-9a-f]+)?', nxt)
        if r:
            t.append(('R', re.sub(r'\.\d+$', '', r.group(1))))
        else:
            t.append(('S', re.sub(r'\.\d+(\+|$)', r'\1', m.group(2) or '?')))
    return t


def local_addr_only(a, b, fnames, pobj=None, cobj=None, fn=None):
    if a[0] != b[0] or not isinstance(a[1], tuple) or len(a[1]) != len(b[1]):
        return 0
    n = 0
    for p, q in zip(a[1], b[1]):
        if p != q:
            if re.sub(r'lea -?0x[0-9a-f]+\(%rip\)', 'lea D(%rip)', p) != re.sub(r'lea -?0x[0-9a-f]+\(%rip\)', 'lea D(%rip)', q):
                return 0
            n += 1
    if not (pobj and cobj and fn):
        return 0
    tp, tc = rip_lea_targets(pobj, fn), rip_lea_targets(cobj, fn)
    if len(tp) != len(tc) or [x[1].split('+')[0] for x in tp] != [y[1].split('+')[0] for y in tc]:
        return 0
    ra, rb = set(a[2]), set(b[2])
    if any(not (r[1] == 'sym' and r[2] in fnames) for r in (ra - rb) | (rb - ra)):
        return 0
    return n


def fileline_only(a, b, srcs):
    if a[0] != b[0] or not isinstance(a[1], tuple) or len(a[1]) != len(b[1]):
        return False
    for p, q in zip(a[1], b[1]):
        if p != q and not (re.sub(r'\$0x[0-9a-f]+', '$I', p) == re.sub(r'\$0x[0-9a-f]+', '$I', q) and p.startswith('mov')):
            return False
    isfile = lambda r: r[1] == 'R' and isinstance(r[3], bytes) and r[3].decode('latin1').endswith(srcs)
    ra, rb = set(a[2]), set(b[2])
    fa, fb = {r for r in ra - rb if isfile(r)}, {r for r in rb - ra if isfile(r)}
    if len(fa) != len(fb):
        return False
    return reconcile(ra - fa, rb - fb)


def expand(xs):
    out = []
    for x in xs:
        out.extend(sorted(glob.glob(x)) or [x])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--parent', nargs='+', default=[])
    ap.add_argument('--child', nargs='+', default=[])
    ap.add_argument('--show', type=int, default=20)
    ap.add_argument('--selftest', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    pa, ch = expand(a.parent), expand(a.child)
    if not pa or not ch or not all(os.path.isfile(x) for x in pa + ch):
        print('REFUSE(2): --parent and --child must name object files'); return 2
    try:
        P, C = load(pa), load(ch)
    except Exception as e:
        print('REFUSE(2): %s' % e); return 2
    srcs = ('.c', '.cpp', '.cc')
    same = fl = la = 0
    bad = []
    fnames = {k[1] for k in C if k[0].startswith('.text')}
    def where(objs):
        w = {}
        for o in objs:
            for ln in subprocess.run(['nm', '--defined-only', o], capture_output=True, text=True).stdout.split('\n'):
                q = ln.split()
                if len(q) == 3 and q[1] in 'Tt':
                    w.setdefault(q[2], o)
        return w
    where_p, where_c = where(pa), where(ch)
    copies = 0
    for k in sorted(set(P) | set(C)):
        if k not in C or k not in P:
            bad.append((k, 'only in the %s' % ('parent' if k in P else 'child'))); continue
        if len(C[k]) > len(P[k]):
            if k[0].startswith(('.data', '.bss')) and not k[0].startswith('.data.rel.ro'):
                bad.append((k, 'a writable variable the child defines %d times' % len(C[k]))); continue
            copies += 1
        sp, sc = set(map(repr, P[k])), set(map(repr, C[k]))
        if sp == sc:
            same += 1; continue
        if len(P[k]) == 1 and len(C[k]) == 1 and P[k][0][:2] == C[k][0][:2] and reconcile(P[k][0][2], C[k][0][2]):
            same += 1; continue
        if len(P[k]) == 1 and len(C[k]) == 1 and fileline_only(P[k][0], C[k][0], srcs):
            fl += 1; continue
        if len(P[k]) == 1 and len(C[k]) == 1:
            ap = (P[k][0][0], P[k][0][1], tuple(r for r in P[k][0][2] if not (r[1] == 'R' and isinstance(r[3], bytes) and r[3].decode('latin1').endswith(srcs))))
            bp = (C[k][0][0], C[k][0][1], tuple(r for r in C[k][0][2] if not (r[1] == 'R' and isinstance(r[3], bytes) and r[3].decode('latin1').endswith(srcs))))
            ap = (ap[0], tuple(re.sub(r'\$0x[0-9a-f]+', '$I', x) if x.startswith('mov') else x for x in ap[1]) if isinstance(ap[1], tuple) else ap[1], ap[2])
            bp = (bp[0], tuple(re.sub(r'\$0x[0-9a-f]+', '$I', x) if x.startswith('mov') else x for x in bp[1]) if isinstance(bp[1], tuple) else bp[1], bp[2])
            n = local_addr_only(ap, bp, fnames, where_p.get(k[1]), where_c.get(k[1]), k[1])
            if n:
                la += n; fl += 1; continue
        bad.append((k, 'code or data differs'))
    print('FUNC_IDENTITY_BOARD symbols=%d identical=%d fileline=%d local_addr=%d header_copies=%d differing=%d' % (len(P), same, fl, la, copies, len(bad)))
    for k, why in bad[:a.show]:
        print('DIFF %s %s: %s' % (k[0], k[1], why))
    return 1 if bad else 0


def selftest():
    import subprocess, tempfile, shutil
    w = tempfile.mkdtemp(prefix='fi_selftest.')
    try:
        def cc(name, text):
            p = os.path.join(w, name + '.c'); open(p, 'w').write(text)
            o = os.path.join(w, name + '.o')
            subprocess.run(['gcc', '-O0', '-fPIC', '-fcf-protection', '-c', p, '-o', o], check=True)
            return o
        par = cc('par', 'static int tag = 84;\nstatic int f(int x) { return x + 1; }\nint h(int);\nint g(int x) { return h(f(x)) * 2 + tag; }\n')
        c1 = cc('c1', '__attribute__((visibility("hidden"))) int tag = 84;\n__attribute__((visibility("hidden"))) int f(int x) { return x + 1; }\n')
        c2 = cc('c2', '__attribute__((visibility("hidden"))) int f(int);\nextern __attribute__((visibility("hidden"))) int tag;\nint h(int);\nint g(int x) { return h(f(x)) * 2 + tag; }\n')
        c3 = cc('c3', '__attribute__((visibility("hidden"))) int f(int);\nextern __attribute__((visibility("hidden"))) int tag;\nint h(int);\nint g(int x) { return h(f(x)) * 3 + tag; }\n')
        P = load([par])
        ok = sys.modules[__name__]
        def verdict(child):
            C = load(child)
            return all(k in C and (set(map(repr, P[k])) == set(map(repr, C[k])) or (len(P[k]) == 1 and len(C[k]) == 1 and P[k][0][:2] == C[k][0][:2]
                       and reconcile(P[k][0][2], C[k][0][2]))) for k in P) and set(P) == set(C)
        r1, r2 = verdict([c1, c2]), verdict([c1, c3])
        if not r1:
            C = load([c1, c2])
            for k in set(P) | set(C):
                if set(map(repr, P.get(k, []))) != set(map(repr, C.get(k, []))):
                    print('SELFTEST diff', k, P.get(k), C.get(k))
        print('SELFTEST split identical: %s; a changed body detected: %s' % (r1, not r2))
        if r1 and not r2:
            print('SELFTEST OK'); return 0
        print('SELFTEST FAIL'); return 1
    finally:
        shutil.rmtree(w, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
