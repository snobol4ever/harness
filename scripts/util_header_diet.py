#!/usr/bin/env python3
# util_header_diet.py -- THE HEADER DIET OF DESIGN-PLAN cache-tree (the cto, 2026-11-12, CTO-636; skill scrip-build reference section 4, C5 and R2).
# A header keeps only the include lines its own text needs, so a unit that reaches it no longer reaches what it carried for nobody.
#   util_header_diet.py plan HEADER...   prints, per header, the include lines it keeps and the ones it drops (nothing written)
#   util_header_diet.py apply HEADER...  rewrites each header without its dropped lines; prints "DROP header line" per dropped line, so a unit that
#                                        relied on one can be given it back (repair)
#   util_header_diet.py repair LOG       reads a make log and a DROP list (stdin), and gives every unit that failed to compile the dropped lines of
#                                        the headers it includes, after its own include of that header
# What a header needs is read by libclang from a unit that includes the header alone, with the build's flags: every cursor located in the header
# whose referenced declaration (or whose first declaration, for a function or variable the header defines) lives in another header, every
# identifier of the header's own #define bodies that is a macro another header defines. An include line is kept when it reaches (gcc -M) a file
# the header needs; a line inside an #if region, a spliced .inc and a C++ standard header are always kept. The proof of an applied diet is the
# build, no new implicit declaration, and util_functions_identical.py over every object that changed.
import collections, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP'))
SRC = os.path.join(ROOT, 'src')


def include_lines(text):
    out, depth, guard_seen = [], 0, False
    for i, t in enumerate(text.split('\n')):
        st = t.lstrip()
        if re.match(r'#\s*if', st):
            depth += 1
            continue
        if re.match(r'#\s*endif', st):
            depth -= 1
            continue
        if depth == 1 and re.match(r'#\s*include\b', st) and not re.search(r'\.inc"', st) and not re.match(r'#\s*include\s*<', st):
            out.append(i)
    return out


def needs(header, cplus):
    import clang.cindex as ci
    rd = subprocess.run(['clang', '-print-resource-dir'], capture_output=True, text=True).stdout.strip()
    with tempfile.NamedTemporaryFile('w', suffix='.cpp' if cplus else '.c', delete=False) as f:
        f.write('#include "%s"\n' % os.path.relpath(header, SRC))
        tu_path = f.name
    args = ['-I' + SRC, '-w', '-Wno-implicit-function-declaration', '-isystem', os.path.join(rd, 'include')] + (['-x', 'c++', '-std=c++17'] if cplus else [])
    tu = ci.Index.create().parse(tu_path, args=args, options=ci.TranslationUnit.PARSE_DETAILED_PROCESSING_RECORD)
    os.unlink(tu_path)
    if any(d.severity >= 3 for d in tu.diagnostics):
        return None
    ha = os.path.abspath(header)
    need, macro_file = set(), {}
    DECL = (ci.CursorKind.MACRO_DEFINITION, ci.CursorKind.FUNCTION_DECL, ci.CursorKind.VAR_DECL, ci.CursorKind.TYPEDEF_DECL, ci.CursorKind.STRUCT_DECL,
            ci.CursorKind.UNION_DECL, ci.CursorKind.ENUM_DECL, ci.CursorKind.ENUM_CONSTANT_DECL, ci.CursorKind.CLASS_DECL, ci.CursorKind.FUNCTION_TEMPLATE)
    for c in tu.cursor.walk_preorder():
        f = c.location.file
        if not f:
            continue
        fa = os.path.abspath(f.name)
        if c.kind in DECL and c.spelling:
            macro_file.setdefault(c.spelling, fa)
        if fa != ha:
            continue
        r = c.referenced
        if r is not None and r.location.file and os.path.abspath(r.location.file.name) != ha:
            need.add(os.path.abspath(r.location.file.name))
        if c.kind in (ci.CursorKind.FUNCTION_DECL, ci.CursorKind.VAR_DECL):
            k = c.canonical
            if k is not None and k.location.file and os.path.abspath(k.location.file.name) != ha:
                need.add(os.path.abspath(k.location.file.name))
    for t in open(header, encoding='utf-8', errors='surrogateescape').read().split('\n'):
        m = re.match(r'\s*#\s*define\s+\w+(?:\([^)]*\))?\s*(.*)', t)
        if m:
            for w in re.findall(r'[A-Za-z_]\w*', m.group(1)):
                if w in macro_file and macro_file[w] != ha:
                    need.add(macro_file[w])
    return need


def reach(line, cplus, hdir):
    r = subprocess.run([('g++' if cplus else 'gcc'), '-M', '-MG'] + (['-x', 'c++', '-std=c++17'] if cplus else ['-x', 'c']) + ['-iquote', hdir, '-I' + SRC, '-'],
                       input=line + '\n', capture_output=True, text=True)
    deps = r.stdout.replace('\\\n', ' ').split(':', 1)[-1].split()
    return {os.path.abspath(x if os.path.isabs(x) else os.path.join(ROOT, x)) for x in deps if x != '-'}


def plan_one(header):
    text = open(header, encoding='utf-8', errors='surrogateescape').read()
    L = text.split('\n')
    cplus = bool(re.search(r'\bstd::|\btemplate\s*<|\bnamespace\b|extern "C\+\+"', text))
    need = needs(header, cplus)
    if need is None and not cplus:
        cplus = True
        need = needs(header, True)
    if need is None:
        return None
    rd = subprocess.run(['clang', '-print-resource-dir'], capture_output=True, text=True).stdout.strip()
    rdi = os.path.abspath(os.path.join(rd, 'include'))
    lines = include_lines(text)
    keep = set()
    reaches = {i: reach(L[i], cplus, os.path.dirname(header)) for i in lines}
    for F in need:
        for i in lines:
            if F in reaches[i] or (F.startswith(rdi + os.sep) and any(os.path.basename(x) == os.path.basename(F) for x in reaches[i])):
                keep.add(i); break
    drop = [i for i in lines if i not in keep]
    return L, keep, drop


def main(argv):
    if len(argv) < 2:
        print(__doc__ or 'usage: util_header_diet.py plan|apply HEADER... | repair LOG'); return 2
    verb = argv[0]
    if verb in ('plan', 'apply'):
        for h in argv[1:]:
            h = os.path.abspath(h)
            r = plan_one(h)
            if r is None:
                print('SKIP %s (does not parse alone)' % os.path.relpath(h, SRC)); continue
            L, keep, drop = r
            for i in drop:
                print('DROP %s\t%s' % (os.path.relpath(h, SRC), L[i].strip()))
            if verb == 'apply' and drop:
                open(h, 'w', encoding='utf-8', errors='surrogateescape').write('\n'.join(t for i, t in enumerate(L) if i not in set(drop)))
        return 0
    if verb == 'repair':
        drops = collections.defaultdict(list)
        for ln in sys.stdin:
            if ln.startswith('DROP '):
                h, inc = ln[5:].rstrip('\n').split('\t', 1)
                drops[h].append(inc)
        bad = sorted(set(re.findall(r'^(?:\S*/SCRIP/)?(src/[^:\s]+\.(?:c|cpp|h|inc)):\d+:\d+: (?:fatal )?error', open(argv[1], errors='replace').read(), re.M)))
        fixed = 0
        for u in bad:
            p = os.path.join(ROOT, u)
            T = open(p, encoding='utf-8', errors='surrogateescape').read().split('\n')
            have = set(t.strip() for t in T)
            add_at = next((i for i, t in enumerate(T) if re.match(r'\s*#\s*include\b', t)), -1) + 1
            ks = [i for h in drops for i, t in enumerate(T) if re.match(r'\s*#\s*include\s*"(?:[^"]*/)?%s"' % re.escape(os.path.basename(h)), t)]
            if ks:
                add_at = min(ks) + 1
            r = subprocess.run(['gcc', '-MM', '-MG', '-I' + SRC] + (['-x', 'c++', '-std=c++17'] if u.endswith(('.cpp', '.cc')) else []) + [p], capture_output=True, text=True)
            reached = {os.path.relpath(os.path.abspath(x if os.path.isabs(x) else os.path.join(ROOT, x)), SRC) for x in r.stdout.replace('\\\n', ' ').split(':', 1)[-1].split()}
            add = []
            for h, incs in drops.items():
                if h not in reached:
                    continue
                for inc in incs:
                    m = re.match(r'#\s*include\s*"([^"]+)"', inc)
                    if m:
                        q = os.path.normpath(os.path.join(SRC, os.path.dirname(h), m.group(1)))
                        inc = '#include "%s"' % (os.path.relpath(q, SRC) if os.path.exists(q) else m.group(1))
                    if inc not in have and inc not in add:
                        add.append(inc)
            if add:
                T[add_at:add_at] = add
                open(p, 'w', encoding='utf-8', errors='surrogateescape').write('\n'.join(T))
                fixed += 1
                print('REPAIR %s +%d' % (u, len(add)))
        print('REPAIRED %d of %d failing files' % (fixed, len(bad)))
        return 0
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
