#!/usr/bin/env bash
# test_gate_pl_an_unknown_stream_alias_throws_and_never_dies_silently.sh -- EVERY STREAM BUILTIN HANDED AN UNKNOWN
# STREAM-OR-ALIAS THROWS A CATCHABLE existence_error(stream, A) AS THE ORACLE DOES, AND NOTHING FAILS OR EXITS
# SILENTLY; AND A REGISTERED ALIAS RESOLVES for write/2, nl/1, format/3, close/1 and set_output/1 (row
# prolog-a-user-stream-alias-is-never-registered-and-write-to-one-dies-instead-of-throwing, hq_R 2026-09-13).
#
# WHAT THIS PINS AND WHY IT IS THE WORSE HALF OF ITS ROW. ISO/IEC 13211-1 § 7.12.2 j) and § 8.11 make an unknown
# stream-or-alias an existence_error(stream, A). SCRIP threw it correctly from eighteen stream builtins and, from
# eight others, did something strictly worse than a missing feature: get_char/2, peek_char/2, get_code/2,
# peek_code/2, get_byte/2, peek_byte/2, close/1 and stream_property/2 FAILED -- observationally identical to a
# plain `fail`, rc=1, no ball, no message, invisible to catch/3. A missing error that FAILS stops a program; a
# failure indistinguishable from a legitimate one lets the caller's own if-then-else take the wrong branch and
# carry on. That is CEO-556's class, and it is why the row ordered the dying guard cured FIRST and alone.
#
# ⛔⭐ THE CAUSE WAS IN THE ASM THUNK, NOT IN THE C. Each C leaf already called pl_stream_idx_ball and produced a
# perfectly correct ball. rtx_plunify.s has two thunk macros over one calling convention: PL_CTX_LEAF_BALL zeroes
# CTX_BALL, reads it back and turns it into a throw; PL_CTX_LEAF neither initialises that slot nor reads it. The
# eight were registered under the plain macro, so a correct ball went into an uninitialised stack slot and was
# never looked at again. Each side reads as finished on its own -- which is exactly why the CLASS is held by
# test_gate_pl_ctx_leaf_thunks_cannot_drop_a_ball.sh (cto, same day) and the BEHAVIOUR is held here. Neither
# gate subsumes the other: that one proves no leaf can drop a ball, this one proves the balls are the ones ISO
# asks for and that a live alias still works. Run both.
#
# ⛔ EVERY WITNESS IS GRADED THROUGH catch/3 AND OFF MARKERS THE PROGRAM ITSELF WRITES, NEVER OFF STDERR OR rc.
# The defect being pinned IS a wrong rc with an empty stream, so an rc-graded or stderr-graded witness reads
# GREEN over it. A caught ball must leave rc=0: a throw that kills the process is not a throw.
#
# ⛔ THE NO-THROW POPULATION IS THE CONTROL AND IT IS THE POINT. Over-throwing is the natural failure mode of this
# cure -- a resolver that rejects every stream passes a throw-only gate perfectly. The R rows below use a LIVE
# alias and a live handle through the same builtins and must NOT raise; they caught a real one in development,
# where routing close/1 through the direction-checking resolver made close(user_input) a permission_error.
#
# ⛔ CULPRIT/CONTEXT DETAIL IS DELIBERATELY NOT GRADED. swipl says context(system:write/2,_) where SCRIP says _G0;
# ISO leaves the second argument of error/2 implementation-defined. The gradeable invariant is the CLASS
# existence_error(stream, A) with A the offending name, and its CATCHABILITY. Both are oracle-anchored on swipl.
#
# ⛔ unget_char/2, unget_code/2 and unget_byte/2 ARE GRADED BUT NOT ORACLE-ANCHORED, AND THE DIFFERENCE IS NAMED:
# swipl has no such predicates at all (it answers existence_error(procedure, unget_char/2)), so there is no oracle
# verdict to diff. They are SCRIP extensions sharing one resolver with the six ISO siblings, so their CLASS is
# anchored by those six rather than by swipl. Writing "matches the oracle" for them would be a false provenance.
#
# ⛔ IT RESOLVES ITS SUBJECT FROM ITS OWN TREE, NOT FROM S4E_HOME (coo 2026-09-13): a gate that resolves through
# S4E_HOME grades the MAIN tree no matter which tree invoked it, so a green run in a side tree is a statement
# about a tree you did not change.
# Usage: bash ../harness/scripts/test_gate_pl_an_unknown_stream_alias_throws_and_never_dies_silently.sh [--verbose]
# EXIT 0 all witnesses graded and correct in BOTH modes; 1 at least one wrong (named); 2 REFUSED (cannot measure).
set -uo pipefail
GATE_NAME=test_gate_pl_an_unknown_stream_alias_throws_and_never_dies_silently
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
out_dir = os.path.dirname(os.path.abspath(scrip))
verbose = os.environ.get("GATE_VERBOSE", "") not in ("", "0")

# GOAL <TAB> CLASS. E:<name> = must throw a CATCHABLE existence_error(stream,<name>). I = instantiation_error.
# D = domain_error(stream_or_alias,_). S:<name> = domain_error(stream,<name>), the ISO core's answer where it and swipl
# conflict: stream_property/2 on an atom that is no stream (ISO conformance case sics_stream_property_2_03,
# corpus packages/prolog/logtalk_iso/predicates/stream_property_2/tests.lgt, and gprolog; swipl says existence_error;
# the superset's ISO core wins a conflict, CEO-391/CEO-1305). R = must NOT raise AND must succeed (the control population: a live alias
# or handle). N = must NOT raise but MAY legitimately fail -- for a TEST predicate whose failure is an answer,
# not an error. at_end_of_stream/1 on a non-empty stream is the only one here: it correctly fails, in SCRIP and
# in swipl alike, and grading it R reported the compiler wrong when the control row was wrong. The row is kept
# rather than deleted because "does not raise on a live alias" is exactly what it is here to prove.
# nos is never opened, so it names no stream and no alias.
THROW = r"""write(nos, a)	E:nos
nl(nos)	E:nos
writeln(nos, a)	E:nos
print(nos, a)	E:nos
writeq(nos, a)	E:nos
write_canonical(nos, a)	E:nos
write_term(nos, a, [])	E:nos
format(nos, "x~n", [])	E:nos
tab(nos, 2)	E:nos
put_char(nos, a)	E:nos
put_code(nos, 0'a)	E:nos
put_byte(nos, 65)	E:nos
flush_output(nos)	E:nos
set_output(nos)	E:nos
set_input(nos)	E:nos
at_end_of_stream(nos)	E:nos
read(nos, _T)	E:nos
read_term(nos, _T, [])	E:nos
get_char(nos, _C)	E:nos
peek_char(nos, _C)	E:nos
get_code(nos, _C)	E:nos
peek_code(nos, _C)	E:nos
get_byte(nos, _B)	E:nos
peek_byte(nos, _B)	E:nos
close(nos)	E:nos
stream_property(nos, alias(_A))	S:nos
unget_char(nos, a)	E:nos
unget_code(nos, 0'a)	E:nos
unget_byte(nos, 65)	E:nos
write(_V, a)	I
nl(_V)	I
close(_V)	I
get_char(_V, _C)	I
set_output(_V)	I
write(3.5, a)	D
close(3.5)	D
get_char(3.5, _C)	D
set_output(3.5)	D
"""

# The control population. Each runs against a stream opened as open('g.txt', MODE, S, [alias(al)]) and must not
# raise. `al` is the registered alias; `S` is the handle. The DONE-WHEN's named five are the first five rows.
RESOLVE = r"""w	write(al, hello)	R
w	nl(al)	R
w	format(al, "x ~w~n", [1])	R
w	(set_output(al), write(viacur), set_output(user_output))	R
w	close(al)	R
w	write_term(al, f(a), [quoted(true)])	R
w	writeq(al, 'A b')	R
w	print(al, a)	R
w	put_char(al, x)	R
w	tab(al, 1)	R
w	flush_output(al)	R
w	stream_property(al, alias(_A))	R
w	stream_property(al, mode(write))	R
w	write(S, viahandle)	R
w	stream_property(S, alias(al))	R
r	get_char(al, _C)	R
r	peek_char(al, _C)	R
r	get_code(al, _C)	R
r	peek_code(al, _C)	R
r	at_end_of_stream(al)	N
r	read_term(al, _T, [])	R
r	get_char(S, _C)	R
r	close(al)	R
"""

tmp = tempfile.mkdtemp()

def build_m4(prog, tag):
    s = os.path.join(tmp, tag + ".s"); b = os.path.join(tmp, tag + ".bin")
    c = subprocess.run([scrip, "--compile", f"--out={s}", prog], capture_output=True, text=True, timeout=60,
                       stdin=subprocess.DEVNULL, cwd=tmp)
    if c.returncode != 0: return None
    g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                        "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm", "-lpthread"],
                       capture_output=True, text=True, timeout=120, cwd=tmp)
    return b if g.returncode == 0 else None

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=20, stdin=subprocess.DEVNULL, cwd=tmp)

# The witness writes its own verdict marker, so neither rc nor stderr is the evidence. @NO means the goal
# completed without raising; @BALL(...) carries the ball; @FAILED means it failed -- the defect's own signature.
THROW_SRC = (":- initialization(main).\n"
             "main :- catch( ( ( %s ) -> write('@NO') ; write('@FAILED') ), E, ( write('@BALL('), writeq(E), write(')') ) ), nl.\n")
RESOLVE_SRC = (":- initialization(main).\n"
               "main :- open('g.txt', %s, S, [alias(al)]),\n"
               "        catch( ( ( %s ) -> write(user_output, '@NO') ; write(user_output, '@FAILED') ), E,\n"
               "               ( write(user_output, '@BALL('), writeq(user_output, E), write(user_output, ')') ) ),\n"
               "        nl(user_output).\n")

def classify(o):
    if "@BALL(" in o:
        return "BALL", o[o.find("@BALL(") + 6:o.rfind(")")]
    if "@NO" in o: return "NO", None
    if "@FAILED" in o: return "FAILED", None
    return "NO-MARKER", None

rows = []; graded = 0; fails = 0

def grade(label, want, o, rc, mode):
    global graded, fails
    graded += 1
    kind, ball = classify(o)
    if kind == "NO-MARKER":
        fails += 1; rows.append((label, mode, want, "printed NO MARKER at all (rc=%d) -- the program died before it could report" % rc)); return
    if rc != 0:
        fails += 1; rows.append((label, mode, want, "rc=%d -- a raise must be CAUGHT, not fatal" % rc)); return
    if want == "N":
        if kind in ("NO", "FAILED"): return
        fails += 1; rows.append((label, mode, "no raise (may fail)", "raised %s on a LIVE alias -- the cure over-throws" % ball)); return
    if want == "R":
        if kind == "NO": return
        if kind == "FAILED": fails += 1; rows.append((label, mode, "no raise, succeeds", "FAILED on a LIVE alias -- the cure over-rejects")); return
        fails += 1; rows.append((label, mode, "no raise, succeeds", "raised %s on a LIVE alias -- the cure over-throws" % ball)); return
    # a throw is wanted
    if kind == "FAILED":
        fails += 1; rows.append((label, mode, want, "FAILED SILENTLY -- indistinguishable from a legitimate failure, invisible to catch/3 (THE DEFECT)")); return
    if kind == "NO":
        fails += 1; rows.append((label, mode, want, "succeeded on a stream that does not exist (SILENT WRONG ANSWER)")); return
    if want.startswith("E:"):
        nm = want[2:]
        if ("existence_error(stream," + nm) not in ball.replace(" ", ""):
            fails += 1; rows.append((label, mode, "existence_error(stream,%s)" % nm, "raised %s" % ball))
    elif want.startswith("S:"):
        nm = want[2:]
        if ("domain_error(stream," + nm) not in ball.replace(" ", ""):
            fails += 1; rows.append((label, mode, "domain_error(stream,%s)" % nm, "raised %s" % ball))
    elif want == "I":
        if "instantiation_error" not in ball:
            fails += 1; rows.append((label, mode, "instantiation_error", "raised %s" % ball))
    elif want == "D":
        if "domain_error(stream_or_alias" not in ball.replace(" ", ""):
            fails += 1; rows.append((label, mode, "domain_error(stream_or_alias,_)", "raised %s" % ball))

tests = [l.split("\t") for l in THROW.strip().split("\n") if l.strip()]
for i, (goal, want) in enumerate(tests):
    prog = os.path.join(tmp, "t%d.pl" % i)
    with open(prog, "w") as f: f.write(THROW_SRC % goal)
    b = build_m4(prog, "t%d" % i)
    for mode in ("m3", "m4"):
        if mode == "m4" and b is None:
            graded += 1; fails += 1; rows.append((goal, mode, want, "NOBUILD -- --compile or the link failed")); continue
        try: r = run([scrip, prog] if mode == "m3" else [b])
        except subprocess.TimeoutExpired:
            graded += 1; fails += 1; rows.append((goal, mode, want, "TIMEOUT")); continue
        grade(goal, want, r.stdout, r.returncode, mode)

rtests = [l.split("\t") for l in RESOLVE.strip().split("\n") if l.strip()]
for i, (fmode, goal, want) in enumerate(rtests):
    prog = os.path.join(tmp, "r%d.pl" % i)
    omode = "write" if fmode == "w" else "read"
    with open(prog, "w") as f: f.write(RESOLVE_SRC % (omode, goal))
    # a read witness needs the file to exist with content; recreate it before every run
    b = build_m4(prog, "r%d" % i)
    for mode in ("m3", "m4"):
        with open(os.path.join(tmp, "g.txt"), "w") as f: f.write("seed.\n")
        if mode == "m4" and b is None:
            graded += 1; fails += 1; rows.append((goal, mode, want, "NOBUILD -- --compile or the link failed")); continue
        try: r = run([scrip, prog] if mode == "m3" else [b])
        except subprocess.TimeoutExpired:
            graded += 1; fails += 1; rows.append((goal, mode, want, "TIMEOUT")); continue
        grade(goal, want, r.stdout, r.returncode, mode)

want_n = (len(tests) + len(rtests)) * 2
if graded == 0:
    print("⛔ REFUSED(2) [%s]: graded ZERO witnesses -- a runner that cannot measure must never print the success "
          "shape." % os.environ.get("GATE_NAME", "gate"), file=sys.stderr)
    sys.exit(2)
if graded != want_n:
    print("⛔ REFUSED(2): graded %d witnesses where the tables hold %d x 2 modes = %d. The denominator is part of "
          "the verdict; a board that cannot say what it graded must refuse." % (graded, len(tests) + len(rtests), want_n),
          file=sys.stderr)
    sys.exit(2)
print("unknown-stream-alias throw audit: %d witnesses graded (%d throw x 2 modes + %d live-alias control x 2 modes), "
      "%d wrong" % (graded, len(tests), len(rtests), fails))
if verbose and not fails:
    print("   every throw row raised a catchable existence_error(stream,_) with rc=0 in BOTH modes; every control "
         "row resolved its live alias without raising")
if not fails:
    print("PASS: no stream builtin fails or dies silently on an unknown stream-or-alias, and a registered alias "
          "resolves through all %d control witnesses." % len(rtests))
    sys.exit(0)
print("\n⛔ FAIL: %d of %d witnesses wrong." % (fails, graded))
for label, mode, want, got in rows:
    print("   %-34s %-3s want %-32s %s" % (label[:34], mode, want[:32], got))
sys.exit(1)
PY
