#!/usr/bin/env python3
"""util_lifetime_triage.py ROOT [DIR...] -- triage every heap allocation site in C/C++ sources by where its pointer goes.

Lon 2026-09-28: memory whose lifetime is a program construct belongs on the stack; memory that outlives the scope that
created it belongs on the heap.  This script only TRIAGES: for each allocation call it finds the enclosing function and
follows the variable the result is assigned to, then prints one TSV row per site with a class:
  RETURNED    the allocation (or the variable holding it) is returned              -> escapes the call
  STORED      the allocation lands in a field, an array element, a global, or a pointer target -> escapes the call
  FREED       the variable is ct_drop()ed / free()d in the same function          -> call-scoped (candidate violation)
  LOCAL       the variable is only read locally or handed to copying/reading calls -> call-scoped (candidate violation)
  PASSED      the variable (or the call itself) is handed to another function      -> read the callee to decide
Every FREED, LOCAL and PASSED row is read by hand; RETURNED and STORED rows are read only where the returned value's own
caller might drop it at once.
"""
import re, sys, os

ALLOC = ['rt_gcheap_alloc', 'rt_ws_alloc_descr', 'rt_wsb_alloc', 'rt_wsb_realloc', 'rt_pvec_alloc', 'rt_pvec_realloc',
         'rt_heap_strdup_c', 'rt_heap_alloc_c', 'rt_str_alloc', 'rt_str_dup', 'rt_gc_alloc_str', 'rt_pm_struct_alloc',
         'rt_pl_struct_alloc', 'rt_gcheap_grow_block', 'rt_arena_alloc', 'rt_agg_alloc', 'rt_env_alloc', 'rt_cs_new',
         'rt_pl_choice_new', 'gv_push', 'gv_reserve', 'PL_CELL_ALLOC', 'ct_alloc', 'ct_grow', 'ct_strdup', 'malloc',
         'calloc', 'realloc', 'strdup', 'rt_slab_region', 'rt_slab_get']
ALLOC_RE = re.compile(r'(?<![A-Za-z0-9_])(' + '|'.join(map(re.escape, ALLOC)) + r')\s*\(')
READERS = set('''memcpy memmove memset memcmp strcpy strncpy strcat strncat snprintf sprintf vsnprintf strlen strcmp strncmp
strchr strrchr strstr fputs fputc fprintf printf fwrite fread fgets puts qsort bsearch pl_mk_atom_dup prolog_atom_intern
prolog_atom_intern_n strtol strtoll strtoul strtoull strtod atoi atol rt_pl_u8_put rt_pl_u8_get utf8_strlen tolower toupper
isalpha isdigit isspace ct_drop free sizeof rt_bomb abort exit'''.split())
FREERS = {'ct_drop', 'free'}

def strip_literals(line):
    return re.sub(r"'(?:\\.|[^'\\])'", "' '", re.sub(r'"(?:\\.|[^"\\])*"', '""', line))

def functions(lines):
    """yield (start, end) spans between the separator lines the C style puts between every pair of functions."""
    cuts = [-1] + [i for i, l in enumerate(lines) if l.startswith('/*---') or l.startswith('/*===')] + [len(lines)]
    for a, b in zip(cuts, cuts[1:]):
        if b - a > 1: yield (a + 1, b - 1)

def fn_name(lines, start, i=None):
    for j in range(i if i is not None else start, start - 1, -1):
        if re.match(r'^(PL_[A-Z_]*LEAF[A-Z_]*|static|[A-Za-z_][A-Za-z0-9_ \*]*\b[A-Za-z_][A-Za-z0-9_]*\s*\([^;]*\)\s*\{)', lines[j]) and not lines[j].startswith(' '):
            m = re.search(r'(PL_[A-Z_]*LEAF[A-Z_]*\(\s*[A-Za-z0-9_]+|[A-Za-z_][A-Za-z0-9_]*)\s*\(', lines[j])
            if m: return m.group(1).replace(' ', '')
    for j in range(start, max(-1, start - 4), -1):
        m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*\{?\s*$', strip_literals(lines[j]).split('{')[0] + ('{' if '{' in lines[j] else ''))
        m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(', strip_literals(lines[j]))
        if m and m.group(1) not in ('if', 'for', 'while', 'switch', 'return', 'sizeof'): return m.group(1)
    return '?'

def classify(body, idx_in_body, line):
    t = strip_literals(line)
    m = ALLOC_RE.search(t); pos = m.start()
    before = t[:pos]
    if re.search(r'\breturn\b[^;]*$', before): return ('RETURNED_PTR' if RET_PTR else 'RETURNED'), ''
    am = re.search(r'([A-Za-z_][A-Za-z0-9_]*(?:\s*(?:->|\.)\s*[A-Za-z_][A-Za-z0-9_]*|\s*\[[^\]]*\])*)\s*=\s*(?:\([^()]*\)\s*)*$', before)
    if not am:
        if re.search(r'[A-Za-z0-9_]\s*\($', before.rstrip()) or re.search(r'[A-Za-z_][A-Za-z0-9_]*\s*\([^()]*$', before):
            return 'PASSED', 'call argument'
        return 'PASSED', 'unparsed'
    lhs = am.group(1).strip()
    if re.search(r'->|\.|\[', lhs) or before.rstrip().endswith('*'):
        base = re.match(r'\*?\s*([A-Za-z_][A-Za-z0-9_]*)', lhs).group(1)
        whole0 = '\n'.join(strip_literals(x) for x in body)
        if re.search(r'\b(?:[A-Za-z_]\w*_t|struct\s+\w+|char|int|long|size_t|DESCR_t|const\s+char)\s+(?!\*)' + re.escape(base) + r'\s*(?:\[|=|;|,)', whole0):
            return 'STORED_LOCAL', lhs + ' (a local aggregate: follow it)'
        return 'STORED', lhs
    var = lhs
    whole = '\n'.join(strip_literals(x) for x in body)
    declared = re.search(r'(?:\b(?:char|int|long|size_t|DESCR_t|void|uint\d+_t|int\d+_t|unsigned|double|const|struct\s+\w+|[A-Za-z_]\w*_t|[A-Z][A-Z0-9_]*_t)\b[\s\*]*|,\s*\**\s*|\(\s*[^()]*\*\s*)' + r'(?<![A-Za-z0-9_])' + re.escape(var) + r'\s*(?:=|;|,|\[|\))', whole)
    if not declared: return 'STORED', var + ' (a global)'
    rest = '\n'.join(strip_literals(x) for x in body[idx_in_body:])
    rest = rest[rest.find(ALLOC_RE.search(rest).group(0)) + 1:] if ALLOC_RE.search(rest) else rest
    w = r'(?<![A-Za-z0-9_])' + re.escape(var) + r'(?![A-Za-z0-9_])'
    if re.search(r'\breturn\b[^;]*' + w, rest): return ('RETURNED_PTR' if RET_PTR else 'RETURNED'), var
    if re.search(r'(?:->|\.|\])\s*[A-Za-z0-9_]*\s*=\s*(?:\([^()]*\)\s*)*[^;=]*' + w, rest) or re.search(r'\*\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*[^;=]*' + w, rest):
        return 'STORED', var + ' (assigned into a field/pointer)'
    for am2 in re.finditer(r'(?<![A-Za-z0-9_\.>])([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)\s*(?:\([^()]*\)\s*)*([^;]*)', rest):
        tgt, rhs = am2.group(1), am2.group(2)
        if tgt == var or not re.search(w, rhs): continue
        if not re.search(r'(?<![A-Za-z0-9_])' + re.escape(tgt) + r'\s*(?:=|;|,|\[)', whole[:whole.find(rhs)] if rhs in whole else whole) or not re.search(r'\b(?:char|int|long|size_t|DESCR_t|void|const|unsigned|[A-Za-z_]\w*_t)\b[\s\*]*' + re.escape(tgt) + r'\b', whole):
            return 'STORED', var + ' -> ' + tgt + ' (a global)'
    freed = any(re.search(re.escape(f) + r'\s*\(\s*(?:\([^()]*\)\s*)?' + w, rest) for f in FREERS)
    callees = set()
    for cm in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(([^;]*)', rest):
        if re.search(w, cm.group(2).split(')')[0] if ')' in cm.group(2) else cm.group(2)) and cm.group(1) not in ('if', 'for', 'while', 'switch', 'return'):
            callees.add(cm.group(1))
    other = sorted(c for c in callees if c not in READERS and not ALLOC_RE.match(c + '('))
    if freed: return 'FREED', var + ('; also passed to ' + ','.join(other) if other else '')
    if other: return 'PASSED', var + ' -> ' + ','.join(other[:6])
    return 'LOCAL', var

RET_PTR = False
def main():
    root = sys.argv[1]; dirs = sys.argv[2:] or ['src']
    for d in dirs:
        for dp, dn, fns in os.walk(os.path.join(root, d)):
            for fn in sorted(fns):
                if not fn.endswith(('.c', '.cpp', '.h')) or fn.endswith('.tab.c'): continue
                p = os.path.join(dp, fn); lines = open(p, encoding='utf-8', errors='replace').read().split('\n')
                spans = list(functions(lines))
                for i, line in enumerate(lines):
                    t = strip_literals(line)
                    if not ALLOC_RE.search(t) or re.match(r'\s*(extern|#define|typedef)\b', t): continue
                    if re.search(r'^[A-Za-z_].*\b(' + '|'.join(ALLOC) + r')\s*\([^)]*\)\s*\{?\s*$', t) and '=' not in t: continue
                    span = next(((s, e) for s, e in spans if s <= i <= e), None)
                    if not span: continue
                    body = lines[span[0]:span[1] + 1]
                    global RET_PTR
                    hd = next((lines[j] for j in range(i, span[0] - 1, -1) if re.match(r'^[A-Za-z_]', lines[j])), '')
                    RET_PTR = bool(re.match(r'^static\s+(?:inline\s+)?(?:const\s+)?(?:char|int|long|size_t|void|uint\w+|int\w+|DESCR_t|const\s+char)\s*\*+\s*\**\s*[A-Za-z_]', hd))
                    cls, why = classify(body, i - span[0], line)
                    print('%s:%d\t%s\t%s\t%s\t%s' % (os.path.relpath(p, root), i + 1, fn_name(lines, span[0], i), ALLOC_RE.search(t).group(1), cls, why))

main()
