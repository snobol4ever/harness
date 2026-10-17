#!/usr/bin/env python3
"""util_uppercase_keywords.py -- uppercase SNOBOL4/SPITBOL KEYWORDS (built-in functions, system names, &keywords, control
statements) in a source file, so the program means under `sbl -bf` (case-SENSITIVE, standard
SNOBOL4) exactly what it meant under `sbl -b` (case-FOLDING).

NEVER touched: string literal contents ('...' / "..."), comment lines (* in column 1), comment
tails (;*), and USER-DEFINED names.  Only names the manual reserves are changed."""
import re, sys

# Built-in functions: union of the ch.19 "Function summary" and "Function Descriptions" headwords.
FUNCS = """ANY APPLY ARBNO ARG ARRAY ATAN BACKSPACE BREAK BREAKX CHAR CHOP CLEAR CODE COLLECT
CONVERT COPY COS DATA DATATYPE DATE DEFINE DETACH DIFFER DUMP DUPL EJECT ENDFILE EQ EVAL EXIT EXP
FENCE FIELD GE GT HOST IDENT INTEGER ITEM LE LEN LEQ LGE LGT LLE LLT LN LNE LOAD LOCAL LPAD LT NE
NOTANY OPSYN POS PROTOTYPE REMDR REPLACE REVERSE REWIND RPAD RPOS RSORT RTAB SET SETEXIT SIN SIZE
SORT SPAN SQRT STOPTR SUBSTR TAB TABLE TAN TIME TRACE TRIM UNLOAD""".split()
# Special system names (manual l.8027+) and the primitive pattern-valued variables.
SPECIAL = """ABORT CONTINUE END FRETURN INPUT NRETURN OUTPUT RETURN SCONTINUE TERMINAL
ARB BAL FAIL REM SUCCEED""".split()
RESERVED = {w: w for w in FUNCS + SPECIAL}
IDENT = re.compile(r"[A-Za-z][A-Za-z0-9_.]*")

def split_code_spans(line):
    """Yield (text, is_code) spans for one physical line, honouring quotes and comment forms."""
    if line[:1] == "*":                      # whole-line comment
        yield line, False; return
    i, n, out, q = 0, len(line), [], None
    while i < n:
        c = line[i]
        if q:                                 # inside a literal: ends at the matching quote
            out.append(c)
            if c == q: yield "".join(out), False; out = []; q = None
            i += 1; continue
        if c in "'\"":
            if out: yield "".join(out), True; out = []
            q = c; out.append(c); i += 1; continue
        if c == ";" and line[i+1:i+2] == "*":  # comment tail -- rest of line is prose
            if out: yield "".join(out), True
            yield line[i:], False; return
        out.append(c); i += 1
    if out: yield "".join(out), (q is None)

def fix_line(line):
    if line[:1] == "-":                       # control statement: uppercase the control word only
        m = re.match(r"-([A-Za-z]+)", line)
        if m: line = "-" + m.group(1).upper() + line[m.end():]
        # fall through: a control's argument is a quoted filename, protected by split_code_spans
    parts = []
    for text, is_code in split_code_spans(line):
        if not is_code: parts.append(text); continue
        # &keyword -> &KEYWORD (every & introduces a system keyword)
        text = re.sub(r"&([A-Za-z][A-Za-z0-9_]*)", lambda m: "&" + m.group(1).upper(), text)
        text = IDENT.sub(lambda m: RESERVED.get(m.group(0).upper(), m.group(0))
                         if m.group(0).upper() in RESERVED else m.group(0), text)
        parts.append(text)
    return "".join(parts)

END_STMT = re.compile(r"^[Ee][Nn][Dd][ \t]*(?:[;*].*)?$")
def fix_text(src):
    """⛔ s191: STOP AT THE END STATEMENT.  Everything after `END` is the program's inline INPUT DATA,
    not code, and uppercasing it CORRUPTS THE DATA.  Measured on csnobol4_suite/tab.sno, whose data is the
    Gettysburg Address: `or any nation` -> `or ANY nation`, `that field` -> `that FIELD`.  Already landed
    once (corpus c8a687ef, s188): trim0/trim1 read `this line has a leading tab` -> `... leading TAB`, so a
    file whose data DESCRIBES ITSELF now contradicts itself.  Inert under SPITBOL, which never reads
    post-END text -- but CSNOBOL4 does, and a re-pin would bake the corruption in."""
    out, done = [], False
    for l in src.splitlines(keepends=True):
        if done: out.append(l); continue
        fixed = fix_line(l)
        out.append(fixed)
        if END_STMT.match(l.rstrip("\n").rstrip("\r")): done = True   # the END line itself is still uppercased; only what FOLLOWS is data
    return "".join(out)

if __name__ == "__main__":
    p = sys.argv[1]
    src = open(p, encoding="utf-8", errors="surrogateescape").read()
    out = fix_text(src)
    if len(sys.argv) > 2 and sys.argv[2] == "--write":
        if out != src: open(p, "w", encoding="utf-8", errors="surrogateescape").write(out); print("CHANGED", p)
    else:
        sys.stdout.write(out)
