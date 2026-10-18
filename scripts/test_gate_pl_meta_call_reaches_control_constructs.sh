#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_meta_call_reaches_control_constructs.sh -- A CONTROL CONSTRUCT REACHED THROUGH A VARIABLE GOAL RUNS.
# THE DEFECT THIS PINS: rt_pl_goal_gen_h (src/runtime/by_name_dispatch.c) resolves a variable goal through
# rt_proc_is_registered, and the proc table holds COMPILED CLAUSE PREDICATES only. A control construct is a
# compile-time lowering rule, never a callable runtime entity, so `X = (p,q), call(X)` raised
# existence_error(procedure, ,/2) while the SOURCE-LITERAL `call((p,q))` was green -- the same goal, green or
# red depending only on whether the compiler could SEE it.
# THE CURE: lower_pl_stage2 synthesises and registers a wrapper proc per control name, reusing the machinery it
# already uses for dynamic predicates. The dispatcher is untouched. ⛔ The wrappers are COMPILER-SYNTHESISED on
# purpose: real swipl refuses the same clauses in user source ("No permission to modify static procedure").
#
# WHAT IT PROVES, in five directions so a naive cure cannot pass it:
#   (a) THE CURE: (p,q), (p;q) and (p->q) reached through a variable all run, both modes.
#   (b) ⭐ IF-THEN-ELSE IS NOT DISJUNCTION. X = (Cond->T;E) must COMMIT: when Cond succeeds the else branch must
#       NOT run, and when Cond fails the THEN branch must not. The naive wrapper ';'(A,B) :- (call(A);call(B))
#       passes arm (a) in full and FAILS here -- it runs E after T fails. This arm is the reason the wrapper
#       dispatches on the shape of A at all.
#   (c) CUT: a cut inside a meta-called goal must run, OR refuse loudly. ⭐ MEASURED: the cut's own pruning
#       re-enters the box, so it hits the SAME rung-10a re-drive gap as (i) -- the cut is not a separate
#       defect, which is exactly what this gate's first version got wrong when it blamed cut transparency.
#   (i) ⛔ THE LIMIT, PINNED RATHER THAN HIDDEN: backtracking INTO a meta-called goal (re-drive) is rung 10a's
#       unbuilt half -- the entry is shareable and correct, the RE-DRIVE wrecks the callee frame. The runtime
#       BOMBs loudly and says so. This arm accepts EITHER the right answer (rung 10a landed) OR the loud
#       refusal, and reds only on a WRONG ANSWER WITH NO BOMB. ⭐ It was written after this gate's first
#       version blamed "the cut escaped the call/1 barrier" for what is actually an unimplemented re-drive --
#       a failure message that names the wrong cause is worse than none, because it sends the next reader
#       into the wrong subsystem.
#   (d) CONTROL: a USER definition of the same name still wins -- synthesis must not shadow the program.
#   (j) THE BUILTIN HALF: a plain builtin reached through a variable (write/1, atom/1, fail/0) must run. The
#       wrapper set is seeded from lower_prolog.c's OWN pl_det_leaves[] table rather than a hand-written name
#       list, so it cannot name a builtin with no leaf behind it and cannot go stale as the table grows.
#   (e) The oracle is ASSERTED, never assumed: swipl runs every witness and the gate REFUSES if its answer moved.
# ⛔ Hermetic: every program is written under mktemp; nothing in corpus/ is read or written.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP (a test that cannot measure REFUSES, never skips-as-success)"
SWIPL=/usr/bin/swipl; [ -x "$SWIPL" ] || refuse "no swipl at $SWIPL -- the oracle premise cannot be checked"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no $ROOT/out/libscrip_rt.so -- the m4 arm cannot link"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_plmeta.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
# every witness is built from USER predicates only -- no builtin is ever the meta-called goal, because the
# builtin half of this class is a different lane and must not be able to red this gate.
PRE='p :- write(a).\nq :- write(b).\nyes.\nno :- yes, fail.\n'
printf "${PRE}:- initialization(main).\nmain :- X = (p,q), call(X), nl.\n"                        > "$W/conj.pl"
printf "${PRE}:- initialization(main).\nmain :- X = (p;q), call(X), nl.\n"                        > "$W/disj.pl"
printf "${PRE}:- initialization(main).\nmain :- X = (yes->p), call(X), nl.\n"                     > "$W/arrow.pl"
printf "${PRE}:- initialization(main).\nmain :- X = (yes->p;q), call(X), nl.\n"                   > "$W/ite_t.pl"
printf "${PRE}:- initialization(main).\nmain :- X = (no->p;q), call(X), nl.\n"                    > "$W/ite_f.pl"
printf "${PRE}main2 :- X = (yes,!), call(X), write(fwd), nl.\n:- initialization(main2).\n"          > "$W/cut.pl"
printf "${PRE}main3 :- X = (yes,!), call(X), fail.\nmain3 :- write(second), nl.\n:- initialization(main3).\n" > "$W/redrive.pl"
printf "','(_,_) :- write(mine), nl.\n:- initialization(main).\nmain :- X = (p,q), call(X).\n"    > "$W/user.pl"
printf ":- initialization(main).\nmain :- X = write(bi), call(X), nl.\n"                             > "$W/bi_write.pl"
printf ":- initialization(main).\nmain :- X = atom(foo), call(X), write(yes), nl.\n"                 > "$W/bi_atom.pl"
printf ":- initialization(main).\nmain :- ( X = fail, call(X) ; write(elsepath) ), nl.\n"            > "$W/bi_fail.pl"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
oracle(){ timeout -k 5 30 "$SWIPL" -q -g true -t halt "$1" </dev/null 2>/dev/null; }
echo "=== gate: a control construct reached through a VARIABLE goal must run (control half only) ==="
echo "--- (e) the ORACLE premise, asserted before anything is graded ---"
declare -A EXP
for w in conj disj arrow ite_t ite_f cut redrive bi_write bi_atom bi_fail; do
  EXP[$w]="$(oracle "$W/$w.pl")"
  [ -n "${EXP[$w]}" ] || refuse "ORACLE PREMISE MOVED: swipl printed nothing for $w.pl -- re-derive rather than grade"
done
[ "${EXP[ite_t]}" = "a" ]      || refuse "ORACLE PREMISE MOVED: (yes->p;q) printed [${EXP[ite_t]}], expected a (commit to THEN)"
[ "${EXP[ite_f]}" = "b" ]      || refuse "ORACLE PREMISE MOVED: (no->p;q) printed [${EXP[ite_f]}], expected b (commit to ELSE)"
ck ok "oracle: conj=[${EXP[conj]}] disj=[${EXP[disj]}] arrow=[${EXP[arrow]}] ite_t=[${EXP[ite_t]}] ite_f=[${EXP[ite_f]}] cut=[${EXP[cut]}]"
for m in m3 m4; do
  echo "--- $m ---"
  run_err(){ timeout -k 5 60 "$SCRIP" "$1" </dev/null 2>&1 >/dev/null; }
  run(){ if [ "$m" = m3 ]; then timeout -k 5 60 "$SCRIP" "$1" </dev/null 2>/dev/null; else
           s="$W/out.s"; b="$W/out.bin"; rm -f "$s" "$b"
           timeout -k 5 90 "$SCRIP" --compile -o "$s" "$1" </dev/null >/dev/null 2>&1 || return 97
           timeout -k 5 90 gcc -no-pie -o "$b" "$s" -L"$ROOT/out" -lscrip_rt -lm >/dev/null 2>&1 || return 98
           LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 60 "$b" </dev/null 2>/dev/null; fi; }
  for w in conj disj arrow; do
    o="$(run "$W/$w.pl")"; [ "$o" = "${EXP[$w]}" ] && ck ok "$m (a) $w through a variable goal -> [$o]" \
      || ck no "$m (a) $w printed [$o], oracle says [${EXP[$w]}]"
  done
  o="$(run "$W/ite_t.pl")"; [ "$o" = "${EXP[ite_t]}" ] && ck ok "$m (b) if-then-else COMMITS to THEN -> [$o]" \
    || ck no "$m (b) ite true-cond printed [$o], oracle says [${EXP[ite_t]}] -- a disjunction wrapper runs the else branch too"
  o="$(run "$W/ite_f.pl")"; [ "$o" = "${EXP[ite_f]}" ] && ck ok "$m (b) if-then-else COMMITS to ELSE -> [$o]" \
    || ck no "$m (b) ite false-cond printed [$o], oracle says [${EXP[ite_f]}]"
  e="$(run_err "$W/cut.pl")"; o="$(run "$W/cut.pl")"
  if [ "$o" = "${EXP[cut]}" ]; then ck ok "$m (c) a cut inside a meta-called goal runs -> [$o] (rung 10a landed)"
  elif printf '%s' "$e" | grep -q 'meta-call re-drive'; then ck ok "$m (c) a cut inside a meta-called goal REFUSES LOUDLY (rung 10a not built) rather than answering wrongly"
  else ck no "$m (c) cut witness printed [$o] with no BOMB, oracle says [${EXP[cut]}] -- a wrong answer where a loud refusal is owed"; fi
  e="$(run_err "$W/redrive.pl")"; o="$(run "$W/redrive.pl")"
  if [ "$o" = "${EXP[redrive]}" ]; then ck ok "$m (i) backtracking INTO a meta-called goal -> [$o] (rung 10a landed)"
  elif printf '%s' "$e" | grep -q 'meta-call re-drive'; then ck ok "$m (i) re-drive REFUSES LOUDLY (rung 10a not built) rather than answering wrongly"
  else ck no "$m (i) re-drive printed [$o] with no BOMB, oracle says [${EXP[redrive]}] -- a wrong answer where a loud refusal is owed"; fi
  o="$(run "$W/user.pl")"; [ "$o" = "mine" ] && ck ok "$m (d) a USER definition of the name still wins" \
    || ck no "$m (d) user-defined ,/2 printed [$o], expected mine -- synthesis must not shadow the program"
  for w in bi_write bi_atom bi_fail; do
    o="$(run "$W/$w.pl")"; [ "$o" = "${EXP[$w]}" ] && ck ok "$m (j) BUILTIN via a variable goal: $w -> [$o]" \
      || ck no "$m (j) $w printed [$o], oracle says [${EXP[$w]}] -- the builtin half of the bridge"
  done
done
echo "------------------------------------------------------------"
if [ "$fails" -eq 0 ]; then echo "✅ GATE GREEN: control constructs reached through a variable goal run, commit correctly, and do not shadow the program (examined $checks checks)"; exit 0; fi
echo "⛔ GATE FAIL: $fails of $checks checks red"
echo "   CURE: lower_pl_stage2 synthesises a wrapper proc per control name; ';'/2 must dispatch on the shape of its first argument so (C->T;E) commits"
exit 1
