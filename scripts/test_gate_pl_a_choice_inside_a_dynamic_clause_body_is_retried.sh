#!/usr/bin/env bash
# test_gate_pl_a_choice_inside_a_dynamic_clause_body_is_retried.sh
#
# THE ROW: prolog-a-disjunction-in-a-dynamic-predicates-clause-body-is-never-backtracked-into (minted by the cto, served by
# hq_prolog). A dynamic predicate's clause is a PACKET FRAGMENT (ARCH-PROLOG-C-OUT-OF-THE-BOX 5.2 A): its entry makes the
# frame the youngest choice (B = the frame's header) and its gamma reads B against that header -- younger means a choice
# inside the clause (the clause's own beta), equal meant none (the slot walk). But a body disjunction and a builtin
# generator (between/3, repeat: IR_TO) open their choice by re-aiming B at the SAME header, so equal could not tell them
# from nothing: their second answers were lost (k(a) :- (true ; write(k_alt)) printed a b where swipl prints a k_alt a b).
# The cure (src/templates/xa/xa_flat.cpp): a clause whose graph holds such a frame retry sends gamma's equal case to the
# clause's own beta, whose exhaustion reaches the chain-omega's walk. A call that leaves a choice (member/2) was right
# before and is graded as the control.
#
# THE ARM: 18 lines -- disjunction, between, repeat with a cut, a cut after a disjunction, if-then-else and once over
# a choice, negation, two disjunctions in one body, an asserted clause, findall, a retract of the running clause (the
# logical update view) -- the ref cut from SWI-Prolog 9.0.4, in both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
:- dynamic(a/1).
a(X) :- ( X = 1 ; X = 2 ), !.
a(z).
:- dynamic(b/1).
b(X) :- ( between(1,3,X) -> true ; X = none ).
b(z).
:- dynamic(c/1).
c(X) :- \+ ( X == q ; fail ), ( X = 1 ; X = 2 ; X = 3 ).
c(z).
:- dynamic(d/2).
d(X,Y) :- ( X = 1 ; X = 2 ), ( Y = p ; Y = q ).
d(z,z).
:- dynamic(e/1).
e(X) :- between(1,2,X), ( true ; X > 5 ).
e(z).
:- dynamic(f/1).
f(X) :- once(( X = 1 ; X = 2 )).
f(z).
:- dynamic(g/1).
g(1). g(2). g(3).
:- dynamic(h/1).
h(X) :- ( X = 1 ; X = 2 ).
:- dynamic(i/1).
i(X) :- ( X = 1 ; X = 2 ; X = 3 ), X >= 2.
i(z).
:- dynamic(j/1).
j(a) :- ( true ; write(j_alt), nl ).
j(b).
s(N, G) :- write(N), write(':'), ( call(G), write(' '), write(G), fail ; true ), nl.
:- dynamic(m/1).
m(X) :- between(1,3,X).
m(z).
:- dynamic(n/1).
n(X) :- repeat, nb_getval(c,N), N1 is N+1, nb_setval(c,N1), X = N1, (N1 >= 2 -> ! ; true).
n(z).
:- dynamic(o/1).
o(X) :- member(X,[p,q]).
o(z).
main :-
  s(a, a(_)), s(b, b(_)), s(c, c(_)), s(d, d(_,_)), s(e, e(_)), s(f, f(_)), s(g, g(_)), s(h, h(_)), s(i, i(_)),
  assertz((k(X) :- ( X = 1 ; X = 2 ))), assertz(k(z)), s(k, k(_)),
  ( h(X1), X1 == 1 -> write(first(X1)) ; write(none) ), nl,
  findall(X2, j(X2), L), write(L), nl,
  ( j(X3), X3 == a, retract((j(a) :- _)), fail ; true ), findall(X4, j(X4), L2), write(L2), nl,
  s(m, m(_)), nb_setval(c,0), s(n, n(_)), s(o, o(_)),
  halt.
PL
cat > "$D/g.ref" <<'REF'
a: a(1)
b: b(1) b(z)
c: c(1) c(2) c(3) c(z)
d: d(1,p) d(1,q) d(2,p) d(2,q) d(z,z)
e: e(1) e(2) e(z)
f: f(1) f(z)
g: g(1) g(2) g(3)
h: h(1) h(2)
i: i(2) i(3) i(z)
k: k(1) k(2) k(z)
first(1)
j_alt
[a,a,b]
j_alt
[b]
m: m(1) m(2) m(3) m(z)
n: n(1) n(2)
o: o(p) o(q) o(z)
REF
( cd "$D" && timeout -k 5 30 "$B/scrip" g.pl < /dev/null > g.m3 2>&1 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./g.bin < /dev/null > g.m4 2>&1 )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 18 of 18 lines answer as swipl"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): every choice inside a dynamic clause body is retried as swipl retries it, in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
