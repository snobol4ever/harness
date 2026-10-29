#!/usr/bin/env bash
# test_gate_pl_a_head_structure_against_an_unbound_argument_is_built_by_the_box.sh -- A PROLOG HEAD'S STRUCTURE AGAINST AN UNBOUND ARGUMENT IS BUILT BY THE BOX, NOT BY A C VALUE SERVICE.
# hq_prolog 2026-10-04, row prolog-bb-a-head-structure-against-an-unbound-argument-is-built-by-the-box-not-rt-pl-unify-struct-fresh-466-call-sites
# (ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 10). ARM 1: nrev.pl, qsort.pl and zebra.pl compiled to mode-4 text call rt_pl_unify_struct_fresh
# nowhere -- IR_UNIFY_STRUCT's write mode allocates the argument block with one rt_gcheap_alloc (zero-filled, typed before the poll), stores
# the result cell in its mapped slot before the poll, and makes every argument cell a self-reference itself (unrolled to eight, a loop past
# it). ARM 2: rt_pl_unify_const_cold is absent from the generated allocating set -- the constant's cold compare is strict by class and
# allocates nothing, so no poll follows its call. ARMS 3-8: six witnesses against swipl in m3 AND m4: append's [H|R] in write mode (a
# 20000-cell list through it, the collector under the box; findall over the reverse mode), a ten-argument head (the loop arm) read back
# through arg/3 and =.., a repeated head variable f(A,A) and a head built from two arguments, nested write mode, the trail (a write-mode
# binding undone by failure), and head constants against a float, a bignum and an integer. The expected text is the oracle's, cut with
# /usr/bin/swipl -q -t halt at gate-writing time; no witness prints an unbound variable (its name is the engine's own).
# RED BEFORE on origin d86f708d0: arm 1 names rt_pl_unify_struct_fresh (nrev 9 sites, qsort 7, zebra 22 -- measured on that build) and
# arm 2 finds rt_pl_unify_const_cold in the allocating set; the witnesses pass there (they are the behaviour the box must keep).
set -u
GATE_NAME=test_gate_pl_a_head_structure_against_an_unbound_argument_is_built_by_the_box
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
B="${S4E_CORPUS:-$ROOT/corpus}/benchmarks/prolog/bench"
TAB="$HERE/../../SCRIP/src/templates/x86/gc_allocating_table.inc"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$TAB" ] || refuse "no generated allocating table at $TAB"
for k in nrev qsort zebra; do [ -f "$B/$k.pl" ] || refuse "no corpus kernel at $B/$k.pl"; done
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
named=""
for k in nrev qsort zebra; do
    timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$k.s" "$B/$k.pl" </dev/null 2>"$TMPD/err" || refuse "$k.pl did not compile: $(head -c 200 "$TMPD/err")"
    c=$(grep -cE "call\s+(qword ptr \[rip \+ rt_pl_unify_struct_fresh@GOTPCREL\]|rt_pl_unify_struct_fresh(@PLT)?)\s*$" "$TMPD/$k.s"); [ "$c" = 0 ] || named="$named $k:$c"
done
if [ -z "$named" ]; then echo "  ok  arm 1: nrev.pl, qsort.pl and zebra.pl's mode-4 text call rt_pl_unify_struct_fresh nowhere"
else echo "  RED arm 1: mode-4 text still calls rt_pl_unify_struct_fresh:$named"; red=$((red+1)); fi
if grep -q '"rt_pl_unify_const_cold"' "$TAB"; then echo "  RED arm 2: rt_pl_unify_const_cold is in the generated allocating set (its cold compare reaches the allocator)"; red=$((red+1))
else echo "  ok  arm 2: rt_pl_unify_const_cold allocates nothing (absent from the generated allocating set)"; fi
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_append <<'EOP'
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).
up(0, Acc, Acc) :- !.
up(N, Acc, L) :- N1 is N - 1, up(N1, [N|Acc], L).
main :- app([1,2,3], [4,5], L), write(L), nl, up(20000, [], Big), app(Big, [end], L2), length(L2, N), write(N), nl, last(L2, E), write(E), nl,
        findall(X-Y, app(X, Y, [a,b]), S), write(S), nl.
:- initialization(main).
EOP
mkw w_wide <<'EOP'
big(g(_, _, _, _, _, _, _, _, _, k)).
main :- big(G), G = g(1,2,3,4,5,6,7,8,9,Z), write(G-Z), nl, big(G2), arg(3, G2, V3), V3 = three, arg(10, G2, V10), arg(3, G2, R3), write(V10/R3), nl,
        ( big(G3), G3 = g(x,_,_,_,_,_,_,_,_,j) -> write(wrong) ; write(fails_ok) ), nl, big(G4), G4 =.. [F|As], length(As, N), write(F/N), nl.
:- initialization(main).
EOP
mkw w_shared <<'EOP'
two(f(A, A)).
mk(p(X, Y), X, Y).
main :- two(T), arg(1, T, V), V = 7, write(T), nl, mk(P, a, B), B = b, write(P), nl, two(U), ( U = f(1, 2) -> write(wrong) ; write(fails_ok) ), nl.
:- initialization(main).
EOP
mkw w_nested <<'EOP'
nest(h(i(_), [_|_])).
main :- nest(N), N = h(i(q), [r|S]), S = [], write(N), nl, nest(M), M = h(I, L), I = i(z), L = [w, v], write(M), nl.
:- initialization(main).
EOP
mkw w_trail <<'EOP'
p(f(_)).
q(g(a, _)).
main :- ( p(X), fail ; true ), ( var(X) -> write(unbound) ; write(bound) ), nl,
        ( q(Y), Y = g(_, 1), fail ; true ), ( var(Y) -> write(unbound) ; write(bound) ), nl,
        ( q(Z), arg(2, Z, 2) -> write(Z) ; write(no) ), nl.
:- initialization(main).
EOP
mkw w_const <<'EOP'
f(1).
g(a).
h(100000000000000000000).
t(G) :- ( G -> write(yes) ; write(no) ), nl.
main :- t(f(1.0)), X = 1.0, t(f(X)), t(f(1)), Y = 100000000000000000000, t(f(Y)), t(h(Y)), t(h(1)), t(g(a)), t(g(b)), Z = 1, t(f(Z)).
:- initialization(main).
EOP
want_w_append='[1,2,3,4,5]
20001
end
[[]-[a,b],[a]-[b],[a,b]-[]]'
want_w_wide='g(1,2,3,4,5,6,7,8,9,k)-k
k/three
fails_ok
g/10'
want_w_shared='f(7,7)
p(a,b)
fails_ok'
want_w_nested='h(i(q),[r])
h(i(z),[w,v])'
want_w_trail='unbound
unbound
g(a,2)'
want_w_const='no
no
yes
no
yes
no
yes
no
yes'
for w in w_append w_wide w_shared w_nested w_trail w_const; do
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
echo "GATE PASS [$GATE_NAME]: nrev.pl, qsort.pl and zebra.pl's mode-4 text call rt_pl_unify_struct_fresh nowhere, rt_pl_unify_const_cold allocates nothing, and the six witnesses (append's write mode, a ten-argument head, repeated head variables, nested write mode, the trail, head constants) match swipl in both modes"
exit 0
