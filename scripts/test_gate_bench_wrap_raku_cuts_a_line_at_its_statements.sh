#!/usr/bin/env bash
# ⛔⭐ THE RAKU WRAPPER GENERATOR CUTS A LINE AT ITS STATEMENTS BEFORE IT CLASSIFIES AN OUTPUT CALL (row instruments-bench-
# wrap-raku-loops-every-kernel-whose-single-shot-prints-its-ref-..., ceo CEO-1283). raku-bench's microbenchmark bodies are ONE
# line of several statements (`my $i = 0; while (++$i <= 1024) { }; say $i;`), and bench_wrap_raku.py classified output calls a
# whole line at a time, so it REFUSED 18 of the 37 kernels whose single shot prints its ref -- each graded FAIL on angles 2 and 3
# and never timed. The cure cuts a line at its top-level semicolons (outside quotes, parens, brackets and braces) and terminates
# a program's final statement, which Raku lets go without a semicolon.
# ⭐ PROVEN BY EXECUTION, HERMETIC, NO BUILD: fixture kernels in a mktemp directory go through generate() in ONE python process,
# and each quiet line is compared whole. The discriminator runs first: the whole-line classifier (OUT_LINE) must NOT match the
# one-line fixture -- a fixture the whole-line shape can classify would let the cut pass vacuously.
# EXIT 0 every arm holds; 1 an arm is red; 2 cannot measure (no generator, python unusable, a discriminator that cannot fail).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GEN="$HERE/bench_wrap_raku.py"
[ -f "$GEN" ] || { echo "⛔ REFUSE(2): no generator at $GEN"; exit 2; }
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
python3 - "$HERE" "$T" <<'PY'
import contextlib, io, os, sys
here, t = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
try:
    import bench_wrap_raku as g
except Exception as e:
    print("⛔ REFUSE(2): bench_wrap_raku.py does not import: %s" % e); sys.exit(2)
C = '$bench_c = $bench_c ~ '
ARMS = [
    ('one-line body: the trailing say after a semicolon is a whole output call',
     'my $i = 0; while (++$i <= 4) { }; say $i;', 'my $i = 0; while (++$i <= 4) { }; ' + C + '($i) ~ "\\n";'),
    ('the final statement needs no semicolon (the program ends there)',
     'my $k = 3; say $k', 'my $k = 3; ' + C + '($k) ~ "\\n";'),
    ('a semicolon inside the loop parens is not a statement boundary',
     'loop (my $i = 1; $i <= 3; ++$i) { }; say $i;', 'loop (my $i = 1; $i <= 3; ++$i) { }; ' + C + '($i) ~ "\\n";'),
    ('a semicolon inside a string is not a statement boundary',
     'my $s = "a;b"; say $s;', 'my $s = "a;b"; ' + C + '($s) ~ "\\n";'),
    ('two output calls on one line are two captures, not one say of a statement list',
     'say 1; print 2;', C + '(1) ~ "\\n"; ' + C + '(2);'),
    ('a multi-argument say after a semicolon still concatenates its arguments',
     'my $a = 1; say $a, "x";', 'my $a = 1; ' + C + '($a) ~ ("x") ~ "\\n";'),
]
if g.OUT_LINE.match(g.code(ARMS[0][1]).rstrip()):
    print("⛔ REFUSE(2): the whole-line classifier already matches %r -- the fixture cannot prove the cut" % ARMS[0][1]); sys.exit(2)
bad = 0
n = 0
def gen(src):
    p = os.path.join(t, 'k%d.raku' % n)
    with open(p, 'w') as f:
        f.write('# *BENCH kernel=k -- fixture\n' + src)
    try:
        return g.generate(p, 'iter', 2, 200), 0
    except SystemExit as e:
        return None, e.code
for name, src, want in ARMS:
    n += 1
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        text, rc = gen(src)
    if text is None:
        bad += 1; print("  RED  (%d) %s -- the generator REFUSED rc=%s: %s" % (n, name, rc, err.getvalue().strip()[:200])); continue
    lines = text.split('\n')
    q = lines.index('sub bench_quiet() {')
    got = lines[q + 3].strip() if q + 3 < len(lines) else ''
    tb = lines.index('sub bench_test() {')
    if got != want:
        bad += 1; print("  RED  (%d) %s\n       want: %s\n       got:  %s" % (n, name, want, got))
    elif lines[tb + 2].strip().rstrip(';') != src.rstrip(';'):
        bad += 1; print("  RED  (%d) %s -- the test body is not the kernel's own statement: %r" % (n, name, lines[tb + 2]))
    else:
        print("  ok   (%d) %s" % (n, name))
n += 1
err = io.StringIO()
with contextlib.redirect_stderr(err):
    text, rc = gen('for ^3 { say $_ };')
if rc == 2 and 'not a whole' in err.getvalue():
    print("  ok   (%d) a say inside a block is still REFUSED by name, never silently captured" % n)
else:
    bad += 1; print("  RED  (%d) a say inside a block was not refused (rc=%s): %s" % (n, rc, (text or err.getvalue())[:200]))
print("population: %d fixture arm(s) through generate(), 1 discriminator (the whole-line classifier cannot read arm 1)" % n)
if bad:
    print("⛔ GATE RED [bench_wrap_raku_cuts_a_line_at_its_statements]: %d of %d arm(s) red" % (bad, n)); sys.exit(1)
print("GATE PASS(0) [bench_wrap_raku_cuts_a_line_at_its_statements]: %d of %d arms hold" % (n, n))
PY
