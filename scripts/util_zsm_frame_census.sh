#!/usr/bin/env bash
# util_zsm_frame_census.sh -- THE ZSM ARM, ITS FRAME HALF: per graph, the RBP frame carved once at entry with the DECLARED resident bytes, and no frame
# address formed outside the declared resident set (ARCH-ZETA-ONE-COORDINATE 3.3 (2); the cto's ask of 2026-10-22 12:0x under CEO-1895: "the per-graph
# frame carved once at entry with the declared resident bytes and no frame address outside it, as a compile-time count under SCRIP_ZSM -- that count is
# the switch's second finish line for every language, so make it read per graph and per language"; built by the cfo).
#
# WHAT IT MEASURES. `SCRIP_ZSM=1 scrip --compile` prints one [ZSM-FRAME] line per graph that carves a frame or forms a frame address
# (src/planner/zeta_plan.cpp zsm_frame_addr/zsm_frame_carve, read through the layout's own tables in src/ir/frame_layout.c zls_g_key_class):
#   total=     the frame bytes the graph's GC frame map registers (emit_gc_map_register), the frame as carved
#   region=    the layout's value region (zls_g_frame_region: 0 keys-only, the resident region under the home_frame fact, else every key)
#   resident=  the bytes of that region the declaration covers: frame words (layout fields no node owns: the resume and mark words, the header)
#              and the fields of nodes zls_frame_resident() declares (homes, state words, the lowerer's resident marks), plus the locals and
#              parameters TEST 2 keeps in the frame (a parameter, or a local zls_home_local_test names)
#   frames=    how many frame maps the graph registers (1 = carved once at entry)
#   addrs=     frame addresses formed from a layout KEY: every frame branch of x86_zop, which FRQ is (a TEST-1 frame home, a resumable frame's
#              local, the frame prefix, the rsp-carved forms); a template's own constant header words are not keys and are not counted
#   word= resident_addrs= outside= unbacked=   addrs by the key's class: a frame word, a declared resident cell, a cell of a node the declaration
#              does not cover or a local that passes TEST 2 (OUTSIDE: under the home_frame fact x86_zop refuses exactly these), no field at all
#   rsp_form=  of addrs, those formed as an rsp offset into a frame carved whole at entry rather than through rbp
# THE FINISH LINE per language (with test_gate_no_spine_preallocation.sh --lang L at 0 and the ZSM declared census at 0): outside=0, excess=0 (the
# region carves no byte the declaration does not cover: region minus resident, summed) and multi=0 (no graph registers more than one frame).
# NOT MEASURED HERE: the frame torn down once (a run-time fact, the declared census's half) and the run-time compile roads (EVAL, CODE, deferred
# patterns), which mode 4's --compile does not take.
#
#   util_zsm_frame_census.sh [--lang L]... [--files F...] [--timeout S] [--graphs]
#     ZSM_FRAME_LANG per language: programs, graphs, framed (total>0), region, resident, excess, multi, addrs, word, resident_addrs, outside,
#     unbacked, rsp_form; --graphs adds ZSM_FRAME_GRAPH per graph with outside>0, unbacked>0, excess>0 or frames>1; ZSM_FRAME_UNMEASURED per program
#     whose compile failed or printed no [ZSM-FRAME] line; ZSM_FRAME_VERDICT last.
#   rc 0  every measured language reads outside=0 unbacked=0 excess=0 multi=0 · rc 1 one does not (named) · rc 2 could not measure
# A COMPILE-ONLY census (no program runs); each compile takes a cc slot of the box-wide pool (util_cc_slot.sh). Grading the population is a BOARD:
# the coo's loop runs it; a seat reads one program with --files.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
exec python3 - "$HERE" "$@" <<'PY'
import collections, concurrent.futures, os, re, subprocess, sys
HERE = sys.argv[1]
SC = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP'))
SCRIP = os.path.join(SC, 'scrip')
LINE = re.compile(r'^\[ZSM-FRAME\] graph=(\S+) total=(-?\d+) region=(-?\d+) resident=(\d+) frames=(\d+) addrs=(\d+) word=(\d+) resident_addrs=(\d+) outside=(\d+) unbacked=(\d+) rsp_form=(\d+)$')
EXT = {'.sno': 'snobol4', '.icn': 'icon', '.pl': 'prolog', '.pas': 'pascal', '.raku': 'raku', '.sc': 'snocone', '.reb': 'rebus'}
KEYS = ('total', 'region', 'resident', 'frames', 'addrs', 'word', 'resident_addrs', 'outside', 'unbacked', 'rsp_form')


def refuse(msg):
    print('ZSM_FRAME REFUSE(2): ' + msg)
    sys.exit(2)


def args():
    a, langs, files, timeout, graphs = sys.argv[2:], [], [], 300, False
    i = 0
    while i < len(a):
        if a[i] == '--lang' and i + 1 < len(a):
            langs.append(a[i + 1]); i += 2
        elif a[i] == '--timeout' and i + 1 < len(a):
            timeout = int(a[i + 1]); i += 2
        elif a[i] == '--graphs':
            graphs = True; i += 1
        elif a[i] == '--files':
            files = a[i + 1:]; break
        else:
            refuse('usage: util_zsm_frame_census.sh [--lang L]... [--files F...] [--timeout S] [--graphs]')
    return langs, files, timeout, graphs


def population(langs, files):
    if files:
        return [(EXT.get(os.path.splitext(f)[1], '?'), os.path.abspath(f)) for f in files]
    r = subprocess.run(['bash', os.path.join(HERE, 'util_spine_population.sh')], capture_output=True, text=True)
    if r.returncode != 0:
        refuse('util_spine_population.sh rc %d: %s' % (r.returncode, r.stderr.strip()))
    out = [tuple(l.split('\t', 1)) for l in r.stdout.splitlines() if '\t' in l]
    return [p for p in out if not langs or p[0] in langs]


def compile_args(prog):
    r = subprocess.run(['bash', '-c', '. "$1/lib_declared_arena.sh"; declared_compile_args_beside "$2"', '-', HERE, prog], capture_output=True, text=True)
    return r.stdout.split() if r.returncode == 0 else None


def measure(job):
    lang, prog, timeout = job
    ca = compile_args(prog)
    if ca is None:
        return job, None, 'its declared compile args were refused (lib_declared_arena.sh)'
    env = dict(os.environ, SCRIP_ZSM='1')
    env.pop('SCRIP_ZSM_FRAME_DIAG', None)
    try:
        c = subprocess.run(['bash', os.path.join(HERE, 'util_cc_slot.sh'), SCRIP, '--compile'] + ca + [prog, '-o', '/dev/null'], cwd=os.path.dirname(prog), env=env,
                           stdin=subprocess.DEVNULL, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return job, None, 'a compile past %d s' % timeout
    rows = []
    for line in c.stderr.decode('utf-8', 'replace').splitlines():
        m = LINE.match(line)
        if m:
            rows.append((m.group(1),) + tuple(int(g) for g in m.groups()[1:]))
    if c.returncode != 0:
        return job, None, 'compile rc %d' % c.returncode
    if not rows:
        return job, None, 'no [ZSM-FRAME] line'
    return job, rows, None


def main():
    langs, files, timeout, graphs = args()
    if not os.access(SCRIP, os.X_OK):
        refuse('no ./scrip at ' + SCRIP)
    progs = population(langs, files)
    if not progs:
        refuse('an empty population')
    agg = collections.defaultdict(lambda: collections.Counter())
    unmeasured = []
    width = max(1, int(os.environ.get('S4E_RUN_SLOTS', '8')))
    with concurrent.futures.ThreadPoolExecutor(max_workers=width) as ex:
        for (lang, prog, _), rows, why in ex.map(measure, [(l, p, timeout) for (l, p) in progs]):
            a = agg[lang]
            a['programs'] += 1
            rel = os.path.relpath(prog, os.path.dirname(SC))
            if rows is None:
                unmeasured.append((lang, rel, why))
                continue
            a['measured'] += 1
            for row in rows:
                v = dict(zip(KEYS, row[1:]))
                excess = max(0, v['region'] - v['resident'])
                a['graphs'] += 1
                a['framed'] += 1 if v['total'] > 0 else 0
                a['excess'] += excess
                a['multi'] += 1 if v['frames'] > 1 else 0
                for k in KEYS:
                    if k not in ('total', 'frames'):
                        a[k] += v[k]
                if graphs and (v['outside'] or v['unbacked'] or excess or v['frames'] > 1):
                    print('ZSM_FRAME_GRAPH lang=%s prog=%s graph=%s total=%d region=%d resident=%d excess=%d frames=%d addrs=%d outside=%d unbacked=%d' %
                          (lang, rel, row[0], v['total'], v['region'], v['resident'], excess, v['frames'], v['addrs'], v['outside'], v['unbacked']))
    red = 0
    for lang in sorted(agg):
        a = agg[lang]
        bad = a['outside'] + a['unbacked'] + a['excess'] + a['multi']
        red += 1 if bad and a['measured'] else 0
        print('ZSM_FRAME_LANG lang=%s programs=%d measured=%d graphs=%d framed=%d region=%d resident=%d excess=%d multi=%d addrs=%d word=%d resident_addrs=%d outside=%d unbacked=%d rsp_form=%d' %
              (lang, a['programs'], a['measured'], a['graphs'], a['framed'], a['region'], a['resident'], a['excess'], a['multi'], a['addrs'], a['word'], a['resident_addrs'],
               a['outside'], a['unbacked'], a['rsp_form']))
    for (lang, rel, why) in unmeasured:
        print('ZSM_FRAME_UNMEASURED lang=%s prog=%s why=%s' % (lang, rel, why))
    meas = sum(a['measured'] for a in agg.values())
    print('ZSM_FRAME_VERDICT measured=%d unmeasured=%d red_languages=%d' % (meas, len(unmeasured), red))
    if not meas:
        sys.exit(2)
    sys.exit(1 if red else 0)


main()
PY
