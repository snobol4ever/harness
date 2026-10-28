#!/usr/bin/env bash
# test_gate_pl_gnu_all_solutions_dec10_io_for_and_name_answer_as_gprolog.sh
#
# THE ROW: prolog-gnu-drivers-find-wrong-answers-bagof-setof-through-call-findall-4-for-3-name-2-g-read-and-tell-user (cfo).
# The GNU package drivers call each goal as a run-time term, which reaches a run-time-compiled $mc: wrapper whose goal is a
# variable at compile time. bagof/3 and setof/3 there now compute their free variables at run time ('$bagof_var'/'$setof_var'
# in the prelude: ISO's witness and variant grouping, keysorted for setof, the goal then the list checked first); findall/4's
# list ends in a fresh variable unified with the tail argument (the copy no longer splits them); for/3 takes between/3's
# guard; name/2 raises instantiation_error and type_error(atomic, T); DEC-10 put/1, get/1, get0/1, skip/1 take the ISO byte and
# code guards, tab/1 evaluates its argument with is/2 and requires an integer; tell(user), see(user) and append(user) switch to
# the terminal instead of creating a file named user.
#
# THE DIALECT IS DECLARED (hq_prolog 2026-10-28, CEO-1995): the GNU tables declare --dialect=gnu (CEO-1810), so both arms run with it. Without it put/1
# is swipl's (3621a8ddd, a one-character atom is written) and put(a) prints "<a> true" where gprolog raises type_error(integer, a); the gate read RED on
# that one line in both modes with SCRIP right, because it was cut before the dialect was a switch.
# THE ARM: one program in the drivers' own style, 32 lines written out from gprolog 1.4.5, both modes, and no file named user
# left behind. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
o(G) :- write('<'), catch(( G -> R = true ; R = fail ), E, ( E = error(F, _) -> R = error(F) ; R = ball(E) )), write('> '), writeq(R), nl.
main :-
  t(bagof(A1, member(A1,[c,a,b,a]), _)), t(bagof(A2, member(A2-_,[1-a,2-b,3-a]), _)), t(bagof(A3, B3^member(A3-B3,[1-a,2-b,3-a]), _)),
  t(setof(A4, member(A4,[c,a,b,a]), _)), t(setof(A5, member(A5-_,[2-a,1-b,3-a,2-a]), _)), t(setof(A6, member(A6,[f(b),1,a,2.0,_]), _)),
  t(bagof(_, true, foo)), t(bagof(_, _, _)), t(findall(A7, member(A7,[1,2]), _, _)),
  t(for(x,1,2)), t(for(_,1,_)), t(for(_,a,2)), t(for(X8,1,3)),
  t(name(_,_)), t(name(f(x),_)), t(name(_,"12")),
  o(put(_)), o(put(a)), o(tab(1+1)), o(tab(foo)), o(tab(_)), o(tab(2.5)),
  o(get(a)), o(get(-2)), o(skip(foo)),
  o(tell(user)), t(telling(_)), o(see(user)), t(seeing(_)), t(tell(_)), t(see(_)),
  catch((open(user, read, S9), close(S9), write(user_file_created)), _, write(no_user_file)), nl, X8 = X8, halt.
PL
cat > "$D/g.want" <<'WANT'
bagof(A,member(A,[c,a,b,a]),B) => [bagof(C,member(C,[c,a,b,a]),[c,a,b,a])]
bagof(A,member(A-B,[1-a,2-b,3-a]),C) => [bagof(D,member(D-a,[1-a,2-b,3-a]),[1,3]),bagof(E,member(E-b,[1-a,2-b,3-a]),[2])]
bagof(A,B^member(A-B,[1-a,2-b,3-a]),C) => [bagof(D,E^member(D-E,[1-a,2-b,3-a]),[1,2,3])]
setof(A,member(A,[c,a,b,a]),B) => [setof(C,member(C,[c,a,b,a]),[a,b,c])]
setof(A,member(A-B,[2-a,1-b,3-a,2-a]),C) => [setof(D,member(D-a,[2-a,1-b,3-a,2-a]),[2,3]),setof(E,member(E-b,[2-a,1-b,3-a,2-a]),[1])]
setof(A,member(A,[f(b),1,a,2.0,B]),C) => [setof(D,member(D,[f(b),1,a,2.0,E]),[E,2.0,1,a,f(b)])]
bagof(A,true,foo) => error(type_error(list,foo))
bagof(A,B,C) => error(instantiation_error)
findall(A,member(A,[1,2]),B,C) => [findall(D,member(D,[1,2]),[1,2|E],E)]
for(x,1,2) => error(type_error(integer,x))
for(A,1,B) => error(instantiation_error)
for(A,a,2) => error(type_error(integer,a))
for(A,1,3) => [for(1,1,3),for(2,1,3),for(3,1,3)]
name(A,B) => error(instantiation_error)
name(f(x),A) => error(type_error(atomic,f(x)))
name(A,[49,50]) => [name(12,[49,50])]
<> error(instantiation_error)
<> error(type_error(integer,a))
<  > true
<> error(type_error(evaluable,foo/0))
<> error(instantiation_error)
<> error(type_error(integer,2.5))
<> error(type_error(integer,a))
<> error(representation_error(in_character_code))
<> error(type_error(integer,foo))
<> true
telling(A) => [telling(user)]
<> true
seeing(A) => [seeing(user)]
tell(A) => error(instantiation_error)
see(A) => error(instantiation_error)
no_user_file
WANT
( cd "$D" && timeout -k 5 30 "$B/scrip" --dialect=gnu g.pl < /dev/null > g.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --dialect=gnu -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && rm -f user && timeout -k 5 30 ./g.bin < /dev/null > g.m4 2>/dev/null )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.want" "$D/g.$m"; then echo "  ok   $m: 32 of 32 lines as gprolog"
    else echo "  FAIL $m: $(diff "$D/g.want" "$D/g.$m" | grep -c '^<') of 32 lines differ: $(diff "$D/g.want" "$D/g.$m" | grep '^>' | head -3 | tr '\n' ' ')"; red=$((red + 1)); fi
done
if [ -e "$D/user" ]; then echo "  FAIL a file named user was created"; red=$((red + 1)); fi
if [ $red -eq 0 ]; then echo "GATE PASS(0): the GNU all-solutions, DEC-10 I/O, for/3 and name/2 lines answer as gprolog in both modes"; exit 0; fi
echo "GATE FAIL(1): $red arm(s) diverge"; exit 1
