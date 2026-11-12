#!/usr/bin/env python3
# util_gen_builtin_table.py [--check | --write] [--tsv FILE] [--out DIR] -- harness/scripts/builtins.tsv -> SCRIP/src/runtime/builtin_table.h, builtin_table.c, builtin_leaf.h and builtin_leaf.c
# (DESIGN-PLAN builtin-table step 1; ARCH-BUILTIN-TABLE.md section 3; R-2016).
#
# builtins.tsv is the ONE table of builtins: one row per builtin per vocabulary. This writes the two generated files the runtime and the compiler include:
#   builtin_table_n.h  BT_ROWS and BT_BID_MAX alone, the two lines a new row changes, so a regeneration recompiles the two data units and
#                      kernel.c, never every includer of builtin_table.h (cache-tree, CTO-636; 39 of 40 regenerations changed only these)
#   builtin_table.h    bt_row_t, the enums, BT_LEGACY_LAST, and bt_bid_legacy(s, len): the vocabulary-blind hash of the 186 names that carried an id before the
#                      table existed (builtin_ids.h). bid_of in builtin_ids.h IS bt_bid_legacy, so every name resolves to exactly the id it resolved to before the table: step 1
#                      changes no resolution. A row with a bid above BT_LEGACY_LAST is a name no code resolves yet; its language step lifts it.
#   builtin_table.c    (a data unit of its own since DESIGN-PLAN cache-tree C1, CTO-636; it was builtin_table.inc, spliced into by_name_dispatch.c) g_builtins[BT_ROWS] (the rows in bid order), bt_row_of(vocab, s, len) (the row index of a name, -1 for none) and bt_bid_of(vocab, s, len): the open-addressed
#                      hash of every row by vocabulary and name. Included by ONE translation unit of the runtime.
#   builtin_leaf.h and builtin_leaf.c (C1 as above: the declarations, and the two tables as hidden definitions in a unit of their own) bt_leaf_t and g_bt_leaf[BT_ROWS]: the leaf of every row whose conv is leaf and whose entry is a bt_ name (a bt_ entry promises the leaf shape
#                      DESCR_t f(DESCR_t *args, int nargs); a leaf that declines returns a DESCR_t whose .v is RTX_NOT_HANDLED); bt_open_t and g_bt_open[BT_ROWS]: the same for a
#                      row whose conv is open (int f(DESCR_t *args, int nargs, DESCR_t *out, long *rq): the road that may ask the box to open a call; it returns 0 when it declines). A leaf not written yet is a weak hidden reference that
#                      resolves to 0, so a step lands one chain at a time; test_gate_every_leaf_row_has_its_leaf closes that at the finish. Included by ONE translation unit.
# --check regenerates in memory and compares with the files on disk (rc 0 current, rc 1 stale or the table invalid, rc 2 cannot read); --write replaces them.
# THE TABLE IS VALIDATED before anything is written: unique bids, unique (vocab, name), a known vocab and conv, an entry on every row that is not inline, integer or "-" bounds.
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
VOCABS = ['sno', 'icn', 'pas', 'rk', 'rkm', 'pl']
CONVS = ['leaf', 'gen', 'open', 'inline']
FLAGS = {'scan': 1, 'mut': 2}
COLS = ['bid', 'vocab', 'name', 'min', 'max', 'entry', 'conv', 'recv', 'flags', 'op', 'src']
RECVS = ['*', '-', 'Str', 'Int', 'Num', 'Rat', 'Complex', 'Bool', 'List', 'Array', 'Hash', 'Map', 'Range', 'Code', 'Any']
UNSTATED = -128


def cstr(s):
    return '"' + ''.join(c if (c.isprintable() and c not in '"\\') else ('\\' + c if c in '"\\' else '\\x%02x' % ord(c)) for c in s) + '"'


def sanitize(name):
    out = ''.join(c if (c.isalnum() or c == '_') else 'x%02X' % ord(c) for c in name)
    return ('_' + out) if out and out[0].isdigit() else out


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
    rows = [dict(r) for r in raw]
    seen_b, seen_n = {}, {}
    for r in rows:
        w = 'builtins.tsv:%d (%s %s)' % (r['ln'], r['vocab'], r['name'])
        if not re.match(r'^\d+$', r['bid']) or int(r['bid']) < 1:
            raise ValueError(w + ': bid must be a positive integer')
        r['bid'] = int(r['bid'])
        if r['bid'] in seen_b:
            raise ValueError(w + ': bid %d is also row %d (an id is assigned once and never reused)' % (r['bid'], seen_b[r['bid']]))
        seen_b[r['bid']] = r['ln']
        if r['vocab'] not in VOCABS:
            raise ValueError(w + ': vocab %s is not one of %s' % (r['vocab'], VOCABS))
        if not r['name']:
            raise ValueError(w + ': empty name')
        k = (r['vocab'], r['name'])
        if k in seen_n:
            raise ValueError(w + ': the same vocab and name as row %d' % seen_n[k])
        seen_n[k] = r['ln']
        if r['conv'] not in CONVS:
            raise ValueError(w + ': conv %s is not one of %s' % (r['conv'], CONVS))
        if r['conv'] != 'inline' and r['entry'] in ('', '-'):
            raise ValueError(w + ': a row that is not inline needs an entry')
        for c in ('min', 'max'):
            if r[c] != '-' and not re.match(r'^-?\d+$', r[c]):
                raise ValueError(w + ': %s must be an integer or -' % c)
            r[c] = UNSTATED if r[c] == '-' else int(r[c])
        if not re.match(r'^-?\d+$', r['op']):
            raise ValueError(w + ': op must be an integer')
        r['op'] = int(r['op'])
        if r['recv'] not in RECVS:
            raise ValueError(w + ': recv %s is not one of %s' % (r['recv'], RECVS))
        fl = 0
        for x in ([] if r['flags'] == '-' else r['flags'].split(',')):
            if x not in FLAGS:
                raise ValueError(w + ': flag %s is not one of %s' % (x, list(FLAGS)))
            fl |= FLAGS[x]
        r['flagbits'] = fl
    return sorted(rows, key=lambda r: r['bid'])


def legacy_rows(rows):
    return [r for r in rows if 'ids' in r['src'].split(',')]


def djb2(s):
    h = 5381
    for b in s.encode('utf-8'):
        h = (h * 33 + b) & 0xFFFFFFFF
    return h


def slot(key, size):
    if isinstance(key, tuple):
        return (djb2(key[1]) + key[0] * 0x9E3779B1) & 0xFFFFFFFF & (size - 1)
    return djb2(key) & (size - 1)


def probe(table_size, items):
    slots = [None] * table_size
    for key, val in items:
        h = slot(key, table_size)
        while slots[h] is not None:
            h = (h + 1) & (table_size - 1)
        slots[h] = (key, val)
    return slots


def pow2_over(n):
    p = 1
    while p < n:
        p <<= 1
    return p


OWN_SLOT_VOCABS = ('rk',)


def slot_sym(r):
    if r['entry'].startswith('bt_'):
        return r['entry']
    if r['vocab'] in OWN_SLOT_VOCABS and r['conv'] in ('leaf', 'open'):
        return 'bt_' + sanitize(r['name'])
    return None


def is_leaf_row(r):
    return r['conv'] == 'leaf' and slot_sym(r) is not None


def is_open_row(r):
    return r['conv'] == 'open' and slot_sym(r) is not None


def gen(rows):
    n, bmax = len(rows), max(r['bid'] for r in rows)
    leg = legacy_rows(rows)
    legmax = max(r['bid'] for r in leg)
    lsz = pow2_over(4 * len(leg))
    lslots = probe(lsz, [(r['name'], r['bid']) for r in leg])
    hsz = pow2_over(2 * n)
    hslots = probe(hsz, [((VOCABS.index(r['vocab']), r['name']), i) for i, r in enumerate(rows)])
    wname = max(len(r['name'].encode('utf-8')) for r in rows) + 1
    wentry = max(len(r['entry'].encode('utf-8')) if r['entry'] != '-' else 0 for r in rows) + 1
    wleg = max(len(r['name'].encode('utf-8')) for r in leg) + 1
    h = []
    h.append('#ifndef BUILTIN_TABLE_H')
    h.append('#define BUILTIN_TABLE_H')
    h.append('#include <string.h>')
    h.append('#define BT_LEGACY_LAST %d' % legmax)
    h.append('#define BT_LEGACY_TABSZ %d' % lsz)
    h.append('#define BT_HASHSZ %d' % hsz)
    h.append('#define BT_UNSTATED (%d)' % UNSTATED)
    h.append('#define BT_NAME_W %d' % wname)
    h.append('#define BT_ENTRY_W %d' % wentry)
    h.append('#define BT_LEGACY_W %d' % wleg)
    h.append('enum { ' + ', '.join('BT_VOC_%s = %d' % (v.upper(), i) for i, v in enumerate(VOCABS)) + ' };')
    h.append('enum { ' + ', '.join('BT_CONV_%s = %d' % (c.upper(), i) for i, c in enumerate(CONVS)) + ' };')
    h.append('enum { ' + ', '.join('BT_FLAG_%s = %d' % (f.upper(), b) for f, b in FLAGS.items()) + ' };')
    h.append('typedef struct { char name[BT_NAME_W]; char entry[BT_ENTRY_W]; unsigned short bid; unsigned char vocab; unsigned char conv; unsigned char flags; unsigned char recv; signed char min; signed char max; short op; } bt_row_t;')
    h.append('extern const bt_row_t g_builtins[];')
    h.append('int bt_row_of(int vocab, const char * s, unsigned len);')
    h.append('int bt_bid_of(int vocab, const char * s, unsigned len);')
    h.append('static const struct { char nm[BT_LEGACY_W]; unsigned short len; unsigned short id; } bt_legacy_tab[BT_LEGACY_TABSZ] = {')
    for i in range(0, lsz, 4):
        h.append('    ' + ' '.join(('{%s,%d,%d},' % (cstr(s[0]), len(s[0].encode('utf-8')), s[1])) if s else '{"",0,0},' for s in lslots[i:i + 4]))
    h.append('};')
    h.append('static inline int bt_bid_legacy(const char * s, unsigned len) {')
    h.append('    unsigned hv = 5381u;')
    h.append('    unsigned i;')
    h.append('    if (!s || !len) return 0;')
    h.append('    for (i = 0; i < len; i++) hv = hv * 33u + (unsigned char)s[i];')
    h.append('    hv &= (unsigned)(BT_LEGACY_TABSZ - 1);')
    h.append('    for (;;) { const char * n = bt_legacy_tab[hv].nm; if (!n[0]) return 0; if (bt_legacy_tab[hv].len == len && !memcmp(n, s, len)) return bt_legacy_tab[hv].id; hv = (hv + 1u) & (unsigned)(BT_LEGACY_TABSZ - 1); }')
    h.append('}')
    h.append('#endif')
    c = []
    c.append('#include "runtime/builtin_table.h"')
    c.append('#include "runtime/builtin_table_n.h"')
    c.append('#include "runtime/builtin_ids.h"')
    c.append('_Static_assert(BT_BID_MAX < BID_TABSZ, "a builtin id at or past BID_TABSZ reads outside g_bn_direct: grow BID_TABSZ, a power of two, past BT_BID_MAX");')
    c.append('const bt_row_t g_builtins[BT_ROWS] = {')
    for r in rows:
        c.append('    { %s, %s, %d, BT_VOC_%s, BT_CONV_%s, %d, %d, %d, %d, %d },' % (cstr(r['name']), cstr(r['entry']) if r['entry'] != '-' else '""', r['bid'], r['vocab'].upper(), r['conv'].upper(),
            r['flagbits'], RECVS.index(r['recv']), r['min'], r['max'], r['op']))
    c.append('};')
    c.append('static const unsigned short bt_hash_tab[BT_HASHSZ] = {')
    for i in range(0, hsz, 16):
        c.append('    ' + ','.join(str(s[1] + 1) if s else '0' for s in hslots[i:i + 16]) + ',')
    c.append('};')
    c.append('int bt_row_of(int vocab, const char * s, unsigned len) {')
    c.append('    unsigned hv = 5381u;')
    c.append('    unsigned i;')
    c.append('    if (!s || !len) return -1;')
    c.append('    for (i = 0; i < len; i++) hv = hv * 33u + (unsigned char)s[i];')
    c.append('    hv = (hv + (unsigned)vocab * 0x9E3779B1u) & (unsigned)(BT_HASHSZ - 1);')
    c.append('    for (;;) { unsigned k = bt_hash_tab[hv]; if (!k) return -1; { const bt_row_t * r = &g_builtins[k - 1]; if (r->vocab == vocab && !strncmp(r->name, s, len) && !r->name[len]) return (int)(k - 1); } hv = (hv + 1u) & (unsigned)(BT_HASHSZ - 1); }')
    c.append('}')
    c.append('int bt_bid_of(int vocab, const char * s, unsigned len) {')
    c.append('    int k = bt_row_of(vocab, s, len);')
    c.append('    return k < 0 ? 0 : g_builtins[k].bid;')
    c.append('}')
    l, ld = [], []
    l.append('#ifndef BUILTIN_LEAF_H')
    l.append('#define BUILTIN_LEAF_H')
    l.append('#include "ir/descr.h"')
    l.append('#include "runtime/builtin_table.h"')
    l.append('typedef DESCR_t (*bt_leaf_t)(DESCR_t * args, int nargs);')
    ld.append('#include "runtime/builtin_leaf.h"')
    ld.append('#include "runtime/builtin_table_n.h"')
    seen = []
    for r in rows:
        if is_leaf_row(r) and slot_sym(r) not in seen:
            seen.append(slot_sym(r))
            l.append('extern DESCR_t %s(DESCR_t * args, int nargs) __attribute__((weak, visibility("hidden")));' % slot_sym(r))
    l.append('extern __attribute__((visibility("hidden"))) const bt_leaf_t g_bt_leaf[];')
    ld.append('__attribute__((visibility("hidden"))) const bt_leaf_t g_bt_leaf[BT_ROWS] = {')
    for i in range(0, n, 8):
        ld.append('    ' + ' '.join(('%s,' % slot_sym(r)) if is_leaf_row(r) else '0,' for r in rows[i:i + 8]))
    ld.append('};')
    l.append('typedef int (*bt_open_t)(DESCR_t * args, int nargs, DESCR_t * out, long * rq);')
    for r in rows:
        if is_open_row(r) and slot_sym(r) not in seen:
            seen.append(slot_sym(r))
            l.append('extern int %s(DESCR_t * args, int nargs, DESCR_t * out, long * rq) __attribute__((weak, visibility("hidden")));' % slot_sym(r))
    l.append('extern __attribute__((visibility("hidden"))) const bt_open_t g_bt_open[];')
    l.append('#endif')
    ld.append('__attribute__((visibility("hidden"))) const bt_open_t g_bt_open[BT_ROWS] = {')
    for i in range(0, n, 8):
        ld.append('    ' + ' '.join(('%s,' % slot_sym(r)) if is_open_row(r) else '0,' for r in rows[i:i + 8]))
    ld.append('};')
    nh = ['#ifndef BUILTIN_TABLE_N_H', '#define BUILTIN_TABLE_N_H', '#define BT_ROWS %d' % n, '#define BT_BID_MAX %d' % bmax, '#endif']
    return '\n'.join(h) + '\n', '\n'.join(c) + '\n', '\n'.join(l) + '\n', '\n'.join(ld) + '\n', '\n'.join(nh) + '\n'


OUTS = ('builtin_table.h', 'builtin_table.c', 'builtin_leaf.h', 'builtin_leaf.c', 'builtin_table_n.h')


def styled(*texts):
    """The generated text laid out by the fleet's own 200-column tool (util_reflow_200.py), so a regenerated file is the file a seat commits and --check compares like with like."""
    tool = os.path.join(HERE, 'util_reflow_200.py')
    if not os.path.exists(tool):
        raise OSError('no %s' % tool)
    with tempfile.TemporaryDirectory() as d:
        ps = [os.path.join(d, n) for n in OUTS]
        for p, t in zip(ps, texts):
            open(p, 'w', encoding='utf-8').write(t)
        r = subprocess.run([sys.executable, '-I', tool, '--apply'] + ps, capture_output=True, text=True)
        if r.returncode != 0:
            raise OSError('util_reflow_200.py --apply failed: %s' % (r.stdout + r.stderr)[-300:])
        return tuple(open(p, encoding='utf-8').read() for p in ps)


def main(argv):
    tsv = os.path.join(HERE, 'builtins.tsv')
    out = os.path.join(HERE, '..', '..', 'SCRIP', 'src', 'runtime')
    if '--tsv' in argv:
        tsv = argv[argv.index('--tsv') + 1]
    if '--out' in argv:
        out = argv[argv.index('--out') + 1]
    if not os.path.exists(tsv):
        print('util_gen_builtin_table: no table at %s' % tsv, file=sys.stderr)
        return 2
    try:
        rows = validate(load(tsv))
    except ValueError as e:
        print('GATE RED: the table is invalid: %s' % e)
        return 1
    try:
        texts = styled(*gen(rows))
    except OSError as e:
        print('util_gen_builtin_table: %s' % e, file=sys.stderr)
        return 2
    paths = [os.path.join(out, n) for n in OUTS]
    if '--write' in argv:
        for p, t in zip(paths, texts):
            open(p, 'w', encoding='utf-8').write(t)
        print('wrote %s: %d rows, bids up to %d, %d legacy' % (', '.join(paths), len(rows), max(r['bid'] for r in rows), len(legacy_rows(rows))))
        return 0
    stale = [p for p, want in zip(paths, texts) if not os.path.exists(p) or open(p, encoding='utf-8').read() != want]
    if stale:
        print('GATE RED: stale or missing: %s -- run: python3 harness/scripts/util_gen_builtin_table.py --write' % ', '.join(stale))
        return 1
    print('current: %d rows, bids up to %d, %d legacy' % (len(rows), max(r['bid'] for r in rows), len(legacy_rows(rows))))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
