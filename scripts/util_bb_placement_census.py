#!/usr/bin/env python3
"""util_bb_placement_census.py -- CEO-1722: does every BB OPERAND (result) and every BB LOCAL live on the RSP SPINE?

THE WORD (Lon 2026-10-14, in-chat to the ceo): "You have a problem in that the RSP-spine is not being used for 90% of ALL BB
operands." and "And add BB's LOCALS to that list also."  THE GOAL: every BB operand and every BB local lives on the RSP spine at
a fixed compile-time offset unless the BB FRAME-PLACEMENT CRITERION forces it off -- an RBP activation frame only where unbounded
growth can intervene between a cell's write and its read (a gamma-suspend, a frame a choice point or a generator retains); a
static slot never for a per-activation cell.  A cell carved with the whole frame at entry and addressed off rsp is RSP by base
register but NOT on the spine (Lon 2026-09-07: "We do not pre-carve. Each BB carves it's own memory."; the cto's reading
2026-10-14), so it is its own home here and its own column, never folded into the spine.

HOMES come from the COMPILER'S OWN STATE, not from a base-register count of the .s: `scrip --dump-homes --compile` prints one
[HOMES] line per node and per local of every graph the flat chain body emits --
  SPINE       a depth-planner cell (the box carves it when it produces it; zd_on and K > 0)
  RSP_CARVED  a layout cell at a fixed rsp offset in a frame carved whole at entry
  RBP         a layout cell behind rbp (a pinned graph, a generator's rbp frame, an xop frame member)
  NONE        no cell (wiring, a K=0 protocol box, an elided result)
Every rip-relative or absolute memory operand in the .s is a runtime cell, a keyword, a GOT entry or a global variable's GVA
cell, never a BB operand's or local's home; the base-register view is printed beside the compiler view (BB_PLACEMENT_ASM) so
the ceo's measurement of 2026-10-14 reproduces next to the classification that answers it.

THE TWO TESTS (CEO-1750, Lon 2026-10-14: "first assumption is RSP-spine, but if a BB operand can not be reached by fixed RSP
offset, or a BB local can not be reached by same RSP relative address for ALPHA and BETA ... ONLY these two cases go to an RBP
ACTIVATION FRAME. ALL the rest/remaining must be RSP SPINE CELLS."), per cell, over the box graph (`scrip --dump-bb` edges) and the
compiler's own rsp facts (`scrip --dump-homes`):
  PLAN_ROW retains_code > 0  a DYNAMIC box (CEO-1949, the cto's ruling as design seat): a box whose gamma leaves rsp at a distance from its alpha no
                             compile-time offset states. The census asks the planner's ONE RETAINS TABLE (planner_retains, SCRIP src/planner/zeta_plan.cpp,
                             the plan dump's retains_code column, found by its NAME in PLAN_COLUMNS) and nothing else: 1 suspend, 2 coexpression,
                             3 unknown-callee, 4 generator-callee, 5 retaining-callee, 6 unresolved-callee, 7 deferred-pattern, 8 gate-holds,
                             9 disjunction-holds, 10 db-generator, 11 retaining-target. The compiler's dump-only retaining-callee proxy, the callee's
                             resumable= and a grep of the callee's asm decide nothing;
  [RSPFX] rsp=renormal       a cut, which restores rsp to the frame base;
  [LOCALUSE] local=V         a box that touches local V (the compiler's own name, VAR_REF included);
  [HOMES] standing=K         the root graph's standing cells (global-type, STANDING, CEO-1751).
  OPERAND TEST: result cell P fails iff for some consumer O a control path P ... O (not through P again) crosses a dynamic box
  with no cut after it, or P is itself dynamic (the path starts at P's gamma edges: once P fails (its omega) its cell is popped and
  nothing reads it, CEO-1865; an Icon DISJUNCTION is no consumer: its op edges name its arms, and the emitted box reads only its own carve --
  the arm selector at [rsp + 16] -- while each arm's last box copies its result into that carve); LOCAL TEST: local V fails iff some box touching it can be entered, at alpha or
  beta, on a path from a dynamic box with no cut between.  No graph-level proxy (generator, retained graph, more than one SUCCEED)
  forces anything by itself.
STATES per cell: SPINE; RBP_FORCED; RBP_MISPLACED (behind rbp, the criterion admits the spine); CARVED_FORCED (printed, owed to
the rbp audit's UNSAFE question, never counted here); CARVED_MISPLACED (pre-carved, the planner could push it where first
used); NONE.  misplaced = RBP_MISPLACED + CARVED_MISPLACED, each printed apart so neither share hides behind the other.

OUTPUT (stdout; the row's DONE-WHEN greps ^BB_PLACEMENT):
  BB_PLACEMENT <lang> graphs=G operands=N locals=M spine=S rsp_carved=C rbp=R none=X rbp_forced=.. rbp_misplaced=.. carved_forced=.. carved_misplaced=.. misplaced=.. unemitted=E
  BB_PLACEMENT total operands=N locals=M spine=S rbp_misplaced=.. carved_misplaced=.. misplaced=..
  BB_PLACEMENT_ASM <lang> mem_operands=N rsp=.. rbp=.. rip=.. r12=.. r13=.. other=..
  BB_PLACEMENT_CLASS <lang> <state>:<cause> <A|L> <kind> count=..
  BB_PLACEMENT_TESTS <lang>|total offspine=.. operand_test=.. local_test=.. standing=.. other=..   (other = off the spine, no test fails)
  BB_PLACEMENT_TESTS_WHY <lang> <test>:<why> count=..
  BB_PLACEMENT_FRAMEHOME <lang> homes=.. agree=.. home_without_test=.. test_without_home=.. ruled=..   (CEO-1854: an operand the compiler carves on the spine
      AND mirrors to an RBP frame slot -- scrip --dump-homes' xf=/xfwhy= -- is TEST 1's frame home; agree = the census's own operand path test
      fails too; home_without_test = homed where the path test passes; test_without_home = the path test fails and nothing is homed, each a
      read at a fixed rsp offset to verify by hand -- the census's retaining-callee proxy over-reaches for an Icon procedure that never suspends;
      CEO-1949 (narrowed by the ceo): ruled = a home the path test does not force that the planner's own facts name a class the ceo ruled right by Lon's
      first test -- a PINNED TEMP (HOMETEST operand:pinned-temp, xfwhy read-across-retaining-edge) WITNESSED by a retry edge, i.e. a box with an incoming beta
      edge lies on a gamma path between the write and a consumer's read, so a retry re-reads the cell; or a RETAINING DISJUNCTION (xfwhy retaining-disjunction
      on an IR_DISJUNCTION, zls_dj_retains). A pinned temp with NO such box is not read across a retaining edge: it counts as home_without_test, the planner's
      reuse-class rule alone homes it. BB_PLACEMENT_FRAMEHOME_PINNED <lang> witnessed=.. unwitnessed=.. prints the split of every pinned temp the path test
      does not force; BB_PLACEMENT_FRAMEHOME_RULED <lang> class=<c> witnessed|planner count=.. prints what is ruled
  BB_PLACEMENT_FRAMEHOME_WHY <lang> why:<rule>|hwt:<rule>|nohome:<test> kind=<box kind> count=..   (why: every home by the planner's rule;
      hwt: the home_without_test side of the same homes, the improper RBP allocations; nohome: the test_without_home side; --cells names
      them frame_homed_untested and spine_unhomed; a frame_homed row's tenth column is the planner's HOMETEST why, e.g. operand:pinned-temp, so a residue names its rule at once)
  BB_HOSTS <lang> ops_rsp=.. ops_rbp=.. ops_precarved=.. ops_none=.. loc_rsp=.. loc_rbp=.. loc_rbp_forced=.. loc_rbp_misplaced=.. loc_none=..
      (Lon 2026-10-21: RSP-hosted against RBP-hosted, operands and locals. An operand is RBP-hosted when it lives behind rbp or the compiler
      mirrors its spine cell to a frame slot; a local is RBP-hosted when it is a frame slot, forced = it fails the local test, misplaced =
      it does not. ops_prealloc = a box granted a frame slot at entry whose cell is NOT an RBP home (on the spine, or no cell): a PRE-ALLOCATION
      (Lon 2026-10-21: "SPINE allocations MUST ONLY be allocated PER BOX and at ALPHA at EACH BOX."); the pre-allocation count is
      ops_prealloc + ops_precarved + loc_rbp_misplaced. util_placement_watch.sh records these per tree in /home/resources/progress/PLACEMENT.tsv.)
  BB_UNWIND <lang>|total rsp_loads=.. retry_restore=.. discard_restore=.. multi_pop=..   (CEO-1755/1759, from the emitted .s: see asm_unwind)
  BB_UNWIND_RSPLOAD <lang> <class> count=..   every rsp load by the label it sits under: restore_* is a RETRY loading rsp from a saved
      value (banned), discard_* a FENCE, ARBNO, cut or statement landing dropping rsp to a saved depth (allowed, counted apart)
  BB_UNWIND_MULTIPOP <lang> into=<box kind> count=..
  --tsv PATH writes one row per misplaced (lang state cause table graph@sig kind count).
  --cells PATH writes one row per OFF-SPINE cell, naming the CEO-1750 test it fails (the cto's review of the spine flip,
      2026-10-17): lang home state test why graph@sig table kind cell -- home RBP or RSP_CARVED, state *_forced or *_misplaced,
      test operand, local or none (none: off the spine with no test failing, which is what misplaced means), why the dynamic
      box's reason, cell the box id or the local's name.
rc 0 = measured; rc 2 = the instrument did not measure (a program unmeasured).
"""
import argparse, collections, hashlib, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SC = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
ROOT = os.environ.get('S4E_HOME') or os.path.dirname(SC)
SCRIP = os.path.join(SC, 'scrip')
CORPUS = os.path.join(ROOT, 'corpus')
EXT = {'.sno': 'snobol4', '.icn': 'icon', '.pl': 'prolog', '.sc': 'snocone', '.reb': 'rebus', '.pas': 'pascal', '.raku': 'raku'}
GEN_KINDS = {'SUSPEND', 'PROC_GEN', 'CREATE', 'ACTIVATE', 'CORET', 'COFAIL'}
HOMES = re.compile(r'^\[HOMES\] g=(-?\d+) graph=(\S+) (all|local)=(\S+) (?:kind=(\S+) )?home=(\S+) off=(-?\d+)(?: xf=(-?\d+) xfwhy=(\S+))?$')
RSPFX = re.compile(r'^\[RSPFX\] g=(-?\d+) graph=(\S+) all=(\d+) kind=(\S+) rsp=(dynamic|renormal) why=(\S+) callee=(\S+)$')
LOCALUSE = re.compile(r'^\[LOCALUSE\] g=(-?\d+) graph=(\S+) all=(\d+) kind=(\S+) local=(\S+)$')
HTEST = re.compile(r'^\[HOMETEST\] g=(-?\d+) graph=(\S+) all=(\d+) kind=(\S+) test=(\S+)$')
PLANG = re.compile(r'^PLAN graph=(\S+) ')
PLANR = re.compile(r'^PLAN_ROW i=\d+ all=(-?\d+) kind=\S+ (.*)$')
RETAINS = {1: 'suspend', 2: 'coexpression', 3: 'unknown-callee', 4: 'generator-callee', 5: 'retaining-callee', 6: 'unresolved-callee', 7: 'deferred-pattern', 8: 'gate-holds',
           9: 'disjunction-holds', 10: 'db-generator', 11: 'retaining-target'}
STANDING = re.compile(r'^\[HOMES\] g=(-?\d+) graph=(\S+) standing=(\d+) home=STANDING why=(\S+)$')
MEM = re.compile(r'\[\s*([a-z0-9]+)')


def run(args, cwd, timeout=300):
    return subprocess.run(args, cwd=cwd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)


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


def homes_of(lang, src, tmp):
    cwd, base = os.path.dirname(src), os.path.basename(src)
    args = [SCRIP, '--dump-homes', '--dump-plan', '--compile'] + (['--target=x86'] if lang == 'prolog' else []) + ['-o', tmp, base]
    r = run(args, cwd)
    if r.returncode != 0 or not os.path.isfile(tmp) or os.path.getsize(tmp) == 0:
        return None, None, None
    nodes, locs, fx = {}, {}, {'renorm': set(), 'standing': [], 'uses': {}, 'retains': {}, 'htest': {}}
    cur, ri, named, name_gi = None, None, {}, collections.defaultdict(set)
    for ln in r.stdout.decode('utf-8', 'replace').splitlines():
        if ln.startswith('PLAN_COLUMNS '):
            cols = ln.split()[1:]
            ri = cols.index('retains_code') if 'retains_code' in cols else None
            continue
        m = PLANG.match(ln)
        if m:
            cur = m.group(1)
            continue
        m = PLANR.match(ln)
        if m and ri is not None:
            v = m.group(2).split()
            c = int(v[ri]) if ri < len(v) and v[ri].lstrip('-').isdigit() else 0
            k = (cur, int(m.group(1)))
            named[k] = max(c, named.get(k, 0))
    for ln in r.stderr.decode('utf-8', 'replace').splitlines():
        m = RSPFX.match(ln)
        if m:
            k = (int(m.group(1)), int(m.group(3)))
            if m.group(5) == 'renormal':
                fx['renorm'].add(k)
            continue
        m = HTEST.match(ln)
        if m:
            fx['htest'][(int(m.group(1)), int(m.group(3)))] = m.group(5)
            continue
        m = LOCALUSE.match(ln)
        if m:
            fx['uses'][(int(m.group(1)), int(m.group(3)))] = m.group(5)
            continue
        m = STANDING.match(ln)
        if m:
            fx['standing'].append((m.group(2), int(m.group(3)), m.group(4)))
            continue
        m = HOMES.match(ln)
        if not m:
            continue
        gi = int(m.group(1))
        name_gi[m.group(2)].add(gi)
        if m.group(3) == 'all':
            nodes[(gi, int(m.group(4)))] = (m.group(5), m.group(6), int(m.group(7)), int(m.group(8)) if m.group(8) else -1, m.group(9) or '-')
        else:
            locs[(gi, m.group(4))] = (m.group(6), int(m.group(7)))
    for (name, ai), c in named.items():
        for gi in name_gi.get(name, ()):
            fx['retains'][(gi, ai)] = max(c, fx['retains'].get((gi, ai), 0))
    if nodes and ri is None:
        print('BB_PLACEMENT REFUSE: the plan dump of %s carries no retains_code column -- ./scrip is older than the planner\'s one retains table (CEO-1949: a retaining edge is planner_retains above 0, nothing else)' % src)
        sys.exit(2)
    return nodes, locs, fx


def asm_bases(path):
    c = collections.Counter()
    for ln in open(path, encoding='utf-8', errors='replace'):
        s = ln.split('#')[0]
        if not s.strip() or s.lstrip().startswith('.'):
            continue
        for m in MEM.finditer(s):
            b = m.group(1)
            c['rsp' if b == 'rsp' else 'rbp' if b == 'rbp' else 'rip' if b == 'rip' else 'r12' if b == 'r12' else 'r13' if b == 'r13' else 'other' if b[0] == 'r' else 'abs'] += 1
    return c


LABEL = re.compile(r'^([^\s#][^\s:]*):')
RSPLOAD =re.compile(r'^(?:mov|lea|xchg|pop|cmov\w+)\s+rsp\s*,\s*(\S.*)$|^pop\s+rsp\s*$|^leave\b')
ADDRSP = re.compile(r'^add\s+rsp\s*,\s*(-?\d+)\s*$')
SUBRSP = re.compile(r'^sub\s+rsp\s*,\s*(-?\d+)\s*$')
JUMP = re.compile(r'^j\w*\s+(\S+)\s*$')
BOXLAB = re.compile(r'^(?:n\d+_([a-z_0-9]+?)_(?:α|β|γ|ω)$|\.L([a-z_0-9]+?)_(?:α|β|γ|ω)_\d+)')


def port_of(lab):
    for ch, nm in (('β', 'beta'), ('ω', 'omega'), ('γ', 'gamma'), ('α', 'alpha')):
        if ch in lab:
            return nm
    return 'none'


def asm_unwind(path, seen_sec):
    """BB_UNWIND (CEO-1755) from the emitted code: every rsp load and every failure-edge pop, by the port of the label it sits under.
    retry_restore = an rsp load (mov/lea/xchg/pop rsp, leave) under a box's beta or omega label or a redo entry; discard_restore = the same
    under a FENCE, ARBNO, cut or statement label (CEO-1759: a discard may drop rsp to a saved depth); multi_pop = a jump to a beta label preceded
    in its straight line by more than one add rsp, or by one that differs from the box's own carve (sub rsp at its alpha).  Graph exits
    (the procedure's own gamma/omega label), alpha and gamma roads, the gc site and the program's startup are counted apart by class."""
    c = collections.Counter()
    secs, cur = [], []
    for ln in open(path, encoding='utf-8', errors='replace'):
        if '.type' in ln and '@function' in ln and cur:
            secs.append(cur)
            cur = []
        cur.append(ln)
    secs.append(cur)
    for sec in secs:
        key = hashlib.sha1(re.sub(r'\d+', 'N', ''.join(sec)).encode()).hexdigest()
        if key in seen_sec:
            continue
        seen_sec.add(key)
        lab, box, carve, adds = '', '', 0, []
        for ln in sec:
            code = ln.split('#')[0].rstrip('\n')
            m = LABEL.match(code)
            if m:
                lab = m.group(1)
                code = code[m.end():]
                adds = []
                bm = re.match(r'^(n\d+_[a-z_0-9]+?)_(α|β|γ|ω)$', lab)
                if bm:
                    if bm.group(1) != box:
                        box, carve = bm.group(1), 0
            for ins in (x.strip() for x in code.split(';')):
                if not ins or ins.startswith('.'):
                    continue
                ins = re.sub(r'\s+', ' ', ins)
                if RSPLOAD.match(ins):
                    pt = port_of(lab)
                    if lab == 'main' or lab.endswith('_stack_kept'):
                        cls = 'startup'
                    elif lab.startswith('.Lgcsite'):
                        cls = 'gcsite'
                    elif pt in ('beta', 'omega') and BOXLAB.match(lab):
                        cls = 'restore_' + pt
                    elif pt in ('gamma', 'omega'):
                        cls = 'exit_' + pt
                    elif lab.endswith('_res'):
                        cls = 'restore_redo'
                    elif lab.endswith('_altdet'):
                        cls = 'exit_altdet'
                    else:
                        cls = pt
                    bk = BOXLAB.match(lab)
                    if cls.startswith('restore_') and bk and re.match(r'^(match_fence|match_arbno|cut|statement)', bk.group(1) or bk.group(2)):
                        cls = 'discard_' + cls[len('restore_'):]
                    c['rspload:' + cls] += 1
                    if os.environ.get('BB_UNWIND_DIAG') and (cls.startswith('restore_') or cls == os.environ.get('BB_UNWIND_DIAG')):
                        print('[UNWIND] %s %s | %s' % (cls, lab, ins), file=sys.stderr)
                    if cls.startswith('restore_'):
                        c['retry_restore'] += 1
                    elif cls.startswith('discard_'):
                        c['discard_restore'] += 1
                    adds = []
                    continue
                sm = SUBRSP.match(ins)
                if sm and port_of(lab) == 'alpha' and box and carve == 0:
                    carve = int(sm.group(1))
                am = ADDRSP.match(ins)
                if am:
                    adds.append(int(am.group(1)))
                    continue
                jm = JUMP.match(ins)
                if jm:
                    tgt = jm.group(1)
                    if port_of(tgt) == 'beta' and adds and (len(adds) > 1 or adds[0] != carve):
                        tk = re.sub(r'^n\d+_|_β.*$|\d+', '', tgt)
                        c['multipop:' + tk] += 1
                        c['multi_pop'] += 1
                    if ins.startswith('jmp'):
                        adds = []
                    continue
                if not ins.startswith('add') and not ins.startswith('mov qword ptr [rax') and not ins.startswith('mov rax'):
                    adds = []
    return c


def zeta_names(src, lang):
    cwd, base = os.path.dirname(src), os.path.basename(src)
    names, vslots, cur = {}, collections.defaultdict(set), None
    r = run([SCRIP, '--dump-zeta'] + (['--target=x86'] if lang == 'prolog' else []) + [base], cwd)
    for ln in r.stdout.decode('utf-8', 'replace').splitlines():
        m = re.match(r"; graph (\d+) '(.*)' ", ln)
        if m:
            cur = int(m.group(1))
            names[cur] = m.group(2)
            continue
        m = re.match(r';\s+vslot \+\d+\s+\d+\s+\S+\s+(\S+)', ln)
        if m and cur is not None:
            vslots[cur].add(m.group(1))
    return names, vslots


def analyse(lang, src, tmp, seen, seen_sec):
    nodes, locs, fx = homes_of(lang, src, tmp)
    if nodes is None:
        return None
    bases = asm_bases(tmp)
    unwind = asm_unwind(tmp, seen_sec)
    names, vslots = zeta_names(src, lang)
    raw = run([SCRIP, '--dump-bb', os.path.basename(src)], os.path.dirname(src)).stdout
    dump = json.loads(raw.decode('utf-8', 'replace'))
    boxes = {b['id']: b for b in dump['boxes']}
    by = collections.defaultdict(list)
    for i in boxes:
        by[int(i.split('_')[0][1:])].append(i)
    gedges = collections.defaultdict(list)
    for e in dump['edges']:
        if e['from'] in boxes and e['to'] in boxes:
            gedges[int(e['from'].split('_')[0][1:])].append(e)
    gname = {g: names.get(g, 'g%d' % g) for g in by}
    gen_graph, susp_graph, multi, sigs = {}, {}, {}, {}
    for g, ids in by.items():
        ks = {boxes[i]['kind'] for i in ids}
        gen_graph[gname[g]] = bool(ks & GEN_KINDS)
        susp_graph[gname[g]] = 'SUSPEND' in ks
        multi[gname[g]] = sum(1 for i in ids if boxes[i]['kind'] == 'SUCCEED') > 1
        sigs[g] = hashlib.sha1(json.dumps([sorted((boxes[i]['kind'], boxes[i].get('label', '')) for i in ids),
                                           sorted((e['from'].split('_', 1)[1], e.get('fp', ''), e['to'].split('_', 1)[1], e.get('tp', ''), e.get('rel', ''), e.get('slot', ''))
                                                  for e in gedges[g])]).encode()).hexdigest()[:10]

    def bkey(bid):
        return (int(bid.split('_')[0][1:]), int(bid.split('_')[1]))

    out = []
    for g in sorted(by):
        key = (lang, gname[g], sigs[g])
        if key in seen:
            continue
        seen.add(key)
        ids = by[g]
        emitted = any((g, int(i.split('_')[1])) in nodes for i in ids)
        dyn = {i: RETAINS.get(fx['retains'].get((g, int(i.split('_')[1])), 0), 'retains') for i in ids if fx['retains'].get((g, int(i.split('_')[1])), 0) > 0}
        renorm = {i for i in ids if bkey(i) in fx['renorm']}
        succ, succ_value, ops = collections.defaultdict(list), collections.defaultdict(list), []
        for e in gedges[g]:
            if e.get('rel') == 'op':
                if not (lang == 'icon' and boxes[e['from']]['kind'] == 'DISJUNCTION'):
                    ops.append((e['from'], e['to']))
            else:
                succ[e['from']].append(e['to'])
                if e.get('fp') != 'omega':
                    succ_value[e['from']].append(e['to'])
        test = {}
        for (o, p) in ops:
            if p in test:
                continue
            seen_s, st = set(), [(y, p in dyn, dyn.get(p)) for y in succ_value[p]]
            while st:
                x, dirty, why = st.pop()
                if x == p or (x, dirty) in seen_s:
                    continue
                seen_s.add((x, dirty))
                if x == o:
                    if dirty:
                        test[p] = 'operand:' + (why or 'dynamic')
                        break
                    continue
                if x in renorm:
                    dirty, why = False, None
                elif x in dyn:
                    dirty, why = True, dyn[x]
                for y in succ[x]:
                    st.append((y, dirty, why))
        betat = {e['to'] for e in gedges[g] if e.get('tp') == 'beta'}
        cons = collections.defaultdict(list)
        for (o, p) in ops:
            cons[p].append(o)

        def retry_read(p):
            for o in cons[p]:
                fwd, st = set(), list(succ_value[p])
                while st:
                    x = st.pop()
                    if x in fwd or x == p:
                        continue
                    fwd.add(x)
                    if x != o:
                        st.extend(succ_value[x])
                if o not in fwd:
                    continue
                pred = collections.defaultdict(list)
                for x in fwd:
                    for y in succ_value[x]:
                        if y in fwd:
                            pred[y].append(x)
                bk, st = set(), [o]
                while st:
                    x = st.pop()
                    for y in pred[x]:
                        if y not in bk:
                            bk.add(y)
                            st.append(y)
                if any(x in betat for x in bk if x != o):
                    return True
            return False

        tainted, st = {}, []
        for d in dyn:
            for y in succ[d]:
                st.append((y, dyn[d]))
            st.append((d, dyn[d]))
        while st:
            x, why = st.pop()
            if x in tainted or x in renorm:
                continue
            tainted[x] = why
            for y in succ[x]:
                st.append((y, why))
        ltest = {}
        for i in ids:
            lab = fx['uses'].get(bkey(i))
            if lab is None or lab not in vslots.get(g, ()) or lab in ltest:
                continue
            if i in tainted:
                ltest[lab] = 'local:' + tainted[i]
        kinds = [boxes[i]['kind'] for i in ids]
        if lang == 'icon':
            cause = 'icn-generator' if gen_graph[gname[g]] else ('icn-dynamic-rsp' if dyn else 'icn-static-rsp')
        elif lang == 'prolog':
            cause = ('pl-multi-exit' if multi[gname[g]] else 'pl-one-exit') + ('-dynamic-rsp' if dyn else '-static-rsp')
        else:
            cause = lang + ('-dynamic-rsp' if dyn else '-static-rsp')
        cells = []
        for i in ids:
            h = nodes.get((g, int(i.split('_')[1])))
            if h is None:
                continue
            ht = fx['htest'].get((g, int(i.split('_')[1])), '-')
            wit = retry_read(i) if (h[3] != -1 and not test.get(i) and ht == 'operand:pinned-temp') else None
            cells.append(('A', boxes[i]['kind'], h[1], test.get(i), i, h[3], h[4], h[2], ht, None, wit))
        for vn in sorted(vslots.get(g, ())):
            h = locs.get((g, vn))
            if h is None:
                continue
            cells.append(('L', vn, h[0], ltest.get(vn), vn, -1, '-', h[1], '-', None, None))
        out.append({'name': gname[g], 'sig': sigs[g], 'cause': cause, 'emitted': emitted, 'cells': cells, 'n': len(ids)})
    return {'graphs': out, 'bases': bases, 'standing': fx['standing'], 'unwind': unwind}


def state_word_kinds():
    path = os.path.join(HERE, 'state_word_kinds.tsv')
    out = {}
    if not os.path.isfile(path):
        return out
    for ln in open(path, encoding='utf-8'):
        if not ln.strip() or ln.startswith('#'):
            continue
        f = ln.rstrip('\n').split('\t')
        if len(f) < 4:
            print('BB_PLACEMENT REFUSE: state_word_kinds.tsv row %r has fewer than four columns (key, class, template, pattern)' % ln.strip()); sys.exit(2)
        key, cls, tpl, pat = f[0], f[1], f[2], f[3]
        tp = os.path.join(SC, tpl)
        if not os.path.isfile(tp) or pat not in open(tp, encoding='utf-8', errors='replace').read():
            print('BB_PLACEMENT REFUSE: state_word_kinds.tsv row %s cites %s for %r and that template does not carry it (ARCH-ZETA-ONE-COORDINATE section 3.1: a state word is derived from the template, never asserted)' % (key, tpl, pat)); sys.exit(2)
        out[key] = cls
    return out


STATE_WORDS = state_word_kinds()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--files', nargs='*', help='source files to measure instead of the committed-artifact set')
    ap.add_argument('--lang', choices=sorted(set(EXT.values())))
    ap.add_argument('--tsv')
    ap.add_argument('--cells')
    ap.add_argument('--verbose', action='store_true')
    a = ap.parse_args()
    if not os.access(SCRIP, os.X_OK):
        print('BB_PLACEMENT REFUSE: no ./scrip at ' + SCRIP)
        return 2
    progs = [(next((l for e, l in EXT.items() if f.endswith(e)), None), os.path.abspath(f)) for f in a.files] if a.files else discover()
    progs = [p for p in progs if p[0]]
    if a.lang:
        progs = [p for p in progs if p[0] == a.lang]
    langs = sorted({p[0] for p in progs})
    tot = {l: collections.Counter() for l in langs}
    bases = {l: collections.Counter() for l in langs}
    rows, seen, unmeasured = collections.Counter(), set(), []
    cellrows = []
    tests = {l: collections.Counter() for l in langs}
    unw = {l: collections.Counter() for l in langs}
    fhome = {l: collections.Counter() for l in langs}
    stw = collections.defaultdict(collections.Counter)
    hosts = {l: collections.Counter() for l in langs}
    seen_sec = set()
    seen_standing = set()
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, 'p.s')
        for pi, (lang, src) in enumerate(progs):
            print('  [%d/%d] %s %s' % (pi + 1, len(progs), lang, os.path.relpath(src, CORPUS)), file=sys.stderr, flush=True)
            try:
                r = analyse(lang, src, tmp, seen, seen_sec)
            except Exception as ex:
                r = None
                if a.verbose:
                    print('  unmeasured %s: %s' % (src, ex), file=sys.stderr)
            if r is None:
                unmeasured.append(src)
                continue
            bases[lang].update(r['bases'])
            unw[lang].update(r['unwind'])
            for (gname_s, ncell, why) in r['standing']:
                if (lang, gname_s) not in seen_standing:
                    seen_standing.add((lang, gname_s))
                    tests[lang]['standing'] += ncell
                    tests[lang]['why:standing:' + why] += ncell
            t = tot[lang]
            for gr in r['graphs']:
                t['graphs'] += 1
                if not gr['emitted']:
                    t['unemitted'] += gr['n']
                    continue
                for (tb, kind, home, forced, cid, xf, xfwhy, off, ht, res, wit) in gr['cells']:
                    swk = next((k for k in (kind, kind and 'IR_' + kind, cid) if k and k in STATE_WORDS), None)
                    sw = STATE_WORDS.get(swk) if swk else None
                    if sw and xfwhy == sw and home in ('RBP', 'RSP_CARVED', 'SPINE') and (xf != -1 or home != 'SPINE'):
                        stw[lang][(swk, sw)] += 1
                        if not forced:
                            forced = 'state:' + sw
                    t['operands' if tb == 'A' else 'locals'] += 1
                    hs = hosts[lang]
                    if tb == 'A' and home in ('SPINE', 'NONE') and off >= 0 and xf == -1:
                        hs['ops_prealloc'] += 1
                        cellrows.append((lang, home, 'prealloc', 'none', '-', gr['name'] + '@' + gr['sig'], tb, kind, cid))
                    if tb == 'A':
                        hs['ops_rbp' if (home == 'RBP' or (home == 'SPINE' and xf != -1)) else 'ops_rsp' if home == 'SPINE' else 'ops_precarved' if home == 'RSP_CARVED' else 'ops_none'] += 1
                    elif home == 'SPINE':
                        hs['loc_rsp'] += 1
                    elif home in ('RBP', 'RSP_CARVED'):
                        hs['loc_rbp'] += 1
                        hs['loc_rbp_forced' if forced else 'loc_rbp_misplaced'] += 1
                    else:
                        hs['loc_none'] += 1
                    if tb == 'A' and home == 'SPINE':
                        fh = fhome[lang]
                        if xf != -1:
                            fh['homes'] += 1
                            fh[('why', xfwhy, kind)] += 1
                            pinned = not forced and ht == 'operand:pinned-temp' and xfwhy == 'read-across-retaining-edge'
                            ruled = None if forced else ('pinned-temp' if (pinned and wit) else 'retaining-disjunction' if (xfwhy == 'retaining-disjunction' and kind == 'DISJUNCTION') else None)
                            fh['agree' if forced else 'ruled' if ruled else 'home_without_test'] += 1
                            if pinned:
                                fh[('pinned', 'witnessed' if wit else 'unwitnessed')] += 1
                            if ruled:
                                fh[('ruled', ruled, 'witnessed' if wit else 'planner')] += 1
                            elif not forced:
                                fh[('hwt', xfwhy, kind)] += 1
                            cellrows.append((lang, 'SPINE+RBP', 'frame_homed' if forced else 'frame_homed_ruled' if ruled else 'frame_homed_untested', 'operand', xfwhy, gr['name'] + '@' + gr['sig'], tb, kind, cid, ht))
                        elif forced and off >= 0:
                            fh['test_without_home'] += 1
                            fh[('nohome', forced, kind)] += 1
                            cellrows.append((lang, 'SPINE', 'spine_unhomed', 'operand', forced.split(':', 1)[1], gr['name'] + '@' + gr['sig'], tb, kind, cid))
                    if home in ('RBP', 'RSP_CARVED'):
                        tt = tests[lang]
                        ftest, fwhy = forced.split(':', 1) if forced else ('none', '-')
                        cellrows.append((lang, home, ('rbp' if home == 'RBP' else 'carved') + ('_forced' if forced else '_misplaced'), ftest, fwhy, gr['name'] + '@' + gr['sig'], tb, kind,
                                         cid))
                        tt['offspine'] += 1
                        if forced:
                            tt[forced.split(':', 1)[0] + '_test'] += 1
                            tt['why:' + forced] += 1
                        else:
                            tt['other'] += 1
                    if home == 'SPINE':
                        t['spine'] += 1
                    elif home == 'NONE':
                        t['none'] += 1
                    elif home == 'RBP':
                        t['rbp'] += 1
                        st = 'rbp_forced' if forced else 'rbp_misplaced'
                        t[st] += 1
                        if not forced:
                            rows[(lang, st, gr['cause'], tb, gr['name'] + '@' + gr['sig'], kind)] += 1
                    elif home == 'RSP_CARVED':
                        t['rsp_carved'] += 1
                        st = 'carved_forced' if forced else 'carved_misplaced'
                        t[st] += 1
                        if not forced:
                            rows[(lang, st, gr['cause'], tb, gr['name'] + '@' + gr['sig'], kind)] += 1
    for lang in langs:
        if tot[lang]['graphs'] == 0:
            unmeasured.append('<' + lang + ' measured nothing>')
    if unmeasured:
        print('BB_PLACEMENT REFUSE: %d program(s) unmeasured: %s' % (len(unmeasured), ' '.join(os.path.relpath(u, ROOT) if os.path.isabs(u) else u for u in unmeasured[:6])))
        return 2
    gt = collections.Counter()
    for lang in langs:
        t = tot[lang]
        t['misplaced'] = t['rbp_misplaced'] + t['carved_misplaced']
        print('BB_PLACEMENT %s graphs=%d operands=%d locals=%d spine=%d rsp_carved=%d rbp=%d none=%d rbp_forced=%d rbp_misplaced=%d carved_forced=%d carved_misplaced=%d misplaced=%d unemitted=%d' %
              (lang, t['graphs'], t['operands'], t['locals'], t['spine'], t['rsp_carved'], t['rbp'], t['none'], t['rbp_forced'], t['rbp_misplaced'], t['carved_forced'],
               t['carved_misplaced'], t['misplaced'], t['unemitted']))
        for k in ('operands', 'locals', 'spine', 'rbp_misplaced', 'carved_misplaced', 'misplaced'):
            gt[k] += t[k]
    print('BB_PLACEMENT total operands=%d locals=%d spine=%d rbp_misplaced=%d carved_misplaced=%d misplaced=%d' %
          (gt['operands'], gt['locals'], gt['spine'], gt['rbp_misplaced'], gt['carved_misplaced'], gt['misplaced']))
    tg = collections.Counter()
    for lang in langs:
        tt = tests[lang]
        print('BB_PLACEMENT_TESTS %s offspine=%d operand_test=%d local_test=%d standing=%d other=%d' % (lang, tt['offspine'], tt['operand_test'], tt['local_test'], tt['standing'], tt['other']))
        for k in ('offspine', 'operand_test', 'local_test', 'standing', 'other'):
            tg[k] += tt[k]
        for k, v in sorted(tt.items()):
            if k.startswith('why:'):
                print('BB_PLACEMENT_TESTS_WHY %s %s count=%d' % (lang, k[4:], v))
    for lang in langs:
        hs = hosts[lang]
        print('BB_HOSTS %s ops_rsp=%d ops_rbp=%d ops_precarved=%d ops_none=%d loc_rsp=%d loc_rbp=%d loc_rbp_forced=%d loc_rbp_misplaced=%d loc_none=%d ops_prealloc=%d' %
              (lang, hs['ops_rsp'], hs['ops_rbp'], hs['ops_precarved'], hs['ops_none'], hs['loc_rsp'], hs['loc_rbp'], hs['loc_rbp_forced'], hs['loc_rbp_misplaced'], hs['loc_none'],
               hs['ops_prealloc']))
    for lang in langs:
        fh = fhome[lang]
        print('BB_PLACEMENT_FRAMEHOME %s homes=%d agree=%d home_without_test=%d test_without_home=%d ruled=%d' % (lang, fh['homes'], fh['agree'], fh['home_without_test'], fh['test_without_home'], fh['ruled']))
        for k, v in sorted((k, v) for k, v in fh.items() if isinstance(k, tuple) and k[0] == 'ruled'):
            print('BB_PLACEMENT_FRAMEHOME_RULED %s class=%s %s count=%d' % (lang, k[1], k[2], v))
        if fh[('pinned', 'witnessed')] or fh[('pinned', 'unwitnessed')]:
            print('BB_PLACEMENT_FRAMEHOME_PINNED %s witnessed=%d unwitnessed=%d' % (lang, fh[('pinned', 'witnessed')], fh[('pinned', 'unwitnessed')]))
        for k, v in sorted(stw[lang].items(), key=lambda kv: -kv[1]):
            print('BB_PLACEMENT_STATE %s key=%s class=%s count=%d' % (lang, k[0], k[1], v))
        for k, v in sorted(((k, v) for k, v in fh.items() if isinstance(k, tuple) and len(k) == 3 and k[0] in ('why', 'hwt', 'nohome')), key=lambda kv: -kv[1]):
            print('BB_PLACEMENT_FRAMEHOME_WHY %s %s:%s kind=%s count=%d' % (lang, k[0], k[1], k[2], v))
    print('BB_PLACEMENT_TESTS total offspine=%d operand_test=%d local_test=%d standing=%d other=%d' % (tg['offspine'], tg['operand_test'], tg['local_test'], tg['standing'], tg['other']))
    ug = collections.Counter()
    for lang in langs:
        u = unw[lang]
        print('BB_UNWIND %s rsp_loads=%d retry_restore=%d discard_restore=%d multi_pop=%d' % (lang, sum(v for k, v in u.items() if k.startswith('rspload:')), u['retry_restore'], u['discard_restore'], u['multi_pop']))
        for k, v in sorted(u.items()):
            if k.startswith('rspload:'):
                print('BB_UNWIND_RSPLOAD %s %s count=%d' % (lang, k[8:], v))
            if k.startswith('multipop:'):
                print('BB_UNWIND_MULTIPOP %s into=%s count=%d' % (lang, k[9:], v))
        for k in ('retry_restore', 'discard_restore', 'multi_pop'):
            ug[k] += u[k]
        ug['rsp_loads'] += sum(v for k, v in u.items() if k.startswith('rspload:'))
    print('BB_UNWIND total rsp_loads=%d retry_restore=%d discard_restore=%d multi_pop=%d' % (ug['rsp_loads'], ug['retry_restore'], ug['discard_restore'], ug['multi_pop']))
    for lang in langs:
        b = bases[lang]
        n = sum(b.values())
        print('BB_PLACEMENT_ASM %s mem_operands=%d rsp=%d rbp=%d rip=%d r12=%d r13=%d other=%d abs=%d' % (lang, n, b['rsp'], b['rbp'], b['rip'], b['r12'], b['r13'], b['other'], b['abs']))
    cls = collections.Counter()
    for k, n in rows.items():
        cls[(k[0], k[1] + ':' + k[2], k[3], k[5])] += n
    for (l, c, tb, kind), n in sorted(cls.items(), key=lambda x: -x[1])[:40]:
        print('BB_PLACEMENT_CLASS %s %s %s %s count=%d' % (l, c, tb, kind, n))
    if a.tsv:
        with open(a.tsv, 'w') as fh:
            for k in sorted(rows):
                fh.write('\t'.join(list(k) + [str(rows[k])]) + '\n')
    if a.cells:
        with open(a.cells, 'w') as fh:
            for r in cellrows:
                fh.write('\t'.join(r) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
