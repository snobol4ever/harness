#!/usr/bin/env bash
# test_gate_pl_arith_iso_errors_are_catchable.sh — arithmetic evaluation must raise a CATCHABLE ISO error, and must
# evaluate a variable bound to an unevaluated term (rows prolog-inria-arithmetic-errors-escape-catch3 and
# prolog-inria-is-nested-unevaluated-arithmetic-type-error, hq_R 2026-09-06).
#
# WHAT THIS PINS, AND WHY IT IS TWO ROWS IN ONE GATE. ISO/IEC 13211-1 § 8.6.1 (is/2) and § 8.7.1 (the arithmetic
# comparisons) say each evaluates its arguments and raises on an unbound or non-evaluable operand. SCRIP did three
# different wrong things and they share one cure surface: (1) is/2 raised through rt_pl_iso_throw_*, which is not a
# throw at all -- pl_iso_uncaught() prints to stderr and exit(1)s, so catch/3 never saw it; (2) the comparisons did
# not raise at all, they FAILED silently, which is the more dangerous shape because rc=0 and the goal just goes
# away; (3) an operand that was a variable bound through =/2 to an unevaluated term (X = 1+2, Y is X*3) raised
# type_error(evaluable,+/2) instead of evaluating to 9, because only the COMPILE-TIME expression was ever folded.
#
# ⛔⭐ THE RAISE POPULATION IS GRADED THROUGH catch/3 ON PURPOSE. That is the whole defect: an error that reaches
# the top level as a "Warning: goal raised exception" line looks correct to any grader reading stderr, and is
# invisible to every Prolog program. A witness graded on stderr text would have read GREEN throughout the bug.
#
# ⛔ THE NO-RAISE POPULATION IS THE CONTROL AND IT IS NOT DECORATION. Over-raising is the natural failure mode of
# an evaluation cure: a checker that raises on everything passes a raise-only gate perfectly while breaking every
# working program. So the must-raise witnesses are graded beside the successes and the plain failures ISO requires
# from the same vendored families (3*2 > 7-1 must FAIL, not raise; is(foo,77) must FAIL, not raise).
#
# ⛔ WITNESSES ARE THE VENDORED SUITE'S OWN. Every raise row is an entry of corpus/packages/prolog/inriasuite/
# {is,arith_gt,arith_lt,arith_gt=,arith_lt=,arith_eq,arith_diff} with its expected term copied from that file.
# ⭐ NOTE THE SHAPE OF THE COMPARISON ENTRIES: the suite writes `2 + floot(1) > 5`, so the culprit is NESTED inside
# an evaluable operator. A cure that only validates the comparison's own operands passes `floot(1) =:= 5` and still
# hard-exits on the other four families -- which is exactly how far an earlier arm of this cure got.
#
# ⛔ THE INTEGER-ONLY EVALUABLE FUNCTORS ARE GRADED HERE TOO (xor gcd >> << /\ \/ rem msb \), because they failed
# the same way the comparisons did -- SILENTLY, with rc=0 -- where ISO and swipl both raise type_error(integer,X).
# They share this cure surface exactly: the ball now has somewhere to go. Each is graded beside the value it must
# still compute (6 xor 3 =:= 5, gcd(12,18) =:= 6, msb(8) =:= 3, \(5) =:= -6) -- a raise-only gate would be passed
# by a cure that broke every one of them.
#
# Usage: bash ../harness/scripts/test_gate_pl_arith_iso_errors_are_catchable.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_arith_iso_errors_are_catchable
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLA_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys
scrip = os.environ["PLA_SCRIP"]
# goal <TAB> expectation. "E:<term>" = must raise exactly that ISO error term THROUGH catch/3; "S" = must succeed;
# "F" = must fail. "B:<term>" = must succeed and bind; see BIND rows below. Sources named in the header.
W = r"""'is'(77, N)	E:instantiation_error
'is'(77, foo)	E:type_error(evaluable,foo/0)
'is'(X, 1 + foo)	E:type_error(evaluable,foo/0)
'is'(X, 77 + N)	E:instantiation_error
'is'(X, \(1.5))	E:type_error(integer,1.5)
'is'(X, 1 xor 1.5)	E:type_error(integer,1.5)
'is'(X, gcd(1,1.5))	E:type_error(integer,1.5)
'is'(X, 1 >> 1.5)	E:type_error(integer,1.5)
'is'(X, 1 << 1.5)	E:type_error(integer,1.5)
'is'(X, 1 /\ 1.5)	E:type_error(integer,1.5)
'is'(X, 1 \/ 1.5)	E:type_error(integer,1.5)
'is'(X, rem(1,1.5))	E:type_error(integer,1.5)
'is'(X, msb(1.5))	E:type_error(integer,1.5)
'is'(X, 1 mod 0)	E:evaluation_error(zero_divisor)
'>'(X,5)	E:instantiation_error
'>'(2 + floot(1),5)	E:type_error(evaluable,floot/1)
'<'(X,5)	E:instantiation_error
'<'(2 + floot(1),5)	E:type_error(evaluable,floot/1)
'>='(X,5)	E:instantiation_error
'>='(2 + floot(1),5)	E:type_error(evaluable,floot/1)
'=<'(X,5)	E:instantiation_error
'=<'(2 + floot(1),5)	E:type_error(evaluable,floot/1)
'=:='(N,5)	E:instantiation_error
'=:='(floot(1),5)	E:type_error(evaluable,floot/1)
'=\\='(N,5)	E:instantiation_error
'=\\='(floot(1),5)	E:type_error(evaluable,floot/1)
'is'(foo,77)	F
'is'(X, 6 xor 3)	S
'is'(X, gcd(12,18))	S
'is'(X, 1 << 4)	S
'is'(X, 12 >> 2)	S
'is'(X, 12 /\ 10)	S
'is'(X, 12 \/ 3)	S
'is'(X, rem(7,2))	S
'is'(X, msb(8))	S
'is'(X, \(5))	S
'>'(0,1)	F
'>'(1.0,1)	F
'>'(3*2,7-1)	F
'<'(0,1)	S
'<'(1.0,1)	F
'<'(3*2,7-1)	F
'>='(0,1)	F
'>='(1.0,1)	S
'>='(3*2,7-1)	S
'=<'(0,1)	S
'=<'(1.0,1)	S
'=<'(3*2,7-1)	S
'=:='(0,1)	F
'=:='(1.0,1)	S
'=:='(3 * 2,7 - 1)	S
0.333 =:= 1/3	F
'=\\='(0,1)	S
'=\\='(1.0,1)	F
'=\\='(3 * 2,7 - 1)	F"""
# BIND rows: the nested-evaluation row's own witnesses -- the goal must succeed AND the check must hold.
B = r"""'is'(Result,3 + 11.0)	Result =:= 14.0
(X = 1 + 2, 'is'(Y, X * 3))	Y == 9
(X = 1 + 2, 'is'(Y, X * 3))	X == 1 + 2
(X = 1 + 2, 'is'(Y, X))	Y == 3
'is'(X,float(3))	X == 3.0
'is'(X, 6 xor 3)	X == 5
'is'(X, gcd(12,18))	X == 6
'is'(X, msb(8))	X == 3
'is'(X, \(5))	X == -6
(X = 2 + 3, Y = X * 2, 'is'(Z, Y + 1))	Z == 11"""
tests = [tuple(l.split("\t")) for l in W.split("\n") if l.strip()]
binds = [tuple(l.split("\t")) for l in B.split("\n") if l.strip()]
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl"); out_dir = os.path.dirname(scrip)
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
def run(mode):
    if mode == "m3":
        r = subprocess.run([scrip, prog], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
        return r.stdout, None
    s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
    c = subprocess.run([scrip, "--compile", f"--out={s}", prog], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
    if c.returncode != 0: return None, "NOBUILD"
    g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                        "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm"], capture_output=True, text=True, timeout=90, cwd=tmp)
    if g.returncode != 0: return None, "NOLINK"
    r = subprocess.run([b], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
    return r.stdout, None
rows = []; graded = 0; fails = 0
for goal, want in tests:
    with open(prog, "w") as f:
        f.write(":- catch( ( %s -> write('@OK') ; write('@NO') ), E, ( write('@ER('), write(E), write(')') ) ), nl.\n" % goal)
    for mode in ("m3", "m4"):
        try: o, err = run(mode)
        except subprocess.TimeoutExpired: graded += 1; fails += 1; rows.append((goal, mode, want, "TIMEOUT")); continue
        graded += 1
        if err: fails += 1; rows.append((goal, mode, want, err)); continue
        raised = inner_term(o) if "@ER" in o else None
        if want.startswith("E:"):
            exp = want[2:]
            if raised is None:
                if   "@OK" in o: fails += 1; rows.append((goal, mode, exp, "SUCCEEDED (no error raised)"))
                elif "@NO" in o: fails += 1; rows.append((goal, mode, exp, "FAILED silently (no error raised)"))
                else:            fails += 1; rows.append((goal, mode, exp, "ESCAPED catch/3 (no @OK/@NO/@ER)"))
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
for goal, chk in binds:
    with open(prog, "w") as f:
        f.write(":- catch( ( ( %s ), ( %s ) -> write('@OK') ; write('@NO') ), E, ( write('@ER('), write(E), write(')') ) ), nl.\n" % (goal, chk))
    for mode in ("m3", "m4"):
        try: o, err = run(mode)
        except subprocess.TimeoutExpired: graded += 1; fails += 1; rows.append((goal, mode, chk, "TIMEOUT")); continue
        graded += 1
        if err: fails += 1; rows.append((goal, mode, chk, err)); continue
        raised = inner_term(o) if "@ER" in o else None
        if   raised is not None: fails += 1; rows.append((goal, mode, chk, "raised " + raised))
        elif "@NO" in o:         fails += 1; rows.append((goal, mode, chk, "check FAILED (wrong binding)"))
        elif "@OK" not in o:     fails += 1; rows.append((goal, mode, chk, "NO-CLASS"))
if graded == 0:
    print("⛔ REFUSED(2) [test_gate_pl_arith_iso_errors_are_catchable]: graded ZERO witnesses"); sys.exit(2)
for goal, mode, want, got in rows[:80]:
    print("    %-34s %s  want %-28s got %s" % (goal[:34], mode, want[:28], got))
nraise = sum(1 for _, w in tests if w.startswith("E:"))
print("PLARITHISO_BOARD witnesses=%d (raise=%d no-raise=%d bind=%d) modes=2 graded=%d PASS=%d FAIL=%d"
      % (len(tests) + len(binds), nraise, len(tests) - nraise, len(binds), graded, graded - fails, fails))
sys.exit(1 if fails else 0)
PY
_prc=${PIPESTATUS[0]}
exit $_prc
