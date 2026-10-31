#!/usr/bin/env python3
# util_header_fanin.py -- THE FAN-IN INSTRUMENT OF THE HEADER SPLIT (ARCH-HEADER-SPLIT.md sections 1 and 2, CEO-2032, step 1a; hq_templates).
#
# Lon, 2026-10-30, in-chat to the ceo: "I want the header files designed properly NOT to cause total re-builds." The cause is umbrella headers, so the
# thing measured is, per header, how many translation units reach it (fanin) against how many of them name anything it declares (users).
#
#   util_header_fanin.py                   one line per header: fanin direct users includes inline_bodies lines path (widest first)
#   util_header_fanin.py --recompiles H    the units a one-line edit to H recompiles (H is a path, or a unique tail of one, under src/)
#   util_header_fanin.py --base            the base set (harness/scripts/header_base_set.tsv) with each header's fanin and users
#   util_header_fanin.py --ceiling         OVER <path> fanin=N users=M per header over the R4 ceiling, UMBRELLA <path> per umbrella, then
#                                          "summary over=N umbrellas=M"
#   util_header_fanin.py --unused          per unit the direct includes none of whose declarations the unit names, then "summary unused=N"
#   util_header_fanin.py --under PATH      with --unused or --bare: only the units under PATH (src/templates), the summary counts those only
#   util_header_fanin.py --bare            per includer the quoted includes written as a bare name for a header in another directory, then
#                                          "summary bare=N"
#   util_header_fanin.py --write-baseline  writes harness/scripts/header_fanin.baseline.tsv; refuses rc 1 when any figure would rise above the
#                                          existing baseline (the baseline is lowered and never raised)
#   util_header_fanin.py --ratchet ARM     ARM is fanin|umbrella|inline|bare|unused|all: prints each figure above the baseline, then
#                                          "arm ARM violations=N" ; rc 1 when N > 0
#
# DEFINITIONS (the page's R4). A unit is a source file (.c .cpp .S) named first in a dependency file (.d) of the built tree; the .d files are
# read from OBJ (default /tmp/si_objs plus the SCRIP root path with / turned into -) and ROOT/out, and a source built two ways counts once with the
# union of its headers. fanin(H) is the number of units whose .d names H, directly or through another header. direct(H) is the number whose own text
# includes H by a quoted name. users(H) is the number of units whose own text, comments and strings removed, names an identifier H declares: a
# macro, a typedef name, a struct, union or enum tag that has a body, an enum member, a function (prototype or definition), a variable; and the
# member path "inst.field" when a header declares "extern T inst" and T has a field of a type H declares (g_runtime.gc names g_runtime_gc.h). The
# include guard is no declaration. A header with two or more includes and no declaration of its own is an UMBRELLA. inline_bodies counts function
# bodies in the header that run over more than one line or hold more than one statement (R3 allows an accessor, a predicate, a tag test).
# The ceiling: fanin(H) <= users(H) + 4, and fanin(H) <= one third of the units for a header outside the base set.
#
# It runs no build. It needs a built tree's .d files and refuses rc 2 with fewer than --min-units of them (default 200).
import argparse, collections, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
HDR_EXT = ('.h', '.hpp', '.inc')
SRC_EXT = ('.c', '.cpp', '.cc', '.S', '.s')
NOT_DECL = {'__attribute__', '__declspec', 'sizeof', 'defined', '__extension__', '_Static_assert', 'static_assert', 'typeof', '__typeof__', 'alignas',
            '_Alignas', '__asm__', 'asm', 'if', 'while', 'for', 'switch', 'return', 'else', 'do', 'void', 'int', 'char', 'long', 'short', 'unsigned', 'signed',
            'float', 'double', 'const', 'volatile', 'static', 'extern', 'inline', 'struct', 'union', 'enum', 'typedef', 'register', '__inline__', '__inline',
            'noexcept', 'operator', 'template', 'class', 'namespace', 'using', 'public', 'private', 'protected', 'auto', 'bool', '_Bool', 'size_t'}
COMMENT = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', re.S)
STRING = re.compile(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'')
INCLUDE = re.compile(r'^[ \t]*#[ \t]*include[ \t]*"([^"\n]+)"', re.M)
WORD = re.compile(r'[A-Za-z_]\w*')
INC_DIRS = ['', 'ir', 'lower', 'emitter', 'runtime/core', 'runtime/builtins', 'runtime', 'runtime/rt', 'parsers/snobol4', 'parsers/raku', 'optimizer',
            'templates/bb', 'templates/xa', 'templates/x86']


def strip_comments(text):
    def sub(m):
        s = m.group(0)
        return s if s[0] in '"\'' else re.sub(r'[^\n]', ' ', s)
    return COMMENT.sub(sub, text)


def strip_strings(text):
    return STRING.sub(lambda m: m.group(0)[0] * 2, text)


def read(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def match_brace(text, i):
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return j
    return len(text) - 1


def preprocess(text):
    """Returns (text without directives, the macro names defined, the guard name)."""
    out, macros, guard, joined = [], [], None, []
    lines = text.split('\n')
    k = 0
    while k < len(lines):
        ln = lines[k]
        if ln.lstrip().startswith('#'):
            full = ln
            while full.rstrip().endswith('\\') and k + 1 < len(lines):
                k += 1
                full = full.rstrip()[:-1] + ' ' + lines[k]
                out.append('')
            m = re.match(r'\s*#\s*ifndef\s+(\w+)', full)
            if m and guard is None and not joined:
                guard = m.group(1)
            joined.append(full)
            m = re.match(r'\s*#\s*define\s+(\w+)', full)
            if m:
                macros.append(m.group(1))
            out.append('')
        else:
            out.append(ln)
            if ln.strip():
                joined.append(ln)
        k += 1
    return '\n'.join(out), macros, guard


def declarator_names(stmt):
    stmt = re.sub(r'__attribute__\s*\(\(.*?\)\)', ' ', stmt, flags=re.S)
    stmt = re.sub(r'=.*', ' ', stmt, flags=re.S) if '(' not in stmt.split('=')[0] else stmt
    names = []
    for part in re.split(r',(?![^()]*\))', stmt):
        part = re.sub(r'\[[^\]]*\]', ' ', part)
        w = [x for x in WORD.findall(part) if x not in NOT_DECL]
        if w:
            names.append(w[-1])
    return names


def function_name(stmt):
    stmt = re.sub(r'__attribute__\s*\(\(.*?\)\)', ' ', stmt, flags=re.S)
    m = re.match(r'[^()]*\(\s*\*\s*(\w+)\s*\)\s*\(', stmt)
    if m:
        return m.group(1)
    for m in re.finditer(r'([A-Za-z_]\w*)\s*\(', stmt):
        if m.group(1) not in NOT_DECL:
            return m.group(1)
    return None


def scan_header(raw):
    """One pass over a header: (declared identifiers, include count, long inline bodies, line count)."""
    text = strip_comments(raw)
    includes = len(INCLUDE.findall(text))
    body, macros, guard = preprocess(strip_strings(text))
    ids = set(m for m in macros if m != guard)
    longs = 0
    n, i, head = len(body), 0, []
    while i < n:
        c = body[i]
        if c == '{':
            h = ''.join(head).strip()
            if re.fullmatch(r'extern\s*(""|"C"|"C\+\+")?', h) or re.fullmatch(r'namespace\s*\w*', h):
                head = []
                i += 1
                continue
            j = match_brace(body, i)
            inner = body[i + 1:j]
            tag = re.search(r'\b(struct|union|enum|class)\b\s*(\w+)?\s*(?::\s*\w+\s*)?$', h)
            if tag:
                if tag.group(2):
                    ids.add(tag.group(2))
                if tag.group(1) == 'enum':
                    for part in inner.split(','):
                        w = WORD.findall(part.split('=')[0])
                        if w:
                            ids.add(w[0])
                head = [h, ' {} ']
            elif h.endswith('=') or re.search(r'=\s*$', h):
                head = [h, ' {} ']
            elif ')' in h:
                name = function_name(h)
                if name:
                    ids.add(name)
                if '\n' in inner.strip('\n ') or inner.count(';') > 1:
                    longs += 1
                head = []
            else:
                head = [h, ' {} ']
            i = j + 1
            continue
        if c == '}':
            head = []
            i += 1
            continue
        if c == ';':
            stmt = ''.join(head).strip()
            head = []
            i += 1
            classify(stmt, ids)
            continue
        head.append(c)
        i += 1
    return ids, includes, longs, raw.count('\n') + (0 if raw.endswith('\n') or not raw else 1)


def classify(stmt, ids):
    if not stmt:
        return
    if re.fullmatch(r'(struct|union|enum|class)\s+\w+', stmt) or stmt.startswith(('using', 'friend', 'template')):
        return
    tail = stmt.rsplit('{}', 1)[1].strip() if '{}' in stmt else None
    if stmt.startswith('typedef'):
        if tail is not None:
            w = WORD.findall(tail)
            if w:
                ids.add(w[-1])
            return
        m = re.search(r'\(\s*\*\s*(\w+)\s*\)\s*\(', stmt)
        if m:
            ids.add(m.group(1))
            return
        w = [x for x in WORD.findall(re.sub(r'\[[^\]]*\]', ' ', stmt.split('(')[0])) if x not in NOT_DECL]
        if w:
            ids.add(w[-1])
        return
    if tail is not None:
        if tail:
            for nm in declarator_names(tail):
                ids.add(nm)
        return
    if '(' in stmt:
        name = function_name(stmt)
        if name:
            ids.add(name)
        return
    for nm in declarator_names(stmt):
        ids.add(nm)


def struct_fields(raw):
    """typedef name -> {field type name: [field names]} for the typedef structs of a header, and the extern instances: (type, inst)."""
    text = strip_strings(strip_comments(raw))
    fields, inst = {}, []
    for m in re.finditer(r'typedef\s+struct\s*\w*\s*\{', text):
        j = match_brace(text, m.end() - 1)
        tail = re.match(r'\s*(\w+)\s*;', text[j + 1:])
        if not tail:
            continue
        d = collections.defaultdict(list)
        for f in re.finditer(r'(?:^|[;{])\s*(?:struct\s+)?(\w+)\s+(\w+)\s*;', text[m.end():j]):
            d[f.group(1)].append(f.group(2))
        fields[tail.group(1)] = d
    for m in re.finditer(r'\bextern\s+(\w+)\s+(\w+)\s*;', text):
        inst.append((m.group(1), m.group(2)))
    return fields, inst


class Tree:
    def __init__(self, root, obj, min_units):
        self.root, self.obj = os.path.abspath(root), obj
        dfiles = []
        for base in (obj, os.path.join(self.root, 'out')):
            for dp, dn, fn in os.walk(base):
                dfiles += [os.path.join(dp, f) for f in fn if f.endswith('.d')]
        if len(dfiles) < min_units:
            print('REFUSE(2): %d .d files under %s and %s/out, fewer than %d: build the tree first' % (len(dfiles), obj, self.root, min_units), file=sys.stderr)
            sys.exit(2)
        self.unit_deps = collections.defaultdict(set)
        for d in dfiles:
            src, deps = self.read_d(d)
            if src:
                self.unit_deps[src].update(deps)
        self.units = sorted(self.unit_deps)
        self.headers = sorted(set(h for s in self.unit_deps.values() for h in s))
        self.info = {}
        for h in self.headers:
            self.info[h] = scan_header(read(os.path.join(self.root, 'src', h)))
        self.unit_text, self.unit_tokens, self.unit_includes = {}, {}, {}
        for u in self.units:
            raw = strip_comments(read(os.path.join(self.root, 'src', u)))
            self.unit_includes[u] = INCLUDE.findall(raw)
            self.unit_text[u] = strip_strings(raw)
            self.unit_tokens[u] = set(WORD.findall(self.unit_text[u]))
        self.header_includes = {h: INCLUDE.findall(strip_comments(read(os.path.join(self.root, 'src', h)))) for h in self.headers}
        self.paths = self.member_paths()
        self.fanin = collections.Counter(h for s in self.unit_deps.values() for h in s)
        self.users_of, self.direct_of = {}, collections.Counter()
        for h in self.headers:
            self.users_of[h] = [u for u in self.units if self.names(u, h)]
        for u in self.units:
            for h in self.resolve_all(u, self.unit_includes[u]):
                self.direct_of[h] += 1

    def read_d(self, path):
        text = read(path).replace('\\\n', ' ')
        m = re.match(r'\s*[^:\s]+:\s*(.*)', text, re.S)
        if not m:
            return None, set()
        toks = m.group(1).split()
        if not toks:
            return None, set()
        src = self.rel(toks[0])
        deps = set()
        for t in toks[1:]:
            r = self.rel(t)
            if r and r.endswith(HDR_EXT):
                deps.add(r)
        return (src if src and src.endswith(SRC_EXT) else None), deps

    def rel(self, p):
        p = os.path.normpath(p)
        if os.path.isabs(p):
            pre = os.path.join(self.root, 'src') + os.sep
            return p[len(pre):] if p.startswith(pre) else None
        return p[4:] if p.startswith('src' + os.sep) else None

    def member_paths(self):
        """header -> list of compiled regexes for 'inst.field' paths that name the header."""
        fields, insts = {}, []
        for h in self.headers:
            f, i = struct_fields(read(os.path.join(self.root, 'src', h)))
            fields.update(f)
            insts += i
        declares = {}
        for h in self.headers:
            for nm in self.info[h][0]:
                declares.setdefault(nm, set()).add(h)
        out = collections.defaultdict(list)
        for ty, inst in insts:
            for fty, names in fields.get(ty, {}).items():
                for h in declares.get(fty, ()):
                    for fld in names:
                        out[h].append(re.compile(r'\b%s\s*\.\s*%s\b' % (re.escape(inst), re.escape(fld))))
        return out

    def names(self, u, h):
        ids = self.info[h][0]
        if ids & self.unit_tokens[u]:
            return True
        return any(rx.search(self.unit_text[u]) for rx in self.paths.get(h, ()))

    def resolve(self, name, deps, who):
        for d in [os.path.dirname(who)] + INC_DIRS:
            cand = os.path.normpath(os.path.join(d, name))
            if cand in deps:
                return [cand]
        name = os.path.normpath(name)
        return sorted(d for d in deps if d == name or d.endswith('/' + name))[:1]

    def resolve_all(self, u, names):
        out = []
        for nm in names:
            out += self.resolve(nm, self.unit_deps[u], u)
        return out

    def row(self, h):
        ids, inc, longs, lines = self.info[h]
        return dict(path=h, fanin=self.fanin[h], direct=self.direct_of[h], users=len(self.users_of[h]), includes=inc, inline_bodies=longs, lines=lines)

    def umbrella(self, h):
        ids, inc = self.info[h][0], self.info[h][1]
        return h.endswith('.h') and inc >= 2 and not ids

    def base_set(self, path):
        out = {}
        for ln in read(path).splitlines():
            if ln.strip() and not ln.startswith('#'):
                p = ln.split('\t')
                out[p[0].strip()] = p[1].strip() if len(p) > 1 else ''
        return out

    def over(self, base):
        third = len(self.units) // 3
        res = []
        for h in self.headers:
            r = self.row(h)
            if r['fanin'] > r['users'] + 4 or (h not in base and r['fanin'] > third):
                res.append(r)
        return sorted(res, key=lambda r: (-r['fanin'], r['path']))

    def unused(self):
        out = {}
        for u in self.units:
            bad = []
            for nm in self.unit_includes[u]:
                for h in self.resolve(nm, self.unit_deps[u], u):
                    if not self.names(u, h) and not (os.path.splitext(h)[0] == os.path.splitext(u)[0]):
                        bad.append(h)
            if bad:
                out[u] = sorted(set(bad))
        return out

    def bare(self):
        out = {}
        for who, incl in [(u, self.unit_includes[u]) for u in self.units] + [(h, self.header_includes[h]) for h in self.headers]:
            deps = self.unit_deps[who] if who in self.unit_deps else set(self.headers)
            bad = []
            for nm in incl:
                if '/' in nm:
                    continue
                for h in self.resolve(nm, deps, who):
                    if os.path.dirname(h) != os.path.dirname(who):
                        bad.append(nm)
            if bad:
                out[who] = sorted(set(bad))
        return out


def default_obj(root):
    return '/tmp/si_objs' + os.path.abspath(root).replace('/', '-')


def baseline_figures(t, base):
    over = {r['path']: r for r in t.over(base)}
    fig = {}
    for h in t.headers:
        r = t.row(h)
        fig[('hdr', h)] = (r['fanin'], r['users'], r['inline_bodies'], 1 if h in over else 0)
    for h in t.headers:
        if t.umbrella(h):
            fig[('umbrella', h)] = (1, 0, 0, 0)
    for u, bad in t.bare().items():
        fig[('bare', u)] = (len(bad), 0, 0, 0)
    for u, bad in t.unused().items():
        fig[('unused', u)] = (len(bad), 0, 0, 0)
    return fig


def load_baseline(path):
    fig = {}
    for ln in read(path).splitlines():
        if not ln.strip() or ln.startswith('#'):
            continue
        p = ln.split('\t')
        if len(p) >= 6 and p[0] in ('hdr', 'umbrella', 'bare', 'unused'):
            fig[(p[0], p[1])] = tuple(int(x) for x in p[2:6])
    return fig


def violations(t, base, old, arm):
    new = baseline_figures(t, base)
    out = []
    for (kind, key), v in sorted(new.items()):
        o = old.get((kind, key))
        if arm == 'fanin' and kind == 'hdr':
            if v[3] and (o is None or not o[3] or v[0] > o[0]):
                out.append('RAISED fanin %s %s -> %d (users %d)' % (key, 'new over' if o is None or not o[3] else str(o[0]), v[0], v[1]))
        elif arm == 'umbrella' and kind == 'umbrella':
            if o is None:
                out.append('RAISED umbrella %s (no umbrella in the baseline)' % key)
        elif arm == 'inline' and kind == 'hdr':
            if v[2] > (o[2] if o else 0) and key not in base:
                out.append('RAISED inline_bodies %s %s -> %d' % (key, o[2] if o else 0, v[2]))
        elif arm in ('bare', 'unused') and kind == arm:
            if o is None or v[0] > o[0]:
                out.append('RAISED %s %s %s -> %d' % (arm, key, o[0] if o else 0, v[0]))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__ and 'per-header fan-in of the built tree (ARCH-HEADER-SPLIT.md)')
    ap.add_argument('--root', default=os.environ.get('S4E_HOME') and os.path.join(os.environ['S4E_HOME'], 'SCRIP') or os.path.join(HERE, '..', '..', 'SCRIP'))
    ap.add_argument('--obj')
    ap.add_argument('--min-units', type=int, default=200)
    ap.add_argument('--base-file', default=os.path.join(HERE, 'header_base_set.tsv'))
    ap.add_argument('--inline-file', default=os.path.join(HERE, 'header_inline_allowed.tsv'))
    ap.add_argument('--baseline-file', default=os.path.join(HERE, 'header_fanin.baseline.tsv'))
    ap.add_argument('--recompiles', metavar='H')
    ap.add_argument('--base', action='store_true')
    ap.add_argument('--ceiling', action='store_true')
    ap.add_argument('--unused', action='store_true')
    ap.add_argument('--bare', action='store_true')
    ap.add_argument('--under', metavar='PATH', help='restrict --unused and --bare to the units under PATH (src/templates or templates)')
    ap.add_argument('--write-baseline', action='store_true')
    ap.add_argument('--ratchet', choices=['fanin', 'umbrella', 'inline', 'bare', 'unused', 'all'])
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    t = Tree(root, a.obj or default_obj(root), a.min_units)
    base = t.base_set(a.base_file)
    if a.recompiles:
        hits = [h for h in t.headers if h == a.recompiles or h.endswith('/' + a.recompiles) or ('src/' + h) == a.recompiles]
        if len(hits) != 1:
            print('REFUSE(2): %r names %d headers under src/: %s' % (a.recompiles, len(hits), ' '.join(hits[:6])), file=sys.stderr)
            return 2
        us = [u for u in t.units if hits[0] in t.unit_deps[u]]
        for u in us:
            print(u)
        print('recompiles=%d of units=%d' % (len(us), len(t.units)))
        return 0
    if a.base:
        for p in sorted(base):
            r = t.row(p) if p in t.info else None
            print('%s\tfanin=%s users=%s\t%s' % (p, r['fanin'] if r else 'absent', r['users'] if r else '-', base[p]))
        print('base=%d present=%d' % (len(base), sum(1 for p in base if p in t.info)))
        return 0
    if a.ceiling:
        ov = t.over(base)
        for r in ov:
            print('OVER %s fanin=%d users=%d' % (r['path'], r['fanin'], r['users']))
        um = [h for h in t.headers if t.umbrella(h)]
        for h in um:
            print('UMBRELLA %s' % h)
        print('summary over=%d umbrellas=%d' % (len(ov), len(um)))
        return 0
    under = a.under and a.under.strip('/')
    if under and under.startswith('src/'):
        under = under[4:]
    keep = (lambda u: not under or u == under or u.startswith(under + '/'))
    if a.unused:
        un = {u: b for u, b in t.unused().items() if keep(u)}
        for u, bad in sorted(un.items()):
            print('%s\t%s' % (u, ' '.join(bad)))
        print('summary unused=%d' % sum(len(b) for b in un.values()))
        return 0
    if a.bare:
        bg = {u: b for u, b in t.bare().items() if keep(u)}
        for u, bad in sorted(bg.items()):
            print('%s\t%s' % (u, ' '.join(bad)))
        print('summary bare=%d' % sum(len(b) for b in bg.values()))
        return 0
    if a.write_baseline or a.ratchet:
        old = load_baseline(a.baseline_file)
        if a.ratchet:
            allowed = t.base_set(a.inline_file)
            wide = dict(base)
            wide.update(allowed)
            total = 0
            for arm in (['fanin', 'umbrella', 'inline', 'bare', 'unused'] if a.ratchet == 'all' else [a.ratchet]):
                vs = violations(t, wide if arm == 'inline' else base, old, arm)
                for v in vs:
                    print(v)
                print('arm %s violations=%d' % (arm, len(vs)))
                total += len(vs)
            if a.ratchet == 'all':
                ov = t.over(base)
                print('summary over=%d umbrellas=%d' % (len(ov), sum(1 for h in t.headers if t.umbrella(h))))
            return 1 if total else 0
        allowed = t.base_set(a.inline_file)
        bad = []
        if old:
            merged = dict(base)
            merged.update(allowed)
            for arm in ('fanin', 'umbrella', 'inline', 'bare', 'unused'):
                bad += violations(t, merged if arm == 'inline' else base, old, arm)
        if bad:
            for v in bad:
                print(v)
            print('REFUSED: the baseline is lowered and never raised; %d figure(s) above it' % len(bad))
            return 1
        new = baseline_figures(t, base)
        with open(a.baseline_file, 'w', encoding='utf-8') as f:
            f.write('# header_fanin.baseline.tsv -- written by util_header_fanin.py --write-baseline (ARCH-HEADER-SPLIT.md section 2, CEO-2032). LOWERED, NEVER RAISED.\n')
            f.write('# kind\tkey\tv1\tv2\tv3\tv4   hdr: fanin users inline_bodies over | umbrella: 1 | bare: includes written bare | unused: includes unused\n')
            f.write('# units=%d\n' % len(t.units))
            for (kind, key), v in sorted(new.items()):
                f.write('%s\t%s\t%d\t%d\t%d\t%d\n' % ((kind, key) + v))
        print('wrote %s: %d rows, units=%d' % (a.baseline_file, len(new), len(t.units)))
        return 0
    rows = sorted((t.row(h) for h in t.headers), key=lambda r: (-r['fanin'], r['path']))
    print('fanin\tdirect\tusers\tincludes\tinline_bodies\tlines\tpath')
    for r in rows:
        print('%d\t%d\t%d\t%d\t%d\t%d\t%s' % (r['fanin'], r['direct'], r['users'], r['includes'], r['inline_bodies'], r['lines'], r['path']))
    print('headers=%d units=%d' % (len(rows), len(t.units)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
