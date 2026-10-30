#!/usr/bin/env python3
# util_gen_rt_entry_table.py [--check | --write] [--tsv FILE] [--out DIR] -- harness/scripts/rt_entries.tsv -> SCRIP/src/runtime/rt_entry_table.inc
# (DESIGN-PLAN zeta-layout step 5, stage 5a; ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md section 3 R4; CEO-2019).
#
# rt_entries.tsv is the table of every runtime symbol emitted code calls: what rides rax:rdx at return (rc), whether the call graph reaches the allocator (allocates), which of the
# four RTCC registers the entry hands back changed (clobbers), its calling convention (conv) and whether it may return an address the box jumps to (transfers). This writes the one
# .inc that carries it: the enums, rt_entry_t and g_rt_entries[RT_ENTRIES], laid out by util_reflow_200.py. STAGE 5a: nothing includes the .inc yet; the old derived tables
# (gc_allocating_table.inc, rtx_clobber_table.inc) stay the readers' until stage 5c, and the gate holds the two sides to each other row by row.
# A dash in a column means no source states it (nothing is invented). --check regenerates in memory and compares with the file on disk (rc 0 current, rc 1 stale or the table invalid,
# rc 2 cannot read); --write replaces it.
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
COLS = ['sym', 'conv', 'rc', 'allocates', 'clobbers', 'transfers', 'src']
CONVS = ['leaf', 'gen', 'open', 'asm']
RCS = ['DESCR', 'OTHER', 'VOID', 'UNKNOWN']
CLOB = {'r8': 1, 'r9': 2, 'r10': 4, 'r11': 8}
CLOB_STATED = 16


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
