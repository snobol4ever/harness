#!/usr/bin/env python3
"""util_template_state_words.py -- ARCH-ZETA-ONE-COORDINATE section 3.1 THE DERIVATION: every box kind's STATE WORDS, read from the templates.

THE RULE (the cto under CEO-1885/1888, 2026-10-22): a STATE WORD is a frame word a box keeps beyond its operand cell -- a word its own
template reads or writes at a port other than the alpha that wrote it -- and three facts of the TEMPLATE force one, never facts of a language:
  address-escapes  the box's word's address goes into r13, the Prolog choice register B, which outlives the box (the BOUND's and the
                   DISJUNCTION's choice header); or into an argument register before a call, when the box has no operand cell (every
                   word it owns is state: the tabling header) or its template touches the same block again after alpha (the leaf holds
                   the address while the child runs).  A lea of a word touched at alpha only is an argv block, never a state word.
  beta-read        a read of the box's word at beta or at a PAIR re-entry (an arm's gamma or omega landing), after a child ran; and a
                   read of ANOTHER box's word that the emitter arm points op_off at (IR_UNMARK reads its BOUND's mark after the goal ran)
  continuation     a jmp or call through a frame word, or a code address stored into one (a resume or step word)
Nothing else is a state word: the operand cell (the result slot +0/+8 of a value producer, ZRES), an operand's or argument's cell, and an
alpha-only word are the placement planner's business (TESTS 1 and 2), never a declaration.

THE METHOD: the emitter's dispatch (src/emitter/emit.cpp, the `case IR_*:` arms) names the templates each kind reaches -- by call, by
pointer (call_box_emit(bb_x)), and through template routing (bb_call -> bb_call_proc_staged) -- and the integer constants the arm sets
(IR_BOUND op_sb = 1, IR_UNMARK op_sb = 0) and whose word op_off names.  Each template is read in emission order with its std::string
helpers and macros (x86_asm.h, the bb headers, the template's statics) expanded inline, its IF / ?: / if branches pruned where a condition
reduces under the arm's constants, and the PORT tracked: alpha after x86_alpha(), beta after x86_beta() / x86_beta_trampoline(), reentry
after x86("def", PAIR(..)).  A frame form is FRQ FRQB FR FRD ZRES ZRESD XSAQ LFDQ, RDQ/RDD on "rbp", and every helper or macro yielding
one; its offset is resolved symbolically -- through the function's locals and the bodies of the emitter's slot helpers -- to the box's
RESULT cell (op_off, zls_off(node), bcps_result_slot()), another block the box owns (zls_act_off(node) ...), or someone else's cell
(bcps_arg_slot(): the argument's).  ir_node_produces_value (src/ir) says which kinds have an operand cell.  Each row cites the template
file and the line that carries the access, and the helper line it expands to.

USAGE (from anywhere; paths are fixed relative to this file):
  util_template_state_words.py                 one STATE_WORD row per kind and read, a STATE_WORD_KIND line per kind, the STATE_WORDS total
  util_template_state_words.py --kind IR_TO    only the named kinds (repeatable)
  util_template_state_words.py --all           also every frame access that implies no class, with the reason
  util_template_state_words.py --write         regenerate state_word_kinds.tsv beside this file from the derivation
  util_template_state_words.py --check         rc 0 when state_word_kinds.tsv equals the derivation and every cited line still carries its
                                               pattern; rc 1 names each row that drifted; rc 2 when an input is missing or unreadable
"""
import argparse
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SC = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP'))
TPL_DIR = os.path.join(SC, 'src', 'templates', 'bb')
X86_DIR = os.path.join(SC, 'src', 'templates', 'x86')
EMIT_DIR = os.path.join(SC, 'src', 'emitter')
EMIT = os.path.join(EMIT_DIR, 'emit.cpp')
IR_DIR = os.path.join(SC, 'src', 'ir')
TSV = os.path.join(HERE, 'state_word_kinds.tsv')
CLASSES = ('address-escapes', 'beta-read', 'continuation')
ARG_REGS = ('rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9')
PINNED = {'r13': 'B, the Prolog choice register, outlives the box'}
PRIMITIVE = {'x86', 'IF', 'FOR', 'emit_for', 'emit_seq', 'x86_bomb', 'x86_deflabel', 'x86_jmp', 'x86_jcc'}
BASE_FORMS = {'FRQ', 'FRQB', 'FR', 'FRD', 'ZRES', 'ZRESD', 'XSAQ', 'LFDQ'}
OPERAND_CELL_FORMS = {'ZRES', 'ZRESD'}
RESULT_FNS = {'zls_off', 'bb_slot_get', 'nd_slot', 'drive_value_slot', 'zls_result_off'}
WRITE_ONLY = {'mov', 'mov32', 'movq', 'movd', 'movabs', 'movzx', 'movsx', 'movsxd', 'lea', 'pop'}
READ_ONLY = {'cmp', 'test', 'bt', 'push', 'ucomisd', 'comisd'}
NO_ACCESS = {'note', 'comment', 'def', 'raw', 'align'}
TYPE_WORDS = {'int', 'long', 'short', 'char', 'unsigned', 'signed', 'const', 'size_t', 'int64_t', 'uint64_t', 'int32_t', 'uint32_t', 'uintptr_t', 'intptr_t', 'void',
              'double', 'float', 'bool', 'IR_t', 'IR_graph_t', 'DESCR_t'}
BINPREC = {'||': 1, '&&': 2, '|': 3, '^': 4, '&': 5, '==': 6, '!=': 6, '<': 7, '>': 7, '<=': 7, '>=': 7, '<<': 8, '>>': 8, '+': 9, '-': 9, '*': 10, '/': 10, '%': 10}
MAX_DEPTH = 10


class Refuse(Exception):
    pass


TOKEN = re.compile(r'''(?P<ws>[ \t\r\f\v]+)|(?P<nl>\n)|(?P<cmt>/\*.*?\*/|//[^\n]*)|(?P<str>"(?:\\.|[^"\\\n])*")|(?P<chr>'(?:\\.|[^'\\\n])+')
    |(?P<num>0[xX][0-9a-fA-F]+[uUlL]*|\d+(?:\.\d*)?(?:[eE][+-]?\d+)?[uUlLfF]*)|(?P<id>[^\W\d]\w*)
    |(?P<op>::|->|<<=|>>=|<<|>>|<=|>=|==|!=|&&|\|\||\+\+|--|\+=|-=|\*=|/=|%=|&=|\|=|\^=|[-+*/%&|^~!<>=?:;,.()\[\]{}#\\@$`])''', re.X | re.S)


class Tok(object):
    __slots__ = ('k', 't', 'f', 'l')

    def __init__(self, k, t, f, l):
        self.k, self.t, self.f, self.l = k, t, f, l

    def __repr__(self):
        return self.t


def tokenize(text, fname, line0=1):
    out, line, pos = [], line0, 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise Refuse('cannot tokenize %s:%d at %r' % (fname, line, text[pos:pos + 20]))
        k = m.lastgroup
        s = m.group(k)
        if k == 'nl':
            line += 1
        elif k == 'cmt':
            line += s.count('\n')
        elif k != 'ws':
            out.append(Tok(k, s, fname, line))
        pos = m.end()
    return out


def split_preprocessor(text, fname):
    """Blank every preprocessor line (keeping the line count); return the code and the #define macros found."""
    lines = text.split('\n')
    code, macros, i = list(lines), {}, 0
    while i < len(lines):
        if lines[i].lstrip().startswith('#'):
            j, phys = i, []
            while True:
                phys.append((j + 1, lines[j]))
                code[j] = ''
                if lines[j].rstrip().endswith('\\') and j + 1 < len(lines):
                    j += 1
                    continue
                break
            m = re.match(r'\s*#\s*define\s+([^\W\d]\w*)(\()?', phys[0][1])
            if m:
                toks = []
                for (ln, s) in phys:
                    s = s.rstrip()
                    if s.endswith('\\'):
                        s = s[:-1]
                    toks += tokenize(s, fname, ln)
                toks = toks[3:]
                params = None
                if m.group(2) and toks and toks[0].t == '(':
                    d, k = 0, 0
                    for k, t in enumerate(toks):
                        d += 1 if t.t == '(' else -1 if t.t == ')' else 0
                        if d == 0:
                            break
                    params = [t.t for t in toks[1:k] if t.k == 'id']
                    toks = toks[k + 1:]
                macros[m.group(1)] = (params, toks, fname, phys[0][0])
            i = j + 1
            continue
        i += 1
    return '\n'.join(code), macros


def match_close(toks, i):
    o = toks[i].t
    c = {'(': ')', '[': ']', '{': '}'}[o]
    d, j = 0, i
    while j < len(toks):
        if toks[j].t == o:
            d += 1
        elif toks[j].t == c:
            d -= 1
            if d == 0:
                return j
        j += 1
    return len(toks) - 1


def find_functions(toks):
    """Every function defined with a body: name -> (params, body tokens, return-type text, file, line)."""
    funcs, i, n = {}, 0, len(toks)
    while i < n:
        t = toks[i]
        if t.k == 'id' and i + 1 < n and toks[i + 1].t == '(' and i > 0 and (toks[i - 1].k == 'id' or toks[i - 1].t in ('*', '&', '>')):
            j = match_close(toks, i + 1)
            k = j + 1
            while k < n and toks[k].t in ('const', 'noexcept'):
                k += 1
            if k < n and toks[k].t == '{' and toks[i - 1].t not in ('return', 'else', 'new', 'case'):
                e = match_close(toks, k)
                params, cur = [], []
                for x in toks[i + 2:j] + [Tok('op', ',', '', 0)]:
                    if x.t == ',' and not [y for y in cur if y.t in ('(', '<')]:
                        names = [y.t for y in cur]
                        ids = [y.t for y in (cur[:names.index('=')] if '=' in names else cur) if y.k == 'id']
                        if ids and ids[-1] != 'void':
                            params.append(ids[-1])
                        cur = []
                    else:
                        cur.append(x)
                b = i - 1
                while b >= 0 and toks[b].t not in (';', '}', '{', ')'):
                    b -= 1
                funcs.setdefault(t.t, (params, toks[k + 1:e], ' '.join(x.t for x in toks[b + 1:i]), t.f, t.l))
                i = e + 1
                continue
        i += 1
    return funcs


def group(toks):
    """Nest a token list by its brackets: a group is ('G', '(' | '[' | '{', [items], open token)."""
    stack, cur = [], []
    pairs = {')': '(', ']': '[', '}': '{'}
    for t in toks:
        if t.t in ('(', '[', '{'):
            stack.append((t, cur))
            cur = []
        elif t.t in pairs:
            if not stack:
                continue
            o, prev = stack.pop()
            prev.append(('G', o.t, cur, o))
            cur = prev
        else:
            cur.append(t)
    while stack:
        o, prev = stack.pop()
        prev.append(('G', o.t, cur, o))
        cur = prev
    return cur


def is_group(x, kind=None):
    return isinstance(x, tuple) and x[0] == 'G' and (kind is None or x[1] == kind)


def flat(items):
    out = []
    for x in items:
        if is_group(x):
            o = x[3]
            out.append(o)
            out += flat(x[2])
            out.append(Tok('op', {'(': ')', '[': ']', '{': '}'}[x[1]], o.f, o.l))
        else:
            out.append(x)
    return out


def text(items):
    s = ''
    for t in flat(items):
        if s and (t.k in ('id', 'num', 'str', 'chr') and (s[-1].isalnum() or s[-1] in '_"\'')):
            s += ' '
        elif s and t.t not in ('(', ')', '[', ']', ',', '.', '->') and s[-1] not in ('(', '[', '.', '!', '~') and t.t != ';':
            s += ' '
        s += t.t
    return s


def split_commas(items):
    out, cur = [], []
    for x in items:
        if not is_group(x) and x.t == ',':
            out.append(cur)
            cur = []
        else:
            cur.append(x)
    out.append(cur)
    return out


def substitute(toks, params, args):
    if not params:
        return list(toks)
    sub = dict(zip(params, args))
    out = []
    for t in toks:
        if t.k == 'id' and t.t in sub:
            out += flat(sub[t.t])
        else:
            out.append(t)
    return out


def local_bindings(items):
    """name -> initializer tokens for every `T name = expr` / `name = expr` statement in a body (the first assignment wins)."""
    toks, out = flat(items), {}
    for i, t in enumerate(toks):
        if t.k != 'id' or i + 1 >= len(toks) or toks[i + 1].t != '=' or t.t in out:
            continue
        p = toks[i - 1].t if i > 0 else ';'
        if p not in (';', '{', '}', ',', ')', '*') and not (toks[i - 1].k == 'id' and (toks[i - 1].t in TYPE_WORDS or toks[i - 1].t.endswith('_t') or toks[i - 1].t == 'auto')):
            continue
        j, d = i + 2, 0
        while j < len(toks):
            x = toks[j].t
            if x in ('(', '[', '{'):
                d += 1
            elif x in (')', ']', '}'):
                if d == 0:
                    break
                d -= 1
            elif d == 0 and x in (';', ','):
                break
            j += 1
        out[t.t] = toks[i + 2:j]
    return out


class World(object):
    def __init__(self):
        self.macros, self.funcs, self.files, self.local_macros, self.cfuncs = {}, {}, {}, {}, {}
        hdrs = sorted(glob.glob(os.path.join(X86_DIR, '*.h'))) + sorted(glob.glob(os.path.join(X86_DIR, 'x86_*.cpp'))) + sorted(glob.glob(os.path.join(TPL_DIR, '*.h')))
        cpps = sorted(glob.glob(os.path.join(TPL_DIR, '*.cpp')))
        if not cpps or not os.path.isfile(os.path.join(X86_DIR, 'x86_asm.cpp')) or not os.path.isfile(EMIT):
            raise Refuse('no templates under %s, or no x86_asm.cpp or emit.cpp' % TPL_DIR)
        for p in hdrs + cpps:
            rel = os.path.relpath(p, SC)
            src = open(p, encoding='utf-8', errors='replace').read()
            self.files[rel] = src.split('\n')
            code, macros = split_preprocessor(src, rel)
            fs = find_functions(tokenize(code, rel))
            if p.endswith('.cpp') and os.path.dirname(p) != X86_DIR:
                self.local_macros[rel] = macros
                for name, f in fs.items():
                    self.funcs.setdefault(name if name.startswith('bb_') and 'std :: string' in f[2] else rel + '::' + name, f)
            else:
                self.macros.update(macros)
                for name, f in fs.items():
                    self.funcs.setdefault(name, f)
        for p in sorted(glob.glob(os.path.join(EMIT_DIR, '*.cpp'))):
            rel = os.path.relpath(p, SC)
            code, _ = split_preprocessor(open(p, encoding='utf-8', errors='replace').read(), rel)
            for name, f in find_functions(tokenize(code, rel)).items():
                self.cfuncs.setdefault(name, f)
        self.templates = sorted(k for k, f in self.funcs.items() if k.startswith('bb_') and f[3].startswith('src/templates/bb/') and f[3].endswith('.cpp'))
        self.forms = set(BASE_FORMS)
        changed = True
        while changed:
            changed = False
            for name, f in list(self.funcs.items()):
                short = name.split('::')[-1]
                if short in self.forms or 'char' not in f[2] or '*' not in f[2]:
                    continue
                s = ' '.join(t.t for t in f[1])
                if re.search(r'\bx86_zop\b|\bRD[QD] \( "rbp"', s) or any(t.k == 'id' and t.t in self.forms for t in f[1]):
                    self.forms.add(short)
                    changed = True

        self.memo_interest = {}

    def interest(self, name, fname, seen=None):
        """(touches, calls): whether a helper's body, its callees followed, carries a frame form, a port or a PAIR label; whether it emits a call."""
        key = (name, fname)
        if key in self.memo_interest:
            return self.memo_interest[key]
        seen = seen if seen is not None else set()
        if key in seen:
            return (False, False)
        seen.add(key)
        mac = self.lookup_macro(name, fname)
        f = None if mac else self.lookup_func(name, fname)
        if mac:
            body, bf = mac[1], mac[2]
        elif f:
            body, bf = f[1], f[3]
        else:
            return (False, False)
        touches = calls = False
        for i, t in enumerate(body):
            if t.k != 'id':
                continue
            nx = body[i + 1].t if i + 1 < len(body) else ''
            nx2 = body[i + 2].t if i + 2 < len(body) else ''
            if t.t in self.forms or t.t in ('x86_alpha', 'x86_beta', 'x86_beta_trampoline', 'x86_deflabel', 'PAIR') or (t.t in ('RDQ', 'RDD') and nx2 == '"rbp"'):
                touches = True
            elif t.t == 'x86' and nx == '(' and nx2 == '"call"':
                calls = True
            elif nx == '(' and t.t not in PRIMITIVE and (self.lookup_macro(t.t, bf) or self.lookup_func(t.t, bf)):
                a, b = self.interest(t.t, bf, seen)
                touches, calls = touches or a, calls or b
            if touches and calls:
                break
        self.memo_interest[key] = (touches, calls)
        return touches, calls

    def lookup_func(self, name, fname):
        return self.funcs.get(fname + '::' + name) or self.funcs.get(name)

    def lookup_any(self, name, fname):
        return self.lookup_func(name, fname) or self.cfuncs.get(name)

    def lookup_macro(self, name, fname):
        return self.local_macros.get(fname, {}).get(name) or self.macros.get(name)


def expand_macros(world, items, fname, depth=0):
    """Expand macro uses in a token list (not std::string helpers): an operand's or a condition's text."""
    toks, out, i = flat(items), [], 0
    while i < len(toks):
        t = toks[i]
        mac = world.lookup_macro(t.t, fname) if t.k == 'id' and t.t != '_' and depth < MAX_DEPTH else None
        if mac and t.t not in PRIMITIVE:
            params, body, mf, ml = mac
            if params is None:
                out += expand_macros(world, body, mf, depth + 1)
                i += 1
                continue
            if i + 1 < len(toks) and toks[i + 1].t == '(':
                j = match_close(toks, i + 1)
                out += expand_macros(world, substitute(body, params, split_commas(group(toks[i + 2:j]))), mf, depth + 1)
                i = j + 1
                continue
        out.append(t)
        i += 1
    return out


class Val(object):
    """A symbolic offset: base 'result' (the box's result cell), 'own:<fn>' (another block the box owns), 'self' (the box's node),
    'node' (another node), 'other' (another box's cell or a field), 'const', or None (cannot say); disp the known displacement or None."""
    __slots__ = ('base', 'disp')

    def __init__(self, base, disp=None):
        self.base, self.disp = base, disp


BLOCK = lambda v: v.base == 'result' or (v.base or '').startswith('own:')


class Ev(object):
    """Resolve an offset expression to a Val: locals through their initializers, calls through the emitter's and templates' bodies."""
    def __init__(self, world, fname, envs, depth):
        self.w, self.fname, self.envs, self.depth = world, fname, envs, depth

    def run(self, toks):
        self.t, self.i = [t for t in toks if t.t != ';'], 0
        if not self.t or self.depth > MAX_DEPTH:
            return Val(None)
        try:
            return self.ternary()
        except (IndexError, ValueError, KeyError):
            return Val(None)

    def peek(self):
        return self.t[self.i].t if self.i < len(self.t) else None

    def ternary(self):
        c = self.binary(1)
        if self.peek() != '?':
            return c
        self.i += 1
        a = self.ternary()
        if self.peek() == ':':
            self.i += 1
        b = self.ternary()
        if a.base == 'const' and b.base != 'const':
            return b
        if b.base == 'const' and a.base != 'const':
            return a
        if a.base == b.base:
            return Val(a.base, a.disp if a.disp == b.disp else None)
        return a if BLOCK(a) else b if BLOCK(b) else Val(None)

    def binary(self, minp):
        lhs = self.unary()
        while True:
            op = self.peek()
            p = BINPREC.get(op)
            if p is None or p < minp:
                return lhs
            self.i += 1
            rhs = self.binary(p + 1)
            lhs = self.combine(op, lhs, rhs)

    def combine(self, op, a, b):
        if a.base == 'const' and b.base == 'const':
            if a.disp is None or b.disp is None:
                return Val('const')
            try:
                return Val('const', int({'+': a.disp + b.disp, '-': a.disp - b.disp, '*': a.disp * b.disp, '/': a.disp // b.disp if b.disp else 0,
                                         '<<': a.disp << b.disp, '>>': a.disp >> b.disp}.get(op, 0)))
            except (ValueError, OverflowError):
                return Val('const')
        if op in ('+', '-'):
            if BLOCK(a) or a.base in ('other', 'node'):
                return Val(a.base, a.disp + (b.disp if op == '+' else -b.disp) if (a.disp is not None and b.base == 'const' and b.disp is not None) else None)
            if op == '+' and (BLOCK(b) or b.base in ('other', 'node')):
                return Val(b.base, b.disp + a.disp if (b.disp is not None and a.base == 'const' and a.disp is not None) else None)
        return Val('const') if op in ('==', '!=', '<', '>', '<=', '>=', '&&', '||') else Val(None)

    def unary(self):
        op = self.peek()
        if op in ('-', '+', '!', '~', '*', '&'):
            self.i += 1
            v = self.unary()
            if op == '-' and v.base == 'const':
                return Val('const', -v.disp if v.disp is not None else None)
            return v if op in ('+', '*', '&') else Val('const')
        if op == '(':
            j = match_close(self.t, self.i)
            inner = self.t[self.i + 1:j]
            if inner and all(x.k == 'id' or x.t in ('*', '::', '<', '>') for x in inner) and (inner[0].t in TYPE_WORDS or inner[0].t.endswith('_t') or inner[0].t == 'std'):
                self.i = j + 1
                return self.unary()
            self.i = j + 1
            return self.postfix(Ev(self.w, self.fname, self.envs, self.depth + 1).run(inner))
        return self.postfix(self.primary())

    def postfix(self, v):
        while self.peek() in ('[', '->', '.'):
            if self.peek() == '[':
                self.i = match_close(self.t, self.i) + 1
                v = Val('node') if v.base in ('self', 'node') else Val('other')
            else:
                self.i += 2
                v = Val('node') if v.base in ('self', 'node') else Val('other')
        return v

    def primary(self):
        t = self.t[self.i]
        self.i += 1
        if t.k == 'num':
            try:
                return Val('const', int(re.sub(r'[uUlL]+$', '', t.t), 0))
            except ValueError:
                return Val('const')
        if t.k == 'chr':
            return Val('const')
        if t.k != 'id':
            return Val(None)
        if t.t in ('_', 'g_emit') and self.peek() == '.' and self.i + 1 < len(self.t):
            f = self.t[self.i + 1].t
            self.i += 2
            if f == 'op_off':
                return Val('result', 0)
            if f == 'node':
                return Val('self')
            return Val('other')
        if self.peek() == '(':
            j = match_close(self.t, self.i)
            args = split_commas(group(self.t[self.i + 1:j]))
            self.i = j + 1
            return self.call(t.t, args)
        if t.t in ('true', 'false', 'nullptr', 'NULL', 'sizeof'):
            return Val('const')
        for env in reversed(self.envs):
            if t.t in env:
                toks, fname, envs = env[t.t]
                return Ev(self.w, fname, envs, self.depth + 1).run(toks)
        mac = self.w.lookup_macro(t.t, self.fname)
        if mac and mac[0] is None:
            return Ev(self.w, mac[2], self.envs, self.depth + 1).run(mac[1])
        return Val(None)

    def call(self, name, args):
        if name in RESULT_FNS or re.match(r'zls_\w+_off$|rk_frame_block_off$', name):
            a = Ev(self.w, self.fname, self.envs, self.depth + 1).run(flat(args[0])) if args and args[0] else Val(None)
            if a.base != 'self':
                return Val('other')
            return Val('result', 0) if name in RESULT_FNS else Val('own:' + name, 0)
        if name == 'ir_call_arg':
            return Val('node')
        mac = self.w.lookup_macro(name, self.fname)
        if mac and mac[0] is not None:
            return Ev(self.w, mac[2], self.envs, self.depth + 1).run(substitute(mac[1], mac[0], args))
        f = self.w.lookup_any(name, self.fname)
        if not f or self.depth > MAX_DEPTH:
            return Val(None)
        params, body, ret, ff, fl = f
        frame = {}
        for k, p in enumerate(params):
            if k < len(args):
                frame[p] = (flat(args[k]), self.fname, self.envs)
        envs = [frame]
        loc = local_bindings(body)
        lframe = {}
        envs.append(lframe)
        for n, tk in loc.items():
            lframe[n] = (tk, ff, envs)
        best = None
        toks = flat(body)
        for i, x in enumerate(toks):
            if x.t != 'return':
                continue
            j = i + 1
            d = 0
            while j < len(toks) and not (d == 0 and toks[j].t == ';'):
                d += 1 if toks[j].t in ('(', '[', '{') else -1 if toks[j].t in (')', ']', '}') else 0
                j += 1
            v = Ev(self.w, ff, envs, self.depth + 1).run(toks[i + 1:j])
            if v.base not in (None, 'const'):
                return v
            best = best or v
        return best or Val(None)


class Cond(object):
    """Evaluate a C condition under the arm's integer constants: True, False, or None when it does not reduce."""
    def __init__(self, consts):
        self.consts = consts

    def eval(self, items, world, fname):
        toks = expand_macros(world, items, fname)
        py, i = [], 0
        while i < len(toks):
            t = toks[i]
            if t.t in ('_', 'g_emit') and i + 2 < len(toks) and toks[i + 1].t == '.' and toks[i + 2].k == 'id':
                v = self.consts.get(toks[i + 2].t)
                if v is None:
                    return None
                py.append(str(v))
                i += 3
                continue
            if t.k == 'num':
                py.append(re.sub(r'[uUlL]+$', '', t.t))
            elif t.t in ('&&', '||', '!'):
                py.append({'&&': ' and ', '||': ' or ', '!': ' not '}[t.t])
            elif t.t in ('==', '!=', '<', '>', '<=', '>=', '(', ')', '+', '-', '*', '&', '|', '^', '~'):
                py.append(t.t)
            elif t.t in ('true', 'false'):
                py.append('True' if t.t == 'true' else 'False')
            else:
                return None
            i += 1
        try:
            return bool(eval(' '.join(py), {'__builtins__': {}}, {}))
        except Exception:
            return None


class Scan(object):
    """One kind's walk over its templates in emission order: ports, frame accesses, the classes they imply."""
    def __init__(self, world, kind, consts, owner, producer, all_rows):
        self.w, self.kind, self.cond, self.owner, self.producer, self.all_rows = world, kind, Cond(consts), owner, producer, all_rows
        self.port, self.regs, self.code_regs = 'alpha', {}, set()
        self.rows, self.stack, self.active, self.envs = [], [], set(), []
        self.pending, self.late_blocks, self.guards = [], set(), []

    def where(self, tok):
        tpl = [s for s in self.stack if s[0].startswith('src/templates/bb/') and s[0].endswith('.cpp')]
        here = (tok.f, tok.l)
        cite = here if (here[0].startswith('src/templates/bb/') and here[0].endswith('.cpp')) else (tpl[-1] if tpl else here)
        return cite, ('-' if here == cite else '%s:%d' % here), (' && '.join(self.guards) or '-')

    def emit_row(self, tok, cls, word, how, port=None, where=None):
        cite, via, when = where or self.where(tok)
        self.rows.append({'kind': self.kind, 'class': cls, 'port': port or self.port, 'template': cite[0], 'line': cite[1], 'via': via, 'word': word, 'how': how, 'when': when})

    def guard(self, items, fname, negate):
        g = re.sub(r'\s+', ' ', text(expand_macros(self.w, items, fname))).strip()
        g = g if len(g) <= 60 else g[:57] + '...'
        self.guards.append(('!(%s)' % g) if negate else g)

    def form_of(self, items, fname):
        """The frame form an operand carries: (form, word text, cell, block) or None; cell is operand-cell | state | operand-word | other."""
        toks = expand_macros(self.w, items, fname)
        for i, t in enumerate(toks):
            if t.k != 'id' or i + 1 >= len(toks) or toks[i + 1].t != '(':
                continue
            j = match_close(toks, i + 1)
            args = split_commas(group(toks[i + 2:j]))
            word = text(toks[i:j + 1])
            if t.t in ('RDQ', 'RDD'):
                if not args or text(args[0]) != '"rbp"':
                    continue
                off = args[1] if len(args) > 1 else []
            elif t.t in self.w.forms:
                off = args[0] if args else []
            else:
                continue
            if t.t in OPERAND_CELL_FORMS:
                return (t.t, word, 'operand-cell', None)
            v = Ev(self.w, fname, self.envs, 0).run(flat(off))
            if not BLOCK(v):
                return (t.t, word, 'other', None)
            if self.owner == 'operand' and v.base == 'result':
                return (t.t, word, 'operand-word', 'operand-word')
            if v.base == 'result':
                if self.producer and v.disp in (0, 8):
                    return (t.t, word, 'operand-cell', None)
                return (t.t, word, 'state', 'result')
            return (t.t, word, 'state', v.base)
        return None

    def carries_form(self, items, fname):
        for t in flat(items):
            if t.k == 'id' and (t.t in self.w.forms or t.t in ('RDQ', 'RDD')):
                return True
            mac = self.w.lookup_macro(t.t, fname) if t.k == 'id' and t.t != '_' else None
            if mac and any(x.k == 'id' and (x.t in self.w.forms or x.t in ('RDQ', 'RDD')) for x in mac[1]):
                return True
        return False

    def access(self, tok, mnem, ops, fname):
        m = mnem.strip('"')
        if m in NO_ACCESS or (m.startswith('j') and m != 'jmp'):
            return
        forms = [self.form_of(o, fname) for o in ops]
        dst = text(expand_macros(self.w, ops[0], fname)).strip('"') if ops else ''
        for f in forms:
            if f and f[3] and self.port in ('beta', 'reentry'):
                self.late_blocks.add(f[3])
        if m == 'lea' and len(ops) > 1:
            f = forms[1]
            self.regs.pop(dst, None)
            self.code_regs.discard(dst)
            if f and f[2] in ('state', 'operand-word'):
                if dst in PINNED:
                    self.emit_row(tok, 'address-escapes', f[1], 'lea %s, %s -- %s' % (dst, f[1], PINNED[dst]))
                else:
                    self.regs[dst] = (f, tok, self.where(tok), self.port)
            elif re.search(r'\bL\s*\(|\bPAIR\s*\(|extlbl', text(ops[1])):
                self.code_regs.add(dst)
            return
        if m == 'call':
            f = forms[0] if forms else None
            if f and f[2] != 'other':
                self.emit_row(tok, 'continuation', f[1], 'call through %s' % f[1])
            callee = text(ops[0]).strip('"') if ops else '?'
            for r in ARG_REGS:
                if r in self.regs:
                    f, lt, wh, pt = self.regs[r]
                    self.pending.append((lt, f, wh, pt, 'lea %s, %s; call %s' % (r, f[1], callee)))
            self.regs = {}
            return
        if m == 'jmp':
            f = forms[0] if forms else None
            if f and f[2] != 'other':
                self.emit_row(tok, 'continuation', f[1], 'jmp through %s' % f[1])
            return
        for k, f in enumerate(forms):
            if not f:
                continue
            write = k == 0 and m not in READ_ONLY
            read = not (k == 0 and (m in WRITE_ONLY or m.startswith('set')))
            if write and len(ops) > 1 and text(ops[1]).strip('"') in self.code_regs and f[2] in ('state', 'operand-word'):
                self.emit_row(tok, 'continuation', f[1], 'a code address stored into %s' % f[1])
            if not read:
                if self.all_rows:
                    self.emit_row(tok, '-', f[1], 'write (%s)' % f[2])
                continue
            if f[2] == 'operand-word':
                self.emit_row(tok, 'beta-read', f[1], "a read of the word the arm points op_off at -- another box's, written at its alpha, read after its child ran")
            elif f[2] == 'state' and self.port in ('beta', 'reentry'):
                self.emit_row(tok, 'beta-read', f[1], '%s %s at %s' % (m, f[1], self.port))
            elif self.all_rows:
                self.emit_row(tok, '-', f[1], 'read (%s) at %s' % (f[2], self.port))
        if dst in self.regs and m not in READ_ONLY:
            del self.regs[dst]
        if dst in self.code_regs and m not in READ_ONLY:
            self.code_regs.discard(dst)
        if m.startswith('mov') and len(ops) > 1:
            s = text(ops[1]).strip('"')
            if s in self.regs and (forms[0] or re.search(r'\bRD[QD]\s*\(|\bptr\b|\[', text(ops[0]))):
                f, lt, wh, pt = self.regs[s]
                self.emit_row(lt, 'address-escapes', f[1], 'lea %s, %s; mov %s, %s -- the address is stored to memory' % (s, f[1], text(ops[0]), s), port=pt, where=wh)
            elif s in self.regs and dst in ARG_REGS:
                self.regs[dst] = self.regs[s]
            if s in self.code_regs:
                self.code_regs.add(dst)

    def settle(self):
        """A lea before a call escapes when the template touches the same block after alpha (the leaf's work spans the box's life); else argv."""
        for (lt, f, wh, pt, how) in self.pending:
            if f[3] in self.late_blocks:
                self.emit_row(lt, 'address-escapes', f[1], how, port=pt, where=wh)
            elif self.all_rows:
                self.emit_row(lt, '-', f[1], how + ' -- argv: the block is touched at alpha only', port=pt, where=wh)

    def walk_expr(self, items, fname):
        """One expression at one nesting level: a ?: splits it, else its items run in order."""
        q = next((k for k, x in enumerate(items) if not is_group(x) and x.t == '?'), None)
        if q is None:
            self.walk_seq(items, fname)
            return
        depth, c = 0, None
        for k in range(q + 1, len(items)):
            x = items[k]
            if is_group(x):
                continue
            if x.t == '?':
                depth += 1
            elif x.t == ':':
                if depth == 0:
                    c = k
                    break
                depth -= 1
        start = 0
        for k in range(q - 1, -1, -1):
            x = items[k]
            if not is_group(x) and (x.t in ('return', '<<', ':') or (x.t.endswith('=') and x.t not in ('==', '!=', '<=', '>='))):
                start = k + 1
                break
        self.walk_seq(items[:start], fname)
        v = self.cond.eval(items[start:q], self.w, fname)
        if c is None:
            self.walk_seq(items[q + 1:], fname)
            return
        if v is not False:
            if v is None:
                self.guard(items[start:q], fname, False)
            self.walk_expr(items[q + 1:c], fname)
            if v is None:
                self.guards.pop()
        if v is not True:
            if v is None:
                self.guard(items[start:q], fname, True)
            self.walk_expr(items[c + 1:], fname)
            if v is None:
                self.guards.pop()

    def walk_seq(self, items, fname):
        i = 0
        while i < len(items):
            x = items[i]
            if is_group(x):
                if x[1] == '{':
                    self.walk_block(x[2], fname)
                else:
                    for part in split_commas(x[2]):
                        self.walk_expr(part, fname)
                i += 1
                continue
            nxt = items[i + 1] if i + 1 < len(items) else None
            if x.k == 'id' and x.t == 'if' and is_group(nxt, '('):
                v = self.cond.eval(nxt[2], self.w, fname)
                body_end = i + 3 if i + 2 < len(items) and is_group(items[i + 2], '{') else len(items)
                if v is not False:
                    if v is None:
                        self.guard(nxt[2], fname, False)
                    self.walk_seq(items[i + 2:body_end], fname)
                    if v is None:
                        self.guards.pop()
                i = body_end
                if i < len(items) and not is_group(items[i]) and items[i].t == 'else':
                    if v is not True:
                        if v is None:
                            self.guard(nxt[2], fname, True)
                        self.walk_seq(items[i + 1:], fname)
                        if v is None:
                            self.guards.pop()
                    return
                continue
            if x.k == 'id' and is_group(nxt, '('):
                self.call(x, nxt, fname)
                i += 2
                continue
            mac = self.w.lookup_macro(x.t, fname) if x.k == 'id' else None
            if mac and mac[0] is None and x.t != '_':
                self.expand_macro(x, None, fname)
            i += 1

    def walk_block(self, items, fname):
        frame = {}
        env = self.envs + [frame]
        for n, tk in local_bindings(items).items():
            frame[n] = (tk, fname, env)
        self.envs.append(frame)
        stmt = []
        for x in items:
            stmt.append(x)
            if (not is_group(x) and x.t == ';') or is_group(x, '{'):
                self.walk_expr([y for y in stmt if is_group(y) or y.t != ';'], fname)
                stmt = []
        if stmt:
            self.walk_expr(stmt, fname)
        self.envs.pop()

    def expand_macro(self, tok, grp, fname):
        mac = self.w.lookup_macro(tok.t, fname)
        if not mac or len(self.stack) > MAX_DEPTH or ('M', tok.t) in self.active:
            return False
        params, body, mf, ml = mac
        self.stack.append((tok.f, tok.l))
        self.active.add(('M', tok.t))
        self.walk_expr(group(substitute(body, params, split_commas(grp[2]) if grp is not None else [])), mf)
        self.active.discard(('M', tok.t))
        self.stack.pop()
        return True

    def call(self, tok, grp, fname):
        name = tok.t
        args = split_commas(grp[2])
        if name == 'x86_alpha':
            self.port, self.regs = 'alpha', {}
            return
        if name in ('x86_beta', 'x86_beta_trampoline') or (name == 'x86_deflabel' and 'X86P_BETA' in text(grp[2])):
            self.port, self.regs = 'beta', {}
            return
        if name == 'IF':
            v = self.cond.eval(args[0], self.w, fname) if len(args) >= 2 else False
            if v is not False:
                if v is None:
                    self.guard(args[0], fname, False)
                for a in args[1:]:
                    self.walk_expr(a, fname)
                if v is None:
                    self.guards.pop()
            return
        if name == 'x86':
            mnem = text(args[0]) if args else ''
            if mnem == '"def"' and len(args) > 1 and re.match(r'PAIR\b', text(args[1])):
                self.port, self.regs = 'reentry', {}
                return
            self.access(tok, mnem, args[1:], fname)
            return
        if name in PRIMITIVE or name in self.w.forms:
            for a in args:
                self.walk_expr(a, fname)
            return
        if (self.w.lookup_macro(name, fname) or self.w.lookup_func(name, fname)) and not name.startswith('bb_'):
            touches, calls = self.w.interest(name, fname)
            if not touches and not any(self.carries_form(a, fname) for a in args):
                if calls:
                    for r in ARG_REGS:
                        if r in self.regs:
                            f, lt, wh, pt = self.regs[r]
                            self.pending.append((lt, f, wh, pt, 'lea %s, %s; %s (a call)' % (r, f[1], name)))
                    self.regs = {}
                return
        mac = self.w.lookup_macro(name, fname)
        if mac and mac[0] is not None and self.expand_macro(tok, grp, fname):
            return
        f = self.w.lookup_func(name, fname)
        if f and ('string' in f[2] or name.startswith('bb_')) and ('F', name) not in self.active and len(self.stack) <= MAX_DEPTH:
            params, body, _, ff, fl = f
            self.stack.append((tok.f, tok.l))
            self.active.add(('F', name))
            saved = self.envs
            self.envs = []
            self.walk_block(group(substitute(body, params, args)), ff)
            self.envs = saved
            self.active.discard(('F', name))
            self.stack.pop()
            return
        for a in args:
            self.walk_expr(a, fname)

    def run(self, template):
        f = self.w.funcs[template]
        self.port, self.regs = 'alpha', {}
        self.stack.append((f[3], f[4]))
        self.active.add(('F', template))
        self.walk_block(group(f[1]), f[3])
        self.active.discard(('F', template))
        self.stack.pop()


def kind_predicate(name, srcs, order, seen=None):
    """The IR kinds a src/ir predicate admits: `t == IR_A`, `t >= IR_A && t <= IR_B` over the IR_e order, and its ir_* callees on t."""
    seen = seen if seen is not None else set()
    if name in seen:
        return set()
    seen.add(name)
    for s in srcs:
        m = re.search(r'\bint ' + name + r'\s*\(\s*IR_e (\w+)\s*\)\s*\{(.*?)\n?\}', s, re.S)
        if m:
            v, body = m.group(1), m.group(2)
            kinds = set(re.findall(r'\b%s == (IR_\w+)' % v, body))
            for lo, hi in re.findall(r'\b%s >= (IR_\w+) && %s <= (IR_\w+)' % (v, v), body):
                if lo not in order or hi not in order:
                    raise Refuse('%s ranges over %s..%s, not both in IR_e' % (name, lo, hi))
                kinds |= set(order[order.index(lo):order.index(hi) + 1])
            for c in re.findall(r'\b(ir_\w+)\s*\(\s*%s\s*\)' % v, body):
                kinds |= kind_predicate(c, srcs, order, seen)
            return kinds
    raise Refuse('no body for %s under src/ir' % name)


def value_producers():
    paths = sorted(glob.glob(os.path.join(IR_DIR, '*.[ch]')))
    srcs = [open(p, encoding='utf-8', errors='replace').read() for p in paths]
    hdr = open(os.path.join(IR_DIR, 'IR.h'), encoding='utf-8', errors='replace').read()
    m = re.search(r'typedef enum\s*\{(.*?)\}\s*IR_e\s*;', hdr, re.S)
    if not m:
        raise Refuse('no IR_e enum in src/ir/IR.h')
    order = re.findall(r'\b(IR_\w+)\b', m.group(1))
    return kind_predicate('ir_node_produces_value', srcs, order)


def dispatch(world):
    """kind -> (templates it reaches, the integer constants its arm sets, whose word op_off names); an arm ends at the next case or column-0 line."""
    code, _ = split_preprocessor(open(EMIT, encoding='utf-8', errors='replace').read(), 'src/emitter/emit.cpp')
    labels = [(m.start(), m.end(), m.group(1)) for m in re.finditer(r'\bcase (IR_[A-Z0-9_]+)\s*:', code)]
    tset = set(world.templates)
    out, pending = {}, []
    for i, (s, e, k) in enumerate(labels):
        pending.append(k)
        nxt = labels[i + 1][0] if i + 1 < len(labels) else len(code)
        top = re.search(r'\n(?=\S)', code[e:nxt])
        arm = code[e:e + top.start()] if top else code[e:nxt]
        if not arm.strip():
            continue
        ks, pending = pending, []
        names = []
        for n in re.findall(r'\b(bb_\w+)\b', arm):
            if n in tset and n not in names:
                names.append(n)
        if not names:
            continue
        consts = dict((m.group(1), int(m.group(2))) for m in re.finditer(r'g_emit\.(op_\w+)\s*=\s*(-?\d+)\s*;', arm))
        owner = 'own'
        m = re.search(r'g_emit\.op_off\s*=\s*([^;]*);', arm)
        if m:
            others = [a for a in re.findall(r'\(\s*([^()]*?)\s*\)', m.group(1)) if a and a != 'nd' and not re.match(r'(int|long|IR_t\s*\*)$', a)]
            if others:
                owner = 'operand'
        for k in ks:
            cur = out.setdefault(k, ([], {}, owner))
            for n in names:
                if n not in cur[0]:
                    cur[0].append(n)
            for a, v in consts.items():
                cur[1].setdefault(a, v)
    return out


def derive(world, kinds=None, all_rows=False):
    prod = value_producers()
    disp = dispatch(world)
    rows, summary, memo = [], {}, {}
    for kind in sorted(disp):
        if kinds and kind not in kinds:
            continue
        tpls, consts, owner = disp[kind]
        sig = (tuple(tpls), tuple(sorted(consts.items())), owner, kind in prod)
        if sig not in memo:
            sc = Scan(world, '-', consts, owner, kind in prod, all_rows)
            for t in tpls:
                sc.run(t)
            sc.settle()
            memo[sig] = sc.rows
        seen, krows = set(), []
        for r in [dict(r, kind=kind) for r in memo[sig]]:
            key = (r['class'], r['template'], r['line'], r['via'], r['word'], r['port'], r['how'], r['when'])
            if key not in seen:
                seen.add(key)
                krows.append(r)
        rows += krows
        summary[kind] = (tpls, owner, kind in prod, [r for r in krows if r['class'] in CLASSES])
    return rows, summary


def proof_rows(world, summary):
    """One row per kind with a state word: its first class in CLASSES order, cited by the template line that carries it."""
    out = []
    for kind in sorted(summary):
        rs = summary[kind][3]
        for cls in CLASSES:
            hit = sorted((r for r in rs if r['class'] == cls), key=lambda r: (r['template'], r['line']))
            if hit:
                r = hit[0]
                pat = re.sub(r'^[\s+]*', '', world.files[r['template']][r['line'] - 1]).rstrip()
                out.append((kind, cls, r['template'], pat, r['line'], r['port'], r['via'], r['when']))
                break
    return out


TSV_HEAD = """# state_word_kinds.tsv -- THE DECLARED STATE WORDS (ARCH-ZETA-ONE-COORDINATE section 3.1; the cto under CEO-1885/1888, 2026-10-22).
# GENERATED: `python3 harness/scripts/util_template_state_words.py --write` writes this file from the templates; --check refuses it when it drifts.
# One row per box kind whose template keeps a frame word beyond its operand cell: key<TAB>class<TAB>template<TAB>pattern<TAB>line<TAB>port<TAB>via<TAB>when
#   key       the IR kind as --dump-homes prints it
#   class     address-escapes | beta-read | continuation: the first the kind's template implies, in that order (the xfwhy= the dump prints for it)
#   template  the file under SCRIP whose line proves it (src/templates/bb/bb_xxx.cpp)
#   pattern   that line's text; util_bb_placement_census.py REFUSES rc 2 a row whose template no longer carries it
#   line      the template line carrying the pattern; util_template_state_words.py --check refuses a row whose cited line no longer does
#   port      alpha | beta | reentry (a PAIR landing: an arm's gamma or omega) -- where the template performs the access
#   via       the helper line the template's call expands to (x86_asm.h, a bb header, a static), or - when the access is on the template line
#   when      the template conditions guarding the access that the emitter arm's constants do not decide (a graph fact such as
#             x86_resumable_frame(), a node field), joined by &&; - when none -- the lowerer's per-node declaration reads them
"""


def write_tsv(rows):
    with open(TSV, 'w', encoding='utf-8') as fh:
        fh.write(TSV_HEAD)
        for r in rows:
            fh.write('\t'.join([r[0], r[1], r[2], r[3], str(r[4]), r[5], r[6], r[7]]) + '\n')


def read_tsv():
    if not os.path.isfile(TSV):
        raise Refuse('no %s' % TSV)
    out = []
    for ln in open(TSV, encoding='utf-8'):
        if not ln.strip() or ln.startswith('#'):
            continue
        f = ln.rstrip('\n').split('\t')
        if len(f) < 4:
            raise Refuse('state_word_kinds.tsv row %r has fewer than four columns' % ln.strip())
        out.append(f)
    return out


def check(world, want):
    bad = 0
    have = read_tsv()
    wk = dict((r[0], r) for r in want)
    hk = {}
    for f in have:
        key = f[0]
        hk[key] = f
        lines = world.files.get(f[2])
        line = f[4] if len(f) > 4 else ''
        if lines is None:
            print('STATE_WORDS_DRIFT %s: cites %s, which is not a template' % (key, f[2]))
            bad += 1
            continue
        if not line.isdigit():
            print('STATE_WORDS_DRIFT %s: cites no line (regenerate with --write)' % key)
            bad += 1
        elif not (1 <= int(line) <= len(lines)) or f[3] not in lines[int(line) - 1]:
            print('STATE_WORDS_DRIFT %s: %s:%s no longer carries %r' % (key, f[2], line, f[3]))
            bad += 1
        w = wk.get(key)
        if w is None:
            print('STATE_WORDS_DRIFT %s: declared %s, and the templates imply no state word for it' % (key, f[1]))
            bad += 1
        elif (w[1], w[2], w[3], str(w[4])) != (f[1], f[2], f[3], line):
            print('STATE_WORDS_DRIFT %s: declared %s at %s:%s, the templates imply %s at %s:%d' % (key, f[1], f[2], line or '?', w[1], w[2], w[4]))
            bad += 1
    for key, w in sorted(wk.items()):
        if key not in hk:
            print('STATE_WORDS_DRIFT %s: the templates imply %s at %s:%d and the table does not declare it' % (key, w[1], w[2], w[4]))
            bad += 1
    print('STATE_WORDS_CHECK rows=%d derived=%d drift=%d' % (len(have), len(want), bad))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('--kind', action='append')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    try:
        if (a.check or a.write) and a.kind:
            raise Refuse('--check and --write read every kind; drop --kind')
        world = World()
        rows, summary = derive(world, set(a.kind) if a.kind else None, a.all)
        want = proof_rows(world, summary)
        if a.check:
            return check(world, want)
        if a.write:
            write_tsv(want)
            print('STATE_WORDS_WRITTEN rows=%d %s' % (len(want), os.path.relpath(TSV, os.path.dirname(SC))))
            return 0
    except (Refuse, OSError) as e:
        print('STATE_WORDS REFUSE: %s' % e)
        return 2
    for r in rows:
        print('STATE_WORD kind=%s class=%s port=%s template=%s:%d via=%s word=%s how=%s when=%s' % (r['kind'], r['class'], r['port'], r['template'], r['line'], r['via'], r['word'], r['how'], r['when']))
    nstate = 0
    for kind in sorted(summary):
        tpls, owner, prod, rs = summary[kind]
        cls = [c for c in CLASSES if any(r['class'] == c for r in rs)]
        nstate += 1 if cls else 0
        print('STATE_WORD_KIND kind=%s classes=%s rows=%d producer=%d op_off=%s templates=%s' % (kind, ','.join(cls) or 'none', len(rs), 1 if prod else 0, owner, ','.join(tpls)))
    print('STATE_WORDS kinds=%d state=%d none=%d rows=%d declared=%d' % (len(summary), nstate, len(summary) - nstate, sum(len(s[3]) for s in summary.values()), len(want)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
