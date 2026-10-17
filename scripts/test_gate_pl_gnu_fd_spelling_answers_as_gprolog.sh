#!/usr/bin/env bash
# test_gate_pl_gnu_fd_spelling_answers_as_gprolog.sh -- GNU PROLOG'S FD SPELLING ANSWERS AS GPROLOG, IN MODE 3 (cfo 2026-10-10,
# row prolog-clpfd-the-gnu-fd-spelling-fd-domain-fd-labeling-fd-all-different-and-the-hash-hash-operators-over-the-same-solver-
# equal-to-gprolog-ceo-1596; ARCH-PROLOG-CLPFD.md section 5 point 3; one oracle per dialect).
#
# THE LAYER.  src/parsers/prolog/prelude/gnu_fd.pl is SCRIP's own text over the vendored clpfd, embedded by the generator's LOCAL
# mode; gprolog's 22 FD operators and the prefix #\ live in the parser's BASE operator table at gprolog's priorities
# (EnginePl/oper.c:158-181), as gprolog declares them always and imports nothing; gnu_fd SHADOWS clpfd's fd_dom/2 (GNU answers
# the list of the domain's values) and fd_dom/2 alone never selects it (QUIET).
#
# THE ARMS, each cut against gplc in this run and diffed in mode 3 (the row's DONE-WHEN carries mode 4; a program naming the
# solver compiles to ~140 MB of asm there): (1) the base operator table and the functor rule -- #\ foo(1,2), #\ #=(1,2) (a
# name immediately followed by ( is a functor even when it is an infix operator, ISO 6.3.4.1, which the parser once read as
# #=('#\\', (1,2))), the priorities of #<=> #==> ## #\/ #/\ read back through =..; (2) twenty-six GNU builtins over the solver:
# fd_dom/2 as a list, fd_min/fd_max/fd_size, fd_max_integer, fd_vector_max, fd_at_least_one, fd_prime, fd_not_prime,
# fd_atleast, fd_minimize, fd_element, fd_element_var, fd_reified_in, fd_cardinality/2,3, fd_has_vector, fd_has_extra_cstr,
# fd_labeling/2's value_method(max|middle) and variable_method(ff), fd_domain/2 over a value list, fd_labeling of one variable,
# backtracks(B); (3) GNU's expressions INSIDE the operators SWI's clpfd also exports -- X ** 2 #= 49, dist/2, exact division (Z / 3
# #= 4 admits only 12), quot_rem/3, min/max, // and rem, (A #<=> B) #/\ (C #<=> E), ## and #==> under #\/, #\ over a #>=#, a
# reified ** -- answered through gnu_fd's wrappers over the '$clpfd_wrapped_<op>' copies the generator's WRAPS emits; the arm
# declares -s8192k (re-measured on the cto's CEO-1632 chunk 1, 45e63ef51: 4 MB stops it, 8 MB runs it whole; before chunk 1 it
# needed 16 MB).  FAIL-ONCE of arm 3, measured on 84ed661f8 (before WRAPS): domain_error(clpfd_expression,
# _ ** 2) on the first line, 12 of 12 lines differ.  ARM 2 declared -s16384k from 18e3120f5 (the wake-up cure's frame cost) until
# CEO-1632 chunk 1 (45e63ef51) released an if-then-else branch's last call; re-measured there, its 23-line witness runs whole at the
# 4 MB default again, so it declares nothing.  FAIL-ONCE, measured on 70f3505ed: arm 1 (no base table) 11 of 11 lines differ, arm 2 (existence_error fd_domain/3)
# 23 of 23; on the cure 0 of 34.  rc=0 agrees with gprolog · rc=1 a divergence · rc=2 REFUSAL (no gplc, no build).  ~8 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_fd_spelling_answers_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unreadable"
GPLC=$(gplc_bin) || refuse "no gplc -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/ops.pl" <<'PL'
:- initialization(main).
show(T) :- T =.. L, write(L), nl.
main :- show(#\ foo(1, 2)), show(#\ #=(1, 2)), show(#\ 1 #= 2), show(a #<=> b #==> c), show(a ## b #\/ c), show(a #\/ b #/\ c), show(a #=# b), show(a #\=# b),
    show(1 #=<# 2), show(#\ a #\<=> b), X = (p #\==> q), X = (_ #\==> _), write(ok), nl, halt.
PL
cat > "$D/fd.pl" <<'PL'
:- initialization(main).
main :-
    fd_domain(Z, 1, 5), Z #\=# 3, fd_dom(Z, D), write(dom(D)), nl,
    fd_domain(W, 1, 9), fd_min(W, Mn), fd_max(W, Mx), fd_size(W, Sz), write(minmax(Mn, Mx, Sz)), nl,
    fd_max_integer(MI), write(maxint(MI)), nl, fd_vector_max(VM), write(vecmax(VM)), nl,
    fd_domain([A,B], 0, 1), fd_at_least_one([A,B]), fd_labeling([A,B]), write(alo(A,B)), nl,
    fd_domain(P, 1, 20), fd_prime(P), fd_dom(P, PD), write(primes(PD)), nl,
    fd_domain(NP, 1, 20), fd_not_prime(NP), fd_dom(NP, NPD), write(notprime(NPD)), nl,
    fd_domain([Q,R], 1, 3), fd_atleast(1, [Q,R], 2), fd_labeling([Q,R]), write(atleast(Q,R)), nl,
    fd_domain(X, 1, 10), fd_minimize(fd_labeling([X]), X), write(min(X)), nl,
    fd_element(I, [1,3,3], 3), fd_dom(I, ID), write(elem(ID)), nl,
    fd_reified_in(V, 1, 3, Bv), V = 5, write(reif(Bv)), nl,
    fd_domain([C1,C2], 0, 5), fd_cardinality([C1 #=# 1, C2 #=# 1], 1), C1 = 1, fd_dom(C2, C2D), write(card(C2D)), nl,
    fd_domain(Y, 1, 9), ( fd_has_vector(Y) -> write(hv(yes)) ; write(hv(no)) ), nl, Y #\=# 5, ( fd_has_vector(Y) -> write(hv2(yes)) ; write(hv2(no)) ), nl,
    fd_domain(Zc, 1, 9), ( fd_has_extra_cstr(Zc) -> write(hec(yes)) ; write(hec(no)) ), nl, Zc #># 3, ( fd_has_extra_cstr(Zc) -> write(hec2(yes)) ; write(hec2(no)) ), nl,
    fd_domain([A2,B2], 1, 3), A2 #<# B2, fd_labeling([A2,B2], [value_method(max)]), write(vmax(A2,B2)), nl,
    fd_domain([C3,D3], 1, 3), C3 #<# D3, fd_labeling([C3,D3], [variable_method(ff), value_method(middle)]), write(mid(C3,D3)), nl,
    fd_domain([E1,E2], 1, 3), fd_element_var(J, [E1,E2], 3), E1 = 1, write(ev(J)), nl,
    fd_domain([F1,F2], 0, 5), fd_cardinality([F1 #=# 1, F2 #=# 1], N), N = 2, write(card(F1,F2)), nl,
    fd_domain(Gv, [2,4,8]), fd_dom(Gv, GL), write(dom2(GL)), nl,
    fd_domain(H, 1, 9), fd_labeling(H), write(single(H)), nl,
    fd_domain([K1,K2], 1, 2), fd_labeling([K1,K2], [backtracks(Bk)]), write(bk(Bk)), nl, halt.
PL
red=0
cat > "$D/ex.pl" <<'PL'
:- initialization(main).
main :-
    fd_domain(X, 1, 20), X ** 2 #= 49, fd_labeling([X]), write(pow(X)), nl,
    D #= dist(3, 8), write(dist(D)), nl,
    fd_domain(Y, 1, 20), dist(Y, 10) #= 4, fd_labeling([Y]), write(dist_lab(Y)), nl,
    fd_domain(Z, 1, 20), Z / 3 #= 4, fd_labeling([Z]), write(exact_div(Z)), nl,
    ( fd_domain(W, 1, 20), W / 3 #= 4, W #\= 12 -> write(exact_div_alt(W)) ; write(exact_div_only_12) ), nl,
    Q #= quot_rem(17, 5, R), write(qr(Q, R)), nl,
    fd_domain(M, 0, 9), min(M, 4) + max(M, 2) #= 9, fd_labeling([M]), write(minmax(M)), nl,
    fd_domain(K, 0, 30), K // 4 #= 3, K rem 4 #= 1, fd_labeling([K]), write(quot_rem2(K)), nl,
    fd_domain([A,B,C,E], 0, 1), (A #<=> B) #/\ (C #<=> E), A = 1, C = 0, fd_labeling([B,E]), write(and_equiv(B, E)), nl,
    fd_domain([P,S], 0, 1), (P ## S) #\/ (P #==> S), fd_labeling([P,S]), write(or_xor(P, S)), nl,
    fd_domain(T, 1, 9), #\ (T ** 2 #>=# 10), fd_labeling([T]), write(not_pow(T)), nl,
    fd_domain(U, 0, 50), B2 #<=> (U ** 2 #= 25), B2 = 1, fd_labeling([U]), write(reif_pow(U)), nl,
    halt.
PL
for w in ops fd ex; do
    ( cd "$D" && timeout -k 5 120 "$GPLC" -o "$w.gnu" "$w.pl" > /dev/null 2>&1 && timeout -k 5 30 "./$w.gnu" < /dev/null > "$w.want" 2>&1 ) || refuse "gprolog itself fails on $w.pl"
    [ -s "$D/$w.want" ] || refuse "gprolog printed nothing for $w.pl"
    stk=; [ "$w" = ex ] && stk=-s8192k
    ( cd "$D" && timeout -k 5 120 "$B/scrip" $stk --run "$w.pl" < /dev/null > "$w.m3" 2>&1 )
    n=$(wc -l < "$D/$w.want")
    if cmp -s "$D/$w.want" "$D/$w.m3"; then echo "  $w m3 GREEN: $n of $n lines as gprolog"
    else echo "  $w m3 RED: $(diff "$D/$w.want" "$D/$w.m3" 2>/dev/null | grep -c '^<') of $n lines differ from gprolog"; diff "$D/$w.want" "$D/$w.m3" 2>/dev/null | head -8 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
