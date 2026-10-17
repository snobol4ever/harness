#!/usr/bin/env python3
"""THE POPULATION MACHINE (CEO-1165 form, generalized for the acceptance bar of CEO-1202): a language rungs BY NAME through
the harness reader and refs, on one tree (--single, the acceptance census) or on a control tree and a cure tree (the landing
evidence), in mode 3 and mode 4, over a list of named collector ARMS, arms run SEQUENTIALLY with a fixed environment (a
threaded first cut mis-assigned stress levels), every child under RLIMIT_AS 6 GB.

usage: util_gc_population_machine.py <lang> <control_root|-> <cure_root> [--arms a,b,..] [--modes m3,m4] [--single]
                                     [--names f] [--limit N] [--jobs J] [--exclude a,b] [--out path]
  lang   snobol4 icon prolog snocone raku pascal rebus
  arms   nogc  = SCRIP_HEAP_KB=524288 stress 0 reloc 0 (the no-collection baseline: a big window, nothing forced)
         sN    = SCRIP_HEAP_KB=128 (the shipped window) SCRIP_GC_STRESS=N SCRIP_GC_RELOC=0 (ordinary compaction)
         rN    = SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=N SCRIP_GC_RELOC=1 (every live block displaced at every collection)
         fN    = SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=N SCRIP_GC_PLANT_FLIP=1 (every live block COPIED to disjoint ground and ALL old
                 ground PROT_NONE until the next collection: a stale pointer FAULTS where it is used, with a located [ZGC-STALE]
                 report -- the arm that turns a silent wrong answer into a crash, CTO-155)
         default r0,r1 -- the CEO-1165 form (stress 0 and 1 under forced relocation), kept for comparability
⛔ WHY BOTH RELOCATION SETTINGS: forced relocation makes a stale copy of a MOVED block wrong at once, but it also moves every
   block, which can hide a word that points at a RECLAIMED block whose ground ordinary compaction refills (hq_icon's unitgenr,
   2026-09-23: mode 4 red at 128 KB with RELOC=0, green with RELOC=1).  An acceptance census names both.
⭐ GC-ATTRIBUTABLE: an entry whose BASELINE arm (the first arm listed for that mode, nogc when it is listed) is green and some
   other arm is not.  The baseline-red entries are the language's own suite work, counted and never mixed into the GC list.
   100 percent is GC-ATTRIBUTABLE=0 on origin for every language in both modes.
The JSON (--out, default ./machine_<lang>.json) keys root|name|arm|mode -> [kind, stdout md5, [collections, grew]]."""
import sys, os, subprocess, json, hashlib, re, resource, tempfile, shutil, time
resource.setrlimit(resource.RLIMIT_AS, (6 << 30, 6 << 30))
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
EXTS = {'snobol4': '.sno', 'icon': '.icn', 'snocone': '.sc', 'prolog': '.pl', 'raku': '.raku', 'pascal': '.pas', 'rebus': '.reb'}
if len(sys.argv) < 4 or sys.argv[1] not in EXTS:
    print(__doc__); sys.exit(2)
lang = sys.argv[1]; ctl = sys.argv[2]; cure = sys.argv[3]
names_f = None; limit = None; jobs = 6; exclude = set(); arm_names = ['r0', 'r1']; modes = ['m3', 'm4']; single = False
out_path = os.path.join(os.getcwd(), 'machine_%s.json' % lang)
a = sys.argv[4:]
while a:
    k = a.pop(0)
    if k == '--names': names_f = a.pop(0)
    elif k == '--limit': limit = int(a.pop(0))
    elif k == '--jobs': jobs = int(a.pop(0))
    elif k == '--exclude': exclude |= set(a.pop(0).split(','))
    elif k == '--arms': arm_names = [x for x in a.pop(0).split(',') if x]
    elif k == '--modes': modes = [x for x in a.pop(0).split(',') if x]
    elif k == '--single': single = True
    elif k == '--out': out_path = a.pop(0)
    else: print('unknown argument %s' % k); sys.exit(2)
if ctl == '-': single = True
def arm_env(n):
    if n == 'nogc': return {'SCRIP_HEAP_KB': '524288', 'SCRIP_GC_STRESS': '0', 'SCRIP_GC_PLANT_FLIP': '0'}
    m = re.fullmatch(r'([srf])(\d+)', n)
    if not m: print('REFUSED(2): arm %r is not nogc, sN, rN or fN' % n); sys.exit(2)
    return {'SCRIP_HEAP_KB': '128', 'SCRIP_GC_STRESS': m.group(2), 'SCRIP_GC_PLANT_FLIP': '1' if m.group(1) in 'rf' else '0'}
ARMS = [(n, arm_env(n)) for n in arm_names]
roots = [cure] if single else [ctl, cure]
for r in roots:
    if not os.access(os.path.join(r, 'scrip'), os.X_OK): print('REFUSED(2): no scrip binary under %s' % r); sys.exit(2)
def tree_of(r):
    try:
        h = subprocess.run(['git', '-C', r, 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip()
        d = subprocess.run(['git', '-C', r, 'status', '--porcelain', '--untracked-files=no'], capture_output=True, text=True).stdout.strip()
        return h + ('-DIRTY' if d else '')
    except Exception: return '?'
TREES = {r: tree_of(r) for r in roots}
ext = EXTS[lang]
base = os.path.join(os.path.dirname(os.path.dirname(HERE)), 'corpus', 'tests', lang, 'ALL')
if not os.path.exists(base + ext): base = '/home/claude_cto/corpus/tests/%s/ALL' % lang
os.environ['SCRIP_GC_EXERCISE'] = '1'
os.environ.pop('SCRIP_HEAP_MB', None)
import corpus_suite_harness as H
sno, ref = base + ext, base + '.ref'
inp = base + '.in' if os.path.exists(base + '.in') else None
arg = base + '.argv' if os.path.exists(base + '.argv') else None
wrc = base + '.wantrc' if os.path.exists(base + '.wantrc') else None
if lang == 'snobol4':
    entries = H.read_suite(sno, ref, inp, None, wrc, arg, modes=None)
else:
    lc = H.LANG_CONFIGS[lang]
    entries = H.read_block_suite(sno, ref, H.banner_re_for(lc["comment_open"], lc["comment_close"]), in_path=inp, w_path=wrc, a_path=arg, modes=None)
if isinstance(entries, dict): entries = list(entries.values())
if names_f:
    want = set(l.strip() for l in open(names_f) if l.strip())
    entries = [e for e in entries if e.name in want]
if exclude: entries = [e for e in entries if e.name not in exclude]
if limit: entries = entries[:limit]
names = [e.name for e in entries]
print('population %s: %d entries; arms %s; modes %s; trees %s' % (lang, len(entries), ','.join(arm_names), ','.join(modes),
      ' '.join('%s=%s' % ('cure' if r == cure else 'control', TREES[r]) for r in roots)), flush=True)
EX_RX = re.compile(r'collections=(\d+)\b.*?grew=(\d+)')
TMP = tempfile.mkdtemp(prefix='gcmach_%s_' % lang)
def run_one(entry, mode):
    paths = H.resolve_paths()
    v = H.run_suite_entry(paths, entry, TMP, [mode], ext=ext, companion_dir=os.path.dirname(sno))
    vd = v.get(mode) if isinstance(v, dict) else v
    kind = getattr(vd, 'kind', str(vd))
    out = getattr(vd, 'stdout', b'') or b''; err = (getattr(vd, 'stderr', b'') or b'').decode('utf-8', 'replace')
    m = EX_RX.search(err)
    return kind, hashlib.md5(out).hexdigest()[:8], (int(m.group(1)), int(m.group(2))) if m else None
res = {}
try:
    for root in roots:
        for (an, env) in ARMS:
            for md in modes:
                t0 = time.time()
                os.environ['SCRIP'] = os.path.join(root, 'scrip'); os.environ['RT_DIR'] = os.path.join(root, 'out')
                os.environ.update(env)
                def work(e):
                    try: return (e.name, run_one(e, md))
                    except Exception as ex: return (e.name, ('ERROR', str(ex)[:60], None))
                with ThreadPoolExecutor(max_workers=jobs) as ex:
                    for (n, r) in ex.map(work, entries):
                        res[(root, n, an, md)] = r
                ng = sum(1 for n in names if res[(root, n, an, md)][0] != 'PASS')
                print('arm done: %s %s %s nongreen=%d (%.0fs)' % ('cure' if root == cure else 'control', an, md, ng, time.time() - t0), flush=True)
finally:
    shutil.rmtree(TMP, ignore_errors=True)
def gc_attributable(root, md):
    b = arm_names[0]; out = {}
    for n in names:
        if res[(root, n, b, md)][0] != 'PASS': continue
        bad = [(an, res[(root, n, an, md)][0]) for an in arm_names[1:] if res[(root, n, an, md)][0] != 'PASS']
        if bad: out[n] = bad
    return out
def baseline_red(root, md):
    return sorted(n for n in names if res[(root, n, arm_names[0], md)][0] != 'PASS')
summary = {}
if not single:
    for an in arm_names:
        for md in modes:
            A = {n: res[(ctl, n, an, md)] for n in names}; B = {n: res[(cure, n, an, md)] for n in names}
            ng_a = {n for n, r in A.items() if r[0] != 'PASS'}; ng_b = {n for n, r in B.items() if r[0] != 'PASS'}
            same_out = sum(1 for n in names if A[n][1] == B[n][1]); same_col = sum(1 for n in names if A[n][2] == B[n][2])
            print('ARM %s %s: control PASS=%d nongreen=%d | cure PASS=%d nongreen=%d | identical-stdout=%d/%d identical-collections=%d/%d'
                  % (an, md, len(names) - len(ng_a), len(ng_a), len(names) - len(ng_b), len(ng_b), same_out, len(names), same_col, len(names)), flush=True)
            only_cure = sorted(ng_b - ng_a); only_ctl = sorted(ng_a - ng_b)
            print('  NONGREEN ONLY ON CURE (%d): %s' % (len(only_cure), ' '.join('%s[%s]' % (n, B[n][0]) for n in only_cure)))
            print('  NONGREEN ONLY ON CONTROL (%d): %s' % (len(only_ctl), ' '.join('%s[%s]' % (n, A[n][0]) for n in only_ctl)))
for root in roots:
    tag = 'cure' if root == cure else 'control'
    for md in modes:
        g = gc_attributable(root, md); br = baseline_red(root, md)
        summary['%s_%s_gc' % (tag, md)] = len(g); summary['%s_%s_base_red' % (tag, md)] = len(br)
        print('GC-ATTRIBUTABLE %s %s (%d, green at %s and non-green under a collector arm): %s' % (tag, md, len(g), arm_names[0],
              ' '.join('%s[%s]' % (n, ','.join('%s:%s' % x for x in v)) for n, v in sorted(g.items()))))
        print('BASELINE-RED %s %s (%d, non-green at %s -- the suite work, not a collector verdict): %s' % (tag, md, len(br), arm_names[0], ' '.join(br)))
if not single:
    for md in modes:
        gc_a = set(gc_attributable(ctl, md)); gc_b = set(gc_attributable(cure, md))
        print('GC-ATTRIBUTABLE %s ONLY ON CURE (%d): %s' % (md, len(gc_b - gc_a), ' '.join(sorted(gc_b - gc_a))))
        print('GC-ATTRIBUTABLE %s ONLY ON CONTROL (%d): %s' % (md, len(gc_a - gc_b), ' '.join(sorted(gc_a - gc_b))))
print('MACHINE lang=%s entries=%d arms=%s modes=%s %s %s' % (lang, len(names), ','.join(arm_names), ','.join(modes),
      ' '.join('%s=%s' % ('cure' if r == cure else 'control', TREES[r]) for r in roots), ' '.join('%s=%d' % kv for kv in sorted(summary.items()))), flush=True)
json.dump({'%s|%s|%s|%s' % k: v for k, v in res.items()}, open(out_path, 'w'))
