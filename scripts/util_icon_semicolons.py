#!/usr/bin/env python3
# util_icon_semicolons.py -- insert the semicolons SCRIP Icon requires, exactly where the strict parser asks for them
# (Lon 2026-10-01, CEO-1392: every statement in a procedure body ends in ';'; only the last expression of a { } block is
# bare). The parser is the only authority (out/parser_icon when it exists, else scrip --dump-ast, whose parse error is the same message): each pass runs out/parser_icon, reads "expected ';' after the token at line L
# col C", finds that token's end on line L (a string literal to its closing quote, a name or number to the end of its run,
# any other token one character) and inserts ';' there; it loops until the file parses or the error is not a semicolon.
#   python3 ../harness/scripts/util_icon_semicolons.py [--check] FILE...     rc 0 every file parses (changed files named), 1 a file
#   python3 ../harness/scripts/util_icon_semicolons.py [--check] --master tests/<lang>/ALL.icn   every block entry between the banners
#   still refuses for another reason (named), 2 no parser binary. --check rewrites nothing and reports what it would add.
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
ENDER = re.compile(r'(?<![\w$&])(return|break)$')
BEGINNER = re.compile(r'''(?:[A-Za-z_0-9"'(\[{\\/*+\-!~]|\$[(<]|&[A-Za-z])''')
NOT_BEGINNER = re.compile(r'(?:then|else|do|of|to|by)\b')
KEYWORD_AT_START = re.compile(r'&[A-Za-z]')
ENDS_EXPR = re.compile(r'''(?:[\w"')\]}]|\$[)>])$''')
CONTINUES = re.compile(r'(?<![\w$&])(?:if|while|until|every|case|not|create|then|else|do|of|to|by|initial|local|static|default|repeat)$')
def preinsert(lines):
    added = []
    for i, line in enumerate(lines):
        e = code_end(line)
        code = line[:e]
        nxt = next((l.strip() for l in lines[i + 1:] if l.strip() and not l.strip().startswith('#')), '')
        if ENDER.search(code): hit = BEGINNER.match(nxt) and not NOT_BEGINNER.match(nxt)
        else: hit = KEYWORD_AT_START.match(nxt) and ENDS_EXPR.search(code) and not CONTINUES.search(code)
        if nxt and hit:
            lines[i] = line[:e] + ';' + line[e:]; added.append((i + 1, e))
    return added
SCRIP_BIN = os.path.join(ROOT, 'scrip')
PARSER_CMD = [PARSER] if os.path.exists(PARSER) else [SCRIP_BIN, '--dump-ast']
def parse_error(path):
    r = subprocess.run(PARSER_CMD + [os.path.basename(path)], cwd=os.path.dirname(os.path.abspath(path)), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=60)
    return None if r.returncode == 0 else (r.stderr or '').strip().splitlines()[0] if (r.stderr or '').strip() else 'parse error (no message)'
def fix(path, check):
    lines = open(path, encoding='utf-8', newline='').read().split('\n'); added = preinsert(lines)
    for _ in range(500):
        err = parse_error(path if not check and not added else write_tmp(path, lines))
        if err is None: break
        m = ERR.search(err)
        if not m: return added, err
        L, C = int(m.group(1)), int(m.group(2))
        if L < 1 or L > len(lines): return added, err
        before = lines[L - 1]; e = settle(before, token_end(before, C))
        lines[L - 1] = before[:e] + ';' + before[e:]
        err2 = parse_error(write_tmp(path, lines))
        if err2 is not None and not ERR.search(err2):
            e = code_end(before); lines[L - 1] = before[:e] + ';' + before[e:]
        added.append((L, e))
    else:
        return added, 'gave up after 500 insertions (a container of many programs is converted with --master)'
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
    print('files=%d changed=%d still_refused=%d' % (len(files), changed, bad)); return 1 if bad else 0
if __name__ == '__main__': sys.exit(main(sys.argv[1:]))
