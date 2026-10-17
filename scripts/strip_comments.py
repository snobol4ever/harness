#!/usr/bin/env python3
"""strip_comments.py — DN-CLEAN-0 (GOAL-DENAME-EMITTER-RUNTIME).
Remove C/C++ comments from SCRIP source, string/char-literal aware.
  - Strips /* ... */ and // ... comments.
  - NEVER touches text inside "..." or '...' literals (incl. escapes).
  - Excludes the generated flex/bison outputs (their comments are the generator's; GENERATED below is the census).
  - .l files go through strip_flex: patterns are copied verbatim, only the C regions are stripped (the R4/R5 flex hazard, cured in the tool).
  - SEPARATOR POLICY (Lon fork): KEEP_SEPARATORS=True keeps the sanctioned 200-char
    /*---*/ (minor) and /*===*/ (major) separators that RULES.md mandates; set False
    for literal "zero comments" (which also requires editing RULES.md).
Usage:
  strip_comments.py --dry-run        # report counts only, write nothing
  strip_comments.py --apply          # rewrite files in place
  strip_comments.py --check          # rc=1 if any comment (other than a 200-char separator) or blank line survives; the R5 gate arm
"""
import os, re, sys

KEEP_SEPARATORS = True   # Option A (default). Set False for Option B (literal zero).
SRC_ROOT = os.path.join(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"), "src")
EXTS = (".c", ".h", ".cpp", ".hpp", ".y", ".l", ".s", ".S")
GENERATED = re.compile(r"(\.lex\.c|\.tab\.c|\.tab\.h|(^|/)lex\.[^/]+\.c)$")
SEP = re.compile(r"^\s*/\*[-=]+\*/\s*$")
SEP_WIDTH = 200   # RULES.md: the sanctioned separator is exactly 200 chars; a short one is dirty and is NOT a comment

def strip_one(text):
    """Return text with comments removed, preserving string/char literals."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        # string / char literal — copy verbatim through the closing quote
        # a single quote opens a char literal ONLY if it closes within 8 chars on the same line ('x', '\\n', '\\x41', '\\'');
        # otherwise it is an ordinary character -- flex patterns like '([^']|'')*' (pascal.l) and <BODY>\\' (snobol4.l) carry
        # unpaired quotes that swallowed the rest of the file verbatim (R5 2026-09-02 measured: 47 separators + comments survived in snobol4.l)
        if c == "'":
            k = text.find("'", i + 1); k2 = text.find("\n", i + 1)
            if k == -1 or k - i > 8 or (k2 != -1 and k2 < k):
                out.append(c); i += 1
                continue
        # likewise a double quote opens a string ONLY if an unescaped closing quote follows on the same line: flex patterns
        # such as <BODY>\\" (snobol4.l) carry an unpaired quote that swallowed 34 separators and their comments verbatim (R5)
        if c == '"':
            k = i + 1; closed = False
            while k < n and text[k] != "\n":
                if text[k] == "\\": k += 2; continue
                if text[k] == '"': closed = True; break
                k += 1
            if not closed:
                out.append(c); i += 1
                continue
        if c == '"' or c == "'":
            q = c
            out.append(c); i += 1
            while i < n:
                d = text[i]
                out.append(d); i += 1
                if d == "\\" and i < n:        # escape: copy next char raw
                    out.append(text[i]); i += 1
                elif d == q:
                    break
            continue
        # block comment
        if c == "/" and i + 1 < n and text[i+1] == "*":
            j = text.find("*/", i + 2)
            j = (j + 2) if j != -1 else n
            # KEEP the line-break separator, NORMALIZED to the canonical 200-char form
            # (Lon 2026-09-02 "Do the line-break comments at 200 character length"; R4 2026-08-20 had 200 in the tree while this constant still said 120): /* + 196 dashes + */  (or '=' for a major separator).
            blk = text[i:j]
            if KEEP_SEPARATORS and SEP.match(blk):
                ch = "=" if "=" in blk else "-"
                out.append("/*" + ch * 196 + "*/")
            else:
                out.append(" ")          # C semantics: a comment becomes one space (no token fusion)
            i = j
            continue
        # line comment
        if c == "/" and i + 1 < n and text[i+1] == "/":
            j = text.find("\n", i)
            i = j if j != -1 else n
            continue
        out.append(c); i += 1
    return "".join(out)

def c_block_end(text, i):
    """text[i] == '{': index just past the matching '}', lexed as C (strings, chars, comments skipped); -1 if unbalanced."""
    depth = 0; n = len(text)
    while i < n:
        c = text[i]
        if c == '"' or c == "'":
            q = c; i += 1
            while i < n and text[i] != q and text[i] != "\n":
                if text[i] == "\\": i += 1
                i += 1
            i += 1; continue
        if c == "/" and i + 1 < n and text[i+1] == "*":
            j = text.find("*/", i + 2); i = n if j == -1 else j + 2; continue
        if c == "/" and i + 1 < n and text[i+1] == "/":
            j = text.find("\n", i); i = n if j == -1 else j; continue
        if c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0: return i + 1
        i += 1
    return -1

def flex_pattern_end(line):
    """Index where a flex rule's PATTERN ends: the first unescaped blank outside "..." / [...] / {...}; len(line) if none.
    This is the whole flex hazard in one place: /* inside a character class ([a-z/*+] in raku.l), an unpaired ' or " in a pattern
    ('([^']|'')*' in pascal.l, <BODY>\\" in snobol4.l), // as a quoted token ("//" in raku.l) -- none of these is C, and R4 and R5
    each destroyed a lexer by running the C lexer over them. Patterns are copied verbatim; only what follows them is C."""
    i = 0; n = len(line)
    while i < n:
        c = line[i]
        if c == "\\": i += 2; continue
        if c == '"':
            i += 1
            while i < n and line[i] != '"':
                if line[i] == "\\": i += 1
                i += 1
            i += 1; continue
        if c == "[":
            i += 1
            if i < n and line[i] == "^": i += 1
            if i < n and line[i] == "]": i += 1
            while i < n and line[i] != "]":
                if line[i] == "\\": i += 1
                elif line[i] == "[" and i + 1 < n and line[i+1] == ":":
                    j = line.find(":]", i + 2); i = j + 1 if j != -1 else i
                i += 1
            i += 1; continue
        if c == "{":
            j = line.find("}", i); i = j + 1 if j != -1 else n; continue
        if c in " \t": return i
        i += 1
    return n

def strip_flex(text):
    """flex sources, structure-aware: the C regions -- %{ %} blocks, indented lines, %top{ }, brace and one-line actions after a
    pattern, and the whole user-code section after the second %% -- go through strip_one; every pattern, name definition, %option and
    %x/%s line is copied byte for byte. Proven by util_style200_oracle_yl.sh (object identity of the regenerated lexer) and by the
    round trip strip_flex(x) == x over the four committed lexers, which already carry no comments (hq_B 2026-09-02)."""
    lines = text.split("\n"); out = []; i = 0; sect = 1
    def emit_c(chunk): out.append(strip_one(chunk))
    while i < len(lines):
        l = lines[i]; s = l.strip()
        if s == "%%" and sect < 3:
            sect += 1; out.append(l); i += 1; continue
        if sect == 3:
            emit_c("\n".join(lines[i:])); break
        if s == "%{" or s.startswith("%top{"):
            close = "%}" if s == "%{" else "}"
            j = i + 1
            while j < len(lines) and lines[j].strip() != close: j += 1
            out.append(l); emit_c("\n".join(lines[i+1:j]))
            if j < len(lines): out.append(lines[j])
            i = j + 1; continue
        if s.startswith("/*"):
            blk = "\n".join(lines[i:]); k = blk.find("*/")
            j = i + blk[:k+2].count("\n") if k != -1 else len(lines) - 1
            emit_c("\n".join(lines[i:j+1])); i = j + 1; continue
        if l[:1] in (" ", "\t"):
            emit_c(l); i += 1; continue
        if sect == 1 or l == "" or s.startswith("%"):
            out.append(l); i += 1; continue
        pe = flex_pattern_end(l); pat = l[:pe]; rest = l[pe:]
        k = 0
        while k < len(rest) and rest[k] in " \t": k += 1
        act = rest[k:]
        if act.startswith("{"):
            blk = "\n".join(lines[i:]); start = pe + k
            e = c_block_end(blk, start)
            if e == -1: out.append(l); i += 1; continue
            tail = blk[e:].split("\n", 1)[0]
            out.append(pat + rest[:k] + strip_one(blk[start:e]) + strip_one(tail))
            i += blk[:e].count("\n") + 1; continue
        if act.startswith("%{"):
            j = i + 1
            while j < len(lines) and lines[j].strip() != "%}": j += 1
            out.append(l); emit_c("\n".join(lines[i+1:j]))
            if j < len(lines): out.append(lines[j])
            i = j + 1; continue
        if act.strip() == "|":
            out.append(l); i += 1; continue
        out.append(pat + rest[:k] + strip_one(act)); i += 1
    return "\n".join(out)

def strip_file(p, src):
    return strip_flex(src) if p.endswith(".l") else strip_one(src)

def clean_blank_runs(text):
    # collapse comment-removal-induced blank lines; RULES.md = zero blank lines.
    lines = [ln.rstrip() for ln in text.split("\n")]
    return "\n".join(ln for ln in lines if ln.strip() != "") + "\n"

def why_dirty(src, stripped):
    """Name the FIRST thing that makes a file dirty, at its line number, so the report says what to fix.
    ⛔ The count line used to say only "a comment or a blank line". A sanctioned separator at the wrong WIDTH
    is neither, so grepping for comments and blank lines -- which is what that message tells you to do --
    finds nothing, twice, and the reader starts doubting the checker instead of the file (hq_T, 2026-09-06,
    ten minutes; hq_R had just shipped exactly that defect). The classifier answers from strip_one()'s own
    output, never from a second guess at what the rule means."""
    a, b = src.split("\n"), stripped.split("\n")
    for i, ln in enumerate(a):
        if ln.strip() == "":
            return i + 1, "blank line"
        if i < len(b) and ln == b[i]:
            continue
        if SEP.match(ln):
            return i + 1, "separator is %d chars, want %d" % (len(ln.strip()), SEP_WIDTH)
        if ln.rstrip() != ln:
            return i + 1, "trailing whitespace"
        return i + 1, "comment"
    if len(a) != len(b):
        return len(b), "line count differs (%d -> %d)" % (len(a), len(b))
    return 0, "differs from the stripped form"

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--dry-run"
    # ⛔⭐ `--check-files <paths...>` GRADES ONLY WHAT WAS HANDED TO IT, so a pre-commit hook can convict the
    # commit in front of it and NOBODY ELSE. The whole-tree --check is the right thing inside `make test` and
    # the wrong thing at commit time: it would refuse an innocent commit because a file the author never
    # opened is dirty, which is how a guard earns a reputation for being in the way and gets bypassed.
    # ⭐ It exists so the hook can SOURCE this authority instead of reimplementing the rule. A second
    # implementation of "what counts as a comment here" would drift from this one, and the drift would be
    # silent in exactly the direction that lets a violation through.
    if mode == "--check-files":
        files = [f for f in sys.argv[2:] if f.endswith(EXTS) and not GENERATED.search(f) and os.path.isfile(f)]
        bad = []
        for p in files:
            with open(p, "r", errors="surrogateescape") as f:
                src = f.read()
            stripped = clean_blank_runs(strip_file(p, src))
            if stripped != src:
                bad.append((p, why_dirty(src, stripped)))
        for p, (ln, why) in bad:
            sys.stderr.write("  %s:%d  %s\n" % (p, ln, why))
        print("checked %d staged src file(s), %d carrying a comment, a blank line or an off-width separator" % (len(files), len(bad)))
        return 1 if bad else 0
    files = []
    for root, _, names in os.walk(SRC_ROOT):
        for nm in names:
            if nm.endswith(EXTS):
                p = os.path.join(root, nm)
                if GENERATED.search(p):
                    continue
                files.append(p)
    files.sort()
    tot_before = tot_after = changed = 0
    for p in files:
        with open(p, "r", errors="surrogateescape") as f:
            src = f.read()
        before = src.count("\n")
        stripped = clean_blank_runs(strip_file(p, src))
        after = stripped.count("\n")
        tot_before += before; tot_after += after
        if stripped != src:
            changed += 1
            if mode == "--apply":
                with open(p, "w", errors="surrogateescape") as f:
                    f.write(stripped)
    if mode == "--check":
        dirty = []
        for p in files:
            raw = open(p, "r", errors="surrogateescape").read()
            stripped = clean_blank_runs(strip_file(p, raw))
            if stripped != raw:
                dirty.append((p, why_dirty(raw, stripped)))
        print("files scanned (generated excluded): %d" % len(files))
        print("files still carrying a comment, a blank line or an off-width separator: %d" % len(dirty))
        for p, (ln, why) in dirty[:40]: print("  %s:%d  %s" % (os.path.relpath(p, SRC_ROOT), ln, why))
        sys.exit(1 if dirty else 0)
    print("files scanned (generated excluded): %d" % len(files))
    print("files that would change          : %d" % changed)
    print("total lines  before -> after     : %d -> %d  (%+d)" % (tot_before, tot_after, tot_after - tot_before))
    print("KEEP_SEPARATORS                  : %s" % KEEP_SEPARATORS)
    print("mode                             : %s" % mode)

if __name__ == "__main__":
    # ⛔ PROPAGATE THE EXIT CODE. `main()` bare discards it, so --check-files printed the offending file and
    # then exited 0 -- a guard that names the violation and lets it through, which is worse than no guard
    # because the output looks like it worked. Measured on the first run of the new mode.
    raise SystemExit(main() or 0)
