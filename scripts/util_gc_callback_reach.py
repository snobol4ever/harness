#!/usr/bin/env python3
"""util_gc_callback_reach.py [--tsv OUT] [--timeout S] [--quiet] [PROGRAM ...]

THE LIVE COUNT OF THE CALLBACK WRAPS (row gc-the-forty-nine-callback-wrap-sites-carry-rt-gc-callback-and-the-count-is-live-not-
static, the cfo, 2026-09-28; ceo CEO-1040/1041).  Every C site that calls back into user code carries RT_GC_CALLBACK or
RT_GC_CALLBACK_V (src/runtime/rt/gc_heap.h), whose close, rt_gc_cb_close(mark, __FILE__, __LINE__, lo, hi), reports raw arena
words left live in an unmapped C frame across a collection (Rule 4).  util_gc_acceptance.py counts those wraps STATICALLY, and a
static count cannot tell "every site wrapped" from "no site ever run": a wrap nothing reaches guards nothing a witness can see.

THIS READER measures reach, with NO runtime change: it runs each program under gdb with a silent breakpoint on rt_gc_cb_close and
prints the file and line argument of every close -- the same two values the macro passes -- so a site is REACHED only when a
real callback through it returned.  No getenv on the callback path, no new static (RULES.md no-new-globals), nothing to switch
off in the shipped build.

  STATIC  every RT_GC_CALLBACK( / RT_GC_CALLBACK_V( invocation under src/runtime (not the #define), with its enclosing function.
  LIVE    each PROGRAM (default: every witness in ../harness/scripts/gc_witnesses) is run in mode 3 from a scratch working directory (a
          witness that names a relative file writes there, not in the checkout), stdin from its .in beside it when one exists,
          under `gdb -batch`, SCRIP_GC_STRESS=1 and the shipped window, one at a time.
  REPORT  population (programs run, programs whose run reached the breakpoint at all, events), REACHED n of N with each reached
          site's event count, every UNREACHED site named by file:line and function, and any event at a line the static list
          does not hold (UNLISTED: the static grep missed a spelling, or the binary is not this tree's).

PLANT (the gate's fail-once, reader-side only, nothing in the runtime): CB_REACH_PLANT_NO_PENDING=1 drops `set breakpoint pending on`,
which leaves the breakpoint unset, so a run that reached callbacks must REFUSE rc 2.

EXIT: 0 measured; 2 REFUSED -- the binary is stale against src/ (util_require_fresh.sh), gdb is missing, or the whole population
produced ZERO close events (a census over which the instrument saw nothing is a blindfold, never "0 reached"); 1 an UNLISTED
event (the static list and the binary disagree about where the wraps are).
"""
import glob, os, re, subprocess, sys, tempfile
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
SCRIP = os.environ.get('SCRIP_BIN', os.path.join(ROOT, 'scrip'))
EXTS = ('.sno', '.icn', '.pl', '.raku', '.pas', '.sc', '.reb')
GDB = """set pagination off
set confirm off
set breakpoint pending on
break rt_gc_cb_close
commands
silent
printf "[GC-CB-SITE] %s:%d\\n", file, line
continue
end
run
"""
INV = re.compile(r'RT_GC_CALLBACK(?:_V)?\(')
FN = re.compile(r'^(?:[A-Za-z_][A-Za-z0-9_]*[ \t*]+)+\**([A-Za-z_][A-Za-z0-9_]*)\s*\(')


def static_sites():
    sites = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'src/runtime/**/*.c'), recursive=True)):
        rel = os.path.relpath(path, ROOT); fn = '-'
        for i, l in enumerate(open(path, errors='replace').read().split('\n'), 1):
            m = FN.match(l)
            if m and not l.startswith((' ', '\t')) and m.group(1) not in ('if', 'for', 'while', 'switch', 'return', 'sizeof'): fn = m.group(1)
            if INV.search(l) and '#define' not in l: sites[(rel, i)] = fn
    return sites


def run_one(prog, timeout, script):
    d = tempfile.mkdtemp(prefix='cb_reach.')
    stem = os.path.splitext(prog)[0]; inp = stem + '.in'
    env = dict(os.environ); env.pop('SCRIP_HEAP_MB', None); env.pop('SCRIP_HEAP_KB', None); env['SCRIP_GC_STRESS'] = '1'
    env.setdefault('SNO_LIB', os.path.join(os.path.dirname(ROOT), 'corpus', 'include'))
    try:
        with open(inp if os.path.isfile(inp) else os.devnull) as fin:
            r = subprocess.run(['gdb', '-q', '-batch', '-x', script, '--args', SCRIP, prog], stdin=fin, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, cwd=d, env=env, timeout=timeout)
        out = r.stdout.decode(errors='replace')
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b'').decode(errors='replace') + '\n[CB-REACH-TIMEOUT]\n'
    finally:
        subprocess.run(['rm', '-rf', d])
    ev = [m.group(1) for m in re.finditer(r'^\[GC-CB-SITE\] (\S+):(\d+)$', out, re.M)]
    ln = [int(m.group(2)) for m in re.finditer(r'^\[GC-CB-SITE\] (\S+):(\d+)$', out, re.M)]
    return [(os.path.relpath(f, ROOT) if os.path.isabs(f) else f, n) for f, n in zip(ev, ln)], ('[CB-REACH-TIMEOUT]' in out)


def main(argv):
    tsv = None; timeout = 120; quiet = False; progs = []
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == '--tsv': tsv = argv[i + 1]; i += 2; continue
        if a == '--timeout': timeout = int(argv[i + 1]); i += 2; continue
        if a == '--quiet': quiet = True; i += 1; continue
        progs.append(os.path.abspath(a)); i += 1
    fr = subprocess.run(['bash', os.path.join(HERE, 'util_require_fresh.sh'), '--gate', 'util_gc_callback_reach'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if fr.returncode != 0:
        print('CB-REACH REFUSE(2): the binary is not current against this tree -- make first (a hand-run binary bypasses the guard, and '
              'a stale one reports lines the source no longer has)'); print(fr.stdout.decode(errors='replace')[-400:]); return 2
    if subprocess.run(['sh', '-c', 'command -v gdb'], stdout=subprocess.DEVNULL).returncode != 0:
        print('CB-REACH REFUSE(2): gdb is not installed -- the reach cannot be read'); return 2
    if not progs:
        progs = sorted(p for p in glob.glob(os.path.join(ROOT, '../harness/scripts/gc_witnesses/*')) if p.endswith(EXTS))
    sites = static_sites()
    gdb = GDB.replace('set breakpoint pending on\n', '') if os.environ.get('CB_REACH_PLANT_NO_PENDING') == '1' else GDB
    script = tempfile.NamedTemporaryFile('w', suffix='.gdb', delete=False); script.write(gdb); script.close()
    hits = Counter(); reached_by = {}; ran = hitprogs = timeouts = 0; timed = []
    for p in progs:
        ev, to = run_one(p, timeout, script.name); ran += 1; timeouts += to
        if to: timed.append(os.path.basename(p))
        if ev: hitprogs += 1
        for s in ev:
            hits[s] += 1; reached_by.setdefault(s, os.path.basename(p))
    os.unlink(script.name)
    total = sum(hits.values())
    print('CB-REACH population: %d program(s) run, %d reached a callback, %d timed out, %d close event(s); static wraps: %d site(s)' % (ran, hitprogs, timeouts, total, len(sites)))
    if total == 0:
        print('CB-REACH REFUSE(2): ZERO close events over the whole population -- the breakpoint never fired, so this run measured nothing '
              '(an empty population, a binary without the wraps, or gdb unable to read the arguments); it is not "0 reached"'); return 2
    unl = sorted(s for s in hits if s not in sites)
    reached = sorted(s for s in sites if s in hits); unreached = sorted(s for s in sites if s not in hits)
    print('CB-REACH REACHED %d of %d wrapped site(s); UNREACHED %d; UNLISTED %d' % (len(reached), len(sites), len(unreached), len(unl)))
    if not quiet:
        for s in reached: print('  REACHED   %s:%d %-40s events=%d first=%s' % (s[0], s[1], sites[s], hits[s], reached_by[s]))
        for s in unreached: print('  UNREACHED %s:%d %s' % (s[0], s[1], sites[s]))
    for t in timed: print('  TIMEOUT   %s -- ran past %d s under gdb; its reach is counted only up to the cut, a partial reading' % (t, timeout))
    for s in unl: print('  UNLISTED  %s:%d events=%d -- a close from a line the static list does not hold' % (s[0], s[1], hits[s]))
    if tsv:
        with open(tsv, 'w') as f:
            f.write('file\tline\tfunction\tevents\tfirst_program\n')
            for s in sorted(sites): f.write('%s\t%d\t%s\t%d\t%s\n' % (s[0], s[1], sites[s], hits.get(s, 0), reached_by.get(s, '-')))
    return 1 if unl else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
