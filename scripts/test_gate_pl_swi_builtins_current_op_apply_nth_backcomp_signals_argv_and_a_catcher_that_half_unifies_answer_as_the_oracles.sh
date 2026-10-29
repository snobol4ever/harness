#!/usr/bin/env bash
# test_gate_pl_swi_builtins_current_op_apply_nth_backcomp_signals_argv_and_a_catcher_that_half_unifies_answer_as_the_oracles.sh -- SWI BUILTINS THE ProRosetta AND SWI SUITES CALLED AND SCRIP GOT WRONG OR LACKED, IN BOTH MODES (hq_prolog 2026-10-15,
# row prolog-every-suite-to-100-under-tenet-ceo-1562; SWI core/test_op current_op 3 cases, core/test_call apply:error, ProRosetta main/0 programs).
# THE CURE, each line of the swipl witness: current_op/3 raises swipl's type_error(integer, P) for a non-integer priority and type_error(atom, T) for a non-atom
# specifier in the SWI dialect (ISO source keeps domain_error); apply/2 on a number raises type_error(callable, G); nth0/3 and nth1/3 with a bound index are
# DETERMINISTIC (the chains of ProRosetta maximum-triangle-path-sum, which needed a 1 GB stack because every nth0 kept a choice point) and raise type_error(integer, I)
# for a non-integer index; library(backcomp) is vendored (sformat/2,3 and its kin); on_signal/3 keeps the handler per signal (default first), nb_linkval/2,
# ansi_format/3 (plain format/2 off a terminal) and catch_with_backtrace/3 exist (the main/0 of library(main) calls the last two); the argv flag is the program's own
# argument list after --, run here with `-- a b` in both modes.
# THE SECOND ARM, cut from gprolog 1.4.5 (/usr/bin/gprolog) because swipl 9.0.4 itself leaves the ball uncaught (swipl-devel's own test_call.pl partial_unification
# requires the ISO answer): a catcher that unifies PART of the ball and then fails must leave the ball untouched for the outer catcher -- the catch handler unifies on
# a forced-trailing boundary and unwinds on a mismatch.  Programs write outer/outer2/ab as gprolog does.
# RED BEFORE (the parent e6febb41a): existence_error for the new names, type_error(atom, 1) for apply, nondeterministic nth0/nth1, domain_error current_op, the
# nested catch ends uncaught.
# THIRD AND FOURTH ARMS: initialization(main, main) runs LAST (after directives and plain initialization goals, the later of two replacing the earlier) and exits 1 when main/0 fails (swipl; SCRIP exited 0), 2 on an exception, the halt code on halt/1.
# rc=0 both modes agree with the oracles · rc=1 a divergence · rc=2 REFUSAL (no swipl, no gprolog, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_builtins_current_op_apply_nth_backcomp_signals_argv_and_a_catcher_that_half_unifies_answer_as_the_oracles
GP=/usr/bin/gprolog
refuse() { echo "⛔ REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$GP" ] || refuse "no gprolog at $GP -- the second oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
t(T, G) :- catch((call(G) -> \+ \+ (numbervars(T, 0, _), writeq(T)) ; writeq(no)), error(E, _), \+ \+ (numbervars(E, 0, _), writeq(caught(E)))), nl.
nd(G, D) :- setup_call_cleanup(true, G, Det = true), ( Det == true -> D = det ; D = nondet ).
main :-
    t(yes, current_op(_, _, 1)), t(yes, current_op(_, 1, _)), t(yes, current_op(_, xxx, _)), t(yes, current_op(x, _, _)), t(yes, current_op(1.2, _, _)),
    t(yes, current_op(1201, _, _)), t(yes, current_op(-1, _, _)), t(yes, current_op(_, f(x), _)), t(yes, current_op(_, _, f(x))), t(yes, current_op(_, [], _)),
    t(yes, apply(1, [a, b])), t(yes, apply(foo, [])), t(R3, (apply(atom_length, [abc, R3]))), t(yes, apply(_, [a])),
    t(yes, nth0(-1, [a], _)), t(yes, nth0(a, [a], _)), t(yes, nth0(1.0, [a, b], _)), t(E4, nth0(1, [a, b, c], E4)), t(E5, nth1(2, [a, b, c], E5)),
    t(yes, nth1(0, [a], _)), t(yes, nth1(a, [a], _)), t(yes, nth0(5, [a], _)), t(L6, findall(I-E6, nth0(I, [a, b], E6), L6)), t(L7, findall(I7, nth1(I7, [a, b, a], a), L7)),
    t(D8, nd(nth0(1, [a, b, c], _), D8)), t(D9, nd(nth1(2, [a, b, c], _), D9)), t(D10, nd(nth0(_, [a, b, c], b), D10)),
    t(S11, sformat(S11, '~w-~w', [a, b])), t(S12, sformat(S12, 'plain')),
    t(O13-N13, (on_signal(int, O13, handler), on_signal(int, N13, default))), t(O14, (on_signal(usr1, _, h1), on_signal(usr1, O14, h2))),
    t(V15, (nb_linkval(k15, v15), nb_getval(k15, V15))),
    t(yes, ansi_format([bold], 'x~w~n', [y])),
    t(R16, catch_with_backtrace(throw(oops), oops, R16 = caught)), t(R17, catch_with_backtrace(R17 = fine, _, true)),
    t(A18, (current_prolog_flag(argv, A18))),
    t(yes, current_prolog_flag(no_such_flag_x, _)).
PL
cat > "$D/c.pl" <<'PL'
t3 :- throw(f(_, 2)).
p1 :- catch(catch(t3, f(2, 1), (write(inner), nl)), f(1, 2), (write(outer), nl)).
p2 :- catch(catch(t3, f(2, 1), (write(inner), nl)), f(_, 2), (write(outer2), nl)).
p3 :- catch(catch(throw(g(_, _)), g(a, b), (write(ab), nl)), g(X, Y), (write(X-Y), nl)).
:- initialization((p1, p2, p3)).
PL
( cd "$D" && timeout -k 5 30 swipl -q -t halt w.pl -- a b < /dev/null > want 2> /dev/null )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 30 "$GP" --consult-file c.pl --query-goal halt < /dev/null 2> /dev/null | awk '/compiled, [0-9]+ lines read/{f=1;next} f && !/^\| \?-/' > cwant )
[ -s "$D/cwant" ] || refuse "gprolog printed nothing for the catch witness"
( cd "$D" && timeout -k 5 30 "$B/scrip" --run w.pl -- a b < /dev/null > m3 2> m3.err; timeout -k 5 30 "$B/scrip" --run c.pl < /dev/null > cm3 2> cm3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 30 ./w -- a b < /dev/null > m4 2>> m4.err
  timeout -k 5 60 "$B/scrip" --compile --out=c.s c.pl < /dev/null 2> cm4.err && gcc -no-pie c.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o c 2>> cm4.err && timeout -k 5 30 ./c < /dev/null > cm4 2>> cm4.err )
n=$(wc -l < "$D/want"); cn=$(wc -l < "$D/cwant"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m swipl arm GREEN: $n of $n lines as swipl"
    else echo "  $m swipl arm RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
    cf=c$m; [ $m = m3 ] && cf=cm3 || cf=cm4
    if cmp -s "$D/cwant" "$D/$cf"; then echo "  $m gprolog arm GREEN: $cn of $cn lines as gprolog"
    else echo "  $m gprolog arm RED: the catch witness differs from gprolog"; diff "$D/cwant" "$D/$cf" 2>/dev/null | head -6 | sed 's/^/    /'; red=1; fi
done
# THIRD ARM, the exit status of initialization(main, main): the program's own main/0 fails -> rc 1, raises -> rc 2, halts -> its code (swipl's rc, cut here).
for body in 'main :- fail.' 'main :- write(a), nl, fail.' 'main :- throw(oops).' 'main :- write(hi), nl.' 'main :- halt(3).'; do
    printf ':- initialization(main, main).\n%s\n' "$body" > "$D/im.pl"
    ( cd "$D" && timeout -k 5 30 swipl -q im.pl < /dev/null > iw.out 2> /dev/null; echo $? > iw.rc
      timeout -k 5 30 "$B/scrip" --run im.pl < /dev/null > i3.out 2> /dev/null; echo $? > i3.rc
      timeout -k 5 60 "$B/scrip" --compile --out=im.s im.pl < /dev/null 2> /dev/null && gcc -no-pie im.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o im 2> /dev/null && { timeout -k 5 30 ./im < /dev/null > i4.out 2> /dev/null; echo $? > i4.rc; } )
    for m in 3 4; do
        if cmp -s "$D/iw.rc" "$D/i$m.rc" && cmp -s "$D/iw.out" "$D/i$m.out"; then echo "  m$m initialization(main, main) '$body' GREEN: rc $(cat "$D/iw.rc") as swipl"
        else echo "  m$m initialization(main, main) '$body' RED: swipl rc $(cat "$D/iw.rc") scrip rc $(cat "$D/i$m.rc" 2>/dev/null)"; red=1; fi
    done
done
# FOURTH ARM, the ORDER: initialization(main, main) runs after every directive and every plain initialization goal, and a later one replaces an earlier one.
for k in 1 2 3; do
    case $k in
        1) printf ':- initialization(main, main).\nmain :- write(main), nl.\n:- initialization((write(plain), nl)).\n:- write(directive), nl.\n:- initialization((write(plain2), nl)).\n' > "$D/im.pl";;
        2) printf ':- initialization(main, main).\nmain :- write(main), nl, fail.\n:- initialization((write(plain), nl)).\n' > "$D/im.pl";;
        3) printf ':- initialization((write(plain), nl)).\n:- initialization(main, main).\nmain :- write(main), nl.\n:- initialization(main2, main).\nmain2 :- write(main2), nl.\n' > "$D/im.pl";;
    esac
    ( cd "$D" && timeout -k 5 30 swipl -q im.pl < /dev/null > iw.out 2> /dev/null; echo $? > iw.rc
      timeout -k 5 30 "$B/scrip" --run im.pl < /dev/null > i3.out 2> /dev/null; echo $? > i3.rc
      timeout -k 5 60 "$B/scrip" --compile --out=im.s im.pl < /dev/null 2> /dev/null && gcc -no-pie im.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o im 2> /dev/null && { timeout -k 5 30 ./im < /dev/null > i4.out 2> /dev/null; echo $? > i4.rc; } )
    for m in 3 4; do
        if cmp -s "$D/iw.rc" "$D/i$m.rc" && cmp -s "$D/iw.out" "$D/i$m.out"; then echo "  m$m initialization order shape $k GREEN: $(paste -sd, "$D/iw.out") rc $(cat "$D/iw.rc") as swipl"
        else echo "  m$m initialization order shape $k RED: swipl [$(paste -sd, "$D/iw.out")] rc $(cat "$D/iw.rc"), scrip [$(paste -sd, "$D/i$m.out" 2>/dev/null)] rc $(cat "$D/i$m.rc" 2>/dev/null)"; red=1; fi
    done
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
