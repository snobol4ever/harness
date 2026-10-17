#!/usr/bin/env python3
"""bench_wrap_rebus.py <kernel.reb> --mode iter|time [--n N] [--bud-ms MS] [-o OUT.reb]

THE GENERATED WRAPPER FOR ONE PRISTINE REBUS BENCHMARK -- it does the test and the measurement at once (RULES.md FACT RULE THE
KERNEL CONVENTION and its 2026-09-23 addendum, CEO-1221; Lon, verbatim: "The source of the benchmark is the apple-core of the test,
the wrapper code can be added to do both the test and the measurements."). The kernel file is never edited: this script writes a
NEW program, to OUT or stdout, and the runner (test_rebus_bench_suite.sh) deletes it after the run. Row rebus-benchmarks-double-as-
tests-ref-in-out-through-the-three-angle-harness-with-a-row-in-the-suite-grid, built by the coo on CEO-1227.

WHAT THE GENERATED PROGRAM DOES, IN ORDER:
  1. THE TEST. The kernel's main runs once, its body verbatim, so STDOUT is byte-comparable with the .ref.
  2. THE MEASUREMENT. The same body with its one `OUTPUT := E` spelled `bench_v := E` then repeats -- N times (angle 2, fixed
     iterations) or until the budget is spent (angle 3, fixed time) -- printing nothing, and ONE line goes to TERMINAL (stderr),
     the shape bench_wrap_snocone.py prints so one reader can parse both:
       BENCH mode=iter kernel=main iters=<n> ns=<elapsed> mismatched=<m> value=<v>
       BENCH mode=time kernel=main iters=<n> ns=<elapsed> budget_ms=<b> mismatched=<m> value=<v>
     TIME() is CLOCK_MONOTONIC nanoseconds in SCRIP (rt_time_ns, one runtime function for both modes).
  ⭐ NON-VACUITY, BEYOND THE TEST LINE: every repetition's value is compared with the first repetition's, and `value=` carries it, so
     the runner holds the REPEATED work to the .ref as well -- a kernel whose repeated work was skipped or folded to a different
     value prints `mismatched=` above zero and an extra stdout line, and fails. (Angle 1, the process wrapper, needs no generated
     program: the runner times the pristine kernel under tools/bench_rusage.)

THE SHAPE A KERNEL MUST HAVE, AND EVERY OTHER SHAPE IS REFUSED BY NAME (no silent fallback):
  exactly one top-level `function main()` with no parameters, closed by an `end` at column 0; exactly one `OUTPUT :=` statement,
  a whole line inside main; no OUTPUT anywhere else, no INPUT anywhere (a kernel that reads input cannot be repeated: its stdin is
  spent after one pass), and no identifier the wrapper uses (anything spelled bench_...).

EXIT 0 the program was written; 2 REFUSED with the reason on stderr.
"""
import argparse
import re
import sys

MAIN = re.compile(r'^function\s+main\s*\(\s*\)\s*$')
FUNC = re.compile(r'^function\s+[A-Za-z_][A-Za-z0-9_]*\s*\(')
OUT_STMT = re.compile(r'^(\s*)OUTPUT\s*:=\s*(\S.*?)\s*$')
TOK = lambda w: re.compile(r'(?<![A-Za-z0-9_])' + w + r'(?![A-Za-z0-9_])')
OUTPUT, INPUT, BENCH = TOK('OUTPUT'), TOK('INPUT'), re.compile(r'(?<![A-Za-z0-9_])bench_', re.I)


def refuse(msg):
    sys.stderr.write('bench_wrap_rebus.py: REFUSED: %s\n' % msg)
    sys.exit(2)


def split_main(lines, path):
    """(lines outside main, main's body lines) -- main is the one `function main()` block, closed by the first column-0 `end`."""
    starts = [i for i, l in enumerate(lines) if MAIN.match(l.rstrip('\n'))]
    if len(starts) != 1:
        refuse('%s has %d top-level `function main()` definitions; the wrapper needs exactly one' % (path, len(starts)))
    s = starts[0]
    e = next((i for i in range(s + 1, len(lines)) if lines[i].rstrip('\n') == 'end'), None)
    if e is None:
        refuse('%s: `function main()` at line %d has no column-0 `end` after it' % (path, s + 1))
    inner = lines[s + 1:e]
    if any(FUNC.match(l) for l in inner):
        refuse('%s: a function definition inside main\'s span (lines %d-%d) -- main is not a simple block' % (path, s + 1, e + 1))
    return lines[:s] + lines[e + 1:], inner


def code(l):
    """the line without its # comment, so a word in a comment is not read as a use"""
    return l.split('#', 1)[0]


def generate(path, mode, n, bud_ms):
    try:
        lines = open(path, encoding='utf-8').read().split('\n')
    except OSError as e:
        refuse('cannot read %s: %s' % (path, e))
    rest, body = split_main(lines, path)
    for i, l in enumerate(lines, 1):
        c = code(l)
        if INPUT.search(c):
            refuse('%s:%d reads INPUT -- a kernel that reads its input cannot be repeated (its stdin is spent after one pass)' % (path, i))
        if BENCH.search(c):
            refuse('%s:%d uses an identifier spelled bench_... -- the wrapper\'s own names would collide with it' % (path, i))
    if any(OUTPUT.search(code(l)) for l in rest):
        refuse('%s: OUTPUT is written outside main -- the repetitions could not be made silent' % path)
    outs = [i for i, l in enumerate(body) if OUTPUT.search(code(l))]
    if len(outs) != 1:
        refuse('%s: main writes OUTPUT on %d lines; the wrapper handles exactly one `OUTPUT := E` statement' % (path, len(outs)))
    m = OUT_STMT.match(code(body[outs[0]]))
    if not m:
        refuse('%s: main\'s OUTPUT line is not a whole `OUTPUT := E` statement: %r' % (path, body[outs[0]].strip()))
    quiet = list(body)
    quiet[outs[0]] = '%sbench_v := %s' % (m.group(1), m.group(2))
    if mode == 'iter':
        loop, tail = 'while bench_k < %d do {' % n, ''
    else:
        loop, tail = 'while time() - bench_t0 < %d do {' % (bud_ms * 1000000), ' || " budget_ms=" || %d' % bud_ms
    out = ['# GENERATED by harness/scripts/bench_wrap_rebus.py --mode %s from %s -- never edited, never committed; the kernel is the' % (mode, path),
           '# pristine source (RULES.md THE KERNEL CONVENTION). The test runs once, then the quiet repetitions report on TERMINAL.']
    out += rest
    out += ['', 'function bench_test()'] + body + ['end', '', 'function bench_quiet()'] + quiet + ['end', '',
            'function main()',
            '  local bench_want, bench_k, bench_bad, bench_t0, bench_ns',
            '  bench_test()',
            '  bench_quiet()',
            '  bench_want := bench_v',
            '  bench_k := 0',
            '  bench_bad := 0',
            '  bench_t0 := time()',
            '  ' + loop,
            '    bench_quiet()',
            '    if bench_v ~== bench_want then bench_bad := bench_bad + 1',
            '    bench_k := bench_k + 1',
            '  }',
            '  bench_ns := time() - bench_t0',
            '  TERMINAL := "BENCH mode=%s kernel=main iters=" || bench_k || " ns=" || bench_ns%s || " mismatched=" || bench_bad || " value=" || bench_want' % (mode, tail),
            '  if bench_bad > 0 then OUTPUT := "BENCH-MISMATCH " || bench_bad || " of " || bench_k || " repetitions computed a value other than the first"',
            'end', '']
    return '\n'.join(out)


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('prog')
    ap.add_argument('--mode', required=True, choices=['iter', 'time'])
    ap.add_argument('--n', type=int, default=3, help='iter mode: repetitions after the test (default 3)')
    ap.add_argument('--bud-ms', type=int, default=200, help='time mode: budget in ms (default 200)')
    ap.add_argument('-o', dest='out', default='')
    a = ap.parse_args(argv[1:])
    if a.mode == 'iter' and a.n < 1:
        refuse('--n must be at least 1 (got %d)' % a.n)
    if a.mode == 'time' and a.bud_ms < 1:
        refuse('--bud-ms must be at least 1 (got %d)' % a.bud_ms)
    text = generate(a.prog, a.mode, a.n, a.bud_ms)
    if a.out:
        with open(a.out, 'w', encoding='utf-8') as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
