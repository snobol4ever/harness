#!/usr/bin/env python3
"""util_raku_nqp_regex.py -- parse an NQP regex body into a small AST.
Nodes: ('seq', [n...]) ('alt', kind '|' or '||', [n...]) ('conj', [n...]) ('quant', n, q, sep, sepkind, sigws)
('lit', text) ('cclass', spec) ('any',) ('anchor', a) ('group', n) ('cap', n) ('call', name, args, zero, neg, alias)
('look', kind, neg, n) ('codeassert', neg, code) ('true',) ('false',) ('sym',) ('code',) ('var', name) ('ws',) ('goal', open, close, n)
('mod', m) ('esc', c) ('named', name, n)"""
import re
class P:
    def __init__(s, t, sigspace=False): s.t, s.i, s.sig = t, 0, sigspace
    def peek(s, k=0): return s.t[s.i + k] if s.i + k < len(s.t) else '\0'
    def at(s, w): return s.t.startswith(w, s.i)
    def skipws(s):
        """skip insignificant whitespace and comments; return True if any whitespace was seen"""
        seen = False
        while s.i < len(s.t):
            c = s.t[s.i]
            if c in ' \t\r\n': s.i += 1; seen = True; continue
            if c == '#':
                j = s.t.find('\n', s.i); s.i = len(s.t) if j < 0 else j; seen = True; continue
            break
        return seen
    def parse(s):
        n = s.alt()
        s.skipws()
        if s.i < len(s.t): raise SyntaxError('trailing at %d: %r' % (s.i, s.t[s.i:s.i+40]))
        return n
    def alt(s, stop=''):
        s.skipws()
        kind = None
        if s.at('||'): s.i += 2; kind = '||'
        elif s.at('|') : s.i += 1; kind = '|'
        arms = [s.conj(stop)]
        while True:
            s.skipws()
            if s.at('||'): s.i += 2; k = '||'
            elif s.at('|') and not s.at('||'): s.i += 1; k = '|'
            else: break
            kind = kind if kind == '||' else k
            arms.append(s.conj(stop))
        return arms[0] if len(arms) == 1 else ('alt', kind or '|', arms)
    def conj(s, stop):
        arms = [s.seq(stop)]
        while True:
            s.skipws()
            if s.at('&&'): s.i += 2
            elif s.at('&') : s.i += 1
            else: break
            arms.append(s.seq(stop))
        return arms[0] if len(arms) == 1 else ('conj', arms)
    def seq(s, stop):
        items = []
        while True:
            ws_before = s.skipws()
            if s.i >= len(s.t) or s.peek() in ']):' + stop and not (s.peek() == ':' and s.is_mod()) or s.at('|') or s.at('&'):
                if s.peek() == ':' and s.is_mod(): pass
                else: break
            if s.sig and ws_before and items and items[-1][0] not in ('code', 'mod'): items.append(('ws',))
            a = s.quantified(stop)
            if a is None: break
            items.append(a)
        if s.sig and ws_before and items and items[-1][0] not in ('ws', 'code', 'mod'): items.append(('ws',))
        return items[0] if len(items) == 1 else ('seq', items)
    def is_mod(s):
        return bool(re.match(r':!?\w+', s.t[s.i:]))
    def quantified(s, stop):
        a = s.atom(stop)
        if a is None: return None
        while True:
            j = s.i
            s.skipws()
            q = None
            if s.at('**'):
                s.i += 2; s.skipws()
                m = re.match(r'(\d+)\s*(?:\.\.\s*(\d+|\*))?|\{\s*(\d+)\s*(?:\.\.\s*(\d+|\*))?\s*\}', s.t[s.i:])
                if not m: raise SyntaxError('bad ** at %d' % s.i)
                lo = m.group(1) or m.group(3); hi = m.group(2) or m.group(4) or lo
                s.i += m.end(); q = ('**', int(lo), hi)
            elif s.peek() in '*+?' and not s.at('?{'):
                q = s.peek(); s.i += 1
            if q is None:
                if s.peek() == ':' and not re.match(r':!?\w', s.t[s.i:]) and not s.at('::'): s.i += 1; continue
                s.i = j; return a
            if s.peek() in ':?!' and not s.at('!{'): s.i += 1
            sep = None; sk = None
            k = s.i; s.skipws()
            if s.at('%%'): s.i += 2; sk = '%%'
            elif s.at('%'): s.i += 1; sk = '%'
            else: s.i = k
            if sk: s.skipws(); sep = s.atom(stop)
            a = ('quant', a, q, sep, sk)
    def atom(s, stop):
        c = s.peek()
        if c == '\0': return None
        if c == "'": return ('lit', s.squote())
        if c in '\u2018\u201c':
            close = '\u2019' if c == '\u2018' else '\u201d'; j = s.t.index(close, s.i + 1); lit = s.t[s.i+1:j]; s.i = j + 1; return ('lit', lit)
        if c == '"': return ('lit', s.dquote())
        if c == '[':
            s.i += 1; n = s.alt(']'); s.skipws(); s.expect(']'); return ('group', n)
        if c == '(':
            s.i += 1; n = s.alt(')'); s.skipws(); s.expect(')'); return ('cap', n)
        if c == '{': j = s.brace(); return ('code',)
        if s.at('<<') or s.at('>>'): w = s.t[s.i:s.i+2]; s.i += 2; return ('anchor', w)
        if c == '<': return s.assertion()
        if c == '\\': return s.escape()
        if c == '.': s.i += 1; return ('any',)
        if s.at('^^'): s.i += 2; return ('anchor', '^^')
        if c == '^': s.i += 1; return ('anchor', '^')
        if s.at('$$'): s.i += 2; return ('anchor', '$$')
        if s.at('$<'):
            m = re.match(r'\$<([\w\-]+)>\s*=\s*', s.t[s.i:])
            if m: s.i += m.end(); return ('named', m.group(1), s.quantified(stop))
            m = re.match(r'\$<([\w\-]+)>', s.t[s.i:]); s.i += m.end(); return ('var', '$<' + m.group(1) + '>')
        if s.at('$*') or re.match(r'\$[A-Za-z_]', s.t[s.i:]):
            m = re.match(r'\$\*?[\w\-]+', s.t[s.i:]); s.i += m.end(); return ('var', m.group(0))
        if c == '$': s.i += 1; return ('anchor', '$')
        if s.at('«') : s.i += 1; return ('anchor', '<<')
        if s.at('»') : s.i += 1; return ('anchor', '>>')
        if s.at('<<') or s.at('>>'): w = s.t[s.i:s.i+2]; s.i += 2; return ('anchor', w)
        if c == ':':
            m = re.match(r':my\s', s.t[s.i:])
            if m:
                s.skip_to_semicolon(); return ('code',)
            m = re.match(r':dba\(', s.t[s.i:])
            if m:
                s.i += 4; depth = 0
                while s.i < len(s.t):
                    ch = s.t[s.i]
                    if ch == "'": s.squote(); continue
                    if ch == '"': s.dquote(); continue
                    if ch == '(': depth += 1
                    elif ch == ')':
                        depth -= 1
                        if depth == 0: s.i += 1; break
                    s.i += 1
                return ('mod', 'dba')
            m = re.match(r':(!?)(s|sigspace|i|ignorecase|r|ratchet|m|ignoremark|P5|Perl5)\b', s.t[s.i:])
            if m:
                s.i += m.end()
                if m.group(2) in ('s', 'sigspace'): s.sig = not m.group(1)
                return ('mod', m.group(1) + m.group(2))
            m = re.match(r':(!?\w+)', s.t[s.i:])
            if m: s.i += m.end(); return ('mod', m.group(1))
            return None
        if c == '~':
            s.i += 1; s.skipws(); close = s.quantified(stop); s.skipws(); inner = s.quantified(stop); return ('goal', None, close, inner)
        if c.isalnum() or c == '_':
            m = re.match(r'\w', s.t[s.i:]); s.i += 1; return ('lit', c)
        if c in ']):|&' + stop: return None
        if c in ',;=-!@%?+*/`': s.i += 1; return ('lit', c) if c in ',;=-' else ('lit', c)
        raise SyntaxError('unexpected %r at %d: %r' % (c, s.i, s.t[s.i:s.i+30]))
    def expect(s, w):
        if not s.at(w): raise SyntaxError('expected %r at %d: %r' % (w, s.i, s.t[s.i:s.i+30]))
        s.i += len(w)
    def squote(s):
        s.i += 1; out = ''
        while s.i < len(s.t) and s.t[s.i] != "'":
            if s.t[s.i] == '\\' and s.i + 1 < len(s.t) and s.t[s.i+1] in "\\'": out += s.t[s.i+1]; s.i += 2; continue
            out += s.t[s.i]; s.i += 1
        s.i += 1; return out
    def dquote(s):
        s.i += 1; out = ''
        esc = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', '"': '"', '0': '\0', 'e': '\x1b', 'f': '\f'}
        while s.i < len(s.t) and s.t[s.i] != '"':
            if s.t[s.i] == '\\' and s.i + 1 < len(s.t):
                out += esc.get(s.t[s.i+1], s.t[s.i+1]); s.i += 2; continue
            out += s.t[s.i]; s.i += 1
        s.i += 1; return out
    def brace(s):
        depth = 0; start = s.i
        while s.i < len(s.t):
            ch = s.t[s.i]
            if ch == '\\': s.i += 2; continue
            if ch == "'" : s.squote(); continue
            if ch == '"' : s.dquote(); continue
            if ch == '#' and s.i > 0 and s.t[s.i-1] in ' \t\n' and not s.t.startswith('#`', s.i):
                j = s.t.find('\n', s.i); s.i = len(s.t) if j < 0 else j; continue
            if ch == '{': depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0: s.i += 1; return s.t[start:s.i]
            s.i += 1
        raise SyntaxError('unbalanced { at %d' % start)
    def skip_to_semicolon(s):
        depth = 0
        while s.i < len(s.t):
            ch = s.t[s.i]
            if ch == "'": s.squote(); continue
            if ch == '"': s.dquote(); continue
            if ch in '({[': depth += 1
            elif ch in ')}]': depth -= 1
            elif ch == ';' and depth <= 0: s.i += 1; return
            s.i += 1
    def escape(s):
        c = s.peek(1); s.i += 2
        if c in 'xX' and s.peek() == '[':
            j = s.t.find(']', s.i); code = s.t[s.i+1:j]; s.i = j + 1; return ('lit', ''.join(chr(int(h, 16)) for h in code.split(',')))
        if c == 'c' and s.peek() == '[':
            j = s.t.find(']', s.i); s.i = j + 1; return ('cclass', 'any')
        if c in 'wWdDsShHvVnNtTrReEfF0': return ('esc', c)
        return ('lit', c)
    def assertion(s):
        t = s.t; i = s.i
        j = skip_cclass(t, i)
        if j: spec = t[i+1:j-1]; s.i = j; return ('cclass', spec)
        s.i += 1
        if s.at('!!{'):
            s.i += 2; code = s.brace(); s.skipws(); s.expect('>'); return ('true',)
        if s.at('?{') or s.at('!{'):
            neg = s.peek() == '!'; s.i += 1; code = s.brace(); s.skipws(); s.expect('>'); return ('codeassert', neg, code)
        if s.at('?>'): s.i += 2; return ('true',)
        if s.at('!>'): s.i += 2; return ('false',)
        if s.at('...>'): s.i += 4; return ('false',)
        if s.at('*>'): s.i += 2; return ('true',)
        m = re.match(r'([?!.&]*)([A-Za-z_][\w\-]*(?:::[A-Za-z_][\w\-]*)*)', t[s.i:])
        if not m:
            m2 = re.match(r'([?!.]*)(\$\*?[\w\-]+|@\*?[\w\-]+|~~)', t[s.i:])
            if m2:
                s.i += m2.end(); s.skipws(); s.expect('>'); return ('call', m2.group(2), '', False, m2.group(1).count('!') % 2 == 1, None)
            raise SyntaxError('bad assertion at %d: %r' % (i, t[i:i+40]))
        pre, name = m.group(1), m.group(2); s.i += m.end()
        alias = None
        if s.at('=') and s.peek(1) in ':[+-':
            j = t.index('>', s.i); spec = t[s.i+1:j]; s.i = j + 1; return ('cclass', spec)
        if s.at('=') :
            s.i += 1; m3 = re.match(r'([?!.&]*)([A-Za-z_][\w\-]*(?:::[A-Za-z_][\w\-]*)*)', t[s.i:]); alias = name; name = m3.group(2); pre = pre + m3.group(1); s.i += m3.end()
        zero = '?' in pre or '!' in pre; neg = pre.count('!') % 2 == 1
        if name in ('before', 'after') and (s.peek() in ' \t\n'):
            s.skipws(); n = s.alt('>'); s.skipws(); s.expect('>'); return ('look', name, neg, n)
        args = ''
        if s.peek() == '(':
            depth = 0; st = s.i
            while s.i < len(t):
                ch = t[s.i]
                if ch == "'": s.squote(); continue
                if ch == '"': s.dquote(); continue
                if ch == '(': depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth == 0: s.i += 1; break
                s.i += 1
            args = t[st+1:s.i-1]
        elif s.peek() == ':' and not s.at('::'):
            stack = []; st = s.i + 1; s.i += 1
            while s.i < len(t):
                ch = t[s.i]
                if ch == "'": s.squote(); continue
                if ch == '"': s.dquote(); continue
                if ch in '=-' and s.peek(1) == '>': s.i += 2; continue
                if ch in '([{<': stack.append(ch)
                elif ch in ')]}': stack and stack.pop()
                elif ch == '>':
                    if stack and stack[-1] == '<': stack.pop()
                    elif not stack: break
                s.i += 1
            args = t[st:s.i]
        elif s.peek() in ' \t\n' and name not in ('sym',):
            s.skipws()
            if not s.at('>'):
                n = s.alt('>'); s.skipws(); s.expect('>'); return ('call', name, '', zero, neg, alias, n)
        s.skipws(); s.expect('>')
        if name == 'sym': return ('sym',)
        return ('call', name, args, zero, neg, alias)
def skip_cclass(t, i):
    j = i + 1
    while j < len(t) and t[j] in '?!.': j += 1
    if j < len(t) and t[j] in '+-' and j + 1 < len(t) and (t[j+1] == '[' or t[j+1].isalpha() or t[j+1] == ':'): j += 1
    elif j < len(t) and t[j] == '[': pass
    elif t.startswith(':', j) and j + 1 < len(t) and (t[j+1].isalpha() or t[j+1] == '!'): pass
    else: return 0
    while j < len(t):
        c = t[j]
        if c == '[':
            j += 1
            while j < len(t) and t[j] != ']': j += 2 if t[j] == '\\' else 1
            j += 1; continue
        if c in '+- \t\n': j += 1; continue
        if c == ':' or c.isalpha() or c == '!':
            while j < len(t) and (t[j].isalnum() or t[j] in ':_!'): j += 1
            continue
        if c == '>': return j + 1
        return 0
    return 0
