#!/usr/bin/env python3
# util_rsp_reset_beta_sites.py <list> <asm dir> <out.tsv> -- the per-site twin of util_rsp_reset_by_port_census.py: one row per rsp reset inside a box beta (program, function, box, label, instruction), same function-body dedupe, so the row count equals the census total. <list> is util_spine_population.sh output (lang<TAB>path), <asm dir> holds 1.s..N.s compiled in list order. (hq_prolog 2026-10-28, CEO-1996)
import collections, hashlib, re, sys, os
sys.path.insert(0, '/home/claude_prolog/harness/scripts')
import util_rsp_reset_by_port_census as C
lst = [l.rstrip('\n').split('\t')[1] for l in open(sys.argv[1])]
seen = set(); rows = []
for i, prog in enumerate(lst, 1):
    f = f'{sys.argv[2]}/{i}.s'
    secs, cur = [], []
    for ln in open(f, encoding='utf-8', errors='replace'):
        if ln.startswith('FN__') and cur: secs.append(cur); cur = []
        cur.append(ln.rstrip('\n'))
    secs.append(cur)
    for sec in secs:
        key = hashlib.sha1(re.sub(r'\d+', 'N', '\n'.join(sec)).encode()).hexdigest()
        if key in seen: continue
        seen.add(key)
        fn, owner = '?', ('other', '-')
        for ln in sec:
            m = C.LAB.match(ln); rest = ln; lab = ''
            if m:
                lab, rest = m.group(1), m.group(2)
                mb = C.BOX.match(lab) or C.INNER.match(lab)
                if lab.startswith('FN__'): fn, owner = lab[4:], ('prologue', '-')
                elif mb: owner = (C.PORT[mb.group(2)], mb.group(1))
                elif C.GPORT.match(lab): owner = ('graph-' + C.PORT[C.GPORT.match(lab).group(2)], '-')
                elif not lab.startswith('.L'): owner = ('graph-protocol', '-') if (lab.endswith('_step') or '_α_body' in lab or lab.startswith('$')) else ('entry-glue', '-')
            for part in rest.split('#')[0].split(';'):
                ins = part.strip()
                if ins and C.RESET.match(ins) and owner[0] == 'beta':
                    rows.append((os.path.basename(prog), fn, owner[1], lab, ins))
print('beta sites:', len(rows))
byprog = collections.Counter(r[0] for r in rows); byins = collections.Counter(re.sub(r'\d+', 'N', r[4]) for r in rows); byfn = collections.Counter(r[1] for r in rows); bybox = collections.Counter(r[2] for r in rows)
print('by program:', ', '.join(f'{k}={v}' for k, v in byprog.most_common()))
print('by instruction:', ', '.join(f'{k!r}={v}' for k, v in byins.most_common()))
print('by box:', ', '.join(f'{k}={v}' for k, v in bybox.most_common(12)))
print('distinct functions:', len(byfn))
with open(sys.argv[3], 'w') as o:
    for r in rows: o.write('\t'.join(r) + '\n')
