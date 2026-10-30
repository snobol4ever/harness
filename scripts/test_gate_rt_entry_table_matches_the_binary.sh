#!/usr/bin/env bash
# test_gate_rt_entry_table_matches_the_binary.sh -- THE RUNTIME ENTRY TABLE AND THE BINARY AGREE (DESIGN-PLAN zeta-layout step 5; ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md section 3 R4;
# CEO-2019). harness/scripts/rt_entries.tsv has one row per runtime symbol emitted code calls; util_gen_rt_entry_table.py writes SCRIP/src/runtime/rt_entry_table.inc from it.
# STAGE 5a (this gate's first form): nothing reads the .inc yet, so the gate holds the table to the two things that are true today -- the built libscrip_rt.so and the two old
# derived tables -- and to the templates that name the symbols:
#   arm 1  the table is valid and rt_entry_table.inc is what the generator writes
#   arm 2  the table holds at least 160 rows (the plan's floor)
#   arm 3  THE UNION: every symbol a template names in x86 call, call_bare or x86_rtcc_call has a row
#   arm 4  every row's symbol exists in out/libscrip_rt.so (defined and exported, or a libc import the row says is one)
#   arm 5  rc, allocates and clobbers agree with gc_allocating_table.inc and rtx_clobber_table.inc row by row, and conv=asm is exactly the symbols src/runtime/rtx declares
#          (a table a later stage has deleted is skipped by name, never silently)
#   arm 6  the RT_CLOB_ bits are the RTCC_C_ bits of x86_asm.h
#   arm 7  rt_entry_table.inc compiles standalone and holds RT_ENTRIES rows
#   arm 8+ NEGATIVE CONTROLS on corrupted copies of the table, never a seam in src (CEO-1680): a wrong rc, a dropped symbol, a symbol the binary does not have, an invalid conv
# rc 0 every arm holds · rc 1 an arm failed · rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
NAME=rt_entry_table_matches_the_binary
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
for f in "$HERE/rt_entries.tsv" "$HERE/util_gen_rt_entry_table.py" "$ROOT/src/runtime/rt_entry_table.inc" "$ROOT/src/templates/x86/x86_asm.h" "$ROOT/out/libscrip_rt.so"; do
    [ -r "$f" ] || refuse "cannot read $f (build first: make)"
done
command -v nm > /dev/null && command -v gcc > /dev/null || refuse "no nm or gcc"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
python3 -I - "$HERE" "$ROOT" "$TD" <<'PY'
import glob, os, re, subprocess, sys
HERE, ROOT, TD = sys.argv[1:4]
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
    a, c = read('templates/x86/gc_allocating_table.inc'), read('templates/x86/rtx_clobber_table.inc')
    alloc = None if a is None else {m.group(1): m.group(2) for m in re.finditer(r'\{\s*"([^"]+)",\s*GC_RET_(\w+)\s*\}', a)}
    bit = {'RTCC_C_R8': 'r8', 'RTCC_C_R9': 'r9', 'RTCC_C_R10': 'r10', 'RTCC_C_R11': 'r11'}
    clob = None
    if c is not None:
        clob = {}
        for m in re.finditer(r'\{\s*"([^"]+)",\s*([^}]+?)\s*\}', c):
            v = m.group(2).strip()
            if m.group(1) != 'sym':
                clob[m.group(1)] = 'none' if v == '0' else '|'.join(sorted((bit[x.strip()] for x in v.split('|')), key=lambda b: int(b[1:])))
    return alloc, clob


def asm_symbols():
    out = set()
    for p in glob.glob(ROOT + '/src/runtime/rtx/*'):
        if p.endswith(('.s', '.S', '.inc', '.h')):
            t = open(p, encoding='utf-8', errors='replace').read()
            out.update(re.findall(r'RTX_(?:FUNC|ENTRY)\s*\(\s*(\w+)\s*\)', t))
            out.update(re.findall(r'^\s*\.globl\s+(\w+)', t, re.M))
    return out


def disagreements(rows, alloc, clob, asm):
    bad = []
    for r in rows:
        s = r['sym']
        if alloc is not None:
            if r['rc'] != alloc.get(s, '-'):
                bad.append('%s rc %s but the allocating table says %s' % (s, r['rc'], alloc.get(s, '-')))
            if r['allocates'] != '-' and r['allocates'] != ('1' if s in alloc else '0'):
                bad.append('%s allocates %s but the allocating table says %s' % (s, r['allocates'], '1' if s in alloc else '0'))
        if clob is not None and r['clobbers'] != clob.get(s, '-'):
            bad.append('%s clobbers %s but the clobber table says %s' % (s, r['clobbers'], clob.get(s, '-')))
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
alloc, clob = old_tables()
asm = asm_symbols()
bad = disagreements(rows, alloc, clob, asm)
skipped = [n for n, t in (('gc_allocating_table.inc', alloc), ('rtx_clobber_table.inc', clob)) if t is None]
grade('arm 5: rc, allocates, clobbers and conv=asm agree with the old tables and rtx%s' % ((' (skipped, deleted: %s)' % ', '.join(skipped)) if skipped else ''), not bad, '; '.join(bad[:5]))
x86 = read('templates/x86/x86_asm.h')
bits = dict(re.findall(r'#define RTCC_C_(R\d+) (\d+)u', x86))
grade('arm 6: the RT_CLOB_ bits are the RTCC_C_ bits of x86_asm.h', {k.lower(): int(v) for k, v in bits.items()} == G.CLOB, 'x86_asm.h has %s, the generator has %s' % (bits, G.CLOB))
open(TD + '/e.c', 'w').write('#include "rt_entry_table.inc"\nint main(void) { return RT_ENTRIES != %d || !g_rt_entries[0].sym; }\n' % len(rows))
cc = subprocess.run(['gcc', '-O0', '-Wno-unused-variable', '-I' + ROOT + '/src/runtime', '-o', TD + '/e', TD + '/e.c'], capture_output=True, text=True)
grade('arm 7: rt_entry_table.inc compiles standalone and holds RT_ENTRIES rows', cc.returncode == 0 and subprocess.run([TD + '/e']).returncode == 0, cc.stderr[:300])


def copy_rows():
    return [dict(x) for x in rows]


m = copy_rows()
k = next(x for x in m if x['rc'] == 'DESCR')
k['rc'] = 'VOID'
grade('arm 8 (control): a wrong rc against the allocating table reads red', bool(disagreements(m, alloc, clob, asm)) if alloc is not None else True)
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
print('%s: graded=%d fails=%d' % (NAME, graded, fails))
if fails:
    print('⛔ GATE RED [%s]: %d of %d arm(s) failed' % (NAME, fails, graded))
    sys.exit(1)
print('GATE PASS(0) [%s]: %d arm(s) -- %d runtime entries, each in the binary, each agreeing with the two old tables, every symbol a template calls named' % (NAME, graded, len(rows)))
PY
