#!/bin/bash
# util_unbacked_read_census.sh -- THE UNBACKED-READ CENSUS: EVERY CELL SITE 1 OF .github/PRECARVE-WHACK-LIST.md LEAVES WITH NO STORAGE, BY BOX KIND, IN ONE COMPILE PASS
# (ceo CEO-1948; row zeta-the-unbacked-read-census-names-every-cell-site-1-exposes-by-box-kind-in-one-compile-pass-ceo-1948).
#
# WHAT IT MEASURES. When a graph is put on the home frame, a key past the home frame's resident region has no frame bytes behind it, and x86_zop
# (src/templates/x86/x86_asm.h, zls_key_unbacked) aborts at the FIRST read of one -- one name per compile, so the work list of a switch stayed hidden
# behind its first scream. This instrument builds a SCRATCH copy of a named SCRIP ref in which that abort is swapped for one stderr line and the
# compile continues:
#     UNBACKED op=<bb_op_name of the box that reads the cell> off=<the key offset>
# The swap is applied to the scratch worktree by this script and NEVER committed to SCRIP (CEO-1680: no seam in SCRIP's own code; the patch lives
# here, in the instrument). It then compiles every MASTER entry of every language (corpus/tests/<lang>/ALL.csv, each entry extracted by
# corpus_suite_harness.py extract WITH its stdin sidecar, so a stdin-bearing entry is graded too) as `./scrip --compile -o /dev/null <entry>`: no run,
# no oracle, no link; an entry's companion files (-INCLUDE, $include, consult) are copied beside it by the suite harness's own _copy_companions, and SNO_LIB is the corpus include directory the grader sets. At most 8 workers (--workers), each child under `ulimit -v 8000000` and `ulimit -c 0` and a box-wide run slot
# (corpus_suite_harness._bounded_run, CEO-1894), a 30 s timeout (--timeout). A compile's compile_args (--stlimit) are not passed: they are run-time knobs.
#
#   util_unbacked_read_census.sh [--ref REF] [--lang L]... [--workers N] [--timeout S] [--tsv FILE] [--verbose] [--clean]
#     --ref      the SCRIP ref to measure (default origin/main); a bare branch name also tries origin/<name>, and an unresolved ref is fetched once from origin
#     --lang     narrow to one language (snobol4 icon prolog raku pascal snocone rebus), repeatable
#     --tsv      write every read as lang<TAB>entry<TAB>op<TAB>off (the per-site work list a switch cures)
#     --verbose  one UNBACKED_PROG line per screaming program
#     --clean    remove every scratch root of this instrument and prune the worktrees; measures nothing
#   UNBACKED_BOARD lang=<l> programs=<n> screaming=<s> reads=<r>            per language: entries compiled, entries with at least one read, reads
#   UNBACKED_KIND  lang=<l> op=<op> reads=<r> programs=<p>                  per language and box kind, most reads first
#   UNBACKED_BASE  lang=<l> reads=<r> kinds=<k>                             what an EMPTY source of that language reads (Prolog's runtime prelude, which every Prolog program carries
#                                                                           once: reads of a Prolog board are programs x base plus UNBACKED_OWN); printed only when above 0
#   UNBACKED_OWN   lang=<l> reads=<r> programs=<p>                          the reads past the baseline, summed per program, and the programs that have any
#   UNBACKED_NOTE  lang=<l> compile_rc_nonzero=<n> hang=<h> first=<entry> err="<its first stderr line>"   a compile that failed for ANY reason is counted, never read as clean
#   UNBACKED_ROOT  ref=<ref> sha=<sha> root=<path>                          where the scratch build is (reused by the next run on the same sha)
#   rc 0  the census measured (reads > 0 is a reading, not a failure: the board is the answer)
#   rc 2  could not measure: the ref does not resolve, the abort is not in that ref's x86_asm.h, the build failed, or no entry extracted
#
# THE SCRATCH ROOT is <root>/.scratch/unbacked-census/<sha12>/{SCRIP,harness,corpus}, three git worktrees side by side (no symlink, ever): SCRIP at
# the ref, harness and corpus at the calling root's HEAD, the corpus sparse (tests, library, include, packages/icon: the compiler reaches
# <exe>/../corpus/packages/icon/ipl and corpus/library, SNO_LIB names corpus/include). The build is incremental on the same sha; a root unused for 24 h is removed by the next run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 - "$HERE" "$@" <<'PY'
import argparse, collections, concurrent.futures, fcntl, os, re, shutil, subprocess, sys, time
HERE = sys.argv[1]
sys.path.insert(0, HERE)
import corpus_suite_harness as h
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
REPO = {n: os.path.join(ROOT, n) for n in ('SCRIP', 'harness', 'corpus')}
SCRATCH = os.path.join(ROOT, '.scratch', 'unbacked-census')
MASTERS = (('snobol4', 'sno'), ('icon', 'icn'), ('prolog', 'pl'), ('raku', 'raku'), ('pascal', 'pas'), ('snocone', 'sc'), ('rebus', 'reb'))
ABORT = re.compile(r'\{ fprintf\(stderr,\s*"FATAL x86_zop: offset %d is a key with no frame bytes.*?\babort\(\);\s*\}', re.S)
SWAP = '{ fprintf(stderr, "UNBACKED op=%s off=%d\\n", _.node ? bb_op_name(_.node->op) : "NONE", off); }'
READ = re.compile(r'^UNBACKED op=(\S+) off=(-?\d+)$', re.M)
HEADER = 'src/templates/x86/x86_asm.h'
STALE_SECONDS = 24 * 3600


def refuse(msg):
    print('UNBACKED_CENSUS REFUSE(2): ' + msg)
    sys.exit(2)


def git(repo, *a):
    return subprocess.run(['git', '-C', repo] + list(a), capture_output=True, text=True)


def resolve(ref):
    def find():
        for c in (ref, 'origin/' + ref):
            r = git(REPO['SCRIP'], 'rev-parse', '--verify', '--quiet', c + '^{commit}')
            if r.returncode == 0:
                return r.stdout.strip()
        return ''
    sha = find()
    if not sha:
        git(REPO['SCRIP'], 'fetch', '--quiet', 'origin', re.sub(r'^origin/', '', ref))
        sha = find()
    if not sha:
        refuse('the ref %r does not resolve in %s (not local, not origin/%s, not fetchable)' % (ref, REPO['SCRIP'], ref))
    return sha


def drop_root(root):
    for n, repo in REPO.items():
        git(repo, 'worktree', 'remove', '--force', os.path.join(root, n))
    shutil.rmtree(root, ignore_errors=True)
    for repo in REPO.values():
        git(repo, 'worktree', 'prune')


def prune_stale(keep):
    if not os.path.isdir(SCRATCH):
        return
    for d in sorted(os.listdir(SCRATCH)):
        p = os.path.join(SCRATCH, d)
        if os.path.isdir(p) and p != keep and time.time() - os.path.getmtime(p) > STALE_SECONDS:
            drop_root(p)


def clean():
    if os.path.isdir(SCRATCH):
        for d in sorted(os.listdir(SCRATCH)):
            p = os.path.join(SCRATCH, d)
            if os.path.isdir(p):
                drop_root(p)
    for repo in REPO.values():
        git(repo, 'worktree', 'prune')
    print('UNBACKED_CLEAN scratch=%s' % SCRATCH)
    sys.exit(0)


def place(name, root, rev, sparse):
    path = os.path.join(root, name)
    if not os.path.exists(os.path.join(path, '.git')):
        r = git(REPO[name], 'worktree', 'add', '--detach', '--no-checkout', path, rev)
        if r.returncode != 0:
            refuse('git worktree add %s at %s: %s' % (name, rev[:12], r.stderr.strip()[-300:]))
        if sparse:
            git(path, 'sparse-checkout', 'set', '--cone', *sparse)
        r = git(path, 'checkout', '--quiet', '--detach', rev)
        if r.returncode != 0:
            refuse('git checkout %s at %s: %s' % (name, rev[:12], r.stderr.strip()[-300:]))
    elif git(path, 'rev-parse', 'HEAD').stdout.strip() != rev:
        r = git(path, 'checkout', '--quiet', '--detach', rev)
        if r.returncode != 0:
            refuse('git checkout %s at %s: %s' % (name, rev[:12], r.stderr.strip()[-300:]))
    if sparse:
        git(path, 'sparse-checkout', 'set', '--cone', *sparse)
    return path


def patch(scrip):
    p = os.path.join(scrip, HEADER)
    src = open(p, encoding='utf-8').read()
    if SWAP in src:
        return
    hits = ABORT.findall(src)
    if len(hits) != 1:
        refuse('%s holds %d x86_zop unbacked-key aborts at this ref (the instrument patch needs exactly one)' % (HEADER, len(hits)))
    open(p, 'w', encoding='utf-8').write(ABORT.sub(lambda m: SWAP, src))


def build(root, scrip):
    log = os.path.join(root, 'build.log')
    with open(log, 'w') as f:
        r = subprocess.run(['make', '-j8', 'OBJ=' + os.path.join(root, 'obj')], cwd=scrip, stdout=f, stderr=subprocess.STDOUT)
    if r.returncode != 0 or not os.access(os.path.join(scrip, 'scrip'), os.X_OK):
        tail = open(log, errors='replace').read().strip().splitlines()[-6:]
        refuse('the scratch build failed (rc %d), log %s: %s' % (r.returncode, log, ' | '.join(tail)))


def entries(corpus, lang, ext):
    t = os.path.join(corpus, 'tests', lang)
    csvp = os.path.join(t, 'ALL.csv')
    if not os.path.isfile(csvp):
        return []
    import csv
    return [(os.path.join(t, 'ALL.' + ext), os.path.join(t, 'ALL.ref'), row['entry']) for row in csv.DictReader(open(csvp, newline='', encoding='utf-8'))]


def extract(job):
    suite, ref, name, out = job
    r = subprocess.run(['python3', os.path.join(HERE, 'corpus_suite_harness.py'), 'extract', suite, ref, name, out,
                        '--out-ref', out + '.ref', '--out-in', out + '.in', '--out-xfail', out + '.xfail'], capture_output=True)
    if r.returncode != 0 or not os.path.isfile(out):
        return None
    h._copy_companions(open(out, encoding='utf-8', errors='replace').read(), os.path.dirname(suite), os.path.dirname(out))
    return out


def compile_one(scrip, timeout, env, f):
    argv = ['bash', '-c', 'ulimit -v 8000000; ulimit -c 0; exec "$@"', 'bash', scrip, '--compile', '-o', '/dev/null', f]
    rc, out, err, why = h._bounded_run(argv, timeout, os.path.dirname(f), env, None, False)
    text = err.decode('utf-8', 'replace')
    first = next((l for l in text.splitlines() if l.strip() and not l.startswith('UNBACKED ')), '')
    return rc, why, READ.findall(text), first[:160]


def main():
    ap = argparse.ArgumentParser(prog='util_unbacked_read_census.sh', add_help=True)
    ap.add_argument('--ref', default='origin/main')
    ap.add_argument('--lang', action='append', default=[])
    ap.add_argument('--workers', type=int, default=8)
    ap.add_argument('--timeout', type=int, default=30)
    ap.add_argument('--tsv', default='')
    ap.add_argument('--verbose', action='store_true')
    ap.add_argument('--clean', action='store_true')
    a = ap.parse_args(sys.argv[2:])
    if a.clean:
        clean()
    langs = [(l, e) for l, e in MASTERS if not a.lang or l in a.lang]
    unknown = [l for l in a.lang if l not in dict(MASTERS)]
    if unknown or not langs:
        refuse('unknown language %s (one of %s)' % (unknown, ' '.join(l for l, _ in MASTERS)))
    workers = max(1, min(8, a.workers))
    sha = resolve(a.ref)
    root = os.path.join(SCRATCH, sha[:12])
    os.makedirs(SCRATCH, exist_ok=True)
    lock = open(os.path.join(SCRATCH, sha[:12] + '.lock'), 'a')
    fcntl.flock(lock, fcntl.LOCK_EX)
    for repo in REPO.values():
        git(repo, 'worktree', 'prune')
    prune_stale(root)
    os.makedirs(root, exist_ok=True)
    os.utime(root)
    scrip = place('SCRIP', root, sha, None)
    place('harness', root, git(REPO['harness'], 'rev-parse', 'HEAD').stdout.strip(), None)
    corpus = place('corpus', root, git(REPO['corpus'], 'rev-parse', 'HEAD').stdout.strip(), ['tests', 'library', 'include', 'packages/icon'])
    patch(scrip)
    build(root, scrip)
    print('UNBACKED_ROOT ref=%s sha=%s root=%s' % (a.ref, sha[:12], root), flush=True)
    xdir = os.path.join(root, 'extract')
    shutil.rmtree(xdir, ignore_errors=True)
    jobs, files = [], {}
    for lang, ext in langs:
        os.makedirs(os.path.join(xdir, lang), exist_ok=True)
        for suite, ref, name in entries(corpus, lang, ext):
            jobs.append((suite, ref, name, os.path.join(xdir, lang, name + '.' + ext)))
    if not jobs:
        refuse('no master entry found under %s/tests' % corpus)
    with concurrent.futures.ThreadPoolExecutor(workers) as ex:
        for out in ex.map(extract, jobs):
            if out:
                files.setdefault(os.path.basename(os.path.dirname(out)), []).append(out)
    if not files:
        refuse('no entry extracted')
    work = [(l, f) for l, _ in langs for f in sorted(files.get(l, []))]
    sa = os.path.join(scrip, 'scrip')
    env = dict(os.environ, SNO_LIB=os.path.join(corpus, 'include'))
    base = {}
    for lang, ext in langs:
        empty = os.path.join(xdir, lang, '.empty.' + ext)
        open(empty, 'w').close()
        base[lang] = compile_one(sa, a.timeout, env, empty)[2]
    with concurrent.futures.ThreadPoolExecutor(workers) as ex:
        res = list(ex.map(lambda w: compile_one(sa, a.timeout, env, w[1]), work))
    board = collections.OrderedDict((l, {'programs': 0, 'screaming': 0, 'reads': 0, 'bad': 0, 'own': 0, 'own_p': 0, 'hang': 0, 'first': '', 'err': '', 'kinds': collections.defaultdict(lambda: [0, 0])}) for l, _ in langs)
    tsv = []
    for (lang, f), (rc, why, reads, first) in zip(work, res):
        b = board[lang]
        entry = os.path.basename(f).rsplit('.', 1)[0]
        b['programs'] += 1
        if why == 'HANG':
            b['hang'] += 1
        if rc != 0 or why:
            b['bad'] += 1
            if not b['first']:
                b['first'], b['err'] = entry, why or first
        if reads:
            b['screaming'] += 1
            b['reads'] += len(reads)
            b['own'] += max(0, len(reads) - len(base[lang]))
            b['own_p'] += 1 if len(reads) > len(base[lang]) else 0
            if a.verbose:
                print('UNBACKED_PROG lang=%s entry=%s reads=%d' % (lang, entry, len(reads)))
            for op in {op for op, _ in reads}:
                b['kinds'][op][1] += 1
            for op, off in reads:
                b['kinds'][op][0] += 1
                tsv.append('%s\t%s\t%s\t%s' % (lang, entry, op, off))
    if a.tsv:
        open(a.tsv, 'w').write('\n'.join(tsv) + ('\n' if tsv else ''))
    for lang, b in board.items():
        if not b['programs']:
            continue
        print('UNBACKED_BOARD lang=%s programs=%d screaming=%d reads=%d' % (lang, b['programs'], b['screaming'], b['reads']))
        for op, (n, p) in sorted(b['kinds'].items(), key=lambda kv: (-kv[1][0], kv[0])):
            print('UNBACKED_KIND lang=%s op=%s reads=%d programs=%d' % (lang, op, n, p))
        if base[lang]:
            print('UNBACKED_BASE lang=%s reads=%d kinds=%d' % (lang, len(base[lang]), len({op for op, _ in base[lang]})))
            print('UNBACKED_OWN lang=%s reads=%d programs=%d' % (lang, b['own'], b['own_p']))
        print('UNBACKED_NOTE lang=%s compile_rc_nonzero=%d hang=%d first=%s err="%s"' % (lang, b['bad'], b['hang'], b['first'] or '-', b['err'].replace('"', "'")))
    sys.exit(0)


main()
PY
