#!/usr/bin/env python3
"""util_loc_token_census.py [--root DIR] [--exclude SUBDIR ...] [--depth N] [--files] -- LINES AND TOKENS OF THE HAND-WRITTEN SOURCE, BY src
SUB-FOLDER (Lon 2026-10-08 16:1x CDT, in-chat to the ceo, verbatim: "It is time to clean the code. First run a census on lines of code and
number of tokens for hand-written code excluding parsers by SCRIP/src sub-folders."). A MEASUREMENT: it writes nothing.
  The population: every .c .h .cpp .hpp .inc .s .S .y .l file under src/ (default --root src), less every file under an excluded
  sub-folder (default: parsers) and less every GENERATED file -- one whose first twelve lines say generated, DO NOT EDIT, or carry a
  bison/flex banner, or whose name is a known generated table (gc_allocating_table.inc, rtx_clobber_table*, *.tab.c, *.tab.h, *.lex.c,
  *.yy.c). Lines are counted three ways: total, non-blank, and code (non-blank and not a bare separator line of the /*----*/ or /*====*/
  form). Tokens are C tokens -- identifiers, numbers, string and character literals (one token each), operators and punctuators, with
  comments and whitespace dropped -- for C, C++ and .inc files; for .s files the assembler's tokens (names, numbers, punctuation) with
  comments dropped. Rows are the sub-folders at --depth (default 2: src/runtime/rt, src/templates/bb ...), with a total per top-level
  folder and a grand total; --files prints one row per file as well.
"""
import os, re, sys

ROOT_DEFAULT = os.path.join(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"), "src")
EXTS = (".c", ".h", ".cpp", ".hpp", ".inc", ".s", ".S", ".y", ".l")
GEN_NAMES = re.compile(r"(gc_allocating_table\.inc|rtx_clobber_table|\.tab\.[ch]$|\.lex\.c$|\.yy\.c$|lex\.[a-z0-9_]+\.c$)")
GEN_WORDS = re.compile(r"generated|DO NOT EDIT|A Bison parser|flex|made by GNU Bison", re.I)
C_TOKEN = re.compile(r"""
    L?"(?:\\.|[^"\\\n])*"            # string literal
  | L?'(?:\\.|[^'\\\n])*'            # character literal
  | 0[xX][0-9A-Fa-f']+[uUlL]*         # hex number
  | (?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?[uUlLfF]*   # number
  | [A-Za-z_\u0080-￿][A-Za-z0-9_\u0080-￿]*   # identifier (unicode names allowed)
  | \.\.\.|<<=|>>=|->|\+\+|--|<<|>>|<=|>=|==|!=|&&|\|\||\+=|-=|\*=|/=|%=|&=|\|=|\^=|::|\#\#
  | [-+*/%<>=!&|^~?:;,.(){}\[\]\#@]
""", re.X)
C_COMMENT = re.compile(r"/\*.*?\*/|//[^\n]*", re.S)
ASM_COMMENT = re.compile(r"/\*.*?\*/|(?:^|\s)[#;][^\n]*|//[^\n]*", re.S)
ASM_TOKEN = re.compile(r'"(?:\\.|[^"\\\n])*"|[A-Za-z_.$@][A-Za-z0-9_.$@]*|0[xX][0-9A-Fa-f]+|\d+|[-+*/%<>=!&|^~?:;,.(){}\[\]]')
SEP_LINE = re.compile(r"^\s*/\*[-=]{8,}\*/\s*$")


def is_generated(path, text):
    if GEN_NAMES.search(os.path.basename(path)):
        return True
    head = "\n".join(text.split("\n", 12)[:12])
    return bool(GEN_WORDS.search(head))


def count(path, text):
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    total = len(lines)
    nonblank = sum(1 for l in lines if l.strip())
    code = sum(1 for l in lines if l.strip() and not SEP_LINE.match(l))
    if path.endswith((".s", ".S")):
        body = ASM_COMMENT.sub(" ", text)
        toks = len(ASM_TOKEN.findall(body))
    else:
        body = C_COMMENT.sub(" ", text)
        toks = len(C_TOKEN.findall(body))
    return total, nonblank, code, toks


def main(argv):
    root = ROOT_DEFAULT; excl = ["parsers"]; depth = 2; per_file = "--files" in argv
    if "--root" in argv:
        root = argv[argv.index("--root") + 1]
    if "--exclude" in argv:
        i = argv.index("--exclude") + 1; excl = []
        while i < len(argv) and not argv[i].startswith("--"):
            excl.append(argv[i]); i += 1
    if "--depth" in argv:
        depth = int(argv[argv.index("--depth") + 1])
    root = os.path.abspath(root)
    rows = {}; generated = []; files = []
    for dp, dns, fns in os.walk(root):
        rel = os.path.relpath(dp, root)
        parts = [] if rel == "." else rel.split(os.sep)
        if parts and parts[0] in excl:
            dns[:] = []; continue
        for fn in sorted(fns):
            if not fn.endswith(EXTS):
                continue
            p = os.path.join(dp, fn)
            try:
                text = open(p, "rb").read().decode("utf-8", "replace")
            except OSError:
                continue
            if is_generated(p, text):
                generated.append(os.path.relpath(p, root)); continue
            t, nb, c, k = count(p, text)
            key = "/".join(parts[:depth]) if parts else "."
            r = rows.setdefault(key, [0, 0, 0, 0, 0]); r[0] += 1; r[1] += t; r[2] += nb; r[3] += c; r[4] += k
            files.append((os.path.relpath(p, root), t, nb, c, k))
    print("LINES AND TOKENS OF THE HAND-WRITTEN SOURCE under %s (excluding %s and %d generated files)" % (root, ", ".join(excl), len(generated)))
    print("%-28s %6s %9s %9s %9s %10s" % ("sub-folder", "files", "lines", "nonblank", "code", "tokens"))
    tops = {}
    for key in sorted(rows):
        f, t, nb, c, k = rows[key]
        print("%-28s %6d %9d %9d %9d %10d" % (key, f, t, nb, c, k))
        top = key.split("/")[0]
        r = tops.setdefault(top, [0, 0, 0, 0, 0])
        for i, v in enumerate((f, t, nb, c, k)):
            r[i] += v
    print("%-28s %6s %9s %9s %9s %10s" % ("-- per top-level folder --", "", "", "", "", ""))
    grand = [0, 0, 0, 0, 0]
    for top in sorted(tops):
        f, t, nb, c, k = tops[top]
        print("%-28s %6d %9d %9d %9d %10d" % (top, f, t, nb, c, k))
        for i, v in enumerate((f, t, nb, c, k)):
            grand[i] += v
    print("%-28s %6d %9d %9d %9d %10d" % ("TOTAL", *grand))
    if generated:
        print("generated, not counted: " + " ".join(generated))
    if per_file:
        print("%-60s %9s %9s %9s %10s" % ("file", "lines", "nonblank", "code", "tokens"))
        for p, t, nb, c, k in sorted(files, key=lambda r: -r[4]):
            print("%-60s %9d %9d %9d %10d" % (p, t, nb, c, k))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
