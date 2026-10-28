#!/usr/bin/env python3
"""util_inf_snobol4_coverage_census.py -- WHAT THE RANDOM GENERATOR AND THE EXHAUSTIVE ENUMERATOR REACH, measured against COVERAGE.tsv.

usage: util_inf_snobol4_coverage_census.py [--scope N] [--seeds K] [--size M] [--family F] [--step S --need H] [--tsv OUT] [--out DIR]

THE VOCABULARY is corpus/demos/scriptix/infinite_snobol4/COVERAGE.tsv (the cto, CEO-1999; one row per construct of the SPITBOL manual v3.7,
with the regex that recognises it on a generated test line, the instrument that is to reach it and the DESIGN-PLAN step that adds it).
THE MEASUREMENT: the generator (the Icon section of infinite_snobol4.md, built through util_inf_snobol4_differential.build_generator) writes a
spread of batches at --scope N -- every walk, kind and preset the driver draws from, --seeds seeds each -- and each row's regex is counted over
the TEST lines of those batches (a preset line, which carries ' = ' at its top level, is skipped unless the row's note says the row reads preset
lines). The enumerator rows are counted over util_program_enumerator.py's own shapes to length 5 over its default alphabet. A row whose regex is
the empty match ($^) is a PROBE: engine_arm reads the enumerator's --help for --engine, every_match_walk reads the driver's --help for --pin,
recursive_pattern reads the preset lines for a pattern that names itself through *.
THE VERDICT: with --step S, only the rows of step S are graded: GREEN (rc 0) when every one of them reads at least --need hits, RED (rc 1)
otherwise; without --step the census prints every family and exits 0. rc 2 when it cannot measure (no icont, no generator, the generator
refuses the scope word: 'bad option scope=N' is the measured state of a step that has not landed).
--scope 0 passes no scope word, so it measures today's grammar on any generator; --scope N (N > 0) passes scope=N, which the generator takes
once DESIGN-PLAN step 1 lands (ARCH-RANDOM-SNOBOL4-GENERATOR.md).
"""
import argparse, csv, hashlib, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
INF = os.path.join(ROOT, 'corpus', 'demos', 'scriptix', 'infinite_snobol4')
VOCAB = os.path.join(INF, 'COVERAGE.tsv')
sys.path.insert(0, HERE)
import util_inf_snobol4_differential as drv

def refuse(why):
    sys.stderr.write('REFUSE(2): ' + why + '\n')
    sys.exit(2)

SPREAD = [  # the walks, kinds and presets the driver's options() draws from, one configuration each
    dict(preset='3', kind='match', walk='random', limit='12'),
    dict(preset='3', kind='expr', walk='random', limit='12'),
    dict(preset='1', kind='expr', walk='random', limit='12'),
    dict(preset='2', kind='match', walk='random', limit='12'),
    dict(preset='1', kind='both', walk='every', elimit='2', plimit='2', climit='1'),
    dict(preset='3', kind='match', walk='every', elimit='1', plimit='2', climit='1'),
]

def read_vocab():
    rows = []
    with open(VOCAB, encoding='utf-8') as f:
        for ln in f:
            if ln.startswith('#') or not ln.strip():
                continue
            rows.append(ln.rstrip('\n').split('\t'))
    head, rows = rows[0], rows[1:]
    return [dict(zip(head, r)) for r in rows]

def is_preset(line):
    depth = 0
    for i, ch in enumerate(line):
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        elif ch == '=' and depth == 1 and line[i - 1:i] == ' ' and line[i + 1:i + 2] == ' ' and line.startswith('('):
            return True
    return False

def generate(gen, out, scope, seeds, size):
    tests, presets = [], []
    for ci, cfg in enumerate(SPREAD):
        for s in range(seeds):
            seed = int(hashlib.md5(('census:%d:%d' % (ci, s)).encode()).hexdigest()[:6], 16) % 999983 + 1
            name = os.path.join(out, 'census_%d_%d.txt' % (ci, s))
            args = ['%s=%s' % kv for kv in cfg.items()] + ['seed=%d' % seed, 'count=%d' % (size * 4), 'size=%d' % size, 'out=' + name]
            if scope > 0:
                args.append('scope=%d' % scope)
            r = subprocess.run([gen] + args, capture_output=True, text=True, timeout=300, cwd=out, env=dict(os.environ, COEXPSIZE='100000'))
            if 'bad option' in (r.stdout + r.stderr):
                refuse('the generator refuses scope=%d (DESIGN-PLAN step 1 has not landed): %s' % (scope, (r.stdout + r.stderr).strip()[:120]))
            if not os.path.exists(name):
                refuse('the generator wrote no batch for %s: %s' % (cfg, (r.stdout + r.stderr).strip()[:200]))
            if r.returncode != 0:
                refuse('the generator died rc=%d for %s, so its batch is partial: %s' % (r.returncode, cfg, (r.stdout + r.stderr).strip()[-200:]))
            for ln in open(name, encoding='latin-1').read().split('\n'):
                if not ln.strip():
                    continue
                (presets if is_preset(ln) else tests).append(ln)
    return tests, presets

def enumerator_lines():
    import util_program_enumerator as en
    import random
    rnd = random.Random(1)
    lines = []
    for n in range(1, 6):
        for sh in en.shapes('term', n):
            lines.extend(en.instantiate(sh, ['x', 'y', 'z', '0', '1', '2'], 8, rnd))
    return lines

def probe(row, presets, enum_help, drv_help):
    c = row['construct']
    if c == 'engine_arm':
        return 1 if '--engine' in enum_help else 0
    if c == 'every_match_walk':
        return 1 if '--pin' in drv_help else 0
    if c == 'recursive_pattern':
        return sum(1 for p in presets if re.match(r'^\(([a-z]) = .*\*\1\b', p))
    return 0

def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--scope', type=int, default=0)
    ap.add_argument('--seeds', type=int, default=2)
    ap.add_argument('--size', type=int, default=300)
    ap.add_argument('--family', default='')
    ap.add_argument('--step', type=int, default=None)
    ap.add_argument('--need', type=int, default=20)
    ap.add_argument('--tsv', default='')
    ap.add_argument('--out', default=os.path.join(ROOT, '.scratch', 'inf_snobol4', 'census'))
    a = ap.parse_args()
    if not os.path.isfile(VOCAB):
        refuse('no vocabulary at ' + VOCAB)
    if not os.access(drv.ICONT, os.X_OK):
        refuse('icont is missing at ' + drv.ICONT)
    rows = read_vocab()
    os.makedirs(a.out, exist_ok=True)
    gen = drv.build_generator(a.out)
    tests, presets = generate(gen, a.out, a.scope, a.seeds, a.size)
    enum_lines = enumerator_lines()
    enum_help = subprocess.run([sys.executable, os.path.join(HERE, 'util_program_enumerator.py'), '--help'], capture_output=True, text=True).stdout
    drv_help = subprocess.run([sys.executable, os.path.join(HERE, 'util_inf_snobol4_differential.py'), '--help'], capture_output=True, text=True).stdout
    results = []
    for row in rows:
        if a.family and row['family'] != a.family:
            continue
        if a.step is not None and int(row['step']) != a.step:
            continue
        rx = row['regex']
        if rx == '$^':
            hits = probe(row, presets, enum_help, drv_help)
        else:
            pat = re.compile(rx)
            pool = enum_lines if row['instrument'] == 'enum' else (presets if 'preset line' in row['note'] else tests)
            hits = sum(1 for ln in pool if pat.search(ln))
        results.append((row, hits))
    print('=== COVERAGE CENSUS scope=%d seeds=%d size=%d test_lines=%d preset_lines=%d enumerator_lines=%d ===' % (a.scope, a.seeds, a.size, len(tests), len(presets), len(enum_lines)))
    print('%-20s %-28s %-5s %6s  %s' % ('family', 'construct', 'inst', 'hits', 'status'))
    fam_tot = {}
    red = 0
    for row, hits in results:
        step = int(row['step'])
        if step == -1:
            status = 'NEVER: ' + row['note'].split(':', 1)[-1].strip()[:60]
        elif hits > 0:
            status = 'REACHED' if step == 0 else 'REACHED (planned step %d)' % step
        else:
            status = 'UNREACHED (step %d)' % step if step > 0 else 'UNREACHED (step 0 reads it reached: re-measure the regex)'
        if a.step is not None and hits < a.need:
            red += 1
            status += '  RED < need %d' % a.need
        print('%-20s %-28s %-5s %6d  %s' % (row['family'], row['construct'], row['instrument'], hits, status))
        t = fam_tot.setdefault(row['family'], [0, 0, 0])
        t[0] += 1
        if step == -1:
            t[2] += 1
        elif hits > 0:
            t[1] += 1
    print('--- per family: rows reached never ---')
    for fam, (n, r, nv) in fam_tot.items():
        print('%-20s %3d %3d %3d' % (fam, n, r, nv))
    tot = sum(v[0] for v in fam_tot.values()); rea = sum(v[1] for v in fam_tot.values()); nev = sum(v[2] for v in fam_tot.values())
    print('TOTAL rows=%d reached=%d never=%d unreached=%d' % (tot, rea, nev, tot - rea - nev))
    if a.tsv:
        with open(a.tsv, 'w') as f:
            f.write('family\tconstruct\tinstrument\tstep\thits\n')
            for row, hits in results:
                f.write('%s\t%s\t%s\t%s\t%d\n' % (row['family'], row['construct'], row['instrument'], row['step'], hits))
    if a.step is not None:
        print('STEP %d coverage: %s (%d rows, %d below need %d)' % (a.step, 'GREEN' if red == 0 else 'RED', len(results), red, a.need))
        return 1 if red else 0
    return 0

if __name__ == '__main__':
    sys.exit(main())
