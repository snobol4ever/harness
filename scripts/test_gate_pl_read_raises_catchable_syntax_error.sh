#!/usr/bin/env bash
# test_gate_pl_read_raises_catchable_syntax_error.sh — read/1, read/2, read_term/2,3 must raise a CATCHABLE
# syntax_error on malformed input instead of handing back a plausible WRONG term (row
# prolog-read-2-returns-a-plausible-wrong-term-on-malformed-input-instead-of-raising-syntax-error, hq_R 2026-09-06).
#
# WHAT THIS PINS. ISO/IEC 13211-1 § 8.14.1 (read_term/3) says a term that cannot be parsed raises syntax_error.
# SCRIP did two different wrong things, both silent, and they share one cure surface in the reader:
#   (1) INPUT THAT ENDS WITHOUT AN END TOKEN returned a plausible WRONG TERM. pl_read_term_text() returned "got a
#       term" on EOF, and pl_parse_term_text() wraps the text as '$rd'(TEXT) -- so the wrap's own closing paren
#       silently closed the user's unclosed one. `foo(a,b` read back as foo(a,b), rc=0, nothing on stderr.
#   (2) INPUT THE PARSER REJECTED made the goal FAIL silently. pl_parse_term_text() returned 0 and the leaf
#       returned a bare failure, so `foo bar baz.` neither bound nor raised.
#
# ⛔⭐ THIS IS THE FAILURE SHAPE THAT OUTRANKS BIGGER BOARD MOVERS. A missing error that FAILS stops a program; a
# missing error that returns a PLAUSIBLE WRONG ANSWER lets it continue and corrupt what it touches. It is also the
# one class our own suites structurally cannot catch: a wrong term diffs GREEN against a ref cut from the same
# wrong behaviour. Every witness here is therefore ORACLE-CUT, never self-pinned.
#
# ⛔⭐ EVERY WITNESS IS GRADED THROUGH catch/3, NEVER OFF STDERR. rt_pl_iso_throw_* prints a stderr line that is
# byte-identical to the real uncaught-ball reporter (FINDING-2026-09-06-hq_R), so a stderr-graded witness reads
# GREEN over this exact defect. The gate reads @OK/@ER markers the program itself writes, and grades rc beside them.
#
# ⛔ THE NO-RAISE POPULATION IS THE CONTROL AND IT IS THE POINT. Over-raising is the natural failure mode of a
# reader-validation cure -- a reader that rejects everything passes a raise-only gate perfectly. The controls
# caught a real one during development: `0'a.` (a character-code constant, ISO § 6.4.4) was read as an opening
# quote, so the term ran to EOF and the new end-token test called a well-formed term a syntax error.
#
# ⛔ CULPRIT DETAIL IS DELIBERATELY NOT GRADED. swipl says syntax_error(end_of_file) where gprolog says
# syntax_error(', or ) expected'); ISO leaves the culprit loose. Both oracles agree on the CLASS and the
# CATCHABILITY for every witness below, and that agreement is the whole gradeable invariant.
#
# ⛔ RESIDUE CURED 2026-09-06 (seat09/hq_C, row prolog-frontend-accepts-malformed-terms-and-reports-no-error-so-
# read2-cannot-raise-syntax-error). The frontend used to silently accept five malformed inputs: pt_primary's
# default case swallowed an unexpected token with no diagnostic (and since pt_primary always consumes a token
# before dispatching, the evidence was gone before anyone could complain), and several "consume the closing
# delimiter if it's there" call sites had no else-branch for when it wasn't. Both are cured in prolog_parse.c;
# the five now raise like any other malformed input and are graded as ordinary E rows in the W table below,
# beside the controls that prove the cure did not over-raise (a bare comma is now always a syntax error, but
# ';' unquoted, '-' as an atom, and character-code literals are untouched).
# ⛔ atom_to_term/3 and term_to_atom/2 reach the same validator and therefore no longer return a wrong term, but
# they FAIL where swipl RAISES -- they are not ISO 8.14 read builtins and are not wired to a ball, so they are NOT
# graded here. Naming them: a silent failure is a strict improvement on a silent wrong answer and is still wrong.
# Usage: bash ../harness/scripts/test_gate_pl_read_raises_catchable_syntax_error.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_read_raises_catchable_syntax_error
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLR_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys
scrip = os.environ["PLR_SCRIP"]
# input-text <TAB> expectation. "E" = read must raise a CATCHABLE syntax_error; "T:<term>" = read must NOT raise and
# must write exactly <term>; "T" = must not raise (term text left ungraded where the two oracles disagree on it).
# Every row's class was cut from BOTH swipl 9.x and gprolog 1.4.5 on 2026-09-06; they agree on all of them.
W = r"""foo(a,b	E
foo(	E
1 +	E
[a,b	E
{a,b	E
foo(a,]	E
'unterminated	E
foo(a,b))	E
foo bar baz	E
)	E
+.	E
foo(a,b)).	E
foo bar baz.	E
).	E
foo(a,]).	E
f(,).	E
foo(a,b,).	E
[a|].	E
1 + .	E
foo(a,b).	T:foo(a,b)
- .	T:-
[].	T:[]
'hello world'.	T:hello world
1+2*3.	T:1+2*3
[a,b,c].	T:[a,b,c]
'it''s'.	T:it's
0'a.	T:97
0' .	T:32
a:-b.	T:a:-b
f(X,Y).	T
"a string".	T
%% just a comment
foo(a,b).	T:foo(a,b)"""
rows_in = [l for l in W.split("\n")]
tests = []
i = 0
while i < len(rows_in):
    l = rows_in[i]
    if l.startswith("%%"):
        tests.append((l[1:] + "\n" + rows_in[i + 1].split("\t")[0], rows_in[i + 1].split("\t")[1])); i += 2; continue
    if l.strip(): p = l.split("\t"); tests.append((p[0], p[1]))
    i += 1
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl"); inp = os.path.join(tmp, "in.txt"); out_dir = os.path.dirname(scrip)
SRC = (":- open('in.txt', read, S), catch( ( read(S,T), write('@OK('), write(T), write(')') ), E,\n"
       "   ( E = error(syntax_error(_),_) -> write('@ER') ; ( write('@OTHER('), write(E), write(')') ) ) ), nl, close(S).\n")
with open(prog, "w") as f: f.write(SRC)
def build_m4():
    s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
    c = subprocess.run([scrip, "--compile", f"--out={s}", prog], capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL, cwd=tmp)
    if c.returncode != 0: return None
    g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                        "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm", "-lpthread"], capture_output=True, text=True, timeout=90, cwd=tmp)
    return b if g.returncode == 0 else None
BIN = build_m4()
def run(mode):
    cmd = [scrip, prog] if mode == "m3" else [BIN]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
    return r.stdout, r.returncode
rows = []; graded = 0; fails = 0
for text, want in tests:
    with open(inp, "w") as f: f.write(text + "\n")
    for mode in ("m3", "m4"):
        if mode == "m4" and BIN is None: graded += 1; fails += 1; rows.append((text, mode, want, "NOBUILD")); continue
        try: o, rc = run(mode)
        except subprocess.TimeoutExpired: graded += 1; fails += 1; rows.append((text, mode, want, "TIMEOUT")); continue
        graded += 1
        got = "@ER" if "@ER" in o else ("@OK" if "@OK" in o else ("@OTHER" if "@OTHER" in o else "NO-CLASS"))
        term = o[o.find("@OK(") + 4:o.rfind(")")] if "@OK(" in o else None
        if rc != 0: fails += 1; rows.append((text, mode, want, "rc=%d (a raise must be CAUGHT, not fatal)" % rc)); continue
        if want == "E":
            if   got == "@OK":  fails += 1; rows.append((text, mode, "syntax_error", "returned term %s (SILENT WRONG ANSWER)" % term))
            elif got == "@OTHER": fails += 1; rows.append((text, mode, "syntax_error", "raised a NON-syntax_error ball"))
            elif got != "@ER":  fails += 1; rows.append((text, mode, "syntax_error", "FAILED silently (no raise, no term)"))
        else:
            if   got == "@ER":  fails += 1; rows.append((text, mode, want, "raised syntax_error (OVER-RAISED)"))
            elif got != "@OK":  fails += 1; rows.append((text, mode, want, got))
            elif want.startswith("T:") and term != want[2:]:
                fails += 1; rows.append((text, mode, want[2:], "read back %r" % term))
SIB = r"""read_term_from_atom('foo(a,b', T, [])	E
read_term_from_atom('[a,b', T, [])	E
read_term_from_atom('foo(a,b))', T, [])	E
read_term_from_atom('foo(a,b)', T, [])	T:foo(a,b)
read_term_from_atom('[a,b,c]', T, [])	T:[a,b,c]
read_term_from_atom('0''a', T, [])	T:97
read_term_from_atom('1+2*3', T, [])	T:1+2*3"""
sibs = [tuple(l.split("\t")) for l in SIB.split("\n") if l.strip()]
for goal, want in sibs:
    with open(prog, "w") as f:
        f.write(":- catch( ( %s, write('@OK('), write(T), write(')') ), E,\n"
                "   ( E = error(syntax_error(_),_) -> write('@ER') ; ( write('@OTHER('), write(E), write(')') ) ) ), nl.\n" % goal)
    B2 = build_m4()
    for mode in ("m3", "m4"):
        if mode == "m4" and B2 is None: graded += 1; fails += 1; rows.append((goal, mode, want, "NOBUILD")); continue
        try:
            cmd = [scrip, prog] if mode == "m3" else [B2]
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
            o, rc = r.stdout, r.returncode
        except subprocess.TimeoutExpired: graded += 1; fails += 1; rows.append((goal, mode, want, "TIMEOUT")); continue
        graded += 1
        got = "@ER" if "@ER" in o else ("@OK" if "@OK" in o else ("@OTHER" if "@OTHER" in o else "NO-CLASS"))
        term = o[o.find("@OK(") + 4:o.rfind(")")] if "@OK(" in o else None
        if rc != 0: fails += 1; rows.append((goal, mode, want, "rc=%d" % rc)); continue
        if want == "E":
            if got != "@ER": fails += 1; rows.append((goal, mode, "syntax_error", "returned %s" % (term if got == "@OK" else got)))
        else:
            if   got == "@ER": fails += 1; rows.append((goal, mode, want, "raised syntax_error (OVER-RAISED)"))
            elif got != "@OK": fails += 1; rows.append((goal, mode, want, got))
            elif want.startswith("T:") and term != want[2:]: fails += 1; rows.append((goal, mode, want[2:], "read back %r" % term))
# ⛔ STDERR SILENCE ON A CAUGHT SYNTAX ERROR. Both oracles print NOTHING on stderr when a syntax_error is
# caught -- measured 2026-09-06 against swipl 9.x and gprolog 1.4.5. SCRIP printed the parser's own
# "parse error: ..." diagnostic there, so a program that HANDLED the error still emitted output it never asked
# for, and any suite that merges the streams or greps stderr saw a spurious line on a passing program.
# ⭐ THE CURE MUST NOT SILENCE CONSULT: a malformed clause in a loaded file still reports loudly, which is why
# the arm below grades the READ path only and the consult path is checked separately in ARM C.
# ⛔ CONTROL OPERATORS AT TOP LEVEL OF A READ TERM. read/1 wraps the text as '$rd'(TEXT) to parse a bare term in
# clause position; with a single paren a TOP-LEVEL COMMA became $rd's own ARGUMENT SEPARATOR, so the wrap produced
# $rd/2, the arity check rejected it, and `a:-b,c.` -- an ordinary clause -- raised syntax_error. Both oracles read
# all of these. The wrap is now '$rd'((TEXT)); these witnesses pin that, and the no-comma rows are the controls
# that would catch a cure which simply stopped checking the arity.
with open(prog, "w") as f: f.write(SRC)
for text, want in (("a:-b,c.", "a:-b,c"), ("b,c;d.", "b,c;d"), ("a:-b,c;d.", "a:-b,c;d"),
                   ("a:-b,c;d->e.", "a:-b,c;d->e"), ("a:-(b,c;d).", "a:-b,c;d"),
                   ("a:-b.", "a:-b"), ("a;b.", "a;b"), ("a->b.", "a->b"), ("f(a,b).", "f(a,b)")):
    with open(inp, "w") as f: f.write(text + "\n")
    graded += 1
    r = subprocess.run([scrip, prog], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
    o = r.stdout
    if "@ER" in o: fails += 1; rows.append((text, "m3", want, "raised syntax_error on a term BOTH oracles read"))
    elif "@OK(" not in o: fails += 1; rows.append((text, "m3", want, "no term"))
    else:
        got = o[o.find("@OK(") + 4:o.rfind(")")]
        if got != want: fails += 1; rows.append((text, "m3", want, "read back %r" % got))
# ⛔ REWRITE prog FIRST: the sibling loop above overwrites it, so without this the arm silently graded a
# read_term_from_atom program instead of the stream reader and PASSED against a binary that HAD the defect.
with open(prog, "w") as f: f.write(SRC)
for text in ("f(,).", "foo(a,b,).", "[a|].", "1 + .", "foo(a,b", "foo bar baz"):
    with open(inp, "w") as f: f.write(text + "\n")
    graded += 1
    r = subprocess.run([scrip, prog], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
    if r.stderr.strip():
        fails += 1; rows.append((text, "m3", "silent stderr", "stderr=%r" % r.stderr.strip()[:60]))
# ARM C: consult MUST still report a parse error loudly -- the quiet flag is scoped to the reader, not global.
cons = os.path.join(tmp, "c.pl")
with open(cons, "w") as f: f.write("good(1).\nbad(a,) :- true.\n:- write(loaded), nl.\n")
graded += 1
rc2 = subprocess.run([scrip, cons], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
if "parse error" not in rc2.stderr:
    fails += 1; rows.append(("consult bad(a,)", "m3", "loud parse error on stderr", "stderr=%r" % rc2.stderr.strip()[:60]))
if graded == 0:
    print("⛔ REFUSED(2) [test_gate_pl_read_raises_catchable_syntax_error]: graded ZERO witnesses"); sys.exit(2)
for text, mode, want, got in rows[:80]:
    print("    %-24s %s  want %-24s got %s" % (repr(text)[:24], mode, want[:24], got))
nraise = sum(1 for _, w in tests if w == "E")
nsr = sum(1 for _, w in sibs if w == "E")
print("PLREADSYN_BOARD witnesses=%d (stream: raise=%d no-raise=%d; sibling read_term_from_atom: raise=%d no-raise=%d) modes=2 graded=%d PASS=%d FAIL=%d"
      % (len(tests) + len(sibs), nraise, len(tests) - nraise, nsr, len(sibs) - nsr, graded, graded - fails, fails))
sys.exit(1 if fails else 0)
PY
_prc=${PIPESTATUS[0]}
exit $_prc
