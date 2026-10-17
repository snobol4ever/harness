#!/usr/bin/env bash
# test_gate_pl_atom_concat_modes.sh — atom_concat/3 must work in ALL THREE modes, and the nondeterministic one is a
# GENERATOR (row flip-inria-atom-concat-3-implements-only-the-forward-mode, hq_R 2026-09-07).
#
# WHAT THIS PINS. ISO/IEC 13211-1 § 8.16.2. atom_concat(A,B,C) has three modes and SCRIP shipped only the first:
#   (+,+,-) forward      -- concatenate. Worked all along, and ARM B is the control that it still does.
#   (-,+,+) / (+,-,+)    -- deterministic decomposition. Cured at `028fcd764`; INRIA atom_concat#98.
#   (-,-,+) nondetermin. -- enumerate every split of C. THE SECOND HALF, cured here; INRIA atom_concat#100.
# Before this gate existed both reverse modes FAILED SILENTLY -- not an error, not a refusal, just `fail`, which is
# a plausible wrong answer a program cannot distinguish from "no such split".
#
# ⛔⭐ THE NONDETERMINISTIC MODE IS THE WHOLE POINT, AND A ONE-SOLUTION PASS IS THE FAILURE THIS GATE EXISTS TO CATCH.
# During the cure the generator was wired without its recede edge and returned the LEAF instead of the generator; it
# then yielded exactly the FIRST split of every atom. Every single-solution probe -- atom_concat(X,Y,'') among them --
# passed perfectly, because one solution is the right answer when there is only one. ARM A therefore grades whole
# SOLUTION LISTS through findall/3, in oracle order, never "did it succeed": a generator that stops early is
# indistinguishable from a correct one at any single call site.
#
# ⛔ EVERY EXPECTATION IS ORACLE-CUT from BOTH swipl 9.x and gprolog 1.4.5, measured 2026-09-07 through a CONSULTED
# FILE rather than a shell argument, so no quoting could mangle a witness. The two agree exactly on every row this
# gate COUNTS, including enumeration order.
#
# ⚠️⭐ TWO CASES ARE PRINTED AND DELIBERATELY NOT COUNTED, BECAUSE THE ORACLES THEMSELVES DISAGREE (ARM E). swipl
# takes atom_concat(1,2,X) and binds X='12', where gprolog raises type_error(atom,1); and for a compound argument
# swipl says type_error(ATOMIC,f(x)) where gprolog says type_error(ATOM,f(x)). SCRIP matches gprolog on both, which
# is the stricter ISO § 8.16.2.3 reading, and INRIA is an ISO conformance suite. Pinning either would be this gate
# picking a winner between two oracles on a point the standard leaves them room on -- so it reports the split and
# grades neither. A disagreement between oracles is evidence about the STANDARD, not a defect in the compiler.
# Usage: bash ../harness/scripts/test_gate_pl_atom_concat_modes.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_atom_concat_modes
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLAC_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys
scrip = os.environ["PLAC_SCRIP"]; out_dir = os.path.dirname(scrip)
# name <TAB> goal body that writes exactly one token <TAB> expected stdout <TAB> note
ROWS = r"""enum_abc	findall(X-Y, atom_concat(X,Y,abc), L), write(L)	[-abc,a-bc,ab-c,abc-]	A: INRIA atom_concat#100 -- all four splits, in order
enum_ab	findall(X-Y, atom_concat(X,Y,ab), L), write(L)	[-ab,a-b,ab-]	A: three splits
enum_a	findall(X-Y, atom_concat(X,Y,a), L), write(L)	[-a,a-]	A: two splits of a one-char atom
enum_empty	findall(X-Y, atom_concat(X,Y,''), L), write(L)	[-]	A: the empty atom still has exactly one split
enum_same_var	findall(X, atom_concat(X,X,abab), L), write(L)	[ab]	A: SAME variable both sides -- unification filters the enumeration
enum_suffix_fixed	findall(X, atom_concat(X,'',abc), L), write(L)	[abc]	A: bound empty suffix selects one split
enum_prefix_fixed	findall(Y, atom_concat('',Y,abc), L), write(L)	[abc]	A: bound empty prefix selects one split
enum_no_dup	findall(X-Y, atom_concat(X,Y,aa), L), write(L)	[-aa,a-a,aa-]	A: repeated characters do not collapse or duplicate splits
fwd	atom_concat(hello,' world',Z), write(Z)	hello world	B: the forward mode must be unchanged
rev_prefix	atom_concat(T,' world','small world'), write(T)	small	B: INRIA atom_concat#98, deterministic (-,+,+)
rev_suffix	atom_concat(small,S,'small world'), write(S)	 world	B: deterministic (+,-,+)
neg_prefix	( atom_concat(zz,_,'small world') -> write('@YES') ; write('@NO') )	@NO	C: a non-matching prefix FAILS, never binds something plausible
neg_suffix	( atom_concat(_,zz,'small world') -> write('@YES') ; write('@NO') )	@NO	C: a non-matching suffix FAILS
neg_both	( atom_concat(a,b,xyz) -> write('@YES') ; write('@NO') )	@NO	C: a wrong concatenation FAILS
err_all_unbound	catch((atom_concat(_,_,_),write('@NO')),E,(E=error(instantiation_error,_)->write('@MATCH');(write('@BALL('),write(E),write(')'))))	@MATCH	D: § 8.16.2.3 -- C unbound and an input unbound
err_b_and_c	catch((atom_concat(a,_,_),write('@NO')),E,(E=error(instantiation_error,_)->write('@MATCH');(write('@BALL('),write(E),write(')'))))	@MATCH	D: A bound is not enough
err_a_and_c	catch((atom_concat(_,b,_),write('@NO')),E,(E=error(instantiation_error,_)->write('@MATCH');(write('@BALL('),write(E),write(')'))))	@MATCH	D: B bound is not enough"""
# ARM E -- PRINTED, NEVER COUNTED: the two rows where swipl and gprolog give different answers (see the banner).
SPLIT = [("num_args", "catch((atom_concat(1,2,X),write(X)),E,(write('@BALL('),write(E),write(')')))", "swipl: 12   gprolog: type_error(atom,1)"),
         ("compound_arg", "catch((atom_concat(f(x),b,_),write('@NO')),E,(write('@BALL('),write(E),write(')')))", "swipl: type_error(atomic,f(x))   gprolog: type_error(atom,f(x))")]
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl")
def write_prog(body):
    with open(prog, "w") as f: f.write(":- %s, nl.\n" % body)
def build_m4():
    s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
    c = subprocess.run([scrip, "--compile", "-o", s, prog], capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL, cwd=tmp)
    if c.returncode != 0: return None, "NOBUILD rc=%d %s" % (c.returncode, (c.stderr or "").strip()[:70])
    g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                        "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm", "-lpthread"], capture_output=True, text=True, timeout=120, cwd=tmp)
    return (b, None) if g.returncode == 0 else (None, "NOLINK")
def run_both(body):
    write_prog(body); res = {}
    b, why = build_m4()
    for mode in ("m3", "m4"):
        if mode == "m4" and b is None: res[mode] = why; continue
        cmd = [scrip, prog] if mode == "m3" else [b]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL, cwd=tmp)
            res[mode] = (r.stdout or "").strip("\n")
        except subprocess.TimeoutExpired: res[mode] = "TIMEOUT"
    return res
rows = [l.split("\t") for l in ROWS.split("\n")]
graded = 0; failed = []
for name, body, want, note in rows:
    got = run_both(body)
    for mode in ("m3", "m4"):
        graded += 1
        if got[mode] != want: failed.append((name, mode, want, got[mode], note))
print("ATOM_CONCAT_MODES witnesses=%d modes=2 graded=%d PASS=%d FAIL=%d" % (len(rows), graded, graded - len(failed), len(failed)))
for name, mode, want, got, note in failed:
    print("  FAIL %-18s %s  want[%s]  got[%s]   (%s)" % (name, mode, want, got, note))
print("  ARM E -- PRINTED, NOT COUNTED (the oracles disagree; SCRIP follows gprolog's stricter ISO reading):")
for name, body, note in SPLIT:
    g = run_both(body)
    print("    %-14s m3[%s] m4[%s]   %s" % (name, g["m3"], g["m4"], note))
if graded == 0:
    print("⛔ REFUSED(2) [atom_concat_modes]: graded ZERO witnesses -- a runner that cannot measure never prints the success shape"); sys.exit(2)
sys.exit(1 if failed else 0)
PY
rc=$?
if [ "$rc" = 0 ]; then echo "✅ GATE GREEN [$GATE_NAME]"; elif [ "$rc" = 2 ]; then echo "⛔ REFUSED(2) [$GATE_NAME]"; else echo "⛔ GATE RED [$GATE_NAME]"; fi
exit $rc
