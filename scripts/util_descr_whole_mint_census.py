#!/usr/bin/env python3
# util_descr_whole_mint_census.py -- census every C site under src/ that builds a DESCR_t FIELD BY FIELD from an
# UNINITIALISED declaration (cfo 2026-10-01, the class behind SCRIP 770ff507d).
#
# WHY: DESCR_t is {v:1, src_node0..2:3, slen:4, ptr:8}.  `DESCR_t r; r.v = DT_DATA; r.slen = 0; r.u = inst;` writes
# 13 of its 16 bytes and leaves src_node0..2 as whatever the stack slot held.  Nothing in the shipping runtime reads
# src_node, so the value is "right" -- but WORD 0 IS READ WHOLE: the one-stack census (SCRIP_GC_SWEEP16) classifies a
# unit by its first word, and dat_alloc_fill's garbage 0x700010 made a legal record cell read 0x70001070, GVA slot 7's
# own address ("stack"), in vscroll_driver.icn's GVA at 1191 of 1833 collections (the cto's bisect to 99d429d4c, which
# had only changed WHAT garbage the collector leaves on the stack).  A dword tag compare in an asm fast path
# (rtx_icnsub.s: cmp dword ptr [r9 + FIELD0_V], DT_DATA) reads the same bytes and sends such a value to the slow road.
#
# WHAT IS COUNTED: a declaration `DESCR_t a;` / `DESCR_t a, b;` with no initialiser, INSIDE A FUNCTION BODY (a struct or
# union member is never counted -- it cannot carry an initialiser), whose FIRST use after the declaration is a field
# store `a.<field> = ...`, and which is not followed by descr_set_src_node(&a, ...) before that use's statement ends.
# C files only: C++ forbids a jump past an initialised declaration, so --apply would be unsafe there, and no .cpp site
# has the shape today (the census prints the .cpp count it skipped).
# WHAT IS NOT: `DESCR_t a = x;`, `DESCR_t a = {0};`, a compound literal, an array `DESCR_t a[3];`, a declaration whose
# first use is a whole assignment `a = f();` or an address-of `&a`.
#
# USAGE:  util_descr_whole_mint_census.py            prints every site and `DESCR-WHOLE-MINT sites=N`; rc 1 if N > 0
#         util_descr_whole_mint_census.py --apply    rewrites each counted declarator to `a = {0}` (src_node 0, UNSTAMPED)
#         util_descr_whole_mint_census.py --selftest planted sites in both directions; FAIL_ONCE=1 must turn arms red
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
DECL = re.compile(r'\bDESCR_t\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*;')


LIT = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', re.S)


def blank_literals(t):
    """comments and string/char literals blanked to spaces, newlines kept, so offsets and line numbers are unchanged."""
    return LIT.sub(lambda m: re.sub(r'[^\n]', ' ', m.group(0)), t)


def body_kinds(code, offsets):
    """kind of the innermost open brace at each offset in `offsets` (ascending): 'F' inside a function or block body,
    'S' inside a struct, union, enum or initialiser list, None at file scope.  It steps from brace to brace, never
    character by character, so a census of all of src/ stays inside a preflight arm's ceiling."""
    out, stack, k = {}, [], 0
    for b in re.finditer(r'[{}]', code):
        i = b.start()
        while k < len(offsets) and offsets[k] < i:
            out[offsets[k]] = stack[-1] if stack else None; k += 1
        if code[i] == '{':
            head = code[max(0, i - 120):i].rstrip()
            agg = re.search(r'(\bstruct|\bunion|\benum)\b[^;{}()]*$', head) or head.endswith('=') or head.endswith(',') or (head.endswith('{') and stack and stack[-1] == 'S')
            stack.append('S' if agg else ('F' if (stack and stack[-1] == 'F') or head.endswith(')') or re.search(r'\b(else|do)$', head) else 'S'))
        elif stack:
            stack.pop()
    while k < len(offsets):
        out[offsets[k]] = stack[-1] if stack else None; k += 1
    return out


def sites_in(text, fail_once=False):
    code = blank_literals(text); ms = list(DECL.finditer(code)); kinds = body_kinds(code, [m.start() for m in ms]); out = []
    for m in ms:
        if kinds[m.start()] != 'F':
            continue
        for nm in [x.strip() for x in m.group(1).split(',')]:
            rest = code[m.end():m.end() + 4000]
            u = re.search(r'\b' + re.escape(nm) + r'\b', rest)
            if not u:
                continue
            tail = rest[u.end():]
            if not re.match(r'\s*\.\s*[A-Za-z_]\w*\s*=(?!=)', tail):
                continue
            stmt = rest[:u.start() + 400]
            if not fail_once and re.search(r'descr_set_src_node\s*\(\s*&\s*' + re.escape(nm) + r'\b', stmt):
                continue
            out.append((text.count('\n', 0, m.start()) + 1, nm, m.start(), m.end()))
    return out


def scan(root, fail_once=False):
    sites, cpp = [], 0
    for d, _, fs in os.walk(os.path.join(root, 'src')):
        for f in sorted(fs):
            p = os.path.join(d, f)
            if f.endswith('.cpp'):
                try: cpp += len(sites_in(open(p, encoding='utf-8', errors='replace').read()))
                except OSError: pass
                continue
            if not f.endswith('.c'):
                continue
            try: t = open(p, encoding='utf-8', errors='replace').read()
            except OSError as e:
                print("⛔ REFUSE(2): cannot read %s -- %s" % (p, e)); sys.exit(2)
            for ln, nm, a, b in sites_in(t, fail_once):
                sites.append((os.path.relpath(p, root), ln, nm, a, b))
    return sites, cpp


def apply(root):
    sites, _ = scan(root); byf = {}
    for f, ln, nm, a, b in sites:
        byf.setdefault(f, []).append((a, b, nm))
    for f, lst in byf.items():
        p = os.path.join(root, f); t = open(p, encoding='utf-8').read()
        for a, b, nm in sorted(set(lst), key=lambda x: (-x[0], x[2])):
            seg = t[a:b]; seg2 = re.sub(r'\b' + re.escape(nm) + r'\b(?!\s*=)', nm + ' = {0}', seg, count=1); t = t[:a] + seg2 + t[b:]
        open(p, 'w', encoding='utf-8').write(t)
    print("DESCR-WHOLE-MINT applied: %d declarator(s) in %d file(s)" % (len(sites), len(byf)))


def selftest():
    fail_once = os.environ.get('FAIL_ONCE') == '1'
    plants = [
        ('field_by_field',  'DESCR_t f(void) { DESCR_t r; r.v = 3; r.slen = 0; r.i = 1; return r; }\n', 1),
        ('two_declarators', 'void g(void) { DESCR_t a, b; a.v = 2; b = a; }\n', 1),
        ('stamped',         'DESCR_t h(void) { DESCR_t d; d.v = 3; descr_set_src_node(&d, 0); d.slen = 0; return d; }\n', 0),
        ('initialised',     'DESCR_t k(void) { DESCR_t d = {0}; d.v = 3; return d; }\n', 0),
        ('whole_assign',    'DESCR_t m(void) { DESCR_t d; d = n(); d.v = 3; return d; }\n', 0),
        ('struct_member',   'typedef struct { DESCR_t key_d; long pos; } VC;\nvoid q(VC *v) { v->key_d.v = 0; }\n', 0),
        ('in_a_string',     'const char *s = "DESCR_t r; r.v = 3;";\n', 0),
    ]
    bad = 0
    for name, text, want in plants:
        got = len(sites_in(text, fail_once)); ok = got == want; bad += 0 if ok else 1
        print("    %-4s %-16s want %d read %d" % ('ok' if ok else 'RED', name, want, got))
    if fail_once:
        if bad: print("  SELFTEST FAIL-ONCE PROVED: %d arm(s) went red with the descr_set_src_node exemption removed" % bad); return 0
        print("  ⛔ SELFTEST FAIL-ONCE DID NOT TRIP"); return 1
    print("  SELFTEST: %d arm(s), %d red" % (len(plants), bad)); return 1 if bad else 0


if __name__ == '__main__':
    if '--selftest' in sys.argv[1:]: sys.exit(selftest())
    if '--apply' in sys.argv[1:]: apply(ROOT); sys.exit(0)
    sites, cpp = scan(ROOT)
    for f, ln, nm, _, _ in sites:
        print("  SITE %s:%d %s" % (f, ln, nm))
    print("DESCR-WHOLE-MINT sites=%d (C files under src/; %d C++ site(s) of the same shape skipped, never applied)" % (len(sites), cpp))
    sys.exit(1 if sites else 0)
