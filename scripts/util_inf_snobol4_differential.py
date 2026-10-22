#!/usr/bin/env python3
"""util_inf_snobol4_differential.py -- the infinite_snobol4 generator run offline against an engine, one reproducible batch at a time.

usage: util_inf_snobol4_differential.py --engine dotnet|jvm|scrip BATCH [BATCH ...] [--size 300] [--seed0 20261022] [--out DIR]
       BATCH is a number or a range A-B; util_inf_snobol4_differential.py --engine dotnet 1-20 runs batches 1 to 20.

Lon 2026-10-22, in-chat to hq_dotnet, verbatim: "Go resurrect the random SNOBOL4 source generator we used a few weeks ago to test SCRIP. Find
snobol4dotnet bugs using that technique. Keep changing things around a bit to get variance." · "That random source generator was written in
Icon." · "For every class of program that fails, add a program to SnoRungs test suite to capture future regressions." The ceo (CEO-1915): any
seat reruns batch N, a fixed seed per batch, the batch's verdict line.

THE GENERATOR IS ONE SOURCE: the Icon section of corpus/demos/scriptix/infinite_snobol4/infinite_snobol4.md (the SCRIPtix program; its
README says how it was grown), extracted here at run time between its ```Icon fence and the next ```, with OFFLINE_MAIN below appended (the
SCRIPtix program's drive() is called by its Snocone section; offline, main() reads the same key=value options and writes the batch file).
icont builds it once per text into DIR. THE EVALUATOR is inf_eval.sno beside it: one test per input line, EVAL under SETEXIT, one result
line out. A batch is the preset lines and then --size tests; the oracle (sbl -bf, the correctness accessor's binary) and the engine (its
harness runner: run_snobol4dotnet.sh, run_snobol4jvm.sh, or the root's SCRIP with --stlimit) each run inf_eval.sno on it, and the result
streams are compared line for line.

THE VARIANCE IS A FUNCTION OF (seed0, N): batch N draws its generator seed, token limit, walk, kind, preset and the every-walk limits
from random.Random('seed0:N'), so batch N is the same batch on every seat and every day, and consecutive batches differ.

OUTPUT: DIR/batch_N.txt (the batch's input lines), DIR/batch_N.diff (each differing line: the test, the oracle's line, the engine's line),
and one verdict line per batch on stdout:
    batch N seed=S preset=P kind=K walk=W limit=L: lines=n differ=d oracle_rc=r engine_rc=r
then a total line. rc 0 when no batch differs, 1 when one does, 2 when it cannot measure (no generator, no oracle, no engine).
A shape that hangs both engines is the language, not a defect: it goes into inf_exclude.tsv beside the generator, and into
inf_exclusions() in the Icon section, with its reason and measurement.
"""
import argparse, hashlib, os, random, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
INF = os.path.join(ROOT, 'corpus', 'demos', 'scriptix', 'infinite_snobol4')
ICONT = '/home/resources/icon-master/bin/icont'
SBL = '/home/resources/x64/bin/sbl'

def refuse(why):
    sys.stderr.write('REFUSE(2): ' + why + '\n')
    sys.exit(2)

OFFLINE_MAIN = r'''
# main for the offline comparison (util_inf_snobol4_differential.py): the SCRIPtix program's key=value options, plus out=FILE and size=M;
# writes one batch file, the preset lines and then M tests, and prints its line count
procedure main(args)
    local a, k, v, name, size;
    inf_defaults();
    name := "batch.txt"; size := 100;
    every a := !args do {
        a ? { k := tab(find("=")); move(1); v := tab(0) } | stop("not key=value: ", a);
        if k == "out" then name := v
        else if k == "size" then size := integer(v)
        else inf_opt(k, v) | stop("bad option ", a);
        };
    write(inf_batch(size, name) | 0);
end
'''

def icon_section():
    lines, on = [], False
    for ln in open(os.path.join(INF, 'infinite_snobol4.md'), encoding='latin-1').read().split('\n'):
        if not on:
            on = ln.strip() == '```Icon'
        elif ln.strip() == '```':
            break
        else:
            lines.append(ln)
    return '\n'.join(lines) + '\n' + OFFLINE_MAIN

def build_generator(out):
    text = icon_section()
    exe = os.path.join(out, 'inf_' + hashlib.md5(text.encode('latin-1')).hexdigest()[:12])
    if not os.path.exists(exe):
        src = exe + '.icn'
        open(src, 'w', encoding='latin-1').write(text)
        r = subprocess.run([ICONT, '-s', '-o', exe, src], cwd=out, capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(exe):
            refuse('icont did not build the generator: ' + r.stderr.strip()[-400:])
    return exe

def engine_argv(engine):
    # a port's runner checks its own build (--binaries), so an engine this root does not hold refuses rather than differing on every line
    if engine in ('dotnet', 'jvm'):
        runner = os.path.join(HERE, 'run_snobol4%s.sh' % engine)
        r = subprocess.run(['bash', runner, '--binaries'], capture_output=True, text=True)
        if r.returncode != 0:
            refuse(r.stderr.strip() or runner + ' --binaries refused')
        return ['bash', runner]
    scrip = os.path.join(ROOT, 'SCRIP', 'scrip')
    if not os.path.exists(scrip):
        refuse('no SCRIP beside harness at ' + scrip)
    return [scrip, '--stlimit', '--run']

def options(seed0, n):
    rng = random.Random('%s:%d' % (seed0, n))
    return {'seed': rng.randrange(1, 10 ** 6), 'limit': rng.choice([6, 8, 10, 12, 16, 20]),
            'walk': rng.choice(['random', 'random', 'random', 'every']), 'kind': rng.choice(['match', 'match', 'expr']),
            'preset': rng.choice(['3', '3', '1', '2']), 'elimit': rng.choice([1, 2, 3]), 'plimit': rng.choice([1, 2]),
            'climit': rng.choice([1, 2, 3])}

def run(argv, batch, cwd):
    with open(batch, 'rb') as fin:
        try:
            r = subprocess.run(argv + ['inf_eval.sno'], stdin=fin, capture_output=True, timeout=600, cwd=cwd)
            return r.stdout.decode('latin-1').split('\n'), r.returncode
        except subprocess.TimeoutExpired:
            return ['TIMEOUT'], -1

def batches(specs):
    for s in specs:
        a, _, b = s.partition('-')
        yield from range(int(a), int(b or a) + 1)

def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--engine', required=True, choices=['dotnet', 'jvm', 'scrip'])
    p.add_argument('batch', nargs='+')
    p.add_argument('--size', type=int, default=300)
    p.add_argument('--seed0', default='20261022')
    p.add_argument('--out', default=os.path.join(ROOT, '.scratch', 'inf_snobol4'))
    a = p.parse_args()
    if not (os.access(ICONT, os.X_OK) and os.access(SBL, os.X_OK)):
        refuse('icont or the correctness oracle is missing (%s, %s)' % (ICONT, SBL))
    os.makedirs(a.out, exist_ok=True)
    gen, eng = build_generator(a.out), engine_argv(a.engine)
    total = differ = bad = 0
    for n in batches(a.batch):
        o = options(a.seed0, n)
        batch = os.path.join(a.out, 'batch_%d.txt' % n)
        args = ['%s=%s' % kv for kv in o.items()] + ['count=%d' % (a.size * 4), 'size=%d' % a.size, 'out=' + batch]
        # the generator runs in a co-expression, whose stack Icon sizes from COEXPSIZE; at the default the closed world's recursive
        # expression walk overflows it (run-time error 302) after a few tests, and an expression batch held its preset lines alone
        subprocess.run([gen] + args, capture_output=True, timeout=300, cwd=a.out, env=dict(os.environ, COEXPSIZE='100000'))
        if not os.path.exists(batch):
            refuse('the generator wrote no batch %d' % n)
        tests = [t for t in open(batch, encoding='latin-1').read().split('\n') if t.strip()]
        (s, src), (d, drc) = run([SBL, '-bf'], batch, INF), run(eng, batch, INF)
        at = lambda out, i: out[i] if i < len(out) else '<none>'
        diffs = [i for i in range(len(tests)) if at(s, i) != at(d, i)]
        with open(os.path.join(a.out, 'batch_%d.diff' % n), 'w', encoding='latin-1') as f:
            for i in diffs:
                f.write('line %d\nTEST   %s\nORACLE %s\nENGINE %s\n' % (i + 1, tests[i], at(s, i), at(d, i)))
        total += len(tests); differ += len(diffs); bad += bool(diffs)
        print('batch %d seed=%s preset=%s kind=%s walk=%s limit=%s: lines=%d differ=%d oracle_rc=%d engine_rc=%d'
              % (n, o['seed'], o['preset'], o['kind'], o['walk'], o['limit'], len(tests), len(diffs), src, drc), flush=True)
    print('total %s: lines=%d differ=%d batches_differing=%d' % (a.engine, total, differ, bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
