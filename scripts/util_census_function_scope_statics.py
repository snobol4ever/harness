#!/usr/bin/env python3
# util_census_function_scope_statics.py -- census EVERY function-scope mutable `static` under src/.
#
# Row: census-function-scope-mutable-statics-under-src (minted hq_P, FLEET-16, on RULES.md line 169's
# clarification that a function-scope mutable static is "or equivalent" under NO-NEW-GLOBALS).
#
# WHY A REAL SCANNER AND NOT `grep '^\s+static'`: this codebase's C style crams a whole function body
# (signature + locals + logic) onto ONE physical line under the 200-char/zero-blank-line convention --
# e.g. `static int zd_omega_test_kind(IR_e op) { static int _tf = -1; ... }` in src/ir/zeta_depth.c.
# The file-scope FUNCTION's own `static` sits at column 0; the function-LOCAL static a few tokens later
# on the SAME line is what this row exists to find, and a leading-indentation grep cannot see it (it is
# not the first token on its line). So this walks a real brace-depth stack after stripping comments and
# string/char literals, and only reports a `static` token whose enclosing scope is a FUNCTION BODY.
#
# TWO-DIRECTION PROOF (RULES.md TWO-PART-PROOF FACT RULE): run with --selftest to inject one deliberate
# function-scope mutable static into a scratch file, prove the scanner catches it (CAN say yes), and
# prove a column-0 file-scope static and a `static const` scalar are both correctly excluded (CAN say no).
#
# KNOWN BLIND SPOTS (stated, not hidden -- INSTRUMENT LAWS batch 15): (1) a static introduced via a
# macro body is invisible to a textual scan of the expansion site -- none exist under src/ as of this
# writing (checked: `grep -rn '#define.*\bstatic\b' src/` is empty), so this is a live but currently
# UNPOPULATED blind spot, not a false all-clear. (2) mutability classification is a heuristic over the
# declarator text (see classify()) -- it is verified against the emit.cpp/zeta_storage.c ground truth
# this row was minted from, not proven exhaustive over every declarator shape in the tree.
import sys, os, re, argparse

SRC_EXTS = ('.c', '.cpp', '.h', '.hpp', '.cc', '.hh')
IDENT_RE = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')

def strip_comments_and_literals(text):
    """Replace comment/string/char contents with spaces (same length, same line/col), so a later
    character-by-character scan sees only real code but line numbers and offsets are unchanged."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i+1] == '/':
            j = text.find('\n', i)
            j = n if j == -1 else j
            out.append(' ' * (j - i)); i = j
        elif c == '/' and i + 1 < n and text[i+1] == '*':
            j = text.find('*/', i + 2)
            j = n if j == -1 else j + 2
            seg = text[i:j]
            out.append(''.join(ch if ch == '\n' else ' ' for ch in seg)); i = j
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            j = min(j + 1, n)
            seg = text[i:j]
            out.append(''.join(ch if ch == '\n' else ' ' for ch in seg)); i = j
        elif c == "'":
            j = i + 1
            while j < n and text[j] != "'":
                j += 2 if text[j] == '\\' else 1
            j = min(j + 1, n)
            seg = text[i:j]
            out.append(''.join(ch if ch == '\n' else ' ' for ch in seg)); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)

FUNC_DISQUALIFY = re.compile(r'\b(struct|union|enum|class|namespace|typedef)\b')

def looks_like_function_opener(preceding_text):
    """preceding_text: code since the last depth-0 statement boundary, up to (not incl.) this '{'.
    True => this '{' opens a function BODY. False => struct/union/enum/class/namespace/initializer."""
    t = preceding_text.strip()
    if not t:
        return False
    if t.rstrip().endswith('='):          # `T x[] = {`  or  `T x = {`
        return False
    if FUNC_DISQUALIFY.search(t):         # struct Foo {, enum E {, namespace N {, typedef struct {
        return False
    # a function definition's tail is always `... ) [K&R-attrs]` ending right before '{'
    return t.rstrip().endswith(')') or bool(re.search(r'\)\s*[A-Za-z_][A-Za-z0-9_]*\s*$', t))

EXTERN_C_RE = re.compile(r'\bextern\s*"C"\s*$')

def scan_file(path, rel):
    raw = open(path, encoding='utf-8', errors='replace').read()
    code = strip_comments_and_literals(raw)
    n = len(code)
    line_of = []  # offset -> line number, built lazily via cumulative newline count
    # `boundary_start`: offset where the text-since-last-statement-boundary began. A stack of
    # frames tracks brace nesting. Frame kinds: 'FUNC' (inside a function body), 'OTHER'
    # (struct/enum/init/etc, nested statics inside these are not function-scope and are not
    # reachable in valid C/C++ anyway), 'TRANSPARENT' (extern "C" { ... } -- behaves exactly like
    # depth 0 for openers inside it).
    # ⛔ `preceding` (used to decide whether a '{' opens a FUNCTION) is sliced from RAW, not from
    # the comment/literal-stripped `code`: strip_comments_and_literals blanks a string literal's
    # QUOTES along with its contents, so `extern "C" {` becomes `extern     {` in `code` and a
    # regex looking for the literal text `"C"` can never match post-strip. Measured: this silently
    # defeated EXTERN_C_RE entirely (0 matches, ever), which combined with the effective_top() fix
    # above to still leave every function inside emit.cpp's file-spanning `extern "C" { ... }`
    # tagged OTHER via the disqualifying "extern" text having no ')' tail. Slicing from `raw`
    # restores the quotes so the regex can see them.
    stack = []
    boundary_start = 0
    hits = []
    i = 0
    line_no = 1
    line_start_offsets = [0]
    for idx, ch in enumerate(raw):
        if ch == '\n':
            line_start_offsets.append(idx + 1)
    def lineno_at(offset):
        import bisect
        return bisect.bisect_right(line_start_offsets, offset)

    def top_is_func():
        for fr in reversed(stack):
            if fr == 'TRANSPARENT':
                continue
            return fr == 'FUNC'
        return False

    def effective_top():
        """Nearest non-TRANSPARENT frame, or None if the stack is empty or holds only
        TRANSPARENT frames -- i.e. we are at REAL depth 0 or nested only inside `extern "C" {`
        wrappers, which do not themselves create a scope for classification purposes."""
        for fr in reversed(stack):
            if fr == 'TRANSPARENT':
                continue
            return fr
        return None

    while i < n:
        ch = code[i]
        if ch == '{':
            preceding = raw[boundary_start:i]
            eff = effective_top()
            # ⛔ BUG FIXED (found on emit.cpp: nearly the WHOLE file lives inside one file-
            # spanning `extern "C" { ... }`, line 10 to line ~3767 -- the old code special-cased
            # TRANSPARENT only at the moment it was PUSHED, so once inside it every further `{`
            # fell into the "nested inside a non-function frame" branch and was hard-coded OTHER,
            # NEVER checking looks_like_function_opener again. That silently misclassified every
            # top-level function in the file as non-function and hid its locals from this census.
            # The fix: skip PAST any number of TRANSPARENT frames to find the nearest real one,
            # exactly as top_is_func() already does for the walking part; a `{` whose effective
            # context is "no real frame at all" is exactly as fresh as one at true depth 0, and
            # must be reclassified fresh, not defaulted to OTHER. ⛔ THIS FIX ALONE WAS STILL NOT
            # ENOUGH -- see EXTERN_C_RE's own note below for the second, independent bug it took
            # to actually move the needle (measured end-to-end: emit.cpp 2 hits -> 137, once BOTH
            # fixes landed together; this fix in isolation only got as far as 55, because
            # EXTERN_C_RE could not yet see the quoted "C" it was searching for).
            if eff == 'FUNC':
                stack.append('FUNC')            # nested block inside a function -> still function scope
            elif eff == 'OTHER':
                stack.append('OTHER')           # nested inside struct/enum/initializer -> stays non-function
            elif EXTERN_C_RE.search(preceding):
                stack.append('TRANSPARENT')     # extern "C" { -- transparent, re-evaluate what's inside fresh
            elif looks_like_function_opener(preceding):
                stack.append('FUNC')
            else:
                stack.append('OTHER')
            boundary_start = i + 1
            i += 1; continue
        if ch == '}':
            if stack:
                stack.pop()
            boundary_start = i + 1
            i += 1; continue
        if ch in (';',):
            boundary_start = i + 1
            i += 1; continue
        # identifier scan
        m = IDENT_RE.match(code, i)
        if m:
            word = m.group(0)
            if word == 'static' and top_is_func():
                # Reconstruct the declarator run: from here to the next ';' AT THE SAME NESTING
                # DEPTH the declaration started at. A plain scan for the next ';' breaks on the
                # `static const struct { const char * n; int code; } table[] = {...};` idiom --
                # the struct TYPE BODY's own field separators are semicolons too, at depth>0, and
                # stopping at the first one truncates the declaration and reports a struct FIELD
                # name ("n") as if it were the static variable. Track ([{ / )]} depth and only
                # accept a ';' at depth 0 as the terminator.
                depth = 0
                j = m.end()
                while j < n:
                    cj = code[j]
                    if cj in '([{':
                        depth += 1
                    elif cj in ')]}':
                        depth -= 1
                    elif cj == ';' and depth <= 0:
                        j += 1
                        break
                    j += 1
                end = j
                decl_text = re.sub(r'\s+', ' ', raw[m.start():end]).strip()
                hits.append((lineno_at(m.start()), decl_text, m.start()))
            i = m.end(); continue
        i += 1
    return hits

# ---- classification ---------------------------------------------------------------------------------
# A declarator's OWN binding is immutable iff `const` binds to the identifier itself: either a bare
# `const SCALAR name` with no '*' anywhere in the specifier (a true const value/array), or a `* const
# name` pointer (the pointer itself is const, regardless of what it points to). `const CHAR * name` /
# `CHAR const * name` (pointer-TO-const, no second const after the '*') is a MUTABLE pointer variable --
# exactly the `static const char * _zo;` shape in emit.cpp that is reassigned at line 2551 -- and must
# NOT be swept into "out of scope" just because the substring "const" appears in the line.
def split_declarators(decl_text):
    """Split one `static ... a, *b = x, c[8];` statement into per-name declarator strings, each
    still prefixed with the shared specifier (crude but sufficient: split on top-level commas)."""
    depth = 0; parts = []; cur = []
    body = decl_text[len('static'):].rstrip(';').strip()
    for ch in body:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(''.join(cur)); cur = []
        else:
            cur.append(ch)
    if cur:
        parts.append(''.join(cur))
    return [p.strip() for p in parts if p.strip()]

def strip_braced_regions(s):
    """Blank out every balanced {...} span (e.g. an inline struct/union TYPE BODY, or an array
    initializer) so a mutability check over the REMAINING top-level text is not contaminated by
    an unrelated '*' or 'const' belonging to a NESTED field -- the `const struct { const char * n;
    ... } table[]` shape: `table` itself is a const-qualified aggregate (C propagates const into
    every member of a const-qualified struct/array), but naively substring-searching the whole
    declarator finds the field's '*' and misses that it is not part of `table`'s own type."""
    out = []
    depth = 0
    for ch in s:
        if ch == '{':
            depth += 1; out.append(' ')
        elif ch == '}':
            depth = max(0, depth - 1); out.append(' ')
        elif depth > 0:
            out.append(' ')
        else:
            out.append(ch)
    return ''.join(out)

def declarator_name(pre_init):
    """The variable's OWN name in a declarator text that has already had any `= init` stripped.
    ⛔ BUG FIXED: "last identifier in the text" picks an ARRAY-SIZE identifier, not the variable,
    whenever the size is a named constant rather than a literal -- `const char *labels[SMX_STRTAB_CAP]`
    has NO '=' at all, so the old code's "last identifier before the first '='" degenerated to "last
    identifier, period" and returned "SMX_STRTAB_CAP" instead of "labels". The name always precedes
    the FIRST top-level '[' (if the declarator is an array); only fall back to "last identifier
    overall" for a bare scalar/pointer with no array dimension."""
    depth = 0
    bracket_at = None
    for idx, ch in enumerate(pre_init):
        if ch == '[' and depth == 0 and bracket_at is None:
            bracket_at = idx
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth = max(0, depth - 1)
    scan_region = pre_init[:bracket_at] if bracket_at is not None else pre_init
    ident_m = list(IDENT_RE.finditer(scan_region))
    return ident_m[-1].group(0) if ident_m else '?'

def classify_declarator(spec_prefix, decl):
    combined = f'{spec_prefix} {decl}'.strip()
    before_name = decl.split('=')[0]
    name = declarator_name(before_name)
    before_name_top = strip_braced_regions(before_name)
    if re.search(r'\*\s*const\s+' + re.escape(name) + r'\b', before_name_top):
        return name, 'CONST (const pointer binding) -- out of scope', combined
    has_star = '*' in before_name_top
    has_const = re.search(r'\bconst\b', spec_prefix) or re.search(r'\bconst\b', before_name_top)
    if has_const and not has_star:
        return name, 'CONST (immutable scalar/array/struct) -- out of scope', combined
    return name, 'MUTABLE -- needs classification (cache vs genuine-state)', combined

def census(root):
    results = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for fn in sorted(filenames):
            if not fn.endswith(SRC_EXTS):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root)
            for lineno, decl_text, static_offset in scan_file(path, rel):
                # decl_text starts with 'static'; find shared specifier vs per-declarator part is
                # approximate -- treat everything up to the first identifier-with-'*'-or-'='-or-','
                # boundary loosely by just handing the whole thing to split_declarators per name.
                for decl in split_declarators(decl_text):
                    name, verdict, combined = classify_declarator('', decl)
                    results.append((rel, lineno, name, verdict, decl_text, static_offset))
    return results

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=os.path.join(os.path.dirname(__file__), '..', 'src'))
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--csv', default=None)
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    root = os.path.abspath(args.root)
    results = census(root)
    mutable = [r for r in results if r[3].startswith('MUTABLE')]
    const_ = [r for r in results if r[3].startswith('CONST')]
    print(f'=== function-scope static census: {root} ===')
    print(f'TOTAL function-scope static declarators: {len(results)}')
    print(f'  MUTABLE (in scope):  {len(mutable)}')
    print(f'  CONST   (out of scope): {len(const_)}')
    print()
    by_file = {}
    for rel, lineno, name, verdict, decl_text, static_offset in mutable:
        by_file.setdefault(rel, []).append((lineno, name, decl_text))
    print('--- per-file breakdown (MUTABLE only) ---')
    for rel in sorted(by_file):
        print(f'{rel}: {len(by_file[rel])}')
    print()
    print('--- MUTABLE declarations, file:line ---')
    for rel, lineno, name, verdict, decl_text, static_offset in mutable:
        print(f'{rel}:{lineno}: {name}\n    {decl_text[:200]}')
    if args.csv:
        import csv
        with open(args.csv, 'w', newline='') as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(['file', 'line', 'name', 'verdict', 'declaration', 'static_offset'])
            for row in results:
                w.writerow(row)
        print(f'\nwrote {args.csv}')
    return 0

def selftest():
    import tempfile
    ok = True
    cases = [
        ("file-scope static must NOT be reported",
         "static int g_should_not_count = 0;\nint f(void) { return g_should_not_count; }\n",
         False, 'g_should_not_count'),
        ("function-scope mutable static on its own line MUST be reported",
         "int f(void) {\n    static int _cache = -1;\n    return _cache;\n}\n",
         True, '_cache'),
        ("function-scope mutable static packed on the SAME line as the signature MUST be reported "
         "(the zd_omega_test_kind shape)",
         "static int zd_omega_test_kind(int op) { static int _tf = -1; return _tf; }\n",
         True, '_tf'),
        ("static const SCALAR must be classified CONST / out of scope",
         "int f(void) { static const int LIMIT = 16; return LIMIT; }\n",
         True, 'LIMIT'),
        ("static const-pointee, mutable pointer (the emit.cpp _zo shape) must be classified MUTABLE",
         'int f(void) { static const char * _zo; _zo = "x"; return 0; }\n',
         True, '_zo'),
        ("static pointer-const (the pointer itself immutable) must be classified CONST",
         'int f(void) { static char * const _p = 0; return 0; }\n',
         True, '_p'),
        ("static inside a struct body (not function scope) must NOT be reported",
         "struct S { static int x; };\n",
         False, 'x'),
        ("REGRESSION (x86_asm.h shape): a `static const struct { f1; f2; } name[] = {...};` table "
         "must report the TABLE name, not a struct FIELD name truncated at the field's own ';'",
         'int f(void) { static const struct { const char * n; int code; } opnames[] = '
         '{ {"add",1}, {"sub",2} }; return 0; }\n',
         True, 'opnames'),
        ("REGRESSION (emit.cpp SMX_STRTAB_CAP shape): an array declarator with a NAMED size constant "
         "and no initializer must report the VARIABLE name, not the size constant",
         'int f(void) { static const char *labels[SMX_STRTAB_CAP]; return 0; }\n',
         True, 'labels'),
        ("REGRESSION (emit.cpp shape): a function-local static inside a function defined DIRECTLY "
         "under a file-spanning `extern \"C\" { ... }` wrapper must still be reported -- the wrapper "
         "is transparent, not a scope of its own",
         '#ifdef __cplusplus\nextern "C" {\n#endif\nint f(void) { static int _cache = -1; return _cache; }\n'
         '#ifdef __cplusplus\n}\n#endif\n',
         True, '_cache'),
    ]
    with tempfile.TemporaryDirectory() as td:
        for desc, src, expect_present, name in cases:
            p = os.path.join(td, 'w.c')
            open(p, 'w').write(src)
            hits = scan_file(p, 'w.c')
            names_seen = set()
            verdict_of = {}
            for lineno, decl_text, static_offset in hits:
                for decl in split_declarators(decl_text):
                    nm, verdict, _ = classify_declarator('', decl)
                    names_seen.add(nm)
                    verdict_of[nm] = verdict
            present = name in names_seen
            status = 'PASS' if present == expect_present else 'FAIL'
            if status == 'FAIL':
                ok = False
            extra = f' [{verdict_of.get(name)}]' if present else ''
            print(f'{status}: {desc}{extra}')
            if status == 'FAIL':
                print(f'      expected present={expect_present}, got present={present}, hits={hits}')
            if present and name in ('LIMIT',):
                v = verdict_of[name]
                if not v.startswith('CONST'):
                    print(f'      FAIL: {name} should classify CONST, got: {v}'); ok = False
            if present and name in ('_zo',):
                v = verdict_of[name]
                if not v.startswith('MUTABLE'):
                    print(f'      FAIL: {name} should classify MUTABLE, got: {v}'); ok = False
            if present and name in ('_p', 'opnames'):
                v = verdict_of[name]
                if not v.startswith('CONST'):
                    print(f'      FAIL: {name} should classify CONST, got: {v}'); ok = False
    print('SELFTEST', 'PASS' if ok else 'FAIL')
    return 0 if ok else 1

if __name__ == '__main__':
    sys.exit(main())
