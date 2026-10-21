#!/usr/bin/env python3
"""util_frame_slot_census.py -- what each graph's activation frame reserves at entry (scrip --dump-zeta), per language, each distinct graph once.
Usage: util_frame_slot_census.py LIST_TSV   (lang <TAB> source path per line)."""
import collections, hashlib, os, re, subprocess, sys

SC = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'SCRIP', 'scrip')
GR = re.compile(r"^; graph (\d+) '(.*)' \S+ slots=(\d+) region_end=(\d+)")
FLD = re.compile(r'^;\s+\+(\d+)\s+(\d+)\s+(\S+)\s+(.*?)\s{2,}(\S+)\s*$|^;\s+\+(\d+)\s+(\d+)\s+(\S+)\s+(.*)$')

def classify(desc):
    d = desc.lower()
    for k in ('return value', 'param', 'call.argv', 'local', 'result (pooled', 'result (slot-elide', 'result'):
        if d.startswith(k):
            return {'result (pooled': 'result-pooled', 'result (slot-elide': 'result-elide-scratch'}.get(k, k)
    return 'word:' + re.split(r'[ (]', d)[0]

def main():
    rows = [l.rstrip('\n').split('\t') for l in open(sys.argv[1]) if l.strip()]
    tot = {}
    seen = set()
    for lang, src in rows:
        t = tot.setdefault(lang, collections.Counter())
        args = [SC, '--dump-zeta'] + (['--target=x86'] if lang == 'prolog' else []) + [os.path.basename(src)]
        try:
            r = subprocess.run(args, cwd=os.path.dirname(src), stdin=subprocess.DEVNULL, capture_output=True, timeout=300)
        except Exception:
            t['unmeasured'] += 1
            continue
        txt = (r.stdout + r.stderr).decode('utf-8', 'replace').splitlines()
        cur, fields = None, []
        def flush():
            if cur is None:
                return
            key = hashlib.sha1(('%s|%s|%s' % (lang, cur[1], '|'.join(fields))).encode()).hexdigest()
            if key in seen:
                return
            seen.add(key)
            t['graphs'] += 1
            t['region_bytes'] += cur[3]
            t['slots'] += cur[2]
            for f in fields:
                t['f:' + f] += 1
        for ln in txt:
            m = GR.match(ln)
            if m:
                flush()
                cur, fields = (int(m.group(1)), m.group(2), int(m.group(3)), int(m.group(4))), []
                continue
            if cur is None or not ln.startswith(';     +'):
                continue
            parts = re.split(r'\s{2,}', ln[1:].strip())
            if len(parts) >= 4:
                size = parts[0].split()
                desc = parts[3] if len(parts) > 3 else ''
                fields.append(classify(desc))
        flush()
    for lang in sorted(tot):
        t = tot[lang]
        fs = sorted(((k[2:], v) for k, v in t.items() if k.startswith('f:')), key=lambda kv: -kv[1])
        print('FRAME %s graphs=%d slots=%d region_bytes=%d unmeasured=%d' % (lang, t['graphs'], t['slots'], t['region_bytes'], t['unmeasured']))
        print('FRAME_FIELDS %s %s' % (lang, ' '.join('%s=%d' % kv for kv in fs[:14])))

if __name__ == '__main__':
    main()
