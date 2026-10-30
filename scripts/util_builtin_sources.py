#!/usr/bin/env python3
# util_builtin_sources.py [--names SOURCE] [--root SCRIP] -- THE BUILTIN NAMES THE SCRIP SOURCES SPELL TODAY, SOURCE BY SOURCE (DESIGN-PLAN builtin-table step 1,
# ARCH-BUILTIN-TABLE.md section 3 "THE SOURCES THE FIRST CUT HARVESTS"; CEO-2016).
#
# The table harness/scripts/builtins.tsv is the one statement of what a builtin is. Until the chains are deleted (steps 2 to 6) the names also live in the places below; this reads
# each place as TEXT (nothing is compiled or run) so the gate can prove THE UNION: every name any source spells has a row. A source that no longer exists in the tree (a later step
# deleted it) reads as absent and is skipped, never as a failure; a source that exists and yields NOTHING is a defect of this reader and exits 2.
#
#   dop_direct   the emitter's registry, src/emitter/emit.cpp dop_direct_fp: { "name", arity, "sym", fp }         (name, arity, entry)
#   bn_direct    src/runtime/by_name_dispatch.c g_bn_direct: [BID_X] = { fn, op, 0 }                                (name via builtin_ids.h, entry, op)
#   icn_tbl      by_name_dispatch.c icn_bi_tbl: { "name", np }                                                       (name, arity)
#   icn_known    by_name_dispatch.c icn_builtin_is_known: icn_known[][9]
#   icn_gen      by_name_dispatch.c icn_builtin_is_generator and rt_builtin_is_generator
#   rt_known     by_name_dispatch.c rt_builtin_is_known: known[][24]
#   ids          src/runtime/builtin_ids.h: the BID_ macros and g_bid_tab                                           (name, id)
#   fn_arms      every strcmp(fn, "...") of by_name_dispatch.c
#   meth_arms    every strcmp(meth, "...") of by_name_dispatch.c                                                      (the receiver methods)
#   pas          src/runtime/pas_bi_names.h: PBI_<id> is the builtin __pas_<id>
#   rk_targets   every "__rk_..." and "rk_..." string src/lower/lower_raku.c spells
#   pl_leaf      src/lower/lower_call_forms.c pl_leaf_kind: the inline Prolog kinds ($mkc, $ax_<op>, $cmp_<c>, $atop_<c>, $<type>, ...)
# An empty string is a table terminator, never a name.
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CSTR = r'"((?:[^"\\]|\\.)*)"'


def unesc(s):
    return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t', '0': '\0'}.get(m.group(1), m.group(1)), s)


def read(root, rel):
    p = os.path.join(root, 'src', rel)
    return open(p, encoding='utf-8', errors='replace').read() if os.path.exists(p) else None


def func_body(text, head_re):
    m = re.search(head_re, text, re.M)
    if not m:
        return None
    i = text.index('{', m.end() - 1) if text[m.end() - 1] != '{' else m.end() - 1
    depth, j = 0, i
    while j < len(text):
        c = text[j]
        if c == '"':
            j += 1
            while text[j] != '"':
                j += 2 if text[j] == '\\' else 1
        elif c == "'":
            j += 1
            while text[j] != "'":
                j += 2 if text[j] == '\\' else 1
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
        j += 1
    return None


def ids_table(root):
    t = read(root, 'runtime/builtin_ids.h')
    if t is None:
        return None
    macros = {m.group(1): int(m.group(2)) for m in re.finditer(r'^#define (BID_\w+) (\d+)\s*$', t, re.M) if m.group(1) != 'BID_TABSZ'}
    if 'g_bid_tab' not in t:
        return macros, None
    tab = [(unesc(m.group(1)), int(m.group(3))) for m in re.finditer(r'\{\s*' + CSTR + r'\s*,\s*(\d+)\s*,\s*(\d+)\s*\}', t)]
    if sorted(i for _, i in tab) != sorted(macros.values()):
        print('util_builtin_sources: builtin_ids.h g_bid_tab holds %d entries but %d BID_ macros are defined -- the reader is out of date with the tree' % (len(tab), len(macros)), file=sys.stderr)
        sys.exit(2)
    return macros, tab


def sanitize(name):
    out = ''.join(c if (c.isalnum() or c == '_') else 'x%02X' % ord(c) for c in name)
    return ('_' + out) if out and out[0].isdigit() else out


def legacy_names():
    """Once builtin_ids.h no longer holds its own name table (step 1 moved it into builtins.tsv), the legacy names are the table's rows that carry the ids source: {sanitized: name}."""
    out = {}
    p = os.path.join(HERE, 'builtins.tsv')
    if os.path.exists(p):
        for ln in open(p, encoding='utf-8'):
            f = ln.rstrip('\n').split('\t')
            if len(f) >= 11 and f[0].isdigit() and 'ids' in f[10].split(','):
                out[sanitize(f[2])] = f[2]
    return out


def src_dop_direct(root):
    t = read(root, 'emitter/emit.cpp')
    b = func_body(t, r'^void \* dop_direct_fp\(') if t else None
    if b is None:
        return None
    return [(unesc(m.group(1)), int(m.group(2)), m.group(3)) for m in re.finditer(r'\{\s*' + CSTR + r',\s*(-?\d+),\s*' + CSTR + r',\s*\w+\s*\}', b) if m.group(1)]


def src_bn_direct(root):
    t, ids = read(root, 'runtime/by_name_dispatch.c'), ids_table(root)
    if t is None or ids is None:
        return None
    m = re.search(r'const bn_direct_t g_bn_direct\[BID_TABSZ\] = \{', t)
    if not m:
        return None
    i, depth, j = m.end() - 1, 0, m.end() - 1
    while True:
        depth += (t[j] == '{') - (t[j] == '}')
        if depth == 0:
            break
        j += 1
    nm = {i2: n for n, i2 in ids[1]} if ids[1] is not None else legacy_names()
    out = []
    for e in re.finditer(r'\[(BID_\w+)\]\s*=\s*\{\s*(?:\(\s*int\s*\(\*\)\([^)]*\)\s*\)\s*)?(\w+)\s*,\s*(-?\w+)', t[i:j]):
        out.append((nm.get(ids[0].get(e.group(1)), nm.get(e.group(1)[4:], e.group(1))), e.group(2), e.group(3)))
    return out


def src_icn_tbl(root):
    t = read(root, 'runtime/by_name_dispatch.c')
    b = func_body(t, r'^static const icn_bi_ent_t \*icn_bi_tbl\(void\)') if t else None
    return None if b is None else [(unesc(m.group(1)), int(m.group(2))) for m in re.finditer(r'\{' + CSTR + r',\s*(-?\d+)\}', b)]


def src_icn_known(root):
    t = read(root, 'runtime/by_name_dispatch.c')
    b = func_body(t, r'^int icn_builtin_is_known\(const char \*name\)') if t else None
    if b is None:
        return None
    m = re.search(r'icn_known\[\]\[9\] = \{(.*?)\};', b, re.S)
    return [unesc(x) for x in re.findall(CSTR, m.group(1)) if x] if m else []


def src_gen(root):
    t = read(root, 'runtime/by_name_dispatch.c')
    if t is None:
        return None
    out = set()
    for h in (r'^int rt_builtin_is_generator\(const char \*name\)', r'^int icn_builtin_is_generator\(const char \*name\)'):
        b = func_body(t, h)
        out.update(unesc(x) for x in re.findall(r'strcmp\(name,\s*' + CSTR + r'\)', b or ''))
    return sorted(out) if out else None


def src_rt_known(root):
    t = read(root, 'runtime/by_name_dispatch.c')
    b = func_body(t, r'^int rt_builtin_is_known\(const char \*name\)') if t else None
    if b is None:
        return None
    out = []
    for m in re.finditer(r'known\[\]\[24\] = \{(.*?)\};', b, re.S):
        out += [unesc(x) for x in re.findall(CSTR, m.group(1)) if x]
    return out


def src_ids(root):
    r = ids_table(root)
    return None if (r is None or r[1] is None) else sorted(r[1], key=lambda x: x[1])


def src_arms(root, var):
    t = read(root, 'runtime/by_name_dispatch.c')
    if t is None:
        return None
    return sorted({unesc(m.group(1)) for m in re.finditer(r'strcmp\(' + var + r',\s*' + CSTR + r'\)', t) if m.group(1)})


def src_pas(root):
    t = read(root, 'runtime/pas_bi_names.h')
    if t is None:
        return None
    m = re.search(r'enum pas_bi_id \{(.*?)\}', t, re.S)
    return ['__pas_' + x for x in re.findall(r'PBI_(\w+)', m.group(1)) if x != 'COUNT' and x != 'N'] if m else []


def src_rk_targets(root):
    t = read(root, 'lower/lower_raku.c')
    return None if t is None else sorted({unesc(x) for x in re.findall(r'"((?:__)?rk_[A-Za-z0-9_]*)"', t)} - {'__rk_', 'rk_'})


def src_pl_leaf(root):
    t = read(root, 'lower/lower_call_forms.c')
    if t is None:
        return None
    ax = func_body(t, r'^static int pl_ax_arity\(const char \* op\)') or ''
    arity = {}
    for var, n in (('b2', 2), ('b1', 1), ('b0', 0)):
        m = re.search(r'\*\s*const\s+' + var + r'\[\]\s*=\s*\{(.*?)\}', ax, re.S)
        for x in re.findall(CSTR, m.group(1) if m else ''):
            arity[unesc(x)] = n
    k = func_body(t, r'^int pl_leaf_kind\(const char \* fn, int narg, const char \*\* op\)') or ''
    mc, mt = re.search(r'cmps\[\]\s*=\s*\{(.*?)\}', k, re.S), re.search(r'types\[\]\s*=\s*\{(.*?)\}', k, re.S)
    cmps = [unesc(x) for x in re.findall(CSTR, mc.group(1))] if mc else []
    types = [unesc(x) for x in re.findall(CSTR, mt.group(1))] if mt else []
    out = [(unesc(x), None) for x in re.findall(r'strcmp\(fn,\s*' + CSTR + r'\)', k) if x != '$ax_eguard']
    out += [('$ax_' + op, n) for op, n in sorted(arity.items())]
    out += [('$cmp_' + c, 2) for c in cmps] + [('$atop_' + c, 2) for c in cmps] + [('$' + ty, 1) for ty in types]
    return out


SOURCES = {
    'dop_direct': src_dop_direct, 'bn_direct': src_bn_direct, 'icn_tbl': src_icn_tbl, 'icn_known': src_icn_known, 'icn_gen': src_gen, 'rt_known': src_rt_known,
    'ids': src_ids, 'fn_arms': lambda r: src_arms(r, 'fn'), 'meth_arms': lambda r: src_arms(r, 'meth'), 'pas': src_pas, 'rk_targets': src_rk_targets, 'pl_leaf': src_pl_leaf,
}


def names_of(rec):
    return rec[0] if isinstance(rec, tuple) else rec


def collect(root):
    """{source: records or None when the source is gone}; exits 2 when a source that exists yields nothing."""
    out = {}
    for k, f in SOURCES.items():
        r = f(root)
        if r is not None and len(r) == 0:
            print('util_builtin_sources: source %s exists and yields no names -- the reader is out of date with the tree' % k, file=sys.stderr)
            sys.exit(2)
        out[k] = r
    return out


def main(argv):
    root = os.path.join(HERE, '..', '..', 'SCRIP')
    if '--root' in argv:
        root = argv[argv.index('--root') + 1]
    got = collect(root)
    if '--names' in argv:
        for r in got.get(argv[argv.index('--names') + 1]) or []:
            print('\t'.join(str(x) for x in (r if isinstance(r, tuple) else (r,))))
        return 0
    allnames = set()
    for k, r in got.items():
        if r is None:
            print('%-11s absent' % k)
            continue
        ns = {names_of(x) for x in r}
        allnames |= ns
        print('%-11s records=%-4d distinct=%d' % (k, len(r), len(ns)))
    print('union of distinct names: %d' % len(allnames))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
