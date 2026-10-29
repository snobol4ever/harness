#!/usr/bin/env bash
# LADDER C rung 10b: THE DYNAMIC DATABASE -- assert, retract, clause AND abolish, in BOTH modes.
# ⛔ WIDENED 2026-09-04 (hq_C, ceo condition 3 on the rung-10b landing). The previous version of this
# file exercised assertz plus a call and NOTHING ELSE, and it read GREEN on a tree where retract/1 and
# clause/2 had never been lowered at all and abolish/1 answered WRONG at rc=0. A gate NAMED for the
# dynamic database, passing while three of its four builtins are broken, is the false-green class: the
# name described the subject, the body described one case, and nobody reading a green line could tell.
# ⭐ Expectations are CUT FROM swipl at run time, never hand-typed -- a hand-typed want is a ref with no
# oracle behind it, and this gate exists precisely because a too-small claim went unchallenged.
# Refuses rc=2 when it cannot measure -- never skip-as-success.
set -u
here=$(cd "$(dirname "$0")/../../SCRIP" && pwd)
cd "$here" || exit 2
[ -x ./scrip ] || { echo "REFUSE: no ./scrip in $here -- run make first"; exit 2; }
[ -f out/libscrip_rt.so ] || { echo "REFUSE: no out/libscrip_rt.so -- run make first"; exit 2; }
command -v gcc > /dev/null || { echo "REFUSE: no gcc -- cannot build the mode-4 arm"; exit 2; }
command -v swipl > /dev/null || { echo "REFUSE: no swipl -- the expectations are cut from the oracle, not hand-typed"; exit 2; }
d=$(mktemp -d) || { echo "REFUSE: mktemp failed"; exit 2; }
trap 'rm -rf "$d"' EXIT
w_assert_unbound=':- dynamic p/1.
:- initialization(main).
main :- assertz(p(1)), p(X), write(X), nl.'
w_assert_ground=':- dynamic q/1.
:- initialization(main).
main :- assertz(q(1)), q(1), write(yes), nl.'
w_retract_erase_first=':- dynamic f/1.
:- initialization(main).
main :- assertz(f(1)), assertz(f(2)), retract(f(1)), findall(X, f(X), L), write(L), nl.'
w_retract_resatisfiable=':- dynamic h/1.
:- initialization(main).
main :- assertz(h(1)), assertz(h(2)), assertz(h(3)), (retract(h(_)), fail ; true), findall(X, h(X), L), write(L), nl.'
w_retract_no_match=':- dynamic r/1.
:- initialization(main).
main :- assertz(r(1)), ( retract(r(2)) -> write(yes) ; write(no) ), nl.'
w_clause_reflect=':- dynamic likes/1.
:- initialization(main).
main :- assertz(likes(wine)), clause(likes(X), true), write(X), nl.'
w_abolish_existence=':- dynamic k/1.
:- initialization(main).
main :- assertz(k(1)), abolish(k/1), catch((k(_), write(found)), error(existence_error(procedure,_),_), write(gone)), nl.'
names="assert_unbound assert_ground retract_erase_first retract_resatisfiable retract_no_match clause_reflect abolish_existence"
rc=0
for w in $names; do
  eval "src=\$w_$w"
  printf '%s\n' "$src" > "$d/$w.pl"
  want=$(cd "$d" && timeout -k 5 20 swipl -q -g halt "$w.pl" < /dev/null 2>/dev/null)
  [ -n "$want" ] || { echo "REFUSE: oracle produced nothing for $w -- cannot grade"; exit 2; }
  g3=$(timeout -k 5 20 ./scrip "$d/$w.pl" < /dev/null 2>&1)
  if [ "$g3" = "$want" ]; then echo "PASS m3 $w"; else echo "FAIL m3 $w: want [$want] got [$g3]"; rc=1; fi
  if ! timeout -k 5 60 ./scrip --compile --out="$d/$w.s" "$d/$w.pl" < /dev/null > /dev/null 2>&1; then echo "FAIL m4 $w: compile refused"; rc=1; continue; fi
  if ! gcc -no-pie "$d/$w.s" -L out -lscrip_rt -Wl,-rpath,"$here/out" -o "$d/$w.exe" > /dev/null 2>&1; then echo "FAIL m4 $w: link"; rc=1; continue; fi
  g4=$(timeout -k 5 20 "$d/$w.exe" < /dev/null 2>&1)
  if [ "$g4" = "$want" ]; then echo "PASS m4 $w"; else echo "FAIL m4 $w: want [$want] got [$g4]"; rc=1; fi
done
n=$(printf '%s\n' $names | grep -c .)
echo "dynamic-DB census: $n witnesses x 2 modes = $((n * 2)) gradings (assert, retract, clause, abolish)"
[ "$rc" = 0 ] || { echo "rung 10b RED: the dynamic database is not correct in both modes"; exit 1; }
c=$(timeout -k 5 900 bash ../harness/scripts/test_prolog_ladder.sh --to 9 2>&1); crc=$?
[ "$crc" = 0 ] || { echo "FAIL: control arm rungs 0-9 red (rc=$crc)"; printf "%s\n" "$c" | tail -3; exit 1; }
printf "%s\n" "$c" | tail -1
echo "rung 10b GREEN: assert, retract, clause and abolish all correct in BOTH modes, rungs 0-9 green"
