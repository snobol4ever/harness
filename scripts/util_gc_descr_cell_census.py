#!/usr/bin/env python3
import os, re, subprocess, sys
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
CORPUS = os.path.join(os.path.dirname(ROOT), 'corpus', 'benchmarks')
EXTS = ('.sno', '.sc', '.icn', '.pl', '.reb', '.raku', '.pas')
LINE = re.compile(r'^;\s+\+(\d+)\s+(\d+)\s+(DESCR|RAW|PTR_GC|PTR_CODE|PTR_FRAME)\s')
def census(path):
    p = subprocess.run([os.path.join(ROOT, 'scrip'), '--dump-zeta', path], capture_output=True, timeout=120); out = p.stdout.decode("utf-8", "replace")
    regs = []
    for ln in out.splitlines():
        m = LINE.match(ln)
        if m: regs.append((int(m.group(1)), int(m.group(2)), m.group(3)))
    descr_b = sum(s for o, s, k in regs if k == 'DESCR')
    raw = sorted(set((o, s) for o, s, k in regs if k != 'DESCR'))
    raw_b = sum(s for o, s in raw)
    offs = set(o for o, s in raw)
    cells = 0; i = 0
    while i < len(raw):
        o, s = raw[i]
        if s <= 8 and i + 1 < len(raw) and raw[i + 1][0] == o + 8 and raw[i + 1][1] <= 8: cells += 1; i += 2
        elif s <= 16: cells += 1; i += 1
        else: cells += (s + 15) // 16; i += 1
    return p.returncode, descr_b, raw_b, cells * 16
def main():
    tot = [0, 0, 0]; rows = []
    for lang in sorted(os.listdir(CORPUS)):
        d = os.path.join(CORPUS, lang)
        if not os.path.isdir(d): continue
        for f in sorted(os.listdir(d)):
            if not f.endswith(EXTS): continue
            rc, db, rb, cb = census(os.path.join(d, f))
            rows.append((lang, f, rc, db, rb, cb)); tot[0] += db; tot[1] += rb; tot[2] += cb
    print('lang program rc descr_bytes raw_bytes raw_as_cells growth_pct')
    for lang, f, rc, db, rb, cb in rows:
        tb = db + rb; nb = db + cb
        print(f'{lang} {f} {rc} {db} {rb} {cb} {((nb - tb) * 100.0 / tb) if tb else 0.0:.1f}')
    tb = tot[0] + tot[1]; nb = tot[0] + tot[2]
    print(f'TOTAL programs={len(rows)} descr_bytes={tot[0]} raw_bytes={tot[1]} raw_as_cells={tot[2]} frame_bytes_before={tb} after={nb} growth_pct={((nb - tb) * 100.0 / tb) if tb else 0.0:.2f}')
if __name__ == '__main__': main()
