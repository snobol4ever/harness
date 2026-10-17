#!/usr/bin/env python3
"""util_raku_nqp_decl.py -- read an NQP grammar file into declarations: (container path, kind, name, params, body, line)."""
import re, sys
DECL = re.compile(r"^(\s*)(proto\s+)?(token|rule|regex|method|multi\s+method)\s+([A-Za-z_!][\w\-']*(?::sym<[^>]*>|:sym«[^»]*»|:[A-Za-z_]+<[^>]*>)?)\s*")
CONT = re.compile(r"^(\s*)(?:my\s+)?(grammar|role)\s+([A-Za-z_][\w:]*)")
def skip_class_seg(t, j):
    """t[j] == '[': index past the class's closing ']' (a backslash escapes)."""
    j += 1
    while j < len(t) and t[j] != ']':
        j += 2 if t[j] == '\\' else 1
    return j + 1
def skip_cclass(t, i):
    """t[i] == '<': if a character-class assertion starts here (<[..]>, <-[..]>, <?[..]>, <![..]>, <.[..]>, <+alpha+[..]>,
    <:Letter>...), return the index just past its '>'; else 0."""
    j = i + 1
    while j < len(t) and t[j] in '?!.': j += 1
    if j < len(t) and t[j] in '+-' and j + 1 < len(t) and (t[j+1] == '[' or t[j+1].isalpha() or t[j+1] == ':'): j += 1
    elif j < len(t) and t[j] == '[': pass
    elif t.startswith(':', j) and j + 1 < len(t) and (t[j+1].isalpha() or t[j+1] in '!'): pass
    else: return 0
    while j < len(t):
        c = t[j]
        if c == '[': j = skip_class_seg(t, j); continue
        if c in '+- \t\n': j += 1; continue
        if c == ':' or c.isalpha() or c == '!':
            while j < len(t) and (t[j].isalnum() or t[j] in ':_!'): j += 1
            continue
        if c == '>': return j + 1
        return 0
    return 0
def match_brace(t, i):
    """t[i] == '{': return the index just past the matching '}', skipping quoted strings, <[ ]> classes and # comments."""
    depth, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == '\\': i += 2; continue
        if c == "'" :
            j = i + 1
            while j < n and t[j] != "'":
                j += 2 if t[j] == '\\' else 1
            i = j + 1; continue
        if c == '"':
            j = i + 1
            while j < n and t[j] != '"':
                j += 2 if t[j] == '\\' else 1
            i = j + 1; continue
        if c == '#' and (i == 0 or t[i-1] in ' \t\n'):
            j = t.find('\n', i); i = n if j < 0 else j; continue
        if c == '<':
            j = skip_cclass(t, i)
            if j: i = j; continue
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: return i + 1
        i += 1
    raise ValueError('unbalanced brace')
def read(path):
    t = open(path, encoding='utf-8').read()
    lines = t.split('\n'); offs = [0]
    for l in lines: offs.append(offs[-1] + len(l) + 1)
    out, stack = [], []
    ln = 0
    while ln < len(lines):
        line = lines[ln]
        c = CONT.match(line)
        if c:
            ind = len(c.group(1).expandtabs())
            while stack and stack[-1][0] >= ind: stack.pop()
            stack.append((ind, c.group(3))); ln += 1; continue
        d = DECL.match(line)
        if d:
            ind = len(d.group(1).expandtabs())
            while stack and stack[-1][0] >= ind: stack.pop()
            pos = offs[ln] + d.end()
            params = ''
            if pos < len(t) and t[pos] == '(':
                depth, j = 0, pos
                while True:
                    if t[j] == '(': depth += 1
                    elif t[j] == ')':
                        depth -= 1
                        if depth == 0: break
                    j += 1
                params = t[pos+1:j]; pos = j + 1
            while pos < len(t) and t[pos] in ' \t\n': pos += 1
            if pos < len(t) and t[pos] == ':' and not t.startswith(':sym', pos):
                m = re.match(r':\w+(?:\([^)]*\))?\s*', t[pos:]); pos += m.end() if m else 0
            if pos < len(t) and t[pos] == '{':
                end = match_brace(t, pos); body = t[pos+1:end-1]
            else:
                end = pos; body = None
            kind = d.group(3).split()[-1]
            out.append(("/".join(n for _, n in stack), kind, d.group(4), params.strip(), body, ln + 1, bool(d.group(2))))
            ln = t.count('\n', 0, end); ln += 1 if ln == d and False else 0
            ln = t.count('\n', 0, end) + 1 if t.count('\n', 0, end) + 1 > ln else ln + 1
            continue
        ln += 1
    return out
if __name__ == '__main__':
    ds = read(sys.argv[1])
    rules = [d for d in ds if d[1] in ('token', 'rule', 'regex')]
    print('declarations', len(ds), 'rules', len(rules), 'distinct rule keys', len({d[0] + '/' + d[2] for d in rules}), 'methods', len(ds) - len(rules), 'no body', sum(1 for d in rules if d[4] is None))
