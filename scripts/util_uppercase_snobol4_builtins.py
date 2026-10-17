#!/usr/bin/env python3
"""util_uppercase_snobol4_builtins.py -- uppercase SPITBOL builtin names in a case-folded source.

Lon 2026-09-11, in-chat to ceo (CEO-571): "So for case insensitive sources, the solution is to modify
the test source to use uppercase reserved/key-words."

WHY: SPITBOL folds case by default; our one mandated invocation is `sbl -bf`, and -f is case-SENSITIVE
because that is what SCRIP's SNOBOL4 is. A third-party source written in SPITBOL's default idiom (lower
case `end`, `output`) is refused by -bf with "No END statement found in source file(s)". The cure is to
convert the SOURCE, once, in the repo -- never to fold at grade time, because a transform applied inside
a harness run means the artifact we grade is not the artifact in the repo (CEO-567, CEO-570).

WHAT IT TOUCHES: only bare identifiers that match the SPITBOL builtin list below, at word boundaries,
and only OUTSIDE string literals and comments. User identifiers keep their case -- they are consistent
within a file and case-sensitivity does not disturb them. `&keyword` names are uppercased after the `&`.

⛔ THE LIST IS THE INSTRUMENT, AND A NAME MISSING FROM IT IS A SILENT NO-OP ON THAT NAME, never an error here.
`EXIT` was absent until 2026-09-12 (hq_C, the twelve-resisting row): `module.sbl` is ONE statement, `exit(-3,'module.out')`,
and the converter reported 0 changes on it -- a file it could not convert at all, reported the same way as a file that
needed nothing. The miss surfaces only downstream, as ERROR 022 undefined function under -bf, which is why the oracle
proof and not this script's own count is the verdict. When a conversion leaves a file red, SUSPECT THIS LIST FIRST.

⛔ IT PROVES ITSELF OR IT FAILS. This script does not decide whether its own edit was correct; the caller
runs the oracle both ways and compares (see --check in the runner, and the row's DONE-WHEN):
    sbl        ORIGINAL.sbl   (case folding, upstream's own invocation)
    sbl -bf    CONVERTED.sbl  (our mandated arm)
Byte-identical output is the proof. A file whose two runs differ is REPORTED and left unconverted -- it
is a finding, never a silent acceptance.
"""
import re, sys
BUILTINS = """END OUTPUT INPUT TERMINAL PUNCH
ANY APPLY ARB ARBNO ARG ARRAY ATAN BAL BREAK BREAKX CHAR CHOP CLEAR CODE COLLECT CONVERT COPY COS DATA
DATATYPE DATE DEFINE DETACH DIFFER DUMP DUPL ENDFILE EQ EVAL EXIT EXP FENCE FIELD FREEZE FUNCTION GE GT HOST
IDENT INTEGER ITEM LE LEN LEQ LGE LGT LLE LLT LN LNE LOAD LOCAL LPAD LT NE NOTANY OPSYN ORD POS PROTOTYPE REMDR REPLACE
REVERSE RPAD RPOS RSORT RTAB SET SETEXIT SIN SIZE SORT SPAN SQRT STOPTR SUBSTR TAB TABLE TAN TIME TRACE
TRIM UNLOAD VALUE VDIFFER REM ABORT FAIL SUCCEED RETURN FRETURN NRETURN CONTINUE
ALPHABET ANCHOR CODE DUMP ERRLIMIT ERRTYPE FTRACE FULLSCAN INPUT LASTNO MAXLNGTH OUTPUT
RTNTYPE STCOUNT STFCOUNT STLIMIT STNO TRIM ABEND ERRTEXT LINE FILE""".split()
UP = {b.upper(): b.upper() for b in BUILTINS}
NAME = re.compile(r'[A-Za-z][A-Za-z0-9_.]*')

def convert_line(line):
    if line[:1] == '*':                      # a comment line: untouched
        return line, 0
    out, i, n, changed = [], 0, len(line), 0
    while i < n:
        c = line[i]
        if c in "'\"":                       # string literal: copy verbatim to the matching quote
            j = line.find(c, i + 1)
            j = n if j < 0 else j + 1
            out.append(line[i:j]); i = j; continue
        m = NAME.match(line, i)
        if m:
            w = m.group(0)
            if w.upper() in UP and w != w.upper():
                out.append(w.upper()); changed += 1
            else:
                out.append(w)
            i = m.end(); continue
        out.append(c); i += 1
    return ''.join(out), changed

def convert_text(t):
    total, lines = 0, []
    for line in t.split('\n'):
        new, c = convert_line(line); total += c; lines.append(new)
    return '\n'.join(lines), total

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.stderr.write("usage: util_uppercase_snobol4_builtins.py IN OUT\n"); sys.exit(2)
    with open(sys.argv[1], 'rb') as f: raw = f.read()
    text = raw.decode('utf-8', errors='surrogateescape')
    new, n = convert_text(text)
    with open(sys.argv[2], 'wb') as f: f.write(new.encode('utf-8', errors='surrogateescape'))
    print(n)
