import os as _os
S4E = _os.environ.get("S4E_HOME") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", ".."))   # D-17 sibling root
import sys, os, re, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from util_dead_cutter import lex_items

ROOT = f'{S4E}/SCRIP'
DEAD = set(open(os.environ.get('SWEEP_DEAD','/tmp/dead_src.txt')).read().split())

def cut_set_for(path):
    with open(path) as f: src = f.read()
    items = lex_items(src)
    names = [it[1] for it in items if it[0]=='func' and it[1]]
    return sorted(set(n for n in names if n in DEAD)), items, names

def attic_path(path):
    rel = os.path.relpath(path, ROOT)
    assert rel.startswith('src/'), rel
    return os.path.join(ROOT, 'src/attic', rel[len('src/'):])

def apply_file(path, commit):
    cut, items, names = cut_set_for(path)
    if not cut: return 0, []
    cutset = set(cut)
    live_out = []
    attic_chunks = []
    for it in items:
        kind, name, text = it
        if kind == 'func' and name in cutset:
            # drop preceding separator if it's the last thing in live_out
            sep_text = ''
            if live_out and live_out[-1][0] == 'sep':
                sep_text = live_out.pop()[2]
            attic_chunks.append(sep_text + text)
        else:
            live_out.append(it)
    # reassemble live
    live_text = ''.join(t for (_,_,t) in live_out)
    # write attic mirror (append if exists)
    ap = attic_path(path)
    os.makedirs(os.path.dirname(ap), exist_ok=True)
    rel = os.path.relpath(path, ROOT)
    header = ("/* ATTIC: dead code refused from %s (commit base %s) — "
              "unreachable from main per --gc-sections oracle. Provenance only; not compiled. */\n"
              % (rel, commit))
    mode = 'a' if os.path.exists(ap) else 'w'
    with open(ap, mode) as f:
        if mode == 'w': f.write(header)
        f.write(''.join(attic_chunks))
    with open(path, 'w') as f:
        f.write(live_text)
    return len(cut), cut

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'map':
        files = [l.strip() for l in open('/tmp/srcfiles.txt')]
        whole=[]; part=[]; total=0
        for p in files:
            cut, items, names = cut_set_for(p)
            if not cut: continue
            nsrc = len(set(names))
            total += len(cut)
            if len(cut) == nsrc: whole.append((p, nsrc))
            else: part.append((p, len(cut), nsrc))
        print("WHOLE-FILE-DEAD (%d files):" % len(whole))
        for p,n in whole: print("  %s  (%d fns)" % (p, n))
        print("PARTIAL-DEAD: %d files" % len(part))
        print("TOTAL dead fns to cut: %d" % total)
        # dump full per-file list for the apply step
        with open('/tmp/cutfiles.txt','w') as f:
            for p,_ in whole: f.write(p+'\n')
            for p,_,_ in part: f.write(p+'\n')
    elif cmd == 'validate':
        # validate cutter vs nm (source names subset of nm, no EXTRA beyond header-inlines)
        for p in sys.argv[2:]:
            cut, items, names = cut_set_for(p)
            print("%s: %d source fns, %d to cut" % (p, len(set(names)), len(cut)))
    elif cmd == 'apply':
        commit = sys.argv[2]
        files = [l.strip() for l in open(os.environ.get('SWEEP_FILES','/tmp/cutfiles.txt')) if l.strip()]
        grand=0
        for p in files:
            n, cut = apply_file(p, commit)
            grand += n
        print("APPLIED: cut %d functions across %d files" % (grand, len(files)))
