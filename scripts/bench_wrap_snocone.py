#!/usr/bin/env python3
"""bench_wrap_snocone.py <prog.sc> --mode iter|time [--n N] [--bud-ms MS] [-o OUT.sc]

THE GENERATED WRAPPER FOR ONE PRISTINE SNOCONE BENCHMARK -- it does the test and the measurement at once (RULES.md FACT RULE
THE KERNEL CONVENTION and its 2026-09-23 addendum, CEO-1221; Lon, verbatim: "The source of the benchmark is the apple-core of the
test, the wrapper code can be added to do both the test and the measurements."). The source file is never edited: this script
writes a NEW program, to OUT or stdout, and the runner deletes it after the run.

WHAT THE GENERATED PROGRAM DOES, IN ORDER:
  1. THE TEST. The program's own standalone behaviour runs once, unchanged, so its STDOUT is byte-comparable with its .ref.
  2. THE MEASUREMENT. The workload is then repeated with no output of its own, and ONE line goes to TERMINAL (stderr):
       BENCH mode=iter kernel=<K> iters=<n> ns=<elapsed>              (angle 2: fixed iterations, time measured)
       BENCH mode=time kernel=<K> iters=<n> ns=<elapsed> budget_ms=<b> (angle 1: fixed time, iterations counted)
     TIME() is integer nanoseconds in SCRIP and in the SPITBOL build under /home/resources (measured 2026-09-23: a 3,000,000-step
     loop read 64,795,259 against 73 ms of wall on SCRIP and 162,158,564 against 169 ms on sbl -bf).
  (Angle 3, the process wrapper, needs no generated program: the runner times the pristine source under tools/bench_rusage.)

TWO SHAPES OF PRISTINE PROGRAM, AND WHAT IS REPEATED IN EACH:
  MARKED -- the program carries exactly one comment line  // *BENCH kernel=<FN> check=<N> bud=<ms> flr=<ms> [batch=<K>]
    (the contract bench_wrap.sh reads for SNOBOL4, spelled with Snocone's comment). Lines above it are SETUP (declarations, the
    kernel function FN, and the one read of the input); lines below are MAIN (the standalone driver). The generated program is
    SETUP + MAIN verbatim, then the loop calls FN, which re-runs the workload over the data SETUP already read and prints nothing.
  UNMARKED -- a program with no marker and no INPUT (a data-driven program cannot be repeated: its stdin is spent after one pass).
    Its top-level procedure/function/struct blocks stay at top level; every other line becomes the body of two generated procedures:
    ZBENCH_BODY (verbatim, called once: the test) and ZBENCH_QUIET (the same lines with the OUTPUT variable spelled ZBENCH_SINK, so a
    repetition computes the value and prints nothing; DETACH(.OUTPUT) cannot do this in SCRIP, which ignores it -- measured
    2026-09-23, SPITBOL honours it). A statement label in the body, or a return at top level, REFUSES: it cannot move into a procedure.

EXIT 0 the program was written; 2 REFUSED with the reason on stderr (no silent fallback: an unwrappable program is named).
"""
import argparse
import os
import re
import sys

MARK = re.compile(r'^\s*//\s*\*BENCH\s+(.*)$')
DECL = re.compile(r'^(procedure|function|struct)\s+([A-Za-z_][A-Za-z0-9_]*)')
LABEL = re.compile(r'^\s*[A-Za-z_][A-Za-z0-9_]*\s*:(?!=)')
TOKEN_INPUT = re.compile(r'(?<![A-Za-z0-9_])INPUT(?![A-Za-z0-9_])')


def refuse(msg):
    sys.stderr.write('bench_wrap_snocone.py: REFUSED: %s\n' % msg)
    sys.exit(2)


def code_spans(line):
    """Yield (is_code, text) pieces of one line: string literals and a // comment are not code."""
    i, n, start = 0, len(line), 0
    while i < n:
        c = line[i]
        if c in ('"', "'"):
            if i > start:
                yield True, line[start:i]
            j = i + 1
            while j < n:
                if line[j] == c:
                    if j + 1 < n and line[j + 1] == c:
                        j += 2
                        continue
                    break
                j += 1
            yield False, line[i:j + 1]
            i = start = j + 1
            continue
        if c == '/' and i + 1 < n and line[i + 1] == '/':
            if i > start:
                yield True, line[start:i]
            yield False, line[i:]
            return
        i += 1
    if start < n:
        yield True, line[start:]


def brace_delta(line):
    d = 0
    for is_code, t in code_spans(line):
        if is_code:
            d += t.count('{') - t.count('}')
    return d


def code_has(line, rx):
    return any(is_code and rx.search(t) for is_code, t in code_spans(line))


def respell_output(line):
    rx = re.compile(r'(?<![A-Za-z0-9_])OUTPUT(?![A-Za-z0-9_])')
    return ''.join(rx.sub('ZBENCH_SINK', t) if is_code else t for is_code, t in code_spans(line))


def harness(mode, call, kernel, n, bud_ms, batch, call_n=''):
    if mode == 'iter':
        if call_n:  # a marked kernel repeats itself: FN(N) is the program's own N-repetition entry, called once
            return ['ZBENCH_I = %d;' % n, 'ZBENCH_T0 = TIME();', 'ZBENCH_R = %s;' % call_n, 'ZBENCH_T1 = TIME();',
                    "TERMINAL = 'BENCH mode=iter kernel=%s iters=' ZBENCH_I ' ns=' (ZBENCH_T1 - ZBENCH_T0);" % kernel]
        return ['ZBENCH_N = %d;' % n, 'ZBENCH_I = 0;', 'ZBENCH_T0 = TIME();',
                'while (LT(ZBENCH_I, ZBENCH_N)) { ZBENCH_R = %s; ZBENCH_I = ZBENCH_I + %d; }' % (call, batch),
                'ZBENCH_T1 = TIME();',
                "TERMINAL = 'BENCH mode=iter kernel=%s iters=' ZBENCH_I ' ns=' (ZBENCH_T1 - ZBENCH_T0);" % kernel]
    return ['ZBENCH_BUD = %d * 1000000;' % bud_ms, 'ZBENCH_I = 0;', 'ZBENCH_T0 = TIME();',
            'while (LT(TIME() - ZBENCH_T0, ZBENCH_BUD)) { ZBENCH_R = %s; ZBENCH_I = ZBENCH_I + %d; }' % (call, batch),
            'ZBENCH_T1 = TIME();',
            "TERMINAL = 'BENCH mode=time kernel=%s iters=' ZBENCH_I ' ns=' (ZBENCH_T1 - ZBENCH_T0) ' budget_ms=%d';" % (kernel, bud_ms)]


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('prog')
    ap.add_argument('--mode', required=True, choices=['iter', 'time'])
    ap.add_argument('--n', type=int, default=0, help='iter mode: repetitions (default: the marker check=, else 1)')
    ap.add_argument('--bud-ms', type=int, default=0, help='time mode: budget in ms (default: the marker bud=, else 200)')
    ap.add_argument('-o', dest='out', default='')
    a = ap.parse_args(argv[1:])
    if not os.path.isfile(a.prog):
        refuse('no such program: %s' % a.prog)
    lines = open(a.prog, encoding='utf-8').read().split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    marks = [i for i, l in enumerate(lines) if MARK.match(l)]
    if len(marks) > 1:
        refuse('%s carries %d // *BENCH markers; exactly one is allowed' % (a.prog, len(marks)))
    head = ['// GENERATED by ../harness/scripts/bench_wrap_snocone.py from %s -- DO NOT EDIT, DO NOT COMMIT.' % os.path.basename(a.prog),
            '// The pristine program is the source of truth; this file is its test-and-measure wrapper, mode=%s.' % a.mode]
    if marks:
        m = marks[0]
        attrs = dict(re.findall(r'(\w+)=(\S+)', MARK.match(lines[m]).group(1)))
        kernel = attrs.get('kernel', '')
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', kernel):
            refuse('%s marker names no kernel=<FN>: %s' % (a.prog, lines[m].strip()))
        if not any(re.match(r'^\s*(function|procedure)\s+%s\s*\(' % re.escape(kernel), l) for l in lines[:m]):
            refuse('%s names kernel %s but SETUP defines no function %s(...) -- the loop would call nothing and read as infinitely fast' % (a.prog, kernel, kernel))
        try:
            check, bud, batch = int(attrs.get('check', '1')), int(attrs.get('bud', '200')), int(attrs.get('batch', '1'))
        except ValueError:
            refuse('%s marker has a non-integer check/bud/batch: %s' % (a.prog, lines[m].strip()))
        n = a.n or check
        body = lines
        tail = harness(a.mode, '%s(%d)' % (kernel, batch), kernel, n, a.bud_ms or bud, batch, call_n='%s(%d)' % (kernel, n))
    else:
        decls, stmts, depth, in_decl, seen_open = [], [], 0, False, False
        for l in lines:
            if not in_decl and depth == 0 and DECL.match(l):
                in_decl, seen_open = True, False
            (decls if in_decl else stmts).append(l)
            depth += brace_delta(l)
            if in_decl:
                seen_open = seen_open or any(c and '{' in t for c, t in code_spans(l))
                if seen_open and depth == 0:
                    in_decl = False
        if depth != 0:
            refuse('%s: braces do not balance at top level (depth %d at end of file)' % (a.prog, depth))
        if any(code_has(l, TOKEN_INPUT) for l in stmts + decls):
            refuse('%s reads INPUT and carries no // *BENCH marker: its stdin is spent after one pass, so it cannot be repeated -- give it a kernel function and a marker' % a.prog)
        for l in stmts:
            if LABEL.match(l) and not l.strip().startswith('//'):
                refuse('%s has a top-level statement label (%s): it cannot move into a generated procedure' % (a.prog, l.strip()))
            if code_has(l, re.compile(r'(?<![A-Za-z0-9_])(n?f?return)(?![A-Za-z0-9_])')):
                refuse('%s has a return at top level (%s)' % (a.prog, l.strip()))
        if not any(code_has(l, re.compile(r'\S')) for l in stmts):
            refuse('%s has no top-level statements to repeat' % a.prog)
        kernel = 'ZBENCH_QUIET'
        body = decls + ['procedure ZBENCH_BODY() {'] + stmts + ['}', 'procedure ZBENCH_QUIET() {'] + [respell_output(l) for l in stmts] + ['}', 'ZBENCH_BODY();']
        tail = harness(a.mode, 'ZBENCH_QUIET()', os.path.basename(a.prog)[:-3], a.n or 1, a.bud_ms or 200, 1)
    text = '\n'.join(head + body + tail) + '\n'
    if a.out:
        open(a.out, 'w', encoding='utf-8').write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
