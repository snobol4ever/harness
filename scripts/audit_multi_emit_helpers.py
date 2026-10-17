#!/usr/bin/env python3
"""FIX-8b census detector — multi-emit helper sub-emitters in BB templates.
PRINCIPLE (Lon, 2026-06-08, 28th run): templates OUTPUT assembly; they do not call
others to do it. A helper may build CHARACTERS ON A LINE (a std::string fragment
spliced into one x86() operand) but must NOT write LINES OF CODE (compose >=2 emission
calls). This detector finds the INLINE+DELETE worklist for FIX-8b.
RULE: a function is an INLINE+DELETE candidate iff it ITSELF calls the x86/x86_* emission
family >=2 times AND it is not a dispatch entry (a per-box bb_*_str function or an
extern "C" box wrapper). Emission calls are counted on a comment/string-stripped skeleton
so an x86( substring inside a literal or comment never inflates the count (verdict #7).
Usage: python3 ../harness/scripts/audit_multi_emit_helpers.py [--csv] [DIR]
Default DIR: src/templates relative to repo root inferred from this file.
"""
import os, re, sys, glob
EMIT_RE = re.compile(r'\bx86[a-z0-9_]*\(')
NAME_BEFORE_BRACE = re.compile(r'([A-Za-z_]\w*)\s*\(')
def blank_noncode(src):
    out = []; i = 0; n = len(src); state = 'code'
    while i < n:
        c = src[i]; nxt = src[i+1] if i + 1 < n else ''
        if state == 'code':
            if c == '/' and nxt == '/': state = 'line'; out.append('  '); i += 2; continue
            if c == '/' and nxt == '*': state = 'block'; out.append('  '); i += 2; continue
            if c == '"': state = 'str'; out.append('"'); i += 1; continue
            if c == "'": state = 'chr'; out.append("'"); i += 1; continue
            out.append(c); i += 1; continue
        if state == 'line':
            if c == '\n': state = 'code'; out.append('\n'); i += 1; continue
            out.append(' '); i += 1; continue
        if state == 'block':
            if c == '*' and nxt == '/': state = 'code'; out.append('  '); i += 2; continue
            out.append('\n' if c == '\n' else ' '); i += 1; continue
        if state == 'str':
            if c == '\\': out.append('  ' if nxt != '\n' else ' \n'); i += 2; continue
            if c == '"': state = 'code'; out.append('"'); i += 1; continue
            out.append('\n' if c == '\n' else ' '); i += 1; continue
        if state == 'chr':
            if c == '\\': out.append('  '); i += 2; continue
            if c == "'": state = 'code'; out.append("'"); i += 1; continue
            out.append(' '); i += 1; continue
    return ''.join(out)
def find_functions(skel):
    funcs = []; depth = 0; i = 0; n = len(skel); seg = 0; name = None; start = None; sig_extern = False
    while i < n:
        c = skel[i]
        if c == '{':
            if depth == 0:
                sig = skel[seg:i]; m = list(NAME_BEFORE_BRACE.finditer(sig))
                name = m[-1].group(1) if m else None; start = i; sig_extern = ('extern' in sig)
            depth += 1; i += 1; continue
        if c == '}':
            depth -= 1
            if depth == 0:
                if name: funcs.append({'name': name, 'start': start, 'end': i, 'extern': sig_extern})
                name = None; seg = i + 1
            i += 1; continue
        if c == ';' and depth == 0: seg = i + 1
        i += 1
    return funcs
def line_of(skel, idx): return skel[:idx].count('\n') + 1
def analyze(path):
    src = open(path, encoding='utf-8').read(); skel = blank_noncode(src)
    res = []
    for f in find_functions(skel):
        body = skel[f['start']:f['end']]; cnt = len(EMIT_RE.findall(body))
        is_entry = f['name'].endswith('_str') or f['extern']
        res.append({'name': f['name'], 'line': line_of(skel, f['start']), 'emits': cnt,
                    'entry': is_entry, 'candidate': (cnt >= 2 and not is_entry)})
    return res, skel
def call_sites(name, files_skel):
    pat = re.compile(r'\b' + re.escape(name) + r'\s*\('); hits = []
    for p, skel in files_skel.items():
        for ln, line in enumerate(skel.splitlines(), 1):
            for _m in pat.finditer(line): hits.append((os.path.basename(p), ln))
    return hits
def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]; csv = '--csv' in sys.argv
    here = os.path.dirname(os.path.abspath(__file__)); root = os.path.join(os.path.dirname(os.path.dirname(here)), "SCRIP")
    # PATH CORRECTED s169 (seat1, gates-dead-paths): the default was src/emitter/BB_templates, dead since
    # the src reorg, so the census globbed an empty dir and reported "0 helpers across 0 files" -- a false
    # zero that read exactly like a clean sweep.
    d = args[0] if args else os.path.join(root, 'src', 'templates')
    files = sorted(glob.glob(os.path.join(d, '*.cpp')))
    all_funcs = {}; files_skel = {}; cands = []
    for p in files:
        res, skel = analyze(p); all_funcs[p] = res; files_skel[p] = skel
        for r in res:
            if r['candidate']: cands.append({'file': os.path.basename(p), 'path': p, **r})
    cands.sort(key=lambda x: (-x['emits'], x['file'], x['name']))
    entry_keep = sum(1 for p in files for r in all_funcs[p] if r['entry'])
    frag_keep = sum(1 for p in files for r in all_funcs[p] if not r['entry'] and r['emits'] < 2)
    cand_files = sorted({c['file'] for c in cands})
    if csv:
        print('emits,file,helper,line,n_call_sites')
        for c in cands:
            cs = [h for h in call_sites(c['name'], files_skel) if h[0] == c['file'] or True]
            print(f"{c['emits']},{c['file']},{c['name']},{c['line']},{len(cs)}")
        return
    print('=' * 92)
    print('FIX-8b MULTI-EMIT HELPER CENSUS  (src/templates/*.cpp)')
    print('  INLINE+DELETE candidate = helper with >=2 x86/x86_* emission calls, not a dispatch entry')
    print('=' * 92)
    print(f"{'EMITS':>6}  {'FILE':<34}{'HELPER':<32}{'@LINE':>6}  CALL-SITES")
    print('-' * 92)
    for c in cands:
        cs = call_sites(c['name'], files_skel)
        loc = ' '.join(f"{a}:{b}" for a, b in cs[:6]) + (' …' if len(cs) > 6 else '')
        print(f"{c['emits']:>6}  {c['file']:<34}{c['name']:<32}{c['line']:>6}  {loc}")
    print('-' * 92)
    print(f"  CANDIDATES (INLINE+DELETE): {len(cands)} helpers across {len(cand_files)} files")
    print(f"  KEEP (dispatch entries bb_*_str / extern \"C\"): {entry_keep}")
    print(f"  KEEP (zero/one-emit fragment & value builders): {frag_keep}")
    print('  NOTE: bb_call-family helpers (marshal_*/arith_opnd_*/pas_sl_setup) are FIX-3-EXCLUDED —')
    print('        8b sweeps the call family only AFTER FIX-3 splits the call kinds.')
    print('=' * 92)
if __name__ == '__main__':
    main()
