#!/usr/bin/env python3
# util_unit_spans.py SRC [--root SCRIP] -- THE SPAN READER OF DESIGN-PLAN cache-tree (the cto, 2026-11-12, CTO-636; skill scrip-build reference section 4).
# Every top-level function and variable of one unit's OWN text, read from clang's AST with the unit's build flags (its line in make -B -n build-all),
# so none of the six shapes that defeat a brace-counting span parser (the extern-C wrapper, 200-column one-liners ending in ';', wrapped signatures,
# K&R braces, literals, macro bodies) can misplace a boundary. One line per declaration:
#   kind  name  S|-(static)  first_line  last_line  B|-(has a body)  refs (the same-file top-level names its body references, comma separated)
# The split tool (step 1) reads it to cut a unit by a manifest and to name the statics a cut must export. rc 2 when clang is absent or reads nothing.
import os, re, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
args = sys.argv[1:]
root = None
if '--root' in args:
    i = args.index('--root'); root = args[i + 1]; del args[i:i + 2]
if len(args) != 1 or not shutil.which('clang'):
    sys.exit('REFUSE(2): usage util_unit_spans.py SRC [--root SCRIP]; clang must be on PATH')
from util_cache_blast import compile_lines
root = os.path.abspath(root or (os.path.join(os.environ['S4E_HOME'], 'SCRIP') if os.environ.get('S4E_HOME') else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'SCRIP')))
src = os.path.abspath(args[0])
flags = next((f for cc, f, s in compile_lines(root) if os.path.abspath(os.path.join(root, s)) == src), None)
if flags is None:
    sys.exit('REFUSE(2): %s has no compile line in %s' % (src, root))
p = subprocess.Popen(['clang', '-fsyntax-only', '-w', '-Wno-implicit-function-declaration', '-Wno-int-conversion', '-Wno-incompatible-pointer-types'] + flags + ['-Xclang', '-ast-dump', '-fno-color-diagnostics', src],
                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, errors='replace')
LOC = re.compile(r'<(?:([^<>:]+\.(?:c|cpp|h|inc|hpp)):(\d+):\d+|line:(\d+):\d+|col:\d+)(?:, (?:([^<>:]+\.(?:c|cpp|h|inc|hpp)):(\d+):\d+|line:(\d+):\d+|col:\d+))?>')
TOP1 = re.compile(r'^[|`]-(\w+)\b')
TOP2 = re.compile(r'^[| ] [|`]-(FunctionDecl|VarDecl|RecordDecl|TypedefDecl|EnumDecl|CXXRecordDecl|FunctionTemplateDecl)\b')
in_linkage = False
REF = re.compile(r"DeclRefExpr .* (?:Function|Var) 0x[0-9a-f]+ '([A-Za-z_]\w*)'")
cur_file = None
decls = []
d = None
for ln in p.stdout:
    m = LOC.search(ln)
    if m:
        if m.group(1):
            cur_file = m.group(1)
        b = int(m.group(2) or m.group(3) or 0) if (m.group(2) or m.group(3)) else None
        e_file = m.group(4)
        e = int(m.group(5) or m.group(6) or 0) if (m.group(5) or m.group(6)) else None
    t1 = TOP1.match(ln)
    if t1:
        in_linkage = t1.group(1) == 'LinkageSpecDecl'
    t = t1 if (t1 and t1.group(1) != 'LinkageSpecDecl') else (TOP2.match(ln) if in_linkage else None)
    if t1 and t1.group(1) == 'LinkageSpecDecl':
        if m and m.group(4):
            cur_file = m.group(4)
        d = None
        continue
    if t:
        in_main = cur_file is not None and cur_file.endswith(src.split('/')[-1]) and m is not None
        if m and m.group(4):
            cur_file = m.group(4)
        d = None
        if in_main and t.group(1) in ('FunctionDecl', 'VarDecl'):
            nm = re.search(r"(?:line:\d+:\d+|col:\d+|\.\w+:\d+:\d+)> (?:col:\d+ |line:\d+:\d+ )?(?:used |referenced |implicit |invalid )*([A-Za-z_]\w*) '", ln)
            if nm and b:
                d = {'k': t.group(1), 'n': nm.group(1), 's': ' static' in ln, 'b': b, 'e': e or b, 'body': False, 'refs': set()}
                decls.append(d)
        continue
    if m and m.group(4):
        cur_file = m.group(4)
    if d is not None:
        if 'CompoundStmt' in ln:
            d['body'] = True
        r = REF.search(ln)
        if r:
            d['refs'].add(r.group(1))
if not decls:
    sys.exit('REFUSE(2): clang read no top-level declaration of %s' % src)
names = {x['n'] for x in decls}
for x in decls:
    print(f"{x['k']}\t{x['n']}\t{'S' if x['s'] else '-'}\t{x['b']}\t{x['e']}\t{'B' if x['body'] else '-'}\t{','.join(sorted(x['refs'] & names - {x['n']}))}")
