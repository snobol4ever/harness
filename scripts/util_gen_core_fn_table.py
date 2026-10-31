#!/usr/bin/env python3
# util_gen_core_fn_table.py [--check | --write] [--tsv FILE] [--out DIR] -- harness/scripts/core_fns.tsv -> SCRIP/src/runtime/core/core_fn_table.inc
# (row icon-the-startup-rebuilds-compile-time-tables-procedures-csets-globals-registered-by-c-calls-at-run-time-ceo-1969).
#
# core_fns.tsv is the table of the C functions the runtime knows BY NAME from its first instruction: one row per name (name, the C function, min and max argument counts). core_lib_init used
# to register each row at every start-up with one core_fn_register_lit call (a heap node, a hash, a bucket walk: about 356 user instructions each on the hardware counter, 45,900 for the
# 129 calls of an empty program, in every language). This writes core_fn_table.inc instead: g_core_fn[CORE_FN_N], the rows as read-only FNCBLK_t nodes exactly as core_fn_register_impl
# filled them (name = spec = entry_label = the literal, fn, min_args clamped at 0, max_args, max_set = max_args >= 0); g_core_fn_hash[], each name's full 32-bit _func_hash_raw (h = 5381;
# h = h * 33 ^ byte); g_core_fn_slot[CORE_FN_HASHSZ], the open-addressed index (linear probe, slot = hash & (size - 1), the value is the row number plus one, 0 empty). The registry in core.c
# consults the dynamic chain first and this table second, so a program that registers or defines the same name shadows the row with an ordinary heap node.
# --check regenerates in memory and compares with the file on disk (rc 0 current, rc 1 stale or the table invalid, rc 2 cannot read); --write replaces it.
# THE TABLE IS VALIDATED before anything is written: a header, a C identifier for the function, integer bounds, unique names.
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
COLS = ['name', 'fn', 'min', 'max']


def cstr(s):
    return '"' + ''.join(c if (c.isprintable() and c not in '"\\') else ('\\' + c if c in '"\\' else '\\x%02x' % ord(c)) for c in s) + '"'


def func_hash_raw(name):
    h = 5381
    for b in name.encode('utf-8'):
        h = ((h * 33) ^ b) & 0xFFFFFFFF
    return h


def load(tsv):
    rows, header = [], None
    for ln, raw in enumerate(open(tsv, encoding='utf-8'), 1):
        raw = raw.rstrip('\n')
        if not raw or raw.startswith('#'):
            continue
        f = raw.split('\t')
        if header is None:
            if f != COLS:
                raise ValueError('%s:%d: the header is %s, want %s' % (tsv, ln, f, COLS))
            header = f
            continue
        if len(f) != len(COLS):
            raise ValueError('%s:%d: %d columns, want %d' % (tsv, ln, len(f), len(COLS)))
        r = dict(zip(COLS, f))
        r['ln'] = ln
        rows.append(r)
    return rows


def validate(raw):
    seen, rows = {}, []
    for r in raw:
        w = 'core_fns.tsv:%d (%s)' % (r['ln'], r['name'])
        if not r['name'] or '(' in r['name'] or ',' in r['name'] or ' ' in r['name']:
            raise ValueError(w + ': a name is non-empty and holds no space, comma or parenthesis (register_fn would treat it as a DEFINE spec)')
        if r['name'] in seen:
            raise ValueError(w + ': the same name as row %d' % seen[r['name']])
        seen[r['name']] = r['ln']
        if not re.match(r'^[^\W\d]\w*$', r['fn']):
            raise ValueError(w + ': fn is not a C identifier')
        for k in ('min', 'max'):
            if not re.match(r'^-?\d+$', r[k]):
                raise ValueError(w + ': %s is not an integer' % k)
        x = dict(r)
        x['min'], x['max'] = int(r['min']), int(r['max'])
        rows.append(x)
    if not rows:
        raise ValueError('core_fns.tsv has no rows')
    return sorted(rows, key=lambda x: x['name'])


def pow2_over(n):
    p = 1
    while p < n:
        p *= 2
    return p


def gen(rows):
    n = len(rows)
    size = pow2_over(2 * n)
    slots = [0] * size
    hashes = []
    for i, r in enumerate(rows):
        hv = func_hash_raw(r['name'])
        hashes.append(hv)
        s = hv & (size - 1)
        while slots[s]:
            s = (s + 1) & (size - 1)
        slots[s] = i + 1
    c = []
    c.append('#define CORE_FN_N %d' % n)
    c.append('#define CORE_FN_HASHSZ %d' % size)
    c.append('static const FNCBLK_t g_core_fn[CORE_FN_N] = {')
    for r in rows:
        q = cstr(r['name'])
        c.append('    { %s, %s, %s, %s, 0, 0, 0, 0, %d, %d, %d, 0 },' % (q, q, q, r['fn'], max(r['min'], 0), r['max'], 1 if r['max'] >= 0 else 0))
    c.append('};')
    c.append('static const unsigned g_core_fn_hash[CORE_FN_N] = {')
    for i in range(0, n, 8):
        c.append('    ' + ' '.join('0x%08xu,' % h for h in hashes[i:i + 8]))
    c.append('};')
    c.append('static const unsigned char g_core_fn_slot[CORE_FN_HASHSZ] = {')
    for i in range(0, size, 32):
        c.append('    ' + ' '.join('%d,' % s for s in slots[i:i + 32]))
    c.append('};')
    return '\n'.join(c) + '\n'


def styled(c):
    """The generated text laid out by the fleet's own 200-column tool (util_reflow_200.py), so a regenerated file is the file a seat commits and --check compares like with like."""
    tool = os.path.join(HERE, 'util_reflow_200.py')
    if not os.path.exists(tool):
        raise OSError('no %s' % tool)
    with tempfile.TemporaryDirectory() as d:
        pc = os.path.join(d, 'core_fn_table.inc')
        open(pc, 'w', encoding='utf-8').write(c)
        r = subprocess.run([sys.executable, '-I', tool, '--apply', pc], capture_output=True, text=True)
        if r.returncode != 0:
            raise OSError('util_reflow_200.py --apply failed: %s' % (r.stdout + r.stderr)[-300:])
        return open(pc, encoding='utf-8').read()


def main(argv):
    tsv = os.path.join(HERE, 'core_fns.tsv')
    out = os.path.join(HERE, '..', '..', 'SCRIP', 'src', 'runtime', 'core')
    if '--tsv' in argv:
        tsv = argv[argv.index('--tsv') + 1]
    if '--out' in argv:
        out = argv[argv.index('--out') + 1]
    if not os.path.exists(tsv):
        print('util_gen_core_fn_table: no table at %s' % tsv, file=sys.stderr)
        return 2
    try:
        rows = validate(load(tsv))
    except ValueError as e:
        print('GATE RED: the table is invalid: %s' % e)
        return 1
    try:
        c = styled(gen(rows))
    except OSError as e:
        print('util_gen_core_fn_table: %s' % e, file=sys.stderr)
        return 2
    pc = os.path.join(out, 'core_fn_table.inc')
    if '--write' in argv:
        open(pc, 'w', encoding='utf-8').write(c)
        print('wrote %s: %d rows, %d slots' % (pc, len(rows), pow2_over(2 * len(rows))))
        return 0
    if not os.path.exists(pc) or open(pc, encoding='utf-8').read() != c:
        print('GATE RED: stale or missing: %s -- run: python3 harness/scripts/util_gen_core_fn_table.py --write' % pc)
        return 1
    print('current: %d rows, %d slots' % (len(rows), pow2_over(2 * len(rows))))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
