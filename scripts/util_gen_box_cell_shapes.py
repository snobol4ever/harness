#!/usr/bin/env python3
"""util_gen_box_cell_shapes.py -- writes SCRIP/src/planner/box_cell_shapes.inc from harness/scripts/box_cell_shapes.tsv, the cell-shape table
(ARCH-ZETA-ONE-COORDINATE 3.5 (iii); ARCH-THREE-ZETAS-EMISSION 10 (3); the cto, CEO-1923). The planner's zd_k_own walks the generated rows top to
bottom and takes the first that matches the node's kind and condition.
  util_gen_box_cell_shapes.py --write     rewrite the .inc
  util_gen_box_cell_shapes.py --check     rc 1 when the committed .inc differs from what the table generates (it names the file), rc 0 when current
rc 2: the table or the SCRIP sibling cannot be read, or a row is malformed (an unknown condition, a non-numeric width other than arm_spine,
arm_spine_hdr, call_args -- the computed widths: the disjunction's arm extent, that extent plus the Prolog choice header, and a call's argument block)."""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TSV = os.path.join(HERE, 'box_cell_shapes.tsv')
INC = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP', 'src', 'planner', 'box_cell_shapes.inc'))
WHEN = {'always': 'BCS_ALWAYS', 'call_curmov': 'BCS_CALL_CURMOV', 'icn_local': 'BCS_ICN_LOCAL', 'icn_suspend': 'BCS_ICN_SUSPEND',
        'has_operands': 'BCS_HAS_OPERANDS', 'no_operands': 'BCS_NO_OPERANDS', 'patv': 'BCS_PATV', 'home_frame': 'BCS_HOME_FRAME', 'icn_home': 'BCS_ICN_HOME',
        'home_state': 'BCS_HOME_STATE', 'pl_home': 'BCS_PL_HOME', 'pl_home_dyn': 'BCS_PL_HOME_DYN', 'pl_home_range_hdr': 'BCS_PL_HOME_RANGE_HDR',
        'pl_home_has_operands': 'BCS_PL_HOME_HAS_OPERANDS', 'pl_bound_spine': 'BCS_PL_BOUND_SPINE', 'pl_spine_record': 'BCS_PL_SPINE_RECORD', 'pl_gate_arm': 'BCS_PL_GATE_ARM', 'pl_to_trailed': 'BCS_PL_TO_TRAILED', 'pl_to_db': 'BCS_PL_TO_DB',
        'call_argv': 'BCS_CALL_ARGV', 'call_argv_cur': 'BCS_CALL_ARGV_CUR', 'call_argv_rec': 'BCS_CALL_ARGV_REC', 'call_argv_cur_rec': 'BCS_CALL_ARGV_CUR_REC'}
FIXED = {'arm_spine': 32, 'arm_spine_hdr': 64}
WORDS = {'arm_spine': '-1', 'arm_spine_hdr': '-2', 'call_args': '-3', 'fence_spine': '-4', 'alt_spine': '-5', 'call_argv': '-6', 'call_argv_cur': '-7', 'call_argv_rec': '-8', 'call_argv_cur_rec': '-9'}


def refuse(msg):
    print('BOX_CELL_SHAPES REFUSE(2): ' + msg)
    sys.exit(2)


def wordkind(n, words, spec):
    pre, fill, suf = spec, '', ''
    if '[' in spec:
        a, b = spec.index('['), spec.index(']') if ']' in spec else -1
        if b != a + 2 or spec[a + 1] not in 'Dr' or spec.count('[') != 1 or spec.count(']') != 1:
            refuse('%s:%d: word_kind %r has a malformed fill (one [D] or [r] at most)' % (TSV, n, spec))
        pre, fill, suf = spec[:a], spec[a + 1], spec[b + 1:]
    if pre == '-':
        pre = ''
    if any(c not in 'Dr' for c in pre + suf):
        refuse('%s:%d: word_kind %r is not a string over D (a 16-byte DESCR cell) and r (a raw 8-byte word)' % (TSV, n, spec))
    if (words.isdigit() or words in FIXED) and fill:
        refuse('%s:%d: word_kind %r has a fill but alpha_words %s is a fixed width' % (TSV, n, spec, words))
    if words in ('call_args', 'fence_spine', 'alt_spine', 'call_argv', 'call_argv_cur', 'call_argv_rec', 'call_argv_cur_rec') and not fill:
        refuse('%s:%d: alpha_words %s is a computed width and needs a [D] or [r] fill in word_kind %r' % (TSV, n, words, spec))
    nw = lambda t: sum(2 if c == 'D' else 1 for c in t)
    want = int(words) if words.isdigit() else FIXED.get(words, 0)
    if want and nw(pre) * 8 != want:
        refuse('%s:%d: word_kind %r spans %d bytes, alpha_words %s says %d' % (TSV, n, spec, nw(pre) * 8, words, want))

    def mk(t):
        m, w = 0, 0
        for c in t:
            if c == 'D':
                m |= 1 << w
            w += 2 if c == 'D' else 1
        return m, w
    pm, pn = mk(pre)
    sm, sn = mk(suf)
    return (pm, pn, {'': 0, 'D': 1, 'r': 2}[fill], sm, sn)


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
            if f[:4] != ['kind', 'alpha_words', 'when', 'word_kind']:
                refuse('%s:%d: the header must begin kind, alpha_words, when, word_kind' % (TSV, n))
            head = True
            continue
        if len(f) != 8:
            refuse('%s:%d: %d columns, want 8' % (TSV, n, len(f)))
        kind, words, when, spec = f[0], f[1], f[2], f[3]
        if when not in WHEN:
            refuse('%s:%d: unknown condition %r' % (TSV, n, when))
        if words not in WORDS and not words.isdigit():
            refuse('%s:%d: alpha_words %r is neither a number nor one of %s' % (TSV, n, words, ' '.join(sorted(WORDS))))
        if kind != '*' and not kind.startswith('IR_'):
            refuse('%s:%d: kind %r is neither * nor an IR kind' % (TSV, n, kind))
        out.append((kind, words, when, wordkind(n, words, spec)))
    if not out:
        refuse('%s has no rows' % TSV)
    return out


def render(rs):
    body = ['{ %s, %s, %s, %d, %d, %d, %d, %d }' % (('-1' if k == '*' else k, WORDS.get(w, w), WHEN[c]) + wk) for k, w, c, wk in rs]
    lines, cur = [], 'static const struct { int op; int words; int when; unsigned wk_pre; int wk_pre_n; int wk_fill; unsigned wk_suf; int wk_suf_n; } box_cell_shapes[] = {'
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
