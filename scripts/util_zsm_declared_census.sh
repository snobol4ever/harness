#!/usr/bin/env bash
# util_zsm_declared_census.sh -- THE ZSM ARM: DECLARED AGAINST ACTUAL, the second finish line of every placement switch
# (ARCH-ZETA-ONE-COORDINATE section 3.3; Lon 2026-10-22 10:1x CDT, verbatim: "Consider using the ZETA STATE MACHINE (ZSM) to help trace the RBP and
# RSP allocations and de-allocations."; ruled by the cto under CEO-1888/1895, built by the cfo at the cto's ask).
#
# WHAT IT MEASURES. With SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 every box's ports call the runtime's state machine (rt_zdp_sm_event), and each event
# carries the box's DECLARATION read from the planner through ONE accessor, zsm_declared_word() in src/planner/zeta_plan.cpp (zd_k, and the
# published plan's gpop and wpop, plus whether the box's gamma, omega and beta edges are LAWFUL by ZD-CHECK's own predicates: a discard or
# arm-environment target, or a box ZD-CHECK exempts, keeps its record law and is not graded; a gamma or omega the hook restores from a banked
# record counts under port=record). A pre-alpha event samples rsp before the alpha hook, so the entry depth E is measured wherever the template
# carves. Under SCRIP_ZSM_DECL=1 the runtime grades every activation against ARCH 1.1 read from E, each port printing DECLARED against ACTUAL:
#   beta   arrival depth E - rsp            declared K            (a retry re-enters at the exit depth)
#   gamma  departure depth E - rsp          declared K - gpop     (lawful gamma edges only)
#   omega  the pop past the entry rsp - E   declared wpop         (lawful omega edges only)
#   end    the construct end's pop past its OWNER's entry, rsp - E_owner, declared gpop - K (MATCH_END and MATCH_REPLACE, the owner MATCH_BEGIN)
# THE CONSTRUCT LAW (the cto's ruling of 2026-10-22 12:0x): MATCH_BEGIN's match frame is a construct cell carved at the owner's alpha, live for
# the whole match and released at the owner's omega and at the construct's end, so the owner is graded with K = zd_k + 64 + op_frame_extra
# (op_frame_extra = 32 + 16 * the frame-slot candidates up to the next MATCH_BEGIN in cfg->all, emit_match_begin_frame_extra, the extent derived
# there until the lowerer sets the construct as a graph fact) less the 16-byte subject cell the template releases first when it does; every box
# inside reads its own measured E; the end's departure is graded against the owner's live activation (the owner's node id rides in rcx).
# AN UNREADABLE DECLARATION IS A REFUSAL, NEVER A 0 (the cto, 3.4): an event of a box no plan declares, or a gamma or omega whose published
# gpop/wpop do not belong to the plan's nodes, counts refused=, apart from checked= and bad=.
# Activations are kept per (node, frame) as a small LIFO of entry depths (a SNOBOL4 function recurses inside one frame); a departure is matched
# to the live activation the law names, and a slot evicted or overflowed counts UNANCHORED, never bad. At exit the runtime prints
# [ZSM-DECL-SUM] op=<kind> port=<p> checked=<n> bad=<m> refused=<r>, one [ZSM-DECL-SITE] per node that ever disagreed (its K, gpop and wpop, and per
# port checked/bad/declared/actual/second-actual, and omega_to= the op and port the first bad omega landed on), and [ZSM-DECL-TOTAL] ...
# unanchored=<u> refused=<r> sites_overflow=<o> (the first three mismatches per kind and port as [ZSM-DECL] lines). A conditional departure (a
# jcc to gamma or omega) carries no event and is not graded; the unanchored count varies a little between runs and modes with the stack's
# addresses, the bad count of a lawful population does not.
#
# THE POPULATION is util_spine_population.sh's (the one the placement watch and the pre-allocation gate count), each program run with its
# declared -d/-s (lib_declared_arena.sh declared_switches_beside), its .cmdline compile args and its .in stdin, in mode 3 and mode 4 (compiled with
# the ZSM switches so the events are planted, linked against out/libscrip_rt.so, run with SCRIP_ZSM_DECL=1). Every child takes a run slot of the
# box-wide pool (corpus_suite_harness._bounded_run, CEO-1894) and every compile a cc slot (util_cc_slot.sh).
#
#   util_zsm_declared_census.sh [--lang L]... [--modes m3,m4] [--files F...] [--timeout S] [--verbose] [--sites]
#     one ZSM_DECL line per (lang, mode, kind, port) that disagreed or refused (every one with --verbose), ZSM_DECL_UNMEASURED per program that printed no
#     total (a crash, a timeout, a program whose run never reached exit), ZSM_DECL_TOTAL per (lang, mode), ZSM_DECL_VERDICT last; --sites adds one
#     ZSM_DECL_SITE line per disagreeing node with THE THREE NUMBERS of the omega triage: declared_K, carved (the beta arrival depth, else the gamma
#     depth plus gpop) and omega_popped (the pop past the entry) beside declared_wpop and omega_to.
#   rc 0  every measured check agreed (bad=0), none refused, and at least one program was measured
#   rc 1  a declared value disagreed with the actual rsp, or a declaration could not be read (the kinds and ports named)
#   rc 2  could not measure (a stale binary, no population, nothing measured)
# CALIBRATION (the cto's order): SNOBOL4 reads 0 first; a switch then reads its language on <switch>^ and on the switch, and an output-equal
# switch with a nonzero count is not done (corrupted memory grades as FAIL, not segv, CEO-1895). This census is a BOARD: the coo's loop runs it.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
exec python3 - "$HERE" "$@" <<'PY'
import collections, concurrent.futures, os, re, subprocess, sys, tempfile
HERE = sys.argv[1]
sys.path.insert(0, HERE)
import corpus_suite_harness as h
SC = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP'))
SCRIP = os.path.join(SC, 'scrip')
OUT = os.path.join(SC, 'out')
ZSM = {'SCRIP_ZSM': '1', 'SCRIP_ZSM_ALL': '1', 'SCRIP_ZSM_DECL': '1', 'SCRIP_ZSM_AEXP': '0'}
SUM = re.compile(r'^\[ZSM-DECL-SUM\] op=(\S+) port=(\S+) checked=(\d+) bad=(\d+) refused=(\d+)$')
TOT = re.compile(r'^\[ZSM-DECL-TOTAL\] checked=(\d+) bad=(\d+) events=(\d+) unanchored=(\d+) refused=(\d+) sites_overflow=(\d+)$')
SITE = re.compile(r'^\[ZSM-DECL-SITE\] op=(\S+) node=(\d+) st=(-?\d+) K=(-?\d+) gp=(-?\d+) wp=(-?\d+) beta=(\S+) gamma=(\S+) omega=(\S+) end=(\S+) omega_to=(\S+)$')
DET = re.compile(r'^\[ZSM-DECL\] ')
sites = False


def refuse(msg):
    print('ZSM_DECL REFUSE(2): ' + msg)
    sys.exit(2)


def args():
    global sites
    a, langs, modes, files, timeout, verbose = sys.argv[2:], [], ['m3', 'm4'], [], 60, False
    i = 0
    while i < len(a):
        if a[i] == '--lang' and i + 1 < len(a):
            langs.append(a[i + 1]); i += 2
        elif a[i] == '--modes' and i + 1 < len(a):
            modes = [m for m in a[i + 1].split(',') if m]; i += 2
        elif a[i] == '--timeout' and i + 1 < len(a):
            timeout = int(a[i + 1]); i += 2
        elif a[i] == '--verbose':
            verbose = True; i += 1
        elif a[i] == '--sites':
            sites = True; i += 1
        elif a[i] == '--files':
            files = a[i + 1:]; break
        else:
            refuse('usage: util_zsm_declared_census.sh [--lang L]... [--modes m3,m4] [--files F...] [--timeout S] [--verbose] [--sites]')
    if not set(modes) <= {'m3', 'm4'} or not modes:
        refuse('--modes takes m3, m4 or m3,m4')
    return langs, modes, files, timeout, verbose


EXT = {'.sno': 'snobol4', '.icn': 'icon', '.pl': 'prolog', '.pas': 'pascal', '.raku': 'raku', '.sc': 'snocone', '.reb': 'rebus'}


def population(langs, files):
    if files:
        return [(EXT.get(os.path.splitext(f)[1], '?'), os.path.abspath(f)) for f in files]
    r = subprocess.run(['bash', os.path.join(HERE, 'util_spine_population.sh')], capture_output=True, text=True)
    if r.returncode != 0:
        refuse('util_spine_population.sh rc %d: %s' % (r.returncode, r.stderr.strip()))
    out = [tuple(l.split('\t', 1)) for l in r.stdout.splitlines() if '\t' in l]
    return [p for p in out if not langs or p[0] in langs]


def declared(prog):
    r = subprocess.run(['bash', '-c', '. "$1/lib_declared_arena.sh"; declared_switches_beside "$2" && echo "--CA--" && declared_compile_args_beside "$2"', '-', HERE, prog],
                       capture_output=True, text=True)
    if r.returncode != 0 or '--CA--' not in r.stdout:
        return None, None
    sw, ca = r.stdout.split('--CA--', 1)
    return sw.split(), ca.split()


def run(argv, cwd, env, stdin_path, timeout):
    data = open(stdin_path, 'rb').read() if stdin_path and os.path.isfile(stdin_path) else None
    rc, out, err, why = h._bounded_run(argv, timeout, cwd, env, data, False)
    return rc, (err or b'').decode('utf-8', 'replace'), why


def measure(job):
    lang, prog, mode, timeout = job
    sw, ca = declared(prog)
    if sw is None:
        return job, None, 'its declared switches were refused (lib_declared_arena.sh)'
    env = dict(os.environ, **ZSM)
    stem, cwd = os.path.splitext(prog)[0], os.path.dirname(prog)
    if mode == 'm3':
        rc, err, why = run([SCRIP, '--run'] + ca + sw + [prog], cwd, env, stem + '.in', timeout)
    else:
        with tempfile.TemporaryDirectory(prefix='zsmdecl.') as t:
            s, b = os.path.join(t, 'p.s'), os.path.join(t, 'p.bin')
            c = subprocess.run(['bash', os.path.join(HERE, 'util_cc_slot.sh'), SCRIP, '--compile'] + ca + [prog, '-o', s], cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                               capture_output=True, timeout=max(timeout, 300))
            if c.returncode != 0 or not os.path.isfile(s):
                return job, None, 'mode-4 compile rc %d' % c.returncode
            l = subprocess.run(['bash', os.path.join(HERE, 'util_cc_slot.sh'), 'gcc', '-m64', '-no-pie', '-rdynamic', s, '-Wl,-rpath,' + OUT, '-L' + OUT, '-lscrip_rt', '-lm',
                                '-lpthread', '-o', b], capture_output=True, timeout=300)
            if l.returncode != 0:
                return job, None, 'mode-4 link rc %d' % l.returncode
            rc, err, why = run([b] + sw, cwd, env, stem + '.in', timeout)
    sums, tot, det, sites = [], None, [], []
    for line in err.splitlines():
        m = SUM.match(line)
        if m:
            sums.append((m.group(1), m.group(2), int(m.group(3)), int(m.group(4)), int(m.group(5))))
            continue
        m = SITE.match(line)
        if m:
            sites.append(m.groups())
            continue
        m = TOT.match(line)
        if m:
            tot = tuple(int(g) for g in m.groups())
        elif DET.match(line) and len(det) < 6:
            det.append(line)
    if tot is None:
        return job, None, ('a HANG past %d s' % timeout) if why == 'HANG' else 'no [ZSM-DECL-TOTAL] at exit (rc %s)' % rc
    return job, (sums, tot, det, rc, sites), None


def port_obs(f):
    if f == '-':
        return None
    chk, bad, d, a0, a1 = f.split('/')
    return int(chk), int(bad), int(d), int(a0), int(a1)


def three(site):
    op, node, st, K, gp, wp, b, g, w, e, to = site
    K, gp, wp = int(K), int(gp), int(wp)
    b, g, w, e = port_obs(b), port_obs(g), port_obs(w), port_obs(e)
    if b:
        carved = '%d' % b[3] if b[3] == b[4] else '%d..%d' % (min(b[3], b[4]), max(b[3], b[4]))
    elif g:
        carved = '%d' % (g[3] + gp) if g[3] == g[4] else '%d..%d' % (min(g[3], g[4]) + gp, max(g[3], g[4]) + gp)
    else:
        carved = '?'
    popped = ('%d' % w[3] if w[3] == w[4] else '%d..%d' % (min(w[3], w[4]), max(w[3], w[4]))) if w else '-'
    return K, gp, wp, carved, popped, b, g, w, e, to


def main():
    langs, modes, files, timeout, verbose = args()
    if not os.access(SCRIP, os.X_OK):
        refuse('no ./scrip at ' + SCRIP)
    progs = population(langs, files)
    if not progs:
        refuse('an empty population')
    jobs = [(l, p, m, timeout) for (l, p) in progs for m in modes]
    agg = collections.defaultdict(lambda: [0, 0, 0])
    tot = collections.defaultdict(lambda: [0, 0, 0, 0, 0, 0, 0])
    unmeasured = []
    width = max(1, int(os.environ.get('S4E_RUN_SLOTS', '8')))
    with concurrent.futures.ThreadPoolExecutor(max_workers=width) as ex:
        for job, res, why in ex.map(measure, jobs):
            lang, prog, mode, _ = job
            t = tot[(lang, mode)]
            t[0] += 1
            if res is None:
                unmeasured.append((lang, mode, prog, why))
                continue
            sums, (chk, bad, ev, una, ref, ovf), det, rc, sl = res
            t[1] += 1
            t[2] += chk
            t[3] += bad
            t[4] += una
            t[5] += ref
            t[6] += ovf
            for (op, port, c, b, r) in sums:
                a = agg[(lang, mode, op, port)]
                a[0] += c
                a[1] += b
                a[2] += r
            rel = os.path.relpath(prog, os.path.dirname(SC))
            if bad or verbose:
                print('ZSM_DECL_PROG lang=%s mode=%s prog=%s checked=%d bad=%d refused=%d rc=%s' % (lang, mode, rel, chk, bad, ref, rc))
                for d in det:
                    print('  ' + d)
            for site in (sl if sites else []):
                K, gp, wp, carved, popped, b, g, w, e, to = three(site)
                bad_ports = ','.join(n for n, o in (('beta', b), ('gamma', g), ('omega', w), ('end', e)) if o and o[1])
                print('ZSM_DECL_SITE lang=%s mode=%s prog=%s op=%s node=%s bad=%s declared_K=%d carved=%s gpop=%d declared_wpop=%d omega_popped=%s omega_to=%s gamma=%s omega=%s end=%s' %
                      (lang, mode, rel, site[0], site[1], bad_ports, K, carved, gp, wp, popped, to, site[7], site[8], site[9]))
    for (lang, mode, op, port) in sorted(agg):
        c, b, r = agg[(lang, mode, op, port)]
        if b or r or verbose:
            print('ZSM_DECL lang=%s mode=%s op=%s port=%s checked=%d bad=%d refused=%d' % (lang, mode, op, port, c, b, r))
    for (lang, mode, prog, why) in unmeasured:
        print('ZSM_DECL_UNMEASURED lang=%s mode=%s prog=%s why=%s' % (lang, mode, os.path.relpath(prog, os.path.dirname(SC)), why))
    allbad = allmeas = allun = allref = 0
    for (lang, mode) in sorted(tot):
        n, m, c, b, u, r, o = tot[(lang, mode)]
        allbad += b
        allmeas += m
        allun += n - m
        allref += r
        print('ZSM_DECL_TOTAL lang=%s mode=%s programs=%d measured=%d unmeasured=%d checked=%d bad=%d refused=%d unanchored=%d sites_overflow=%d' % (lang, mode, n, m, n - m, c, b, r, u, o))
    print('ZSM_DECL_VERDICT measured=%d unmeasured=%d bad=%d refused=%d' % (allmeas, allun, allbad, allref))
    if not allmeas:
        sys.exit(2)
    sys.exit(1 if allbad or allref else 0)


main()
PY
