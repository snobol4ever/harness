#!/usr/bin/env python3
# util_gc_rule12_residual_census.py -- THE RESIDUAL OF THE TOLD WALK AT RULE-1 AND RULE-2 SITES (ARCH-GC-COMPILE-TIME-FRAME-MAPS 16.1 (d) and 16.3, the cto 2026-10-31; zeta-layout step 4a-3).
# Runs the gc_witnesses of a language in mode 3 under SCRIP_GC_STRESS=<n> and SCRIP_GC_CHAIN_CHECK=3, whose census (gc_told_window) compares the 16-byte-unit search with the planner's
# declarations at every rule-1 and rule-2 site, and sums the SEARCH-ONLY words of those two rules (SO-RULES r1 + r2): the words the search accepted that no declaration names.
# Prints per language and stress  RULE12_PROGRAMS lang=<lang> stress=<n> programs=<p> refused=<r>  and  RULE12_RESIDUAL lang=<lang> stress=<n> residual=<k>  (the line ends with the
# residual, the DONE-WHEN reads residual=0$; it reads residual=refused when any program was refused, so a refusal is never a zero), then the programs that carry the residual (largest first). A program killed by a signal or by --timeout (rc < 0 or >= 128) is REFUSED, counted and named,
# never read as residual 0. rc 0 always when it measured; rc 2 when it cannot (no scrip, no witnesses).
# usage: util_gc_rule12_residual_census.py --langs raku,prolog,icon --stress 1,3 [--timeout 300] [--jobs 4] [--limit N]
import argparse, os, re, subprocess, sys, concurrent.futures

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SCRIP = os.path.join(ROOT, 'SCRIP')
GCW = os.path.join(HERE, 'gc_witnesses')
EXT = {'raku': '.raku', 'prolog': '.pl', 'icon': '.icn', 'snobol4': '.sno', 'pascal': '.pas'}
SO = re.compile(r'^\[GC-TOLD\] SO-RULES r0=(\d+) r1=(\d+) r2=(\d+)')

def run_one(path, stress, timeout):
    env = dict(os.environ)
    env.pop('SCRIP_HEAP_MB', None)
    env.update({'SCRIP_GC_CHAIN_CHECK': '3', 'SCRIP_GC_STRESS': str(stress), 'SCRIP_HEAP_KB': '128', 'SCRIP_HEAP_MAX_MB': '512'})
    inp = os.path.splitext(path)[0] + '.in'
    stdin = open(inp, 'rb') if os.path.exists(inp) else subprocess.DEVNULL
    cmd = [os.path.join(SCRIP, 'scrip'), '-d131072k', '-s4096k', path]
    slot = os.path.join(HERE, 'util_run_slot.sh')
    if os.path.exists(slot):
        cmd = ['bash', slot] + cmd
    r1 = r2 = 0
    p = subprocess.Popen(cmd, stdin=stdin, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, env=env, cwd=SCRIP, start_new_session=True)
    try:
        import threading
        timer = threading.Timer(timeout, lambda: os.killpg(p.pid, 9))
        timer.start()
        for raw in p.stderr:
            m = SO.match(raw.decode('utf-8', 'replace'))
            if m:
                r1 += int(m.group(2)); r2 += int(m.group(3))
        rc = p.wait()
        timer.cancel()
    except Exception as e:
        try:
            os.killpg(p.pid, 9)
        except Exception:
            pass
        return os.path.basename(path), None, 'exception %s' % e
    if stdin is not subprocess.DEVNULL:
        stdin.close()
    if rc < 0 or rc >= 128:
        return os.path.basename(path), None, 'rc=%d' % rc
    return os.path.basename(path), (r1, r2), ''

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--langs', default='raku,prolog,icon')
    ap.add_argument('--stress', default='1,3')
    ap.add_argument('--timeout', type=int, default=300)
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--limit', type=int, default=0)
    a = ap.parse_args()
    if not os.access(os.path.join(SCRIP, 'scrip'), os.X_OK):
        print('REFUSE(2): %s/scrip is not built' % SCRIP); return 2
    for lang in a.langs.split(','):
        if lang not in EXT:
            print('REFUSE(2): unknown language %s' % lang); return 2
        progs = sorted(os.path.join(GCW, f) for f in os.listdir(GCW) if f.endswith(EXT[lang]))
        if a.limit:
            progs = progs[:a.limit]
        if not progs:
            print('REFUSE(2): no gc_witnesses for %s' % lang); return 2
        for st in a.stress.split(','):
            res = []
            with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as ex:
                for r in ex.map(lambda p: run_one(p, st, a.timeout), progs):
                    res.append(r)
            tot = sum(v[0] + v[1] for _, v, _ in res if v)
            refused = [(n, why) for n, v, why in res if v is None]
            print('RULE12_PROGRAMS lang=%s stress=%s programs=%d refused=%d' % (lang, st, len(progs), len(refused)))
            print('RULE12_RESIDUAL lang=%s stress=%s residual=%s' % (lang, st, 'refused' if refused else str(tot)))
            for n, v, _ in sorted((r for r in res if r[1]), key=lambda r: -(r[1][0] + r[1][1]))[:8]:
                if v[0] + v[1]:
                    print('    %-52s r1=%d r2=%d' % (n, v[0], v[1]))
            for n, why in refused:
                print('    REFUSED %-44s %s' % (n, why))
            sys.stdout.flush()
    return 0

sys.exit(main())
