#!/usr/bin/env bash
# test_gate_pl_a_call_whose_first_argument_selects_one_clause_enters_it_without_a_choice.sh -- FIRST-ARGUMENT INDEXING, V1: A KEY THAT SELECTS ONE CLAUSE ENTERS IT WITHOUT A CHOICE POINT.
# hq_prolog 2026-10-04, row prolog-bb-a-call-whose-first-argument-selects-one-clause-enters-it-without-a-choice-point-the-switch-box-of-the-design-of-record-7-2
# (ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 11; the design of record ARCH-PROLOG-BB-REWRITE.md section 7.2). A multi-clause predicate's entry dereferences its
# first argument and branches on its key (a functor id, an atom id, a small integer): one candidate clause is entered in last-alternative form (no next
# alternative, B back to the outer choice), none concedes through the step, two or more take the full chain. ARM 1 (both modes): the box-level port trace
# (SCRIP_PL_TRACE=1; mode 4 compiled and run with it) of app([1,2],[3],L), fail shows NO head failure inside app/3 -- clause 1 is never tried on a list and
# clause 2 is never tried on [] after a redo. ARM 2: nrev.pl's mode-4 text carries the switch for app/3 and nrev/2. ARM 2b (the cto's review): compiled
# with --trace, clause 1's first node is the trace wrapper, which reads as a VARIABLE clause, so the list key has two candidates and the switch sends it to
# the CHAIN (clause 1's entry), never to a DET stub -- while the untraced text sends the same key to app/3's last alternative. ARMS 3-7: five witnesses vs swipl in
# m3 AND m4 -- every key class with a duplicate key keeping the chain, a variable clause interleaved (the fallback), cut in a selected clause, the list
# kernels with a 5000-cell recursion, and a dynamic predicate, an exception from a selected clause, bignum / compound / character-code keys. The expected
# text is the oracle's, cut with /usr/bin/swipl -q -t halt at gate-writing time; no witness prints an unbound variable.
# RED BEFORE on origin 7be988e89: arm 1 reads 3 head failures inside app/3 in both modes (two of clause 1 on a list, one of clause 2 on [] after the redo),
# arm 2 finds no switch; the witnesses pass there (they are the behaviour the switch must keep).
# ARM 1b, V2 (ARCH section 11.4): a key with two or more candidates walks ONLY its own set -- the traced w_v2 (q/2 with a variable clause and
# duplicate keys interleaved, cut in a selected clause) shows no head failure inside q/2 in either mode (origin 2aaf9a2db's V1: 19 in m3 -- every
# multi-candidate key took the full chain); w_v2 also joins the swipl witnesses.
set -u
GATE_NAME=test_gate_pl_a_call_whose_first_argument_selects_one_clause_enters_it_without_a_choice
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
B="${S4E_CORPUS:-$ROOT/corpus}/benchmarks/prolog/bench"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$B/nrev.pl" ] || refuse "no corpus kernel at $B/nrev.pl"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_trace <<'EOP'
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).
main :- ( app([1,2], [3], L), write(L), nl, fail ; true ).
:- initialization(main).
EOP
RX='Fail: n[0-9]+_unify_(const|struct) -> app(/|.2F)3_step'
n3=$(cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 60 "$SCRIP" w_trace.pl </dev/null 2>&1 | grep -cE "$RX")
n4=REFUSED
if (cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 120 "$SCRIP" --compile -o w_trace.s w_trace.pl </dev/null >/dev/null 2>&1) && gcc -m64 -no-pie "$TMPD/w_trace.s" -o "$TMPD/w_trace.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null; then
    n4=$(cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 60 ./w_trace.bin </dev/null 2>&1 | grep -cE "$RX"); fi
if [ "$n3" = 0 ] && [ "$n4" = 0 ]; then echo "  ok  arm 1: the traced app([1,2],[3],L), fail shows no head failure inside app/3 in either mode"
else echo "  RED arm 1: head failures inside app/3 in the trace: m3=$n3 m4=$n4 (clause 1 tried on a list, or clause 2 on [] after a redo)"; red=$((red+1)); fi
mkw w_v2 <<'EOP'
q(a, 1).
q(b, 2).
q(c, 3).
q(X, 4) :- X == b.
q(b, 5).
q(f(_), 6).
q(b, 7) :- !.
q(b, 8).
p([], 0).
p([X|_], X) :- X > 5, !.
p([_|T], Y) :- p(T, Y).
main :- findall(V, q(b, V), L), write(L), nl, findall(V, q(c, V), C), write(C), nl, findall(V, q(zz, V), Z), write(Z), nl,
        findall(V, q(f(1), V), F), write(F), nl, findall(K-V, q(K, V), A), length(A, N), write(N), nl, p([1,2,9,3], P), write(P), nl,
        ( q(b, 2) -> write(yes) ; write(no) ), nl, findall(V, (q(b, V), V > 3), G), write(G), nl.
:- initialization(main).
EOP
RX2='Fail: n[0-9]+_unify_(const|struct) -> q(/|.2F)2_step'
m3=$(cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 60 "$SCRIP" w_v2.pl </dev/null 2>&1 | grep -cE "$RX2")
m4=REFUSED
if (cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 120 "$SCRIP" --compile -o w_v2t.s w_v2.pl </dev/null >/dev/null 2>&1) && gcc -m64 -no-pie "$TMPD/w_v2t.s" -o "$TMPD/w_v2t.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null; then
    m4=$(cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 60 ./w_v2t.bin </dev/null 2>&1 | grep -cE "$RX2"); fi
if [ "$m3" = 0 ] && [ "$m4" = 0 ]; then echo "  ok  arm 1b: V2 -- the traced q/2 calls show no head failure of a clause outside the key's set in either mode"
else echo "  RED arm 1b: head failures inside q/2 in the trace: m3=$m3 m4=$m4 (a multi-candidate key walked clauses outside its set)"; red=$((red+1)); fi
timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/nrev.s" "$B/nrev.pl" </dev/null 2>"$TMPD/err" || refuse "nrev.pl did not compile: $(head -c 200 "$TMPD/err")"
sa=$(grep -cE '^app\$2F3_switch:' "$TMPD/nrev.s"); sn=$(grep -cE '^nrev\$2F2_switch:' "$TMPD/nrev.s")
if [ "$sa" -ge 1 ] && [ "$sn" -ge 1 ]; then echo "  ok  arm 2: nrev.pl's mode-4 text carries the switch for app/3 and nrev/2"
else echo "  RED arm 2: nrev.pl's mode-4 text: app/3 switch=$sa nrev/2 switch=$sn"; red=$((red+1)); fi
(cd "$TMPD" && timeout -k 5 120 "$SCRIP" --trace --compile -o w_tr.s w_trace.pl </dev/null >/dev/null 2>&1) || refuse "w_trace.pl did not compile under --trace"
(cd "$TMPD" && timeout -k 5 120 "$SCRIP" --compile -o w_nt.s w_trace.pl </dev/null >/dev/null 2>&1) || refuse "w_trace.pl did not compile"
swblk() { awk '/^app\$2F3_switch:/{f=1; next} f && /^app\$2F3_(ixdet|ixfail|res|β)/{exit} f' "$1"; }
tdet=$(swblk "$TMPD/w_tr.s" | grep -cE 'je +app\$2F3_(alt|ixdet)'); tchain=$(swblk "$TMPD/w_tr.s" | grep -cE 'je +n[0-9]+_'); ndet=$(swblk "$TMPD/w_nt.s" | grep -cE 'je +app\$2F3_alt1')
if [ "$tdet" = 0 ] && [ "$tchain" -ge 1 ] && [ "$ndet" -ge 1 ]; then echo "  ok  arm 2b: under --trace the wrapper reads VAR and the list key takes the chain (no DET stub); untraced, it enters app/3's last alternative"
else echo "  RED arm 2b: --trace switch: DET targets=$tdet chain targets=$tchain; untraced alt1 targets=$ndet"; red=$((red+1)); fi
mkw w_keys <<'EOP'
q(a, 1).
q(b, 2).
q(f(_), 3).
q(1, 4).
q([], 5).
q([_|_], 6).
q(a, 7).
t(G) :- ( G -> write(yes) ; write(no) ), nl.
main :- findall(K-V, q(K, V), L), length(L, N), write(N), nl, findall(V, q(_, V), Vs), write(Vs), nl,
        findall(V, q(a, V), A), write(A), nl, q(b, B), write(B), nl, q(f(x), F), write(F), nl, q(1, I), write(I), nl,
        q([], E), write(E), nl, q([z], C), write(C), nl, t(q(zz, _)), t(q(9, _)), t(q(g(1), _)), t(q(f(1,2), _)), t(q(1.0, _)), t(q(2, _)),
        X = Y, Y = b, q(X, D), write(D), nl, call(q, f(1), M), write(M), nl, findall(W, (member(Z, [b, 1, [], zz, a]), q(Z, W)), Ws), write(Ws), nl.
:- initialization(main).
EOP
mkw w_var <<'EOP'
p(a, 1).
p(X, 2) :- X == zz.
p(f(_), 3).
p(1, 4).
p(a, 5).
main :- findall(V, p(a, V), A), write(A), nl, findall(V, p(zz, V), Z), write(Z), nl, findall(V, p(f(0), V), F), write(F), nl,
        findall(V, p(1, V), I), write(I), nl, findall(V, p(9, V), N), write(N), nl, findall(V, p(_, V), All), write(All), nl.
:- initialization(main).
EOP
mkw w_cut <<'EOP'
r(a, 1) :- !.
r(a, 2).
r(b, 3) :- !.
r(c, 4).
r([], 5) :- !, fail.
r([], 6).
s(X, Y) :- r(X, Y).
s(_, 9).
main :- findall(V, r(a, V), A), write(A), nl, findall(V, r(b, V), B), write(B), nl, findall(V, r([], V), E), write(E), nl,
        findall(V, s(b, V), S), write(S), nl, findall(V, s([], V), T), write(T), nl, findall(V, s(c, V), C), write(C), nl.
:- initialization(main).
EOP
mkw w_lists <<'EOP'
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).
nrev([], []).
nrev([H|T], R) :- nrev(T, RT), app(RT, [H], R).
len([], 0).
len([_|T], N) :- len(T, M), N is M + 1.
mk(0, []) :- !.
mk(N, [N|T]) :- M is N - 1, mk(M, T).
main :- mk(30, L), nrev(L, R), write(R), nl, findall(X-Y, app(X, Y, [1,2,3]), S), write(S), nl, mk(5000, Big), len(Big, N), write(N), nl,
        app(Big, [end], B2), last(B2, La), write(La), nl, ( app(foo, _, _) -> write(wrong) ; write(fails_ok) ), nl, ( len(7, _) -> write(wrong) ; write(fails_ok) ), nl.
:- initialization(main).
EOP
mkw w_misc <<'EOP'
:- dynamic(d/2).
e(a) :- throw(oops).
e(b).
k(10000000000000000000000, big).
k(1, small).
k(f(1, 2), pair).
c(0'x, code).
c(120, other).
main :- assertz(d(a, 1)), assertz(d(b, 2)), assertz(d(a, 3)), findall(V, d(a, V), D), write(D), nl,
        catch(e(a), E, (write(caught(E)), nl)), ( e(b) -> write(eb) ; write(no) ), nl, ( e(c) -> write(wrong) ; write(fails_ok) ), nl,
        k(1, K1), write(K1), nl, k(10000000000000000000000, K2), write(K2), nl, k(f(1, 2), K3), write(K3), nl, ( k(f(1), _) -> write(wrong) ; write(fails_ok) ), nl,
        findall(W, c(120, W), C), write(C), nl.
:- initialization(main).
EOP
want_w_v2='[2,4,5,7]
[3]
[]
[6]
6
9
yes
[4,5,7]'
want_w_keys='7
[1,2,3,4,5,6,7]
[1,7]
2
3
4
5
6
no
no
no
no
no
no
2
3
[2,4,5,1,7]'
want_w_var='[1,5]
[2]
[3]
[4]
[]
[1,3,4,5]'
want_w_cut='[1]
[3]
[]
[3,9]
[9]
[4,9]'
want_w_lists='[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30]
[[]-[1,2,3],[1]-[2,3],[1,2]-[3],[1,2,3]-[]]
5000
end
fails_ok
fails_ok'
want_w_misc='[1,3]
caught(oops)
eb
fails_ok
small
big
pair
fails_ok
[code,other]'
for w in w_keys w_var w_cut w_lists w_misc w_v2; do
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
echo "GATE PASS [$GATE_NAME]: no head failure inside app/3 in the traced run of either mode, nrev.pl carries the switch for app/3 and nrev/2, and the five witnesses (every key class, a variable clause, cut, the list kernels, dynamic / exception / bignum keys) match swipl in both modes"
exit 0
