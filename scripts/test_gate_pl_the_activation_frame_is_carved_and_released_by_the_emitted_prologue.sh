#!/usr/bin/env bash
# test_gate_pl_the_activation_frame_is_carved_and_released_by_the_emitted_prologue.sh -- THE BLOCK PROTOCOL: A PROLOG CALL CROSSES NO C HELPER TO CARVE, FILL OR RELEASE ITS FRAME.
# hq_prolog 2026-10-03, row prolog-bb-the-activation-frame-is-carved-and-released-by-the-emitted-prologue-not-six-c-helpers-per-call-9881-call-sites
# (CEO-1477/1478/1481; ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 1). ARM 1: nrev.pl compiled to mode-4 text names none of the six helpers
# (rt_jmp_frame_lexprep2, rt_icn_zframe_args_install, rt_arg_stage, rt_proc_call_open_det, rt_proc_drop_frame_h, rt_nret_fix_tiny) -- the
# caller builds the argument block on its spine, the callee carves kt below it and reads F.A[i] at [rbp+kt+16i], the prologue zeroes inline,
# the exits release frame and block. ARMS 2-6: five witnesses against swipl-cut refs in m3 AND m4: a deterministic call chain (nrev, app on
# backtracking), a nondeterministic call resumed through beta (the retained frame and its block), a last call that takes the inline tail path
# (300000 deep: without it the 4 MB stack overflows), a last call the inline safety test refuses (an unbound frame variable handed down), a
# meta-call of a compiled predicate (the block built from the staged medium, the token discriminated).
# RED BEFORE on origin 71e513d2c: arm 1 names four of the six (lexprep2, args_install, arg_stage, open_det); the witnesses pass there (they are
# the behaviour the protocol must keep), so the gate's FAIL-ONCE is arm 1.
set -u
GATE_NAME=test_gate_pl_the_activation_frame_is_carved_and_released_by_the_emitted_prologue
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
timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/nrev.s" "$B/nrev.pl" </dev/null 2>"$TMPD/err" || refuse "nrev.pl did not compile: $(head -c 200 "$TMPD/err")"
named=""
for h in rt_jmp_frame_lexprep2 rt_icn_zframe_args_install rt_arg_stage rt_proc_call_open_det rt_proc_drop_frame_h rt_nret_fix_tiny; do
    c=$(grep -cE "call\s+(qword ptr \[rip \+ ${h}@GOTPCREL\]|${h}(@PLT)?)\s*$" "$TMPD/nrev.s"); [ "$c" = 0 ] || named="$named $h:$c"
done
if [ -z "$named" ]; then echo "  ok  arm 1: nrev.pl's mode-4 text calls none of the six frame helpers"
else echo "  RED arm 1: nrev.pl's mode-4 text still calls:$named"; red=$((red+1)); fi
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_det <<'EOP'
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).
nrev([], []).
nrev([H|T], R) :- nrev(T, RT), app(RT, [H], R).
len([], 0).
len([_|T], N) :- len(T, N0), N is N0 + 1.
main :- nrev([1,2,3,4,5,6,7,8,9,10], R), write(R), nl, len(R, N), write(N), nl,
        app(X, Y, [a,b]), write(X-Y), nl, fail.
main :- write(done), nl.
:- initialization(main).
EOP
mkw w_nondet <<'EOP'
color(red). color(green). color(blue).
pair(X, Y) :- color(X), color(Y), X \== Y.
count(N) :- findall(X-Y, pair(X, Y), L), length(L, N).
main :- forall(pair(A, B), (write(A-B), nl)), count(N), write(N), nl,
        ( color(C), C == blue -> write(found(C)) ; write(none) ), nl.
:- initialization(main).
EOP
mkw w_tail <<'EOP'
loop(0) :- !.
loop(N) :- N1 is N - 1, loop(N1).
sum(0, A, A) :- !.
sum(N, A, S) :- A1 is A + N, N1 is N - 1, sum(N1, A1, S).
main :- loop(300000), write(looped), nl, sum(200000, 0, S), write(S), nl.
:- initialization(main).
EOP
mkw w_refused <<'EOP'
bind(X, V) :- X = V.
chain(N, X) :- N > 0, !, N1 is N - 1, bind(Y, N), chain(N1, X0), X = [Y|X0].
chain(0, []).
last_unbound(X) :- hold(X).
hold(X) :- X = held.
main :- chain(5, L), write(L), nl, last_unbound(V), write(V), nl.
:- initialization(main).
EOP
mkw w_meta <<'EOP'
dbl(X, Y) :- Y is X * 2.
gen(1). gen(2). gen(3).
main :- G = dbl(21, R), call(G), write(R), nl,
        findall(Z, (call(gen, X), dbl(X, Z)), L), write(L), nl,
        ( call(gen(2)) -> write(yes) ; write(no) ), nl,
        catch(call(nosuch(1)), error(E, _), (write(E), nl)).
:- initialization(main).
EOP
want_w_det='[10,9,8,7,6,5,4,3,2,1]
10
[]-[a,b]
[a]-[b]
[a,b]-[]
done'
want_w_nondet='red-green
red-blue
green-red
green-blue
blue-red
blue-green
6
found(blue)'
want_w_tail='looped
20000100000'
want_w_refused='[5,4,3,2,1]
held'
want_w_meta='42
[2,4,6]
yes
existence_error(procedure,nosuch/1)'
for w in w_det w_nondet w_tail w_refused w_meta; do
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
mkw w_dyn <<'EOP'
g(A,A).
main :- assertz((f(N,R):-g(N,R))), f(5,Y), write(Y), nl, assertz((d(0,0):-!)), assertz((d(N,R):-M is N-1, d(M,R0), R is R0+1)), d(5,X), write(X), nl.
:- initialization(main).
EOP
want_w_dyn='5
5'
for mode in m3 m4; do
    want="$want_w_dyn"
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" w_dyn.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/w_dyn.s" "$TMPD/w_dyn.pl" </dev/null 2>"$TMPD/err" || { echo "  RED w_dyn $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
        gcc -m64 -no-pie "$TMPD/w_dyn.s" -o "$TMPD/w_dyn.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED w_dyn $mode: the assembler or linker refused"; red=$((red+1)); continue; }
        got="$(cd "$TMPD" && timeout -k 5 60 ./w_dyn.bin </dev/null 2>"$TMPD/err")"; rc=$?
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  w_dyn $mode: a runtime-asserted clause calls a static pinned predicate with a variable argument (the coo's witness, 2026-10-03: the call site asks the registry when the stage-2 table does not know the callee)"
    else echo "  RED w_dyn $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [5|5] -- a call inside a runtime fragment must take the block arm for a pinned callee"; red=$((red+1)); fi
done
printf 'my $f = -> $x { $x + 1 }; say $f(1);\n' > "$TMPD/w_blk.raku"
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" w_blk.raku </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/w_blk.s" "$TMPD/w_blk.raku" </dev/null 2>"$TMPD/err" || { echo "  RED w_blk $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
        gcc -m64 -no-pie "$TMPD/w_blk.s" -o "$TMPD/w_blk.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED w_blk $mode: the assembler or linker refused"; red=$((red+1)); continue; }
        got="$(cd "$TMPD" && timeout -k 5 60 ./w_blk.bin </dev/null 2>"$TMPD/err")"; rc=$?
    fi
    if [ "$rc" = 0 ] && [ "$got" = 2 ]; then echo "  ok  w_blk $mode: a non-pinned callee entered by name through rt_proc_enter (hq_raku's stored-block witness, 2026-10-03)"
    else echo "  RED w_blk $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [2] -- rt_proc_enter's nargs must survive the rtcc register loads"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: nrev.pl's mode-4 text calls none of the six frame helpers, and the five witnesses (det chain, nondet resume, inline tail path, refused tail, meta-call) match swipl in both modes"
exit 0
