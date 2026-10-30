#!/usr/bin/env python3
# util_gen_rt_entry_table.py [--check | --write | --sync-decls] [--tsv FILE] [--out DIR] -- harness/scripts/rt_entries.tsv -> SCRIP/src/runtime/rt_entry_table.inc
# (DESIGN-PLAN zeta-layout step 5, stage 5a; ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md section 3 R4; CEO-2019).
#
# rt_entries.tsv is the table of every runtime symbol emitted code calls: what rides rax:rdx at return (rc), whether the call graph reaches the allocator (allocates), which of the
# four RTCC registers the entry hands back changed (clobbers), its calling convention (conv) and whether it may return an address the box jumps to (transfers). This writes the one
# .inc that carries it: the enums, rt_entry_t and g_rt_entries[RT_ENTRIES], laid out by util_reflow_200.py. STAGE 5a: nothing includes the .inc yet; the old derived tables
# (gc_allocating_table.inc, rtx_clobber_table.inc) stay the readers' until stage 5c, and the gate holds the two sides to each other row by row.
# A dash in a column means no source states it (nothing is invented). --check regenerates in memory and compares with the file on disk (rc 0 current, rc 1 stale or the table invalid,
# rc 2 cannot read); --write replaces it.
# STAGE 5b (the declarations at the definitions): a runtime entry's conv and transfers are stated where it is DEFINED, as one textual statement
#   RT_ENTRY_DECL(sym, conv, transfers)      conv leaf | gen | open, transfers 0 | 1 (1 when the entry may return an address the box jumps to: CEO-1576's rt_call_next_t shape)
# anywhere under SCRIP/src (hq_runtime defines the macro however it likes: it may emit a record into a section the binary carries; the text is what this reads). decl_disagreements()
# holds the table to the declarations: a row (an asm entry and a libc import excepted) with no declaration, a symbol declared twice, a conv or transfers that differs, a declaration
# with no row. --sync-decls rewrites the table's conv and transfers columns from the declarations, so the table is derived from them and the gate reads them equal.
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
COLS = ['sym', 'conv', 'rc', 'allocates', 'clobbers', 'transfers', 'src']
CONVS = ['leaf', 'gen', 'open', 'asm']
RCS = ['DESCR', 'OTHER', 'VOID', 'UNKNOWN']
CLOB = {'r8': 1, 'r9': 2, 'r10': 4, 'r11': 8}
CLOB_STATED = 16
DECL = re.compile(r'\bRT_ENTRY_DECL\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*(leaf|gen|open)\s*,\s*([01])\s*\)')
SRC_EXT = ('.c', '.h', '.cpp', '.inc', '.s')


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


def find_decls(root):
    """{sym: [(conv, transfers, path, line)]} for every RT_ENTRY_DECL statement under root."""
    out = {}
    for d, _, fs in os.walk(root):
        for f in sorted(fs):
            if not f.endswith(SRC_EXT):
                continue
            p = os.path.join(d, f)
            try:
                text = open(p, encoding='utf-8', errors='replace').read()
            except OSError:
                continue
            if 'RT_ENTRY_DECL' not in text:
                continue
            for m in DECL.finditer(text):
                out.setdefault(m.group(1), []).append((m.group(2), m.group(3), p, text.count('\n', 0, m.start()) + 1))
    return out


def decl_disagreements(rows, decls):
    """The lines naming every way the table and the declarations at the definitions differ; empty when they agree."""
    bad, bysym = [], {r['sym']: r for r in rows}
    for r in rows:
        if r['conv'] == 'asm' or 'import' in r['src'].split(','):
            continue
        ds = decls.get(r['sym'], [])
        if not ds:
            bad.append('%s: no RT_ENTRY_DECL at its definition' % r['sym'])
        elif len(ds) > 1:
            bad.append('%s: declared %d times (%s)' % (r['sym'], len(ds), ', '.join('%s:%d' % (os.path.basename(x[2]), x[3]) for x in ds)))
        elif (ds[0][0], ds[0][1]) != (r['conv'], r['transfers']):
            bad.append('%s: the table says conv %s transfers %s, the declaration says conv %s transfers %s' % (r['sym'], r['conv'], r['transfers'], ds[0][0], ds[0][1]))
    for sym in sorted(decls):
        if sym not in bysym:
            bad.append('%s: declared with RT_ENTRY_DECL but the table has no row' % sym)
        elif bysym[sym]['conv'] == 'asm' or 'import' in bysym[sym]['src'].split(','):
            bad.append('%s: declared with RT_ENTRY_DECL but its row is an %s' % (sym, 'asm entry (RTX_FUNC states it)' if bysym[sym]['conv'] == 'asm' else 'import'))
    return bad


def sync_decls(tsv, decls):
    """Rewrite the conv and transfers columns of tsv from the declarations (one declaration per row, an asm entry and an import left alone); returns the number of rows changed."""
    lines, n, header = open(tsv, encoding='utf-8').read().split('\n'), 0, False
    for i, raw in enumerate(lines):
        if not raw or raw.startswith('#'):
            continue
        f = raw.split('\t')
        if not header:
            header = True
            continue
        if len(f) != len(COLS) or f[1] == 'asm' or 'import' in f[6].split(','):
            continue
        ds = decls.get(f[0], [])
        if len(ds) == 1 and (f[1], f[5]) != (ds[0][0], ds[0][1]):
            f[1], f[5] = ds[0][0], ds[0][1]
            lines[i] = '\t'.join(f)
            n += 1
    open(tsv, 'w', encoding='utf-8').write('\n'.join(lines))
    return n


def validate(raw):
    rows, seen = [dict(r) for r in raw], {}
    for r in rows:
        w = 'rt_entries.tsv:%d (%s)' % (r['ln'], r['sym'])
        if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', r['sym']):
            raise ValueError(w + ': sym is not a C identifier')
        if r['sym'] in seen:
            raise ValueError(w + ': the same sym as row %d' % seen[r['sym']])
        seen[r['sym']] = r['ln']
        if r['conv'] != '-' and r['conv'] not in CONVS:
            raise ValueError(w + ': conv %s is not one of %s or -' % (r['conv'], CONVS))
        if r['rc'] != '-' and r['rc'] not in RCS:
            raise ValueError(w + ': rc %s is not one of %s or -' % (r['rc'], RCS))
        if r['allocates'] not in ('0', '1', '-'):
            raise ValueError(w + ': allocates must be 0, 1 or -')
        if r['transfers'] not in ('0', '1', '-'):
            raise ValueError(w + ': transfers must be 0, 1 or -')
        bits = 0
        if r['clobbers'] == 'none':
            bits = CLOB_STATED
        elif r['clobbers'] != '-':
            for x in r['clobbers'].split('|'):
                if x not in CLOB:
                    raise ValueError(w + ': clobber %s is not one of %s' % (x, list(CLOB)))
                bits |= CLOB[x]
            bits |= CLOB_STATED
        r['clobbits'] = bits
    return sorted(rows, key=lambda r: r['sym'])


def gen(rows):
    out = ['#ifndef RT_ENTRY_TABLE_INC', '#define RT_ENTRY_TABLE_INC']
    out.append('#define RT_ENTRIES %d' % len(rows))
    out.append('enum { RT_CONV_NONE = 0, ' + ', '.join('RT_CONV_%s = %d' % (c.upper(), i + 1) for i, c in enumerate(CONVS)) + ' };')
    out.append('enum { RT_RC_NONE = 0, ' + ', '.join('RT_RC_%s = %d' % (c, i + 1) for i, c in enumerate(RCS)) + ' };')
    out.append('enum { ' + ', '.join('RT_CLOB_%s = %d' % (k.upper(), v) for k, v in CLOB.items()) + ', RT_CLOB_STATED = %d };' % CLOB_STATED)
    out.append('typedef struct { const char * sym; unsigned char conv; unsigned char rc; signed char allocates; unsigned char clobbers; signed char transfers; } rt_entry_t;')
    out.append('static const rt_entry_t g_rt_entries[RT_ENTRIES] = {')
    for r in rows:
        out.append('    { "%s", %s, %s, %s, %d, %s },' % (r['sym'], 'RT_CONV_' + r['conv'].upper() if r['conv'] != '-' else 'RT_CONV_NONE', 'RT_RC_' + r['rc'] if r['rc'] != '-' else 'RT_RC_NONE',
                                                         '-1' if r['allocates'] == '-' else r['allocates'], r['clobbits'], '-1' if r['transfers'] == '-' else r['transfers']))
    out.append('};')
    out.append('#endif')
    return '\n'.join(out) + '\n'


def styled(text):
    tool = os.path.join(HERE, 'util_reflow_200.py')
    if not os.path.exists(tool):
        raise OSError('no %s' % tool)
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, 'rt_entry_table.inc')
        open(p, 'w', encoding='utf-8').write(text)
        r = subprocess.run([sys.executable, '-I', tool, '--apply', p], capture_output=True, text=True)
        if r.returncode != 0:
            raise OSError('util_reflow_200.py --apply failed: %s' % (r.stdout + r.stderr)[-300:])
        return open(p, encoding='utf-8').read()


def main(argv):
    tsv = os.path.join(HERE, 'rt_entries.tsv')
    out = os.path.join(HERE, '..', '..', 'SCRIP', 'src', 'runtime')
    if '--tsv' in argv:
        tsv = argv[argv.index('--tsv') + 1]
    if '--out' in argv:
        out = argv[argv.index('--out') + 1]
    if not os.path.exists(tsv):
        print('util_gen_rt_entry_table: no table at %s' % tsv, file=sys.stderr)
        return 2
    if '--sync-decls' in argv:
        src = os.path.join(HERE, '..', '..', 'SCRIP', 'src')
        n = sync_decls(tsv, find_decls(src))
        print('synced %d row(s) of %s from the RT_ENTRY_DECL statements under %s; now run --write' % (n, tsv, os.path.abspath(src)))
        return 0
    try:
        rows = validate(load(tsv))
        text = styled(gen(rows))
    except ValueError as e:
        print('GATE RED: the table is invalid: %s' % e)
        return 1
    except OSError as e:
        print('util_gen_rt_entry_table: %s' % e, file=sys.stderr)
        return 2
    p = os.path.join(out, 'rt_entry_table.inc')
    if '--write' in argv:
        open(p, 'w', encoding='utf-8').write(text)
        print('wrote %s: %d rows' % (p, len(rows)))
        return 0
    if not os.path.exists(p) or open(p, encoding='utf-8').read() != text:
        print('GATE RED: stale or missing: %s -- run: python3 harness/scripts/util_gen_rt_entry_table.py --write' % p)
        return 1
    print('current: %d rows' % len(rows))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
