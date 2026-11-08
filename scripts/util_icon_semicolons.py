#!/usr/bin/env python3
# util_icon_semicolons.py -- insert the semicolons SCRIP Icon requires, exactly where the strict parser asks for them
# (Lon 2026-10-01, R-1392: every statement in a procedure body ends in ';'; only the last expression of a { } block is
# bare). The parser is the only authority (out/parser_icon when it exists, else scrip --dump-ast, whose parse error is the same message): each pass runs out/parser_icon, reads "expected ';' after the token at line L
# col C", finds that token's end on line L (a string literal to its closing quote, a name or number to the end of its run,
# any other token one character) and inserts ';' there; it loops until the file parses or the error is not a semicolon.
#   python3 ../harness/scripts/util_icon_semicolons.py [--check] [--compile-args=ARGS] FILE...     rc 0 every file parses (changed files named), 1 a file
#   python3 ../harness/scripts/util_icon_semicolons.py [--check] --master tests/<lang>/ALL.icn   every block entry between the banners
#   still refuses for another reason (named), 2 no parser binary. --check rewrites nothing and reports what it would add.
#   --compile-args=ARGS (the spelling util_add_ladder_witness.py takes; CTO-544 U2) parses with scrip --dump-ast ARGS, since out/parser_icon takes no switch (it opens
#   --dialect=unicon as a file); a package's unmarked_compile_args go here. An insertion cap of max(500, 4 * lines + 4). A file the parse completes whose import the
#   package resolver cannot find (icon: import: cannot find package, raised after the parse, icon_driver.c) is PARSED and the import named: that is the resolver's row.
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP"); PARSER = os.path.join(ROOT, 'out', 'parser_icon')
ERR = re.compile(r"expected ';'.*?after the token at line (\d+) col (\d+)")
def token_end(line, col):
    i = col - 1
    if i >= len(line): return len(line)
    c = line[i]
    if c in '"\'':
        j = i + 1
        while j < len(line):
            if line[j] == '\\': j += 2; continue
            if line[j] == c: return j + 1
            j += 1
        return len(line)
    if c.isalnum() or c == '_':
        j = i
        while j < len(line) and (line[j].isalnum() or line[j] == '_' or line[j] == '.'): j += 1
        return j
    if c == '$' and i + 1 < len(line) and line[i + 1] in '()<>': return i + 2
    return i + 1
def settle(line, e):
    q = None; i = 0; s = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == '\\': i += 1
            elif c == q:
                if s < e <= i: e = i + 1
                q = None
        elif c in '"\'': q = c; s = i
        elif c == '#': break
        i += 1
    while 0 < e < len(line) and (line[e - 1].isalnum() or line[e - 1] in '_.') and (line[e].isalnum() or line[e] in '_.'): e += 1
    return e
def code_end(line):
    q = None; i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == '\\': i += 1
            elif c == q: q = None
        elif c in '"\'': q = c
        elif c == '#': return len(line[:i].rstrip())
        i += 1
    return len(line.rstrip())
B, E = 1, 2
WORDS = {'break': 3, 'case': 1, 'create': 1, 'critical': 1, 'default': 1, 'end': 1, 'every': 1, 'fail': 3, 'if': 1, 'initial': 1, 'initially': 2, 'local': 1, 'next': 3, 'not': 1, 'repeat': 1, 'return': 3, 'static': 1, 'suspend': 3, 'thread': 1, 'until': 1, 'while': 1}
RESERVED = {'abstract', 'by', 'class', 'do', 'else', 'global', 'import', 'invocable', 'link', 'method', 'of', 'package', 'procedure', 'record', 'then', 'to'}
OPS = [('$(', 1), ('$)', 2), ('$<', 1), ('$>', 2), ('(', 1), (')', 2), ('[', 1), (']', 2), ('{', 1), ('}', 2), ('<<@', 3), ('<@', 3), ('@>>', 3), ('@>', 3), ('|||:=', 0), ('~===:=', 0), ('===:=', 0), ('~===', 1), ('===', 1), ('|||', 1), ('~==:=', 0), ('==:=', 0), ('~==', 1), ('==', 1),
       ('||:=', 0), ('~=:=', 0), ('~=', 1), ('||', 1), ('++:=', 0), ('--:=', 0), ('**:=', 0), ('++', 1), ('--', 1), ('**', 1), ('.|', 0), ('.>', 0), ('.$', 0), ('&&', 0), ('->', 0), ('=>', 0), ('::', 1), (':=:', 0), (':=', 0), ('??', 0), ('<->', 0), ('<-', 0), ('+:', 0), ('-:', 0),
       ('\\', 1), ('@', 1), ('?', 1), ('=', 1), ('~', 1), ('|', 1), ('^', 1), ('/', 1), ('.', 1), ('-', 1), ('+', 1), ('*', 1), ('&', 1), ('!', 1)]
OPS.sort(key=lambda o: -len(o[0]))
ENDERS = {'return', 'break', 'next', 'fail', 'suspend'}
NUMBER = re.compile(r'(?:\d+[rR][0-9a-zA-Z]+|\d+(?:\.\d*)?(?:[eE][-+]?\d+)?(?:[kKmMgGtTpP]|[dD]\d+)?|\.\d+(?:[eE][-+]?\d+)?)')
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
def lex(text):
    out = []; i = 0; n = len(text); line = 1; start = 0
    while i < n:
        c = text[i]
        if c == '\n': line += 1; start = i + 1; i += 1; continue
        if c in ' \t\r\f\v': i += 1; continue
        if c == '#':
            while i < n and text[i] != '\n': i += 1
            continue
        if c == '$' and text[start:i].strip() == '' and IDENT.match(text, i + 1):
            while i < n and text[i] != '\n': i += 1
            continue
        if c in '"\'':
            j = i + 1; l0 = line
            while j < n and text[j] != c:
                if text[j] == '\\': j += 1
                if j < n and text[j] == '\n': line += 1; start = j + 1
                j += 1
            out.append((l0, line, 3, i, j + 1, '')); i = j + 1; continue
        if c == '`':
            dbl = text.startswith('``', i); j = i + (2 if dbl else 1); stop = '``' if dbl else '`'
            while j < n and not text.startswith(stop, j): j += 1
            out.append((line, line, 2, i, j + len(stop), '')); i = j + len(stop); continue
        m = NUMBER.match(text, i) if (c.isdigit() or c == '.') else None
        if m and m.end() > i + (c == '.'):
            out.append((line, line, 3, i, m.end(), '')); i = m.end(); continue
        m = IDENT.match(text, i)
        if m:
            w = m.group(); out.append((line, line, WORDS.get(w, 0 if w in RESERVED else 3), i, m.end(), w)); i = m.end(); continue
        for o, f in OPS:
            if text.startswith(o, i): out.append((line, line, f, i, i + len(o), '')); i += len(o); break
        else:
            out.append((line, line, 0, i, i + 1, '')); i += 1
    return out
def preinsert(lines):
    text = '\n'.join(lines); toks = lex(text); marks = []
    for a, b in zip(toks, toks[1:]):
        if text[text.rfind('\n', 0, a[3]) + 1:a[3]].lstrip().split(' ')[0] in ('procedure', 'method', 'record') or text[text.rfind('\n', 0, a[3]) + 1:].lstrip().startswith(('procedure ', 'method ', 'record ')): continue
        if a[1] < b[0] and a[2] & E and b[2] & B and b[5] != 'end' and (b[5] == '' and text[b[3]] not in '"\'`' and not text[b[3]].isdigit() and text[b[3]] != '.' or text[b[3]:b[3] + 2] == '.' or a[5] in ENDERS): marks.append(a[4])
    for off in reversed(marks): text = text[:off] + ';' + text[off:]
    lines[:] = text.split('\n')
    added = []; line = 1; k = 0; marks.sort()
    for off in marks: added.append((text.count('\n', 0, off + k) + 1, off)); k += 1
    return added
SCRIP_BIN = os.path.join(ROOT, 'scrip')
PARSER_CMD = [PARSER] if os.path.exists(PARSER) else [SCRIP_BIN, '--dump-ast']
UNRESOLVED = re.compile(r'^icon: import: cannot find package ')
def parse_error(path):
    r = subprocess.run(PARSER_CMD + [os.path.basename(path)], cwd=os.path.dirname(os.path.abspath(path)), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=60)
    if r.returncode == 0: return None
    first = (r.stderr or '').strip().splitlines()[0] if (r.stderr or '').strip() else 'parse error (no message)'
    if UNRESOLVED.match(first): UNRESOLVED_SEEN[os.path.abspath(path)] = first; return None
    return first
UNRESOLVED_SEEN = {}
def string_close(lines, L, C):
    s = lines[L - 1]; i = C - 1
    if i >= len(s) or s[i] not in '"\'': return None
    q = s[i]; k = L - 1; j = i + 1
    while k < len(lines):
        s = lines[k]
        while j < len(s):
            if s[j] == '\\': j += 2; continue
            if s[j] == q: return (k, j + 1) if k > L - 1 else None
            j += 1
        if not s.rstrip().endswith('_'): return None
        k += 1; j = 0
    return None
def fix(path, check):
    lines = open(path, encoding='utf-8', newline='').read().split('\n'); added = preinsert(lines); cap = max(500, 4 * len(lines) + 4)
    for _ in range(cap):
        err = parse_error(path if not check and not added else write_tmp(path, lines))
        if err is None: break
        m = ERR.search(err)
        if not m: return added, err
        L, C = int(m.group(1)), int(m.group(2))
        if L < 1 or L > len(lines): return added, err
        sc = string_close(lines, L, C)
        if sc: lines[sc[0]] = lines[sc[0]][:sc[1]] + ';' + lines[sc[0]][sc[1]:]; added.append((sc[0] + 1, sc[1])); continue
        before = lines[L - 1]; e = settle(before, token_end(before, C))
        lines[L - 1] = before[:e] + ';' + before[e:]
        err2 = parse_error(write_tmp(path, lines))
        if err2 is not None and not ERR.search(err2):
            e = code_end(before); lines[L - 1] = before[:e] + ';' + before[e:]
        added.append((L, e))
    else:
        return added, 'gave up after %d insertions, the cap max(500, 4 * lines + 4) (a container of many programs is converted with --master)' % cap
    if added and not check: open(path, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
    return added, None
def write_tmp(path, lines):
    t = path + '.semi.icn'; open(t, 'w', encoding='utf-8', newline='').write('\n'.join(lines)); return t
BANNER = re.compile(r'^#-+ \d+ \S+')
def fix_master(path, check):
    text = open(path, encoding='utf-8', newline='').read(); lines = text.split('\n')
    starts = [i for i, l in enumerate(lines) if BANNER.match(l)]
    if not starts: print('REFUSE(2): %s has no entry banners' % path); return 2
    bounds = [(starts[k] + 1, (starts[k + 1] if k + 1 < len(starts) else len(lines))) for k in range(len(starts))]
    blocks = 0; semis = 0; bad = 0; d = os.path.dirname(os.path.abspath(path)); cfg = os.path.join(d, 'config')
    tmp = os.path.join(cfg if os.path.isdir(cfg) else d, os.path.basename(path) + '.semi.block.icn')
    for a, b in bounds:
        body = lines[a:b]
        while body and body[-1] == '': body.pop()
        open(tmp, 'w', encoding='utf-8', newline='').write('\n'.join(body) + '\n')
        added, err = fix(tmp, False)
        if err: bad += 1; print('STILL REFUSED %s block at line %d: %s' % (path, a + 1, err[:140])); continue
        if added:
            blocks += 1; semis += len(added)
            fixed = open(tmp, encoding='utf-8', newline='').read().rstrip('\n').split('\n')
            lines[a:a + len(body)] = fixed
    for t in (tmp, tmp + '.semi.icn'):
        if os.path.exists(t): os.unlink(t)
    if not check and blocks: open(path, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
    print('%s %s: entries=%d changed=%d semicolons=%d still_refused=%d' % ('WOULD CHANGE' if check else 'CHANGED', path, len(bounds), blocks, semis, bad)); return 1 if bad else 0
def main(argv):
    global PARSER_CMD
    ca = [a for a in argv if a.startswith('--compile-args=')]; argv = [a for a in argv if not a.startswith('--compile-args=')]
    args = ' '.join(a[len('--compile-args='):] for a in ca).split()
    if args: PARSER_CMD = [SCRIP_BIN, '--dump-ast'] + args
    check = '--check' in argv
    if '--master' in argv:
        return fix_master(argv[argv.index('--master') + 1], check)
    files = [a for a in argv if a != '--check']
    if PARSER_CMD[0] == PARSER and subprocess.run(['bash', '-c', '. "$1/lib_build_currency.sh" && assert_parser_current icon "$2"', '-', HERE, ROOT]).returncode != 0:
        print('REFUSE(2): out/parser_icon is missing or older than a source it was compiled from (named above) -- make parsers'); return 2
    bad = 0; changed = 0
    for f in files:
        added, err = fix(f, check)
        t = f + '.semi.icn'
        if os.path.exists(t): os.unlink(t)
        if added: changed += 1; print('%s %s: %d semicolon(s) at %s' % ('WOULD ADD' if check else 'ADDED', f, len(added), ' '.join('%d:%d' % a for a in added[:12])))
        if err: bad += 1; print('STILL REFUSED %s: %s' % (f, err[:160]))
        u = [v for k, v in UNRESOLVED_SEEN.items() if k in (os.path.abspath(f), os.path.abspath(t))]
        if u and not err: print('PARSED %s, its import unresolved (the package resolver runs after the parse; not this converter\'s): %s' % (f, u[-1][:160]))
    print('files=%d changed=%d still_refused=%d' % (len(files), changed, bad)); return 1 if bad else 0
if __name__ == '__main__': sys.exit(main(sys.argv[1:]))
