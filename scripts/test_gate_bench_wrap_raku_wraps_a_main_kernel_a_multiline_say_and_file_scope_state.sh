#!/usr/bin/env bash
# ⛔⭐ THE RAKU WRAPPER GENERATOR WRAPS A KERNEL THAT DEFINES sub MAIN, PRINTS A STRING THAT RUNS OVER LINES, ENDS A BLOCK ON AN OUTPUT STATEMENT WITH NO SEMICOLON, PRINTS THE
# TOPIC WITH A BARE .say, READS A NAMED FILE, AND KEEPS THE FILE-SCOPE STATE ITS HOISTED SUBS READ (row raku-every-suite-to-100-under-nonet-ceo-1266, RakBench 68 of 80;
# hq_raku 2026-10-21 against SCRIP 218731c54). THE REDS, measured on the coo's board at SCRIP e06e1d5e3 and again by hand: twelve kernels read FAIL on the fixed-iterations and
# fixed-time angles, and eleven of them were the generator's: (1) spinner, rc-forest-fire, rc-forest-fire-stringify, rc-mandelbrot: the kernel's `sub MAIN` was nested in the
# wrapper subs and never called, so the capture was empty (value=0 where the .ref has 536704 characters); (2) rc-dragon-curve: one `say "..."` whose string runs over five lines
# was refused ("not a whole say E; line"); (3) rc-mandelbrot: `print "\n"` as the last statement of a block has no semicolon and was refused; (4) rc-self-describing-numbers:
# `.say if ... for ...` printed the empty list, so the capture held two characters of ten; (5) parse-json and parse-json-no-obj-creation: `slurp($json-file)` reads a NAMED
# FILE beside the kernel, not stdin, and was refused as stdin; (6) rc-9-billion-names and rc-forest-fire: the hoisted subs read file-scope `my` variables that the generator moved
# into the wrapper subs, so the hoisted code saw other variables (the test run's own stdout differed from the .ref).
# THE CURE (bench_wrap_raku.py): a `sub MAIN` is kept out of the generated program as MAIN and enters twice, renamed -- bench_tmain (verbatim, called last by bench_test, so the
# test's stdout is the .ref and the repetitions cannot advance state the test then reads) and bench_qmain (its output calls rewritten to captures, called by bench_quiet); an
# output line whose string literal is still open at its end pulls the next lines in, newlines kept; an output line followed by a line opening with `}` is terminated (an
# OUTPUT line only: the last item of a multi-line hash literal reads the same and stays as written); `.say` with no receiver captures `$_`; only `slurp()` with no argument and `$*IN`
# are stdin; a file-scope `my` a hoisted declaration READS and does not declare itself is declared once at file scope (untyped) and its statement becomes an assignment, so every
# repetition starts again from it.
# ⭐ PROVEN BY EXECUTION, HERMETIC, NO BUILD: fixture kernels in a mktemp directory go through generate() in ONE python process and each generated program is compared by line.
# ⭐ IT CAN FAIL, AND DID: BENCH_WRAP_GEN=<a generator file> points the gate at another generator (an instrument's own switch, never a seam in SCRIP); run against the generator
# of harness 9f372d9 (the commit before the cure) arms 1 to 5 and 7 read RED (6 of 11) and arms 6, 8, 9, 10 and 11 hold, because they pin behaviour the cure must not move.
# EXIT 0 every arm holds; 1 an arm is red; 2 cannot measure (no generator, python unusable).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GEN="${BENCH_WRAP_GEN:-$HERE/bench_wrap_raku.py}"
[ -f "$GEN" ] || { echo "⛔ REFUSE(2): no generator at $GEN"; exit 2; }
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
python3 - "$GEN" "$T" <<'PY'
import contextlib, importlib.util, io, os, sys
gen_path, t = sys.argv[1], sys.argv[2]
try:
    spec = importlib.util.spec_from_file_location("bench_wrap_raku_under_test", gen_path)
    g = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(g)
except Exception as e:
    print("⛔ REFUSE(2): %s does not import: %s" % (gen_path, e)); sys.exit(2)
HEAD = '# *BENCH kernel=k -- fixture\n'
n = 0
def gen(src):
    global n
    n += 1
    p = os.path.join(t, 'k%d.raku' % n)
    with open(p, 'w') as f:
        f.write(HEAD + src)
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err):
            return g.generate(p, 'iter', 2, 200), 0, ''
    except SystemExit as e:
        return None, e.code, err.getvalue().strip()[:160]
bad = 0
def arm(name, ok, why=''):
    global bad
    if ok:
        print('  ok   %s' % name)
    else:
        bad += 1
        print('  RED  %s%s' % (name, (' -- ' + why) if why else ''))
def lines_of(text): return text.split('\n') if text else []
Q = '$bench_c = $bench_c ~ '

text, rc, why = gen('sub MAIN(Int $n = 3) {\n    say $n;\n}\n')
L = lines_of(text)
arm('(1) a sub MAIN kernel: bench_tmain and bench_qmain, no sub MAIN, the test called last and the repetition quiet',
    text is not None and 'sub bench_tmain(Int $n = 3) {' in L and 'sub bench_qmain(Int $n = 3) {' in L and not any(l.startswith('sub MAIN') for l in L)
    and '    ' + Q + '($n) ~ "\\n";' in L and '    bench_tmain();' in L and '    bench_qmain();' in L, 'generator REFUSED rc=%s %s' % (rc, why) if text is None else 'the wrapper does not carry the renamed pair')
text, rc, why = gen('say "a\nb";\n')
arm('(2) a say whose string runs over two lines is one capture with the newline kept',
    text is not None and '    ' + Q + '("a\nb") ~ "\\n";' in text and '    say "a\nb";' in text, 'generator REFUSED rc=%s %s' % (rc, why) if text is None else 'the literal is not carried whole')
text, rc, why = gen('for 1..2 {\n    print "x"\n}\n')
L = lines_of(text)
arm('(3) an output statement with no semicolon before the closing brace is captured',
    text is not None and '        ' + Q + '("x");' in L and '        print "x";' in L, 'generator REFUSED rc=%s %s' % (rc, why) if text is None else 'the capture line is missing')
text, rc, why = gen('.say if $_ > 1 for 1..3;\n')
L = lines_of(text)
arm('(4) a bare .say captures the topic',
    text is not None and '    ' + Q + '($_) ~ "\\n" if $_ > 1 for 1..3;' in L, 'generator REFUSED rc=%s %s' % (rc, why) if text is None else 'the capture of the topic is missing')
text, rc, why = gen('my $seed = 42;\nsub f { $seed = $seed + 1; $seed }\nsay f();\n')
L = lines_of(text)
decl = L.index('my $seed;') if 'my $seed;' in L else -1
sub = L.index('sub f { $seed = $seed + 1; $seed }') if 'sub f { $seed = $seed + 1; $seed }' in L else -1
arm('(5) a file-scope variable a hoisted sub reads stays at file scope and every repetition re-initialises it',
    text is not None and 0 <= decl < sub and L.count('    $seed = 42;') == 2 and not any('my $seed = 42' in l for l in L), 'generator REFUSED rc=%s %s' % (rc, why) if text is None else 'declared at %d, sub at %d, assignments %d' % (decl, sub, L.count('    $seed = 42;')))
text, rc, why = gen('my $n = 5;\nsub g($n) { $n }\nsay g($n);\n')
L = lines_of(text)
arm('(6) a sub that declares its own $n as a parameter does not hoist the file-scope $n',
    text is not None and 'my $n;' not in L and L.count('    my $n = 5;') == 2, 'generator REFUSED rc=%s %s' % (rc, why) if text is None else 'the file-scope $n was hoisted over the sub\'s own')
text, rc, why = gen('my $t = slurp("data.txt");\nsay $t.chars;\n')
arm('(7) slurp of a named file is not stdin', text is not None, 'REFUSED rc=%s %s' % (rc, why))
text, rc, why = gen('my $t = slurp();\nsay $t.chars;\n')
arm('(8) slurp() with no argument is still stdin, REFUSED by name', text is None and rc == 2 and 'reads stdin' in why, 'rc=%s %s' % (rc, why))
text, rc, why = gen('my $l = $*IN.get;\nsay $l;\n')
arm('(9) $*IN is still stdin, REFUSED by name', text is None and rc == 2 and 'reads stdin' in why, 'rc=%s %s' % (rc, why))
text, rc, why = gen('my %h = {\n    a => 1,\n    b => 2\n};\nsay %h<a>;\n')
L = lines_of(text)
arm('(10) the last item of a multi-line hash literal is left as written (no semicolon added)',
    text is not None and L.count('        b => 2') == 2 and not any(l.rstrip().endswith('b => 2;') for l in L), 'generator REFUSED rc=%s %s' % (rc, why) if text is None else 'a semicolon was added inside the literal')
text, rc, why = gen('my $r = 1;\nfor 1..2 {\n    say $r;\n}\n')
arm('(11) a say inside a block is still captured whole (unchanged)', text is not None and '        ' + Q + '($r) ~ "\\n";' in lines_of(text), 'REFUSED rc=%s %s' % (rc, why))
print('population: 11 fixture arm(s) through generate(), %s' % gen_path)
if bad:
    print('GATE FAIL(1) [bench_wrap_raku_wraps_a_main_kernel_a_multiline_say_and_file_scope_state]: %d of 11 arms red' % bad); sys.exit(1)
print('GATE PASS(0) [bench_wrap_raku_wraps_a_main_kernel_a_multiline_say_and_file_scope_state]: 11 of 11 arms hold'); sys.exit(0)
PY
