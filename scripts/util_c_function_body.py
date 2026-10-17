#!/usr/bin/env python3
"""util_c_function_body.py FILE NAME [NAME...] [--raw] -- print the file-scope DEFINITION of each named C function, one statement per line.

A structural gate that read a function by physical line (an awk range from the line `static void f(...)` to the next `^}`) went
blind when the 200-column re-flow (CEO-1565) packed a block onto one line or put its opening brace beside the signature. This
tool finds the definition by its name and its braces instead: the name followed by a parameter list and a `{` (a prototype,
ending in `;`, and a call, followed by anything else, are skipped, so an extern "C" guard is transparent), then the body to
its matching `}`, counting braces outside strings, character literals and comments. The text is printed with a line break after every `{`, `}` and `;` that sits outside parentheses, so a
gate's grep for one statement reads the same whatever the layout: one statement per line, the signature on the first.
--raw prints the definition as the file spells it. rc 0 when every name was found, rc 1 when one was not (named on stderr),
rc 2 on a usage error.
"""
import re, sys


def strip_noncode(src):
    out = []; i = 0; n = len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i); j = n if j < 0 else j; out.append(' ' * (j - i)); i = j
        elif c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2); j = n if j < 0 else j + 2; out.append(re.sub(r'[^\n]', ' ', src[i:j])); i = j
        elif c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == '\\' else 1
            j = min(j + 1, n); out.append(c + ' ' * (j - i - 2) + c if j - i >= 2 else src[i:j]); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)


def find_definition(src, code, name):
    for m in re.finditer(r'(?<![\w.>])' + re.escape(name) + r'\s*\(', code):
        i = m.end(); p = 1
        while i < len(code) and p:
            p += {'(': 1, ')': -1}.get(code[i], 0); i += 1
        j = i
        while j < len(code) and code[j] in ' \t\r\n':
            j += 1
        if j >= len(code) or code[j] != '{':
            continue
        b = 0; k = j
        while k < len(code):
            if code[k] == '{':
                b += 1
            elif code[k] == '}':
                b -= 1
                if b == 0:
                    break
            k += 1
        s = code.rfind('\n', 0, m.start()) + 1
        return s, k + 1
    return None


def one_statement_per_line(src, code):
    out = []; line = []; paren = 0
    for c, d in zip(src, code):
        if d == '\n':
            d = c = ' '
        line.append(c)
        if d == '(':
            paren += 1
        elif d == ')':
            paren -= 1
        elif d in '{};' and paren <= 0:
            t = ''.join(line).strip()
            if t:
                out.append(re.sub(r'\s+', ' ', t) if not t.startswith('#') else t)
            line = []
    t = ''.join(line).strip()
    if t:
        out.append(re.sub(r'\s+', ' ', t))
    return '\n'.join(out) + '\n'


def main(argv):
    raw = '--raw' in argv
    args = [a for a in argv if a != '--raw']
    if len(args) < 2:
        sys.stderr.write(__doc__); return 2
    try:
        src = open(args[0], encoding='utf-8', errors='replace').read()
    except OSError as e:
        sys.stderr.write('util_c_function_body: %s\n' % e); return 2
    code = strip_noncode(src); rc = 0
    for name in args[1:]:
        r = find_definition(src, code, name)
        if not r:
            sys.stderr.write('util_c_function_body: no definition of %s in %s\n' % (name, args[0])); rc = 1; continue
        a, b = r
        sys.stdout.write(src[a:b] + '\n' if raw else one_statement_per_line(src[a:b], code[a:b]))
    return rc


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
