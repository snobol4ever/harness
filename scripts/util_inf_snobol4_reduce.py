#!/usr/bin/env python3
"""util_inf_snobol4_reduce.py -- one divergence of the infinite_snobol4 differential reduced to a standalone witness of at most 20 lines.

usage: util_inf_snobol4_reduce.py BATCH.diff --line L --engine dotnet|jvm|scrip [--scope N] [--seed0 S] [--class TEXT] [--out W.sno] [--apply]
       util_inf_snobol4_reduce.py --selftest

Step 2 of DESIGN-PLAN: random-codegen-scope (the cto, 2026-10-28, CEO-1999; .github ARCH-RANDOM-SNOBOL4-GENERATOR.md section 5 and R4),
landed by hq_dotnet. BATCH.diff and BATCH.txt are what util_inf_snobol4_differential.py writes for batch N: L is the differing line's number
in the batch (its "line L" block in the diff), counted as the driver counts, over the batch's non-blank lines with the preset lines first.

1. THE CLOSURE. The preset lines are the batch's leading (name = value) lines, the capitals' null line and inf_caps left out (a fresh
   program starts with null capitals, and inf_caps is the evaluator's own flag). The closure is every preset line whose name the test
   mentions, then the names those lines mention, to a fixed point; a test that indirects ($, f g h, APPLY, EVAL, CODE) can reach any cell, so
   then every preset line is in. f, g and h are the evaluator's functions, copied from inf_eval.sno, and h's inf_names rows with them.
2. THE SHAPE. The direct form first: &ERRLIMIT, the closure, SETEXIT, inf_r = <test>, the value, FAIL or ERROR n, then the capitals
   (X Y Z and every capital the test names; all 26 when the test calls g or h, which reach any of them), END. The supporting names are
   inf_-prefixed and no capital is one of them, so a capture into any capital survives to the capitals line (Lon: the supporting code uses
   no single-letter name). The direct form counts only when sbl -bf runs it to the capitals line; otherwise, or when it does not differ,
   the EVAL form, inf_r = EVAL('<test>'), because some classes live only on EVAL's road. A form whose run differs is the divergence.
3. DDMIN OVER THE CLOSURE: the closure's units (a preset line, a function with its DEFINE, the inf_names table, one inf_names row) are
   dropped in halves, then in smaller pieces, then singly, and a drop is kept only when sbl -bf and the engine, both re-run, print exactly
   what they printed for the whole closure, so a drop that turns the divergence into another one is refused. The test line is never
   changed: a program still over 20 lines is printed for the HQ to shorten its expression, and rc 1.
4. THE PROOF. The final program is run once more on both; it is printed (and, with --apply, written to --out, by default
   BATCH_line_L.sno beside the diff) only if they still differ, with one header line naming the batch, the line, the engine and the class.
   The ref is NOT cut here: util_add_ladder_witness.py cuts it from sbl -bf when the witness is harvested (section 6).

--selftest plants a three-preset divergence in a closed-world batch against a fake engine (sbl -bf with its X= line rewritten by sed) and
proves the closure, the ddmin, the direct form, the EVAL form (an engine that differs only on EVAL's road) and the refusal of a line that
does not differ, with no port engine.

rc 0 a witness of at most 20 lines that differs; 1 reduced, but still over 20 lines (printed); 2 could not measure (no oracle, no engine,
no such line, or a divergence the batch shows that no standalone form reproduces).
"""
import argparse, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import util_inf_snobol4_differential as drv

MAX_LINES = 20
PRESET = re.compile(r"^\((?:[A-Za-z_][A-Za-z0-9_]*(?:\[[^\]]*\])?\s*=\s*)+.*\)$")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
CAPITAL = re.compile(r"(?<![A-Za-z0-9_])([A-Z])(?![A-Za-z0-9_(])")
CALLS = {name: re.compile(r"(?<![A-Za-z0-9_])%s\s*\(" % name) for name in 'fgh'}
INDIRECT = re.compile(r"\$|(?<![A-Za-z0-9_])(?:[fgh]\s*\(|APPLY|EVAL|CODE)")
# the evaluator's functions as inf_eval.sno defines them: the DEFINE goes on top, the body after the capitals line
FUNCTIONS = {
    'f': ("        DEFINE('f(inf_arg)inf_s')", ["f       inf_s = a[inf_arg]                                      :F(FRETURN)",
                                                 "        f = $inf_s                                              :(RETURN)"]),
    'g': ("        DEFINE('g(inf_arg)inf_s')", ["g       inf_s = a[inf_arg]                                      :F(FRETURN)",
                                                 "        g = REPLACE(inf_s, &LCASE, &UCASE)                      :(RETURN)"]),
    'h': ("        DEFINE('h(inf_arg)inf_s')", ["h       inf_s = a[inf_arg]                                      :F(FRETURN)",
                                                 "        h = inf_names[REPLACE(inf_s, &LCASE, &UCASE)]",
                                                 "        DIFFER(h)                                               :S(NRETURN)F(FRETURN)"]),
}

def refuse(why):
    sys.stderr.write('REFUSE(2): ' + why + '\n')
    sys.exit(2)

def unquoted(text):
    return re.sub(r"'[^']*'|\"[^\"]*\"", ' ', text)

def names(text):
    return set(IDENT.findall(unquoted(text)))

def quoted(text):
    if '"' not in text:
        return '"' + text + '"'
    if "'" not in text:
        return "'" + text + "'"
    return ' "\'" '.join("'" + part + "'" for part in text.split("'"))

def read_diff(path, line):
    rows = open(path, encoding='latin-1').read().split('\n')
    for i, row in enumerate(rows):
        if row == 'line %d' % line and i + 1 < len(rows) and rows[i + 1].startswith('TEST   '):
            return rows[i + 1][7:]
    return None

def presets_before(lines, upto):
    """the leading preset lines of the batch above line `upto` (1-based), as statements, the capitals' null line and inf_caps left out"""
    out = []
    for text in lines[:upto - 1]:
        if not PRESET.match(text):
            break
        lhs = text[1:].split('=')[0].strip()
        if lhs == 'inf_caps' or re.fullmatch(r'[A-Z]', lhs):
            continue
        out.append(text[1:-1])
    return out

def closure_units(test, presets):
    """the closure as ordered units: ('preset', statement), ('function', name), ('names', None), ('row', capital)"""
    defined = [re.match(r'[A-Za-z_][A-Za-z0-9_]*', p).group(0) for p in presets]
    keep, want, seen = set(), names(test), test
    if INDIRECT.search(unquoted(test)):
        want |= set(defined)
    while True:
        grew = False
        for i, d in enumerate(defined):
            if i not in keep and d in want:
                keep.add(i); want |= names(presets[i]); seen += '\n' + presets[i]; grew = True
        if not grew:
            break
    units = [('preset', presets[i]) for i in sorted(keep)]
    calls = INDIRECT.search(unquoted(seen)) and re.search(r'[fgh]\s*\(|APPLY|EVAL|CODE', unquoted(seen))
    fns = [n for n in 'fgh' if CALLS[n].search(unquoted(seen)) or calls]
    units += [('function', n) for n in fns]
    if 'h' in fns:
        units += [('names', None)] + [('row', chr(c)) for c in range(ord('A'), ord('Z') + 1)]
    return units

def capitals_named(test):
    caps = set(CAPITAL.findall(unquoted(test)))
    if CALLS['g'].search(unquoted(test)) or CALLS['h'].search(unquoted(test)):
        caps = {chr(c) for c in range(ord('A'), ord('Z') + 1)}
    return ['X', 'Y', 'Z'] + sorted(caps - {'X', 'Y', 'Z'})

def program(test, units, form, header):
    fns = [u[1] for u in units if u[0] == 'function']
    caps = capitals_named(test)
    out = ['* ' + header] if header else []
    out.append('        &ERRLIMIT = 1000')
    out += [FUNCTIONS[n][0] for n in fns]
    for kind, val in units:
        if kind == 'names':
            out.append('        inf_names = TABLE()')
        elif kind == 'row':
            out.append("        inf_names['%s'] = .%s" % (val, val))
        elif kind == 'preset':
            out.append('        ' + val)
    out.append("        SETEXIT('inf_err')")
    out.append('        inf_r = %s' % (test if form == 'direct' else 'EVAL(%s)' % quoted(test)) + '  :F(inf_no)')
    out.append("        OUTPUT = DATATYPE(inf_r) ' ' inf_r  :(inf_out)")
    out.append("inf_no  OUTPUT = 'FAIL'  :(inf_out)")
    out.append("inf_err OUTPUT = 'ERROR ' &ERRTYPE")
    out.append('inf_out OUTPUT = ' + " ' ' ".join("'%s=' %s" % (c, c) for c in caps) + '  :(END)')
    for n in fns:
        out += FUNCTIONS[n][1]
    out.append('END')
    return '\n'.join(out) + '\n'

class Runner:
    """runs a candidate program on sbl -bf and on the engine, standard output only, each run bounded; memoized by text"""
    def __init__(self, engine_argv, work):
        self.engine, self.work, self.memo, self.runs = engine_argv, work, {}, 0

    def one(self, argv, text):
        path = os.path.join(self.work, 'w.sno')
        open(path, 'w', encoding='latin-1').write(text)
        try:
            r = subprocess.run(argv + ['w.sno'], stdin=subprocess.DEVNULL, capture_output=True, timeout=30, cwd=self.work)
            return r.stdout.decode('latin-1'), r.returncode
        except subprocess.TimeoutExpired:
            return 'TIMEOUT', -1

    def pair(self, text):
        if text not in self.memo:
            self.runs += 1
            self.memo[text] = (self.one([drv.SBL, '-bf'], text), self.one(self.engine, text))
        return self.memo[text]

def oracle_completes(result):
    (out, rc), _ = result
    tail = [l for l in out.split('\n') if l.strip()]
    return rc == 0 and bool(tail) and tail[-1].startswith('X=')

def ddmin(units, holds):
    n = 2
    while len(units) >= 2:
        size = -(-len(units) // n)
        pieces = [units[i:i + size] for i in range(0, len(units), size)]
        for piece in pieces:
            rest = [u for u in units if u not in piece]
            if holds(rest):
                units, n = rest, max(n - 1, 2)
                break
        else:
            if n >= len(units):
                break
            n = min(len(units), 2 * n)
    if len(units) == 1 and holds([]):
        units = []
    return units

def reduce(test, lines, line, engine_argv, header, log=print):
    """returns (rc, program text or None, form); rc as the module's"""
    with tempfile.TemporaryDirectory(prefix='inf_reduce_') as work:
        run = Runner(engine_argv, work)
        units = closure_units(test, presets_before(lines, line))
        for form in ('direct', 'eval'):
            whole = run.pair(program(test, units, form, header))
            if not oracle_completes(whole) or whole[0][0] == whole[1][0]:
                log('form %s: %s' % (form, 'sbl does not run it to the capitals line' if not oracle_completes(whole) else 'no divergence'))
                continue
            sig = (whole[0][0], whole[1][0])
            kept = ddmin(units, lambda u: (lambda r: (r[0][0], r[1][0]) == sig)(run.pair(program(test, u, form, header))))
            text = program(test, kept, form, header)
            final = Runner(engine_argv, work).pair(text)
            if final[0][0] == final[1][0]:
                log('form %s: the reduced program no longer differs on the proof run (a flaky engine?)' % form)
                return 2, None, form
            log('form %s: closure %d units -> %d, %d candidate runs, %d lines' % (form, len(units), len(kept), run.runs, text.count('\n')))
            return (0 if text.count('\n') <= MAX_LINES else 1), text, form
        return 2, None, None

def selftest():
    presets = ["(A = B = C = D = E = F = G = H = I = J = K = L = M = N = O = P = Q = R = S = T = U = V = W = X = Y = Z = '')",
               '(inf_caps = 1)', "(a = ARRAY('0:35'))"]
    pool = 'abcdefghijklmnopqrstuvwxyz0123456789'
    presets += ["(a[%d] = '%s')" % (i, c) for i, c in enumerate(pool)]
    presets += ['(%s = %d)' % (c, i + 1) for i, c in enumerate('bcdefghij')] + ['(k = 0)']
    presets += ["(%s = '%s')" % (c, d) for c, d in zip('lmnopqrs', 'mnopqrst')] + ["(t = 'l')", '(u = TABLE())']
    presets += ["(u['%s'] = %d)" % (c, i) for i, c in enumerate(pool)]
    presets += ['(v = LEN(1) $ X)', "(w = ANY('bcd') . Y)", '(x = *$l)', "(y = BREAK('n') $ Z)", '(z = POS(0) *v *w)']
    tests = ["$l $m ? 'no' . X", "'ab' ? 'a' . X"]
    lines = presets + tests
    want = ["        l = 'm'", "        m = 'n'", "        n = 'o'"]
    fake = ['bash', '-c', drv.SBL + ' -bf "$1" | sed "s/^X=no /X=NO /"', 'fake']
    fake_eval = ['bash', '-c', 'if grep -q "EVAL(" "$1"; then ' + drv.SBL + ' -bf "$1" | sed "s/^X=no /X=NO /"; else ' + drv.SBL + ' -bf "$1"; fi', 'fake']
    bad, quiet = [], lambda s: None
    line = len(presets) + 1
    for name, eng, form in (('direct', fake, 'direct'), ('eval', fake_eval, 'eval')):
        rc, text, got = reduce(tests[0], lines, line, eng, 'selftest', quiet)
        body = [l for l in (text or '').split('\n') if l.startswith('        ') and '=' in l and 'inf_' not in l and 'OUTPUT' not in l and 'ERRLIMIT' not in l]
        if rc != 0 or got != form or body != want or 'DEFINE' in (text or ''):
            bad.append('%s: rc=%s form=%s presets=%s' % (name, rc, got, body))
        else:
            print('selftest %s: rc 0, the %s form, the closure reduced to the three presets l m n, %d lines' % (name, form, text.count('\n')))
    rc, text, got = reduce(tests[1], lines, line + 1, fake, 'selftest', quiet)
    if rc != 2:
        bad.append('a line that does not differ: rc=%s, want 2' % rc)
    else:
        print('selftest refusal: a line that does not differ on the fake engine is refused rc 2')
    for b in bad:
        print('SELFTEST RED ' + b)
    print('SELFTEST %s' % ('PASS' if not bad else 'FAIL'))
    return 0 if not bad else 1

def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('diff', nargs='?')
    p.add_argument('--line', type=int)
    p.add_argument('--engine', choices=['dotnet', 'jvm', 'scrip'])
    p.add_argument('--scope', default='?')
    p.add_argument('--seed0', default='?')
    p.add_argument('--class', dest='klass', default='')
    p.add_argument('--out')
    p.add_argument('--apply', action='store_true', help='write the witness to --out (default BATCH_line_L.sno beside the diff)')
    p.add_argument('--selftest', action='store_true')
    a = p.parse_args()
    if not os.access(drv.SBL, os.X_OK):
        refuse('the correctness oracle is missing: ' + drv.SBL)
    if a.selftest:
        return selftest()
    if not (a.diff and a.line and a.engine):
        refuse('usage: util_inf_snobol4_reduce.py BATCH.diff --line L --engine dotnet|jvm|scrip [--apply] | --selftest')
    batch = re.sub(r'\.diff$', '.txt', a.diff)
    if not (os.path.isfile(a.diff) and os.path.isfile(batch)):
        refuse('no %s with its %s beside it' % (a.diff, batch))
    test = read_diff(a.diff, a.line)
    lines = [t for t in open(batch, encoding='latin-1').read().split('\n') if t.strip()]
    if test is None or a.line > len(lines) or lines[a.line - 1] != test:
        refuse('line %d is not a differing line of %s whose text is line %d of %s' % (a.line, a.diff, a.line, batch))
    n = re.search(r'batch_(\d+)\.diff$', a.diff)
    header = 'infinite_snobol4 scope=%s seed0=%s batch %s line %d: %s differs from sbl -bf%s' % (
        a.scope, a.seed0, n.group(1) if n else '?', a.line, a.engine, (' -- ' + a.klass) if a.klass else '')
    rc, text, form = reduce(test, lines, a.line, drv.engine_argv(a.engine), header)
    if text is None:
        refuse('line %d differs in its batch, but neither standalone form reproduces it on %s against sbl -bf (it may need an earlier test)' % (a.line, a.engine))
    sys.stdout.write(text)
    if rc == 1:
        print('OVER %d LINES (%d): the test line itself must be shortened by hand' % (MAX_LINES, text.count('\n')))
    elif a.apply:
        out = a.out or re.sub(r'\.diff$', '_line_%d.sno' % a.line, a.diff)
        open(out, 'w', encoding='latin-1').write(text)
        print('WROTE ' + out)
    return rc

if __name__ == '__main__':
    sys.exit(main())
