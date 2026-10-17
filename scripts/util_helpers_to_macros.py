#!/usr/bin/env python3
"""util_helpers_to_macros.py [--check] [FILE...] (default: every src/templates/bb/bb_*.cpp and src/templates/xa/xa_*.cpp) : the R5 helper mechanism over template sources.
A template keeps at most two file-scope statics (TEMPLATE SPEC v2, audit class helper_count); every other helper is a same-named file macro. A top-level
    static [inline] TYPE name(params) { return EXPR; }
whose body is exactly one return of one expression is rewritten, in place and in the same position, as
    #define name(params) (EXPR)
the expression's own lines kept (one line of C++ per line of emitted asm), each but the last ending in a backslash.
A function is converted only when it is safe to do so by construction: no default argument, no block or lambda or assignment in the body, never referenced except as a call, and a parameter the body
uses more than once is converted only when every call site passes it a side-effect-free argument (no call). A parameter is parenthesized at each use; one of a narrowing or sign-changing type (bool, unsigned, uint64_t, double, char and the like) is also cast to its declared type, and a result of such a type is cast to
the declared return type, so the macro converts exactly as the function did; an int, long, pointer or std::string result is not cast.
--check prints the candidates and the helper_count each file would read after, and exits 1 if any candidate exists; without it the files are rewritten in place.
A helper whose body holds an asm call or a gc poll, or whose name is inside the target argument of an x86("call", ...), stays a function: the safe-point and bare-poll censuses read the call's source line and a computed call target, and a macro body
reports the line of its invocation. Only as many are converted as the file's static count exceeds two, the shortest bodies first, so a one-box file keeps its box body a function.
HQ-TEMPLATES (CEO-1321), after a rebase conflict or a landing that adds a static to a template: run it over the file, rebuild, A/B."""
import re, sys, glob, os

CAST = {'unsigned', 'unsigned int', 'unsigned long', 'uint64_t', 'uint32_t', 'int64_t', 'size_t', 'bool', 'double', 'char', 'uint8_t', 'uint16_t', 'int32_t', 'short'}
HEAD = re.compile(r'^static[ \t]+(?:inline[ \t]+)?((?:(?:const|unsigned|signed|long|short)[ \t]+)*[\w:]+(?:[ \t]*\*+)?)(?:[ \t]+|(?<=\*))(\w+)[ \t]*\(([^()]*)\)[ \t]*\{', re.M)
COLS = 200


def blank(s):
    out = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c in '"\'':
            j = i + 1
            while j < n and s[j] != c:
                if s[j] == '\\':
                    j += 1
                j += 1
            out.append(c + ' ' * (j - i - 1) + (c if j < n else ''))
            i = j + 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def match_brace(s, i):
    d = 1
    j = i
    n = len(s)
    while d and j < n:
        c = s[j]
        if c in '"\'':
            k = j + 1
            while k < n and s[k] != c:
                if s[k] == '\\':
                    k += 1
                k += 1
            j = k + 1
            continue
        if c == '{':
            d += 1
        elif c == '}':
            d -= 1
        j += 1
    return j


def split_args(t):
    out, d, cur = [], 0, []
    for c in t:
        if c in '([{':
            d += 1
        elif c in ')]}':
            d -= 1
        if c == ',' and d == 0:
            out.append(''.join(cur))
            cur = []
        else:
            cur.append(c)
    if ''.join(cur).strip() or out:
        out.append(''.join(cur))
    return out


def parse_params(p):
    p = p.strip()
    if p in ('', 'void'):
        return []
    out = []
    for a in split_args(p):
        m = re.fullmatch(r'\s*((?:const\s+)?[\w:]+(?:\s*[*&]+)?|[\w:]+\s+[\w:]+)\s*[*&]*\s*(\w+)\s*', a)
        m2 = re.fullmatch(r'\s*(.*?)\s*([*&]*)\s*(\w+)\s*', a)
        if not m2:
            return None
        t = (m2.group(1) + (' ' + m2.group(2) if m2.group(2) else '')).strip()
        if not m2.group(1).strip():
            return None
        out.append((t, m2.group(3)))
    return out


def sub_params(expr, params):
    segs = re.split(r'("(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\')', expr)
    for k in range(0, len(segs), 2):
        for t, nm in params:
            rep = '((%s)(%s))' % (t, nm) if t in CAST else '(%s)' % nm
            segs[k] = re.sub(r'(?<![\w.>:])%s\b(?!\s*::)' % re.escape(nm), lambda m: rep, segs[k])
    return ''.join(segs)


def simple_arg(a):
    b = blank(a)
    return not re.search(r'\w\s*\(', b.replace('sizeof', 'x')) and '++' not in b and '--' not in b and '=' not in re.sub(r'[=!<>]=', '', b)


def convert(path, apply):
    s = open(path, encoding='utf-8').read()
    heads = []
    for m in HEAD.finditer(s):
        heads.append(m)
    n_static = len(re.findall(r'^static', s, re.M))
    plans = []
    for m in heads:
        name = m.group(2)
        rtype = m.group(1).strip()
        i = m.end()
        j = match_brace(s, i)
        body = s[i:j - 1]
        bb = blank(body)
        if not re.fullmatch(r'\s*return\s[^;]*;\s*', bb):
            continue
        if '{' in bb or '}' in bb or re.search(r'(?<![=!<>])=(?!=)', bb) or '[]' in bb or '->*' in bb:
            continue
        params = parse_params(m.group(3))
        if params is None or '=' in m.group(3):
            continue
        rest = s[:m.start()] + s[j:]
        restb = blank(rest)
        if re.search(r'\b%s\b' % re.escape(name), blank(body)):
            continue
        calls = []
        ok = True
        for u in re.finditer(r'\b%s\b' % re.escape(name), restb):
            after = restb[u.end():]
            mm = re.match(r'\s*\(', after)
            if not mm:
                ok = False
                break
            k = u.end() + mm.end()
            d = 1
            q = k
            while d and q < len(restb):
                if restb[q] == '(':
                    d += 1
                elif restb[q] == ')':
                    d -= 1
                q += 1
            calls.append(rest[k:q - 1])
        if re.search(r'"call"|gc_poll', body) or re.search(r'x86\("call(?:_bare)?",\s*[^,]*\b%s\b' % re.escape(name), rest):
            continue
        if not ok or re.search(r'^static[^\n{(]*\b%s\s*\([^(){]*\)\s*;' % re.escape(name), rest, re.M):
            continue
        expr_lines = body.strip().split('\n')
        first = re.sub(r'^\s*return\s+', '', expr_lines[0])
        expr_lines = [first] + expr_lines[1:]
        expr_lines[-1] = re.sub(r';\s*$', '', expr_lines[-1])
        flat = blank(' '.join(expr_lines))
        multi = [nm for _, nm in params if len(re.findall(r'(?<![\w.>:])%s\b' % re.escape(nm), flat)) > 1]
        if multi:
            bad = False
            for c in calls:
                aa = split_args(c)
                if len(aa) != len(params):
                    bad = True
                    break
                for (t, nm), a in zip(params, aa):
                    if nm in multi and not simple_arg(a):
                        bad = True
            if bad:
                continue
        plans.append((m, j, name, rtype, params, expr_lines))
    need = max(0, n_static - 2)
    plans = sorted(plans, key=lambda q: sum(len(l) for l in q[5]))[:need]
    plans.sort(key=lambda q: q[0].start())
    if not plans:
        return 0, n_static, n_static
    out = []
    pos = 0
    for m, j, name, rtype, params, lines in plans:
        out.append(s[pos:m.start()])
        indent = len(lines[-1]) - len(lines[-1].lstrip()) if len(lines) > 1 else 0
        lines = [l for l in lines]
        txt = [sub_params(l, params) for l in lines]
        flat = blank(' '.join(x.strip() for x in txt))
        cast = '(%s)' % rtype if rtype in CAST else ''
        plist = ', '.join(nm for _, nm in params)
        if len(txt) == 1:
            body1 = txt[0].strip()
            line = '#define %s(%s) (%s)' % (name, plist, (cast + '(' + body1 + ')') if cast else body1)
            if len(line) > COLS:
                line = None
            new = line
        else:
            new = None
        if new is None:
            pad = ' ' * 4
            seq = [x.rstrip() for x in txt]
            mn = min(len(x) - len(x.lstrip()) for x in seq[1:]) if len(seq) > 1 else 0
            head = '#define %s(%s) ( \\' % (name, plist)
            rows = []
            for k, x in enumerate(seq):
                x = x.strip() if k == 0 else x[mn:] if len(x) >= mn else x.strip()
                rows.append(('      ' if k == 0 else '    ') + (cast + '(' if cast and k == 0 else '') + x + (')' if cast and k == len(seq) - 1 else '') + ('' if k == len(seq) - 1 else ' \\'))
            new = head + '\n' + '\n'.join(rows) + ' \\\n)'
            if any(len(r) > COLS for r in new.split('\n')):
                out[-1] = out[-1]
                out.append(s[m.start():j])
                pos = j
                continue
        out.append(new)
        pos = j
    out.append(s[pos:])
    res = ''.join(out)
    n_after = len(re.findall(r'^static', res, re.M))
    if apply and res != s:
        open(path, 'w', encoding='utf-8').write(res)
    return len(plans), n_static, n_after


def main():
    args = sys.argv[1:]
    check = '--check' in args
    files = [a for a in args if not a.startswith('--')]
    if not files:
        files = sorted(glob.glob('src/templates/bb/bb_*.cpp') + glob.glob('src/templates/xa/xa_*.cpp'))
    tot = 0
    for p in files:
        k, b, a = convert(p, not check)
        if k:
            tot += k
            print('%-44s %3d helper(s) -> macros; statics %2d -> %2d (helper_count %2d -> %2d)' % (os.path.basename(p), k, b, a, max(0, b - 2), max(0, a - 2)))
    print('total converted: %d' % tot)
    sys.exit(1 if (check and tot) else 0)


main()
