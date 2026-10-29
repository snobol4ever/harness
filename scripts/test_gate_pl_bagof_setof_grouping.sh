#!/usr/bin/env bash
# test_gate_pl_bagof_setof_grouping.sh — bagof/3 and setof/3 group by their FREE VARIABLES and share variable
# IDENTITY with the caller (ladder rung 8b; row prolog-inria-bagof-setof-free-var-identity-and-grouping-broken,
# hq_R 2026-09-07).
#
# WHAT THIS PINS. ISO/IEC 13211-1 § 8.10.2 / § 8.10.3. bagof/setof are NOT findall-with-a-sort: the variables of the
# Goal that appear neither in the Template nor under a `^` are the WITNESS, and the builtin backtracks once per
# distinct witness binding, yielding that group's Templates. SCRIP shipped them as literally findall + "fail if
# empty" + "sort" — no witness was computed, nothing was grouped, and `^` was a rung-8 compile refusal. Two visible
# consequences, both cured here:
#   (1) IDENTITY. bagof(X,(X=Y;X=Z),L) must bind L to the CALLER's Y and Z cells, so a later Y=hello, Z=world makes
#       L == [hello,world]. SCRIP returned two fresh unrelated variables and the later bindings never reached L.
#   (2) GROUPING. setof(1,(Y=2;Y=1),_) must backtrack over Y, binding it to 1 and to 2. SCRIP never bound it at all.
#
# ⛔⭐ GROUPING IS BY VARIANT, NOT BY `==`, AND THAT IS THE WHOLE DIFFICULTY. In bagof(X,(X=Y;X=Z),L) BOTH solutions
# carry a witness that is a pair of distinct fresh variables. Those two witnesses are NOT `==` (different variable
# identities), so an `==` grouping splits them into two groups and answers [Y] and [Z] — plausible, and wrong. They
# ARE variants, so the cure needed a real variant test; the engine had no `=@=`, and one was written for this
# (rt_pl_variant_cells, a structural walk carrying a variable BIJECTION, in unification.c).
#
# ⛔ THE CALLER'S WITNESS IS UNIFIED WITH **EVERY** MEMBER OF THE GROUP, NOT WITH THE GROUP'S FIRST WITNESS. Each
# solution is copied independently (findall's collector freshens variables per item), so each member's Template
# refers to ITS OWN copy's cells. Unifying only the representative leaves every later member's Template dangling —
# measured: it produced bagof_fail on ARM A's first row while every other row passed. Unifying all members coalesces
# the copies onto the caller's cells, which is what makes identity work.
#
# ⭐ ARM D IS THE REGRESSION CONTROL AND IT IS THE POINT OF THE WHOLE DESIGN: findall/3 must go on IGNORING free
# variables (findall(X,(X=Y;X=Z),L) is two fresh variables, never a group), and bagof with NO free variables must
# keep its old behaviour. The lowering therefore takes the witness path ONLY when the free-variable set is non-empty,
# so every program without free variables keeps its previous codegen — that is the blast-radius control, stated as a
# test rather than as an intention.
#
# ⛔ EVERY EXPECTATION IS ORACLE-CUT from BOTH swipl 9.x and gprolog 1.4.5, measured 2026-09-07 through a CONSULTED
# FILE. The two agree exactly on every row this gate counts.
# Usage: bash ../harness/scripts/test_gate_pl_bagof_setof_grouping.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_bagof_setof_grouping
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLBS_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys
scrip = os.environ["PLBS_SCRIP"]; out_dir = os.path.dirname(scrip)
ROWS = r"""identity_shares_caller_cells	( bagof(X,(X=Y;X=Z),L), Y=hello, Z=world, L==[hello,world] -> write(yes) ; write(no) )	yes	A: the row's own witness -- L must BE the caller's Y and Z
setof_backtracks_free_var	findall(Y, setof(1,(Y=2;Y=1),_), Ys), sort(Ys,S), write(S)	[1,2]	A: setof must bind the free variable per group
bagof_groups_by_free_var	findall(K-L, bagof(X, member(X-K,[a-1,b-2,c-1]), L), R), write(R)	[1-[a,c],2-[b]]	A: one group per distinct witness, witness order standard
setof_groups_by_free_var	findall(N-L, setof(X, member(X-N,[p-2,q-1,r-2]), L), R), write(R)	[1-[q],2-[p,r]]	A: setof groups AND sorts within the group
caret_quantifies_away	findall(L, bagof(X, Y^member(X-Y,[a-1,b-2]), L), R), write(R)	[[a,b]]	B: ^ removes Y from the witness -- one group
caret_setof	setof(X,Y^member(X,[b,a]),L), write(L)	[a,b]	B: ^ on setof, was a rung-8 compile refusal
caret_disjunction	bagof(X,Y^(X=1;X=2),L), write(L)	[1,2]	B: ^ over a control construct, was a rung-8 refusal
setof_sorts_and_dedups	findall(L, setof(X, member(X,[c,a,b,a]), L), R), write(R)	[[a,b,c]]	C: setof still sorts and removes duplicates
bagof_empty_fails	( bagof(X, member(X,[]), _) -> write(yes) ; write(no) )	no	C: bagof FAILS on no solutions, never returns []
bagof_pair_template	findall(L, bagof(X-Y, member(X-Y,[a-1,b-2]), L), R), write(R)	[[a-1,b-2]]	C: compound template, no free variables
bagof_no_free_vars	( bagof(X,(X=1;X=2),L), L==[1,2] -> write(yes) ; write(no) )	yes	D: FV empty -- the OLD path, must be untouched
findall_ignores_free_vars	findall(X,(X=Y;X=Z),L), ( L=[A,B], var(A), var(B), A\==B -> write(two_fresh) ; write(grouped) )	two_fresh	D: findall must NOT group -- the blast-radius control
findall_unaffected_pairs	findall(K-X, member(X-K,[a-1,b-2,c-1]), R), write(R)	[1-a,2-b,1-c]	D: findall keeps solution order and does not group
findall_plain	findall(X,(X=1;X=2),L), write(L)	[1,2]	D: the ordinary findall, unchanged"""
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl")
def build_m4():
    s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
    c = subprocess.run([scrip, "--compile", f"--out={s}", prog], capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL, cwd=tmp)
    if c.returncode != 0: return None, "NOBUILD rc=%d %s" % (c.returncode, (c.stderr or "").strip()[:70])
    g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                        "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm", "-lpthread"], capture_output=True, text=True, timeout=120, cwd=tmp)
    return (b, None) if g.returncode == 0 else (None, "NOLINK")
def run_both(body):
    with open(prog, "w") as f: f.write(":- %s, nl.\n" % body)
    res = {}; b, why = build_m4()
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
print("BAGOF_SETOF_GROUPING witnesses=%d modes=2 graded=%d PASS=%d FAIL=%d" % (len(rows), graded, graded - len(failed), len(failed)))
for name, mode, want, got, note in failed:
    print("  FAIL %-28s %s  want[%s]  got[%s]   (%s)" % (name, mode, want, got, note))
if graded == 0:
    print("⛔ REFUSED(2) [bagof_setof_grouping]: graded ZERO witnesses -- a runner that cannot measure never prints the success shape"); sys.exit(2)
sys.exit(1 if failed else 0)
PY
rc=$?
if [ "$rc" = 0 ]; then echo "✅ GATE GREEN [$GATE_NAME]"; elif [ "$rc" = 2 ]; then echo "⛔ REFUSED(2) [$GATE_NAME]"; else echo "⛔ GATE RED [$GATE_NAME]"; fi
exit $rc
