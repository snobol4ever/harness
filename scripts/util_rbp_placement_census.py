#!/usr/bin/env python3
"""util_rbp_placement_census.py -- CEO-1682: is every RBP placement one the BB FRAME-PLACEMENT CRITERION admits?

THE QUESTION (Lon 2026-10-11, via the ceo): "Are you absolutely sure ALL the ZETAS are on the RSP SPINE and not wrongly
allocated on the RBP ACTIVATION?"  The criterion (RULES.md, Lon 2026-08-27): an operand or local stays on the RSP spine iff
every consumer reaches it at a fixed compile-time offset on every path; it moves to an RBP activation frame only where
unbounded stack growth can intervene between its write and its read.  This census COMPUTES, for every site, which base the
emitter used and whether the criterion needs it.  Nothing here is a declared list: a site stops being printed the moment it
stops being misplaced.

TWO SITE TABLES (Icon and Prolog, graph by graph; the box graph is `scrip --dump-bb`, the names and the local cells are
`scrip --dump-zeta`, the emitted base is the compiled .s):
  A  OPERAND  -- one site per operator->operand edge (rel "op" in the dump): the operator reads the operand's result cell.
  L  LOCAL    -- one site per box that touches a named frame cell: VAR, VAR_REF, ASSIGN_VAR, REV_ASSIGN_VAR, NULLTEST_VAR,
                 FIELD_VAR, a labelled ASSIGN; every VAR_REF of a Prolog clause (a clause variable is a frame cell).
EMITTED BASE of a site is its graph's: the graph's region in the .s is PINNED (a `mov rbp, rsp` or `lea rbp, [rax+N]`
prologue seed) so every cell of it is rbp-relative, or it is not and every cell is rsp-relative.  A graph with no region in
the .s was never emitted and its sites are counted UNEMITTED, not placed.
CRITERION VERDICT.  A box RETAINS when it can leave a callee frame on the spine after its gamma: SUSPEND, PROC_GEN, CREATE,
ACTIVATE, CORET, COFAIL, CALL_VALUE, and a call whose callee graph (found by name in the same program) retains -- for Icon a
callee containing a SUSPEND (the compiler's rt_proc_is_generator; a procedure that only drives a generator inside itself does not retain for its caller), for Prolog a callee with more than one clause (more than one SUCCEED box; this
is a CONSERVATIVE bound, determinate-by-indexing predicates are counted as retaining, so MISPLACED is a floor).
  operand edge (O,P)  REQUIRED iff a retaining box lies on a gamma path strictly between P and O.
  local site          REQUIRED iff a retaining box can execute before the site (it reaches it over any edge), or is it.
A graph that is itself a generator (holds a SUSPEND or PROC_GEN) is REQUIRED throughout: the sanctioned exception (Lon s242).
STATES per site: SPINE (emitted rsp), REQUIRED (emitted rbp, criterion needs it), MISPLACED (emitted rbp, criterion admits
rsp), UNSAFE (emitted rsp, criterion needs rbp -- must read 0, printed so a wrong spine placement cannot hide).
SNOBOL4 has no per-graph regions (functions are inlined into main, patterns are proc_*_alpha thunks), so its sites are the
rbp memory operands of util_rbp_region_census.py's regions: REQUIRED iff the region rebuilds rsp from rbp mid-body
(`lea rsp, [rbp+N]`, the match retry reset -- unbounded growth reset), MISPLACED otherwise, UNSEEDED rbp operands are DRIFT.

OUTPUT (stdout; the row's DONE-WHEN greps ^RBP_PLACEMENT):
  RBP_PLACEMENT <lang> graphs=G sites=N spine=S required=R misplaced=M unsafe=U unemitted=E
  RBP_PLACEMENT total sites=N placed=P required=R misplaced=M unsafe=U
  RBP_PRECARVE <lang> graphs=G carved_bytes=B zero_filled=Z      (pinned graphs: the frame carved at entry, Lon 2026-09-07)
  RBP_RECONCILE ...                                              (the instrument checked against the .s; rc 2 when it fails)
  --tsv PATH writes one row per MISPLACED graph and table (lang class table graph@sig count); --combos PATH writes the distinct
  operator/operand kind combinations and local-access kinds still misplaced (lang table operator operand count); --check PATH
  reds a graph row absent from the committed --tsv file or whose count rose (a ratchet that can only fall).
rc 0 = measured; rc 1 = --check failed; rc 2 = the instrument did not measure (a program unmeasured, a reconcile failed).
"""
import argparse, collections, hashlib, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SC = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
ROOT = os.environ.get('S4E_HOME') or os.path.dirname(SC)
SCRIP = os.path.join(SC, 'scrip')
CORPUS = os.path.join(ROOT, 'corpus')
EXT = {'.sno': 'snobol4', '.icn': 'icon', '.pl': 'prolog'}
RET_KINDS = {'SUSPEND', 'PROC_GEN', 'CREATE', 'ACTIVATE', 'CORET', 'COFAIL', 'CALL_VALUE'}
GEN_KINDS = {'SUSPEND', 'PROC_GEN', 'CREATE', 'ACTIVATE', 'CORET', 'COFAIL'}
CALL_KINDS = {'CALL_PROC_STAGED', 'CALL_ICON', 'CALL'}
CALLEE_KINDS = {'CALL', 'CALL_ICON', 'CALL_PROC_STAGED', 'CALL_BUILTIN', 'GATE', 'MATCH'}
WINDOW_KINDS = {'PATTERN_ALT', 'PATTERN_CAT', 'PATTERN_CAPTURE', 'PATTERN_DEFER', 'SUSPEND', 'PROC_GEN', 'CREATE', 'ACTIVATE',
                'CORET', 'COFAIL', 'SCAN', 'SCAN_ENTER', 'SCAN_ALTERNATE', 'SCAN_SEQUENCE', 'SCAN_UPTO', 'SCAN_FIND', 'SCAN_MANY',
                'SCAN_ANY', 'SCAN_BAL', 'SCAN_MATCH', 'SCAN_MOVE', 'SCAN_TAB', 'SCAN_POS', 'TO', 'TO_BY', 'LIMIT', 'REPALT',
                'ITERATE', 'DISJUNCTION', 'CUT', 'CALL_BUILTIN_GEN', 'KW_ICON_GEN', 'CALL_VALUE', 'REV_ASSIGN', 'REV_ASSIGN_VAR',
                'REV_SWAP', 'MATCH_FENCE1', 'MATCH_FENCE0', 'MATCH_ABORT', 'MATCH_ARBNO', 'MATCH_CALLOUT', 'MATCH_VALUE',
                'MATCH_DEFER', 'MATCH_ALTERNATE'}
LOCAL_KINDS = {'VAR', 'VAR_REF', 'ASSIGN_VAR', 'REV_ASSIGN_VAR', 'NULLTEST_VAR', 'FIELD_VAR'}
SEED = re.compile(r'\bmov\s+rbp\s*,\s*rsp\b|\blea\s+rbp\s*,\s*(qword ptr\s*)?\[\s*rax\s*\+')
RBPM = re.compile(r'\[\s*rbp\s*[+\-\]]')
RSPM = re.compile(r'\[\s*rsp\s*[+\-\]]')
CEREM = re.compile(r'\bmov\s+\[\s*rsp\s*[+-]\s*\d+\s*\]\s*,\s*rbp\b|\bmov\s+rbp\s*,\s*rsp\b|\bmov\s+rsp\s*,\s*rbp\b'
                   r'|\bmov\s+rbp\s*,\s*(qword ptr\s*)?\[\s*r?[sb]p\s*[+-]\s*\d+\s*\]|\b(push|pop)\s+rbp\b')
CLASSD = re.compile(r'\bmov\s+rbp\s*,\s*(qword ptr\s*)?\[r(ax|bx|cx|dx|si|di|8|9|1[0-5])')
FNLAB = re.compile(r'^FN__([^:\s]+):')
MAINLAB = re.compile(r'^(main):')
SNO_ENTRY = re.compile(r'^(proc_.*_α|main|main_init)\s*:')
SUBRSP = re.compile(r'\bsub\s+rsp\s*,\s*(\d+)\b')
RSP_FROM_RBP = re.compile(r'\blea\s+rsp\s*,\s*(qword ptr\s*)?\[\s*rbp\b')


def decode(n):
    return re.sub(r'\$([0-9A-F]{2})', lambda m: chr(int(m.group(1), 16)), n)


def run(args, cwd, stdout=subprocess.PIPE, timeout=120):
    return subprocess.run(args, cwd=cwd, stdin=subprocess.DEVNULL, stdout=stdout, stderr=subprocess.DEVNULL, timeout=timeout)


def discover():
    out = []
    for top in ('benchmarks', 'demos'):
        for dp, _, fs in os.walk(os.path.join(CORPUS, top)):
            for f in fs:
                if not f.endswith('.s'):
                    continue
                stem = os.path.join(dp, f[:-2])
                for e, lang in EXT.items():
                    if os.path.isfile(stem + e):
                        out.append((lang, stem + e))
    return sorted(out, key=lambda x: (x[0], x[1]))


def compile_asm(lang, src, tmp):
    cwd, base = os.path.dirname(src), os.path.basename(src)
    args = [SCRIP, '--compile'] + (['--target=x86'] if lang == 'prolog' else []) + [base]
    with open(tmp, 'wb') as fh:
        r = run(args, cwd, stdout=fh, timeout=120)
    return r.returncode == 0 and os.path.getsize(tmp) > 0


def zeta_info(src):
    cwd, base = os.path.dirname(src), os.path.basename(src)
    names, vslots, cur = {}, collections.defaultdict(set), None
    for ln in run([SCRIP, '--dump-zeta', base], cwd).stdout.decode('utf-8', 'replace').splitlines():
        m = re.match(r"; graph (\d+) '(.*)' ", ln)
        if m:
            cur = int(m.group(1))
            names[cur] = m.group(2)
            continue
        m = re.match(r';\s+vslot \+\d+\s+\d+\s+\S+\s+(\S+)', ln)
        if m and cur is not None:
            vslots[cur].add(m.group(1))
    return names, vslots


def insns(ln):
    s = ln.strip()
    m = re.match(r'^[^\s:#"]+:\s*(.*)$', s)
    if m:
        s = m.group(1)
    s = s.split('#')[0].strip()
    if not s or s.startswith('.'):
        return []
    return [x.strip() for x in s.split(';') if x.strip()]


def asm_regions(path, wanted=None):
    regs, cur, hold = {}, None, 0
    for ln in open(path, encoding='utf-8', errors='replace'):
        if ln[:4] == 'FN__' or ln[:5] == 'main:':
            m = FNLAB.match(ln) or MAINLAB.match(ln)
        else:
            m = None
        if m:
            nm = decode(m.group(1)) if m.re is FNLAB else 'main'
            cur = regs.setdefault(nm, {'seed': 0, 'rbp': 0, 'rsp': 0, 'carve': 0, 'zero': 0}) if (wanted is None or nm in wanted) else None
            hold = 14
            continue
        if cur is None:
            continue
        for s in insns(ln):
            if hold > 0:
                hold -= 1
                mm = SUBRSP.search(s)
                if mm and not cur['carve']:
                    cur['carve'] = int(mm.group(1))
                if re.search(r'\brep\s+stos|\bxorps\s+xmm0, xmm0', s):
                    cur['zero'] = 1
            if SEED.search(s):
                cur['seed'] += 1
            if CEREM.search(s) or CLASSD.search(s):
                continue
            if RBPM.search(s):
                cur['rbp'] += 1
            if RSPM.search(s):
                cur['rsp'] += 1
    return regs


def sno_regions(path):
    regs, cur = [], None
    for ln in open(path, encoding='utf-8', errors='replace'):
        m = SNO_ENTRY.match(ln.strip())
        if m:
            cur = {'name': m.group(1), 'seed': 0, 'rbp': 0, 'rsp': 0, 'reset': 0}
            regs.append(cur)
            continue
        if cur is None:
            continue
        for s in insns(ln):
            if SEED.search(s):
                cur['seed'] += 1
            if RSP_FROM_RBP.search(s):
                cur['reset'] += 1
            if CEREM.search(s) or CLASSD.search(s):
                continue
            if RBPM.search(s):
                cur['rbp'] += 1
            if RSPM.search(s):
                cur['rsp'] += 1
    return regs


def graphs_of(dump, names, vslots):
    boxes = {b['id']: b for b in dump['boxes']}
    by = collections.defaultdict(list)
    for i in boxes:
        by[int(i.split('_')[0][1:])].append(i)
    gam, rgam, allf, ops = collections.defaultdict(list), collections.defaultdict(list), collections.defaultdict(list), []
    for e in dump['edges']:
        if e['from'] not in boxes or e['to'] not in boxes:
            continue
        if e.get('rel') == 'op':
            ops.append((e['from'], e['to']))
        elif e.get('fp') == 'gamma':
            allf[e['from']].append(e['to'])
            if e.get('tp') == 'alpha':
                gam[e['from']].append(e['to'])
                rgam[e['to']].append(e['from'])
    return boxes, by, gam, rgam, allf, ops


def analyse_program(lang, src, tmpasm, seen):
    if not compile_asm(lang, src, tmpasm):
        return None
    if lang == 'snobol4':
        return {'sno': sno_regions(tmpasm)}
    names, vslots = zeta_info(src)
    raw = run([SCRIP, '--dump-bb', os.path.basename(src)], os.path.dirname(src), timeout=180).stdout
    dump = json.loads(raw.decode('utf-8', 'replace'))
    boxes = {b['id']: b for b in dump['boxes']}
    by = collections.defaultdict(list)
    for i in boxes:
        by[int(i.split('_')[0][1:])].append(i)
    gedges = collections.defaultdict(list)
    for e in dump['edges']:
        if e['from'] in boxes and e['to'] in boxes:
            gedges[int(e['from'].split('_')[0][1:])].append(e)
    gname = {g: names.get(g, '?') for g in by}
    gen_graph, susp_graph, multi, sigs = {}, {}, {}, {}
    for g, ids in by.items():
        ks = {boxes[i]['kind'] for i in ids}
        gen_graph[gname[g]] = bool(ks & GEN_KINDS)
        susp_graph[gname[g]] = 'SUSPEND' in ks
        multi[gname[g]] = sum(1 for i in ids if boxes[i]['kind'] == 'SUCCEED') > 1
        sigs[g] = hashlib.sha1(json.dumps([sorted((boxes[i]['kind'], boxes[i].get('label', '')) for i in ids),
                                           sorted((e['from'].split('_', 1)[1], e.get('fp', ''), e['to'].split('_', 1)[1], e.get('tp', ''), e.get('rel', ''), e.get('slot', ''))
                                                  for e in gedges[g])]).encode()).hexdigest()[:10]
    new = {g for g in by if (lang, gname[g], sigs[g]) not in seen}
    regs = asm_regions(tmpasm, {gname[g] for g in new})

    def retains(bid):
        b = boxes[bid]
        if b['kind'] in RET_KINDS:
            return True
        if b['kind'] in CALL_KINDS:
            lab = b.get('label', '')
            return susp_graph.get(lab, False) if lang == 'icon' else multi.get(lab, False)
        return False

    out = []
    for g in sorted(new):
        ids = by[g]
        nm = gname[g]
        reg = regs.get(nm)
        rset = {i for i in ids if retains(i)}
        gen = gen_graph.get(nm, False)
        kinds = [boxes[i]['kind'] for i in ids]
        win = [k for k in kinds if k in WINDOW_KINDS]
        cal = [k for k in kinds if k in CALLEE_KINDS]
        if lang == 'icon':
            cause = 'icn-generator-procedure' if gen else ('icn-window:' + sorted(set(win))[0] if win else ('icn-callee:' + sorted(set(cal))[0] if cal else 'icn-none'))
        else:
            cause = 'pl-predicate-retaining-callee' if rset else 'pl-predicate-no-retaining-callee'
        gam, rgam, allf, ops = collections.defaultdict(list), collections.defaultdict(list), collections.defaultdict(list), []
        for e in gedges[g]:
            if e.get('rel') == 'op':
                ops.append((e['from'], e['to'], e.get('slot', '')))
            elif e.get('fp') == 'gamma':
                allf[e['from']].append(e['to'])
                if e.get('tp') == 'alpha':
                    gam[e['from']].append(e['to'])
                    rgam[e['to']].append(e['from'])
        sites = []
        for (o, p, slot) in ops:
            fwd, st = set(), [p]
            while st:
                x = st.pop()
                for y in gam[x]:
                    if y != o and y not in fwd:
                        fwd.add(y)
                        st.append(y)
            bwd, st = set(), [o]
            while st:
                x = st.pop()
                for y in rgam[x]:
                    if y != p and y not in bwd:
                        bwd.add(y)
                        st.append(y)
            req = gen or bool(((fwd & bwd) - {p, o}) & rset)
            sites.append(('A', boxes[o]['kind'], boxes[p]['kind'] + '#' + str(slot), req))
        rall = collections.defaultdict(list)
        for x in ids:
            for y in allf[x]:
                rall[y].append(x)
        for i in ids:
            b = boxes[i]
            k = b['kind']
            lab = b.get('label', '')
            loc = (k in LOCAL_KINDS and (lang == 'prolog' or lab in vslots.get(g, ()))) or (k == 'ASSIGN' and lab in vslots.get(g, ()))
            if not loc:
                continue
            seen_b, st = set(), [i]
            while st:
                x = st.pop()
                for y in rall[x]:
                    if y not in seen_b:
                        seen_b.add(y)
                        st.append(y)
            req = gen or bool(seen_b & rset) or (i in rset)
            sites.append(('L', k, lab, req))
        out.append({'name': nm, 'sig': sigs[g], 'cause': cause, 'region': reg, 'sites': sites})
    return {'graphs': out}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--files', nargs='*', help='source files to measure instead of the committed-artifact set')
    ap.add_argument('--lang', choices=['snobol4', 'icon', 'prolog'])
    ap.add_argument('--tsv')
    ap.add_argument('--combos')
    ap.add_argument('--check')
    ap.add_argument('--verbose', action='store_true')
    a = ap.parse_args()
    if not os.access(SCRIP, os.X_OK):
        print('RBP_PLACEMENT REFUSE: no ./scrip at ' + SCRIP)
        return 2
    progs = [(next((l for e, l in EXT.items() if f.endswith(e)), None), os.path.abspath(f)) for f in a.files] if a.files else discover()
    if a.lang:
        progs = [p for p in progs if p[0] == a.lang]
    tot = {l: collections.Counter() for l in EXT.values()}
    seen_graphs, rows, unmeasured, reconcile = set(), collections.Counter(), [], collections.Counter()
    carve = {l: collections.Counter() for l in EXT.values()}
    with tempfile.TemporaryDirectory() as td:
        tmpasm = os.path.join(td, 'p.s')
        for pi, (lang, src) in enumerate(progs):
            print('  [%d/%d] %s %s' % (pi + 1, len(progs), lang, os.path.relpath(src, CORPUS)), file=sys.stderr, flush=True)
            try:
                r = analyse_program(lang, src, tmpasm, seen_graphs)
            except Exception as ex:
                r = None
                if a.verbose:
                    print('  unmeasured %s: %s' % (src, ex), file=sys.stderr)
            if r is None:
                unmeasured.append(src)
                continue
            t = tot[lang]
            if lang == 'snobol4':
                for rg in r['sno']:
                    key = (lang, os.path.basename(src), rg['name'])
                    t['graphs'] += 1
                    t['spine'] += rg['rsp']
                    if rg['rbp']:
                        if rg['seed'] and rg['reset']:
                            t['required'] += rg['rbp']
                        elif rg['seed']:
                            t['misplaced'] += rg['rbp']
                            rows[(lang, 'snobol4-seeded-region-no-rsp-reset', 'R', os.path.basename(src) + ':' + rg['name'], 'rbp-operand', '-')] += rg['rbp']
                        else:
                            reconcile['drift'] += rg['rbp']
                    t['sites'] += rg['rsp'] + rg['rbp']
                continue
            for gr in r['graphs']:
                key = (lang, gr['name'], gr['sig'])
                if key in seen_graphs:
                    continue
                seen_graphs.add(key)
                reg = gr['region']
                t['graphs'] += 1
                if reg is None:
                    t['unemitted'] += len(gr['sites'])
                    reconcile['graphs_without_region'] += 1
                    continue
                pinned = reg['seed'] > 0
                if not pinned and reg['rbp'] > 0:
                    reconcile['drift'] += reg['rbp']
                if pinned and reg['rbp'] == 0:
                    reconcile['pinned_without_rbp_operand'] += 1
                if pinned:
                    carve[lang]['graphs'] += 1
                    carve[lang]['bytes'] += reg['carve']
                    carve[lang]['zero'] += reg['zero']
                for (tb, ok, oth, req) in gr['sites']:
                    t['sites'] += 1
                    if not pinned:
                        t['unsafe' if req else 'spine'] += 1
                    elif req:
                        t['required'] += 1
                    else:
                        t['misplaced'] += 1
                        rows[(lang, gr['cause'], tb, gr['name'] + '@' + gr['sig'], ok, oth)] += 1
    for lang in EXT.values():
        if tot[lang]['graphs'] == 0 and any(p[0] == lang for p in progs):
            unmeasured.append('<' + lang + ' measured nothing>')
    if unmeasured:
        print('RBP_PLACEMENT REFUSE: %d program(s) unmeasured: %s' % (len(unmeasured), ' '.join(os.path.relpath(u, ROOT) if os.path.isabs(u) else u for u in unmeasured[:6])))
        return 2
    gt = collections.Counter()
    for lang in EXT.values():
        t = tot[lang]
        if not any(p[0] == lang for p in progs):
            continue
        print('RBP_PLACEMENT %s graphs=%d sites=%d spine=%d required=%d misplaced=%d unsafe=%d unemitted=%d' %
              (lang, t['graphs'], t['sites'], t['spine'], t['required'], t['misplaced'], t['unsafe'], t['unemitted']))
        for k in ('sites', 'spine', 'required', 'misplaced', 'unsafe'):
            gt[k] += t[k]
    print('RBP_PLACEMENT total sites=%d placed=%d required=%d misplaced=%d unsafe=%d' % (gt['sites'], gt['spine'] + gt['required'], gt['required'], gt['misplaced'], gt['unsafe']))
    for lang in ('icon', 'prolog'):
        if any(p[0] == lang for p in progs):
            print('RBP_PRECARVE %s pinned_graphs=%d carved_bytes=%d zero_filled=%d' % (lang, carve[lang]['graphs'], carve[lang]['bytes'], carve[lang]['zero']))
    print('RBP_RECONCILE programs=%d unique_graphs=%d graphs_without_region=%d unseeded_rbp_operands_drift=%d pinned_graphs_with_no_rbp_operand=%d' %
          (len(progs), len(seen_graphs), reconcile['graphs_without_region'], reconcile['drift'], reconcile['pinned_without_rbp_operand']))
    bycause = collections.Counter()
    for k, n in rows.items():
        bycause[(k[0], k[1])] += n
    for (l, c), n in sorted(bycause.items(), key=lambda x: -x[1]):
        print('RBP_PLACEMENT_CLASS %s %s misplaced=%d' % (l, c, n))
    per_graph, combos = collections.Counter(), collections.Counter()
    for k, n in rows.items():
        per_graph[(k[0], k[1], k[2], k[3])] += n
        combos[(k[0], k[2], k[4], k[5].split('#')[0] if k[2] == 'A' else '-')] += n
    for lang in ('icon', 'prolog', 'snobol4'):
        ca = [v for k, v in combos.items() if k[0] == lang and k[1] == 'A']
        cl = [v for k, v in combos.items() if k[0] == lang and k[1] != 'A']
        if any(p[0] == lang for p in progs):
            print('RBP_PLACEMENT_COMBOS %s operand_combos=%d operand_sites=%d local_kinds=%d local_sites=%d' % (lang, len(ca), sum(ca), len(cl), sum(cl)))
    if a.tsv:
        with open(a.tsv, 'w') as fh:
            for k in sorted(per_graph):
                fh.write('\t'.join(list(k) + [str(per_graph[k])]) + '\n')
    if a.combos:
        with open(a.combos, 'w') as fh:
            for k in sorted(combos):
                fh.write('\t'.join(list(k) + [str(combos[k])]) + '\n')
    rc = 0
    if reconcile['drift']:
        print('RBP_RECONCILE FAIL: %d rbp operand(s) in a region that never seeded rbp' % reconcile['drift'])
        rc = 2
    if a.check:
        base = {}
        for ln in open(a.check):
            q = ln.rstrip('\n').split('\t')
            if len(q) == 5:
                base[tuple(q[:4])] = int(q[4])
        worse = [(k, n, base.get(k, 0)) for k, n in per_graph.items() if n > base.get(k, 0)]
        for k, n, b in sorted(worse)[:12]:
            print('RBP_PLACEMENT_RATCHET new or risen: %s now=%d baseline=%d' % ('/'.join(k), n, b))
        print('RBP_PLACEMENT_RATCHET graph_tables baseline=%d now=%d risen_or_new=%d' % (len(base), len(per_graph), len(worse)))
        if worse and rc == 0:
            rc = 1
    return rc


if __name__ == '__main__':
    sys.exit(main())
