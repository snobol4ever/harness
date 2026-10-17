#!/usr/bin/env python3
"""Consolidate the PLATFORM_X86 arm of a BB template into ONE return with IF() selectors.

Transforms:
    if (PLATFORM_X86) {
        if (MEDIUM_MACRO_DEF) { return <A>; }
        if (MEDIUM_BINARY)    { bin = {...}; return <B>; }
        if (MEDIUM_TEXT)      { return <C>; }   // or: if (MEDIUM_TEXT) return <C>;
    }
into:
    if (PLATFORM_X86) {
        <bin-assignment hoisted, unconditional>
        return IF(MEDIUM_MACRO_DEF, <A>)
             + IF(MEDIUM_BINARY,    <B>)
             + IF(MEDIUM_TEXT,      <C>);
    }

Only handles the SIMPLE shape: at most one MEDIUM_MACRO_DEF, one MEDIUM_BINARY (with at
most one `bin = {...};` statement immediately before its return), one MEDIUM_TEXT, each
arm being a single `return <expr>;`. Files with internal branching inside an arm, FOR
loops, multiple bin/return per medium, or extra statements are SKIPPED (return None) and
must be done by hand.
"""
import sys, re

def find_block(s, open_idx):
    """Given index of a '{', return index just past the matching '}'."""
    depth = 0
    i = open_idx
    while i < len(s):
        if s[i] == '{': depth += 1
        elif s[i] == '}':
            depth -= 1
            if depth == 0: return i + 1
        i += 1
    raise ValueError("unbalanced")

def parse_medium_arm(body, medium):
    """Find `if (MEDIUM_x) { ... }` or `if (MEDIUM_x) return ...;` in body.
    Returns (bin_assign_or_None, return_expr) or None if absent.
    Raises if shape is too complex."""
    m = re.search(r'if\s*\(\s*%s\s*\)' % medium, body)
    if not m: return None
    j = m.end()
    # skip whitespace
    while j < len(body) and body[j] in ' \t\n': j += 1
    if body[j] == '{':
        end = find_block(body, j)
        inner = body[j+1:end-1]
    else:
        # braceless: single statement up to the terminating ; (the return)
        end = body.index(';', j) + 1
        inner = body[j:end]
    inner = inner.strip()
    # split into statements: optional `bin = {...};` then `return <expr>;`
    bin_assign = None
    bm = re.match(r'(bin\s*=\s*\{.*?\}\s*;)\s*', inner, re.S)
    if bm:
        bin_assign = bm.group(1)
        inner = inner[bm.end():].strip()
    rm = re.match(r'return\s+(.*?);\s*$', inner, re.S)
    if not rm:
        raise ValueError("complex arm in %s: %r" % (medium, inner[:60]))
    return (bin_assign, rm.group(1).strip())

def transform(src):
    m = re.search(r'if\s*\(\s*PLATFORM_X86\s*\)\s*\{', src)
    if not m: return None
    open_brace = m.end() - 1
    end = find_block(src, open_brace)
    body = src[open_brace+1:end-1]
    # bail if FOR loop or nested medium logic likely
    try:
        md = parse_medium_arm(body, 'MEDIUM_MACRO_DEF')
        bn = parse_medium_arm(body, 'MEDIUM_BINARY')
        tx = parse_medium_arm(body, 'MEDIUM_TEXT')
    except ValueError as e:
        sys.stderr.write("SKIP (complex): %s\n" % e)
        return None
    # require that the body contains ONLY these arms (no other statements)
    stripped = body
    for arm_re in [r'if\s*\(\s*MEDIUM_MACRO_DEF\s*\).*',
                   r'if\s*\(\s*MEDIUM_BINARY\s*\).*',
                   r'if\s*\(\s*MEDIUM_TEXT\s*\).*']:
        pass
    bin_assigns = [a[0] for a in (md, bn, tx) if a and a[0]]
    if len(bin_assigns) > 1:
        sys.stderr.write("SKIP: multiple bin assignments\n"); return None
    parts = []
    if md: parts.append(('MEDIUM_MACRO_DEF', md[1]))
    if bn: parts.append(('MEDIUM_BINARY',    bn[1]))
    if tx: parts.append(('MEDIUM_TEXT',      tx[1]))
    if not parts:
        sys.stderr.write("SKIP: no medium arms found\n"); return None
    # build new body
    lines = []
    if bin_assigns:
        lines.append("        " + bin_assigns[0])
    ret = "        return "
    sel = []
    for name, expr in parts:
        # indent expr continuation lines
        sel.append("IF(%s,\n               %s)" % (name, expr.strip()))
    ret += "\n             + ".join(sel) + ";"
    new_body = "\n" + ("\n".join(lines) + "\n" if lines else "") + ret + "\n    "
    return src[:open_brace+1] + new_body + src[end-1:]

if __name__ == '__main__':
    path = sys.argv[1]
    src = open(path).read()
    out = transform(src)
    if out is None:
        sys.exit(2)
    open(path, 'w').write(out)
    print("rewrote", path)
