#!/usr/bin/env python3
"""bench_wrap_raku.py <kernel.raku> --mode iter|time [--n N] [--bud-ms MS] [-o OUT.raku]

THE GENERATED WRAPPER FOR ONE PRISTINE RAKU BENCHMARK -- the test and the measurement in one program (RULES.md FACT RULE THE
KERNEL CONVENTION and its 2026-09-23 addendum, CEO-1221; Lon 2026-09-24 14:2x, in-chat to the ceo: create the RakBench runner).
The kernel file is never edited: this writes a NEW program that test_raku_bench_suite.sh deletes after the run. The shape mirrors
bench_wrap_rebus.py so one reader parses every language's BENCH line; the spelling is the subset SCRIP's Raku front-end parses
today (a sub per half, `while`, `if ... ne ...`, string `~`, `note(...)`, `wall_us()` -- probed 2026-09-24).

WHAT THE GENERATED PROGRAM DOES, IN ORDER:
  1. THE TEST. Every top-level `use` line, then every top-level `sub`/`class`/`role`/`grammar`/`enum`/`constant` declaration,
     hoisted verbatim; then the kernel's remaining top-level statements verbatim inside `sub bench_test()`, called once -- so
     STDOUT is byte-comparable with the .ref.
  2. THE MEASUREMENT. `sub bench_quiet()` holds the same statements with every whole-statement `say E;` / `put E;` / `print E;`
     spelled as appends to a local string it returns (a line is first cut at its top-level semicolons, so the `say $i;` that
     ends raku-bench's one-line bodies is a whole output call; CEO-1283), then repeats -- N times (angle 2) or until the
     budget is spent (angle 3) -- after one warm-up repetition that fixes the wanted capture and restarts the clock; ONE line
     goes to stderr:
       BENCH mode=iter kernel=main iters=<n> ns=<elapsed> mismatched=<m> value=<chars of the wanted capture>
       BENCH mode=time kernel=main iters=<n> ns=<elapsed> budget_ms=<b> mismatched=<m> value=<chars>
     wall_us() is SCRIP's builtin microsecond clock (Rakudo gets it from prelude_rakudo.rakumod via -M); ns = us * 1000.
  ⭐ NON-VACUITY: `value=` is the character count of the wanted capture, and the runner holds it to the .ref's own count, so a
     quiet body whose output was lost (a capture that reads empty) or that computes something else fails; mismatched= counts
     repetitions whose capture differs from the first.

REFUSED BY NAME (no silent fallback): a kernel that reads stdin ($*IN, get, lines, slurp, prompt); an identifier spelled
bench_...; an output call that is not a whole statement (`say` inside a block, `.say` / `.print` method forms inside an
expression, `printf`, `sprintf`-less formats); a hoisted declaration that itself prints (its output could not be made quiet).

EXIT 0 the program was written; 2 REFUSED with the reason on stderr.
"""
import argparse
import re
import sys

USE = re.compile(r'^use\s')
DECL = re.compile(r'^(sub|multi|proto|class|role|grammar|enum|constant|unit|module)\s')
MODS = r'(\s+(for|if|unless|while|until|given|with|without)\s.*)?'
OUT_LINE = re.compile(r'^(\s*)(say|put|print)\s+(.*?)' + MODS + r';\s*(#.*)?$')
METHOD_LINE = re.compile(r'^(\s*)(.*?)\.(say|put|print)\s*(\(\s*\))?' + MODS + r';\s*(#.*)?$')
OUT_WORD = re.compile(r'(?<![A-Za-z0-9_.\-])(say|put|print|printf)(?![A-Za-z0-9_\-])')
METHOD_OUT = re.compile(r'\.(say|put|print|printf)\b')
STDIN = re.compile(r'\$\*IN\b|(?<![A-Za-z0-9_\-])(get|lines|slurp|prompt)\s*\(')
BENCH = re.compile(r'(?<![A-Za-z0-9_])bench_', re.I)


def refuse(msg):
    sys.stderr.write('bench_wrap_raku.py: REFUSED: %s\n' % msg)
    sys.exit(2)


def code(l):
    """the line without a trailing # comment (a # inside a string is rare in these kernels; a false read only refuses)"""
    return l.split('#', 1)[0]


def block_end(lines, i):
    """index of the line closing the brace block that opens on line i (brace count over code text)"""
    depth = 0
    seen = False
    for j in range(i, len(lines)):
        c = code(lines[j])
        depth += c.count('{') - c.count('}')
        if '{' in c:
            seen = True
        if seen and depth <= 0:
            return j
    return None


def split(lines, path):
    uses, hoist, body = [], [], []
    i = 0
    while i < len(lines):
        l = lines[i]
        if USE.match(l):
            uses.append(l)
            i += 1
        elif DECL.match(l):
            if '{' in code(l) or (i + 1 < len(lines) and code(lines[i + 1]).lstrip().startswith('{')):
                j = block_end(lines, i)
                if j is None:
                    refuse('%s:%d: the declaration\'s brace block never closes' % (path, i + 1))
                if prints(lines[i:j + 1]):
                    body += lines[i:j + 1]
                else:
                    hoist += lines[i:j + 1]
                i = j + 1
            else:
                hoist.append(l)
                i += 1
        else:
            body.append(l)
            i += 1
    return uses, hoist, body


def cut(text, sep):
    """`text` cut at every `sep` outside quotes and outside the parens, brackets and braces opened within it, each part
    keeping the `sep` that ends it. Depth at or below zero still cuts: a line that closes a block opened above it
    (`}; say $x;`) separates its own statements."""
    parts, depth, q, cur = [], 0, None, ''
    i = 0
    while i < len(text):
        ch = text[i]
        if q:
            cur += ch
            if ch == '\\' and i + 1 < len(text):
                cur += text[i + 1]; i += 1
            elif ch == q:
                q = None
        elif ch in '"\'':
            q = ch; cur += ch
        elif ch in '([{':
            depth += 1; cur += ch
        elif ch in ')]}':
            depth -= 1; cur += ch
        elif ch == sep and depth <= 0:
            parts.append(cur + ch); cur = ''
        else:
            cur += ch
        i += 1
    parts.append(cur)
    return parts


def joined(expr):
    """`a, b, c` (top-level commas, outside parens, brackets, braces and quotes) as `(a) ~ (b) ~ (c)` -- print/say
    concatenate their arguments without a separator, where a list in string context would insert spaces."""
    parts = [p.rstrip(',').strip() for p in cut(expr, ',')]
    parts = [p for p in parts if p]
    return ' ~ '.join('(%s)' % p for p in parts) if len(parts) > 1 else '(%s)' % expr.strip()


def statements(c):
    """the statements of one line of code, cut at its top-level semicolons (CEO-1283: raku-bench's microbenchmark bodies
    are ONE line -- `my $i = 0; while (++$i <= 1024) { }; say $i;` -- so a trailing `say` is a whole output call only once
    the line is cut); a line holding one statement comes back whole."""
    return [p for p in cut(c, ';') if p.strip()]


def quiet_line(l, path, ln):
    c = code(l)
    if not OUT_WORD.search(c) and not METHOD_OUT.search(c):
        return l
    parts = statements(c)
    if len(parts) > 1:
        ind = c[:len(c) - len(c.lstrip())]
        return ind + ' '.join(quiet_line(p.strip(), path, ln) for p in parts)
    m = METHOD_LINE.match(c.rstrip())
    if m and METHOD_OUT.search(c):
        ind, expr, verb, mod = m.group(1), m.group(2), m.group(3), m.group(5) or ''
        nl = ' ~ "\\n"' if verb in ('say', 'put') else ''
        return '%s$bench_c = $bench_c ~ (%s)%s%s;' % (ind, expr, nl, mod)
    if METHOD_OUT.search(c):
        refuse('%s:%d: a .say/.print method form that is not a whole statement line: %r' % (path, ln, l.strip()))
    m = OUT_LINE.match(c.rstrip())
    if not m:
        refuse('%s:%d: an output call that is not a whole `say E;` / `put E;` / `print E;` line: %r' % (path, ln, l.strip()))
    ind, verb, expr, mod = m.group(1), m.group(2), m.group(3), m.group(4) or ''
    nl = ' ~ "\\n"' if verb in ('say', 'put') else ''
    return '%s$bench_c = $bench_c ~ %s%s%s;' % (ind, joined(expr), nl, mod)


def prints(block):
    return any(OUT_WORD.search(code(l)) or METHOD_OUT.search(code(l)) for l in block)


def generate(path, mode, n, bud_ms):
    try:
        lines = open(path, encoding='utf-8').read().split('\n')
    except OSError as e:
        refuse('cannot read %s: %s' % (path, e))
    for i, l in enumerate(lines, 1):
        c = code(l)
        if STDIN.search(c):
            refuse('%s:%d reads stdin -- a kernel that reads its input cannot be repeated' % (path, i))
        if BENCH.search(c):
            refuse('%s:%d uses an identifier spelled bench_... -- the wrapper\'s own names would collide with it' % (path, i))
    last = max((i for i, l in enumerate(lines) if code(l).strip()), default=None)
    if last is not None:
        c = code(lines[last]).rstrip()
        if not c.endswith((';', '{', '}', ',')):
            # the program's final statement needs no semicolon (`...; say $k` ends seven raku-bench bodies); once it is
            # wrapped inside a sub, more statements follow it, so it is terminated here
            lines[last] = c + ';' + lines[last][len(c):]
    uses, hoist, body = split(lines, path)
    quiet = [quiet_line(l, path, i + 1) for i, l in enumerate(body)]
    if not prints(body):
        refuse('%s: the kernel prints nothing at top level -- nothing to hold to the .ref' % path)
    if mode == 'iter':
        cond, tail = '$bench_k < %d' % n, ''
    else:
        cond, tail = '(wall_us() - $bench_t0) * 1000 < %d' % (bud_ms * 1000000), ' ~ " budget_ms=%d"' % bud_ms
    out = ['# GENERATED by harness/scripts/bench_wrap_raku.py --mode %s from %s -- never edited, never committed; the kernel is the' % (mode, path),
           '# pristine source (RULES.md THE KERNEL CONVENTION). The test runs once, then the quiet repetitions report on stderr.']
    out += uses + hoist
    out += ['sub bench_test() {'] + ['    ' + l for l in body] + ['}']
    out += ['sub bench_quiet() {', '    my $bench_c = "";'] + ['    ' + l for l in quiet] + ['    return $bench_c;', '}']
    out += ['bench_test();',
            'my $bench_want = bench_quiet();',
            'my int $bench_k = 0;',
            'my int $bench_bad = 0;',
            'my $bench_t0 = wall_us();',
            'while %s {' % cond,
            '    my $bench_got = bench_quiet();',
            '    if $bench_got ne $bench_want {',
            '        $bench_bad = $bench_bad + 1;',
            '    }',
            '    $bench_k = $bench_k + 1;',
            '}',
            'my $bench_ns = (wall_us() - $bench_t0) * 1000;',
            'note("BENCH mode=%s kernel=main iters=" ~ $bench_k ~ " ns=" ~ $bench_ns%s ~ " mismatched=" ~ $bench_bad ~ " value=" ~ $bench_want.chars);' % (mode, tail),
            'if $bench_bad > 0 {',
            '    say "BENCH-MISMATCH " ~ $bench_bad ~ " of " ~ $bench_k ~ " repetitions computed a value other than the first";',
            '}', '']
    return '\n'.join(out)


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('prog')
    ap.add_argument('--mode', required=True, choices=['iter', 'time'])
    ap.add_argument('--n', type=int, default=3)
    ap.add_argument('--bud-ms', type=int, default=200)
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
