#!/usr/bin/env python3
"""util_gen_box_cell_shapes.py -- writes SCRIP/src/planner/box_cell_shapes.inc from harness/scripts/box_cell_shapes.tsv, the cell-shape table
(ARCH-ZETA-ONE-COORDINATE 3.5 (iii); ARCH-THREE-ZETAS-EMISSION 10 (3); the cto, CEO-1923). The planner's zd_k_own walks the generated rows top to
bottom and takes the first that matches the node's kind and condition.
  util_gen_box_cell_shapes.py --write     rewrite the .inc
  util_gen_box_cell_shapes.py --check     rc 1 when the committed .inc differs from what the table generates (it names the file), rc 0 when current
rc 2: the table or the SCRIP sibling cannot be read, or a row is malformed (an unknown condition, a non-numeric width other than arm_spine)."""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TSV = os.path.join(HERE, 'box_cell_shapes.tsv')
INC = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP', 'src', 'planner', 'box_cell_shapes.inc'))
WHEN = {'always': 'BCS_ALWAYS', 'call_curmov': 'BCS_CALL_CURMOV', 'icn_local': 'BCS_ICN_LOCAL', 'icn_suspend': 'BCS_ICN_SUSPEND',
        'has_operands': 'BCS_HAS_OPERANDS', 'no_operands': 'BCS_NO_OPERANDS', 'patv': 'BCS_PATV'}


def refuse(msg):
    print('BOX_CELL_SHAPES REFUSE(2): ' + msg)
    sys.exit(2)


def rows():
    try:
        lines = open(TSV, encoding='utf-8').read().splitlines()
    except OSError as e:
        refuse('cannot read %s: %s' % (TSV, e))
    out, head = [], False
    for n, l in enumerate(lines, 1):
        if not l or l.startswith('#'):
            continue
        f = l.split('\t')
        if not head:
            if f[:3] != ['kind', 'alpha_words', 'when']:
                refuse('%s:%d: the header must begin kind, alpha_words, when' % (TSV, n))
            head = True
            continue
        if len(f) != 7:
            refuse('%s:%d: %d columns, want 7' % (TSV, n, len(f)))
        kind, words, when = f[0], f[1], f[2]
        if when not in WHEN:
            refuse('%s:%d: unknown condition %r' % (TSV, n, when))
        if words != 'arm_spine' and not words.isdigit():
            refuse('%s:%d: alpha_words %r is neither a number nor arm_spine' % (TSV, n, words))
        if kind != '*' and not kind.startswith('IR_'):
            refuse('%s:%d: kind %r is neither * nor an IR kind' % (TSV, n, kind))
        out.append((kind, words, when))
    if not out:
        refuse('%s has no rows' % TSV)
    return out


def render(rs):
    body = ['{ %s, %s, %s }' % ('-1' if k == '*' else k, '-1' if w == 'arm_spine' else w, WHEN[c]) for k, w, c in rs]
    lines, cur = [], 'static const struct { int op; int words; int when; } box_cell_shapes[] = {'
    for i, b in enumerate(body):
        item = ' ' + b + (',' if i + 1 < len(body) else ' };')
        if len(cur) + len(item) > 200:
            lines.append(cur)
            cur = '   '
        cur += item
    lines.append(cur)
    text = '\n'.join(lines) + '\n'
    with tempfile.TemporaryDirectory(prefix='bcs.') as t:
        f = os.path.join(t, 'box_cell_shapes.inc')
        open(f, 'w', encoding='utf-8').write(text)
        r = subprocess.run([sys.executable, os.path.join(HERE, 'util_reflow_200.py'), '--apply', f], capture_output=True, text=True)
        if r.returncode not in (0, 1):
            refuse('util_reflow_200.py --apply rc %d: %s' % (r.returncode, r.stderr.strip()))
        return open(f, encoding='utf-8').read()


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('--write', '--check'):
        refuse('usage: util_gen_box_cell_shapes.py --write | --check')
    if not os.path.isdir(os.path.dirname(INC)):
        refuse('no SCRIP sibling at %s' % os.path.dirname(INC))
    rs = rows()
    want = render(rs)
    if sys.argv[1] == '--write':
        open(INC, 'w', encoding='utf-8').write(want)
        print('BOX_CELL_SHAPES wrote %s (%d rows)' % (INC, len(rs)))
        return 0
    have = open(INC, encoding='utf-8').read() if os.path.isfile(INC) else ''
    if have != want:
        print('BOX_CELL_SHAPES STALE: %s differs from what %s generates -- run util_gen_box_cell_shapes.py --write in the landing that edits the table' % (INC, TSV))
        return 1
    print('BOX_CELL_SHAPES current: %s matches %s' % (INC, TSV))
    return 0


if __name__ == '__main__':
    sys.exit(main())
