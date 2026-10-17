#!/usr/bin/env bash
# test_gate_pl_a_memory_limit_is_a_catchable_resource_error_for_length_numlist_and_the_trail_arena_answers_as_swipl.sh -- A MEMORY LIMIT IS A CATCHABLE resource_error(stack) FOR THE BULK LEAVES, AND THE TRAIL ARENA HOLDS 5 MILLION BINDINGS, IN BOTH MODES
# (hq_prolog 2026-10-15, row prolog-exhausting-the-heap-cap-or-the-trail-arena-ends-the-run-where-swipl-raises-a-catchable-resource-error; the ceo's CEO-1791
# ruling, road B: the bulk leaves check the cap and raise before they allocate; no codegen).
# THE CURE: length(L, N) and numlist(Low, High, L) ask '$heap_guard'/2 (by_name_dispatch.c, rt_gcheap_cap_bytes) before they build N list cells of 48 bytes: when
# N * 48 exceeds the smaller of the heap cap and the stack_limit flag the call raises error(resource_error(stack), _) -- catchable, where it ran 3 seconds into the
# cap and exited rc 1.  The stack_limit flag (SWI's, 1 GB default) is settable (a program lowers it, as SWI core/test_resource_error does, and restores it);
# the effective limit is never above the heap cap, which stays a cap.  numlist/3 fails for Low > High and raises swipl's instantiation/type errors.  The trail arena
# is 512 MB of address space (it was 128 MB: 4,194,303 conditional bindings), so five million bindings under an open choice point (the second arm, run with -d1024m
# and cut from swipl) complete.
# THE ARM: the witness below is cut against swipl -q in this run and diffed in mode 3 and mode 4; the second arm is one program run in both modes under -d1024m.
# RED BEFORE (the parent): resource_error never reached the catch (rc 1 after the cap), numlist(5,1,L) answered [], the arena program died "trail arena exhausted ... REFUSE rc=2".
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~25 s (the trail arm builds 5 million bindings twice).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_a_memory_limit_is_a_catchable_resource_error_for_length_numlist_and_the_trail_arena_answers_as_swipl
refuse() { echo "⛔ REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
t(T, G) :- catch((call(G) -> \+ \+ (numbervars(T, 0, _), writeq(T)) ; writeq(no)), error(E, _), \+ \+ (numbervars(E, 0, _), writeq(caught(E)))), nl.
main :-
    t(E1, catch(length(_, 100000000), error(E1, _), true)),
    t(E2, catch((length(L2, 100000000), L2 = [_|_]), error(E2, _), true)),
    t(E3, (current_prolog_flag(stack_limit, Old3), set_prolog_flag(stack_limit, 1000000), catch((numlist(1, 100000, L3), L3 = [_|_], length(L3, _)), error(E3, _), true), set_prolog_flag(stack_limit, Old3))),
    t(L4, (length(L4, 3), L4 = [a|_])),
    t(L5, numlist(1, 5, L5)),
    t(L6, (length(L6, 0))),
    t(N7, (length(L7, 7), length(L7, N7))),
    t(yes, (current_prolog_flag(stack_limit, X8), integer(X8))),
    t(E9, (current_prolog_flag(stack_limit, Old), set_prolog_flag(stack_limit, 1000000), catch(length(_, 100000), error(E9, _), true), set_prolog_flag(stack_limit, Old))),
    t(N10, (length(L10, 10000), length(L10, N10))),
    t(L11, (numlist(5, 1, L11))),
    t(E12, catch(length(_, -1), error(E12, _), true)),
    t(E13, catch(length(_, a), error(E13, _), true)),
    t(E14, catch(numlist(a, 3, _), error(E14, _), true)), t(E15, catch(numlist(1, b, _), error(E15, _), true)), t(E16, catch(numlist(_, 3, _), error(E16, _), true)), t(L17, numlist(3, 3, L17)).
PL
cat > "$D/t.pl" <<'PL'
:- initialization(main).
main :- catch((length(L, 5000000), (true ; true), maplist(=(x), L), write(bound)), error(resource_error(_), _), write(caught)), nl, halt.
PL
( cd "$D" && timeout -k 5 60 swipl -q -t halt w.pl < /dev/null > want 2> /dev/null )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 60 swipl -q t.pl < /dev/null > twant 2> /dev/null )
[ "$(cat "$D/twant")" = bound ] || refuse "swipl did not bind the five million variables: $(cat "$D/twant")"
( cd "$D" && timeout -k 5 60 "$B/scrip" --run w.pl < /dev/null > m3 2> m3.err; timeout -k 5 120 "$B/scrip" --run -d1024m t.pl < /dev/null > tm3 2> tm3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 60 ./w < /dev/null > m4 2>> m4.err
  timeout -k 5 60 "$B/scrip" --compile -o t.s t.pl < /dev/null 2> tm4.err && gcc -no-pie t.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o t 2>> tm4.err && timeout -k 5 120 ./t -d1024m < /dev/null > tm4 2>> tm4.err )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
    tf=t$m
    if [ "$(cat "$D/$tf" 2>/dev/null)" = bound ]; then echo "  $m trail arm GREEN: five million bindings under an open choice point bound as swipl"
    else echo "  $m trail arm RED: [$(cat "$D/$tf" 2>/dev/null)] $(head -c 160 "$D/t$m.err" 2>/dev/null)"; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
