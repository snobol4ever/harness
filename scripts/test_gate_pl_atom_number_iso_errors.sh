#!/usr/bin/env bash
# test_gate_pl_atom_number_iso_errors.sh — the atom/number conversion builtins must RAISE the ISO error, not fail
# and not succeed (row prolog-atom-number-conversion-builtins-do-not-validate-arguments-so-iso-errors-never-fire,
# hq_R 2026-09-05, approved by the ceo as HQ-RESOLVE's first cure row).
#
# WHAT THIS PINS. ISO/IEC 13211-1 § 8.16 (atom_length, atom_concat, sub_atom, atom_chars, atom_codes, char_code,
# number_chars, number_codes) says each of these raises on an unbound or wrongly-typed argument. SCRIP validated
# nothing: the INRIA census (hq_R, SCRIP bba73d438, board 279/445 outcome-class) found 37 witnesses in ONE shape --
# want instantiation_error/type_error/representation_error/syntax_error, got a bare failure or a bare success.
#
# ⛔⭐ WHY THIS GATE EXISTS BESIDE test_prolog_inria_suite.sh RATHER THAN INSIDE IT. The vendor board is 445 goals
# and ~40s and moves whenever ANY lane lands anything; it answers "what is the conformance number". This answers
# "did MY class regress", in under a second, over a population that cannot drift under me. A floor gate whose
# witnesses are explicit is the point -- reading it tells you exactly what is promised, which a fraction never does.
#
# ⛔ THE WITNESSES ARE NOT TRANSCRIBED BY HAND. They were extracted mechanically from the vendored suite
# (corpus/packages/prolog/inriasuite/{atom_chars,atom_codes,atom_concat,atom_length,char_code,number_chars,
# number_codes,sub_atom}) by anchoring on the TAIL of each entry -- the expected term -- rather than splitting the
# entry at a depth-0 comma. That is deliberate: the suite's 0'c character literals (0'[ , 0'] , 0'' ) break a naive
# depth scanner, which is why the vendor runner carries a _mask_0c_lits pass. Anchoring on the tail sidesteps the
# class instead of re-implementing the mask. The extraction was CROSS-CHECKED against the vendor runner's own red
# list and agrees family-by-family; that agreement, not the extractor, is the evidence.
#
# ⛔ ONE SUITE ENTRY IS DELIBERATELY EXCLUDED and it is named here rather than dropped silently:
#     [(atom_chars(X,['1','2']), Y is X + 1), type_error(evaluable, '12'/0)]
# Its error comes from is/2, not from atom_chars/2, and arithmetic errors in this engine escape catch/3 entirely
# (measured: `catch((X is foo, write(X)), E, ...)` prints "Warning: goal raised exception" and never enters the
# recovery goal). It belongs to the arithmetic-errors-escape-catch3 row, not to this one. Curing THIS row must not
# be graded on a defect it does not own -- and that row's cure will not close this gate either, which is the honest
# split. Population here is therefore 37, and the script prints that denominator.
#
# Usage: bash ../harness/scripts/test_gate_pl_atom_number_iso_errors.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_atom_number_iso_errors
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLA_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys, re
scrip = os.environ["PLA_SCRIP"]
# goal <TAB> expected ISO error functor, or the literal `success` where the ORACLE raises nothing.
#
# ⛔⭐ TWO WITNESSES CARRY THE ORACLE'S ANSWER, NOT THE VENDOR SUITE'S, AND THEY ARE NAMED HERE RATHER THAN
# DROPPED (CEO-391: what only another implementation provides is OUTSIDE THE BASELINE -- named beside the
# suite with the oracle's own error and a source check, out of nobody's denominator, never hidden).
# The vendored INRIA entries are
#     [atom_codes(A,[ 0'i, 0's, 1000]),   representation_error(character_code)].  % 1000 not a code
#     [number_codes(A,[ 0'1, 0'2, 1000]), representation_error(character_code)].  % 1000 not a code
# and that comment is the suite author's own premise: a processor whose character set is 0..255. ISO
# 13211-1 leaves the character set IMPLEMENTATION-DEFINED, and this engine's is Unicode -- which the
# Logtalk conformance suite's whole unicode/ group tests and which atom_length('<3 Greek letters>') =:= 3
# now depends on. Measured against the oracle (swipl, the ISO superset, CEO-391 Oracles), 2026-09-13:
#     atom_codes(A,[0'i,0's,1000])    -> A = is<U+03E8>          (succeeds; NO error)
#     number_codes(A,[0'1,0'2,1000])  -> error(syntax_error(illegal_number), ...)
#     atom_codes(A,[0'i,-1])          -> error(type_error(character_code,-1), ...)   (still an error)
# So the two rows below are graded on the oracle. ⭐ The reason this is written out instead of just edited:
# a witness whose expectation is silently relaxed is indistinguishable from a witness that was never
# strict, and the next reader cannot tell a measured ruling from a convenience. hq_R owns this gate and
# was told; the cto was told.
# Everything else here is the vendored INRIA suite verbatim; see this script's header.
W = """atom_chars(A,L)\tinstantiation_error
atom_chars(A,[a,E,c])\tinstantiation_error
atom_chars(A,[a,b|L])\tinstantiation_error
atom_chars(f(a),L)\ttype_error
atom_chars(A,iso)\ttype_error
atom_chars(A,[a,f(b)])\ttype_error
atom_codes(A,L)\tinstantiation_error
atom_codes(f(a),L)\ttype_error
atom_codes(A, 0'x)\ttype_error
atom_codes(A,[ 0'i, 0's, 1000])\tsuccess
atom_concat(A1,'iso',A3)\tinstantiation_error
atom_concat('iso',A2,A3)\tinstantiation_error
atom_concat(f(a),'iso',A3)\ttype_error
atom_concat('iso',f(a),A3)\ttype_error
atom_concat(A1,A2,f(a))\ttype_error
atom_length(Atom, 4)\tinstantiation_error
atom_length(1.23, 4)\ttype_error
atom_length(atom, '4')\ttype_error
char_code('ab',Code)\ttype_error
char_code(a,x)\ttype_error
char_code(Char,Code)\tinstantiation_error
char_code(Char,-2)\trepresentation_error
number_chars(A,['3',' '])\tsyntax_error
number_chars(A,L)\tinstantiation_error
number_chars(a,L)\ttype_error
number_chars(A,4)\ttype_error
number_chars(A,['4',2])\ttype_error
number_codes(A,L)\tinstantiation_error
number_codes(a,L)\ttype_error
number_codes(A,4)\ttype_error
number_codes(A,[ 0'1, 0'2, 1000])\tsyntax_error
sub_atom(Banana, 3, 2, _, S2)\tinstantiation_error
sub_atom(f(a), 2, 2, _, S2)\ttype_error
sub_atom('Banana', 4, 2, _, 2)\ttype_error
sub_atom('Banana', a, 2, _, S2)\ttype_error
sub_atom('Banana', 4, n, _, S2)\ttype_error
sub_atom('Banana', 4, _, m, S2)\ttype_error"""
tests = [tuple(l.split("\t")) for l in W.split("\n") if l.strip()]
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl")
out_dir = os.path.dirname(scrip)
# ⛔ THE ERROR FUNCTOR IS READ FROM INSIDE THE error(...) WRAPPER. scrip prints ISO errors as
# error(Subtype(...), Context); taking the OUTERMOST functor yields the literal "error" for every single
# entry and would grade every arm identically -- the vendor runner carries the same note for the same reason.
def functor_of(text):
    m = re.search(r"@ER\(\s*error\(\s*([a-z_]+)", text)
    if m: return m.group(1)
    m = re.search(r"@ER\(\s*([a-z_]+)", text)
    return m.group(1) if m else None
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
                c = subprocess.run([scrip, "--compile", "-o", s, prog], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
                if c.returncode != 0: graded += 1; fails += 1; rows.append((goal, mode, want, "NOBUILD")); continue
                g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                                    "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm"], capture_output=True, text=True, timeout=90, cwd=tmp)
                if g.returncode != 0: graded += 1; fails += 1; rows.append((goal, mode, want, "NOLINK")); continue
                r = subprocess.run([b], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
                o = r.stdout
        except subprocess.TimeoutExpired:
            graded += 1; fails += 1; rows.append((goal, mode, want, "TIMEOUT")); continue
        graded += 1
        if "@ER" in o:
            got = functor_of(o) or "error?"
            if got == want: continue
            fails += 1; rows.append((goal, mode, want, "raised " + got))
        elif "@OK" in o:
            if want == "success": continue
            fails += 1; rows.append((goal, mode, want, "SUCCEEDED (no error raised)"))
        elif "@NO" in o: fails += 1; rows.append((goal, mode, want, "FAILED (no error raised)"))
        else:            fails += 1; rows.append((goal, mode, want, "NO-CLASS (no @OK/@NO/@ER in output)"))
# ⛔ A GATE THAT GRADED NOTHING REFUSES -- it never prints the success shape (RULES.md).
if graded == 0:
    print("⛔ REFUSED(2) [test_gate_pl_atom_number_iso_errors]: graded ZERO witnesses"); sys.exit(2)
for goal, mode, want, got in rows[:80]:
    print("    %-34s %s  want %-22s got %s" % (goal[:34], mode, want, got))
print("PLATOMNUM_BOARD witnesses=%d modes=2 graded=%d PASS=%d FAIL=%d" % (len(tests), graded, graded - fails, fails))
sys.exit(1 if fails else 0)
PY
_prc=${PIPESTATUS[0]}
if [ "$_prc" = "0" ]; then echo "GATE PASS(0) [$GATE_NAME]: every atom/number conversion witness raises its ISO error in BOTH modes"
elif [ "$_prc" = "2" ]; then echo "GATE UNPROVEN(2) [$GATE_NAME]"
else echo "GATE FAIL($_prc) [$GATE_NAME]: an atom/number conversion builtin did not raise the ISO error the standard requires"; fi
gate_stamp
exit "$_prc"
