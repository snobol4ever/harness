#!/usr/bin/env bash
# test_gate_pl_copy_term_terminates_on_a_rational_tree.sh
#
# THE ROW: prolog-copy-term-2-does-not-terminate-on-a-rational-tree-and-the-overflow-kills-the-rest-of-the-file (minted by
# hq_prolog 2026-09-16 on X = f(X), copy_term(X, Y) dying with ERROR 246 in both modes; swi core/test_fastrw.pl reached it
# through findall over term(cyclic, X) :- X = f(X)). The copier answers rational trees on origin today; this gate holds it.
#
# THE ARM: nine lines against a ref cut from SWI-Prolog 9.0.4 -- a self cycle, a fresh copy of a ground cycle (== says equal,
# as swipl does), a mutual cycle through two functors, sharing of a variable and of the term itself, a cycle under a list and
# under a nested functor, a cyclic and a mutually cyclic term copied out of findall, the copy still cyclic to acyclic_term/1,
# and a ground cycle beside an atom -- in mode 3 and mode 4. FAIL_ONCE=1 plants one wrong line into the ref to prove the arm
# can say no. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
term(int, 1).
term(cyclic, X) :- X = f(X).
term(pair, P) :- P = p(Q), Q = q(P).
term(list, [a,b]).
chk(N, G) :- write(N), write(': '), ( catch(G, E, (write(caught(E)), fail)) -> write(yes) ; write(no) ), nl.
main :-
  chk(self, ( X = f(X), copy_term(X, Y), Y = f(Z), Z == Y )),
  chk(self_fresh, ( X2 = f(X2), copy_term(X2, Y2), Y2 \== X2 )),
  chk(mutual, ( A = f(B), B = g(A), copy_term(A, C), C = f(D), D = g(E), E == C )),
  chk(sharing, ( S = g(S, V, V), copy_term(S, T), T = g(T1, W1, W2), T1 == T, W1 == W2, var(W1), W1 \== V )),
  chk(deep, ( L = [a, h(L), b], copy_term(L, M), M = [a, h(M2), b], M2 == M )),
  chk(nested, ( N = n(k(N), 1, N), copy_term(N, O), O = n(k(O1), 1, O2), O1 == O, O2 == O )),
  chk(findall, ( findall(T3, term(_, T3), L3), length(L3, 4), L3 = [_, F, P, _], F = f(F1), F1 == F, P = p(q(P1)), P1 == P )),
  chk(acyclic_after_copy, ( X4 = f(X4), copy_term(X4, Y4), \+ acyclic_term(Y4) )),
  chk(ground_cyclic, ( G = f(G, 1), copy_term(G, H), H = f(H1, 1), H1 == H )),
  halt.
PL
cat > "$D/g.ref" <<'REF'
self: yes
self_fresh: no
mutual: yes
sharing: yes
deep: yes
nested: yes
findall: yes
acyclic_after_copy: yes
ground_cyclic: yes
REF
[ "${FAIL_ONCE:-0}" = 1 ] && printf 'planted: yes\n' >> "$D/g.ref"
( cd "$D" && timeout -k 5 30 "$B/scrip" g.pl < /dev/null > g.m3 2>&1 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl did not compile and link in mode 4"
( cd "$D" && timeout -k 5 30 ./g.bin < /dev/null > g.m4 2>&1 )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 9 of 9 lines answer as swipl"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): copy_term/2 copies rational trees as swipl does, in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
