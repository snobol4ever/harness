#!/usr/bin/env bash
# test_gate_core_fn_table_is_current.sh -- THE RUNTIME'S BUILT-IN FUNCTIONS ARE STATIC DATA, NOT 129 REGISTRATIONS AT EVERY START-UP (row icon-the-startup-rebuilds-compile-time-tables-procedures-
# csets-globals-registered-by-c-calls-at-run-time-ceo-1969). harness/scripts/core_fns.tsv is the one statement of the C functions the runtime knows by name; util_gen_core_fn_table.py writes
# SCRIP/src/runtime/core/core_fn_table.inc from it, and core.c consults that table after its dynamic chain.
#   arm 1  the table is valid and core_fn_table.inc is exactly what the generator writes (a table edited without regenerating, or the .inc edited by hand, is stale)
#   arm 2  core_lib_init spells no register_fn_lit: the rows are not registered at run time any more (a call that came back would pay a heap node, a hash and a walk per row at every start-up again)
#   arm 3  a C program built against the REAL core.h and the REAL .inc: every row is found by the slot probe from the runtime's own hash (h = 5381; h = h * 33 ^ byte) and holds exactly the fields
#          core_fn_register_impl filled (name = spec = entry_label, fn, min_args clamped at 0, max_args, max_set = max_args >= 0, no params, no locals, no next); every stored hash equals the
#          hash of its name; a name that is not a row (each row's name with a suffix and with a prefix) is not found
#   arm 4+ NEGATIVE CONTROLS on corrupted copies, never a seam in src (CEO-1680): a table with a row dropped, built into a scratch .inc and graded by the same C check, reads red; a table with a
#          repeated name is refused by validate
# rc 0 every arm holds · rc 1 an arm failed · rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
NAME=core_fn_table_is_current
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
for f in "$HERE/core_fns.tsv" "$HERE/util_gen_core_fn_table.py" "$HERE/util_reflow_200.py" "$ROOT/src/runtime/core/core_fn_table.inc" "$ROOT/src/runtime/core/core.c" "$ROOT/src/runtime/core/core.h"; do
    [ -r "$f" ] || refuse "cannot read $f"
done
command -v gcc > /dev/null || refuse "no gcc"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
python3 -I - "$HERE" "$ROOT" "$TD" <<'PY'
import os, re, subprocess, sys
HERE, ROOT, TD = sys.argv[1:4]
sys.path.insert(0, HERE)
import util_gen_core_fn_table as G
NAME = 'core_fn_table_is_current'
graded, fails = 0, 0


def grade(label, ok, detail=''):
    global graded, fails
    graded += 1
    if ok:
        print('  ok   ' + label)
    else:
        fails += 1
        print('  ⛔ FAIL ' + label + (': ' + detail if detail else ''))


tsv = os.path.join(HERE, 'core_fns.tsv')
try:
    rows = G.validate(G.load(tsv))
except ValueError as e:
    print('GATE RED [%s]: the table is invalid: %s' % (NAME, e))
    sys.exit(1)
r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'util_gen_core_fn_table.py'), '--check'], capture_output=True, text=True)
grade('arm 1: the table is valid and core_fn_table.inc is what the generator writes (%s)' % (r.stdout.strip().splitlines()[-1][:80] if r.stdout.strip() else 'no output'), r.returncode == 0, (r.stdout + r.stderr).strip()[:300])

core = open(os.path.join(ROOT, 'src/runtime/core/core.c'), encoding='utf-8').read()
m = re.search(r'^void core_lib_init\(void\) \{\n(.*?)^\}\n', core, re.S | re.M)
grade('arm 2: core_lib_init spells no register_fn_lit (the %d rows are static data)' % len(rows), bool(m) and 'register_fn_lit' not in m.group(1), 'core_lib_init not found' if not m else 'a register_fn_lit call is back in core_lib_init')

INC = ['-I' + ROOT + '/src' + s for s in ('', '/ir', '/lower', '/emitter', '/runtime/core', '/runtime/builtins', '/runtime', '/runtime/rt', '/parsers/snobol4', '/parsers/raku', '/optimizer')]


def check(inc_dir, label):
    fns = sorted({x['fn'] for x in rows})
    c = ['#include <stdio.h>', '#include "core.h"']
    c += ['DESCR_t %s(DESCR_t * a, int n) { (void) a; (void) n; return NULVCL; }' % f for f in fns]
    c += ['#include "core_fn_table.inc"', 'static unsigned hraw(const char * n) { unsigned h = 5381; while (*n) h = h * 33 ^ (unsigned char) *n++; return h; }',
          'static const FNCBLK_t * find(const char * name) { unsigned hr = hraw(name); for (unsigned sl = hr & (CORE_FN_HASHSZ - 1); g_core_fn_slot[sl]; sl = (sl + 1) & (CORE_FN_HASHSZ - 1)) '
          '{ unsigned k = g_core_fn_slot[sl] - 1u; if (g_core_fn_hash[k] == hr && !strcmp(g_core_fn[k].name, name)) return &g_core_fn[k]; } return 0; }',
          'static int bad = 0;', 'static void want(const char * what, const char * nm, int ok) { if (!ok) { bad++; if (bad < 12) printf("%s %s\\n", what, nm); } }',
          'int main(void) {', '    char buf[256];', '    for (int i = 0; i < CORE_FN_N; i++) want("hash", g_core_fn[i].name, g_core_fn_hash[i] == hraw(g_core_fn[i].name));']
    for x in rows:
        q = G.cstr(x['name'])
        c.append('    { const FNCBLK_t * e = find(%s); want("missing", %s, e != 0); if (e) { want("fields", %s, e->fn == %s && e->min_args == %d && e->max_args == %d && e->max_set == %d '
                 '&& e->name == e->spec && e->name == e->entry_label && !e->next && !e->params && !e->locals && !e->nparams && !e->nlocals); } }'
                 % (q, q, q, x['fn'], max(x['min'], 0), x['max'], 1 if x['max'] >= 0 else 0))
        c.append('    snprintf(buf, sizeof buf, "%%sx", %s); want("absent", buf, find(buf) == 0);' % q)
        c.append('    snprintf(buf, sizeof buf, "_%%s", %s); want("absent", buf, find(buf) == 0);' % q)
    c += ['    want("count", "CORE_FN_N", CORE_FN_N == %d);' % len(rows), '    printf("checked %d rows, %d disagree\\n", CORE_FN_N, bad);', '    return bad != 0;', '}']
    src = os.path.join(TD, label + '.c')
    open(src, 'w', encoding='utf-8').write('\n'.join(c) + '\n')
    rc = subprocess.run(['gcc', '-O0', '-w', '-I' + inc_dir] + INC + ['-o', os.path.join(TD, label), src], capture_output=True, text=True)
    if rc.returncode != 0:
        return None, rc.stderr[-400:]
    out = subprocess.run([os.path.join(TD, label)], capture_output=True, text=True)
    return out.returncode, (out.stdout.strip().splitlines()[-1] if out.stdout.strip() else 'C check')


rc, msg = check(os.path.join(ROOT, 'src/runtime/core'), 'real')
if rc is None:
    grade('arm 3: the C check builds against the real headers', False, msg)
else:
    grade('arm 3: %s' % msg, rc == 0, msg)

ctl = os.path.join(TD, 'ctl_inc')
os.makedirs(ctl)
open(os.path.join(ctl, 'core_fn_table.inc'), 'w', encoding='utf-8').write(G.styled(G.gen(rows[1:])))
rc, msg = check(ctl, 'ctl')
grade('arm 4 (control): a table with its first row dropped reads red in the same C check (%s)' % msg, rc == 1, 'the C check did not read it red: rc=%s %s' % (rc, msg))

m2 = G.load(tsv)
m2.append(dict(m2[0]))
try:
    G.validate(m2)
    grade('arm 5 (control): a repeated name reads red', False, 'validate accepted it')
except ValueError:
    grade('arm 5 (control): a repeated name reads red', True)
print('%s: graded=%d fails=%d' % (NAME, graded, fails))
if fails:
    print('⛔ GATE RED [%s]: %d of %d arm(s) failed' % (NAME, fails, graded))
    sys.exit(1)
print('GATE PASS(0) [%s]: %d arm(s) -- %d built-in functions are one static table, found by the runtime hash, fields identical to a registration, nothing registered at start-up' % (NAME, graded, len(rows)))
PY
