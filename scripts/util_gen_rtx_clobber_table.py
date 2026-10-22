#!/usr/bin/env python3
"""util_gen_rtx_clobber_table.py -- THE LEAF CLOBBER TABLE, DERIVED FROM THE ASSEMBLED OBJECTS AND GATED AGAINST THEM
(cto 2026-09-30, row rtx-leaves-carry-no-register-veneer-an-asm-runtime-call-is-not-a-c-function; Lon 2026-09-30, in-chat
to the ceo, verbatim: "Ensure the veneer to save and restore registers has been removed from ALL x86 asm runtime calls since
they are not C functions and do not require the extra."; ARCH-RT-CALL-PROTOCOL.md section 15 THE LEAF CONTRACT).

WHAT IT WRITES.  src/templates/x86/rtx_clobber_table.inc: one row per registered asm-runtime entry (the registry is the
rtx_entry_names section RTX_FUNC and RTX_ENTRY append to, read out of the objects -- never typed), naming which of the RTCC
four the entry can hand back changed: r8, r10, r11 other than as received, r9 other than the GVA base.  The emitter's
x86_rtcc_clob_raw() reads it for every call into the asm runtime: mask 0 keeps the bare call, a named register is
re-established at the call site after the call (r9 from its master slot g_rtccb+48, r11 from the box id the site holds) --
the site knows what is live, the leaf saves nothing.

HOW.  The same recipe as test_gate_rtx_entries_keep_the_rtcc_four.sh: every src/runtime/rtx/*.s assembled into a scratch
directory with the Makefile's own RT_INCS, the registry read with objcopy, and ../harness/scripts/util_rtx_abi_walk.py --clobber-table
abstract-interpreting every entry along every path (a body it cannot read REFUSES the whole table: rc 2, nothing written).

Usage: util_gen_rtx_clobber_table.py [--root DIR] [--out FILE] [--check]
  --check   read the objects, derive the table, and compare it with the checked-in file: rc 0 when identical, 1 when the
            checked-in table is stale (the diff is printed), 2 when the table could not be derived.
Exit 0 = written (or identical under --check), 1 = stale under --check, 2 = could not derive.
"""
import os, re, subprocess, sys, tempfile, shutil

REGBIT = {'r8': 'RTCC_C_R8', 'r9': 'RTCC_C_R9', 'r10': 'RTCC_C_R10', 'r11': 'RTCC_C_R11'}


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace', **kw)
    return r.returncode, r.stdout, r.stderr


def rt_incs(root):
    txt = open(os.path.join(root, 'Makefile'), encoding='utf-8', errors='replace').read().replace('\\\n', ' ')
    m = re.search(r'^RT_INCS\s*:=\s*(.*)$', txt, re.M)
    if not m: return None
    v = m.group(1).split('#')[0].replace('$(SRC)', root + '/src').replace('$(RT)', root + '/src/runtime')
    return [t for t in v.split() if t.startswith('-I')]


def derive(root):
    incs = rt_incs(root)
    if incs is None: return None, 'could not read RT_INCS out of the Makefile'
    rtx = os.path.join(root, 'src', 'runtime', 'rtx')
    srcs = sorted(f for f in os.listdir(rtx) if f.endswith('.s'))
    if not srcs: return None, 'no src/runtime/rtx/*.s'
    work = tempfile.mkdtemp(prefix='rtxclob.')
    try:
        objs = []
        for s in srcs:
            o = os.path.join(work, s[:-2] + '.o')
            rc, out, err = run(['gcc', '-g', '-w', '-fPIC'] + incs + ['-I' + rtx, '-x', 'assembler-with-cpp', '-c', os.path.join(rtx, s), '-o', o])
            if rc != 0: return None, 'could not assemble %s: %s' % (s, err.strip()[:300])
            objs.append(o)
        names = b''
        for o in objs:
            rc, out, err = run(['objcopy', '-O', 'binary', '--only-section=rtx_entry_names', o, o + '.names'])
            if rc == 0 and os.path.exists(o + '.names'): names += open(o + '.names', 'rb').read()
        entries = [n.decode('utf-8') for n in names.split(b'\0') if n]
        if not entries: return None, 'the objects define no rtx_entry_names'
        ef = os.path.join(work, 'entries.txt')
        open(ef, 'w', encoding='utf-8').write(''.join(e + '\n' for e in entries))
        walker = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'util_rtx_abi_walk.py')
        rc, out, err = run([sys.executable, walker] + objs + ['--entries', ef, '--clobber-table'])
        if rc != 0: return None, 'the walker could not derive the table (rc %d): %s' % (rc, (out + err).strip()[-600:])
        table = {}
        for line in out.split('\n'):
            m = re.match(r'^RTX-CLOBBER (\S+) (\S+)$', line)
            if m: table[m.group(1)] = () if m.group(2) == '-' else tuple(m.group(2).split(','))
        if len(table) != len(entries): return None, 'the walker reported %d of %d entries' % (len(table), len(entries))
        return table, None
    finally:
        shutil.rmtree(work, ignore_errors=True)


def render(table):
    rows = []
    for name in sorted(table):
        regs = table[name]
        mask = '|'.join(REGBIT[r] for r in ('r8', 'r9', 'r10', 'r11') if r in regs) or '0'
        rows.append('    { "%s", %s },' % (name, mask))
    body = 'static const struct { char sym[%d]; unsigned mask; } rtx_clob_tab[] = {\n' % (max(len(n) for n in table) + 1)
    return body + '\n'.join(rows) + '\n};\n#define RTX_CLOB_TAB_N ((int)(sizeof rtx_clob_tab / sizeof rtx_clob_tab[0]))\n'


def main(argv):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'SCRIP'))
    out, check = None, False
    i = 0
    while i < len(argv):
        if argv[i] == '--root': root = os.path.abspath(argv[i + 1]); i += 2; continue
        if argv[i] == '--out': out = argv[i + 1]; i += 2; continue
        if argv[i] == '--check': check = True; i += 1; continue
        print('REFUSED: unknown switch %s' % argv[i]); return 2
    if out is None: out = os.path.join(root, 'src', 'templates', 'x86', 'rtx_clobber_table.inc')
    table, why = derive(root)
    if table is None:
        print('REFUSED(2): %s' % why); return 2
    text = render(table)
    n_clob = sum(1 for v in table.values() if v)
    if check:
        have = open(out, encoding='utf-8').read() if os.path.exists(out) else ''
        if have == text:
            print('RTX-CLOBBER-TABLE FRESH entries=%d clobbering=%d file=%s' % (len(table), n_clob, out)); return 0
        hl, tl = have.split('\n'), text.split('\n')
        diffs = [(a, b) for a, b in zip(hl, tl) if a != b][:8]
        print('RTX-CLOBBER-TABLE STALE: the checked-in table disagrees with the objects (have %d lines, want %d)' % (len(hl), len(tl)))
        for a, b in diffs: print('   have: %s\n   want: %s' % (a, b))
        return 1
    open(out, 'w', encoding='utf-8').write(text)
    print('RTX-CLOBBER-TABLE entries=%d clobbering=%d wrote %s' % (len(table), n_clob, out))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
