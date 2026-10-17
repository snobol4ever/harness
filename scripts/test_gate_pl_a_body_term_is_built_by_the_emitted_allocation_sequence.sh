#!/usr/bin/env bash
# test_gate_pl_a_body_term_is_built_by_the_emitted_allocation_sequence.sh -- A PROLOG BODY TERM IS BUILT BY THE BOX, NOT BY rt_pl_dop_mkc.
# hq_prolog 2026-10-03, row prolog-bb-a-body-term-is-built-by-the-emitted-allocation-sequence-not-rt-pl-dop-mkc-924-call-sites
# (CEO-1477; ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 3). ARM 1: zebra.pl and crypt.pl compiled to mode-4 text name no rt_pl_dop_mkc -- the
# $mkc box allocates its argument block with one rt_gcheap_alloc, stores the result cell before the poll, and writes the functor and the kids
# itself (an unbound kid: a fresh self-reference in the block, the variable's cell bound to it under the trail test). ARMS 2-7: six witnesses
# against swipl in m3 AND m4: bound kids and a nested list tail, unbound kids bound later and read back, the trail (a structure binding undone
# by failure, in a clause and in a disjunction), a 20000-cell list built tail-recursively (the allocator's slow path and the collector under
# the box), a 16-argument compound with a late-bound kid read back through =.., and sharing (findall, one variable in two terms, nested terms,
# copy_term). The expected text is the oracle's, cut with /usr/bin/swipl -q -t halt at gate-writing time.
# ARM 8, w_order (row prolog-bb-a-term-built-over-an-unbound-heap-variable-links-to-it-never-rebinds-it-so-the-standard-order-of-variables-holds, re-minted per
# CEO-1511): an unbound kid already on the heap is LINKED from the new block, never rebound, so two variables keep their standard order however many
# terms are built over them (r(f(M,N),R1), r(f(N,M),R2) gives R1 \== R2; msort of the same two variables in either order is one list). RED on origin
# a6b90f22e in both modes: two of its checks read no.
# RED BEFORE on origin 35ed4e649: arm 1 names rt_pl_dop_mkc (zebra 38 sites, crypt 37); the witnesses pass there (they are the behaviour the
# box must keep), so the gate's FAIL-ONCE is arm 1.
set -u
GATE_NAME=test_gate_pl_a_body_term_is_built_by_the_emitted_allocation_sequence
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
B="${S4E_CORPUS:-$ROOT/corpus}/benchmarks/prolog/bench"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$B/zebra.pl" ] && [ -f "$B/crypt.pl" ] || refuse "no corpus kernels at $B/zebra.pl, $B/crypt.pl"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
named=""
for k in zebra crypt; do
    timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/$k.s" "$B/$k.pl" </dev/null 2>"$TMPD/err" || refuse "$k.pl did not compile: $(head -c 200 "$TMPD/err")"
    c=$(grep -cE "call\s+(qword ptr \[rip \+ rt_pl_dop_mkc@GOTPCREL\]|rt_pl_dop_mkc(@PLT)?)\s*$" "$TMPD/$k.s"); [ "$c" = 0 ] || named="$named $k:$c"
done
if [ -z "$named" ]; then echo "  ok  arm 1: zebra.pl and crypt.pl's mode-4 text call rt_pl_dop_mkc nowhere"
else echo "  RED arm 1: mode-4 text still calls rt_pl_dop_mkc:$named"; red=$((red+1)); fi
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_bound <<'EOP'
p(X,Y,Z) :- Z = f(X,g(Y,1),[a,b|X]).
main :- p(1,b,T), write(T), nl.
:- initialization(main).
EOP
mkw w_unbound <<'EOP'
q(T) :- T = f(X,Y,X), X = 1, Y = 2.
mk(T) :- T = g(_, k).
main :- q(T), write(T), nl, T = f(A,B,C), write(A-B-C), nl, mk(U), arg(1, U, V), V = 7, write(U), nl, mk(W), W = g(8, K), write(W-K), nl.
:- initialization(main).
EOP
mkw w_trail <<'EOP'
r(X) :- ( _ = f(X), X = 1, fail ; true ), ( var(X) -> write(unbound) ; write(X) ), nl.
main :- r(_), s.
s :- X = g(Y), ( Y = 1, fail ; true ), ( var(Y) -> write(still_unbound) ; write(bound(X)) ), nl.
:- initialization(main).
EOP
mkw w_list <<'EOP'
mk(0, Acc, Acc) :- !.
mk(N, Acc, L) :- N1 is N - 1, mk(N1, [N|Acc], L).
main :- mk(20000, [], L), length(L, Len), write(Len), nl, L = [F|_], write(F), nl, last(L, La), write(La), nl.
:- initialization(main).
EOP
mkw w_big <<'EOP'
main :- X = 5, T = t(1,2,3,4,5,6,7,8,9,10,11,12,13,14,X,Y), Y = z, write(T), nl, T =.. [_|Args], length(Args, N), write(N), nl.
:- initialization(main).
EOP
mkw w_share <<'EOP'
main :- findall(p(X,Y), (member(X,[1,2]), member(Y,[a,b])), L), write(L), nl, A = f(V), B = g(V), V = 7, write(A-B), nl, T = f(g(W), h(W)), W = k, write(T), nl, copy_term(T, C), write(C), nl.
:- initialization(main).
EOP
mkw w_order <<'EOP'
:- initialization(main).
r(f(A, B), R) :- ( A @< B -> R = lt ; R = ge ).
t(G) :- ( G -> write(ok) ; write(no) ), nl.
build(0, _, _) :- !.
build(K, M, N) :- _ = f(N, M), _ = g(M, N, M), K1 is K - 1, build(K1, M, N).
main :- r(f(M, N), R1), r(f(N, M), R2), t(R1 \== R2),
        build(100, M, N), r(f(M, N), R3), t(R3 == R1),
        X = f(A, B), Y = g(B, A), msort([A, B], S1), msort([B, A], S2), t(S1 == S2), t(X \== Y),
        T1 = h(A), T2 = h(A), t(T1 == T2), compare(O1, A, B), _ = k(B, A), compare(O2, A, B), t(O1 == O2),
        copy_term(f(P, _Q, P), C), C = f(P1, Q1, R1c), t(P1 == R1c), t(P1 \== Q1),
        U = w(Z), V = v(Z), Z = 1, write(U-V), nl,
        K1 = k(X1), K2 = k(Y1), X1 = Y1, t(K1 == K2),
        sort([B, A, B], SS), length(SS, LS), write(LS), nl,
        findall(W-E, member(W-E, [1-_, 2-_]), FL), length(FL, LF), write(LF), nl.
EOP
want_w_bound='f(1,g(b,1),[a,b|1])'
want_w_unbound='f(1,2,1)
1-2-1
g(7,k)
g(8,k)-k'
want_w_trail='unbound
still_unbound'
want_w_list='20000
1
20000'
want_w_big='t(1,2,3,4,5,6,7,8,9,10,11,12,13,14,5,z)
16'
want_w_share='[p(1,a),p(1,b),p(2,a),p(2,b)]
f(7)-g(7)
f(g(k),h(k))
f(g(k),h(k))'
want_w_order='ok
ok
ok
ok
ok
ok
ok
ok
w(1)-v(1)
ok
2
2'
for w in w_bound w_unbound w_trail w_list w_big w_share w_order; do
    eval "want=\$want_$w"
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED $w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
            gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED $w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
            got="$(cd "$TMPD" && timeout -k 5 60 "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
        fi
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode"
        else echo "  RED $w $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)]"; red=$((red+1)); fi
    done
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: zebra.pl and crypt.pl's mode-4 text call rt_pl_dop_mkc nowhere, and the seven witnesses (bound kids, unbound kids, the trail, a 20000-cell list, a 16-argument compound, sharing, variable order across builds) match swipl in both modes"
exit 0
