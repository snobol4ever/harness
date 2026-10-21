#!/usr/bin/env python3
"""util_rsp_reset_by_port_census.py -- every RESET of rsp in the emitted .s (a write of rsp that is not a relative add, sub, push or pop: mov rsp, X;
lea rsp, [base other than rsp]; leave; xchg/and/pop rsp), by the box and port whose code holds it (Lon 2026-10-21: "Ensure that we NEVER
reset RSP at BETA."; CEO-1814, CEO-1841). Owners as in util_alloc_by_port_census.py; each distinct function body counted once.
Usage: util_rsp_reset_by_port_census.py file.s..."""
import collections, hashlib, re, sys

LAB = re.compile(r'^([^\s#][^\s:]*):\s*(.*)$')
BOX = re.compile(r'^n\d+_([a-z0-9_]+?)_(α|β|γ|ω|bx)$')
INNER = re.compile(r'^\.L([a-z0-9_]+?)_(α|β|γ|ω)_\d+(?:_\d+)?$')
PORT = {'α': 'alpha', 'β': 'beta', 'γ': 'gamma', 'ω': 'omega', 'bx': 'box'}
RESET = re.compile(r'^(?:mov\s+rsp\s*,|lea\s+rsp\s*,\s*\[(?!\s*rsp\b)|xchg\s+rsp\b|xchg\s+\w+\s*,\s*rsp\b|and\s+rsp\b|pop\s+rsp\b|leave\b)')

def main():
    seen, c, sample = set(), collections.Counter(), {}
    for f in sys.argv[1:]:
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
            seen.add(key)
            fn, owner = '?', ('other', '-')
            for ln in sec:
                m = LAB.match(ln); rest = ln
                if m:
                    lab, rest = m.group(1), m.group(2)
                    mb = BOX.match(lab) or INNER.match(lab)
                    if lab.startswith('FN__'):
                        fn, owner = lab[4:], ('prologue', '-')
                    elif mb:
                        owner = (PORT[mb.group(2)], mb.group(1))
                    elif not lab.startswith('.L'):
                        owner = ('graph-protocol', '-') if (lab.endswith('_step') or '_α_body' in lab or lab.startswith('$')) else ('entry-glue', '-')
                for part in rest.split('#')[0].split(';'):
                    ins = part.strip()
                    if ins and RESET.match(ins):
                        k = (owner[0], owner[1], re.sub(r'\d+', 'N', ins.split(',', 1)[-1].strip()) if ins.startswith(('mov', 'lea')) else ins.split()[0])
                        c[k] += 1
                        sample.setdefault(k, fn)
    byport = collections.Counter()
    for (p, kind, src), v in c.items():
        byport[p] += v
    print('RSP_RESET functions=%d %s' % (len(seen), ' '.join('%s=%d' % kv for kv in sorted(byport.items()))))
    for (p, kind, src), v in sorted(c.items(), key=lambda kv: -kv[1]):
        if p == 'beta':
            print('RSP_RESET_BETA kind=%s from=%s sites=%d e.g. %s' % (kind, src[:40], v, sample[(p, kind, src)][:60]))

if __name__ == '__main__':
    main()
