#!/usr/bin/env python3
"""util_asm_identity.py --base <SCRIP dir> [--new <SCRIP dir>] [--jobs N] [--langs snobol4,icon,...] [--keep DIR] -- THE MOVE PROOF (ceo CEO-1988).

A landing that MOVES a calculation (the emitter's memory model into the planner, CEO-1988) changes no emitted byte. This compiles every entry
of the seven master suites (corpus/tests/<lang>/ALL.*, extracted by corpus_suite_harness's own readers, the one extraction authority), every
benchmark kernel (corpus/benchmarks/<lang>/) and every demo (corpus/demos/<lang>/) to mode-4 assembly with TWO scrip binaries -- the base tree's
and the new tree's -- and compares the bytes. Each compile runs in its program's own directory with SNO_LIB = that directory and corpus/include,
stdin /dev/null. A pair is IDENTICAL (same rc, same bytes), LINE-ONLY (same rc, same instruction bytes, only a <template file>:<line> comment reference moved; counted apart, never in different; coo 10-26), DIFFERENT (both compiled, bytes differ), REFUSED-BOTH (both refused the same way: the
program is outside today's compiler on both trees, so the pair proves nothing either way and is counted apart), or SPLIT (one compiled, one did
not). EXIT 0 every pair IDENTICAL or REFUSED-BOTH; 1 a DIFFERENT or SPLIT pair (the first 30 named, with the first differing line); 2 REFUSED.
Calibrate first: --base and --new the same tree reads 0 DIFFERENT, or the compiler is not deterministic and this instrument cannot measure.
"""
import argparse
import concurrent.futures
import hashlib
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
S4E = os.path.normpath(os.path.join(HERE, '..', '..'))
CORPUS = os.path.join(S4E, 'corpus')
EXTS = {'snobol4': ('.sno', '.spt', '.sbl'), 'icon': ('.icn',), 'prolog': ('.pl', '.pro'), 'pascal': ('.pas', '.p', '.pp'),
        'raku': ('.raku',), 'snocone': ('.sc',), 'rebus': ('.reb',), 'scriptix': ('.md', '.scrip')}
MASTER = {'snobol4': 'ALL.sno', 'icon': 'ALL.icn', 'prolog': 'ALL.pl', 'pascal': 'ALL.pas', 'raku': 'ALL.raku', 'snocone': 'ALL.sc', 'rebus': 'ALL.reb'}


def harness():
    spec = importlib.util.spec_from_file_location('csh', os.path.join(HERE, 'corpus_suite_harness.py'))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def master_entries(csh, lang, outdir):
    src = os.path.join(CORPUS, 'tests', lang, MASTER[lang])
    ref = os.path.join(CORPUS, 'tests', lang, 'ALL.ref')
    if not (os.path.isfile(src) and os.path.isfile(ref)):
        return []
    ext = os.path.splitext(src)[1]
    copen, cclose = '*', ''
    for lc in csh.LANG_CONFIGS.values():
        if lc.get('ext') == ext:
            copen, cclose = lc.get('comment_open', '*'), lc.get('comment_close', '')
            break
    try:
        entries = csh.read_block_suite(src, ref, csh.banner_re_for(copen, cclose), in_path=None, x_path=None)
    except Exception:
        entries = csh.read_suite(src, ref, in_path=None, x_path=None)
    d = os.path.join(outdir, 'master', lang)
    os.makedirs(d, exist_ok=True)
    out = []
    for e in entries:
        text = e.sno_lines[0] if e.kind == 'line' else '\n'.join(e.sno_lines)
        p = os.path.join(d, e.name + ext)
        with open(p, 'w', encoding='utf-8') as f:
            f.write(text + '\n')
        out.append(('master/%s/%s' % (lang, e.name), p))
    return out


def tree_programs(kind, lang):
    root = os.path.join(CORPUS, kind, lang)
    out = []
    for d, _, fs in os.walk(root):
        for f in sorted(fs):
            if f.endswith(EXTS.get(lang, ())) and not f.startswith('.'):
                p = os.path.join(d, f)
                out.append(('%s/%s' % (kind, os.path.relpath(p, os.path.join(CORPUS, kind))), p))
    return sorted(out)


def run_slot():
    # ONE POOL OF RUN SLOTS FOR THE WHOLE BOX (CEO-1894), the same flock pool corpus_suite_harness.py takes: three seats proving moves at once
    # ran 20 compile workers beside the box's 8 slots (load 15-25 on 16 cores, ceo 2026-10-26 12:10 CDT, Lon: "what's the health of the machine?").
    # A wait for a slot is taken BEFORE the compile's timeout starts, so it can never read as a hang.
    if os.environ.get('S4E_RUN_SLOT_HELD'):
        return None
    import fcntl
    try:
        import random, time
        n = max(1, int(os.environ.get('S4E_RUN_SLOTS', '8')))
        d = os.environ.get('S4E_RUN_SLOT_DIR') or '/tmp/s4e-run-slots'
        os.makedirs(d, exist_ok=True)
        while True:
            for i in range(n):
                f = open(os.path.join(d, 'slot%d' % i), 'a')
                try:
                    fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    return f
                except OSError:
                    f.close()
            time.sleep(0.25 + random.random() * 0.25)
    except OSError:
        return None


def compile_one(scrip, prog, outs):
    env = dict(os.environ)
    d = os.path.dirname(prog)
    env['SNO_LIB'] = d + ':' + os.path.join(CORPUS, 'include')
    env['SCRIP_DIAG'] = '0'
    env['S4E_RUN_SLOT_HELD'] = '1'
    slot = run_slot()
    try:
        r = subprocess.run([scrip, '--compile', f"--out={outs}", prog], cwd=d, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                           stderr=subprocess.PIPE, timeout=300)
        rc, err = r.returncode, r.stderr.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        rc, err = 124, 'timeout'
    finally:
        if slot:
            slot.close()
    data = open(outs, 'rb').read() if rc == 0 and os.path.exists(outs) else b''
    return rc, data, err


SRCREF = re.compile(rb'(\.(?:cpp|c|h|inc)):[0-9]+')


def line_only(a, b):
    """Two differing asm lines whose instruction text (before the first '#') is equal and whose comments differ only in a <source file>:<line> reference."""
    ca, _, ma = a.partition(b'#')
    cb, _, mb = b.partition(b'#')
    return ca == cb and bool(ma) and bool(mb) and SRCREF.sub(rb'\1:N', ma) == SRCREF.sub(rb'\1:N', mb)


def one(args):
    label, prog, base, new, tmp = args
    h = hashlib.sha1(label.encode()).hexdigest()[:16]
    rb, db, eb = compile_one(os.path.join(base, 'scrip'), prog, os.path.join(tmp, h + '.b.s'))
    rn, dn, en = compile_one(os.path.join(new, 'scrip'), prog, os.path.join(tmp, h + '.n.s'))
    for p in (h + '.b.s', h + '.n.s'):
        try:
            os.unlink(os.path.join(tmp, p))
        except OSError:
            pass
    if rb == 0 and rn == 0:
        if db == dn:
            return label, 'IDENTICAL', ''
        lb, ln = db.split(b'\n'), dn.split(b'\n')
        first = None
        for i in range(max(len(lb), len(ln))):
            a = lb[i] if i < len(lb) else b'<eof>'
            b = ln[i] if i < len(ln) else b'<eof>'
            if a != b and not line_only(a, b):
                return label, 'DIFFERENT', 'line %d: base %r | new %r' % (i + 1, a[:90], b[:90])
            if a != b and first is None:
                first = i + 1
        return label, 'LINE-ONLY', 'first at line %d' % first
    if rb != 0 and rn != 0:
        return label, 'REFUSED-BOTH', 'rc %d/%d' % (rb, rn)
    return label, 'SPLIT', 'base rc %d, new rc %d: %s' % (rb, rn, (eb if rb else en).strip().split('\n')[0][:120])


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', required=True)
    ap.add_argument('--new', default=os.path.join(S4E, 'SCRIP'))
    ap.add_argument('--jobs', type=int, default=6)
    ap.add_argument('--langs', default='snobol4,icon,prolog,pascal,raku,snocone,rebus,scriptix')
    a = ap.parse_args(argv[1:])
    for t in (a.base, a.new):
        if not os.access(os.path.join(t, 'scrip'), os.X_OK):
            print('REFUSED(2): no built scrip in %s' % t, file=sys.stderr)
            return 2
    csh = harness()
    work = tempfile.mkdtemp(prefix='asmid.')
    try:
        pop = []
        for lang in a.langs.split(','):
            if lang in MASTER:
                pop += master_entries(csh, lang, work)
            pop += tree_programs('benchmarks', lang) + tree_programs('demos', lang)
        tmp = os.path.join(work, 's')
        os.makedirs(tmp)
        res = {'IDENTICAL': 0, 'LINE-ONLY': 0, 'DIFFERENT': 0, 'REFUSED-BOTH': 0, 'SPLIT': 0}
        bad = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as ex:
            for label, v, why in ex.map(one, [(l, p, os.path.abspath(a.base), os.path.abspath(a.new), tmp) for l, p in pop]):
                res[v] += 1
                if v in ('DIFFERENT', 'SPLIT'):
                    bad.append((label, v, why))
        def head(t):
            try:
                return subprocess.run(['git', '-C', t, 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip()
            except Exception:
                return '?'
        print('ASM_IDENTITY population=%d identical=%d different=%d refused_both=%d split=%d line_only=%d base=%s new=%s langs=%s' % (
            len(pop), res['IDENTICAL'], res['DIFFERENT'], res['REFUSED-BOTH'], res['SPLIT'], res['LINE-ONLY'], head(a.base), head(a.new), a.langs))
        for label, v, why in bad[:30]:
            print('  %-10s %s -- %s' % (v, label, why))
        return 1 if bad else 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
