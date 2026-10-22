#!/usr/bin/env bash
# util_population_asm_identity.sh -- ONE TREE AGAINST ANOTHER, BYTE FOR BYTE, OVER THE SPINE POPULATION (ARCH-THREE-ZETAS-EMISSION 10: every planner
# chunk landing is byte-identical on util_spine_population.sh, 274 of 274, against its parent; the cto, CEO-1923).
# Compiles every program of the population in mode 4 with this tree's binary and with the CONTROL binary (a worktree build of the parent), each
# compile through a cc slot (util_cc_slot.sh, CEO-1894), from the program's own directory with its declared compile args, and compares the two
# outputs whole. With --m3 it also runs every program in mode 3 under both binaries (its declared -d/-s and its .in stdin, each run in a run slot
# of the box-wide pool, corpus_suite_harness._bounded_run) and compares rc and stdout -- the answers, since mode 3 emits into a sealed slab.
#   util_population_asm_identity.sh --control PATH [--scrip PATH] [--lang L]... [--m3] [--m3-timeout S] [--jobs N] [--timeout S] [--names] [--files F...]
#   (--timeout bounds each compile, default 300 s; --m3-timeout each mode-3 run, default 90 s)
# Prints ASM_IDENTITY lang=<l>|total programs=<p> identical=<i> differ=<d> refused=<r> [m3_same=<s> m3_differ=<x> m3_refused=<y>]; with --names one
# ASM_IDENTITY_DIFFER / M3_DIFFER / REFUSED line per program. rc 0 when nothing differs and nothing refused; rc 1 when a program differs; rc 2 when it
# could not measure (no binary, no population, or a compile that fails or times out on either tree -- refused, never counted identical).
# This is a BOARD over 274 programs: a seat runs it only as a planner chunk's own proof (the chunk rows' receipts), the coo's loop otherwise.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 - "$HERE" "$@" <<'PY'
import collections, concurrent.futures, os, subprocess, sys, tempfile
HERE = sys.argv[1]
sys.path.insert(0, HERE)
import corpus_suite_harness as h
SCRIP = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP', 'scrip'))
EXT = {'.sno': 'snobol4', '.icn': 'icon', '.pl': 'prolog', '.pas': 'pascal', '.raku': 'raku', '.sc': 'snocone', '.reb': 'rebus'}


def refuse(msg):
    print('ASM_IDENTITY REFUSE(2): ' + msg)
    sys.exit(2)


a = sys.argv[2:]
control, langs, files, m3, jobs, timeout, m3_timeout, names = None, [], [], False, 6, 300, 90, False
i = 0
while i < len(a):
    if a[i] == '--control' and i + 1 < len(a):
        control = a[i + 1]; i += 2
    elif a[i] == '--scrip' and i + 1 < len(a):
        SCRIP = a[i + 1]; i += 2
    elif a[i] == '--lang' and i + 1 < len(a):
        langs.append(a[i + 1]); i += 2
    elif a[i] == '--jobs' and i + 1 < len(a):
        jobs = int(a[i + 1]); i += 2
    elif a[i] == '--timeout' and i + 1 < len(a):
        timeout = int(a[i + 1]); i += 2
    elif a[i] == '--m3':
        m3 = True; i += 1
    elif a[i] == '--m3-timeout' and i + 1 < len(a):
        m3_timeout = int(a[i + 1]); i += 2
    elif a[i] == '--names':
        names = True; i += 1
    elif a[i] == '--files':
        files = [os.path.abspath(f) for f in a[i + 1:]]; break
    else:
        refuse('usage: util_population_asm_identity.sh --control PATH [--scrip PATH] [--lang L]... [--m3] [--m3-timeout S] [--jobs N] [--timeout S] [--names] [--files F...]')
if not control:
    refuse('--control PATH is required (the parent tree\'s built scrip binary)')
for b in (SCRIP, control):
    if not (os.path.isfile(b) and os.access(b, os.X_OK)):
        refuse('no binary at ' + b)
if os.path.realpath(SCRIP) == os.path.realpath(control):
    refuse('the control and the subject are the same binary')
if files:
    pop = [(EXT.get(os.path.splitext(f)[1], '?'), f) for f in files]
else:
    r = subprocess.run(['bash', os.path.join(HERE, 'util_spine_population.sh')], capture_output=True, text=True)
    if r.returncode != 0:
        refuse('util_spine_population.sh rc %d' % r.returncode)
    pop = [tuple(l.split('\t', 1)) for l in r.stdout.splitlines() if '\t' in l]
pop = [p for p in pop if not langs or p[0] in langs]
if not pop:
    refuse('the population is empty')


def declared(prog):
    r = subprocess.run(['bash', '-c', '. "$1/lib_declared_arena.sh"; declared_switches_beside "$2" && echo "--CA--" && declared_compile_args_beside "$2" --compile-only', '-', HERE, prog],
                       capture_output=True, text=True)
    if r.returncode != 0 or '--CA--' not in r.stdout:
        return None, None, None
    sw, ca = r.stdout.split('--CA--', 1)
    decl, _src = h.cmdline_declarations(prog)
    ra = (decl.get(os.path.splitext(os.path.basename(prog))[0]) or ([], []))[1] or []
    return sw.split(), ca.split(), list(ra)


def compile_with(binary, prog, ca, out):
    try:
        c = subprocess.run(['bash', os.path.join(HERE, 'util_cc_slot.sh'), 'timeout', str(timeout), binary, '--compile'] + ca + [os.path.basename(prog), '-o', out],
                           cwd=os.path.dirname(prog), stdin=subprocess.DEVNULL, capture_output=True)
    except OSError as e:
        return None, 'compile could not start: %s' % e
    if c.returncode == 124:
        return None, 'compile timed out at %d s' % timeout
    return (c.returncode, open(out, 'rb').read() if os.path.isfile(out) else b''), None


def run_with(binary, prog, ca, sw, ra):
    stem = os.path.splitext(prog)[0]
    data = open(stem + '.in', 'rb').read() if os.path.isfile(stem + '.in') else None
    rc, out, err, why = h._bounded_run([binary, '--run'] + ca + sw + [os.path.basename(prog)] + (['--'] + ra if ra else []), m3_timeout, os.path.dirname(prog), None, data, False)
    return rc, out or b'', why


both_fail = []


def measure(p):
    lang, prog = p
    sw, ca, rargs = declared(prog)
    if sw is None:
        return lang, prog, 'refused', 'its declared switches were refused (lib_declared_arena.sh)', None
    with tempfile.TemporaryDirectory(prefix='asmid.') as t:
        (ra, wa), (rb, wb) = compile_with(SCRIP, prog, ca, os.path.join(t, 'a.s')), compile_with(control, prog, ca, os.path.join(t, 'b.s'))
        if wa or wb:
            return lang, prog, 'refused', wa or wb, None
        same = ra == rb
        if same and ra[0] != 0:
            both_fail.append('ASM_IDENTITY_BOTH_REFUSE lang=%s prog=%s rc=%d' % (lang, prog, ra[0]))
    m3r = None
    if m3:
        ra, rb = run_with(SCRIP, prog, ca, sw, rargs), run_with(control, prog, ca, sw, rargs)
        if ra[2] or rb[2]:
            m3r = ('refused', 'mode 3 %s' % (ra[2] or rb[2]))
        else:
            m3r = ('same', '') if (ra[0], ra[1]) == (rb[0], rb[1]) else ('differ', 'rc %d vs %d, stdout %s' % (ra[0], rb[0], 'equal' if ra[1] == rb[1] else 'differs'))
    return lang, prog, 'identical' if same else 'differ', '', m3r


cnt = collections.defaultdict(collections.Counter)
lines = []
with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
    for lang, prog, verdict, why, m3r in ex.map(measure, pop):
        cnt[lang][verdict] += 1
        if verdict == 'differ':
            lines.append('ASM_IDENTITY_DIFFER lang=%s prog=%s' % (lang, prog))
        elif verdict == 'refused':
            lines.append('ASM_IDENTITY_REFUSED lang=%s prog=%s why=%s' % (lang, prog, why))
        if m3r:
            cnt[lang]['m3_' + m3r[0]] += 1
            if m3r[0] != 'same':
                lines.append('M3_%s lang=%s prog=%s %s' % (m3r[0].upper(), lang, prog, m3r[1]))
if names:
    for l in sorted(lines + both_fail):
        print(l)
tot = collections.Counter()
for lang in sorted(cnt):
    c = cnt[lang]
    tot.update(c)
    print('ASM_IDENTITY lang=%s programs=%d identical=%d differ=%d refused=%d%s' % (lang, sum(c[k] for k in ('identical', 'differ', 'refused')), c['identical'], c['differ'], c['refused'],
          (' m3_same=%d m3_differ=%d m3_refused=%d' % (c['m3_same'], c['m3_differ'], c['m3_refused'])) if m3 else ''))
print('ASM_IDENTITY total programs=%d identical=%d differ=%d refused=%d%s (subject %s, control %s)' % (sum(tot[k] for k in ('identical', 'differ', 'refused')), tot['identical'], tot['differ'],
      tot['refused'], (' m3_same=%d m3_differ=%d m3_refused=%d' % (tot['m3_same'], tot['m3_differ'], tot['m3_refused'])) if m3 else '', SCRIP, control))
if tot['refused'] or tot['m3_refused']:
    sys.exit(2)
sys.exit(1 if tot['differ'] or tot['m3_differ'] else 0)
PY
