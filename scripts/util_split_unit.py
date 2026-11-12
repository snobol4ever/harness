#!/usr/bin/env python3
# util_split_unit.py -- THE SPLIT TOOL OF DESIGN-PLAN cache-tree, step 1 (the cto, 2026-11-12, CTO-636; skill scrip-build reference section 4, laws C2-C4 and C8).
#
# Cuts one SCRIP translation unit into contiguous pieces in file order, by a manifest that names, for each piece, the function it starts at, so the
# manifest survives any edit of the unit's bodies and is re-applied on origin's HEAD at the moment of landing (C8). Reading the pieces in name order gives
# back the unit's functions in their original order.
#
#   util_split_unit.py plan  SRC [--target LINES] [--prefix P]     prints a manifest: NN_<lang><TAB>first_function (NN the file order, so the pieces' names sort as the unit read) (contiguous cuts at the cheapest boundary
#                                                                  near every TARGET lines, never separating a static the cut cannot export)
#   util_split_unit.py apply SRC --manifest M --dir DIR --prefix P [--head NAME] [--keep]
#                                                                  writes DIR/<P>head.h (the unit's declarations: every line that is no function or
#                                                                  variable definition, in order, its includes rewritten from src/) and DIR/<piece>.c per
#                                                                  manifest row, deletes SRC unless --keep, and prints the pieces, the exports and the
#                                                                  Makefile line to replace
#   util_split_unit.py --selftest                                 splits a fixture three ways and proves the pieces compile, link and run like the unit
#
# THE TRANSFORM (the grant of Lon's go, 2026-11-12: the statics a cut exports become hidden-visibility externs, so an access compiles to the code a static's
# access compiled to): a static function or variable referenced from another piece loses its "static" and gains __attribute__((visibility("hidden")));
# its prototypes in the head lose "static" too, and when it has none, one is generated from its definition's own text up to its body. A static that a macro
# defines (its "static" is in the macro's text) cannot be exported: plan never cuts between it and its users, and apply refuses rc 2 when the manifest does.
# A top-level #if region that holds a definition travels whole into the piece of its first definition. Functions are found by libclang with expansion
# locations, so a function a macro makes (PL_CX_LEAF_HEAD ... PL_CX_LEAF_TAIL) spans the lines it was written on, and two on one line are one chunk.
# rc 0 done; rc 1 the manifest names a function the unit does not define, or a cut no export can satisfy; rc 2 could not read the unit.
import argparse, collections, os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
SEP = re.compile(r'^/\*-{50,}\*/$')
HIDDEN = '__attribute__((visibility("hidden"))) '
LANGS = [('pl', r'^(pl|PL|plw|plc|rt_pl|dop_pl|bt_pl|pl_\w*)_?'), ('rk', r'^(rk|RK|rt_rk|bt_rk|bt___rk)_'), ('pas', r'^(pas|PAS|rt_pas)_'),
         ('icn', r'^(icn|ICN|rt_icn|bt_icn)_'), ('sno', r'^(sno|SNO|rt_sno|spt)_')]


def lang_of(name):
    for k, rx in LANGS:
        if re.match(rx, name):
            return k
    return 'sh'


def flags_for(root, src):
    from util_cache_blast import compile_lines
    for cc, f, s in compile_lines(root):
        if os.path.abspath(os.path.join(root, s)) == os.path.abspath(src):
            return cc, f
    return None, None


class Unit:
    def __init__(self, src, flags, cplus=False):
        import clang.cindex as ci
        self.ci = ci
        self.src = os.path.abspath(src)
        self.text = open(self.src, encoding='utf-8', errors='surrogateescape').read()
        self.lines = self.text.split('\n')
        args = [a for a in flags if a.startswith(('-I', '-D', '-U', '-std=', '-include'))] + ['-w', '-Wno-implicit-function-declaration', '-Wno-int-conversion',
                                                                                             '-Wno-incompatible-pointer-types']
        rd = subprocess.run(['clang', '-print-resource-dir'], capture_output=True, text=True).stdout.strip()
        if rd:
            args += ['-isystem', os.path.join(rd, 'include')]
        if cplus:
            args = ['-x', 'c++'] + args
        tu = ci.Index.create().parse(self.src, args=args)
        fatal = [d for d in tu.diagnostics if d.severity >= 4]
        if fatal:
            raise SystemExit('REFUSE(2): libclang could not read %s: %s' % (self.src, fatal[0].spelling))
        self.errors = [d for d in tu.diagnostics if d.severity == 3]
        self.defs, self.protos, self.vars, self.decls = [], collections.defaultdict(list), [], []
        self.incdefs = {}
        self.byname = {}
        self.unexportable = set()
        def top(cur):
            for c in cur.get_children():
                f = c.location.file
                if c.kind == ci.CursorKind.LINKAGE_SPEC:
                    top(c); continue
                if f and f.name.endswith('.inc') and c.kind in (ci.CursorKind.VAR_DECL, ci.CursorKind.FUNCTION_DECL) and self.direct_inc(f.name):
                    self.incdefs[c.spelling] = os.path.abspath(f.name)
                if not f or os.path.abspath(f.name) != self.src:
                    continue
                yield_one(c)
        def yield_one(c):
            K = ci.CursorKind
            b, e = c.extent.start.line, c.extent.end.line
            static = c.storage_class == ci.StorageClass.STATIC
            if c.kind in (K.FUNCTION_DECL,) and c.is_definition():
                body = next((x for x in c.get_children() if x.kind == K.COMPOUND_STMT), None)
                args_ = [a.type.spelling for a in c.get_arguments()]
                tproto = '%s %s(%s%s)' % (c.result_type.spelling, c.spelling, ', '.join(args_) or ('' if c.type.is_function_variadic() else 'void'),
                                          ', ...' if c.type.is_function_variadic() and args_ else '')
                d = {'name': c.spelling, 'b': b, 'e': e, 'static': static, 'cur': c, 'col': c.extent.start.column, 'tproto': tproto,
                     'body': (body.extent.start.line, body.extent.start.column) if body else None, 'kind': 'f'}
                d['macro'] = not self.literal_static(d) if static else False
                self.defs.append(d); self.byname[c.spelling] = d
            elif c.kind == K.FUNCTION_DECL:
                self.protos[c.spelling].append({'b': b, 'e': e, 'col': c.extent.start.column, 'static': static})
                self.decls.append({'name': c.spelling, 'b': b, 'e': e, 'col': c.extent.start.column, 'static': static, 'kind': 'fp'})
            elif c.kind == K.VAR_DECL and c.storage_class == ci.StorageClass.EXTERN:
                self.decls.append({'name': c.spelling, 'b': b, 'e': max(e, self.statement_end(b, c.extent.start.column)), 'col': c.extent.start.column,
                                   'static': False, 'kind': 've'})
            elif c.kind == K.VAR_DECL and c.storage_class != ci.StorageClass.EXTERN:
                e = max(e, self.statement_end(b, c.extent.start.column))
                d = {'name': c.spelling, 'b': b, 'e': e, 'static': static, 'cur': c, 'col': c.extent.start.column, 'kind': 'v', 'type': c.type.spelling}
                d['macro'] = not self.literal_static(d) if static else False
                self.vars.append(d); self.byname[c.spelling] = d
        top(tu.cursor)
        if not self.defs:
            raise SystemExit('REFUSE(2): libclang read no function definition of %s' % self.src)
        names = set(self.byname) | {d['name'] for d in self.decls} | set(self.incdefs)
        self.refs = {}
        for d in self.defs + self.vars:
            r = set()
            for x in d['cur'].walk_preorder():
                if x.kind == ci.CursorKind.DECL_REF_EXPR and x.referenced is not None and x.referenced.spelling in names:
                    r.add(x.referenced.spelling)
            r.discard(d['name'])
            self.refs[d['name']] = r
            d.pop('cur')
        for v in self.vars:
            for w in self.vars:
                if v is not w and v['b'] <= w['e'] and w['b'] <= v['e']:
                    v['multi'] = True
        for d in self.defs:
            txt = ' '.join(self.lines[d['b'] - 1:(d['body'][0] if d['body'] else d['b'])])
            d['inline_head'] = 'always_inline' in txt or any('always_inline' in ' '.join(self.lines[p['b'] - 1:p['e']]) for p in self.protos.get(d['name'], []))
        for d in self.defs + self.vars:
            d['pin'] = bool(d['macro'] or d.get('multi') or ('(unnamed' in d.get('type', '') or '(anonymous' in d.get('type', '')) and d['static'])
        self.chunks()

    def direct_inc(self, path):
        if not hasattr(self, '_incs'):
            self._incs = {}
            for m in re.finditer(r'^\s*#\s*include\s*"([^"]+\.inc)"', self.text, re.M):
                for base in (os.path.dirname(self.src),):
                    q = os.path.normpath(os.path.join(base, m.group(1)))
                    self._incs[q] = m.group(1)
            for m in re.finditer(r'^\s*#\s*include\s*"([^"]+\.inc)"', self.text, re.M):
                q = os.path.basename(m.group(1))
                self._incs.setdefault(q, m.group(1))
        p = os.path.abspath(path)
        return p in self._incs or os.path.basename(p) in self._incs

    def statement_end(self, line, col):
        """The line of the ';' that ends the declaration starting at (line, col), at brace and paren depth 0, strings and comments skipped (libclang's
        extent of a variable whose initializer runs over several lines can stop at the initializer's first line)."""
        depth, i, n = 0, line - 1, len(self.lines)
        t, k = self.lines[i], col - 1
        while i < n:
            while k < len(t):
                ch = t[k]
                if ch in '"\'':
                    q, k = ch, k + 1
                    while k < len(t) and t[k] != q:
                        k += 2 if t[k] == '\\' else 1
                elif t.startswith('/*', k):
                    e = t.find('*/', k + 2)
                    if e < 0:
                        break
                    k = e + 1
                elif t.startswith('//', k):
                    break
                elif ch in '({[':
                    depth += 1
                elif ch in ')}]':
                    depth -= 1
                elif ch == ';' and depth <= 0:
                    return i + 1
                k += 1
            i += 1
            t, k = (self.lines[i], 0) if i < n else ('', 0)
        return line

    def literal_static(self, d):
        t = self.lines[d['b'] - 1][d['col'] - 1:]
        m = re.match(r'(?:__attribute__\(\([^)]*\)\)\s*)*static\b', t)
        return bool(m) and d['name'] in ' '.join(self.lines[d['b'] - 1:d['e']])

    def chunks(self):
        """Merge overlapping definitions into chunks; attach each chunk's leading separator lines; make each top-level #if region holding a definition one chunk."""
        n = len(self.lines)
        owner = [None] * (n + 2)
        items = sorted(self.defs + self.vars, key=lambda d: (d['b'], d['e']))
        ch = []
        for d in items:
            if ch and d['b'] <= ch[-1]['e']:
                ch[-1]['e'] = max(ch[-1]['e'], d['e']); ch[-1]['items'].append(d)
            else:
                ch.append({'b': d['b'], 'e': d['e'], 'items': [d]})
        depth, opened, regions = 0, None, []
        inside = [False] * (n + 2)
        for c in ch:
            for i in range(c['b'], c['e'] + 1):
                inside[i] = True
        for i in range(1, n + 1):
            if inside[i]:
                continue
            t = self.lines[i - 1].lstrip()
            if re.match(r'#\s*if', t):
                if depth == 0:
                    opened = i
                depth += 1
            elif re.match(r'#\s*endif', t):
                depth -= 1
                if depth == 0:
                    regions.append((opened, i))
        for (rb, re_) in regions:
            members = [c for c in ch if rb < c['b'] and c['e'] < re_]
            if members:
                keep = [c for c in ch if c not in members]
                keep.append({'b': rb, 'e': re_, 'items': [d for c in members for d in c['items']], 'region': True})
                ch = sorted(keep, key=lambda c: c['b'])
        for c in ch:
            while c['b'] > 1 and SEP.match(self.lines[c['b'] - 2]) and not any(o['b'] <= c['b'] - 1 <= o['e'] for o in ch if o is not c):
                c['b'] -= 1
            c['fns'] = [d for d in c['items'] if d['kind'] == 'f']
        self.ch = ch
        for c in ch:
            for d in c['items']:
                d['chunk'] = c

    def glue_lines(self):
        used = set()
        for c in self.ch:
            used.update(range(c['b'], c['e'] + 1))
        return [i for i in range(1, len(self.lines) + 1) if i not in used]


def rewrite_includes(text, src_dir, src_root):
    def sub(m):
        inc = m.group(2)
        for base in (src_dir, src_root):
            p = os.path.normpath(os.path.join(base, inc))
            if os.path.exists(p):
                return '%s"%s"' % (m.group(1), os.path.relpath(p, src_root))
        return m.group(0)
    return re.sub(r'^(\s*#\s*include\s*)"([^"]+)"', sub, text, flags=re.M)


def movable_decls(u):
    """The glue declarations a piece may carry: whole lines holding one declaration whose name its text spells, outside every top-level #if region."""
    occupied = collections.Counter()
    for d in u.defs + u.vars + u.decls:
        for i in range(d['b'], d['e'] + 1):
            occupied[i] += 1
    regions = []
    depth, opened = 0, None
    inside = set()
    for c in u.ch:
        inside.update(range(c['b'], c['e'] + 1))
    for i in range(1, len(u.lines) + 1):
        if i in inside:
            continue
        t = u.lines[i - 1].lstrip()
        if re.match(r'#\s*if', t):
            if depth == 0:
                opened = i
            depth += 1
        elif re.match(r'#\s*endif', t):
            depth -= 1
            if depth == 0:
                regions.append((opened, i))
    out = []
    for d in u.decls:
        lines = u.lines[d['b'] - 1:d['e']]
        txt = '\n'.join(lines)
        if any(occupied[i] != 1 for i in range(d['b'], d['e'] + 1)) or any(rb <= d['b'] <= re_ for rb, re_ in regions):
            continue
        if u.lines[d['b'] - 1][:d['col'] - 1].strip() or not txt.rstrip().endswith(';') or '#' in txt.lstrip()[:1]:
            continue
        if not re.search(r'\b%s\b' % re.escape(d['name']), txt) or any(o is not d and o['b'] == d['b'] for o in u.decls):
            continue
        out.append(d)
    return out


def history_cochange(u, root, since):
    """Per commit since SINCE that touched the unit: the chunks its hunks fall in (by the function each hunk header names)."""
    rel = os.path.relpath(u.src, root)
    log = subprocess.run(['git', '-C', root, 'log', '--since=' + since, '--format=@@C %h', '-U0', '-p', '--', rel], capture_output=True, text=True).stdout
    chunk_of = {d['name']: id(d['chunk']) for d in u.defs}
    out, cur = [], None
    for ln in log.split('\n'):
        if ln.startswith('@@C'):
            cur = set(); out.append(cur); continue
        if ln.startswith('@@ ') and cur is not None:
            m = re.search(r'([A-Za-z_]\w*)\s*\(', re.sub(r'^@@[^@]*@@ ?', '', ln))
            if m and m.group(1) in chunk_of:
                cur.add(chunk_of[m.group(1)])
    return out


def plan(u, target, root=None, since='60 days ago'):
    """Clusters, not cuts: the function chunks are joined by their calls, by the commits that edited them together and by adjacency in the file, the
    strongest relative bond first, while the joined piece stays under TARGET lines; a pinned static (made by a macro, or of an unnamed type) and the
    users of a data .inc are joined first and never parted. Small leftovers join their strongest neighbour. Returns [(piece, [chunk ids])] in file order."""
    ch = [c for c in sorted(u.ch, key=lambda c: c['b']) if c['fns'] and not all(d.get('inline_head') for d in c['fns'])]
    idx = {id(c): k for k, c in enumerate(ch)}
    of_name = {}
    for c in ch:
        for d in c['items']:
            of_name[d['name']] = idx[id(c)]
    parent = list(range(len(ch)))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    def union(a, b):
        a, b = find(a), find(b)
        if a != b:
            parent[b] = a
    users = collections.defaultdict(set)
    for a, rs in u.refs.items():
        if a in of_name:
            for b in rs:
                users[b].add(of_name[a])
    for d in u.defs + u.vars:
        if d['pin']:
            ks = set(users.get(d['name'], ())) | ({of_name[d['name']]} if d['name'] in of_name else set())
            ks = sorted(ks)
            for k in ks[1:]:
                union(ks[0], k)
    byinc = collections.defaultdict(set)
    for n, f in u.incdefs.items():
        byinc[f] |= users.get(n, set())
    for f, ks in byinc.items():
        ks = sorted(ks)
        for k in ks[1:]:
            union(ks[0], k)
    W = collections.defaultdict(float)
    def bond(a, b, w):
        if a != b:
            W[(min(a, b), max(a, b))] += w
    for a, rs in u.refs.items():
        if a in of_name:
            for b in rs:
                if b in of_name:
                    bond(of_name[a], of_name[b], 1.0)
    for k in range(len(ch) - 1):
        bond(k, k + 1, 0.5)
    if root:
        for cs in history_cochange(u, root, since):
            ks = sorted(idx[c] for c in cs if c in idx)
            if 1 < len(ks) <= 24:
                w = 3.0 / (len(ks) - 1)
                for i in range(len(ks)):
                    for j in range(i + 1, len(ks)):
                        bond(ks[i], ks[j], w)
    size = collections.Counter()
    for k, c in enumerate(ch):
        size[find(k)] += c['e'] - c['b'] + 1
    members = collections.defaultdict(list)
    for k in range(len(ch)):
        members[find(k)].append(k)
    CW = collections.defaultdict(lambda: collections.defaultdict(float))
    for (a, b), w in W.items():
        ra, rb = find(a), find(b)
        if ra != rb:
            CW[ra][rb] += w; CW[rb][ra] += w
    import heapq
    heap = [(-w / ((size[a] * size[b]) ** 0.5), a, b) for a in CW for b, w in CW[a].items() if a < b]
    heapq.heapify(heap)
    alive = set(members)
    while heap:
        sc, a, b = heapq.heappop(heap)
        if a not in alive or b not in alive or size[a] + size[b] > target:
            continue
        cur = CW[a].get(b, 0)
        if abs(-cur / ((size[a] * size[b]) ** 0.5) - sc) > 1e-12:
            continue
        members[a] += members.pop(b); size[a] += size.pop(b); alive.discard(b)
        for x, w in CW.pop(b).items():
            CW[x].pop(b, None)
            if x != a:
                CW[a][x] += w; CW[x][a] = CW[a][x]
        CW[a].pop(a, None)
        for x, w in CW[a].items():
            heapq.heappush(heap, (-w / ((size[a] * size[x]) ** 0.5), min(a, x), max(a, x)))
    for a in sorted(alive, key=lambda a: size[a]):
        if a not in alive or size[a] >= target // 4:
            continue
        nb = [(w, x) for x, w in CW[a].items() if x in alive and size[x] + size[a] <= target * 1.5]
        if not nb:
            continue
        w, x = max(nb)
        members[x] += members.pop(a); size[x] += size.pop(a); alive.discard(a)
        for y, w2 in CW.pop(a).items():
            CW[y].pop(a, None)
            if y != x:
                CW[x][y] += w2; CW[y][x] = CW[x][y]
        CW[x].pop(x, None)
    groups = sorted((sorted(members[a]) for a in alive), key=lambda m: ch[m[0]]['b'])
    out = []
    for i, g in enumerate(groups):
        lang = collections.Counter()
        for k in g:
            for d in ch[k]['fns']:
                lang[lang_of(d['name'])] += d['e'] - d['b'] + 1
        out.append(('%02d_%s' % (i + 1, lang.most_common(1)[0][0] if lang else 'sh'), [id(ch[k]) for k in g]))
    return out


def plan_rows(u, groups):
    by_id = {id(c): c for c in u.ch}
    return [(d['name'], p) for p, ids in groups for i in ids for d in by_id[i]['fns'][:1]]


def assign(u, manifest_rows):
    """Every chunk's piece: a function chunk by the manifest (an unlisted one takes the piece of the listed chunk before it in the file), a variable chunk
    by its users when they sit in one piece, a chunk of always_inline functions the head (INL)."""
    named = {}
    for n, p in manifest_rows:
        if n not in u.byname:
            raise SystemExit('RED(1): the manifest names %s, which %s does not define' % (n, u.src))
        named[id(u.byname[n]['chunk'])] = p
    pieces = list(dict.fromkeys(p for _, p in manifest_rows))
    poc, cur = {}, pieces[0]
    for c in sorted(u.ch, key=lambda c: c['b']):
        cur = named.get(id(c), cur)
        poc[id(c)] = cur
    users = collections.defaultdict(set)
    for a, rs in u.refs.items():
        for b in rs:
            users[b].add(a)
    for c in u.ch:
        if c['fns'] or c.get('region'):
            continue
        ps = {poc[id(u.byname[a]['chunk'])] for d in c['items'] for a in users[d['name']] if a in u.byname and u.byname[a]['chunk'] is not c}
        if len(ps) == 1:
            poc[id(c)] = ps.pop()
    for c in u.ch:
        ih = [d for d in c['fns'] if d['inline_head']]
        if ih:
            if len(ih) != len(c['items']):
                raise SystemExit('RED(1): an always_inline function shares lines with another definition: %s' % ', '.join(d['name'] for d in c['items']))
            poc[id(c)] = INL
    return pieces, poc, users


INL = '<head>'


def proto_of(u, d):
    """A definition's own text up to its body, or for a function a macro makes, the prototype its type spells; "static" (and "inline") dropped."""
    n = d['name']
    if d['kind'] == 'v':
        decl = ' '.join(' '.join(u.lines[d['b'] - 1:d['e']])[d['col'] - 1:].split('=')[0].split())
        decl = re.sub(r'\s*;\s*$', '', decl)
        m = re.search(r'\[(\d+)\]', d['type'])
        if '[]' in decl and m:
            decl = decl.replace('[]', '[%s]' % m.group(1), 1)
        decl = re.sub(r'^((?:__attribute__\(\([^)]*\)\)\s*)*)static\s+', r'\1', decl, count=1)
        return 'extern ' + (HIDDEN if d['static'] else '') + decl + ';'
    bl, bc = d['body']
    O = u.lines
    if bl == d['b']:
        seg = O[d['b'] - 1][d['col'] - 1:bc - 1]
    else:
        seg = '\n'.join([O[d['b'] - 1][d['col'] - 1:]] + O[d['b']:bl - 1] + [O[bl - 1][:bc - 1]])
    seg = ' '.join(seg.split())
    if not re.search(r'\b%s\s*\(' % re.escape(n), seg):
        if '(*' in d['tproto'] or 'unnamed' in d['tproto']:
            raise SystemExit('RED(1): %s is made by a macro and its type %s has no plain prototype' % (n, d['tproto']))
        seg = d['tproto']
    seg = re.sub(r'^((?:__attribute__\(\([^)]*\)\)\s*)*)static\s+(?:inline\s+)?', r'\1', seg, count=1)
    return (HIDDEN if d['static'] else '') + seg + ';'


def apply(u, manifest, outdir, prefix, head_name, src_root, cplus):
    """Writes the head (includes, macros, types, the declarations no piece can carry, the always_inline bodies), one export header per piece that
    others call into (its exports, declared once; the piece includes it, so the compiler holds its definitions to it), and the pieces, each carrying the
    external declarations it uses and the producer headers it calls into."""
    rows = [tuple(l.rstrip('\n').split('\t')[:2]) for l in open(manifest) if l.strip() and not l.startswith('#')]
    pieces, poc, users = assign(u, rows)
    piece = {d['name']: poc[id(d['chunk'])] for d in u.defs + u.vars}
    def users_pieces(n):
        return {piece[a] for a in users.get(n, ()) if a in piece}
    exports = {}
    for n, d in u.byname.items():
        ps = users_pieces(n) - {piece[n]}
        if ps:
            exports[n] = ps
    bad = [n for n in exports if u.byname[n]['pin']]
    if bad:
        raise SystemExit('RED(1): the manifest separates a static a macro defines (or of an unnamed type) from its user: %s' % ', '.join(sorted(bad)[:12]))
    L = list(u.lines)
    def strip_static(line_no, col):
        t = L[line_no - 1]
        head, tail = t[:col - 1], t[col - 1:]
        tail2 = re.sub(r'^((?:__attribute__\(\([^)]*\)\)\s*)*)static\s+(?:inline\s+)?', r'\1' + HIDDEN.replace('\\', '\\\\'), tail, count=1)
        L[line_no - 1] = head + tail2
        return tail2 != tail
    for n in sorted(exports):
        d = u.byname[n]
        if d['static']:
            if not strip_static(d['b'], d['col']):
                raise SystemExit('RED(1): cannot find the static of %s at line %d' % (n, d['b']))
            for p in u.protos.get(n, []):
                if p['static'] and not strip_static(p['b'], p['col']):
                    raise SystemExit('RED(1): cannot find the static of %s\'s prototype at line %d' % (n, p['b']))
    movable = {id(d): d for d in movable_decls(u)}
    decl_home = {}
    piece_decls = collections.defaultdict(list)
    export_text = collections.defaultdict(list)
    head_extra = []
    stays = set()
    for d in u.decls:
        n = d['name']
        if id(d) not in movable:
            stays.add(id(d)); continue
        txt = '\n'.join(L[d['b'] - 1:d['e']])
        if n in u.byname:
            home = piece[n]
            if home == INL or INL in users_pieces(n):
                stays.add(id(d)); continue
            if n in exports:
                export_text[home].append((d['b'], txt))
            else:
                piece_decls[home].append((d['b'], txt))
        else:
            ps = users_pieces(n)
            if not ps or INL in ps:
                stays.add(id(d)); continue
            for p in ps:
                piece_decls[p].append((d['b'], txt))
    has_decl = {d['name'] for d in u.decls if id(d) in movable or id(d) in stays}
    for n in sorted(exports):
        d = u.byname[n]
        if n in has_decl:
            continue
        home = piece[n]
        if home == INL or INL in exports[n]:
            head_extra.append(proto_of(u, d))
        else:
            export_text[home].append((d['b'], proto_of(u, d)))
    inl_needs = {b for a, rs in u.refs.items() if a in piece and piece[a] == INL for b in rs}
    for n in sorted(inl_needs):
        if n in u.byname and n not in has_decl and n not in exports and piece[n] != INL:
            head_extra.append(proto_of(u, u.byname[n]))
    inc_home = {}
    for n, f in u.incdefs.items():
        ps = users_pieces(n)
        inc_home.setdefault(f, set()).update(ps)
    moved_inc_lines = {}
    for i, line in enumerate(u.lines, 1):
        m = re.match(r'^\s*#\s*include\s*"([^"]+\.inc)"', line)
        if m:
            q = os.path.normpath(os.path.join(os.path.dirname(u.src), m.group(1)))
            ps = inc_home.get(q) or inc_home.get(os.path.abspath(q))
            if ps and len(ps) == 1 and INL not in ps:
                moved_inc_lines[i] = next(iter(ps))
    skip = set()
    for d in u.decls:
        if id(d) in movable and id(d) not in stays:
            skip.update(range(d['b'], d['e'] + 1))
    skip.update(moved_inc_lines)
    glue = [i for i in u.glue_lines() if i not in skip]
    R = lambda t: rewrite_includes(t, os.path.dirname(u.src), src_root)
    os.makedirs(outdir, exist_ok=True)
    rel = lambda name: os.path.relpath(os.path.join(outdir, name), src_root)
    guard = lambda name: re.sub(r'\W', '_', rel(name)).upper()
    inl = '\n'.join(R('\n'.join(L[c['b'] - 1:c['e']])) for c in sorted(u.ch, key=lambda c: c['b']) if poc[id(c)] == INL)
    head_text = '#ifndef %s\n#define %s\n%s\n%s%s#endif\n' % (guard(head_name), guard(head_name), R('\n'.join(L[i - 1] for i in glue)).rstrip('\n'),
                                                              ''.join(x + '\n' for x in head_extra), (inl + '\n') if inl else '')
    open(os.path.join(outdir, head_name), 'w', encoding='utf-8', errors='surrogateescape').write(head_text)
    ext = os.path.splitext(u.src)[1]
    hext = '.h'
    written, headers = [], []
    calls_into = collections.defaultdict(set)
    for n, ps in exports.items():
        for p in ps:
            if p != INL:
                calls_into[p].add(piece[n])
    for p in pieces:
        if export_text.get(p):
            hn = '%s%s%s' % (prefix, p, hext)
            body = '\n'.join(t for _, t in sorted(export_text[p]))
            open(os.path.join(outdir, hn), 'w', encoding='utf-8', errors='surrogateescape').write(
                '#ifndef %s\n#define %s\n#include "%s"\n%s\n#endif\n' % (guard(hn), guard(hn), rel(head_name), R(body)))
            headers.append(os.path.join(outdir, hn))
    for p in pieces:
        incs = ['#include "%s"' % rel(head_name)]
        for q in sorted({p} | calls_into[p]):
            if q != INL and export_text.get(q):
                incs.append('#include "%s"' % rel('%s%s%s' % (prefix, q, hext)))
        for i in sorted(k for k, v in moved_inc_lines.items() if v == p):
            incs.append(R(u.lines[i - 1]))
        decls = [t for _, t in sorted(set(piece_decls[p]))]
        body = [R('\n'.join(L[c['b'] - 1:c['e']])) for c in sorted(u.ch, key=lambda c: c['b']) if poc[id(c)] == p]
        name = '%s%s%s' % (prefix, p, ext)
        open(os.path.join(outdir, name), 'w', encoding='utf-8', errors='surrogateescape').write('\n'.join(incs + decls + body) + '\n')
        written.append(os.path.join(outdir, name))
    return written, sorted(exports), rel(head_name), headers


def measure(u, groups, root, since):
    """What a partition costs: the call edges it cuts, the statics it exports, the pieces each commit of the history touches."""
    pof = {}
    for p, ids in groups:
        for i in ids:
            pof[i] = p
    cpiece = {d['name']: pof.get(id(d['chunk'])) for d in u.defs if id(d['chunk']) in pof}
    tot = cut = 0
    ex = set()
    for a, rs in u.refs.items():
        for b in rs:
            if a in cpiece and b in cpiece:
                tot += 1
                if cpiece[a] != cpiece[b]:
                    cut += 1; ex.add(b)
    hist = history_cochange(u, root, since) if root else []
    touched = [len({pof[c] for c in cs if c in pof}) for cs in hist]
    sizes = sorted(sum(next(c for c in u.ch if id(c) == i)['e'] - next(c for c in u.ch if id(c) == i)['b'] + 1 for i in ids) for _, ids in groups)
    return {'pieces': len(groups), 'lines_min': sizes[0], 'lines_median': sizes[len(sizes) // 2], 'lines_max': sizes[-1], 'edges': tot, 'cut': cut,
            'cut_pct': round(100.0 * cut / max(1, tot)), 'exported': len(ex), 'commits': len(touched),
            'pieces_per_commit': round(sum(touched) / max(1, len(touched)), 2)}


def selftest():
    w = tempfile.mkdtemp(prefix='split_selftest.')
    try:
        src = os.path.join(w, 'src')
        os.makedirs(os.path.join(src, 'u'))
        open(os.path.join(src, 'u', 'u.h'), 'w').write('#ifndef U_H\n#define U_H\nint u_main(int);\n#endif\n')
        open(os.path.join(src, 'u', 'u.c'), 'w').write('\n'.join([
            '#include "u.h"', '#include <stdio.h>', '#define LEAF(n) static int leaf_##n(int x) { return x + n; }',
            'static int counter;', 'static const char *names[] = { "a", "b", "c" };', 'static int helper(int);',
            '/*' + '-' * 60 + '*/', 'static int twice(int x) { counter++; return 2 * x; }', 'LEAF(1) LEAF(2)',
            '/*' + '-' * 60 + '*/', 'static int helper(int x) { return twice(x) + leaf_1(x) + leaf_2(x) + (int)(sizeof names / sizeof names[0]); }',
            '/*' + '-' * 60 + '*/', 'int u_main(int x) {', '    int r = helper(x);', '    return r + counter;', '}', '']))
        open(os.path.join(src, 'main.c'), 'w').write('#include <stdio.h>\n#include "u/u.h"\nint main(void) { printf("%d\\n", u_main(5)); return 0; }\n')
        def run(srcs):
            exe = os.path.join(w, 'a.out')
            r = subprocess.run(['gcc', '-O0', '-fPIC', '-I' + src] + srcs + ['-o', exe], capture_output=True, text=True)
            if r.returncode:
                return 'COMPILE: ' + r.stderr[-400:]
            return subprocess.run([exe], capture_output=True, text=True).stdout.strip()
        want = run([os.path.join(src, 'u', 'u.c'), os.path.join(src, 'main.c')])
        if want != '27':
            print('SELFTEST REFUSE(2): the fixture itself answered %r' % want); return 2
        u = Unit(os.path.join(src, 'u', 'u.c'), ['-I' + src])
        for k, man in enumerate([[('twice', 'a'), ('helper', 'a'), ('u_main', 'a')], [('twice', 'a'), ('helper', 'a'), ('u_main', 'b')],
                                 [('twice', 'a'), ('helper', 'b'), ('u_main', 'c')]]):
            mp = os.path.join(w, 'm%d.tsv' % k)
            open(mp, 'w').write(''.join('%s\t%s\n' % r for r in man))
            out = os.path.join(src, 'u%d' % k)
            try:
                pieces, ex, _, hs = apply(Unit(os.path.join(src, 'u', 'u.c'), ['-I' + src]), mp, out, 'p_', 'p_head.h', src, False)
            except SystemExit as e:
                if k == 2 and str(e).startswith('RED(1)'):
                    print('SELFTEST arm %d: apply refused a cut through the macro-made statics, as it must: %s' % (k, str(e)[:120])); continue
                print('SELFTEST FAIL arm %d: %s' % (k, e)); return 1
            got = run(pieces + [os.path.join(src, 'main.c')])
            print('SELFTEST arm %d: %d pieces, %d export headers, exports %s, answer %s' % (k, len(pieces), len(hs), ','.join(ex) or '-', got))
            if got != want:
                print('SELFTEST FAIL arm %d: %r != %r' % (k, got, want)); return 1
        groups = plan(u, 3)
        if not groups:
            print('SELFTEST FAIL: plan produced nothing'); return 1
        print('SELFTEST plan: %s' % plan_rows(u, groups))
        print('SELFTEST OK'); return 0
    finally:
        shutil.rmtree(w, ignore_errors=True)


def main():
    if '--selftest' in sys.argv:
        return selftest()
    ap = argparse.ArgumentParser()
    ap.add_argument('verb', choices=['plan', 'apply', 'measure'])
    ap.add_argument('src')
    ap.add_argument('--root', default=os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP')))
    ap.add_argument('--target', type=int, default=700)
    ap.add_argument('--since', default='60 days ago')
    ap.add_argument('--manifest')
    ap.add_argument('--dir')
    ap.add_argument('--prefix', default='')
    ap.add_argument('--head')
    ap.add_argument('--keep', action='store_true')
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    cc, flags = flags_for(root, a.src)
    if flags is None:
        print('REFUSE(2): %s has no compile line in %s' % (a.src, root)); return 2
    cplus = a.src.endswith(('.cpp', '.cc'))
    u = Unit(a.src, flags, cplus)
    if a.verb == 'plan':
        groups = plan(u, a.target, root, a.since)
        for n, p in plan_rows(u, groups):
            print('%s\t%s' % (n, p))
        print('PLAN_BOARD %s' % ' '.join('%s=%s' % kv for kv in measure(u, groups, root, a.since).items()), file=sys.stderr)
        return 0
    if not a.manifest:
        print('REFUSE(2): %s needs --manifest' % a.verb); return 2
    if a.verb == 'measure':
        rows = [tuple(l.rstrip('\n').split('\t')[:2]) for l in open(a.manifest) if l.strip() and not l.startswith('#')]
        pieces, poc, _ = assign(u, rows)
        groups = [(p, [i for i, q in poc.items() if q == p and any(id(c) == i and c['fns'] for c in u.ch)]) for p in pieces]
        print('PLAN_BOARD %s' % ' '.join('%s=%s' % kv for kv in measure(u, groups, root, a.since).items()))
        return 0
    if not a.dir:
        print('REFUSE(2): apply needs --dir'); return 2
    head = a.head or (a.prefix + 'head.h')
    pieces, ex, rel_head, headers = apply(u, a.manifest, a.dir, a.prefix, head, os.path.join(root, 'src'), cplus)
    if not a.keep:
        os.remove(a.src)
    print('SPLIT %s -> %d pieces, %d export headers, %s; exported %d' % (os.path.relpath(a.src, root), len(pieces), len(headers), rel_head, len(ex)))
    for p in pieces + headers:
        print('PIECE %s' % os.path.relpath(p, root))
    return 0


if __name__ == '__main__':
    sys.exit(main())
