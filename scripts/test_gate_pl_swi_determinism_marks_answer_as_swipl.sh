#!/usr/bin/env bash
# test_gate_pl_swi_determinism_marks_answer_as_swipl.sh -- SWI-PROLOG 9'S DETERMINISM MARKS, $/0 AND $/1, ANSWER AS SWIPL IN BOTH
# MODES (cfo 2026-10-11, row prolog-swi-determinism-marks-dollar-0-and-dollar-1-parse-and-run-so-probench-det-answers-its-ref-ceo-1660;
# ProBench det, the van Roy kernel in SWI's dialect, died at "expected . at end of SSU rule" on rdet(N) => $p, $, N1 is N - 1, rdet(N1)).
#
# THE CURE.  The parser reads $ as SWI's op(1, fx, $).  The lowerer places the semantics: a $ in a clause-level conjunction is the
# clause cut, and the goals after it run with their exit through IR_CLEANUP CLEANUP_DET (r13 against the frame's F.B0, the word the
# cut restored) -- a choice left raises determinism_error(PI, det, nondet, guard) -- and their failure through the catch-handle leaf:
# a ball in flight is rethrown untouched, none raises determinism_error(PI, det, fail, guard).  $G banks B (CLEANUP_BANK), runs
# call(G) inline, compares at the exit (CLEANUP_DET against the bank) and fails the same way with determinism_error(G, det, _, goal);
# later failure backtracks past a det $G, never into it.  The last goal after $ keeps its last-call arm, so a $ recursion runs in
# constant stack.  The prelude defines $/0 and $/1 for a meta-call.  NAMED GAP: a guarded last call that takes the last-call arm is
# not checked inside the callee (SWI's guard_in_caller, the deepest last-call frame), and a $ nested in a disjunction guards the rest
# of its own branch only; the witness holds neither shape.
#
# THE ARM: the guard's nondet and fail exits, a cut after the guard, a ball through both marks, backtracking past a det $G, the goal
# mark's nondet and fail exits (inline and meta-called), a 500000-deep $ recursion at the shipped 4 MB stack, and the written forms
# -- cut against swipl -q in this run, variable names normalized, diffed in mode 3 and mode 4.  rc=0 both modes agree with swipl,
# rc=1 a divergence, rc=2 REFUSAL (no swipl, no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSED(2) [test_gate_pl_swi_determinism_marks_answer_as_swipl]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate test_gate_pl_swi_determinism_marks_answer_as_swipl || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
p.
q(1).
q(2).
r :- fail.
boom :- throw(mine).
a1(X) :- q(X), $, true.
a2(X) :- q(X), $, fail.
a3 :- $, q(_), true.
a4 :- $, q(_), !.
a5 :- $, \+ fail.
a6 :- $, call(q(_)).
a7 :- $, findall(X, q(X), _).
a8 :- $, throw(mine).
a9(X) :- q(X), $p, X >= 2.
a10(X) :- $q(X), true.
a11 :- $boom.
a12(X) :- $r, X = 1.
rdet(0) => true.
rdet(N) => $p, $, N1 is N - 1, rdet(N1).
t(G) :- catch((G -> writeq(yes(G)) ; writeq(no(G))), error(E, _), writeq(caught(E))), nl.
t2(G) :- catch((G -> writeq(yes(G)) ; writeq(no(G))), B, writeq(ball(B))), nl.
main :- t(a1(_)), t(a2(_)), t(a3), t(a4), t(a5), t(a6), t(a7), t2(a8), t(a9(_)), t(a10(_)), t2(a11), t(a12(_)),
  t($q(_)), t($r), t($p), t((X0 = 2, $q(X0))), t(rdet(500000)),
  writeq(($p, $)), nl, writeq(f($, $a, '$'(a, b), ($) - a)), nl, writeq($ (1 + 2)), nl,
  ( current_op(P, T, $) -> writeq(op(P, T)) ; writeq(no_op) ), nl.
PL
( cd "$D" && timeout -k 5 60 swipl -q -t halt w.pl < /dev/null 2> /dev/null | sed -E 's/_[0-9]+/_V/g' > want )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 60 "$B/scrip" -s4096k --run w.pl < /dev/null 2> m3.err | sed -E 's/_G?[0-9]+/_V/g' > m3 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 60 ./w -s4096k < /dev/null 2>> m4.err | sed -E 's/_G?[0-9]+/_V/g' > m4 )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -8 | sed 's/^/    /'; head -3 "$D/$m.err" | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS test_gate_pl_swi_determinism_marks_answer_as_swipl"
exit "$red"
