#!/usr/bin/env python3
# lib_scrip_dash_o.py <scan|apply> PATH... -- finds (and rewrites) every place a script hands the assembly output to scrip as -o FILE.
#
# SPITBOL's -o=file names the compilation LISTING, so SCRIP's --compile assembly output is --out=FILE (CEO-1224, the dash-o move of
# the row spine-scrip-assembly-output-moves-from-o-file-to-out-file...). A bare -o FILE is refused by the driver; this finds the callers.
#
# What counts as a scrip command, in shell text (a .sh, .mk or Makefile, and the bodies of heredocs, scanned line by line):
#   a segment (split on ; && || | & ( ) and newline, recursing into $( ) and backticks) whose FIRST scrip-like word is preceded only by
#   assignments, options, durations, expansions and the wrappers env timeout nice valgrind xargs clean and friends. A scrip-like word is
#   a path whose last component is scrip or scrip0, or $NAME where NAME is SCRIP, SCRIP_BIN, SCRIP_CC, SG_SCRIP or a variable the same
#   file assigns a scrip-like value (also through ${X:-default}). gcc -o, icont -o, -o=file (the listing sink) and everything after
#   a bare -- are never touched.
# What counts in Python: a list or tuple literal holding "-o" followed by a value AND "--compile" or "--target=..." or a scrip-named
#   first element (ast, so a gcc list is never touched); and, in shell files, python text of the shape "--compile", "-o", NAME.
#
# scan: prints path:line: text for each hit, then HITS n; rc 1 when n > 0, rc 0 when 0.   apply: rewrites in place, prints REWROTE n.
# --exclude=BASENAME (repeatable) leaves a file out, for a gate whose own fixtures hold the shapes it hunts.
#
# Migration record, 2026-10-29 (step 2 of the row; apply over the parents of SCRIP 62b9f095a, harness d7a8ccd, corpus 8f0a4e8d1, .github 3520dc48e,
# then four hand edits, three stub compilers and the prose): harness 1,007 files (995 shell, 12 Python; 1,199 --out= tokens), SCRIP 2 (the
# Makefile and the README), corpus 1 (a README), .github 11 (the instruction pages and 4 probe or wip scripts): 1,021 files in the four repos.
# The harness commit's own message says 1,019 files, 1,207 tokens and 859 shell files: those are working totals of the sitting and a miscount; the
# figures here are counted from the commit (git show --stat, 995 .sh and 12 .py in it).
import ast, collections, os, re, sys

ASSIGN = re.compile(r'^(\$\{?)?[A-Za-z_][A-Za-z_0-9]*(\})?(\[[^\]]*\])?\+?=')
PREFIX_WORDS = {'env', 'timeout', 'nice', 'ionice', 'stdbuf', 'valgrind', 'strace', 'exec', 'command', 'time', '!', 'if', 'then', 'else',
                'elif', 'do', 'while', 'until', 'builtin', 'nohup', 'setsid', 'sudo', 'xargs', 'clean', 'taskset', '{'}
SEEDS = {'SCRIP', 'SCRIP_BIN', 'SCRIP_CC', 'SG_SCRIP'}
EXTRA = {'lib_gate.sh': {'_bin'}}
EMBEDDED = re.compile(r'(["\'])--compile\1\s*,\s*(["\'])-o\2\s*,\s*([A-Za-z_][\w.]*)')


class Tok:
    __slots__ = ('s', 'e', 'text', 'kind')

    def __init__(self, s, e, text, kind):
        self.s, self.e, self.text, self.kind = s, e, text, kind


def match_close(t, i, open_c, close_c):
    depth, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == '\\':
            i += 2
            continue
        if c == "'":
            j = t.find("'", i + 1)
            i = (j + 1) if j >= 0 else n
            continue
        if c == '"':
            i += 1
            while i < n and t[i] != '"':
                if t[i] == '\\':
                    i += 1
                elif t[i] == '$' and i + 1 < n and t[i + 1] == '(':
                    i = match_close(t, i + 1, '(', ')') - 1
                i += 1
            i += 1
            continue
        if c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def lex(t, base=0, tolerant=False):
    toks, subs = [], []
    i, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == '\\' and i + 1 < n and t[i + 1] == '\n':
            i += 2
            continue
        if c in ' \t':
            i += 1
            continue
        if c == '\n':
            toks.append(Tok(base + i, base + i + 1, '\n', 'op'))
            i += 1
            continue
        if c == '#':
            j = t.find('\n', i)
            i = j if j >= 0 else n
            continue
        two = t[i:i + 2]
        if two in ('&&', '||', ';;', '|&'):
            toks.append(Tok(base + i, base + i + 2, two, 'op'))
            i += 2
            continue
        if c in ';|()&' and not (c == '&' and i + 1 < n and t[i + 1] == '>'):
            if c == '&' and i > 0 and t[i - 1] in '<>':
                i += 1
                continue
            toks.append(Tok(base + i, base + i + 1, c, 'op'))
            i += 1
            continue
        st, redir = i, False
        while i < n:
            c = t[i]
            if c == '\\':
                i += 2
                continue
            if c in ' \t\n' or c in ';|()':
                break
            if c == '&':
                if i + 1 < n and t[i + 1] == '&':
                    break
                if i > st and t[i - 1] in '<>':
                    i += 1
                    continue
                if i == st and i + 1 < n and t[i + 1] == '>':
                    redir = True
                    i += 1
                    continue
                break
            if c in '<>':
                redir = True
                i += 1
                continue
            if c == "'":
                j = t.find("'", i + 1)
                if j < 0:
                    if tolerant:
                        i = n
                        break
                    raise ValueError('unterminated quote at %d' % (base + i))
                i = j + 1
                continue
            if c == '"':
                i += 1
                while i < n and t[i] != '"':
                    if t[i] == '\\':
                        i += 2
                        continue
                    if t[i] == '$' and i + 1 < n and t[i + 1] == '(':
                        j = match_close(t, i + 1, '(', ')')
                        if j < 0:
                            if tolerant:
                                i = n
                                break
                            raise ValueError('unterminated $( at %d' % (base + i))
                        subs.append((i + 2, j - 1))
                        i = j
                        continue
                    if t[i] == '`':
                        j = t.find('`', i + 1)
                        if j > 0:
                            subs.append((i + 1, j))
                            i = j + 1
                            continue
                    i += 1
                if i >= n and not tolerant:
                    raise ValueError('unterminated dquote at %d' % (base + st))
                i += 1
                continue
            if c == '$' and i + 1 < n and t[i + 1] == '(':
                j = match_close(t, i + 1, '(', ')')
                if j < 0:
                    if tolerant:
                        i = n
                        break
                    raise ValueError('unterminated $( at %d' % (base + i))
                subs.append((i + 2, j - 1))
                i = j
                continue
            if c == '$' and i + 1 < n and t[i + 1] == '{':
                j = match_close(t, i + 1, '{', '}')
                i = j if j > 0 else i + 2
                continue
            if c == '`':
                j = t.find('`', i + 1)
                if j > 0:
                    subs.append((i + 1, j))
                    i = j + 1
                    continue
            i += 1
        kind = 'redir' if redir and re.match(r'^[0-9]*(&>|>>|>|<<<|<<-?|<)', t[st:i]) else 'w'
        toks.append(Tok(base + st, base + i, t[st:i], kind))
    return toks, [(base + a, base + b) for a, b in subs]


def unq(w):
    w = re.sub(r'\$\{([A-Za-z_]\w*)\}', r'$\1', w)
    return w.replace('"', '').replace("'", '')


def is_scrip(u, vars_):
    if re.search(r'(^|/)scrip0?$', u):
        return True
    m = re.fullmatch(r'\$([A-Za-z_]\w*)', u)
    return bool(m and m.group(1) in vars_)


def prefix_ok(w, prev=None):
    u = unq(w.text)
    if ASSIGN.match(u) or u in PREFIX_WORDS or u.startswith('-'):
        return True
    if prev is not None and unq(prev.text) in ('-u', '-C', '-S', '--unset') and re.fullmatch(r'[A-Za-z_]\w*', u):
        return True
    if re.fullmatch(r'\$\{[^}]*\}', u) or re.fullmatch(r'[0-9]+(\.[0-9]+)?[smhd]?', u):
        return True
    return bool(re.fullmatch(r'\$[A-Za-z_@*#?0-9]\w*', u))


def scan_text(t, vars_, base=0, tolerant=False, depth=0):
    toks, subs = lex(t, base, tolerant)
    hits, seg = [], []

    def flush():
        if not seg:
            return
        clean, skip = [], False
        for w in seg:
            if skip:
                skip = False
                continue
            if w.kind == 'redir':
                skip = bool(re.fullmatch(r'[0-9]*(&>|>>|>|<<<|<<-?|<)', w.text))
                continue
            clean.append(w)
        seg.clear()
        ks = [i for i, w in enumerate(clean) if is_scrip(unq(w.text), vars_)]
        if not ks or not all(prefix_ok(w, clean[i - 1] if i else None) for i, w in enumerate(clean[:ks[0]])):
            return
        args = clean[ks[0] + 1:]
        j = 0
        while j < len(args):
            a = args[j]
            if a.text == '--':
                break
            if a.text == '-o' and j + 1 < len(args):
                hits.append((a.s, args[j + 1].s, 'sep'))
                j += 1
            elif a.text.startswith('-o') and len(a.text) > 2 and a.text[2] != '=':
                hits.append((a.s, a.s, 'att'))
            j += 1

    for tk in toks:
        if tk.kind == 'op' or (tk.kind == 'w' and tk.text in ('{', '}', 'then', 'do', 'else', 'elif', 'fi', 'done', 'esac', 'in')):
            flush()
        else:
            seg.append(tk)
    flush()
    if depth < 4:
        for a, b in subs:
            hits += scan_text(t[a - base:b - base], vars_, a, tolerant, depth + 1)
    return hits


def heredoc_plan(t):
    lines = t.split('\n')
    starts, off = [], 0
    for ln in lines:
        starts.append(off)
        off += len(ln) + 1
    plan, k = [], 0
    while k < len(lines):
        plan.append(('main', k))
        m = re.search(r'<<-?\s*(["\']?)([A-Za-z_][A-Za-z_0-9]*)\1', lines[k])
        if m and '<<<' not in lines[k]:
            j = k + 1
            while j < len(lines) and lines[j].strip() != m.group(2):
                j += 1
            plan += [('body', b) for b in range(k + 1, min(j, len(lines)))]
            if j < len(lines):
                plan.append(('main', j))
            k = j + 1
            continue
        k += 1
    return plan, lines, starts


def shell_hits(t, vars_):
    plan, lines, starts = heredoc_plan(t)
    hits, buf = [], []

    def run_main():
        if not buf:
            return
        text = '\n'.join(l for _, l in buf)
        spans, o = [], 0
        for idx, l in buf:
            spans.append((o, o + len(l) + 1, starts[idx]))
            o += len(l) + 1
        try:
            found = scan_text(text, vars_)
        except ValueError:
            found, o2 = [], 0
            for idx, l in buf:
                found += scan_text(l, vars_, o2, True)
                o2 += len(l) + 1
        for a, b, kind in found:
            for lo, hi, fs in spans:
                if lo <= a < hi:
                    hits.append((fs + a - lo, fs + b - lo, kind))
                    break
        buf.clear()

    for kind, idx in plan:
        if kind == 'main':
            buf.append((idx, lines[idx]))
        else:
            run_main()
            hits += scan_text(lines[idx], vars_, starts[idx], True)
    run_main()
    return hits


def file_vars(path, text):
    vars_ = set(SEEDS) | EXTRA.get(os.path.basename(path), set())
    asg = re.compile(r'(?:^|[;&|(\s])(?:export\s+|local\s+|readonly\s+|declare\s+)?([A-Za-z_]\w*)=("[^"]*"|\'[^\']*\'|[^\s;"\'|&)]*)')
    pairs = [(m.group(1), m.group(2)) for ln in text.split('\n') if not ln.lstrip().startswith('#') for m in asg.finditer(ln)]
    changed = True
    while changed:
        changed = False
        for name, rhs in pairs:
            if name in vars_:
                continue
            r = re.sub(r'\$\{([A-Za-z_]\w*)\}', r'$\1', rhs.strip('"\''))
            m = re.fullmatch(r'\$\{[A-Za-z_]\w*:?-(.*)\}', r)
            if m:
                r = re.sub(r'\$\{([A-Za-z_]\w*)\}', r'$\1', m.group(1))
            if re.search(r'(^|/)scrip0?$', r) or (re.fullmatch(r'\$[A-Za-z_]\w*', r) and r[1:] in vars_):
                vars_.add(name)
                changed = True
    return vars_


def py_sites(src):
    out = []
    for n in ast.walk(ast.parse(src)):
        if not isinstance(n, (ast.List, ast.Tuple)):
            continue
        consts = [e.value for e in n.elts if isinstance(e, ast.Constant) and isinstance(e.value, str)]
        first = (ast.get_source_segment(src, n.elts[0]) or '') if n.elts else ''
        compiles = any(c == '--compile' or c.startswith('--target') for c in consts)
        gcc = bool(re.match(r'^["\']?(gcc|cc|g\+\+|clang|as|ld|swipl|gplc|fpc|iconx|icont)\b', first))
        for i, e in enumerate(n.elts[:-1]):
            if isinstance(e, ast.Constant) and e.value == '-o' and (compiles or (re.search('scrip', first, re.I) and not gcc)):
                out.append((e, n.elts[i + 1]))
    return out


def py_hits(text):
    lines = text.split('\n')

    def off(ln, col):
        return sum(len(l) + 1 for l in lines[:ln - 1]) + len(lines[ln - 1].encode('utf-8')[:col].decode('utf-8'))

    hits = []
    for e, x in py_sites(text):
        a, b = off(e.lineno, e.col_offset), off(x.end_lineno, x.end_col_offset)
        xs = text[off(x.lineno, x.col_offset):b]
        hits.append((a, b, 'py', xs))
    return hits


def gather(paths):
    out = []
    for p in paths:
        if os.path.isdir(p):
            for dp, dn, fn in os.walk(p):
                dn[:] = [d for d in dn if d not in ('.git', 'out', 'obj', 'node_modules')]
                out += [os.path.join(dp, f) for f in fn if f.endswith(('.sh', '.mk', '.py')) or f == 'Makefile']
        else:
            out.append(p)
    return sorted(out)


def rewrite(path, text):
    edits = []
    if path.endswith('.py'):
        try:
            for a, b, kind, xs in py_hits(text):
                if '\n' in xs:
                    continue
                q = "'" if '"' in xs else '"'
                edits.append((a, b, 'f%s--out={%s}%s' % (q, xs, q) if not re.fullmatch(r'["\'][^"\'{}]*["\']', xs) else '"--out=' + xs[1:-1] + '"'))
        except SyntaxError:
            pass
    else:
        for a, b, kind in shell_hits(text, file_vars(path, text)):
            edits.append((a, b if kind == 'sep' else a + 2, '--out='))
        for m in EMBEDDED.finditer(text):
            edits.append((m.start(2), m.end(3), 'f"--out={%s}"' % m.group(3)))
    return sorted(set(edits), reverse=True)


def line_of(text, pos):
    return text.count('\n', 0, pos) + 1


def main():
    mode = sys.argv[1]
    skip = {a[10:] for a in sys.argv[2:] if a.startswith('--exclude=')}
    paths = [p for p in gather([a for a in sys.argv[2:] if not a.startswith('--exclude=')]) if os.path.basename(p) not in skip]
    total = 0
    for p in paths:
        try:
            text = open(p, encoding='utf-8', errors='surrogateescape').read()
        except OSError:
            continue
        edits = rewrite(p, text)
        total += len(edits)
        if mode == 'scan':
            for a, b, _ in sorted(edits):
                print('%s:%d: %s' % (p, line_of(text, a), text.split('\n')[line_of(text, a) - 1].strip()[:160]))
        elif edits:
            for a, b, new in edits:
                text = text[:a] + new + text[b:]
            open(p, 'w', encoding='utf-8', errors='surrogateescape').write(text)
    print(('HITS %d' if mode == 'scan' else 'REWROTE %d') % total)
    return 1 if mode == 'scan' and total else 0


if __name__ == '__main__':
    sys.exit(main())
