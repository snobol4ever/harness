#!/usr/bin/env python3
# util_runner_outputs.py -- box-scheduler step 23 (the cqo, CTO-496; the shared-box skill's DESIGN section 8): runners default their outputs under
# /tmp/s4e/<seat> and delete them at the verdict. --check reads, over the runner population of a harness scripts directory (test_design_*_steps.sh,
# test_*_suite.sh, test_*_ladder.sh, test_smoke_*.sh, test_feature_reps.sh, corpus_suite_harness.py):
#   under_root          runners whose source sets an output default under a root (a .scratch path, a /home/claude_* literal, or an OUT/WORK/SCRATCH
#                       variable rooted at $ROOT/$HERE/$S4E_HOME/$SC that is not the SCRIP/out library directory); each is named
#   kept_after_verdict  runner_out directories a finished runner left: the plant (lib_runner_out.sh's runner_out_default in a child that exits)
#                       must be gone, plus every /tmp/s4e/<seat>/runner_out.<name>.<pid>.* whose pid is no longer alive; each is named
#   outside_seat        literal /tmp writes that bypass the seat directory (mktemp /tmp/..., > /tmp/...): reported, not gated
# Prints one line 'RUNNERS under_root=U kept_after_verdict=K runners=N outside_seat=O plant=green|red' then the names. rc 0 when U and K are 0,
# 1 otherwise, 2 when it cannot measure (no scripts directory, no runner); a tree with no lib_runner_out.sh reads the plant red.
# --list prints the population. --scripts DIR reads another tree's scripts (the fail-once proof reads origin's).
import argparse, glob, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
POP = re.compile(r'(test_design_.*_steps|test_.*_suite|test_.*_ladder|test_smoke_.*|test_feature_reps)\.sh|corpus_suite_harness\.py')
ROOTED = re.compile(r'^\s*(local\s+)?[A-Za-z_]*(OUT|WORK|SCRATCH)[A-Za-z_]*="?\$\{?(ROOT|HERE|S4E_HOME|S4E|SC|SCRIP)\b')
LIB_DIR = re.compile(r'/SCRIP/out"?\s*$')
TMP_LIT = re.compile(r'mktemp(\s+-d)?\s+/tmp/(?!s4e/)|[0-9]?>\s*/tmp/(?!s4e/)[A-Za-z]|mkdtemp\([^)]*dir=["\']/tmp["\']')
def population(d):
    return sorted(f for f in os.listdir(d) if POP.fullmatch(f) and os.path.isfile(os.path.join(d, f)))
def code_lines(p):
    try:
        L = open(p, errors='replace').read().split('\n')
    except OSError:
        return []
    return [(i + 1, l) for i, l in enumerate(L) if not re.match(r'\s*#', l)]
def under_root(p):
    hits = []
    for n, l in code_lines(p):
        if '${TMPDIR' in l:
            continue
        if re.search(r'["=\s]\$?\{?[A-Za-z_]*\}?/\.scratch\b|/home/claude_', l) and '=' in l:
            hits.append(n)
        elif ROOTED.search(l) and not LIB_DIR.search(l):
            hits.append(n)
    return hits
def outside_seat(p):
    return [n for n, l in code_lines(p) if TMP_LIT.search(l)]
def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
def orphans():
    out = []
    for d in glob.glob('/tmp/s4e/*/runner_out.*'):
        m = re.search(r'/runner_out\.[^/]*\.([0-9]+)\.[^./]+$', d)
        if m and os.path.isdir(d) and not alive(int(m.group(1))):
            out.append(d)
    return sorted(out)
def plant(d):
    lib = os.path.join(d, 'lib_runner_out.sh')
    if not os.path.isfile(lib):
        return False, 'no lib_runner_out.sh in %s: the mechanism is absent' % d
    sh = '. "$1" && runner_out_default plant && touch "$OUT/output" && printf "%s\\n" "$OUT"'
    r = subprocess.run(['bash', '-c', sh, 'plant', lib], capture_output=True, text=True, timeout=60)
    path = r.stdout.strip().split('\n')[-1] if r.stdout.strip() else ''
    if r.returncode != 0 or not path:
        return False, 'the plant made no directory (rc %d: %s)' % (r.returncode, r.stderr.strip()[:160])
    if not re.match(r'/tmp/s4e/[a-z0-9_]+/runner_out\.plant\.', path):
        return False, 'the plant made %s, not under /tmp/s4e/<seat>' % path
    if os.path.exists(path):
        return False, 'the plant left %s after its verdict' % path
    k = subprocess.run(['bash', '-c', sh, 'plant', lib], capture_output=True, text=True, timeout=60, env=dict(os.environ, S4E_KEEP_OUT='1'))
    kp = k.stdout.strip().split('\n')[-1] if k.stdout.strip() else ''
    kept = bool(kp) and os.path.isdir(kp)
    if kept:
        subprocess.run(['rm', '-rf', '--', kp])
    if not kept:
        return False, 'S4E_KEEP_OUT=1 did not keep the plant directory'
    return True, 'the plant made %s and it was gone at the verdict; S4E_KEEP_OUT=1 kept its twin' % path
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--scripts', default=HERE)
    a = ap.parse_args()
    d = os.path.abspath(a.scripts)
    if not os.path.isdir(d):
        print('REFUSE(2): no scripts directory %s' % d)
        return 2
    pop = population(d)
    if not pop:
        print('REFUSE(2): no runner in %s' % d)
        return 2
    if a.list:
        print('\n'.join(pop))
        return 0
    if not a.check:
        print('usage: util_runner_outputs.py --check | --list [--scripts DIR]')
        return 2
    ur = [(f, under_root(os.path.join(d, f))) for f in pop]
    ur = [(f, h) for f, h in ur if h]
    os_ = [(f, outside_seat(os.path.join(d, f))) for f in pop]
    os_ = [(f, h) for f, h in os_ if h]
    ok, why = plant(d)
    orph = orphans()
    kept = len(orph) + (0 if ok else 1)
    print('RUNNERS under_root=%d kept_after_verdict=%d runners=%d outside_seat=%d plant=%s' % (len(ur), kept, len(pop), sum(len(h) for _, h in os_), 'green' if ok else 'red'))
    print('  PLANT %s' % why)
    for f, h in ur:
        print('  UNDER-ROOT %s lines %s' % (f, ','.join(map(str, h))))
    for o in orph:
        print('  KEPT-AFTER-VERDICT %s' % o)
    for f, h in os_:
        print('  OUTSIDE-SEAT %s lines %s' % (f, ','.join(map(str, h))))
    return 0 if not ur and kept == 0 else 1
if __name__ == '__main__':
    sys.exit(main())
