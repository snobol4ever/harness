#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_pl_number_syntax_iso.sh — number_chars/2 and number_codes/2 must PARSE the list argument and unify
# NUMERICALLY, and must accept the ISO number syntax (row
# flip-inria-number-chars-and-codes-reject-exponent-and-character-code-number-syntax, hq_R 2026-09-06).
#
# ⛔⭐ THE `NO` CLASS SPLIT INTO `RAISE` AND `NO` ON 2026-09-13 (hq_C, CEO-660's lane). Five of the six
# no-accept witnesses were written as "must FAIL, not accept" at a time when this engine could not raise at
# all, and BOTH ORACLES RAISE ON THEM. Measured that day, goal for goal, each inside catch/3:
#     number_chars(X,['a','b'])              swipl error(syntax_error(illegal_number),...)   gprolog syntax_error
#     number_chars(X,['3','.','3','.','3'])  swipl error(syntax_error(illegal_number),...)   gprolog syntax_error
#     number_chars(X,['0',''''])             swipl error(syntax_error(illegal_number),...)   gprolog syntax_error
#     number_codes(X,[0'0,0'x])              swipl error(syntax_error(illegal_number),...)   gprolog syntax_error
#     number_codes(X,[])                     swipl error(syntax_error(illegal_number),...)   gprolog syntax_error
#     number_chars(3.3,['3','.','4'])        swipl @NO (fails)                               gprolog @NO (fails)
# ⭐ THE SIXTH IS WHY THE CLASS HAD TO SPLIT RATHER THAN BE RELABELLED WHOLESALE: it is the only one whose
# list DOES denote a number, so it is an honest unification failure and must stay a failure. A single `NO`
# bucket could not tell "this text is not a number" from "this number is not that number" -- and because
# RAISING also does not accept, the weaker expectation was satisfied by both behaviours and could never
# notice which one it had. A gate whose PASS is reachable two ways names only one of them.
#
# WHAT THIS PINS. ISO/IEC 13211-1 § 8.16.7/8.16.8 with § 6.4.4: when the list argument of number_chars/2 or
# number_codes/2 is a proper list, it is PARSED and the resulting NUMBER is unified with the first argument.
# SCRIP failed silently on four INRIA goals, and the four are TWO different defects that share one choke point:
#   (a) DIRECTION — with the first argument BOUND, the leaf converted it to CANONICAL TEXT and unified TEXT
#       LISTS, so number_chars(3.3,['3','.','3','E','+','0']) compared "3.3" against "3.3E+0" and failed.
#       ⛔ Exponent parsing was never the problem and the row's own mint text said it was: the parser already
#       yields 3.3 for that list when the first argument is unbound. Two spellings of one number are one number,
#       and only numeric unification can say so. (INRIA number_chars#309, number_codes#324.)
#   (b) SYNTAX — pl_parse_number() had no 0'c character-code constant, so "0'A" and "0'a" did not parse at all.
#       (INRIA number_chars#314, number_codes#328.)
#
# ⭐ AND ONE DEFECT NO INRIA GOAL COVERS, FOUND BY PROBING PAST THE FAILING WITNESSES AND WORSE THAN BOTH:
# number_codes(X,"0xff") returned 255.0 — a FLOAT. strtoll stopped at the 'x', and strtod then parsed "0xff"
# as a HEX FLOAT, which C99 supports and ISO Prolog does not. A silent WRONG ANSWER sitting on the same line as
# the silent failures, and invisible to the suite that sent me here. It is graded below by TYPE, not just value:
# integer(X) must hold, because 255.0 and 255 both write as a number a careless witness would accept.
#
# ⛔ THE NO-ACCEPT CONTROLS ARE THE POINT. Over-acceptance is the natural failure mode of a number-reader cure —
# a reader that accepts everything passes an accept-only gate perfectly. The reverse direction is graded too
# (number_chars(3.3,L) must still yield ['3','.','3']), because reordering the leaf to try the list first is
# exactly the edit that would break it.
#
# ⛔ ONE FORM IS DELIBERATELY NOT GRADED, BECAUSE THE ORACLES DISAGREE: "0''" (zero, quote, quote) is 39 in
# swipl 9.x and a syntax_error in gprolog 1.4.5, measured 2026-09-06. SCRIP follows swipl. That is a CHOICE and
# it is named here rather than pinned, on the same rule the read/2 gate uses for culprit text: where the two
# oracles disagree the standard is loose, and a gate that pins one vendor's reading manufactures a conformance
# claim. "0'''" (three quotes) IS graded — both oracles answer 39.
# Usage: bash ../harness/scripts/test_gate_pl_number_syntax_iso.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_number_syntax_iso
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLN_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys
scrip = os.environ["PLN_SCRIP"]; out_dir = os.path.dirname(scrip)
# goal <TAB> expectation. "OK" = must succeed. "NO" = must fail (and must NOT raise). "V:<term>" = must succeed
# and the probe's own write/1 of X must read exactly <term>.  Every OK/V row was confirmed against BOTH
# swipl 9.x and gprolog 1.4.5 on 2026-09-06 unless the header names it ungraded.
W = r"""number_chars(3.3,['3','.','3','E','+','0'])	OK	inria number_chars#309 DIRECTION
number_codes(33.0,[0'3,0'.,0'3,0'E,0'+,0'0,0'1])	OK	inria number_codes#324 DIRECTION
number_chars(A,['0','''','A']), X=A	V:65	inria number_chars#314 0'c
number_codes(A,[0'0,39,0'a]), X=A	V:97	inria number_codes#328 0'c
number_codes(X,[0'0,39,39,39])	V:39	0''' quote char, BOTH oracles agree
number_chars(X,['3','.','3','E','+','0'])	V:3.3	exponent, list->number direction
number_codes(X,[0'1,0'2])	V:12	plain integer
number_chars(X,['-','4','2'])	V:-42	negative integer
number_codes(X,[0'0,0'x,0'f,0'f])	V:255	0xff is INTEGER 255, never the float 255.0
number_codes(X,[0'0,0'o,0'1,0'7])	V:15	octal
number_codes(X,[0'0,0'b,0'1,0'1])	V:3	binary
number_chars(3.3,['3','.','3'])	OK	identical spelling still unifies
number_codes(255,[0'0,0'x,0'f,0'f])	OK	bound integer vs a radix spelling of itself
number_chars(X,['a','b'])	RAISE	not a number -- syntax_error, both oracles
number_chars(X,['3','.','3','.','3'])	RAISE	malformed float
number_chars(3.3,['3','.','4'])	NO	a DIFFERENT number must not unify -- the ONE arm that is a failure, not an error
number_chars(X,['0',''''])	RAISE	0' with no character is incomplete
number_codes(X,[0'0,0'x])	RAISE	radix prefix with no digits
number_codes(X,[])	RAISE	empty list is not a number"""
TYPE = [("number_codes(N,[0'0,0'x,0'f,0'f]), integer(N)", "0xff must be an INTEGER -- the float 255.0 writes indistinguishably"),
        ("number_codes(N,[0'1,0'2]), integer(N)", "a plain integer stays an integer"),
        ("number_chars(N,['3','.','3']), float(N)", "a float stays a float"),
        ("number_codes(N,[0'0,0'x,0'f,0'f]), \\+ float(N)", "and must NOT be a float -- this is the arm that was red before the cure")]
REV = [("number_chars(3.3,L), X=L", "[3,.,3]"), ("number_codes(12,L), X=L", "[49,50]")]
tests = [tuple(l.split("\t")) for l in W.split("\n") if l.strip()]
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl")
def write_prog(goal):
    with open(prog, "w") as f:
        f.write(":- catch( ( %s -> ( write('@OK('), write(X), write(')') ) ; write('@NO') ), E,\n"
                "   ( write('@ER('), write(E), write(')') ) ), nl.\n" % goal)
def build_m4():
    s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
    c = subprocess.run([scrip, "--compile", f"--out={s}", prog], capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL, cwd=tmp)
    if c.returncode != 0: return None
    g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                        "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm", "-lpthread"], capture_output=True, text=True, timeout=90, cwd=tmp)
    return b if g.returncode == 0 else None
def run_both(goal):
    write_prog(goal); b = build_m4(); res = []
    for mode in ("m3", "m4"):
        if mode == "m4" and b is None: res.append(("NOBUILD", -1)); continue
        try: r = subprocess.run([scrip, prog] if mode == "m3" else [b], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
        except subprocess.TimeoutExpired: res.append(("TIMEOUT", -1)); continue
        o = r.stdout.strip()
        res.append((o, r.returncode))
    return res
rows = []; graded = 0; fails = 0
def val(o):
    return o[o.find("@OK(") + 4:o.rfind(")")] if "@OK(" in o else None
for goal, want, why in tests:
    g2 = goal if ("X=" in goal or "X," in goal or "(X," in goal) else goal + ", X=yes"
    for mode, (o, rc) in zip(("m3", "m4"), run_both(g2)):
        graded += 1
        if rc != 0: fails += 1; rows.append((goal, mode, want, "rc=%d %s" % (rc, o[:40]))); continue
        if want == "RAISE":
            if "syntax_error" not in o: fails += 1; rows.append((goal, mode, "@ER syntax_error", "%s   [%s]" % (o[:44], why)))
        elif want == "NO":
            if "@NO" not in o: fails += 1; rows.append((goal, mode, "@NO (must not accept)", "%s   [%s]" % (o[:44], why)))
        elif want == "OK":
            if "@OK" not in o: fails += 1; rows.append((goal, mode, "@OK", "%s   [%s]" % (o[:44], why)))
        else:
            v = val(o)
            if v != want[2:]: fails += 1; rows.append((goal, mode, want[2:], "%s   [%s]" % (o[:44], why)))
for goal, why in TYPE:
    for mode, (o, rc) in zip(("m3", "m4"), run_both(goal + ", X=ok")):
        graded += 1
        if rc != 0 or "@OK" not in o: fails += 1; rows.append((goal, mode, "@OK (type holds)", "%s   [%s]" % (o[:44], why)))
for goal, want in REV:
    for mode, (o, rc) in zip(("m3", "m4"), run_both(goal)):
        graded += 1
        v = val(o)
        if rc != 0 or v != want: fails += 1; rows.append((goal, mode, want, "%s   (reverse direction)" % (o[:44])))
if graded == 0:
    print("⛔ REFUSED(2) [test_gate_pl_number_syntax_iso]: graded ZERO witnesses"); sys.exit(2)
for goal, mode, want, got in rows[:80]:
    print("    %-44s %s  want %-22s got %s" % (goal[:44], mode, want[:22], got))
print("    UNGRADED BY DESIGN: number_codes(X,[0'0,39,39])  \"0''\"  -- swipl 9.x says 39, gprolog 1.4.5 raises syntax_error; SCRIP follows swipl, named not pinned")
print("PLNUMSYN_BOARD witnesses=%d (accept/value=%d raise=%d no-accept=%d type=%d reverse=%d) modes=2 graded=%d PASS=%d FAIL=%d"
      % (len(tests) + len(TYPE) + len(REV), sum(1 for _, w, _ in tests if w not in ("NO", "RAISE")),
         sum(1 for _, w, _ in tests if w == "RAISE"), sum(1 for _, w, _ in tests if w == "NO"),
         len(TYPE), len(REV), graded, graded - fails, fails))
sys.exit(1 if fails else 0)
PY
_prc=${PIPESTATUS[0]}
exit $_prc
