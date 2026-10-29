#!/usr/bin/env bash
# test_gate_pl_sort_4_answers_as_swipl.sh
#
# THE ROW: prolog-sort-4-is-absent-from-the-superset. sort/4 (Key, Order, List, Sorted) lives in the Prolog prelude
# (src/parsers/prolog/prolog_parse.c): Key 0 is the whole element, Key N an argument index; @< and @> drop later elements
# whose key is identical to an earlier one's, @=< and @>= keep them in input order (stable both ways); the errors are
# swipl's, in swipl's order -- Key (instantiation, not_less_than_one, sort_key; a list of indices is a key PATH, a 0 in
# it is not_less_than_one and a var, float or compound in it fails), Order (instantiation, type_error(atom, O), domain
# order), the list (instantiation for a partial list, type_error(list, L)), then each element and each step of the
# path (instantiation, compound, an atom index is a dict key and SCRIP has no dicts, existence_error(argument, I, E)).
#
# THE ARM: 80 cases -- swipl's own core/test_sort.pl sort4 unit bar its two dict-literal cases, plus probes of every
# error branch -- the ref cut from SWI-Prolog 9.0.4 (context and variable names normalized), in both modes. A string
# order ("@<") is left out: it grades the double_quotes default, not sort/4.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
t(G) :- catch((G -> write(yes(G)) ; write(no)), E, write(E)), nl.
main :-
  t(sort(0,@>,[a-1,b-2,a-3,c-0],_)),
  t(sort(1,@>,[a-1,b-2,a-3,c-0],_)),
  t(sort(1,@<,[a-1,b-2,a-3,c-0],_)),
  t(sort(1,@>=,[a-1,b-2,a-3,c-0],_)),
  t(sort(2,@=<,[a-1,b-2,a-3,c-0],_)),
  t(sort(0,@<,[],_)),
  t(sort(_,@<,[a],_)),
  t(sort(0,_,[a],_)),
  t(sort(0,foo,[a],_)),
  t(sort(a,@<,[a],_)),
  t(sort(-1,@<,[a],_)),
  t(sort(1,@<,[a],_)),
  t(sort(3,@<,[f(a)],_)),
  t(sort(0,@<,[a|_],_)),
  t(sort(0,@<,[a|b],_)),
  t(sort(0,@<,foo,_)),
  t(sort(0,@<,[b,a],[a|_])),
  t(sort(0,@<,[b,a],foo)),
  t(sort(1,@<,[f(X),f(_),f(X)],_)),
  t(sort(a,@<,[f(x)],_)),
  t(sort(1.0,@<,[f(x)],_)),
  t(sort(0,@<,[],_)),
  t(sort(a,@<,[],_)),
  t(sort(a,foo,[],_)),
  t(sort(-1,foo,[],_)),
  t(sort(0,foo,foo,_)),
  t(sort(-1,@<,foo,_)),
  t(sort(1,@<,[f(x)|_],_)),
  t(sort(1,@<,[a|_],_)),
  t(sort(0,@<,[b,a],[a,b|c])),
  t(sort(0,@<,[a],foo)),
  t(sort(1,@<,[f(_)],_)),
  t(sort(1,@<,[_],_)),
  t(sort(0,@=<,[1,1.0,1],_)),
  t(sort(0,@<,[1,1.0,1],_)),
  t(sort([1,1], @=<, [c(t(1),x),b(t(2),x),a(t(2),x),a(t(3),x)], _)),
  t(sort([1,2],@<,[a(b(1,2)),a(b(3,0))],_)),
  t(sort([],@<,[b,a],_)),
  t(sort([0],@<,[b,a],_)),
  t(sort([1,0],@<,[f(b),f(a)],_)),
  t(sort([a],@<,[f(b)],_)),
  t(sort([1,a],@<,[f(b)],_)),
  t(sort([1|_],@<,[f(b)],_)),
  t(sort([1|x],@<,[f(b)],_)),
  t(sort([_],@<,[f(b)],_)),
  t(sort([1,2],@<,[f(b)],_)),
  t(sort([1,2],@<,[f(g(b))],_)),
  t(sort([1,1],@<,[f(_)],_)),
  t(sort([-1],@<,[f(b)],_)),
  t(sort(a(1),@<,[1],_)),
  t(sort(0,1,[1],_)),
  t(sort(0,f(x),[1],_)),
  t(sort(0,@<,[],_)),
  t(sort(0,1,[],_)),
  t(sort([1],@<,[],_)),
  t(sort([1],@<,[c(1),a(1)],_)),
  t(sort(1,@<,[f(1)|_],_)),
  t(sort([1.0],@<,[f(b)],_)),
  t(sort([f(x)],@<,[f(b)],_)),
  t(sort([],@<,[f(b),f(a)],_)),
  t(sort([],@<,[_],_)),
  t(sort([_],@<,[],_)),
  t(sort([1,_],@<,[f(g(1))],_)),
  t(sort([0],foo,[],_)),
  t(sort([1.0],foo,[],_)),
  t(sort(1,@<,[f(1),f(2)|foo],_)),
  t(sort([2],@>=,[f(1,b),f(2,a),f(3,b)],_)),
  t(sort(0, @<, [1,2,2,3], _)),
  t(sort(0, @=<, [1,2,2,3], _)),
  t(sort(0, @>, [1,2,2,3], _)),
  t(sort(0, @>=, [1,2,2,3], _)),
  t(sort(1, @<, [a(1),a(2),a(2),a(3)], _)),
  t(sort(1, @<, [c(1),a(2),a(2),a(3)], _)),
  t(sort(1, @=<, [c(1),b(2),a(2),a(3)], _)),
  t(sort([1], @=<, [c(1),b(2),a(2),a(3)], _)),
  t(sort([1,1], @<, [c(t(1),x),b(t(2),x),a(t(2),x),a(t(3),x)], _)),
  t(sort(a(1), @<, [1,2,2,3], _)),
  t(sort(0, 1, [1,2,2,3], _)),
  t(sort(2, @<, [a(1)], _)),
  t(sort(a, @<, [a(1), a(2)], _)),
  halt.
PL
cat > "$D/g.ref" <<'REF'
yes(sort(0,@>,[a-1,b-2,a-3,c-0],[c-0,b-2,a-3,a-1]))
yes(sort(1,@>,[a-1,b-2,a-3,c-0],[c-0,b-2,a-1]))
yes(sort(1,@<,[a-1,b-2,a-3,c-0],[a-1,b-2,c-0]))
yes(sort(1,@>=,[a-1,b-2,a-3,c-0],[c-0,b-2,a-1,a-3]))
yes(sort(2,@=<,[a-1,b-2,a-3,c-0],[c-0,a-1,b-2,a-3]))
yes(sort(0,@<,[],[]))
error(instantiation_error,sort/4)
error(instantiation_error,sort/4)
error(domain_error(order,foo),sort/4)
error(type_error(compound,a),sort/4)
error(domain_error(not_less_than_one,-1),sort/4)
error(type_error(compound,a),sort/4)
error(existence_error(argument,3,f(a)),sort/4)
error(instantiation_error,sort/4)
error(type_error(list,[a|b]),sort/4)
error(type_error(list,foo),sort/4)
yes(sort(0,@<,[b,a],[a,b]))
no
yes(sort(1,@<,[f(_V),f(_V),f(_V)],[f(_V),f(_V)]))
error(type_error(dict,f(x)),sort/4)
error(type_error(sort_key,1.0),sort/4)
yes(sort(0,@<,[],[]))
yes(sort(a,@<,[],[]))
error(domain_error(order,foo),sort/4)
error(domain_error(not_less_than_one,-1),sort/4)
error(domain_error(order,foo),sort/4)
error(domain_error(not_less_than_one,-1),sort/4)
error(instantiation_error,sort/4)
error(instantiation_error,sort/4)
no
no
yes(sort(1,@<,[f(_V)],[f(_V)]))
error(instantiation_error,sort/4)
yes(sort(0,@=<,[1,1.0,1],[1.0,1,1]))
yes(sort(0,@<,[1,1.0,1],[1.0,1]))
yes(sort([1,1],@=<,[c(t(1),x),b(t(2),x),a(t(2),x),a(t(3),x)],[c(t(1),x),b(t(2),x),a(t(2),x),a(t(3),x)]))
yes(sort([1,2],@<,[a(b(1,2)),a(b(3,0))],[a(b(3,0)),a(b(1,2))]))
error(type_error(compound,b),sort/4)
error(domain_error(not_less_than_one,0),sort/4)
error(domain_error(not_less_than_one,0),sort/4)
error(type_error(dict,f(b)),sort/4)
error(type_error(compound,b),sort/4)
error(type_error(sort_key,[1|_V]),sort/4)
error(type_error(sort_key,[1|x]),sort/4)
no
error(type_error(compound,b),sort/4)
error(existence_error(argument,2,g(b)),sort/4)
error(instantiation_error,sort/4)
error(domain_error(not_less_than_one,-1),sort/4)
error(type_error(sort_key,a(1)),sort/4)
error(type_error(atom,1),sort/4)
error(type_error(atom,f(x)),sort/4)
yes(sort(0,@<,[],[]))
error(type_error(atom,1),sort/4)
yes(sort([1],@<,[],[]))
yes(sort([1],@<,[c(1),a(1)],[c(1)]))
error(instantiation_error,sort/4)
no
no
error(type_error(dict,f(b)),sort/4)
error(instantiation_error,sort/4)
no
no
error(domain_error(not_less_than_one,0),sort/4)
no
error(type_error(list,[f(1),f(2)|foo]),sort/4)
yes(sort([2],@>=,[f(1,b),f(2,a),f(3,b)],[f(1,b),f(3,b),f(2,a)]))
yes(sort(0,@<,[1,2,2,3],[1,2,3]))
yes(sort(0,@=<,[1,2,2,3],[1,2,2,3]))
yes(sort(0,@>,[1,2,2,3],[3,2,1]))
yes(sort(0,@>=,[1,2,2,3],[3,2,2,1]))
yes(sort(1,@<,[a(1),a(2),a(2),a(3)],[a(1),a(2),a(3)]))
yes(sort(1,@<,[c(1),a(2),a(2),a(3)],[c(1),a(2),a(3)]))
yes(sort(1,@=<,[c(1),b(2),a(2),a(3)],[c(1),b(2),a(2),a(3)]))
yes(sort([1],@=<,[c(1),b(2),a(2),a(3)],[c(1),b(2),a(2),a(3)]))
yes(sort([1,1],@<,[c(t(1),x),b(t(2),x),a(t(2),x),a(t(3),x)],[c(t(1),x),b(t(2),x),a(t(3),x)]))
error(type_error(sort_key,a(1)),sort/4)
error(type_error(atom,1),sort/4)
error(existence_error(argument,2,a(1)),sort/4)
error(type_error(dict,a(1)),sort/4)
REF
( cd "$D" && timeout -k 5 30 "$B/scrip" g.pl < /dev/null > g.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./g.bin < /dev/null > g.m4 2>/dev/null )
red=0
for m in m3 m4; do
    sed 's/_G[0-9]*/_V/g' "$D/g.$m" > "$D/g.$m.n"
    if cmp -s "$D/g.ref" "$D/g.$m.n"; then echo "  ok   $m: 80 of 80 cases answer as swipl"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m.n" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): sort/4 answers swipl's 80 cases in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
