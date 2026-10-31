#!/usr/bin/env python3
"""lib_rtx_clobber_derive.py -- THE CLOBBER SET OF EVERY REGISTERED ASM-RUNTIME ENTRY, DERIVED FROM THE ASSEMBLED OBJECTS
(DESIGN-PLAN zeta-layout step 5, stage 5c; CEO-2019).  This is the derivation that util_gen_rtx_clobber_table.py carried (cto
2026-09-30, row rtx-leaves-carry-no-register-veneer-an-asm-runtime-call-is-not-a-c-function; Lon 2026-09-30, in-chat to the ceo,
verbatim: "Ensure the veneer to save and restore registers has been removed from ALL x86 asm runtime calls since they are not C
functions and do not require the extra."; ARCH-RT-CALL-PROTOCOL.md section 15 THE LEAF CONTRACT), moved here when that generator
and rtx_clobber_table.inc were deleted: the runtime entry table (rt_entries.tsv, rt_entry_table.inc) is now the one source the
emitter reads, and util_gen_rt_entry_table.py --sync-asm / --check-asm call derive() to keep its asm rows equal to the objects.

derive(root) assembles every src/runtime/rtx/*.s with the Makefile's own RT_INCS, reads the registry (the rtx_entry_names section
RTX_FUNC and RTX_ENTRY append to, read out of the objects with objcopy -- never typed), and runs util_rtx_abi_walk.py --clobber-table,
which abstract-interprets every entry along every path.  It returns ({entry: tuple of the RTCC registers among r8 r9 r10 r11 the
entry can hand back changed}, None), or (None, why) when it cannot (a body the walker cannot read REFUSES the whole derivation).
"""
import os, re, subprocess, sys, tempfile, shutil


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
