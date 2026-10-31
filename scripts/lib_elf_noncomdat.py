#!/usr/bin/env python3
# lib_elf_noncomdat.py [--moved FILE] <objdirA> <objdirB> [outA outB] -- THE --no-comdat ARM OF util_objects_identical_stripped.sh (R5-PRIME (b), ARCH-HEADER-SPLIT.md section 1, the cto's ruling
# CEO-2078; hq_templates). A step that carries out R3 by moving inline bodies into a compiled file cannot keep every object byte-identical: the copies of the moved bodies vanish from every
# includer's object, the weak ones in COMDAT groups and the "static inline" ones in plain .text (with their function-local statics in .data/.bss). What must not move is everything else.
# For every object present in both trees this compares, without debug info, the CODE AND DATA OF EVERY DEFINED SYMBOL that is not a member of a COMDAT group and not one of the moved functions
# (or a static local of one): the bytes of its slice of the section and the relocations inside it. Left out:
#   - a COMDAT group member (SHF_GROUP), the group sections, .eh_frame and its relocations (they unwind the vanished copies), the symbol tables and every .debug_*;
#   - a symbol named in --moved FILE (one name per line): a function, with its static locals and guard variables, or a plain variable named exactly (a header's unused static data
#     leaves a unit that no longer includes the header);
#   - a SHF_MERGE section (the string and constant pools): never compared by its bytes; a relocation into one is compared by the ENTRY it reaches (the NUL-terminated string, or the
#     entsize constant), not by its offset, so a literal that moved is no difference and a literal that changed is;
#   - a relocation into plain .rodata (the string literals are there, unpooled) is compared by the bytes it reaches (up to the NUL: an empty literal is empty), never by its offset; into
#     .data.rel.ro the section name is compared and the offset is not.
# A relocation against a named symbol is compared by symbol name and addend. A defined symbol in one object only is a difference unless it is a moved one ("vanished") or the
# object itself is new. Prints "DIFF key symbol detail", "NEW-B key" (an object only the second tree has: not a failure), "ONLY-A key" (an object that vanished: a failure), then
# "objects=N identical=N differing=M". rc 0 all kept symbols identical, rc 1 any difference or vanished object, rc 2 the instrument could not measure.
import os, re, struct, subprocess, sys

SHF_GROUP, SHF_MERGE, SHF_STRINGS = 0x200, 0x10, 0x20
SHT_NOBITS, SHT_RELA, SHT_SYMTAB, SHT_GROUP = 8, 4, 2, 17
PCREL = {2, 4}
SKIP_NAMES = ('.eh_frame', '.rela.eh_frame', '.symtab', '.strtab', '.shstrtab')
FUNC_RX = re.compile(r'^(?:.*\s)?([A-Za-z_][A-Za-z_0-9]*)(?:\[abi:[a-z0-9]+\])?\(')


class Elf:
    def __init__(self, path):
        d = open(path, 'rb').read()
        if d[:4] != b'\x7fELF' or d[4] != 2 or d[5] != 1:
            raise ValueError('not a little-endian ELF64: ' + path)
        self.d = d
        shoff, = struct.unpack_from('<Q', d, 0x28)
        shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3A)
        self.sec = []
        for i in range(shnum):
            o = shoff + i * shentsize
            name, typ, flags, addr, off, size, link, info, align, entsize = struct.unpack_from('<IIQQQQIIQQ', d, o)
            self.sec.append(dict(i=i, nameoff=name, type=typ, flags=flags, off=off, size=size, link=link, info=info, align=align, entsize=entsize))
        so = self.sec[shstrndx]['off']
        for s in self.sec:
            e = d.index(b'\0', so + s['nameoff'])
            s['name'] = d[so + s['nameoff']:e].decode('latin1')
        self.syms = []
        for s in self.sec:
            if s['type'] == SHT_SYMTAB:
                strtab = self.sec[s['link']]['off']
                for k in range(s['size'] // 24):
                    o = s['off'] + k * 24
                    nm, info, other, shndx, val, sz = struct.unpack_from('<IBBHQQ', d, o)
                    e = d.index(b'\0', strtab + nm)
                    self.syms.append(dict(name=d[strtab + nm:e].decode('utf-8', 'surrogateescape'), info=info, shndx=shndx, value=val, size=sz))
        self.demangle()

    def demangle(self):
        names = [y['name'] for y in self.syms]
        if not names:
            return
        r = subprocess.run(['c++filt'], input='\n'.join(names) + '\n', capture_output=True, text=True, encoding='utf-8', errors='surrogateescape')
        out = r.stdout.split('\n')
        if r.returncode != 0 or len(out) < len(names):
            raise ValueError('c++filt failed')
        for y, dn in zip(self.syms, out):
            y['dem'] = dn

    def rodata_entry(self, s, off):
        b = self.data(s)
        e = b.find(b'\0', off, off + 512)
        return b[off:e] if e >= off else b[off:off + 512]

    def symbol_at(self, shndx, off):
        if not hasattr(self, '_bysec'):
            self._bysec = {}
            for y in self.syms:
                if (y['info'] & 0xf) in (0, 1, 2) and y['name'] and 0 < y['shndx'] < len(self.sec):
                    self._bysec.setdefault(y['shndx'], []).append((y['value'], y['size'], y['dem']))
        for v, z, d in self._bysec.get(shndx, ()):
            if v <= off < v + max(z, 1):
                return (d, v)
        return None

    def data(self, s):
        return b'' if s['type'] == SHT_NOBITS else self.d[s['off']:s['off'] + s['size']]

    def kept(self, s):
        if s['type'] in (0, SHT_GROUP, SHT_SYMTAB, 3) or s['flags'] & SHF_GROUP:
            return False
        n = s['name']
        return not (n in SKIP_NAMES or n.startswith('.debug_') or n.startswith('.rela.debug_'))

    def merge_entry(self, s, off):
        b = self.data(s)
        if s['flags'] & SHF_STRINGS:
            e = b.find(b'\0', off)
            return b[off:e if e >= 0 else len(b)]
        w = s['entsize'] or 1
        return b[off:off + w]


RELOC_RX = re.compile(r'^\s+[0-9a-f]+: (R_X86_64_\w+)\t(.*)$')
INSN_RX = re.compile(r'^\s*[0-9a-f]+:\t(.*)$')
BR_RX = re.compile(r'^((?:j[a-z]+|call|jmp)q?\s+)[0-9a-f]+ (<.*>)$')
CMT_RX = re.compile(r'\s+# [0-9a-f]+ <.*>$')


def disasm(path, grouped):
    """{(section, function): [normalised instruction text]} for the code sections that are not COMDAT group members: addresses dropped, a branch or call target kept as its <symbol+offset>."""
    r = subprocess.run(['objdump', '-d', '-r', '--no-show-raw-insn', '-C', path], capture_output=True, text=True)
    if r.returncode != 0:
        raise ValueError('objdump failed on ' + path)
    funcs, sec, cur, seen, starts = {}, None, None, {}, {}
    for line in r.stdout.split('\n'):
        m = re.match(r'^Disassembly of section (\S+):', line)
        if m:
            sec, cur = m.group(1), None
            continue
        m = re.match(r'^[0-9a-f]+ <(.*)>:$', line)
        if m and sec is not None:
            if sec in grouped:
                cur = None
                continue
            k = (sec, m.group(1))
            seen[k] = seen.get(k, 0) + 1
            cur = funcs.setdefault((sec, m.group(1), seen[k]), [])
            continue
        if cur is None:
            continue
        mr = RELOC_RX.match(line)
        if mr and cur:
            tgt = re.sub(r'[+-]0x[0-9a-f]+$', '', mr.group(2).strip())
            if not tgt.startswith('.') and not tgt.startswith('*'):
                last = cur[-1]
                bm = re.match(r'^((?:j[a-z]+|call|jmp)q?) ', last)
                cur[-1] = (bm.group(1) + ' ' + tgt) if bm else (last + ' @' + tgt)
            continue
        m = INSN_RX.match(line)
        if not m:
            continue
        if sec is not None:
            starts.setdefault(sec, []).append(int(line.split(':', 1)[0], 16))
        t = CMT_RX.sub('', m.group(1).rstrip())
        t = re.sub(r'\s+', ' ', t)
        b = BR_RX.match(t)
        if b:
            t = b.group(1) + b.group(2)
        cur.append(t)
    return funcs, starts


IMM_RX = re.compile(r'\$0x([0-9a-f]+)')


LINE_CALLEES = re.compile(r'^call <?(x86_rt_gc_poll_at|drive_guard_refused)\b')


def insn_delta(x, y):
    """The set of line-number shifts when the instruction lists x and y differ only in immediates that feed a __LINE__ call (the gc poll site, the emitter's guard refusal): an immediate
    that differs must be followed within ten instructions by a call to one of those, and must have moved by less than 200 (an include block grew or shrank). Else None."""
    if len(x) != len(y):
        return None
    ds = set()
    for i, (a, b) in enumerate(zip(x, y)):
        if a == b:
            continue
        ia, ib = IMM_RX.findall(a), IMM_RX.findall(b)
        if len(ia) != len(ib) or IMM_RX.sub('$#', a) != IMM_RX.sub('$#', b):
            return None
        dif = [int(q, 16) - int(p, 16) for p, q in zip(ia, ib) if p != q]
        if len(dif) != 1 or not 0 < abs(dif[0]) < 200:
            return None
        if not any(LINE_CALLEES.match(t) for t in x[i + 1:i + 11]):
            return None
        ds.add(dif[0])
    return ds or None


def is_moved(dem, moved):
    m = FUNC_RX.match(dem)
    return bool(m and m.group(1) in moved) or dem in moved


def reloc_desc(e, roff, rinfo, add, adj=None):
    sym, typ = rinfo >> 32, rinfo & 0xffffffff
    pc = (adj(roff) if adj and typ in PCREL else 0)
    sy = e.syms[sym] if sym < len(e.syms) else dict(name='', info=0, shndx=0, dem='')
    if (sy['info'] & 0xf) == 3 and 0 < sy['shndx'] < len(e.sec):
        ts = e.sec[sy['shndx']]
        if ts['flags'] & SHF_MERGE:
            return (typ, 'M', ts['name'], e.merge_entry(ts, add + pc))
        if ts['flags'] & SHF_GROUP:
            return (typ, 'G', ts['name'], add)
        if ts['name'].startswith('.rodata'):
            return (typ, 'R', ts['name'], e.rodata_entry(ts, add + pc))
        if ts['name'].startswith('.data.rel.ro'):
            return (typ, 'A', ts['name'], 0)
        off = add + pc
        hit = e.symbol_at(sy['shndx'], off)
        if hit:
            return (typ, 'V', ts['name'], (hit[0], off - hit[1]))
        return (typ, 'S', ts['name'], add)
    return (typ, 'N', sy['name'], add)


def canon(path, moved):
    e = Elf(path)
    out = {}
    relocs = {}
    for s in e.sec:
        if s['type'] == SHT_RELA and e.kept(e.sec[s['info']]):
            b = e.data(s)
            relocs.setdefault(s['info'], []).extend(struct.unpack_from('<QQq', b, k * 24) for k in range(len(b) // 24))
    bysec = {}
    for y in e.syms:
        t = y['info'] & 0xf
        if t in (1, 2) and 0 < y['shndx'] < len(e.sec) and e.kept(e.sec[y['shndx']]) and not (e.sec[y['shndx']]['flags'] & SHF_MERGE):
            bysec.setdefault(y['shndx'], []).append(y)
    grouped = {x['name'] for x in e.sec if x['flags'] & SHF_GROUP}
    code, starts = disasm(path, grouped)
    import bisect

    def adj_for(secname):
        st = starts.get(secname)
        if not st:
            return lambda roff: 4
        return lambda roff: (st[bisect.bisect_right(st, roff)] if bisect.bisect_right(st, roff) < len(st) else roff + 4) - roff
    rl_of = {}
    for si, ys in bysec.items():
        s = e.sec[si]
        body = e.data(s)
        for y in ys:
            dem = y['dem']
            if is_moved(dem, moved):
                continue
            lo, hi = y['value'], y['value'] + y['size']
            if s['flags'] & 4:
                rl_of[(s['name'], dem)] = tuple(sorted((r[0] - lo,) + reloc_desc(e, *r, adj_for(s['name'])) for r in relocs.get(si, ()) if lo <= r[0] < hi)) if y['size'] else ()
                continue
            if s['type'] == SHT_NOBITS:
                content = ('bss', y['size'])
            else:
                content = ('bytes', body[lo:hi])
            rl = tuple(sorted((r[0] - lo,) + reloc_desc(e, *r, adj_for(s['name'])) for r in relocs.get(si, ()) if lo <= r[0] < hi)) if y['size'] else ()
            key = (s['name'], dem, y['info'] >> 4 == 0)
            out[key] = (content, rl)
    for (sec, nm, k), insns in code.items():
        if is_moved(nm, moved):
            continue
        out[(sec, nm, k)] = (('insns', tuple(insns)), rl_of.get((sec, nm), ()))
    return out


def collect(dirpath, pre, into):
    for dp, dn, fs in os.walk(dirpath):
        for f in fs:
            if f.endswith('.o'):
                rel = os.path.relpath(os.path.join(dp, f), dirpath)
                into[pre + ':' + re.sub(r'-[0-9a-f]{10}(/|\.|$)', r'\1', rel)] = os.path.join(dp, f)


def line_delta(x, y):
    """The constant D when every difference between the byte strings x and y lies in 32-bit little-endian words that differ by exactly D (a __LINE__ immediate that moved); else None."""
    if len(x) != len(y):
        return None
    i, d = 0, None
    n = len(x)
    while i < n:
        if x[i] == y[i]:
            i += 1
            continue
        for st in range(max(0, i - 3), i + 1):
            if st + 4 <= n:
                dv = (struct.unpack_from('<I', y, st)[0] - struct.unpack_from('<I', x, st)[0]) & 0xffffffff
                if dv and (x[st:i] == y[st:i]) and (d is None or dv == d) and dv < 4096:
                    d = dv
                    i = st + 4
                    break
        else:
            return None
    return d


def describe(a, b):
    ca, ra = a
    cb, rb = b
    if ca != cb and ca[0] == 'insns' and cb[0] == 'insns':
        x, y = ca[1], cb[1]
        i = next((j for j in range(min(len(x), len(y))) if x[j] != y[j]), min(len(x), len(y)))
        return 'code differs (%d vs %d instructions), first at instruction %d: %s | %s' % (len(x), len(y), i, x[i] if i < len(x) else '-', y[i] if i < len(y) else '-')
    if ca != cb:
        if ca[0] == 'bytes' and cb[0] == 'bytes':
            at = next((j for j in range(min(len(ca[1]), len(cb[1]))) if ca[1][j] != cb[1][j]), min(len(ca[1]), len(cb[1])))
            return 'bytes differ (%d vs %d bytes) first at offset %d' % (len(ca[1]), len(cb[1]), at)
        return 'content differs: %s | %s' % (ca[:2], cb[:2])
    i = next((j for j in range(min(len(ra), len(rb))) if ra[j] != rb[j]), min(len(ra), len(rb)))
    return 'relocations differ (%d vs %d), first: %s | %s' % (len(ra), len(rb), ra[i] if i < len(ra) else '-', rb[i] if i < len(rb) else '-')


def main(argv):
    moved = set()
    if len(argv) > 2 and argv[1] == '--moved':
        moved = {l.strip() for l in open(argv[2]) if l.strip()}
        argv = argv[:1] + argv[3:]
    if len(argv) not in (3, 5):
        print('usage: lib_elf_noncomdat.py [--moved FILE] <objdirA> <objdirB> [outA outB]', file=sys.stderr)
        return 2
    A, B = {}, {}
    collect(argv[1], 'obj', A)
    collect(argv[2], 'obj', B)
    if len(argv) == 5:
        collect(argv[3], 'out', A)
        collect(argv[4], 'out', B)
    n = same = diff = gone = lineonly = 0
    lines = []
    for key in sorted(set(A) | set(B)):
        if key not in A:
            lines.append('NEW-B ' + key)
            continue
        if key not in B:
            lines.append('ONLY-A ' + key)
            gone += 1
            continue
        n += 1
        try:
            ca, cb = canon(A[key], moved), canon(B[key], moved)
        except Exception as ex:
            print('REFUSE(2): cannot read %s: %s' % (key, ex), file=sys.stderr)
            return 2
        bad = []
        deltas = set()
        for k in sorted(set(ca) | set(cb), key=str):
            if k not in cb:
                bad.append((k, 'present in the first object only (vanished, not a moved function)'))
            elif k not in ca:
                bad.append((k, 'present in the second object only (appeared)'))
            elif ca[k] != cb[k]:
                (xa, ra), (xb, rb) = ca[k], cb[k]
                if ra == rb and xa[0] == 'insns' and xb[0] == 'insns':
                    dl = insn_delta(xa[1], xb[1])
                    if dl is not None:
                        deltas |= dl
                        continue
                bad.append((k, describe(ca[k], cb[k])))
        if deltas and not bad:
            lineonly += 1
        if bad:
            diff += 1
            for k, why in bad:
                lines.append('DIFF %s %s:%s %s' % (key, k[0], k[1], why))
        else:
            same += 1
    if lines:
        print('\n'.join(lines))
    print('objects=%d identical=%d differing=%d (of the identical, %d differ only in __LINE__ immediates that moved with an include block)' % (n, same, diff, lineonly))
    return 1 if diff or gone else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
