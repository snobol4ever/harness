#!/usr/bin/env python3
"""util_alloc_by_port_census.py -- PERSISTING stack allocations in the emitted .s, by the box and port whose code makes them (Lon 2026-10-21: no
pre-allocation of a spine cell; a cell is allocated at the alpha of the box that needs it; inventory every box that allocates at beta).
A port segment runs from a box label (n<id>_<kind>_<port>, or an inner .L<kind>_<port>_<n>[_<m>]) to the next such label. Along it the
net rsp change d is tracked: push -8, pop +8, sub rsp N -N, add rsp N +N (a negative add allocates), lea rsp [rsp -/+ N]; any other write
of rsp (mov/lea from a register or memory, leave, and) is a restore and ends the tracking for that segment. At every exit -- a jump, a
ret, or the fall into the next label -- an exit with d < 0 is a PERSISTING ALLOCATION of -d bytes made by that port. Transient pairs
(push/pop around a call, the alignment sub/add) net to zero and are not counted. A prologue segment (the function label to its first
box label) is reported apart as PROLOGUE. Function bodies are hashed with digits masked; each distinct body counts once.
Usage: util_alloc_by_port_census.py OUT_TSV file.s..."""
import collections, hashlib, re, sys

LAB = re.compile(r'^([^\s#][^\s:]*):\s*(.*)$')
BOX = re.compile(r'^n\d+_([a-z0-9_]+?)_(α|β|γ|ω|bx)$')
INNER = re.compile(r'^\.L([a-z0-9_]+?)_(α|β|γ|ω)_\d+(?:_\d+)?$')
PORT = {'α': 'alpha', 'β': 'beta', 'γ': 'gamma', 'ω': 'omega', 'bx': 'box'}
RSPW = re.compile(r'^(?:mov|lea|xchg|and|or|cmov\w+)\s+rsp\s*,|^leave\b|^pop\s+rsp\b')

def step(ins):
    m = re.match(r'^push\s', ins)
    if m:
        return -8
    if re.match(r'^pop\s', ins):
        return 8
    m = re.match(r'^sub\s+rsp\s*,\s*(-?\d+)\s*$', ins)
    if m:
        return -int(m.group(1))
    m = re.match(r'^add\s+rsp\s*,\s*(-?\d+)\s*$', ins)
    if m:
        return int(m.group(1))
    m = re.match(r'^lea\s+rsp\s*,\s*\[rsp\s*([-+])\s*(\d+)\]', ins)
    if m:
        return int(m.group(2)) * (1 if m.group(1) == '+' else -1)
    if RSPW.match(ins):
        return None
    return 0

def main():
    out, files = sys.argv[1], sys.argv[2:]
    seen, nfun = set(), 0
    segs = collections.Counter()
    alloc_segs, alloc_bytes, sample = collections.Counter(), collections.Counter(), {}
    pro_bytes, pro_n = 0, 0
    for f in files:
        secs, cur = [], []
        for ln in open(f, encoding='utf-8', errors='replace'):
            if ln.startswith('FN__') and cur:
                secs.append(cur); cur = []
            cur.append(ln.rstrip('\n'))
        secs.append(cur)
        for sec in secs:
            key = hashlib.sha1(re.sub(r'\d+', 'N', '\n'.join(sec)).encode()).hexdigest()
            if key in seen:
                continue
            seen.add(key); nfun += 1
            fn = '?'; owner = None; d = 0; live = False; worst = 0
            def close():
                nonlocal worst, pro_bytes, pro_n
                if owner is not None and owner[0] == 'prologue' and live and d < 0:
                    pro_bytes += -d; pro_n += 1
                if owner is not None and owner[0] != 'prologue':
                    segs[owner] += 1
                    if worst < 0:
                        alloc_segs[owner] += 1; alloc_bytes[owner] += -worst
                        sample.setdefault(owner, '%s %d' % (fn, -worst))
            for ln in sec:
                m = LAB.match(ln); rest = ln
                if m:
                    lab, rest = m.group(1), m.group(2)
                    mb = BOX.match(lab) or INNER.match(lab)
                    if lab.startswith('FN__'):
                        close(); fn = lab[4:]; owner = ('prologue', fn); d = 0; live = True; worst = 0
                    elif mb:
                        if live and d < 0 and owner and owner[0] != 'prologue':
                            worst = min(worst, d)
                        close(); owner = (PORT[mb.group(2)], mb.group(1)); d = 0; live = True; worst = 0
                    elif not lab.startswith('.L'):
                        close(); owner = None; live = False
                if owner is None or not live:
                    continue
                for part in rest.split('#')[0].split(';'):
                    ins = part.strip()
                    if not ins or ins.startswith('.'):
                        continue
                    s = step(ins)
                    if s is None:
                        live = False; break
                    d += s
                    if re.match(r'^(j\w+|ret)\b', ins) and d < 0:
                        worst = min(worst, d)
            close()
    tot = collections.Counter()
    for k, v in segs.items():
        tot[k[0]] += v
    tota = collections.Counter()
    for k, v in alloc_segs.items():
        tota[k[0]] += v
    print('NET functions=%d prologue_carves=%d prologue_bytes=%d' % (nfun, pro_n, pro_bytes))
    for p in ('alpha', 'beta', 'gamma', 'omega', 'box'):
        print('NET_PORT port=%s segments=%d allocating=%d' % (p, tot[p], tota[p]))
    for k, v in sorted(alloc_segs.items(), key=lambda kv: (kv[0][0] != 'beta', -kv[1])):
        if k[0] != 'alpha':
            print('NET_OFF_ALPHA port=%s kind=%s allocating_segments=%d of %d bytes=%d e.g. %s' % (k[0], k[1], v, segs[k], alloc_bytes[k], sample[k][:100]))
    with open(out, 'w', encoding='utf-8', newline='\n') as w:
        for k in sorted(segs):
            w.write('%s\t%s\t%d\t%d\t%d\n' % (k[0], k[1], segs[k], alloc_segs[k], alloc_bytes[k]))

if __name__ == '__main__':
    main()
