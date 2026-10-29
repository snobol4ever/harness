import argparse, collections, os, re, subprocess, sys, tempfile
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
DERIV = re.compile(r'^\s*(add|sub)\s+(r[a-z0-9]+),\s*(r13|r14|r15)\b')
CALL  = re.compile(r'^\s*call\s+(\S+)')
LEA   = re.compile(r'^\s*lea\s+[a-z0-9]+,\s*\[([^]]*)\]')
ALLOCFREE = ('memcmp', 'memcpy', 'memset', 'strlen', 'memchr', 'strcmp', 'strncmp')
def classify_lea(b):
    if b.startswith('rip'): return 'rip+label (static, never moves)'
    if b.startswith('rbp') or b.startswith('rsp'): return 'frame (rbp/rsp)'
    return 'other base=' + b.split()[0]
def census(asm_files):
    lea = collections.Counter(); live = collections.Counter(); sites = []
    ninstr = 0
    for f in asm_files:
        lines = [l.rstrip() for l in open(f, encoding='utf-8', errors='surrogateescape')]
        for i, l in enumerate(lines):
            if l[:1] in (' ', '\t') and l.strip(): ninstr += 1
            m = LEA.match(l)
            if m: lea[classify_lea(m.group(1))] += 1
            m = DERIV.match(l)
            if not m: continue
            live_set = {m.group(2)}; verdict = None; target = ''
            for j in range(i + 1, min(i + 40, len(lines))):
                t = lines[j]
                c = CALL.match(t)
                if c:
                    target = c.group(1)
                    base = target.split('@')[0].lstrip('*')
                    verdict = 'ARGUMENT to a non-allocating call' if base in ALLOCFREE else 'LIVE ACROSS A CALL'
                    break
                alt = '|'.join(sorted(live_set))
                if re.search(r'\[\s*(' + alt + r')\b', t): verdict = 'consumed (dereferenced)'; break
                cp = re.match(r'^\s*mov\s+(r[a-z0-9]+),\s*(' + alt + r')\b', t)
                if cp: live_set.add(cp.group(1)); continue
                if re.search(r'^\s*mov\s+(qword ptr\s*)?\[[^]]*\],\s*(' + alt + r')\b', t): verdict = 'consumed (stored to memory)'; break
                if re.search(r'^\s*(cmp|test)\s+(' + alt + r')\b', t): verdict = 'consumed (tested)'; break
                kill = re.match(r'^\s*(mov|lea|xor)\s+(r[a-z0-9]+),', t)
                if kill and kill.group(2) in live_set:
                    live_set.discard(kill.group(2))
                    if not live_set: verdict = 'dead (overwritten)'; break
            verdict = verdict or 'UNRESOLVED in 40 instructions'
            live[verdict] += 1
            if verdict.startswith(('LIVE', 'UNRESOLVED')): sites.append((f, i + 1, l.strip(), target))
    return ninstr, lea, live, sites
def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--files', nargs='*', default=[]); ap.add_argument('--asm', nargs='*', default=[])
    a = ap.parse_args()
    asm = list(a.asm); tmp = None
    if a.files:
        tmp = tempfile.mkdtemp(prefix="gc_derived."); __import__("atexit").register(__import__("shutil").rmtree, tmp, True)
        for src in a.files:
            o = os.path.join(tmp, os.path.basename(src) + '.s')
            if subprocess.call([os.path.join(ROOT, 'scrip'), '--compile', f"--out={o}", src],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                               timeout=60) == 0 and os.path.exists(o): asm.append(o)
    if not asm:
        print('CENSUS derived-values REFUSED rc=2: no emitted asm to read -- a census over an empty population is not a clean reading'); return 2
    ninstr, lea, live, sites = census(asm)
    if ninstr == 0:
        print('CENSUS derived-values REFUSED rc=2: %d file(s) held zero instructions' % len(asm)); return 2
    across = live['LIVE ACROSS A CALL'] + live['UNRESOLVED in 40 instructions']
    print('CENSUS derived-values programs=%d instructions=%d LIVE-ACROSS-AN-ALLOCATING-CALL=%d want=0' % (len(asm), ninstr, across))
    print('  WHY THIS CENSUS EXISTS: Diwan, Moss and Hudson (PLDI 1992, /home/resources/gc-papers/) emit a DERIVATIONS TABLE beside their stack and register tables,')
    print('  because an optimizer manufactures values derived by pointer arithmetic -- an untidy pointer into, or past, an object a moving collector will relocate.')
    print('  SCRIP has no derivations table and no derived-value concept. This asks whether it needs one, and the answer is a property of the three zetas:')
    print('  r13 sigma is the subject BASE, r14 delta is a CURSOR OFFSET and r15 Delta is a LENGTH, so emitted code adds an offset to a base at the point of use.')
    for k, v in lea.most_common(): print('  LEA %-34s %d' % (k, v))
    for k, v in live.most_common(): print('  DERIVED %-38s %d' % (k, v))
    for f, n, l, t in sites[:25]: print('  SITE %s:%d %s -> %s' % (os.path.basename(f), n, l, t or '?'))
    return 1 if across else 0
if __name__ == '__main__': sys.exit(main())
