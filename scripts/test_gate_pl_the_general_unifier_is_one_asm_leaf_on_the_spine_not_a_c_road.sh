#!/usr/bin/env bash
# test_gate_pl_the_general_unifier_is_one_asm_leaf_on_the_spine_not_a_c_road.sh -- THE GENERAL UNIFIER IS ONE ASM LEAF ON THE SPINE.
# hq_prolog 2026-10-04, row prolog-bb-the-general-unifier-is-one-asm-leaf-on-the-spine-not-rt-pl-unify-value-and-rt-pl-dop-unify-389-call-sites
# (ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 6). ARM 1: zebra.pl's and qsort.pl's mode-4 text name neither rt_pl_unify_value nor rt_pl_dop_unify --
# every unification (a head's value cells, a body =/2, the bind of is/2) calls rtx_pl_unify, which dereferences both cells, binds by age with the
# emitted trail test, walks compound kids pairwise over blocks on its own spine region, compares small integers and atoms inline and leaves the
# rest to rt_pl_unify_atomic_cold; it allocates nothing and is polled by nobody (the allocating-set table does not list it). ARMS 2-7: six
# witnesses vs swipl in m3 AND m4: terms nested 200 deep in a non-last position (the C twin rt_pl_unify_deep_c for nesting past the region, same
# rules), var-var binding in the three age cases (callee var to caller var, frame var to a heap var from an asserted clause, both heap), atomicity
# of a failed unification in the middle of a structure under a choice point, mixed atomics (an integer never unifies with its atom or its float,
# big integers by value, atoms by text whatever their cell), a 100,000-element list unified in constant stack, and body =/2 answering its left
# cell. The expected text is the oracle's, cut with /usr/bin/swipl -q -t halt at gate-writing time.
# ARM 8, w_zero -- THE CONSISTENCY ARM (the cto's ruling, 2026-10-04): for two ground terms unification succeeds exactly when they are identical,
# so = agrees with ==, \==, @<, compare/3, msort/2 and sort/2 on signed zeros, in a head constant, inside a compound and under the occurs check.
# SCRIP answers swipl's way throughout: 0.0 = -0.0 no, 0.0 == -0.0 no, 0.0 \== -0.0 yes, -0.0 @< 0.0 yes, 0.0 =:= -0.0 yes, compare > and <,
# msort [-0.0,0.0,0.0], sort [-0.0,0.0]. ORACLE-DIVERGENT, recorded so a gprolog-cut entry that meets it is read against this note: gprolog 1.4.5
# answers the opposite on all but =:= -- = yes, == yes, \== no, @< no, =:= yes, compare = and =, msort [0.0,-0.0,0.0], sort [0.0] (ARCH-PROLOG-
# C-OUT-OF-THE-BOX section 6.3's table). RED BEFORE on origin 405215caf: w_zero's first line reads yes in both modes (the unifier compared reals by
# value while the order distinguished the sign).
# RED BEFORE on origin 9380158bb: arm 1 names rt_pl_dop_unify (zebra 11, qsort 9 -- measured by SCRIP_BIN on that build), and w_long reds in both
# modes with ERROR 246 (the C road recursed once per list cell on the C stack); the other witnesses pass there (the behaviour the leaf must keep).
set -u
GATE_NAME=test_gate_pl_the_general_unifier_is_one_asm_leaf_on_the_spine_not_a_c_road
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
B="${S4E_CORPUS:-$ROOT/corpus}/benchmarks/prolog/bench"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$B/zebra.pl" ] && [ -f "$B/qsort.pl" ] || refuse "no corpus kernels at $B/zebra.pl, $B/qsort.pl"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
named=""
for k in zebra qsort; do
    timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$k.s" "$B/$k.pl" </dev/null 2>"$TMPD/err" || refuse "$k.pl did not compile: $(head -c 200 "$TMPD/err")"
    for h in rt_pl_unify_value rt_pl_dop_unify; do
        c=$(grep -cE "call\s+(qword ptr \[rip \+ ${h}@GOTPCREL\]|${h}(@PLT)?)\s*$" "$TMPD/$k.s"); [ "$c" = 0 ] || named="$named $k:$h:$c"
    done
done
if [ -z "$named" ]; then echo "  ok  arm 1: zebra.pl's and qsort.pl's mode-4 text call neither rt_pl_unify_value nor rt_pl_dop_unify"
else echo "  RED arm 1: mode-4 text still calls:$named"; red=$((red+1)); fi
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_deep <<'EOP'
build(0, a) :- !.
build(N, f(T, N)) :- N1 is N - 1, build(N1, T).
buildb(0, b) :- !.
buildb(N, f(T, N)) :- N1 is N - 1, buildb(N1, T).
buildv(0, V, V) :- !.
buildv(N, f(T, N), V) :- N1 is N - 1, buildv(N1, T, V).
main :- build(200, A), build(200, B), ( A = B -> write(eq) ; write(ne) ), nl,
        build(200, C), buildb(200, D), ( C = D -> write(eq2) ; write(ne2) ), nl,
        build(200, E), buildv(200, F, V), ( E = F -> write(V) ; write(ne3) ), nl,
        buildv(200, G, W1), buildv(200, H, W2), G = H, W1 = leaf, write(W2), nl,
        build(60, I), build(59, J), ( I = f(J, 60) -> write(eq4) ; write(ne4) ), nl,
        build(60, K), build(59, L), ( K = f(L, 61) -> write(eq5) ; write(ne5) ), nl.
:- initialization(main).
EOP
mkw w_age <<'EOP'
mk(X) :- Y = X, Y = Y.
fill(1).
r(_).
p(V) :- r(V).
q(5).
h(_).
main :- mk(X), fill(X), write(X), nl,
        A = B, A = 1, write(B), nl,
        p(C), q(C), write(C), nl,
        findall(Z, (Z = W, W = 2), L), write(L), nl,
        length(L2, 3), L2 = [P, Q, R], P = Q, Q = R, R = 7, write(L2), nl,
        assertz(k(_)), assertz(k(2)), findall(Y, (k(Y), (var(Y) -> Y = 9 ; true)), L3), write(L3), nl,
        h(M), M = 3, write(M), nl,
        findall(N-O, (member(N, [1, 2]), h(O), O = N), L4), write(L4), nl.
:- initialization(main).
EOP
mkw w_atomic <<'EOP'
main :- ( f(X, b) = f(a, c) -> write(bad) ; ( var(X) -> write(unbound) ; write(leak) ) ), nl,
        ( g(Y, Z, 1) = g(1, 2, 2) ; true ), ( var(Y), var(Z) -> write(ok) ; write(leak2) ), nl,
        ( [A, B, C] = [1, 2 | T], T = [3, 4] -> write(bad2) ; ( var(A), var(B), var(C) -> write(ok2) ; write(leak3) ) ), nl,
        catch(( h(D, E) = h(1, _), E = 2, D = 1 ), _, true), write(D-E), nl,
        \+ \+ ( F = 1, G = F, write(G), nl ), ( var(F), var(G) -> write(restored) ; write(leak4) ), nl.
:- initialization(main).
EOP
mkw w_mixed <<'EOP'
t(G, Yes, No) :- ( call(G) -> write(Yes) ; write(No) ), nl.
main :- t(1 = '1', bad, a), t(1 = 1.0, bad, b), t('a' = a, c, bad), t(-3 = -3, d, bad), t(1.5 = 1.5, e, bad), t(1.5 = 2.5, bad, f),
        atom_codes(A, "ab"), t(A = ab, g, bad), t(ab = ba, bad, h),
        X = 1267650600228229401496703205376, Y = 1267650600228229401496703205376, Z = 1267650600228229401496703205377,
        t(X = Y, i, bad), t(X = Z, bad, j), t(X = 1, bad, k), t(f(X) = f(Y), l, bad),
        t(f(a, b) = f(a), bad, m), t(f(a) = g(a), bad, n), t(f(a) = a, bad, o),
        t(foo = "foo", bad, r), t(0 = -0, s, bad).
:- initialization(main).
EOP
mkw w_long <<'EOP'
main :- findall(X, between(1, 100000, X), A), findall(Y, between(1, 100000, Y), B), ( A = B -> write(same) ; write(diff) ), nl,
        findall(X2, between(1, 100000, X2), C), length(D, 100000), C = D, nth1(99999, D, V), write(V), nl,
        findall(X3, between(1, 100000, X3), E), findall(Y3, between(2, 100001, Y3), F), ( E = F -> write(bad) ; write(differ) ), nl,
        length(G, 100000), length(H, 100000), G = H, G = [first | _], H = [Q | _], write(Q), nl.
:- initialization(main).
EOP
mkw w_body <<'EOP'
main :- X = f(Y), Y = 1, write(X), nl, Z = g(_), Z = g(2), write(Z), nl, ( A = 1, A = 2 -> write(bad) ; write(ok) ), nl,
        B = [1, 2, 3], B = [_, M | _], write(M), nl, C = D, D = E, E = done, write(C), nl, ( f(P, P) = f(1, 2) -> write(bad2) ; write(ok2) ), nl,
        f(Q, Q) = f(R, S), R = 4, write(S), nl.
:- initialization(main).
EOP
mkw w_zero <<'EOP'
:- initialization(main).
z(0.0).
nz(-0.0).
p(G) :- ( catch(G, E, (write(err(E)), nl, fail)) -> write(yes) ; write(no) ), nl.
main :- p(0.0 = -0.0), p(0.0 == -0.0), p(0.0 \== -0.0), p(-0.0 @< 0.0), p(0.0 =:= -0.0),
        compare(O, 0.0, -0.0), write(O), nl, compare(O2, -0.0, 0.0), write(O2), nl,
        msort([0.0, -0.0, 0.0], L), write(L), nl, sort([0.0, -0.0], S), write(S), nl,
        p(z(-0.0)), p(nz(0.0)), p(nz(-0.0)), X = -0.0, p(z(X)), p(f(0.0) = f(-0.0)), p(unify_with_occurs_check(0.0, -0.0)),
        p(0.5 = 0.5), Y is 1.0 * 2, p(Y = 2.0), p(Y = 2).
EOP
want_w_deep='eq
ne2
a
leaf
eq4
ne5'
want_w_age='1
1
5
[2]
[7,7,7]
[9,2]
3
[1-1,2-2]'
want_w_atomic='unbound
ok
ok2
1-2
1
restored'
want_w_mixed='a
b
c
d
e
f
g
h
i
j
k
l
m
n
o
r
s'
want_w_long='same
99999
differ
first'
want_w_body='f(1)
g(2)
ok
2
done
ok2
4'
want_w_zero='no
no
yes
yes
yes
>
<
[-0.0,0.0,0.0]
[-0.0,0.0]
no
no
yes
no
no
no
yes
yes
no'
for w in w_deep w_age w_atomic w_mixed w_long w_body w_zero; do
    eval "want=\$want_$w"
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED $w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
            gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED $w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
            got="$(cd "$TMPD" && timeout -k 5 60 "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
        fi
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode"
        else echo "  RED $w $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)]"; red=$((red+1)); fi
    done
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: zebra.pl's and qsort.pl's mode-4 text call neither rt_pl_unify_value nor rt_pl_dop_unify, and the seven witnesses (deep nesting, the three var-var ages, atomicity, mixed atomics, a 100,000-element list, body =/2, signed zeros consistent across =, ==, compare and the sorts) match swipl in both modes"
exit 0
