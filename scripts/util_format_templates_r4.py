#!/usr/bin/env python3
"""util_format_templates_r4.py [--check] [FILE...] (default: every src/templates/bb/bb_*.cpp and src/templates/xa/xa_*.cpp) : the R4 hygiene mechanism over template sources -- whitespace and string-literal splitting ONLY.
  1. one x86( call per source line (a line holding two or more is broken before each later one, the joining '+' moving to the new line);
  2. no line over 200 columns (broken at the last top-level ' + ' or ', ' outside string literals that fits; a long string literal is split
     into adjacent literals, which the compiler concatenates);
  3. a one-line function whose body begins with a declaration on the signature line is expanded to one statement per line.
Every token is kept, in order; the only change to a token is a string literal split into two adjacent literals.
--check prints the three counts per file and exits 1 if any is non-zero; without it the files are rewritten in place.
HQ-TEMPLATES (CEO-1321), the R4 hygiene mechanism landed whole over the population (LARGE CHUNKS, CEO-1479): run it over a template you changed and the audit's over_col, multi_x86 and sig_decls
classes stay at 0; after a rebase conflict in a template file, take your side of the file and re-run it."""
import re, sys

COLS = 200
# The bb_call family was left out until the safe-point census measured its poll window in x86 calls (62514e7f0, f09217bae); a whitespace-only reformat no longer moves a poll out of its window, so the family is in the default population.
CALL_FAMILY = ()
LIM = 190
SD = re.compile(r'\)\s*\{\s*(std::string|int |long |const char|auto |bool |double |char |uint64_t|size_t|IR_t)')

def scan(line):
    """Yield (index, char) of every char of `line` outside a string or char literal."""
    i = 0; n = len(line)
    while i < n:
        c = line[i]
        if c in '"\'':
            j = i + 1
            while j < n and line[j] != c:
                if line[j] == '\\': j += 1
                j += 1
            i = j + 1; continue
        yield i, c
        i += 1

def blank_strings(line):
    out = list(line)
    i = 0; n = len(line)
    while i < n:
        c = line[i]
        if c in '"\'':
            j = i + 1
            while j < n and line[j] != c:
                if line[j] == '\\': j += 1
                j += 1
            for k in range(i + 1, min(j, n)): out[k] = ' '
            i = j + 1; continue
        i += 1
    return ''.join(out)

def indent_of(line):
    return len(line) - len(line.lstrip(' '))

def x86_positions(body):
    outside = set(i for i, c in scan(body))
    return [m.start() for m in re.finditer(r'\bx86\(', body) if m.start() in outside]

def split_multi_x86(body):
    """body has no trailing backslash. Returns a list of lines (no backslashes)."""
    pos = x86_positions(body)
    if len(pos) < 2: return [body]
    lead = indent_of(body) if body.lstrip().startswith(('+', '?', ':')) else max(4, pos[0] - 2)
    parts = []; start = 0
    for p in pos[1:]:
        parts.append(body[start:p]); start = p
    parts.append(body[start:])
    res = []; carry = ''
    for k, part in enumerate(parts):
        text = part.rstrip(); plus = False
        if k < len(parts) - 1:
            m = re.search(r'\+\s*$', text)
            if m: text = text[:m.start()].rstrip(); plus = True
        res.append(text if k == 0 else ' ' * lead + carry + text.lstrip())
        carry = '+ ' if plus else ''
    return res

def split_long_string(body):
    for mm in re.finditer(r'"((?:[^"\\]|\\.)*)"', body):
        if len(mm.group(0)) > 100 and mm.start() < LIM:
            s = mm.group(1)
            room = max(30, min(110, LIM - mm.start() - 4))
            cut = s.rfind(' ', 0, room)
            while cut > 0 and s[cut + 1:].startswith(('[rsp', '[rbp')): cut = s.rfind(' ', 0, cut)
            if cut <= 0: continue
            head = body[:mm.start()]
            a, b = s[:cut + 1], s[cut + 1:]
            return [head + '"' + a + '"', ' ' * (indent_of(head) + 4) + '"' + b + '"' + body[mm.end():]]
    return None

def compress_padding(body):
    """Alignment padding inside a line (a run of 4+ spaces that is not the leading indent) is collapsed to one space."""
    ind = indent_of(body)
    outside = set(i for i, c in scan(body))
    out = []; i = ind; n = len(body)
    while i < n:
        if body[i] == ' ' and i in outside:
            j = i
            while j < n and body[j] == ' ': j += 1
            out.append(' ' if j - i >= 4 else body[i:j]); i = j; continue
        out.append(body[i]); i += 1
    return body[:ind] + ''.join(out)

def break_long(body):
    if len(body) <= COLS: return [body]
    body = compress_padding(body)
    if len(body) <= COLS: return [body]
    outside = set(i for i, c in scan(body))
    best = None
    depth = 0; semis = []
    for i, c in scan(body):
        if c == '(' : depth += 1
        elif c == ')': depth = max(0, depth - 1)
        elif c == ';' and depth == 0 and i + 1 < len(body) and body[i + 1] == ' ' and indent_of(body) < i <= LIM: semis.append(i)
    first_tok = indent_of(body)
    for m in re.finditer(r' \+ | && | \|\| |, ', body):
        if m.start() in outside and first_tok < m.start() <= LIM: best = m
    if best is None and not semis:
        tern = [m for m in re.finditer(r' [?:] ', body) if m.start() in outside and indent_of(body) < m.start() <= LIM]
        if tern:
            m = tern[-1]; ind = indent_of(body)
            out = []
            for r in [body[:m.start()].rstrip(), ' ' * (ind + 4) + body[m.start() + 1:]]: out.extend(break_long(r))
            return out
    if best is None and semis:
        p = semis[-1]; ind = indent_of(body)
        out = []
        for r in [body[:p + 1], ' ' * (ind + 4) + body[p + 2:]]: out.extend(break_long(r))
        return out
    if best is None:
        sp = split_long_string(body)
        if sp is None: return [body]
        out = []
        for r in sp: out.extend(break_long(r))
        return out
    p = best.start(); tok = best.group(0); ind = indent_of(body)
    if tok in (' + ', ' && ', ' || '):
        op = tok.strip()
        res = [body[:p].rstrip(), ' ' * (ind + 4) + op + ' ' + body[p + len(tok):]]
    else:
        res = [body[:p + 1], ' ' * (ind + 4) + body[p + 2:].lstrip()]
    out = []
    for r in res: out.extend(break_long(r))
    return out

def split_statements(text):
    """Split `text` (the inside of a block or a statement run) into top-level statements at ';' (paren/brace depth 0) and after a closing '}' at depth 0."""
    out = []; cur = ''; dp = db = 0; i = 0; n = len(text)
    while i < n:
        c = text[i]
        if c in '"\'':
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == '\\': j += 1
                j += 1
            cur += text[i:j + 1]; i = j + 1; continue
        if c == '(': dp += 1
        elif c == ')': dp = max(0, dp - 1)
        elif c == '{': db += 1
        elif c == '}':
            db -= 1; cur += c; i += 1
            if db == 0 and dp == 0:
                rest = text[i:].lstrip()
                if not rest.startswith(('else', 'while', ';', ',')):
                    out.append(cur.strip()); cur = ''
            continue
        elif c == ';' and dp == 0 and db == 0:
            out.append((cur + ';').strip()); cur = ''; i += 1; continue
        cur += c; i += 1
    if cur.strip(): out.append(cur.strip())
    return out

def expand_block(stmt, ind):
    """A statement holding `) { <declaration> ...` (an if/for/while block opened with a declaration) is written one statement per line."""
    if not SD.search(blank_strings(stmt)): return [' ' * ind + stmt]
    d = 0; n = len(stmt); i = 0
    while i < n:
        c = stmt[i]
        if c in '"\'':
            j = i + 1
            while j < n and stmt[j] != c:
                if stmt[j] == '\\': j += 1
                j += 1
            i = j + 1; continue
        if c == '(': d += 1
        elif c == ')': d = max(0, d - 1)
        elif c == '{' and d == 0:
            k = i; depth = 0
            while k < n:
                ch = stmt[k]
                if ch in '"\'':
                    j = k + 1
                    while j < n and stmt[j] != ch:
                        if stmt[j] == '\\': j += 1
                        j += 1
                    k = j + 1; continue
                if ch == '{': depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0: break
                k += 1
            if k >= n: return [' ' * ind + stmt]
            head = stmt[:i + 1].rstrip(); inner = stmt[i + 1:k].strip(); tail = stmt[k + 1:].strip()
            out = [' ' * ind + head]
            for st in split_statements(inner): out.extend(expand_block(st, ind + 4))
            out.append(' ' * ind + '}' + ((' ' + tail) if tail else ''))
            return out
        i += 1
    return [' ' * ind + stmt]

def expand_one_line_function(line):
    if not SD.search(blank_strings(line)): return None
    if line.lstrip().startswith('#'): return None
    s = line; n = len(s)
    depth_p = depth_b = 0; sig = None; stmts = []; cur = ''
    i = 0
    while i < n:
        c = s[i]
        if c in '"\'':
            j = i + 1
            while j < n and s[j] != c:
                if s[j] == '\\': j += 1
                j += 1
            cur += s[i:j + 1]; i = j + 1; continue
        if c == '(': depth_p += 1
        elif c == ')': depth_p -= 1
        elif c == '{':
            if sig is None and depth_p <= 0 and depth_b == 0:
                sig = (cur + '{').rstrip(); cur = ''; depth_b = 1; i += 1; continue
            depth_b += 1
        elif c == '}':
            depth_b -= 1
            if depth_b == 0:
                if cur.strip(): stmts.append(cur.strip())
                if s[i + 1:].strip(): return None
                return ([sig] + [ln for st in stmts for ln in expand_block(st, 4)] + ['}']) if sig and stmts else None
        elif c == ';' and depth_p == 0 and depth_b == 1:
            stmts.append((cur + ';').strip()); cur = ''; i += 1; continue
        cur += c; i += 1
    # a function that continues on later lines: the declaration still leaves the signature line
    if sig is not None:
        rest = s[len(sig):].lstrip() if s.startswith(sig) else None
        if rest: return [sig, '    ' + rest]
    return None

def process(text):
    L = text.split('\n'); out = []
    for l in L:
        if l.lstrip().startswith('#include') or l.startswith('/*') or not l.strip():
            out.append(l); continue
        cont = l.rstrip().endswith('\\')
        body = l.rstrip()[:-1].rstrip() if cont else l
        pieces = expand_one_line_function(body) if not cont else None
        if not pieces and not cont and not body.lstrip().startswith('#') and SD.search(blank_strings(body)):
            ind = indent_of(body); sts = split_statements(body.strip())
            pieces = [ln for st in sts for ln in expand_block(st, ind)]
        pieces = pieces or [body]
        res = []
        for p in pieces:
            for q in split_multi_x86(p):
                res.extend(break_long(q))
        if cont: res = [r + ' \\' for r in res]
        out.extend(res)
    return '\n'.join(out)

def counts(text):
    cl = sum(1 for l in text.split('\n') if len(l) > COLS)
    ml = sum(1 for l in re.sub(r'"[^"]*"', '', text.replace('\\"', '')).split('\n') if re.search(r'x86\(.*x86\(', l))
    sd = sum(1 for l in text.split('\n') if SD.search(blank_strings(l)))
    return cl, ml, sd

if __name__ == '__main__':
    import glob, os
    check = '--check' in sys.argv
    files = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not files:
        root = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
        files = sorted(glob.glob(root + '/src/templates/bb/bb_*.cpp') + glob.glob(root + '/src/templates/xa/xa_*.cpp'))
        files = [f for f in files if os.path.basename(f) not in CALL_FAMILY]
    bad = 0
    for f in files:
        t = open(f, encoding='utf-8').read()
        if check:
            c = counts(t)
            if any(c): bad = 1; print('%-40s over_col %d multi_x86 %d sig_decls %d' % (f.split('/')[-1], *c))
            continue
        n = process(t)
        if n != t:
            open(f, 'w', encoding='utf-8').write(n)
            print('%-40s before %s after %s   (over_col, multi_x86, sig_decls)' % (f.split('/')[-1], counts(t), counts(n)))
    sys.exit(bad)
