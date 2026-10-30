#!/usr/bin/env bash
# test_gate_builtin_table_is_current.sh -- THE BUILTIN TABLE IS THE ONE TABLE, AND NOTHING WAS LOST OR RENUMBERED (DESIGN-PLAN builtin-table step 1; ARCH-BUILTIN-TABLE.md section 3;
# CEO-2016). harness/scripts/builtins.tsv is the one statement of what a builtin is; util_gen_builtin_table.py writes SCRIP/src/runtime/builtin_table.h and builtin_table.inc from it.
#   arm 1  the table is valid and both generated files are exactly what the generator writes (a table edited without regenerating, or a generated file edited by hand, is stale)
#   arm 2  THE UNION: every name any of the twelve sources (util_builtin_sources.py: dop_direct_fp, g_bn_direct, icn_bi_tbl, the known lists, builtin_ids.h, every strcmp(fn, ...) and
#          strcmp(meth, ...) arm, pas_bi_names.h, lower_raku.c's targets, pl_leaf_kind) spells has a row; a name a chain still spells and the table lost is the defect
#   arm 3  the 190 ids of builtin_ids.h keep their numbers: every BID_ macro is the bid of exactly the row whose sanitized name it carries
#   arm 4  builtin_ids.h carries no private hash: bid_of IS bt_bid_legacy, the generated table's (step 1 resolves nothing differently)
#   arm 5  a C program built against the REAL headers: bt_bid_of(vocab, name) returns every row's bid; bid_of(name) returns the legacy id of every legacy name and 0 for every other
#          (bid_of is vocabulary-blind: every row spelling a legacy NAME gets the legacy id, every other name 0, exactly as before the table); the largest bid sits below BID_TABSZ
#   arm 6+ NEGATIVE CONTROLS on corrupted copies of the table, never a seam in src (CEO-1680): a legacy bid renumbered, a source name dropped, a bid reused, a row with no entry
# rc 0 every arm holds · rc 1 an arm failed · rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
NAME=builtin_table_is_current
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
for f in "$HERE/builtins.tsv" "$HERE/util_gen_builtin_table.py" "$HERE/util_builtin_sources.py" "$ROOT/src/runtime/builtin_table.h" "$ROOT/src/runtime/builtin_table.inc" "$ROOT/src/runtime/builtin_ids.h"; do
    [ -r "$f" ] || refuse "cannot read $f"
done
command -v gcc > /dev/null || refuse "no gcc"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
python3 -I - "$HERE" "$ROOT" "$TD" <<'PY'
import os, re, subprocess, sys
HERE, ROOT, TD = sys.argv[1:4]
sys.path.insert(0, HERE)
import util_gen_builtin_table as G
import util_builtin_sources as U
NAME = 'builtin_table_is_current'
graded, fails = 0, 0


def grade(label, ok, detail=''):
    global graded, fails
    graded += 1
    if ok:
        print('  ok   ' + label)
    else:
        fails += 1
        print('  ⛔ FAIL ' + label + (': ' + detail if detail else ''))


def missing_names(rows, sources):
    have = {r['name'] for r in rows}
    return sorted({U.names_of(x) for recs in sources.values() if recs for x in recs} - have)


def legacy_problems(rows, macros):
    byname = {G.sanitize(r['name']): r for r in rows if 'ids' in r['src'].split(',')}
    bad = []
    for m, i in sorted(macros.items()):
        r = byname.get(m[4:])
        if r is None or r['bid'] != i:
            bad.append('%s=%d' % (m, i))
    return bad


tsv = os.path.join(HERE, 'builtins.tsv')
try:
    rows = G.validate(G.load(tsv))
except ValueError as e:
    print('GATE RED [%s]: the table is invalid: %s' % (NAME, e))
    sys.exit(1)
r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'util_gen_builtin_table.py'), '--check'], capture_output=True, text=True)
grade('arm 1: the table is valid and builtin_table.h and .inc are what the generator writes (%s)' % r.stdout.strip().splitlines()[-1][:80] if r.stdout.strip() else 'arm 1', r.returncode == 0, (r.stdout + r.stderr).strip()[:300])

src = U.collect(ROOT)
miss = missing_names(rows, src)
grade('arm 2: the union -- every name the twelve sources spell has a row (%d rows, %d source names)' % (len(rows), len({U.names_of(x) for v in src.values() if v for x in v})), not miss, 'no row for: %s' % miss[:12])

ids_t = U.ids_table(ROOT)
bad = legacy_problems(rows, ids_t[0])
grade('arm 3: the %d ids of builtin_ids.h keep their numbers' % len(ids_t[0]), not bad, 'renumbered or lost: %s' % bad[:8])

hdr = open(os.path.join(ROOT, 'src/runtime/builtin_ids.h'), encoding='utf-8').read()
grade('arm 4: builtin_ids.h carries no private hash, bid_of is bt_bid_legacy', 'g_bid_tab' not in hdr and 'return bt_bid_legacy(s, len)' in hdr, 'g_bid_tab still there or bid_of does not call bt_bid_legacy')

c = ['#include <stdio.h>', '#include <string.h>', '#include "builtin_ids.h"', '#include "builtin_table.inc"', 'static int bad = 0;',
     'static void want(const char * what, const char * nm, int got, int exp) { if (got != exp) { bad++; if (bad < 12) printf("%s %s: got %d want %d\\n", what, nm, got, exp); } }',
     'int main(void) {']
legacy_of = {x['name']: x['bid'] for x in rows if 'ids' in x['src'].split(',')}
for rr in rows:
    nm = G.cstr(rr['name'])
    c.append('    want("bt_bid_of", %s, bt_bid_of(%d, %s, (unsigned)strlen(%s)), %d);' % (nm, G.VOCABS.index(rr['vocab']), nm, nm, rr['bid']))
    c.append('    want("bid_of", %s, bid_of(%s, (unsigned)strlen(%s)), %d);' % (nm, nm, nm, legacy_of.get(rr['name'], 0)))
c += ['    want("BT_BID_MAX", "-", BT_BID_MAX < BID_TABSZ, 1);', '    want("bid_of NULL", "-", bid_of(0, 3), 0);', '    want("bid_of empty", "-", bid_of("", 0), 0);',
      '    want("bid_of unknown", "-", bid_of("no_such_builtin", 15), 0);', '    printf("checked %d rows, %d disagree\\n", BT_ROWS, bad);', '    return bad != 0;', '}']
open(TD + '/chk.c', 'w', encoding='utf-8').write('\n'.join(c) + '\n')
rc = subprocess.run(['gcc', '-O0', '-Wno-unused-function', '-I' + ROOT + '/src/runtime', '-o', TD + '/chk', TD + '/chk.c'], capture_output=True, text=True)
if rc.returncode != 0:
    grade('arm 5: the C check builds against the real headers', False, rc.stderr[:400])
else:
    out = subprocess.run([TD + '/chk'], capture_output=True, text=True)
    grade('arm 5: %s' % (out.stdout.strip().splitlines()[-1] if out.stdout.strip() else 'C check'), out.returncode == 0, out.stdout[:400])


def copy_rows():
    return [dict(x) for x in rows]


m = copy_rows()
k = next(x for x in m if x['bid'] == 135)
k['bid'] = 5000
grade('arm 6 (control): a legacy id renumbered (135 -> 5000) reads red', bool(legacy_problems(m, ids_t[0])))
m = [x for x in copy_rows() if x['name'] != 'upto']
grade('arm 7 (control): a source name dropped from the table (upto) reads red', 'upto' in missing_names(m, src))
m = G.load(tsv)
m[5]['bid'] = m[6]['bid']
try:
    G.validate(m)
    grade('arm 8 (control): a bid reused reads red', False, 'validate accepted it')
except ValueError:
    grade('arm 8 (control): a bid reused reads red', True)
m = G.load(tsv)
x = next(y for y in m if y['conv'] == 'leaf')
x['entry'] = '-'
try:
    G.validate(m)
    grade('arm 9 (control): a leaf row with no entry reads red', False, 'validate accepted it')
except ValueError:
    grade('arm 9 (control): a leaf row with no entry reads red', True)
print('%s: graded=%d fails=%d' % (NAME, graded, fails))
if fails:
    print('⛔ GATE RED [%s]: %d of %d arm(s) failed' % (NAME, fails, graded))
    sys.exit(1)
print('GATE PASS(0) [%s]: %d arm(s) -- one table, the union held, the 190 ids unmoved, bid_of reads the generated table and resolves nothing differently' % (NAME, graded))
PY
