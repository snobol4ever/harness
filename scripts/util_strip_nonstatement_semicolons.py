#!/usr/bin/env python3
"""Census (--fix to repair) Icon sources where our semicolon pass put a `;` where NO Icon accepts one.

MEASURED 2026-09-06 (hq_B), all four shapes, both directions, against icont/iconx and SCRIP:
    $define N 3;   record pt(x,y);   global g;   invocable all;
icont REJECTS every one ("`;`: invalid declaration"); SCRIP accepts them WITH or WITHOUT the semicolon.
So the semicolon our conversion added to preprocessor directives and declarations bought SCRIP nothing
and cost the file its gradability against its own oracle -- hq_I found arizona's prepro.icn and ilib.icn
scored as FAILs that no compiler change could ever cure, because the oracle cannot compile our copy.

TWO RULES, BOTH MEASURED THE SAME WAY. (1) A line whose FIRST token is `$<directive>`, `record`,
`global`, `link` or `invocable` and whose last non-comment character is `;`. (2) A line ending in `;`
whose next non-blank, non-comment line begins with `else` -- our pass put a semicolon after the THEN
branch, which CLOSES THE IF for icont ("`else`: invalid expression") while SCRIP tolerates it. Both
shapes were checked both ways: SCRIP runs identically with and without, icont refuses only ours.

⛔ SCOPE, DELIBERATELY NARROW. A statement-ending semicolon is
REQUIRED by SCRIP's frontend (RULES.md, ICON SEMICOLON-REQUIRED) and is never touched. Continuation
lines are left alone: a `record` spanning two lines has its `;` on a line this rule does not match, and
leaving it is the safe direction -- this tool exists to remove a semicolon no Icon accepts, not to
normalise style.

⭐ A PROGRAM THAT PRINTS ITS OWN SOURCE has its .ref moved by any edit here (arizona's fncs1 and io are
the known pair). This tool does not re-cut refs; it names every file it changed so the caller can grade
the suite that owns them.
"""
import os, re, sys
DECL = re.compile(r'^\s*(\$\s*[A-Za-z_]+|record|global|link|invocable)\b')
def strip_line(l):
    body, comment = l, ""
    h = body.find('#')
    if h >= 0:
        body, comment = body[:h], body[h:]
    stripped = body.rstrip()
    if not stripped.endswith(';'):
        return None
    return stripped[:-1].rstrip() + (" " + comment if comment else "")
SIG = re.compile(r'[^\s]')
def _lex(t):
    """Yield (kind, start, end) over t: 'code' chars are everything outside comments and literals.

    Icon comments run # to EOL; string literals are "..." with \\ escapes and an underscore
    line-continuation; cset literals are '...'. Anything inside those is never a token.
    """
    i, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == '#':
            j = t.find('\n', i); j = n if j < 0 else j
            yield ('skip', i, j); i = j
        elif c in '"\'':
            q, j = c, i + 1
            while j < n:
                if t[j] == '\\': j += 2; continue
                if t[j] == q: j += 1; break
                if t[j] == '\n': break
                j += 1
            yield ('skip', i, j); i = j
        else:
            yield ('code', i, i + 1); i += 1
def _codemask(t):
    m = bytearray(len(t))
    for kind, a, b in _lex(t):
        if kind == 'code':
            for k in range(a, b): m[k] = 1
    return m
def _prev_sig(t, m, i):
    j = i - 1
    while j >= 0 and (not m[j] or t[j].isspace()): j -= 1
    return j
def _prev_word(t, m, i):
    j = _prev_sig(t, m, i)
    if j < 0 or not (t[j].isalnum() or t[j] == '_'): return '', j
    e = j + 1
    while j >= 0 and m[j] and (t[j].isalnum() or t[j] == '_'): j -= 1
    return t[j + 1:e], j + 1
def repair_text(t):
    """Remove every semicolon Icon accepts nowhere, and turn a semicolon-separated
    parenthesised group into the brace-delimited compound expression Icon spells it with.

    Four shapes, each MEASURED against Arizona icont 9.5.25a before it was written here:
      `;` before `else`  -- closes the if, so else dangles ("else: invalid expression")
      `;` before `then`  -- same, one keyword earlier ("missing then")
      `;` before the `}` that closes a CASE body -- an empty clause ("invalid case clause").
          ⛔ NOT general: `{1; 2; 3;}` is VALID Icon and its trailing `;` CHANGES THE VALUE
          (the empty expression yields &null), so this rule fires only for a case body.
      `;` directly inside `( )` -- parentheses group ONE expression, they do not sequence
          ("missing right parenthesis"). Dropping the semicolons would leave `(1 2 3)`,
          also invalid, so the repair is the delimiter: the group becomes `{ }`, which is
          Icon's compound expression and yields the same last value.
    Returns (new_text, n_changes).
    """
    t = t; changed = 0
    for _pass in range(200):
        m = _codemask(t); stack = []; cut = None; braces = None
        for i, c in enumerate(t):
            if not m[i]: continue
            if c in '([{':
                kind = 'paren' if c == '(' else 'brack' if c == '[' else 'brace'
                if c == '{' and _prev_word(t, m, i)[0] == 'of': kind = 'case'
                stack.append((kind, i))
            elif c in ')]}':
                if stack: stack.pop()
            elif c == ';':
                if stack and stack[-1][0] == 'paren':
                    op = stack[-1][1]; d = 0
                    for j in range(op, len(t)):
                        if not m[j]: continue
                        if t[j] in '([{': d += 1
                        elif t[j] in ')]}':
                            d -= 1
                            if d == 0: braces = (op, j); break
                    if braces: break
            if c == '}' and stack == [] : pass
        if braces:
            op, cl = braces
            t = t[:op] + '{' + t[op + 1:cl] + '}' + t[cl + 1:]; changed += 1; continue
        m = _codemask(t); stack = []; cut = None
        for i, c in enumerate(t):
            if not m[i]: continue
            if c in '([{':
                kind = 'paren' if c == '(' else 'brack' if c == '[' else 'brace'
                if c == '{' and _prev_word(t, m, i)[0] == 'of': kind = 'case'
                stack.append((kind, i))
            elif c in ')]}':
                if c == '}' and stack and stack[-1][0] == 'case':
                    j = _prev_sig(t, m, i)
                    if j >= 0 and t[j] == ';': cut = j; break
                if stack: stack.pop()
        if cut is None:
            m = _codemask(t)
            for kw in ('else', 'then'):
                for mm in re.finditer(r'\b%s\b' % kw, t):
                    i = mm.start()
                    if not m[i]: continue
                    j = _prev_sig(t, m, i)
                    if j >= 0 and t[j] == ';': cut = j; break
                if cut is not None: break
        if cut is None: return t, changed
        t = t[:cut] + t[cut + 1:]; changed += 1
    raise RuntimeError('repair_text did not converge')
def main():
    args = sys.argv[1:]
    fix = "--fix" in args
    roots = [a for a in args if not a.startswith("--")] or ["../corpus"]
    files = []
    for r in roots:
        if not os.path.isdir(r):
            print("⛔ REFUSES (rc=2): %s is not a directory -- cannot measure" % r); return 2
        for dp, _dn, fn in os.walk(r):
            # ⛔ .dat IS IN THE POPULATION AND WAS THE HOLE. corpus/tests/icon/config/prepro.dat is an
            # $include'd code fragment, so icont preprocesses it exactly like a source -- and our pass had
            # put `;` on three of its directives. `$define abc 321;` then expands abc to `321;`, so the
            # INCLUDING entry failed 30 lines later with "missing right parenthesis" and read as a defect
            # at a line that was innocent. An extension filter that stops at .icn cannot see that.
            files += [os.path.join(dp, n) for n in fn if n.endswith(".icn") or n.endswith(".dat")]
    if not files:
        print("⛔ REFUSES (rc=2): no .icn files under %s -- a census that cannot see its population must not print 0" % ", ".join(roots)); return 2
    def next_code(ls, i):
        for j in range(i + 1, len(ls)):
            t = ls[j].strip()
            if t and not t.startswith("#"):
                return t
        return ""
    touched = lines_changed = 0
    dangling = []
    for p in sorted(files):
        # A DANGLING SYMLINK IS NOT A MEASUREMENT FAILURE, it is a file with no content to measure, so it
        # is NAMED and skipped rather than refused -- but a real read error still refuses rc=2, because an
        # instrument that silently drops unreadable members of its population reports a number it did not earn.
        if os.path.islink(p) and not os.path.exists(p):
            dangling.append(p); continue
        try:
            src = open(p, encoding="utf-8", errors="surrogateescape").read()
        except OSError as e:
            print("⛔ REFUSES (rc=2): cannot read %s (%s)" % (p, e)); return 2
        src, n_struct = repair_text(src)
        srclines = src.split("\n")
        out, n = [], n_struct
        for i, l in enumerate(srclines):
            if DECL.match(l):
                t = strip_line(l)
                if t is not None:
                    out.append(t); n += 1; continue
            if re.match(r'^\s*else\b', next_code(srclines, i)):
                t = strip_line(l)
                if t is not None:
                    out.append(t); n += 1; continue
            out.append(l)
        if n:
            touched += 1; lines_changed += n
            print("  %-6s %s (%d line(s))" % ("FIXED" if fix else "would", p, n))
            if fix:
                open(p, "w", encoding="utf-8", errors="surrogateescape").write("\n".join(out))
    print("source files scanned=%d (.icn + $include'd .dat) | %s=%d files, %d line(s)"
          % (len(files) - len(dangling), "REPAIRED" if fix else "would repair", touched, lines_changed))
    for d in dangling:
        print("  ⚠ DANGLING SYMLINK, skipped and named (no content to measure): %s" % d)
    if not fix and touched:
        print("   run with --fix to strip them; then re-grade the suites that own those files")
    return 0
if __name__ == "__main__":
    sys.exit(main())
