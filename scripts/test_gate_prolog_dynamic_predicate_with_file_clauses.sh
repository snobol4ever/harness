#!/usr/bin/env bash
# test_gate_prolog_dynamic_predicate_with_file_clauses.sh -- a predicate the file declares `:- dynamic` AND gives
# clauses to is a DYNAMIC procedure whose file clauses are its initial clauses (ISO 7.4.2.1): retract, assertz,
# clause/2 and abolish see them, and a call after modification runs the modified set, in BOTH modes.
# Row prolog-dynamic-declared-predicate-with-file-clauses-is-treated-as-static-by-retract-both-modes (coo, 2026-09-06,
# on ceo CEO-377): before the cure every database verb on such a predicate threw
# permission_error(modify, static_procedure, Name/Arity) in both modes, because the lowering's ownership test made
# any file clause "static" regardless of the directive.  Expectations are CUT FROM THE ORACLE (swipl) at run time,
# never hand-typed; a signal exit is a CRASH, never a FAIL.  Refuses rc=2 when it cannot grade.
set -u
here=$(cd "$(dirname "$0")/../../SCRIP" && pwd)
cd "$here" || exit 2
[ -x ./scrip ] || { echo "REFUSE: no ./scrip in $here -- run make first"; exit 2; }
[ -f out/libscrip_rt.so ] || { echo "REFUSE: no out/libscrip_rt.so -- run make first"; exit 2; }
"$here/../harness/scripts/util_require_fresh.sh" --gate test_gate_prolog_dynamic_predicate_with_file_clauses ./scrip out/libscrip_rt.so || exit 2
command -v gcc > /dev/null || { echo "REFUSE: no gcc -- cannot build the mode-4 arm"; exit 2; }
command -v swipl > /dev/null || { echo "REFUSE: no swipl -- the expectations are cut from the oracle, not hand-typed"; exit 2; }
d=$(mktemp -d) || { echo "REFUSE: mktemp failed"; exit 2; }
trap 'rm -rf "$d"' EXIT
w_counter_retract_assert=':- dynamic cnt/1.
:- initialization(main).
cnt(0).
inc :- retract(cnt(N)), N1 is N+1, assertz(cnt(N1)).
main :- inc, inc, inc, cnt(V), write(V), nl, forall(cnt(W), (write(W), nl)).'
w_assert_onto_file_clauses=':- dynamic color/1.
:- initialization(main).
color(red).
color(green).
main :- assertz(color(blue)), asserta(color(black)), findall(C, color(C), L), write(L), nl.'
w_clause_sees_file_clauses=':- dynamic likes/2.
:- initialization(main).
likes(mary, wine).
likes(john, X) :- likes(mary, X).
main :- findall(H-B, clause(likes(H, wine), B), L), write(L), nl, retract((likes(john, _) :- _)), findall(P, likes(P, wine), L2), write(L2), nl.'
w_retractall_then_empty_fails=':- dynamic fact/1.
:- initialization(main).
fact(1).
fact(2).
main :- retractall(fact(_)), ( fact(_) -> write(still) ; write(empty) ), nl, assertz(fact(9)), fact(Z), write(Z), nl.'
w_static_stays_static=':- initialization(main).
stat(1).
main :- catch((assertz(stat(2)), write(asserted)), error(permission_error(modify, static_procedure, PI), _), (write(PI), nl)), nl.'
names="counter_retract_assert assert_onto_file_clauses clause_sees_file_clauses retractall_then_empty_fails static_stays_static"
rc=0; n=0
for w in $names; do
  eval "src=\$w_$w"
  printf '%s\n' "$src" > "$d/$w.pl"
  want=$(cd "$d" && timeout -k 5 20 swipl -q -g halt "$w.pl" < /dev/null 2>/dev/null)
  [ -n "$want" ] || { echo "REFUSE: oracle produced nothing for $w -- cannot grade"; exit 2; }
  g3=$(timeout -k 5 20 ./scrip "$d/$w.pl" < /dev/null 2>&1); r3=$?
  if [ "$r3" -ge 124 ]; then echo "CRASH m3 $w: rc=$r3"; rc=1
  elif [ "$g3" = "$want" ]; then echo "PASS m3 $w"; else echo "FAIL m3 $w: want [$want] got [$g3]" | cut -c1-300; rc=1; fi
  if ! timeout -k 5 60 ./scrip --compile -o "$d/$w.s" "$d/$w.pl" < /dev/null > /dev/null 2>&1; then echo "FAIL m4 $w: compile refused"; rc=1; continue; fi
  if ! gcc -no-pie "$d/$w.s" -L out -lscrip_rt -Wl,-rpath,"$here/out" -o "$d/$w.exe" > /dev/null 2>&1; then echo "FAIL m4 $w: link"; rc=1; continue; fi
  g4=$(timeout -k 5 20 "$d/$w.exe" < /dev/null 2>&1); r4=$?
  if [ "$r4" -ge 124 ]; then echo "CRASH m4 $w: rc=$r4"; rc=1
  elif [ "$g4" = "$want" ]; then echo "PASS m4 $w"; else echo "FAIL m4 $w: want [$want] got [$g4]" | cut -c1-300; rc=1; fi
  n=$((n+1))
done
echo "DYNAMIC_WITH_FILE_CLAUSES witnesses=$n modes=2 graded=$((n * 2))"
if [ "$rc" = 0 ]; then echo "GATE PASS(0) [test_gate_prolog_dynamic_predicate_with_file_clauses]: $((n * 2)) gradings, a dynamic-declared predicate keeps its file clauses under retract, assert, clause and retractall in both modes; a static one still refuses"; exit 0; fi
echo "GATE FAIL(1) [test_gate_prolog_dynamic_predicate_with_file_clauses]: see the FAIL/CRASH lines above ($((n * 2)) gradings)"; exit 1
