#!/usr/bin/env python3
"""bench_wrap_snobol4.py <kernel.sno> --mode iter|time [--n N] [--bud-ms MS] [-o OUT.sno]

THE GENERATED WRAPPER FOR ONE PRISTINE SNOBOL4 BENCHMARK -- the test and the measurement in one program (RULES.md FACT RULE THE
KERNEL CONVENTION and its 2026-09-23 addendum, CEO-1221; Lon 2026-09-24 14:2x, in-chat to the ceo: create the SnoBench runner).
The kernel file is never edited: this writes a NEW program, to OUT or stdout, that test_snobol4_bench_suite.sh deletes after the
run. The shape mirrors bench_wrap_rebus.py so one reader parses every language's BENCH line.

WHAT THE GENERATED PROGRAM DOES, IN ORDER:
  1. THE TEST. The kernel runs once, verbatim -- its SETUP section (everything above the `*BENCH` line, or the whole program when
     there is none) and its MAIN section (the standalone driver below the `*BENCH` line, its END removed) -- so STDOUT is
     byte-comparable with the .ref.
  2. THE MEASUREMENT. Quiet repetitions -- N of them (angle 2, fixed iterations) or until the budget is spent (angle 3, fixed
     time) -- printing nothing, then ONE line on TERMINAL (stderr):
       BENCH mode=iter kernel=<FN> iters=<n> ns=<elapsed> mismatched=<m> value=<v>
       BENCH mode=time kernel=<FN> iters=<n> ns=<elapsed> budget_ms=<b> mismatched=<m> value=<v>
     TIME() is CLOCK_MONOTONIC nanoseconds in SCRIP (rt_time_ns, one runtime function for both modes; harness.inc's NS-TIME).
     ⭐ AN ENGINE WHOSE TIME() COUNTS ANOTHER UNIT says so with --time-unit-ns U (nanoseconds per TIME() unit; 1 by default): the
     budget is spelled in its own unit and ns= is scaled back to nanoseconds. snobol4dotnet mimics SPITBOL exactly (Lon 2026-10-18,
     in-chat to hq_dotnet, verbatim: "The snobol4dotnet is meant to mimic SPITBOL exactly."), and SPITBOL's TIME() is milliseconds
     (the manual; Dewar and Emmer's zystm), so it runs at U = 1000000; the fleet's own SPITBOLs answer nanoseconds by NS-TIME.
     THE QUIET BODY: with a `*BENCH kernel=<FN> check=<N>` line (bench_wrap.sh's contract), each repetition calls FN(N) and
     `value=` carries its return, compared with the first repetition's (mismatched= counts the differing ones). Without that
     line, each repetition re-runs MAIN with every `OUTPUT = E` spelled `ZBENCH_V = E` and its labels suffixed `_ZB`, so the
     same work runs silently; `value=` is then the last such value.
  ⭐ NON-VACUITY: the repeated work must compute one value, and the test half must print the ref; either failing fails the kernel.

REFUSED BY NAME (no silent fallback): a kernel that reads INPUT (its stdin is spent after one pass); one that uses an identifier
spelled ZBENCH_...; a `*BENCH` line naming a kernel function the SETUP does not DEFINE; a MAIN section whose OUTPUT line is not
a whole `OUTPUT = E` statement (an OUTPUT in the goto field, a multi-target assignment). A goto to END inside MAIN is redirected
to the wrapper's own continuation label, so the loop still runs.

EXIT 0 the program was written; 2 REFUSED with the reason on stderr.
"""
import argparse
import re
import sys

BENCH_LINE = re.compile(r'^\*BENCH\s+kernel=([A-Za-z_][A-Za-z0-9_.]*)\s+check=(\d+)')
LABEL = re.compile(r'^([A-Za-z][A-Za-z0-9_.]*)(\s|$)')
OUT_STMT = re.compile(r'^([A-Za-z][A-Za-z0-9_.]*)?(\s+)OUTPUT\s*=\s*(.*?)(\s*:\s*[SF]?\(.*)?\s*$')
TOK = lambda w: re.compile(r'(?<![A-Za-z0-9_.])' + w + r'(?![A-Za-z0-9_.])')
INPUT, OUTPUT = TOK('INPUT'), TOK('OUTPUT')
ZB = re.compile(r'(?<![A-Za-z0-9_])ZBENCH_', re.I)
GOTO_END = re.compile(r'\(END\)')


def refuse(msg):
    sys.stderr.write('bench_wrap_snobol4.py: REFUSED: %s\n' % msg)
    sys.exit(2)


def code(l):
    return '' if l.startswith('*') else l


def split(lines, path):
    """(setup lines, bench line or None, main lines without END) -- END is the last non-blank line, at column 1."""
    end = None
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip():
            if re.match(r'^END(\s|$)', lines[i]):
                end = i
            break
    if end is None:
        refuse('%s: no END statement at the foot of the program' % path)
    body = lines[:end]
    bl = [i for i, l in enumerate(body) if BENCH_LINE.match(l)]
    if len(bl) > 1:
        refuse('%s carries %d *BENCH lines; the contract is one' % (path, len(bl)))
    if bl:
        i = bl[0]
        return body[:i], body[i], body[i + 1:]
    return body, None, []


def suffix_labels(lines):
    """MAIN copied as the quiet body: every label defined here gets _ZB, and every goto to it follows; OUTPUT = E becomes ZBENCH_V = E."""
    labels = [LABEL.match(l).group(1) for l in lines if not l.startswith('*') and LABEL.match(l)]
    out = []
    for l in lines:
        if l.startswith('*') or not l.strip():
            continue
        m = LABEL.match(l)
        if m:
            l = m.group(1) + '_ZB' + l[len(m.group(1)):]
        for lab in labels:
            l = re.sub(r'\(' + re.escape(lab) + r'\)', '(' + lab + '_ZB)', l)
        o = OUT_STMT.match(l)
        if o:
            l = '%s%sZBENCH_V = %s%s' % (o.group(1) or '', o.group(2), o.group(3), o.group(4) or '')
        elif OUTPUT.search(l):
            refuse('a MAIN line writes OUTPUT other than as a whole OUTPUT = E statement: %r' % l.strip())
        out.append(l)
    return out


def generate(path, mode, n, bud_ms, unit_ns=1):
    try:
        lines = open(path, encoding='utf-8').read().split('\n')
    except OSError as e:
        refuse('cannot read %s: %s' % (path, e))
    for i, l in enumerate(lines, 1):
        c = code(l)
        if INPUT.search(c):
            refuse('%s:%d reads INPUT -- a kernel that reads its input cannot be repeated' % (path, i))
        if ZB.search(c):
            refuse('%s:%d uses an identifier spelled ZBENCH_... -- the wrapper\'s own names would collide with it' % (path, i))
    setup, bench, main = split(lines, path)
    if bench is None:
        setup, main = [], setup
    test_main = [GOTO_END.sub('(ZBENCH_L)', l) for l in main]
    if bench:
        m = BENCH_LINE.match(bench)
        fn, chk = m.group(1), m.group(2)
        if not any(re.search(r"DEFINE\(\s*'" + re.escape(fn) + r"\(", l) for l in setup):
            refuse('%s: the *BENCH line names kernel %s, which the SETUP section never DEFINEs' % (path, fn))
        quiet = ['        ZBENCH_V = %s(%s)' % (fn, chk)]
        kname = fn
    else:
        quiet = [GOTO_END.sub('(ZBENCH_E)', l) for l in suffix_labels(main)]
        if not quiet:
            refuse('%s: no *BENCH line and no MAIN section to repeat' % path)
        kname = 'main'
    if mode == 'iter':
        cond = 'LT(ZBENCH_K, %d)' % n
        tail = ''
    else:
        if (bud_ms * 1000000) % unit_ns:
            refuse('--bud-ms %d is not a whole number of TIME() units of %d ns' % (bud_ms, unit_ns))
        cond = 'LT(TIME() - ZBENCH_T0, %d)' % (bud_ms * 1000000 // unit_ns)
        tail = " ' budget_ms=%d'" % bud_ms
    out = ['* GENERATED by harness/scripts/bench_wrap_snobol4.py --mode %s from %s -- never edited, never committed; the kernel is the' % (mode, path),
           '* pristine source (RULES.md THE KERNEL CONVENTION). The test runs once, then the quiet repetitions report on TERMINAL:',
           '* one warm-up repetition sets the wanted value and restarts the clock, then the counted repetitions run until the',
           '* iteration count or the time budget is reached; every repetition is compared with the wanted value.']
    out += setup
    out += test_main
    out += ['ZBENCH_L ZBENCH_K = -1',
            '        ZBENCH_BAD = 0',
            '        ZBENCH_T0 = TIME()',
            'ZBENCH_M ZBENCH_V = ZBENCH_V']
    out += quiet
    out += ['ZBENCH_E ZBENCH_K = ZBENCH_K + 1',
            '        ZBENCH_WANT = EQ(ZBENCH_K, 0) ZBENCH_V          :S(ZBENCH_R)',
            '        ZBENCH_BAD = DIFFER(ZBENCH_V, ZBENCH_WANT) ZBENCH_BAD + 1',
            '        ' + cond + '                                :S(ZBENCH_M)F(ZBENCH_D)',
            'ZBENCH_R ZBENCH_T0 = TIME()                            :(ZBENCH_M)',
            'ZBENCH_D ZBENCH_NS = TIME() - ZBENCH_T0' if unit_ns == 1 else 'ZBENCH_D ZBENCH_NS = (TIME() - ZBENCH_T0) * %d' % unit_ns,
            "        TERMINAL = 'BENCH mode=%s kernel=%s iters=' ZBENCH_K ' ns=' ZBENCH_NS%s ' mismatched=' ZBENCH_BAD ' value=' ZBENCH_WANT" % (mode, kname, tail),
            "        OUTPUT = GT(ZBENCH_BAD, 0) 'BENCH-MISMATCH ' ZBENCH_BAD ' of ' ZBENCH_K ' repetitions computed a value other than the first'",
            'END', '']
    return '\n'.join(out)


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('prog')
    ap.add_argument('--mode', required=True, choices=['iter', 'time'])
    ap.add_argument('--n', type=int, default=3)
    ap.add_argument('--bud-ms', type=int, default=200)
    ap.add_argument('--time-unit-ns', type=int, default=1)
    ap.add_argument('-o', dest='out', default='')
    a = ap.parse_args(argv[1:])
    if a.mode == 'iter' and a.n < 1:
        refuse('--n must be at least 1 (got %d)' % a.n)
    if a.mode == 'time' and a.bud_ms < 1:
        refuse('--bud-ms must be at least 1 (got %d)' % a.bud_ms)
    if a.time_unit_ns < 1:
        refuse('--time-unit-ns must be at least 1 (got %d)' % a.time_unit_ns)
    text = generate(a.prog, a.mode, a.n, a.bud_ms, a.time_unit_ns)
    if a.out:
        with open(a.out, 'w', encoding='utf-8') as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
