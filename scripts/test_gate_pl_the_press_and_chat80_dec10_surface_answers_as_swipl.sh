#!/usr/bin/env bash
# test_gate_pl_the_press_and_chat80_dec10_surface_answers_as_swipl.sh
#
# THE ROWS (hq_pascal's, found vendoring PRESS and CHAT-80 under CEO-1595; hq_prolog 2026-10-10): abolish/2 refused at compile;
# put/1 of a one-element code list a type error; the recorded database (recorda/recordz/recorded/erase) missing; prompt/2, prompt1/1, statistics/2 and style_check/1 missing; library(quintus) missing
# (log/2, acos/2, sqrt/2, otherwise/0); and in mode 4 an asserted clause calling the program's
# own for/2 refused at run time.
# THE CURES: the lowerer rewrites abolish(N, A) to abolish(N/A) and put(X) to (V is X, put_code(V)) as DEC-10 Prolog's put/1
# evaluates; the evaluator reads [X] as X (a code) or the code of a one-character atom, as swipl does; the prelude carries the
# recorded database over '$rec'/3 facts with '$record'(Id) references, and erase/1 routes such a reference there; public and mode
# are declarations; statistics/2 reads a new CPU-clock leaf '$cpu_ms'/1 (CLOCK_PROCESS_CPUTIME_ID) and wall_ms/1, prompt/2 keeps the
# prompt (printed by no read, as swipl prints none when user_input is not a terminal), prompt1/1 and style_check/1 accept; library(quintus) is vendored from swipl 9.0.4
# through util_gen_prolog_prelude_libs.py (current_stream/3 omitted: SCRIP lowers it natively); and the ladder's builtin refusal does not fire while lowering at run time (g_stage2.rt_lowering), where
# the program's own predicates are not in the compile-time table.
#
# THE ARM: 15 lines as SWI-Prolog 9.0.4 prints them, in both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
:- set_prolog_flag(double_quotes, codes).
:- initialization(main).
:- public natnum/1.
:- mode(natnum(+)).
:- dynamic(seen/1).
natnum(0).
seen(a).
for(0, _Goal) :- !.
for(N, Goal) :- N > 0, call(Goal), M is N-1, for(M, Goal), !.
main :-
  abolish(seen, 1), ( catch(seen(_), _, fail) -> write(still) ; write(gone) ), nl,
  put("("), put([0'x]), put(0')), nl,
  X is [0'a] + 1, write(X), nl,
  recordz(k, val(1), _), recordz(k, val(2), R2), recorda(k, val(0), _),
  findall(V, recorded(k, val(V), _), L1), write(L1), nl,
  erase(R2), findall(V, recorded(k, val(V)), L2), write(L2), nl,
  recorda(f(x, y), two), ( recorded(f(_, _), T) -> write(T) ; write(none) ), nl,
  log(2.718281828459045, Lg), write(Lg), nl, acos(0.5, Ac), write(Ac), nl, sqrt(16, Sq), write(Sq), nl,
  ( otherwise -> write(otherwise) ; true ), nl,
  natnum(N0), write(N0), nl,
  prompt(Old, 'Q: '), prompt(Mid, Old), write(Mid), nl, prompt1('P: '), style_check(-singleton),
  statistics(runtime, [T0, _]), statistics(walltime, [W0, _]), statistics(cputime, C),
  ( integer(T0), integer(W0), number(C) -> write(stats_ok) ; write(stats_bad) ), nl,
  assertz((h :- for(2, (write(q), nl)))), h,
  halt.
PL
cat > "$D/g.ref" <<'REF'
gone
(x)
98
[0,1,2]
[0,1]
two
1.0
1.0471975511965979
4.0
otherwise
0
Q: 
stats_ok
q
q
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" g.pl < /dev/null > g.m3 2>&1 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>&1 )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 15 of 15 lines answer as swipl"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): the PRESS and CHAT-80 DEC-10 surface answers as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
