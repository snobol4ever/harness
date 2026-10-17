#!/usr/bin/env bash
# test_gate_pl_allsol_goal_is_validated.sh — findall/3, bagof/3 and setof/3 must CONVERT their Goal argument to a
# goal before they collect anything, and the conversion is what raises (row
# flip-inria-all-solutions-builtins-do-not-validate-their-goal-argument, hq_R 2026-09-06).
#
# WHAT THIS PINS. ISO/IEC 13211-1 § 8.10.1.3 / § 8.10.2.3 / § 8.10.3.3 give the all-solutions builtins the same two
# error conditions every meta-predicate carries, and § 7.6.2 says where they come from: the Goal argument is
# CONVERTED to a goal first, so an unbound goal is instantiation_error and a non-callable one is
# type_error(callable, Goal) — both raised before a single solution is collected. SCRIP did three different wrong
# things over six INRIA goals, and they share one cure surface in the lowerer:
#   (1) A NON-CALLABLE GOAL SUCCEEDED SILENTLY. findall(X,4,S), bagof(X,1,L) and setof(X,1,L) all wrote @OK, rc=0.
#       Nothing failed, nothing raised, and S/L came back bound — a plausible wrong answer, not a visible error.
#   (2) AN UNBOUND GOAL RAISED THE WRONG BALL. findall(X,Goal,S) raised type_error(callable,?/0): right that it is
#       an error, wrong about which, and the `?/0` culprit names nothing a program could inspect.
#   (3) A GOAL UNDER A CARET REFUSED TO COMPILE. bagof(X,Y^Z,L) and setof(X,X^(true;4),L) hit the rung-8 refusal
#       (rc=2, whole program does not build) — correct for a ^ goal we cannot yet GROUP, wrong for one ISO says
#       must THROW. The error needs no grouping, so the guard is now decided AHEAD of that refusal.
#
# ⛔⭐ THE ORDERING IS THE LOAD-BEARING PART. Moving the guard in front of the then-standing rung-8 refusal
# could have silently deleted that refusal for goals it legitimately covered, turning "this program does not
# compile" into "this program runs and quietly returns the wrong list". ⚠️ ARM C USED TO BE THAT CONTROL (a ^ goal
# with a callable body must still refuse rc=2) AND IS NOW CONVERTED: rung 8b landed, grouping is built, so those
# three goals RUN and the arm asserts the ORACLE's own answers instead — strictly stronger than a refusal check.
# The premise was retired by a landing, not violated by a regression; ARM C itself carries the full reasoning.
#
# ⛔ EVERY EXPECTATION IS ORACLE-CUT, from BOTH swipl 9.x and gprolog 1.4.5, measured 2026-09-06. The two agree on
# the ball's CLASS and its CULPRIT for all six; they differ only on the context argument (swipl
# context($bags:findall_loop/4,_) vs gprolog findall/3), which ISO leaves loose and this gate does not read.
# The ball is matched by UNIFICATION inside the witness program, never by comparing written text, so a
# write/1 formatting difference can never be mistaken for a semantic one.
#
# ✅⭐ THE NAMED GAP IS CLOSED AND ITS ARM IS NOW GRADED (hq_C `d4eefd1ac`, 2026-09-07). It stood here as a printed,
# uncounted row for one evening: a non-callable or unbound goal that only a RUNTIME binding puts in goal position —
# findall(X,(true,Y),S) with Y unbound — was still type_error(callable,?/0), because this cure inserts the guard on
# the goal's STATIC shape and the deeper runtime case is out of that insertion's reach. hq_C's meta-call re-drive
# resolves goals from slots at run time and therefore holds the real term at exactly the moment the lowerer cannot
# see it, so it calls rt_pl_dop_goal_guard_c on the RESOLVED goal — the same leaf, one caller further out. The row
# below is graded from here on, in both modes, like any other.
# ⛔ THE GAP WAS NOT MERELY AN ANONYMOUS CULPRIT, WHICH IS WHAT THIS FILE USED TO IMPLY. Measured by hq_C: the
# unbound case was raising a TYPE error where ISO § 7.6.2 says instantiation — a wrong CLASS wearing a right-looking
# shape, not a lazy argument on a correct error. ⭐ A placeholder culprit is a signal to re-check the error CLASS,
# not just the term: whoever wrote the placeholder was not distinguishing cases at that point either.
# ⛔ THE ARM WAS DELIBERATELY NOT PROMOTED UNTIL hq_C'S COMMIT WAS ON ORIGIN. This gate is in `make test`; promoting
# it an hour earlier would have reddened the blocking set for all nine seats in order to certify a cure that was not
# yet pushed. A gate must describe origin, never a colleague's intentions, however certain they are.
# Usage: bash ../harness/scripts/test_gate_pl_allsol_goal_is_validated.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_allsol_goal_is_validated
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
export PLA_SCRIP="$SCRIP"
python3 - <<'PY'
import os, subprocess, tempfile, sys
scrip = os.environ["PLA_SCRIP"]; out_dir = os.path.dirname(scrip)
# ARM A -- THE RAISE POPULATION. goal <TAB> the ball this must raise, written as a Prolog term that is UNIFIED with
# the caught ball. Each row names the INRIA goal it flips. Both oracles agree on every one of them.
RAISE = r"""findall(X,Goal,S)	error(instantiation_error,_)	inria findall#205
findall(X,4,S)	error(type_error(callable,4),_)	inria findall#206
bagof(X,1,L)	error(type_error(callable,1),_)	inria bagof#129
setof(X,1,L)	error(type_error(callable,1),_)	inria setof#374
bagof(X,Y^Z,L)	error(instantiation_error,_)	inria bagof#128
setof(X,X^(true;4),L)	error(type_error(callable,(true;4)),_)	inria setof#373
findall(X,3.5,S)	error(type_error(callable,3.5),_)	float in goal position
setof(X,2,L)	error(type_error(callable,2),_)	setof, non-caret
bagof(X,Y^3,L)	error(type_error(callable,3),_)	caret over a non-callable
findall(X,(true,4),S)	error(type_error(callable,(true,4)),_)	conjunction names the whole construct
findall(X,(4;true),S)	error(type_error(callable,(4;true)),_)	disjunction, culprit on the left
findall(X,(true->4),S)	error(type_error(callable,(true->4)),_)	if-then
bagof(X,Goal,L)	error(instantiation_error,_)	bagof, unbound, no caret
setof(X,Goal,L)	error(instantiation_error,_)	setof, unbound, no caret"""
# ARM B -- THE NO-RAISE CONTROL, and it is the point. Over-raising is the natural failure mode of an argument
# validator: one that rejects everything passes a raise-only gate perfectly. want is 'S' (must succeed) or 'F'
# (must fail), never an error.
OK = r"""findall(X,(X=1;X=2),S)	S	ordinary disjunction
findall(X,member(X,[a,b]),S)	S	ordinary compound goal
findall(X-Y,(X=1,Y=2),S)	S	conjunction binding both
findall(X,true,S)	S	an atom IS callable
findall(X,fail,S)	S	findall of no solutions still succeeds with []
bagof(X,(X=1;X=2),L)	S	bagof, no caret
setof(X,(X=2;X=1),L)	S	setof sorts
bagof(X,fail,L)	F	bagof FAILS on no solutions, never raises
setof(X,fail,L)	F	setof FAILS on no solutions, never raises
findall(X,(true,true),S)	S	nested control, all callable
findall(X,(true;fail),S)	S	disjunction, all callable
findall(X,(true->true),S)	S	if-then, all callable"""
# ARM D -- THE NAMED GAP. Printed, never counted: the guard reads the goal's STATIC shape, so a variable only a
# runtime binding puts in goal position inside a conjunction is still the old type_error(callable,?/0).
RUNTIME_SHAPE = [("findall(X,(true,Y),S)", "error(instantiation_error,_)", "unbound var in goal position only at RUNTIME -- hq_C d4eefd1ac, the leaf called on the RESOLVED goal"),
                 ("G = 1, call(G)", "error(type_error(callable,1),_)", "runtime-resolved non-callable names its REAL culprit, not ?/0")]
tmp = tempfile.mkdtemp(); prog = os.path.join(tmp, "t.pl")
def write_prog(goal, check):
    with open(prog, "w") as f:
        f.write(":- catch( ( %s -> write('@OK') ; write('@NO') ), E,\n"
                "   ( E = %s -> write('@MATCH') ; ( write('@BALL('), write(E), write(')') ) ) ), nl.\n" % (goal, check))
def build_m4():
    s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
    c = subprocess.run([scrip, "--compile", "-o", s, prog], capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL, cwd=tmp)
    if c.returncode != 0: return None, "NOBUILD rc=%d %s" % (c.returncode, (c.stderr or "").strip()[:70])
    g = subprocess.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(out_dir, "out"), "-lscrip_rt",
                        "-Wl,-rpath," + os.path.join(out_dir, "out"), "-lm", "-lpthread"], capture_output=True, text=True, timeout=90, cwd=tmp)
    return (b, None) if g.returncode == 0 else (None, "NOLINK")
def outcome(goal, check):
    """(m3_result, m4_result) as (marker, rc) pairs; marker is @MATCH/@OK/@NO/@BALL/NO-CLASS or a build refusal."""
    write_prog(goal, check)
    res = []
    b, why = build_m4()
    for mode in ("m3", "m4"):
        if mode == "m4" and b is None: res.append((why, -1)); continue
        try: r = subprocess.run([scrip, prog] if mode == "m3" else [b], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
        except subprocess.TimeoutExpired: res.append(("TIMEOUT", -1)); continue
        o = r.stdout
        m = "@MATCH" if "@MATCH" in o else ("@BALL" if "@BALL" in o else ("@OK" if "@OK" in o else ("@NO" if "@NO" in o else "NO-CLASS")))
        if m == "@BALL": m = "@BALL" + o[o.find("@BALL(") + 5:o.rfind(")") + 1]
        res.append((m, r.returncode))
    return res
rows = []; graded = 0; fails = 0
for line in [l for l in RAISE.split("\n") if l.strip()]:
    goal, check, why = line.split("\t")
    for mode, (m, rc) in zip(("m3", "m4"), outcome(goal, check)):
        graded += 1
        if m != "@MATCH" or rc != 0:
            fails += 1; rows.append((goal, mode, check, "%s rc=%s   [%s]" % (m, rc, why)))
for line in [l for l in OK.split("\n") if l.strip()]:
    goal, want, why = line.split("\t")
    for mode, (m, rc) in zip(("m3", "m4"), outcome(goal, "error(_,_)")):
        graded += 1
        exp = "@OK" if want == "S" else "@NO"
        if m != exp or rc != 0:
            fails += 1; rows.append((goal, mode, exp + " (must not raise)", "%s rc=%s   [%s]" % (m, rc, why)))
# ARM C -- WAS "THE REFUSAL MUST SURVIVE", NOW "THESE MUST RUN AND MATCH THE ORACLE". ⛔ THE ARM WAS CONVERTED, NOT
# DELETED, AND THE REASON MATTERS. It used to assert rc=2 "rung 8" on a ^ goal whose body IS callable, because
# grouping was NOT BUILT and a cure that ate the refusal would have turned "does not compile" into "runs and quietly
# returns the wrong list". Rung 8b landed (hq_R, row prolog-inria-bagof-setof-free-var-identity-and-grouping-broken):
# bagof/setof now compute free variables, collect a Witness-Template pair, group by VARIANT and backtrack over the
# groups, so a ^ goal is no longer ungroupable -- the caret is stripped by the free-variable computation and the
# remaining goal has nothing to group. The old expectation is therefore FALSE BY CONSTRUCTION, not violated.
# ⭐ A gate arm whose PREMISE a landing retires must be re-pointed at the new truth, never quietly dropped: these
# three now assert the ORACLE's own answer, which is strictly stronger than "it refuses". Cut from BOTH oracles
# 2026-09-07 through a consulted file; scrip matches gprolog exactly on all three. swipl agrees on the two lists and
# is not read for the third's ERROR CONTEXT argument (swipl says bagof/3, gprolog and scrip say foo/2) -- ISO leaves
# that argument loose and this gate has never read it.
for goal, want in (("bagof(X,Y^(X=1;X=2),L), write(L)", "[1,2]"),
                   ("setof(X,Y^member(X,[b,a]),L), write(L)", "[a,b]"),
                   ("catch(bagof(X,Y^foo(X,Y),L),error(existence_error(procedure,foo/2),_),write(ex))", "ex")):
    with open(prog, "w") as f: f.write(":- %s, nl.\n" % goal)
    b, why = build_m4()
    for mode in ("m3", "m4"):
        graded += 1
        if mode == "m4" and b is None:
            fails += 1; rows.append((goal, mode, "%s (rung 8b landed: these RUN now)" % want, why)); continue
        r = subprocess.run([scrip, prog] if mode == "m3" else [b], capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, cwd=tmp)
        got = (r.stdout or "").strip()
        if r.returncode != 0 or got != want:
            fails += 1; rows.append((goal, mode, "%s (rung 8b landed: these RUN now)" % want, "rc=%d %r" % (r.returncode, got[:60])))
if graded == 0:
    print("⛔ REFUSED(2) [test_gate_pl_allsol_goal_is_validated]: graded ZERO witnesses -- a runner that cannot measure never prints the success shape"); sys.exit(2)
for goal, mode, want, got in rows[:80]:
    print("    %-26s %s  want %-42s got %s" % (goal[:26], mode, want[:42], got))
for goal, check, why in RUNTIME_SHAPE:
    for mode, (m, rc) in zip(("m3", "m4"), outcome(goal, check)):
        graded += 1
        if m != "@MATCH" or rc != 0:
            fails += 1; rows.append((goal, mode, check, "%s rc=%s   [%s]" % (m, rc, why)))
nr = len([l for l in RAISE.split("\n") if l.strip()]); nk = len([l for l in OK.split("\n") if l.strip()])
print("PLALLSOL_BOARD witnesses=%d (raise=%d no-raise=%d caret-now-runs=3 runtime-shape=%d) modes=2 graded=%d PASS=%d FAIL=%d"
      % (nr + nk + 3 + len(RUNTIME_SHAPE), nr, nk, len(RUNTIME_SHAPE), graded, graded - fails, fails))
sys.exit(1 if fails else 0)
PY
_prc=${PIPESTATUS[0]}
exit $_prc
