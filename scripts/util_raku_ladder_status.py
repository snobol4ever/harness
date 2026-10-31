#!/usr/bin/env python3
"""util_raku_ladder_status.py -- THE RAKU LADDER INSTRUMENT (.github/ARCH-RAKU-TO-100.md section 9; row
raku-ladder-step-0-the-ladder-instrument-util-raku-ladder-status-reads-the-rungs-and-replaces-the-map-ceo-2044). A READ: it runs no program.

READS  corpus/tests/raku/config/LADDER.tsv (every declared rung, its construct and family), corpus/tests/raku/ALL.csv (the RakRungs master:
       a rung's FORMS are its ladder__rungNNN_* entries), corpus/tests/raku/config/ROAST-RUNG-MAP.tsv (every red Roast program's first-block
       and unblock rung) and /home/resources/progress/results.tsv (the latest reading per program and mode). A reading stamped on a -dirty
       SCRIP tree measures no tree on origin and is UNREAD here (CEO-2060).
A RUNG is GREEN when it has at least one form and every form reads PASS in m3 AND m4 at its latest reading; a rung with no form yet is RED
       by definition (the work list). A program STANDS PASS when its latest Roast reading is PASS in both modes.

  --family F01,F02   per rung of the named families: GREEN or RED with its first red form, then each program first-blocked there and its
                     standing now (m3 and m4). Without --family only the summary prints.
  --green            exit 0 only when every declared rung of the named families is GREEN (else 1); needs --family.
  --count            ROAST_COUNT: Roast PASS of the denominator, read through util_score_row.py from-progress --dry-run (the one reader
                     of the row's rule: both modes, EXCLUDED out); rc 2 when that reader cannot say.
  --replace          rewrite ROAST-RUNG-MAP.tsv's first-block column (and its basis and construct) for every program whose first rung
                     is GREEN: the lowest RED rung among its features by the generator's own data (util_raku_ladder_design.placement_data);
                     a program with no feature row moves to the next RED rung of its first rung's family; a program whose rungs are all
                     GREEN goes to its unblock rung with basis all-green:form-owed (it gains a form there). The unblock column never moves.
Every run prints LADDER_SUMMARY (all declared rungs by family) and exits 0 unless --green or --count says otherwise.
"""
import argparse, csv, importlib.util, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LADDER = os.path.join(ROOT, 'corpus/tests/raku/config/LADDER.tsv')
MAP = os.path.join(ROOT, 'corpus/tests/raku/config/ROAST-RUNG-MAP.tsv')
MASTER = os.path.join(ROOT, 'corpus/tests/raku/ALL.csv')
RESULTS = os.environ.get('S4E_LADDER_RESULTS', '/home/resources/progress/results.tsv')
RUNGS_SUITE, ROAST_SUITE = 'raku-rungs', 'roast'


def refuse(msg):
    print('REFUSE(2): ' + msg)
    sys.exit(2)


def rung_num(r):
    return int(r[4:])


def load_ladder():
    rungs = []
    for line in open(LADDER, encoding='utf-8'):
        if line.startswith('#') or not re.match(r'^rung\d+\t', line):
            continue
        f = line.rstrip('\n').split('\t')
        if len(f) < 7:
            refuse('LADDER.tsv row has %d columns: %s' % (len(f), f[0]))
        fm = re.search(r'family (F\d\d)', f[2])
        cm = re.search(r'roast construct (\S+) \(', f[2])
        rungs.append({'rung': f[0], 'n': rung_num(f[0]), 'slug': f[1], 'status': f[6], 'family': fm.group(1) if fm else 'F00',
                      'construct': cm.group(1) if cm else f[1]})
    if not rungs:
        refuse('no rung read from ' + LADDER)
    return rungs


def load_forms():
    forms = {}
    with open(MASTER, encoding='utf-8', newline='') as fh:
        for row in csv.DictReader(fh):
            m = re.match(r'^ladder__(rung\d+)_', row.get('entry', ''))
            if m:
                forms.setdefault(m.group(1), []).append(row['entry'])
    return forms


def load_readings():
    if not os.path.exists(RESULTS):
        refuse('no progress table at ' + RESULTS)
    latest = {}
    with open(RESULTS, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            f = line.rstrip('\n').split('\t')
            if len(f) < 10 or f[5] not in (RUNGS_SUITE, ROAST_SUITE):
                continue
            key = (f[5], f[7], f[8])
            if key not in latest or f[0] >= latest[key][0]:
                latest[key] = (f[0], f[1], f[9])
    return latest


def verdict(latest, suite, prog, mode):
    r = latest.get((suite, prog, mode))
    if r is None:
        return 'UNREAD'
    if r[1].endswith('-dirty'):
        return 'UNREAD-dirty'
    return r[2]


def rung_state(rung, forms, latest):
    fs = forms.get(rung['rung'], [])
    if not fs:
        return 'RED', 'NO-FORM'
    for e in fs:
        m3, m4 = verdict(latest, RUNGS_SUITE, e, 'm3'), verdict(latest, RUNGS_SUITE, e, 'm4')
        if m3 != 'PASS' or m4 != 'PASS':
            return 'RED', '%s m3=%s m4=%s' % (e, m3, m4)
    return 'GREEN', '%d forms' % len(fs)


def load_map():
    head, rows = [], []
    for line in open(MAP, encoding='utf-8'):
        if line.startswith('#'):
            head.append(line)
            continue
        f = line.rstrip('\n').split('\t')
        if len(f) != 6:
            refuse('ROAST-RUNG-MAP.tsv row has %d columns: %s' % (len(f), f[0]))
        rows.append(f)
    return head, rows


def roast_count():
    sr = os.path.join(HERE, 'util_score_row.py')
    p = subprocess.run([sys.executable, sr, 'from-progress', '--suite', ROAST_SUITE, '--dry-run'], capture_output=True, text=True,
                       cwd=os.path.join(ROOT, 'SCRIP'))
    m = re.search(r'would set roast -> (\d+)/(\d+)(?: excluded=(\d+))? stamped ([0-9a-f]+(?:-dirty)?)', p.stdout + p.stderr)
    if not m:
        print('ROAST_COUNT REFUSE(2): util_score_row.py from-progress --suite roast --dry-run rc=%d said no row' % p.returncode)
        return 2
    print('ROAST_COUNT pass=%s denominator=%s excluded=%s tree=%s (util_score_row.py from-progress, both modes)'
          % (m.group(1), m.group(2), m.group(3) or '0', m.group(4)))
    return 0


def load_generator():
    spec = importlib.util.spec_from_file_location('util_raku_ladder_design', os.path.join(HERE, 'util_raku_ladder_design.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def replace(rungs, state, head, rows):
    gen = load_generator()
    red, prog_cons, override, fam_of, files_of, norm = gen.placement_data()
    by_construct = {r['construct']: r for r in rungs}
    by_n = {r['n']: r for r in rungs}
    moved = 0
    out = []
    for f in rows:
        prog, first, unblock, outcome, basis, cons = f
        fr = by_n.get(rung_num(first))
        if fr is None:
            refuse('%s sits on %s, which LADDER.tsv does not declare' % (prog, first))
        if state[fr['rung']][0] != 'GREEN':
            out.append(f)
            continue
        feats = sorted(by_construct[c]['n'] for c in prog_cons.get(prog, ()) if c in by_construct)
        if feats:
            reds = [n for n in feats if state[by_n[n]['rung']][0] != 'GREEN']
            new_basis = 'next-red:tests'
        else:
            reds = [r['n'] for r in rungs if r['family'] == fr['family'] and r['n'] > fr['n'] and state[r['rung']][0] != 'GREEN']
            new_basis = 'next-red:chapter'
        if reds:
            nr = by_n[reds[0]]
        else:
            nr = by_n[rung_num(unblock)]
            new_basis = 'all-green:form-owed'
        nf = [prog, 'rung%03d' % nr['n'], unblock, outcome, new_basis, nr['construct']]
        if nf != f:
            moved += 1
            print('REPLACED %s %s -> %s (%s)' % (prog, first, nf[1], new_basis))
        out.append(nf)
    with open(MAP, 'w', encoding='utf-8') as fh:
        fh.writelines(head)
        for f in out:
            fh.write('\t'.join(f) + '\n')
    print('REPLACE moved=%d of %d programs' % (moved, len(rows)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--family', default='')
    ap.add_argument('--green', action='store_true')
    ap.add_argument('--count', action='store_true')
    ap.add_argument('--replace', action='store_true')
    a = ap.parse_args()
    fams = [x.strip() for x in a.family.split(',') if x.strip()]
    if a.green and not fams:
        refuse('--green needs --family')
    for p in (LADDER, MAP, MASTER):
        if not os.path.exists(p):
            refuse('missing ' + p)
    rungs = load_ladder()
    known = {r['family'] for r in rungs}
    bad = [x for x in fams if x not in known]
    if bad:
        refuse('no declared rung in family %s (families: %s)' % (','.join(bad), ' '.join(sorted(known))))
    forms, latest = load_forms(), load_readings()
    state = {r['rung']: rung_state(r, forms, latest) for r in rungs}
    head, rows = load_map()
    blocked = {}
    for f in rows:
        blocked.setdefault(rung_num(f[1]), []).append(f[0])
    for fam in fams:
        for r in (x for x in rungs if x['family'] == fam):
            st, why = state[r['rung']]
            progs = blocked.get(r['n'], [])
            print('%s %s %s %s %s first_blocked=%d' % (r['rung'], st, r['family'], r['construct'], ('first_red=' + why) if st == 'RED' else why, len(progs)))
            for p in progs:
                m3, m4 = verdict(latest, ROAST_SUITE, p, 'm3'), verdict(latest, ROAST_SUITE, p, 'm4')
                print('    %s %s m3=%s m4=%s' % ('PASS' if m3 == m4 == 'PASS' else 'RED ', p, m3, m4))
    by_fam = {}
    for r in rungs:
        g = by_fam.setdefault(r['family'], [0, 0, 0])
        g[0] += 1
        g[1] += state[r['rung']][0] == 'GREEN'
        g[2] += state[r['rung']][1] == 'NO-FORM'
    tot = [sum(v[i] for v in by_fam.values()) for i in range(3)]
    print('LADDER_SUMMARY rungs=%d green=%d red=%d no_form=%d mapped_programs=%d ' % (tot[0], tot[1], tot[0] - tot[1], tot[2], len(rows))
          + ' '.join('%s=%d/%d' % (k, v[1], v[0]) for k, v in sorted(by_fam.items())) + ' (F00 = rung00..rung20, the BUILT ladder)')
    rc = 0
    if a.replace:
        replace(rungs, state, head, rows)
    if a.count:
        rc = max(rc, roast_count())
    if a.green:
        sel = [r for r in rungs if r['family'] in fams]
        ng = sum(state[r['rung']][0] == 'GREEN' for r in sel)
        print('LADDER_GREEN families=%s green=%d of %d -> %s' % (','.join(fams), ng, len(sel), 'GREEN' if ng == len(sel) else 'RED'))
        if rc == 0 and ng != len(sel):
            rc = 1
    sys.exit(rc)


if __name__ == '__main__':
    main()
