#!/usr/bin/env bash
# test_gate_pl_term_inspection_iso_errors.sh — the term-inspection builtins must RAISE the ISO error, not fail and
# not succeed, AND must keep failing/succeeding where the standard says so (row prolog-term-inspection-arg-and-
# functor-do-not-validate-arguments-so-iso-errors-never-fire, hq_R 2026-09-05).
#
# WHAT THIS PINS. ISO/IEC 13211-1 § 8.5.1 functor/3 and § 8.5.2 arg/3 say each raises on an unbound or wrongly-typed
# argument. SCRIP validated nothing: the INRIA census (hq_R, SCRIP 23c6e45d6, board 316/445 outcome-class) found all
# 6 arg error goals returning a bare failure, 5 of 6 functor error goals returning a bare failure, and
# functor(T,foo,-1) returning a bare SUCCESS -- i.e. building a term of arity -1 rather than raising domain_error.
#
# ⛔⭐ THIS GATE GRADES TWO POPULATIONS, AND THE SECOND IS THE POINT. A gate that only checks that the error goals
# raise is passed just as well by a builtin that raises on EVERYTHING -- over-raising is the natural failure mode of
# an argument-validation cure, and it breaks working programs silently. So the RAISE population (12) is graded
# beside a NO-RAISE population (9) drawn from the same vendored families: the successes ISO requires, and the plain
# failures (arg past the arity, functor with the wrong arity) that must stay failures. 21 witnesses, both modes.
#
# ⛔ THE ERROR TERM IS GRADED WHOLE, NOT BY ITS FUNCTOR. `type_error(compound,atom)` and `type_error(integer,a)`
# share a functor and are different defects; the INRIA census's own "want error, got error -- right class, wrong
# functor" bucket is exactly this class. Grading the functor alone would let a cure that raises the right KIND with
# the wrong CULPRIT read green, which is the error a validation cure is most likely to make.
#
# ⛔ THE WITNESSES ARE THE VENDORED SUITE'S OWN, not hand-invented: every RAISE row is an entry of
# corpus/packages/prolog/inriasuite/{arg,functor} with its expected term copied from that file, and every NO-RAISE
# row is an entry of the same two files expecting success or failure. Nothing here is transcribed from memory.
#
# ⛔ TWO SUITE ENTRIES ARE DELIBERATELY OUT OF SCOPE and are named rather than dropped silently:
#     [(current_prolog_flag(max_arity,A), X is A + 1, functor(T,foo,X)), representation_error(max_arity)]
# in both `functor` and `functor-bis` -- current_prolog_flag/2 is NOBUILD on this engine (Prolog ladder rung 7,
# ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § E), so the goal never reaches functor/3 at all. That is hq_C's ladder rung,
# not a builtins gap, and grading this row on it would grade this lane on another lane's unbuilt rung.
#
# ⭐ NOTE ON `functor-bis`, because the vendor board will look wrong to anyone who does not know: it is an
# UNDOCUMENTED NEGATIVE-CONTROL file -- absent from the suite README's own 67-file list, carrying the authors'
# comments "Must fail" / "Must succeed" / "Must instantiate Y by 3" against deliberately WRONG expectations. Its
# entry [functor(X,foo,a), failure] (commented "type_error(integer,a) expected") passed only while scrip was wrong
# in the same direction, and it MUST go red when this cure lands. A cure that leaves it green has not raised.
#
# Usage: bash ../harness/scripts/test_gate_pl_term_inspection_iso_errors.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_term_inspection_iso_errors
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLT_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys, re
scrip = os.environ["PLT_SCRIP"]
# goal <TAB> expectation. "E:<term>" = must raise exactly that ISO error term; "S" = must succeed; "F" = must fail.
# Every row is an entry of corpus/packages/prolog/inriasuite/{arg,functor}; see this script's header.
W = """arg(X,foo(a,b),a)\tE:instantiation_error
arg(1,X,a)\tE:instantiation_error
arg(0,atom,A)\tE:type_error(compound,atom)
arg(0,3,A)\tE:type_error(compound,3)
arg(-3,foo(a,b),A)\tE:domain_error(not_less_than_zero,-3)
arg(a,foo(a,b),X)\tE:type_error(integer,a)
functor(X,Y,3)\tE:instantiation_error
functor(X,foo,N)\tE:instantiation_error
functor(X,foo,a)\tE:type_error(integer,a)
functor(F,1.5,1)\tE:type_error(atom,1.5)
functor(F,foo(a),1)\tE:type_error(atomic,foo(a))
functor(T,foo,-1)\tE:domain_error(not_less_than_zero,-1)
arg(1,foo(a,b),a)\tS
arg(2,foo(a,f(X,b),c),f(a,Y))\tS
arg(3,foo(3,4),N)\tF
arg(0,foo(a,b),foo)\tF
functor(foo(a,b,c),foo,3)\tS
functor(X,foo,0)\tS
functor(X,1.1,0)\tS
functor([],[],0)\tS
functor(foo(a),foo,2)\tF"""
tests = [tuple(l.split("\t")) for l in W.split("\n") if l.strip()]
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl")
out_dir = os.path.dirname(scrip)
# ⛔ THE INNER TERM IS TAKEN BY BALANCED PARENS, NOT BY A REGEX ALTERNATION. scrip prints ISO errors as
# error(Subtype(...), Context); the subtype's own arguments contain commas and parens (type_error(atomic,foo(a))),
# so a comma-split or a lazy regex truncates exactly the witnesses this gate exists to tell apart.
def inner_term(text):
    i = text.find("@ER(")
    if i < 0: return None
    s = text[i + 4:]
    if not s.startswith("error("): return None
    s = s[6:]; d = 0
    for k, ch in enumerate(s):
        if ch == "(": d += 1
        elif ch == ")": d -= 1
        elif ch == "," and d == 0: return s[:k].strip()
    return None
rows = []; graded = 0; fails = 0
for goal, want in tests:
    with open(prog, "w") as f:
        f.write(":- catch( ( %s -> write('@OK') ; write('@NO') ), E, ( write('@ER('), write(E), write(')') ) ), nl.\n" % goal)
    for mode in ("m3", "m4"):
        try:
            if mode == "m3":
                r = subprocess.run([scrip, prog], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
                o = r.stdout
            else:
                s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
                c = subprocess.run([scrip, "--compile", f"--out={s}", prog], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
                if c.returncode != 0: graded += 1; fails += 1; rows.append((goal, mode, want, "NOBUILD")); continue
                g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                                    "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm"], capture_output=True, text=True, timeout=90, cwd=tmp)
                if g.returncode != 0: graded += 1; fails += 1; rows.append((goal, mode, want, "NOLINK")); continue
                r = subprocess.run([b], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
                o = r.stdout
        except subprocess.TimeoutExpired:
            graded += 1; fails += 1; rows.append((goal, mode, want, "TIMEOUT")); continue
        graded += 1
        raised = inner_term(o) if "@ER" in o else None
        if want.startswith("E:"):
            exp = want[2:]
            if raised is None:
                if   "@OK" in o: fails += 1; rows.append((goal, mode, exp, "SUCCEEDED (no error raised)"))
                elif "@NO" in o: fails += 1; rows.append((goal, mode, exp, "FAILED (no error raised)"))
                else:            fails += 1; rows.append((goal, mode, exp, "NO-CLASS (no @OK/@NO/@ER in output)"))
            elif raised.replace(" ", "") != exp.replace(" ", ""):
                fails += 1; rows.append((goal, mode, exp, "raised " + raised))
        elif want == "S":
            if   raised is not None: fails += 1; rows.append((goal, mode, "success", "raised " + raised + " (OVER-RAISED)"))
            elif "@NO" in o:         fails += 1; rows.append((goal, mode, "success", "FAILED"))
            elif "@OK" not in o:     fails += 1; rows.append((goal, mode, "success", "NO-CLASS"))
        else:
            if   raised is not None: fails += 1; rows.append((goal, mode, "failure", "raised " + raised + " (OVER-RAISED)"))
            elif "@OK" in o:         fails += 1; rows.append((goal, mode, "failure", "SUCCEEDED"))
            elif "@NO" not in o:     fails += 1; rows.append((goal, mode, "failure", "NO-CLASS"))
# ⛔ A GATE THAT GRADED NOTHING REFUSES -- it never prints the success shape (RULES.md).
if graded == 0:
    print("⛔ REFUSED(2) [test_gate_pl_term_inspection_iso_errors]: graded ZERO witnesses"); sys.exit(2)
for goal, mode, want, got in rows[:80]:
    print("    %-32s %s  want %-30s got %s" % (goal[:32], mode, want, got))
nraise = sum(1 for _, w in tests if w.startswith("E:"))
print("PLTERMINSP_BOARD witnesses=%d (raise=%d no-raise=%d) modes=2 graded=%d PASS=%d FAIL=%d"
      % (len(tests), nraise, len(tests) - nraise, graded, graded - fails, fails))
sys.exit(1 if fails else 0)
PY
_prc=${PIPESTATUS[0]}
if [ "$_prc" = "0" ]; then echo "GATE PASS(0) [$GATE_NAME]: arg/3 and functor/3 raise their exact ISO error terms in BOTH modes, and still succeed/fail where the standard says so"
elif [ "$_prc" = "2" ]; then echo "GATE UNPROVEN(2) [$GATE_NAME]"
else echo "GATE FAIL($_prc) [$GATE_NAME]: a term-inspection builtin did not raise the ISO error term the standard requires, or raised where it must not"; fi
gate_stamp
exit "$_prc"
