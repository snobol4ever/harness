#!/usr/bin/env bash
# test_gate_rt_entry_table_matches_the_binary.sh -- THE RUNTIME ENTRY TABLE AND THE BINARY AGREE (DESIGN-PLAN zeta-layout step 5; ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md section 3 R4;
# CEO-2019). harness/scripts/rt_entries.tsv has one row per runtime symbol emitted code calls; util_gen_rt_entry_table.py writes SCRIP/src/runtime/rt_entry_table.inc from it.
# STAGE 5c (the clobber half) has landed: the emitter reads the .inc (emit_rtx_clob_mask scans g_rt_entries), and the table carries every registered asm-runtime entry, not only the
# ones a template names. The gate holds it to the built libscrip_rt.so, to gc_allocating_table.inc (until hq_collector's 5c row deletes it), to the assembled objects (the clobbers of
# every asm row) and to the templates that name the symbols:
#   arm 1  the table is valid and rt_entry_table.inc is what the generator writes
#   arm 2  the table holds at least 160 rows (the plan's floor)
#   arm 3  THE UNION: every symbol a template names in x86 call, call_bare or x86_rtcc_call has a row
#   arm 4  every row's symbol exists in out/libscrip_rt.so (defined and exported, or a libc import the row says is one)
#   arm 5  rc and allocates agree with gc_allocating_table.inc row by row, the clobbers of every asm row are what the objects derive (util_gen_rt_entry_table.py --check-asm, which the leaf
#          clobber gate also plants against), and conv=asm is exactly the symbols src/runtime/rtx registers (a table a later stage has deleted is skipped by name, never silently)
#   arm 5b (STAGE 5c, the allocating half, the generator half: ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH 10 and 10.1) rc and allocates of EVERY row equal what the built libscrip_rt.so derives (lib_rt_alloc_derive.py: the call graph
#          reaches rt_gcheap_alloc, tail jumps included, and the return class out of the DWARF), graded before the asm refusal so a stale clobber row cannot hide it; controls: an allocating row whose allocates is cleared,
#          a non-allocating row that claims 1, and a row whose rc is widened from OTHER to DESCR each read red (arms 8b to 8d)
#   arm 6  the RT_CLOB_ bits are the RTCC_C_ bits of x86_rtcc.h
#   arm 7  rt_entry_table.inc compiles standalone and holds RT_ENTRIES rows
#   arm 8+ NEGATIVE CONTROLS on corrupted copies of the table, never a seam in src (CEO-1680): a wrong rc, a dropped symbol, a symbol the binary does not have, an invalid conv
#   arm 12 STAGE 5b (graded always now): every row (an asm entry and a libc import excepted) has exactly one RT_ENTRY_DECL(sym, conv, transfers) under SCRIP/src at its definition, saying the table's conv and
#          transfers, and no declaration lacks a row (RED until hq_runtime declares them; `util_gen_rt_entry_table.py --sync-decls` then derives the table's two columns from them)
#   arm 13+ CONTROLS of arm 12 on a scratch tree: agreeing declarations read clean; a missing one, a double one, a wrong conv, a wrong transfers and a stray one are each named
# usage: test_gate_rt_entry_table_matches_the_binary.sh [--declared]   (arm 12 is graded always since stage 5b landed; the flag is accepted and does nothing, the 5b and 5c rows' DONE-WHENs pass it)
# rc 0 every arm holds · rc 1 an arm failed · rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
NAME=rt_entry_table_matches_the_binary
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
for f in "$HERE/rt_entries.tsv" "$HERE/util_gen_rt_entry_table.py" "$ROOT/src/runtime/rt_entry_table.inc" "$ROOT/src/templates/x86/x86_rtcc.h" "$ROOT/out/libscrip_rt.so"; do
    [ -r "$f" ] || refuse "cannot read $f (build first: make)"
done
command -v nm > /dev/null && command -v gcc > /dev/null || refuse "no nm or gcc"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
DECLARED=0; [ "${1:-}" = "--declared" ] && DECLARED=1
python3 -I - "$HERE" "$ROOT" "$TD" "$DECLARED" <<'PY'
import glob, os, re, subprocess, sys
HERE, ROOT, TD, DECLARED = sys.argv[1:5]
sys.path.insert(0, HERE)
import util_gen_rt_entry_table as G
NAME = 'rt_entry_table_matches_the_binary'
graded, fails = 0, 0


def grade(label, ok, detail=''):
    global graded, fails
    graded += 1
    if ok:
        print('  ok   ' + label)
    else:
        fails += 1
        print('  ⛔ FAIL ' + label + (': ' + detail if detail else ''))


def read(rel):
    p = os.path.join(ROOT, 'src', rel)
    return open(p, encoding='utf-8', errors='replace').read() if os.path.exists(p) else None


def called_symbols():
    out = set()
    for p in glob.glob(ROOT + '/src/templates/**/*.cpp', recursive=True) + glob.glob(ROOT + '/src/templates/**/*.h', recursive=True):
        t = open(p, encoding='utf-8', errors='replace').read()
        out.update(re.findall(r'x86\("call(?:_bare)?",\s*"([A-Za-z_][A-Za-z0-9_]*)"', t))
        out.update(re.findall(r'x86_rtcc_call\(\s*"([A-Za-z_][A-Za-z0-9_]*)"', t))
    return out


def binary_symbols():
    d, u = set(), set()
    for ln in subprocess.run(['nm', '-D', ROOT + '/out/libscrip_rt.so'], capture_output=True, text=True).stdout.splitlines():
        f = ln.split()
        if len(f) == 2 and f[0] == 'U':
            u.add(f[1].split('@')[0])
        elif len(f) == 3:
            d.add(f[2].split('@')[0])
    return d, u


def old_tables():
    a = read('templates/x86/gc_allocating_table.inc')
    return None if a is None else {m.group(1): m.group(2) for m in re.finditer(r'\{\s*"([^"]+)",\s*GC_RET_(\w+)\s*\}', a)}


def asm_symbols():
    """The asm entries: the names the BINARY carries in its rtx_entry_names section (RTX_FUNC and RTX_ENTRY push each entry's name there, token-pasted macro entries included),
    so a macro-made entry is seen; the text scan of src/runtime/rtx is the fallback when objcopy cannot read the section."""
    lib = ROOT + '/out/libscrip_rt.so'
    try:
        r = subprocess.run(['objcopy', '-O', 'binary', '--only-section=rtx_entry_names', lib, '/dev/stdout'], capture_output=True)
        names = {x.decode() for x in r.stdout.split(b'\0') if x}
        if r.returncode == 0 and len(names) > 100:
            return names
    except OSError:
        pass
    out = set()
    for p in glob.glob(ROOT + '/src/runtime/rtx/*'):
        if p.endswith(('.s', '.S', '.inc', '.h')):
            t = open(p, encoding='utf-8', errors='replace').read()
            out.update(re.findall(r'RTX_(?:FUNC|ENTRY)\s*\(\s*(\w+)\s*\)', t))
            out.update(re.findall(r'^\s*\.globl\s+(\w+)', t, re.M))
    return out


def disagreements(rows, alloc, asm):
    bad = []
    for r in rows:
        s = r['sym']
        if alloc is not None:
            if r['rc'] != alloc.get(s, '-'):
                bad.append('%s rc %s but the allocating table says %s' % (s, r['rc'], alloc.get(s, '-')))
            if r['allocates'] != '-' and r['allocates'] != ('1' if s in alloc else '0'):
                bad.append('%s allocates %s but the allocating table says %s' % (s, r['allocates'], '1' if s in alloc else '0'))
        if (r['conv'] == 'asm') != (s in asm):
            bad.append('%s conv %s but rtx %s it' % (s, r['conv'], 'declares' if s in asm else 'does not declare'))
    return bad


def missing_in_binary(rows, d, u):
    return [r['sym'] for r in rows if r['sym'] not in d and not (r['sym'] in u and 'import' in r['src'].split(','))]


tsv = os.path.join(HERE, 'rt_entries.tsv')
try:
    rows = G.validate(G.load(tsv))
except ValueError as e:
    print('GATE RED [%s]: the table is invalid: %s' % (NAME, e))
    sys.exit(1)
r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'util_gen_rt_entry_table.py'), '--check'], capture_output=True, text=True)
grade('arm 1: the table is valid and rt_entry_table.inc is what the generator writes (%s)' % (r.stdout.strip() or r.stderr.strip())[:60], r.returncode == 0, (r.stdout + r.stderr).strip()[:300])
grade('arm 2: the table holds %d rows (floor 160)' % len(rows), len(rows) >= 160)
called = called_symbols()
miss = sorted(called - {x['sym'] for x in rows})
grade('arm 3: the union -- every symbol a template calls has a row (%d called)' % len(called), not miss, 'no row for: %s' % miss[:12])
d, u = binary_symbols()
nob = missing_in_binary(rows, d, u)
grade('arm 4: every row\'s symbol exists in libscrip_rt.so (%d defined and exported, %d libc imports)' % (len({x['sym'] for x in rows} & d), len({x['sym'] for x in rows} & u - d)), not nob, 'not in the binary: %s' % nob[:12])
try:
    balloc = G.derive_alloc(ROOT)
except OSError as e:
    print('GATE REFUSE(2) [%s]: the allocating set could not be derived from the binary: %s' % (NAME, str(e)[:300]))
    sys.exit(2)
bad_b = G.alloc_disagreements(rows, balloc)
grade('arm 5b: rc and allocates of all %d rows equal what the binary derives (%d symbols reach the allocator, %d rows allocate)' % (len(rows), len(balloc), sum(1 for x in rows if x['allocates'] == '1')), not bad_b, '%d disagree, e.g. %s' % (len(bad_b), '; '.join(bad_b[:3])))
alloc = old_tables()
asm = asm_symbols()
bad = disagreements(rows, alloc, asm)
ca = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'util_gen_rt_entry_table.py'), '--check-asm'], capture_output=True, text=True)
if ca.returncode == 2:
    print('GATE REFUSE(2) [%s]: the asm clobbers could not be derived from the objects: %s' % (NAME, (ca.stdout + ca.stderr).strip()[:300]))
    sys.exit(2)
if ca.returncode != 0:
    bad += [x.strip() for x in ca.stdout.splitlines()[:6]]
skipped = [n for n, t in (('gc_allocating_table.inc', alloc),) if t is None]
grade('arm 5: rc and allocates agree with the allocating table, the clobbers of every asm row with the objects (--check-asm, %s), and conv=asm is exactly the registered asm entries%s' % (ca.stdout.strip()[:44], (' (allocating table skipped, deleted: %s)' % ', '.join(skipped)) if skipped else ''), not bad, '; '.join(bad[:5]))
x86 = read('templates/x86/x86_rtcc.h')
bits = dict(re.findall(r'#define RTCC_C_(R\d+) (\d+)u', x86))
grade('arm 6: the RT_CLOB_ bits are the RTCC_C_ bits of x86_rtcc.h', {k.lower(): int(v) for k, v in bits.items()} == G.CLOB, 'x86_rtcc.h has %s, the generator has %s' % (bits, G.CLOB))
open(TD + '/e.c', 'w').write('#include "rt_entry_table.inc"\nint main(void) { return RT_ENTRIES != %d || !g_rt_entries[0].sym; }\n' % len(rows))
cc = subprocess.run(['gcc', '-O0', '-Wno-unused-variable', '-I' + ROOT + '/src/runtime', '-o', TD + '/e', TD + '/e.c'], capture_output=True, text=True)
grade('arm 7: rt_entry_table.inc compiles standalone and holds RT_ENTRIES rows', cc.returncode == 0 and subprocess.run([TD + '/e']).returncode == 0, cc.stderr[:300])


def copy_rows():
    return [dict(x) for x in rows]


m = copy_rows()
k = next(x for x in m if x['rc'] == 'DESCR')
k['rc'] = 'VOID'
grade('arm 8 (control): a wrong rc against the allocating table reads red', bool(disagreements(m, alloc, asm)) if alloc is not None else True)
m = copy_rows()
k = next(x for x in m if x['allocates'] == '1' and x['conv'] != 'asm' and x['sym'] in balloc)
k['allocates'] = '0'
grade('arm 8b (control): an allocating entry (%s) whose allocates is cleared reads red against the binary' % k['sym'], any('%s: allocates 0 but the binary reaches the allocator' % k['sym'] in x for x in G.alloc_disagreements(m, balloc)))
m = copy_rows()
k = next(x for x in m if x['allocates'] == '0' and x['sym'] not in balloc)
k['allocates'] = '1'
grade('arm 8c (control): a non-allocating entry (%s) that claims allocates 1 reads red against the binary' % k['sym'], any('%s: allocates 1 but the binary does not reach the allocator' % k['sym'] in x for x in G.alloc_disagreements(m, balloc)))
m = copy_rows()
k = next(x for x in m if x['rc'] == 'OTHER')
k['rc'] = 'DESCR'
grade('arm 8d (control): an entry (%s) whose return class is widened from OTHER to DESCR reads red against the binary -- the mutation that would spill an untagged long as a descriptor cell' % k['sym'], any('%s: rc DESCR but the binary says OTHER' % k['sym'] in x for x in G.alloc_disagreements(m, balloc)))
m = [x for x in copy_rows() if x['sym'] != 'rt_zdp_ev']
grade('arm 9 (control): a called symbol dropped from the table (rt_zdp_ev) reads red', 'rt_zdp_ev' in called - {x['sym'] for x in m})
m = copy_rows()
m.append(dict(m[0], sym='rt_no_such_entry_xyz', ln=99999))
grade('arm 10 (control): a row whose symbol the binary does not have reads red', 'rt_no_such_entry_xyz' in missing_in_binary(m, d, u))
m = G.load(tsv)
m[3]['conv'] = 'nonsense'
try:
    G.validate(m)
    grade('arm 11 (control): an invalid conv reads red', False, 'validate accepted it')
except ValueError:
    grade('arm 11 (control): an invalid conv reads red', True)
decl = G.find_decls(os.path.join(ROOT, 'src'))
bad = G.decl_disagreements(rows, decl)
todo = sum(1 for x in rows if x['conv'] != 'asm' and 'import' not in x['src'].split(','))
if True:
    grade('arm 12: every row has exactly one RT_ENTRY_DECL at its definition, agreeing with the table (%d declared, %d rows to declare)' % (len(decl), todo), not bad, '%d disagree, e.g. %s' % (len(bad), '; '.join(bad[:3])))
sd = os.path.join(TD, 'declscratch')
os.makedirs(sd, exist_ok=True)
fake = [dict(zip(G.COLS, ['aa_leaf', 'leaf', 'VOID', '0', '-', '0', 'call'])), dict(zip(G.COLS, ['bb_open', 'open', 'OTHER', '0', '-', '1', 'call'])),
        dict(zip(G.COLS, ['cc_asm', 'asm', 'VOID', '0', '-', '-', 'call,asm'])), dict(zip(G.COLS, ['dd_libc', 'leaf', '-', '0', '-', '-', 'call,import']))]


def tree(text):
    open(os.path.join(sd, 'f.c'), 'w', encoding='utf-8').write(text)
    return G.decl_disagreements(fake, G.find_decls(sd))


good = '#define RT_ENTRY_DECL(sym, conv, transfers)\nRT_ENTRY_DECL(aa_leaf, leaf, 0)\nint aa_leaf(void);\nRT_ENTRY_DECL(bb_open, open, 1)\n'
grade('arm 13 (control): declarations that agree read clean, the macro definition and an asm entry and a libc import need none', tree(good) == [], str(tree(good)))
grade('arm 14 (control): a missing declaration is named', any('bb_open: no RT_ENTRY_DECL' in x for x in tree(good.replace('RT_ENTRY_DECL(bb_open, open, 1)', ''))))
grade('arm 15 (control): a double declaration is named', any('aa_leaf: declared 2 times' in x for x in tree(good + 'RT_ENTRY_DECL(aa_leaf, leaf, 0)\n')))
grade('arm 16 (control): a wrong conv and a wrong transfers are each named', any('bb_open: the table says conv open' in x for x in tree(good.replace('open, 1', 'gen, 1'))) and any('aa_leaf: the table says' in x for x in tree(good.replace('leaf, 0)\nint', 'leaf, 1)\nint'))))
grade('arm 17 (control): a declaration with no row, and one for an asm entry, are each named', any('zz_stray: declared' in x and 'no row' in x for x in tree(good + 'RT_ENTRY_DECL(zz_stray, leaf, 0)\n')) and any('cc_asm: declared' in x for x in tree(good + 'RT_ENTRY_DECL(cc_asm, leaf, 0)\n')))
open(os.path.join(sd, 'f.c'), 'w', encoding='utf-8').write(good)
os.makedirs(os.path.join(sd, 'sub'), exist_ok=True)
open(os.path.join(sd, 'sub', 'h.S'), 'w', encoding='utf-8').write('RT_ENTRY_DECL(zz_stray, leaf, 0)\n')
grade('arm 18 (control): a statement in a capital .S file is scanned', 'zz_stray' in G.find_decls(sd))
os.remove(os.path.join(sd, 'sub', 'h.S'))
asm_real = asm_symbols()
flip = [dict(x) for x in rows]
t = next((x for x in flip if x['conv'] == 'asm'), None)
if t is not None:
    t['conv'] = 'leaf'
grade('arm 19 (control): the asm set is the binary\'s rtx_entry_names section (%d names) and an asm row booked leaf reads red against it' % len(asm_real), len(asm_real) > 100 and t is not None and any('conv leaf but rtx declares it' in x for x in disagreements(flip, None, asm_real)))
print('%s: graded=%d fails=%d' % (NAME, graded, fails))
if fails:
    print('⛔ GATE RED [%s]: %d of %d arm(s) failed' % (NAME, fails, graded))
    sys.exit(1)
print('GATE PASS(0) [%s]: %d arm(s) -- %d runtime entries, each in the binary, each agreeing with the allocating table and the objects, every symbol a template calls named' % (NAME, graded, len(rows)))
PY
