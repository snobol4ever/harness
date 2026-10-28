#!/usr/bin/env python3
# util_program_enumerator.py -- THE EXHAUSTIVE / RANDOM PROGRAM ENUMERATOR (ceo + Lon, 2026-09-04, row
# exhaustive-program-enumerator-to-length-n-with-oracle-divergences-as-witnesses; GOAL-TEST-SUITE-CONSISTENCY.md point 9).
#
#   python3 ../harness/scripts/util_program_enumerator.py --lang snobol4 --to-length 6 --report          # every program up to 6 tokens
#   python3 ../harness/scripts/util_program_enumerator.py --lang snobol4 --random 2000 --seed 7 --report  # a seeded random walk, same grammar
#   python3 ../harness/scripts/util_program_enumerator.py --selftest                                       # the fail-once arms, no oracle needed
#   python3 harness/scripts/util_program_enumerator.py --engine jvm --to-length 5                          # the same population under a port
#
# THE ENGINE ARM (step 13 of the cto's DESIGN-PLAN random-codegen-scope, ARCH-RANDOM-SNOBOL4-GENERATOR.md; CEO-1999, hq_jvm):
# --engine scrip (the default) runs SCRIP once per --modes entry (m3 interprets, m4 compiles, assembles and links); --engine dotnet|jvm
# runs the batch once through the port's harness runner, run_snobol4<engine>.sh, in the calling shape every port runner shares (the
# bare file name in the program's own folder), after the runner's --binaries check has passed, so a root without that engine, or with a
# stale build of it, refuses rather than reading DIFF on every id. --modes is scrip's alone: a port's one mode is named by the engine.
# The POPULATION line names the engine and its tree, and the witnesses carry the engine in their names (gen_<lang>_<engine>_...).
#
# LINEAGE: harness/adapters/tiny/Expressions.py (Lon, 2026-03-11) -- its grammar is THE grammar here, verbatim:
#   term := factor | factor '+' term | factor '-' term        factor := element | element '*' factor | element '/' factor
#   element := item | '+' element | '-' element               item := x | y | z | INT | '(' term ')'
# and its yield-based enumerator is the idiom; .github/archive/MISC-REORG-GENTEST.md (2026-03-29) is the spec ("every
# syntactically valid program from 0 to N tokens"); ../harness/scripts/util_pattern_fuzz.py (2026-08-20) is the grading precedent
# (oracle is the judge, its exit status checked first; signals are NEGATIVE returncodes; dedup by canonical shape).
#
# WHAT "EVERY PROGRAM" MEANS HERE, MEASURED (the M-G8-DEPTH decision the spec left open): the exhaustive arm enumerates
# every distinct expression SHAPE up to N tokens -- structure, operators, parentheses -- with leaves as placeholders, then
# instantiates each shape over a small leaf alphabet (default x y z 0 1 2). With the full literal alphabet the count at
# 9 tokens is Catalan(4)*4^4*13^5 = 1.3e9 programs; over shapes it is 3,584. The report prints both counts per length.
# A program is one expression: the batch program assigns x y z, sets &ERRLIMIT so a runtime error (division by zero,
# SPITBOL error 014) becomes statement FAILURE, prints "<id>=<value>" or "<id>=E<&ERRTYPE>" per expression, END.
# The oracle (sbl -bf, lib_oracle_flags.sh's correctness oracle) runs the same batch; verdicts per id: AGREE, DIFF,
# CRASH (a signal or rc!=0 with ids missing), HANG (timeout), ORACLE-BAD (the oracle itself gave no line). A batch that
# yields no ids at all is bisected until each offending expression stands alone. Divergences are written as single-
# expression witnesses (<out>/gen_<lang>_<engine>_len<N>_<k>.sno + .ref) deduplicated to the first of each canonical shape.
# rc=0 every graded program AGREE / rc=1 divergences (named) / rc=2 cannot measure (oracle absent, compiler absent, an
# empty population). A report that could not run is never a zero.
import argparse, collections, functools, itertools, os, random, re, subprocess, sys, tempfile
S4E = os.environ.get('S4E_HOME') or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SCRIP_DIR = os.path.join(S4E, 'SCRIP'); SCRIP = os.path.join(SCRIP_DIR, 'scrip'); RT = os.path.join(SCRIP_DIR, 'out')
SBL = '/home/resources/x64/bin/sbl'; SBL_FLAGS = ['-bf']
HERE = os.path.dirname(os.path.abspath(__file__)); PORTS = ('dotnet', 'jvm')
TREES = {'scrip': SCRIP_DIR, 'dotnet': os.path.join(S4E, 'snobol4dotnet'), 'jvm': os.path.join(S4E, 'snobol4jvm')}
def runner(engine): return os.path.join(HERE, 'run_snobol4%s.sh' % engine)
LEAF = 'L'
BIN_TERM = ['+', '-']; BIN_FACTOR = ['*', '/']; UNARY = ['+', '-']
def refuse(msg):
    print('REFUSE (rc=2) [util_program_enumerator]: %s' % msg); sys.exit(2)
@functools.lru_cache(maxsize=None)
def shapes(nt, n):
    """Every string of the nonterminal `nt` with EXACTLY n tokens, leaves as LEAF. Lon's grammar, right-recursive as written."""
    out = []
    if n <= 0: return tuple(out)
    if nt == 'item':
        if n == 1: out.append(LEAF)
        if n >= 3: out += ['(' + t + ')' for t in shapes('term', n - 2)]
    elif nt == 'element':
        out += shapes('item', n)
        if n >= 2: out += [u + e for u in UNARY for e in shapes('element', n - 1)]
    elif nt == 'factor':
        out += shapes('element', n)
        for k in range(1, n - 1):
            for l in shapes('element', k):
                for r in shapes('factor', n - 1 - k):
                    out += [l + ' ' + op + ' ' + r for op in BIN_FACTOR]
    elif nt == 'term':
        out += shapes('factor', n)
        for k in range(1, n - 1):
            for l in shapes('factor', k):
                for r in shapes('term', n - 1 - k):
                    out += [l + ' ' + op + ' ' + r for op in BIN_TERM]
    return tuple(out)
def shape_count(n): return len(shapes('term', n))
def instantiate(shape, alphabet, limit, rnd):
    """Every leaf assignment over `alphabet` when the count is within `limit`, else `limit` seeded samples."""
    k = shape.count(LEAF); total = len(alphabet) ** k
    def fill(assign):
        it = iter(assign); return re.sub(LEAF, lambda m: next(it), shape)
    if total <= limit:
        for assign in itertools.product(alphabet, repeat=k): yield fill(assign)
    else:
        seen = set()
        while len(seen) < limit:
            assign = tuple(rnd.choice(alphabet) for _ in range(k))
            if assign in seen: continue
            seen.add(assign); yield fill(assign)
def random_expr(rnd, depth):
    """Expressions.py's rand_* walk, same weights, bounded by depth so it terminates."""
    def item(d):
        r = rnd.randint(1, 100)
        if r <= 20: return 'x'
        if r <= 40: return 'y'
        if r <= 60: return 'z'
        if r <= 80 or d <= 0: return str(rnd.randint(0, 9))
        return '(' + term(d - 1) + ')'
    def element(d):
        r = rnd.randint(1, 100)
        if r <= 80 or d <= 0: return item(d)
        return ('+' if r <= 90 else '-') + element(d - 1)
    def factor(d):
        r = rnd.randint(1, 100)
        if r <= 70 or d <= 0: return element(d)
        return element(d - 1) + (' * ' if r <= 85 else ' / ') + factor(d - 1)
    def term(d):
        r = rnd.randint(1, 100)
        if r <= 70 or d <= 0: return factor(d)
        return factor(d - 1) + (' + ' if r <= 85 else ' - ') + term(d - 1)
    return term(depth)
def canon(expr):
    s = re.sub(r'\b\d+\b', 'N', expr); s = re.sub(r'\b[xyz]\b', 'V', s); return s
def ntokens(expr): return len(re.findall(r'\(|\)|\d+|[xyz]|[-+*/]', expr))
def nchars(expr): return len(expr.replace(' ', ''))
def program(exprs, env):
    """One SNOBOL4 program printing "<id>=<value>" per expression; a runtime error prints "<id>=E<errtype>" and continues."""
    lines = ['\t&ERRLIMIT = 1000000']
    lines += ['\t%s = %s' % (v, val) for v, val in env]
    for i, e in exprs:
        lines.append('\tOUTPUT = "%d=" (%s)\t:S(N%d)' % (i, e, i))
        lines.append('\tOUTPUT = "%d=E" &ERRTYPE' % i)
        lines.append('N%d' % i)
    lines.append('END'); return '\n'.join(lines) + '\n'
def run(cmd, tmo, cwd=None):
    try:
        p = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=tmo, cwd=cwd)
    except subprocess.TimeoutExpired: return 124, '', 'TIMEOUT'
    return p.returncode, p.stdout, p.stderr
def parse_ids(out):
    res = {}
    for line in out.splitlines():
        m = re.match(r'^(\d+)=(.*)$', line)
        if m: res[int(m.group(1))] = m.group(2)
    return res
def oracle_run(path, tmo):
    rc, out, err = run([SBL] + SBL_FLAGS + [path], tmo); return rc, parse_ids(out)
def scrip_run(mode, path, work, tmo):
    if mode == 'm3':
        rc, out, err = run([SCRIP, path], tmo, cwd=work); return rc, parse_ids(out)
    base = os.path.splitext(os.path.basename(path))[0]
    s = os.path.join(work, base + '.s'); o = os.path.join(work, base + '.o'); b = os.path.join(work, base + '.bin')
    rc, out, err = run([SCRIP, '--compile', '-o', s, path], tmo * 4, cwd=work)
    if rc != 0: return ('COMPILE', rc), {}
    rc, out, err = run(['as', '--64', '-o', o, s], tmo * 4)
    if rc != 0: return ('AS', rc), {}
    rc, out, err = run(['gcc', '-no-pie', '-o', b, o, os.path.join(RT, 'libscrip_rt.so'), '-lm', '-lstdc++', '-Wl,-rpath,' + RT], tmo * 4)
    if rc != 0: return ('LINK', rc), {}
    rc, out, err = run([b], tmo, cwd=work); return rc, parse_ids(out)
def port_run(engine, path, tmo):
    rc, out, err = run(['bash', runner(engine), os.path.basename(path)], tmo, cwd=os.path.dirname(path)); return rc, parse_ids(out)
def engine_run(mode, path, work, tmo):
    """A mode is scrip's m3 or m4, or a port engine's name: the one way that port runs."""
    return port_run(mode, path, tmo) if mode in PORTS else scrip_run(mode, path, work, tmo)
def verdict_of(rc, got, oracle, i):
    if i not in oracle: return 'ORACLE-BAD'
    if i in got: return 'AGREE' if got[i] == oracle[i] else 'DIFF'
    if rc == 124: return 'HANG'
    if isinstance(rc, tuple): return 'CRASH-' + rc[0]
    if rc in (139, -11): return 'CRASH-SEGV'
    if isinstance(rc, int) and rc < 0: return 'CRASH-SIG%d' % (-rc)
    return 'CRASH-rc%s' % rc
class Grader:
    def __init__(self, env, modes, work, tmo):
        self.env = env; self.modes = modes; self.work = work; self.tmo = tmo; self.n_batches = 0
        self.oracle_rows = {}
    def grade(self, exprs, depth=0):
        """exprs: list of (id, expr). Returns {id: {mode: verdict}} plus self.oracle_rows[id] = oracle value."""
        if not exprs: return {}
        self.n_batches += 1
        path = os.path.join(self.work, 'b%05d_%d.sno' % (self.n_batches, depth))
        open(path, 'w').write(program(exprs, self.env))
        orc, oracle = oracle_run(path, self.tmo)
        if not oracle and len(exprs) > 1:
            h = len(exprs) // 2; r = self.grade(exprs[:h], depth + 1); r.update(self.grade(exprs[h:], depth + 1)); return r
        self.oracle_rows.update(oracle)
        res = {i: {} for i, _ in exprs}
        for mode in self.modes:
            rc, got = engine_run(mode, path, self.work, self.tmo)
            missing = [i for i, _ in exprs if i in oracle and i not in got]
            if missing and len(exprs) > 1 and (rc != 0 or not got):
                h = len(exprs) // 2
                sub = self.grade_mode(mode, exprs[:h], depth + 1); sub.update(self.grade_mode(mode, exprs[h:], depth + 1))
                for i in res: res[i][mode] = sub.get(i, 'ORACLE-BAD' if i not in oracle else 'UNGRADED')
                continue
            for i, _ in exprs: res[i][mode] = verdict_of(rc, got, oracle, i)
        return res
    def grade_mode(self, mode, exprs, depth):
        self.n_batches += 1
        path = os.path.join(self.work, 'b%05d_%d%s.sno' % (self.n_batches, depth, mode))
        open(path, 'w').write(program(exprs, self.env))
        oracle = {i: self.oracle_rows[i] for i, _ in exprs if i in self.oracle_rows}
        rc, got = engine_run(mode, path, self.work, self.tmo)
        missing = [i for i, _ in exprs if i in oracle and i not in got]
        if missing and len(exprs) > 1 and (rc != 0 or not got):
            h = len(exprs) // 2; r = self.grade_mode(mode, exprs[:h], depth + 1); r.update(self.grade_mode(mode, exprs[h:], depth + 1)); return r
        return {i: verdict_of(rc, got, oracle, i) for i, _ in exprs}
def write_witness(outdir, lang, engine, length, k, expr, env, oracle_val):
    base = os.path.join(outdir, 'gen_%s_%s_len%02d_%03d' % (lang, engine, length, k))
    open(base + '.sno', 'w').write(program([(1, expr)], env))
    open(base + '.ref', 'w').write('1=%s\n' % oracle_val); return base + '.sno'
def selftest():
    fails = []
    n1 = shape_count(1); n3 = shape_count(3); n2 = shape_count(2)
    if n1 != 1: fails.append('shape_count(1)=%d, expected 1 (the lone leaf)' % n1)
    if n2 != 2: fails.append('shape_count(2)=%d, expected 2 (+L, -L)' % n2)
    if n3 != 1 + 4 + 4: fails.append('shape_count(3)=%d, expected 9: (L), ++L +-L -+L --L, L+L L-L L*L L/L' % n3)
    if len(shapes('term', 0)) != 0: fails.append('an empty budget must enumerate nothing, not a phantom program')
    exprs = [(1, 'x + 1'), (2, 'y * 2'), (3, 'z / 0')]
    src = program(exprs, [('x', 7), ('y', -3), ('z', 2)])
    if src.count('OUTPUT = "') != 2 * len(exprs): fails.append('a batch program must carry exactly two OUTPUT sites per expression (value, error)')
    oracle = {1: '8', 2: '-6', 3: 'E14'}
    good = {1: '8', 2: '-6', 3: 'E14'}; corrupt = {1: '8', 2: '-7', 3: 'E14'}
    if any(verdict_of(0, good, oracle, i) != 'AGREE' for i in oracle): fails.append('identical outputs must read AGREE')
    if verdict_of(0, corrupt, oracle, 2) != 'DIFF': fails.append('a corrupted value must read DIFF, never AGREE')
    if verdict_of(-11, {1: '8'}, oracle, 2) != 'CRASH-SEGV': fails.append('a missing id under SIGSEGV (-11) must read CRASH-SEGV')
    if verdict_of(124, {}, oracle, 1) != 'HANG': fails.append('a timeout must read HANG')
    if verdict_of(0, {1: '8'}, {1: '8'}, 2) != 'ORACLE-BAD': fails.append('an id the oracle never printed must read ORACLE-BAD, never a SCRIP verdict')
    if canon('x + 12 * (y - 3)') != 'V + N * (V - N)': fails.append('canon must fold literals to N and variables to V')
    if ntokens('(x + 12) * -y') != 8: fails.append('ntokens("(x + 12) * -y") must be 8, got %d' % ntokens('(x + 12) * -y'))
    rnd = random.Random(1)
    inst = list(instantiate('L + L', ['x', 'y'], 100, rnd))
    if sorted(inst) != sorted(['x + x', 'x + y', 'y + x', 'y + y']): fails.append('instantiate must produce every leaf assignment when within the limit')
    if len(list(instantiate('L + L + L', ['x', 'y', 'z'], 5, rnd))) != 5: fails.append('instantiate must produce exactly the limit when the assignment count exceeds it')
    for f in fails: print('SELFTEST FAIL: ' + f)
    print('SELFTEST %s: %d checks, %d failures' % ('PASS' if not fails else 'FAIL', 12, len(fails)))
    return 0 if not fails else 1
def main():
    ap = argparse.ArgumentParser(description='exhaustive / random program enumerator graded against the oracle')
    ap.add_argument('--lang', default='snobol4'); ap.add_argument('--to-length', type=int, default=0, help='exhaustive: every shape up to N tokens')
    ap.add_argument('--random', type=int, default=0, help='random: this many seeded programs over the same grammar')
    ap.add_argument('--seed', type=int, default=7); ap.add_argument('--depth', type=int, default=4)
    ap.add_argument('--alphabet', default='x,y,z,0,1,2'); ap.add_argument('--per-shape', type=int, default=64, help='leaf assignments per shape: all when <= this, else this many seeded samples')
    ap.add_argument('--engine', default='scrip', choices=('scrip',) + PORTS, help='scrip (once per --modes entry) or a port through run_snobol4<engine>.sh')
    ap.add_argument('--env', default='x=7,y=-3,z=2'); ap.add_argument('--modes', help='scrip only (default m3,m4)'); ap.add_argument('--batch', type=int, default=400)
    ap.add_argument('--timeout', type=int, default=20)
    ap.add_argument('--out', help='witness folder (default SCRIP/out/enumerator for scrip, <root>/.scratch/enumerator/<engine> for a port)')
    ap.add_argument('--report', action='store_true'); ap.add_argument('--count-only', action='store_true', help='print shape and program counts per length and exit')
    ap.add_argument('--selftest', action='store_true'); ap.add_argument('--keep-batches', action='store_true')
    a = ap.parse_args()
    if a.selftest: sys.exit(selftest())
    if a.lang != 'snobol4': refuse('only the snobol4 grammar exists today (Expressions.py); %s is the next lane\'s rung' % a.lang)
    alphabet = a.alphabet.split(','); rnd = random.Random(a.seed)
    if a.count_only:
        print('length(tokens) shapes programs(alphabet=%s per-shape<=%d)' % (a.alphabet, a.per_shape))
        for n in range(1, (a.to_length or 10) + 1):
            sh = shapes('term', n); progs = sum(min(len(alphabet) ** s.count(LEAF), a.per_shape) for s in sh)
            print('%2d %8d %9d' % (n, len(sh), progs))
        return 0
    if not a.to_length and not a.random: refuse('nothing to enumerate: pass --to-length N and/or --random K')
    if not os.path.exists(SBL): refuse('oracle absent at %s -- every verdict would be a plausible false table' % SBL)
    if a.engine in PORTS:
        if a.modes: refuse('--modes is scrip\'s; the %s engine runs one way, through %s' % (a.engine, os.path.basename(runner(a.engine))))
        r = subprocess.run(['bash', runner(a.engine), '--binaries'], capture_output=True, text=True)
        if r.returncode != 0: refuse(r.stderr.strip() or runner(a.engine) + ' --binaries refused')
        modes = [a.engine]; a.out = a.out or os.path.join(S4E, '.scratch', 'enumerator', a.engine)
    else:
        if not os.path.exists(SCRIP): refuse('compiler absent at %s -- build it first' % SCRIP)
        modes = (a.modes or 'm3,m4').split(','); a.out = a.out or os.path.join(RT, 'enumerator')
    env = [(kv.split('=')[0], kv.split('=')[1]) for kv in a.env.split(',')]
    os.makedirs(a.out, exist_ok=True); work = tempfile.mkdtemp(prefix='enum_', dir=a.out if a.keep_batches else None)
    pop = []
    if a.to_length:
        for n in range(1, a.to_length + 1):
            for sh in shapes('term', n):
                for e in instantiate(sh, alphabet, a.per_shape, rnd): pop.append((n, e))
    if a.random:
        for _ in range(a.random):
            e = random_expr(rnd, a.depth); pop.append((ntokens(e), e))
    if not pop: refuse('the population is empty at --to-length %d --random %d' % (a.to_length, a.random))
    ids = list(enumerate(pop, 1)); grader = Grader(env, modes, work, a.timeout); results = {}
    for start in range(0, len(ids), a.batch):
        chunk = [(i, e) for i, (n, e) in ids[start:start + a.batch]]
        results.update(grader.grade(chunk))
    by_len = collections.defaultdict(lambda: collections.Counter()); witnesses = []; seen = {}; chars = collections.Counter()
    for i, (n, e) in ids:
        chars[nchars(e)] += 1
        for mode in modes:
            v = results.get(i, {}).get(mode, 'UNGRADED'); by_len[n][(mode, v)] += 1
            if v in ('AGREE', 'ORACLE-BAD'): continue
            key = (mode, v, canon(e))
            if key in seen: seen[key] += 1; continue
            seen[key] = 1; k = len(witnesses)
            witnesses.append((mode, v, n, e, write_witness(a.out, a.lang, a.engine, n, k, e, env, grader.oracle_rows.get(i, '?')), grader.oracle_rows.get(i, '?')))
    total = len(ids); graded = sum(1 for i, _ in ids for m in modes if results.get(i, {}).get(m) not in (None, 'UNGRADED', 'ORACLE-BAD'))
    agree = sum(1 for i, _ in ids for m in modes if results.get(i, {}).get(m) == 'AGREE')
    print('=== ENUMERATOR %s: engine=%s to-length=%d random=%d alphabet=%s per-shape<=%d env=%s modes=%s batches=%d ===' % (
        a.lang, a.engine, a.to_length, a.random, a.alphabet, a.per_shape, a.env, ','.join(modes), grader.n_batches))
    print('length(tokens) shapes programs  ' + '  '.join('%s:AGREE/DIFF/CRASH/HANG/ORACLE-BAD' % m for m in modes))
    for n in sorted(by_len):
        sh = shape_count(n) if a.to_length and n <= a.to_length else '-'
        progs = sum(1 for _, (m, _) in ids if m == n)
        cells = []
        for m in modes:
            c = by_len[n]; crash = sum(v for (mm, vv), v in c.items() if mm == m and vv.startswith('CRASH'))
            cells.append('%s:%d/%d/%d/%d/%d' % (m, c[(m, 'AGREE')], c[(m, 'DIFF')], crash, c[(m, 'HANG')], c[(m, 'ORACLE-BAD')]))
        print('%2d %8s %8d  %s' % (n, sh, progs, '  '.join(cells)))
    print('char-length histogram: ' + ' '.join('%d:%d' % (k, chars[k]) for k in sorted(chars)))
    tree = TREES[a.engine]
    print('POPULATION programs=%d graded=%d (programs x modes, oracle-bad excluded) AGREE=%d DIVERGENCE-CLASSES=%d engine=%s tree: %s=%s' % (
        total, graded, agree, len(witnesses), a.engine, os.path.basename(tree),
        subprocess.run(['git', '-C', tree, 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip() or '?'))
    for mode, v, n, e, path, oval in witnesses:
        print('  [%s %-12s] x%-4d len=%d  %-40s oracle=%-10s -> %s' % (mode, v, seen[(mode, v, canon(e))], n, e[:40], oval[:10], os.path.basename(path)))
    if graded == 0: refuse('zero programs graded -- the oracle produced no lines (batch dir kept: %s)' % work)
    if not a.keep_batches:
        for f in os.listdir(work): os.remove(os.path.join(work, f))
        os.rmdir(work)
    return 0 if not witnesses else 1
if __name__ == '__main__': sys.exit(main())
