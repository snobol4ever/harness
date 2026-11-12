#!/usr/bin/env python3
# util_cache_blast.py -- THE CACHE-MISS PRICE OF A TREE'S HISTORY (DESIGN-PLAN cache-tree, the cto, 2026-11-12, CTO-636; skill scrip-build reference section 4).
#
# Lon, 2026-11-12, in the cto's window: "We must MAXIMIZE sharing of the CACHE when we go to 32 JUNIORS and 16 SENIORS and 8 OFFICERS adn 4 BOSSES."
# Every seat builds through one ccache; a commit that reaches a seat's tree forces a recompile of every unit whose preprocessed text it changed, and
# a hit costs nothing. This prices that: for each commit since SINCE that touched src/, the units it forces (its own touched units, and every unit
# reaching a touched header, through the dependency graph the compiler reports for the tree as it stands), at each unit's measured compile
# instructions (util_unit_cost_census.sh). It is a projection of the history onto TODAY's graph: a file a later split deleted counts as no unit.
#
#   util_cache_blast.py --cost TSV [--root SCRIP] [--since DATE] [--top N] [--deps-from-d]
#   prints  CACHE_BLAST_BOARD commits=N units=N full_build_Ginstr=X history_Ginstr=X per_commit_Ginstr=X (tree <hash>)
#   then    commits  units/edit  Ginstr/edit  Ginstr_total  file      (one line per touched file, the costliest first)
#   --max-per-commit G   rc 1 when per_commit_Ginstr exceeds G (the plan's last probe)
# A unit with no price in TSV is priced at the median of the priced ones and counted in "unpriced=N". rc 2: no dependency graph, no cost table, no commit.
import argparse, collections, concurrent.futures, glob, os, shlex, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def compile_lines(root):
    r = subprocess.run(['make', '-B', '-n', 'build-all'], cwd=root, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit('REFUSE(2): make -B -n build-all failed in %s' % root)
    out = []
    for line in r.stdout.splitlines():
        if ' -c ' not in line:
            continue
        toks = shlex.split(line)
        if toks and toks[0] == 'ccache':
            toks = toks[1:]
        if '-c' not in toks or 'assembler' in line:
            continue
        src = toks[toks.index('-c') + 1]
        flags, i = [], 1
        while i < len(toks):
            x = toks[i]
            if x in ('-I', '-D', '-U', '-include', '-isystem', '-iquote') and i + 1 < len(toks):
                flags += [x, toks[i + 1]]; i += 2; continue
            if x.startswith(('-I', '-D', '-U', '-std=', '-finput-charset', '-include', '-isystem', '-iquote')):
                flags.append(x)
            i += 1
        out.append((toks[0], flags, src))
    return out


def rel(root, p):
    return os.path.relpath(p if os.path.isabs(p) else os.path.join(root, p), root)


def parse_d(root, text):
    first = text.replace('\\\n', ' ').split('\n', 1)[0]
    if ':' not in first:
        return None, []
    deps = first.split(':', 1)[1].split()
    return (rel(root, deps[0]), [rel(root, h) for h in deps[1:]]) if deps else (None, [])


def graph(root, from_d):
    reach, units = collections.defaultdict(set), set()
    if from_d:
        texts = [open(d).read() for d in glob.glob(os.path.join(root, 'out', 'rt_pic-*', '*.d'))]
    else:
        lines = compile_lines(root)
        def one(u):
            cc, flags, src = u
            return subprocess.run([cc, '-MM'] + flags + [src], cwd=root, capture_output=True, text=True).stdout
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
            texts = list(ex.map(one, lines))
    for t in texts:
        u, hs = parse_d(root, t)
        if u:
            units.add(u)
            for h in hs:
                reach[h].add(u)
    return units, reach


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cost', required=True)
    ap.add_argument('--root', default=os.path.join(os.environ['S4E_HOME'], 'SCRIP') if os.environ.get('S4E_HOME') else os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP')))
    ap.add_argument('--since', default='30 days ago')
    ap.add_argument('--top', type=int, default=40)
    ap.add_argument('--deps-from-d', action='store_true')
    ap.add_argument('--max-per-commit', type=float)
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    cost = {}
    try:
        for ln in open(a.cost):
            p = ln.rstrip('\n').split('\t')
            if len(p) >= 2 and p[1].isdigit():
                cost[rel(root, p[0])] = int(p[1])
    except OSError:
        sys.exit('REFUSE(2): no cost table %s' % a.cost)
    if not cost:
        sys.exit('REFUSE(2): the cost table %s prices no unit' % a.cost)
    units, reach = graph(root, a.deps_from_d)
    if len(units) < 50:
        sys.exit('REFUSE(2): the dependency graph names %d units' % len(units))
    med = sorted(cost.values())[len(cost) // 2]
    price = lambda u: cost.get(u, med)
    log = subprocess.run(['git', '-C', root, 'log', '--since=' + a.since, '--name-only', '--format=@@%h', '--', 'src'], capture_output=True, text=True).stdout
    commits = [(b.strip().split('\n')[0], [f for f in b.strip().split('\n')[1:] if f.strip()]) for b in log.split('@@')[1:]]
    if not commits:
        sys.exit('REFUSE(2): no commit touched src/ since %s' % a.since)
    per, tot = collections.defaultdict(lambda: [0, 0, 0]), 0
    for h, fs in commits:
        miss = set()
        for f in fs:
            m = ({f} if f in units else set()) | reach.get(f, set())
            per[f][0] += 1; per[f][1] += len(m); per[f][2] += sum(price(u) for u in m)
            miss |= m
        tot += sum(price(u) for u in miss)
    full = sum(price(u) for u in units)
    pc = tot / len(commits) / 1e9
    head = subprocess.run(['git', '-C', root, 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip()
    print('CACHE_BLAST_BOARD commits=%d units=%d unpriced=%d full_build_Ginstr=%.1f history_Ginstr=%.1f per_commit_Ginstr=%.2f (tree %s)' % (
        len(commits), len(units), len(units - set(cost)), full / 1e9, tot / 1e9, pc, head))
    print('commits\tunits/edit\tGinstr/edit\tGinstr_total\tfile')
    for f, (c, n, g) in sorted(per.items(), key=lambda kv: -kv[1][2])[:a.top]:
        print('%d\t%.1f\t%.2f\t%.1f\t%s' % (c, n / c, g / c / 1e9, g / 1e9, f))
    if a.max_per_commit is not None and pc > a.max_per_commit:
        print('CACHE_BLAST_RED per_commit_Ginstr=%.2f over %.2f' % (pc, a.max_per_commit))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
