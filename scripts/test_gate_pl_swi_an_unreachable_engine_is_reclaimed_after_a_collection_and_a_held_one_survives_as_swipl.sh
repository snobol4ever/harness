#!/bin/bash
# test_gate_pl_swi_an_unreachable_engine_is_reclaimed_after_a_collection_and_a_held_one_survives_as_swipl.sh -- THE ENGINE HANDLE IS A COLLECTOR-VISIBLE VALUE (ceo CEO-1960/1964/1966; row
# prolog-swi-engines-designed-by-the-cto-and-built-ceo-1960, stage B; the cto's ruling (a), the cfo's four conditions of 2026-10-25).
# The handle of an engine is an HB_DINST instance of the hidden datatype engine (rt_pl_engine.c): immutable, shared by copy_term/assert/findall/nb_setval as a rational is, atomic to unify, compare,
# write and atomic/1, printed <engine>(Id,0xADDR). The context, the trail arena and the slab ride in it as integers OUTSIDE the collected heap (RT_DIAG asserts gc_blk_of reads null for each). The registry is
# a g_runtime member (g_misc_t.pl_eng) cleared through rt_gc_weak_keep in a post-mark hook beside kw_cset_gc_weak; an unmarked anonymous engine goes on a list of plain integers and is destroyed AFTER the
# collection (scrip_coexpr_destroy through rt_proc_drop_frame_h, rt_pl_tr_free_arena), never inside it; its id is reported by '$engine_reaped'/1 so the prelude forgets its records and the finalisation never
# runs Prolog. A handle stored by assert is rebuilt from '$pl_engine'(Id) and PINNED (the clause database is not scanned), so an engine referenced only from a clause survives. An engine that holds its own
# handle in its parked frame is KEPT, as swipl keeps it (measured: 9.0.4 and 10.1.5, 100 of 100 retained): the parked stacks are unconditional roots. garbage_collect/0 and garbage_collect_atoms/0 now REQUEST a
# collection ('$gc_now'), which swipl's gc_engines tests assume.
# THE WITNESSES (refs cut from swipl 9.0.4; 10.1.5 reads them byte-identically): ew.pl -- a hundred plain engines dropped are reclaimed, a hundred parked ones too, a hundred self-referencing ones are kept,
# an engine reachable only from an asserted clause survives and answers, live engines are listed and answer; ewb.pl -- the asserted engine also survives SCRIP_GC_STRESS=1 (a collection at every poll) and a
# later collection. A THIRD arm reads SCRIP's own counters: after a hundred dropped engines and one collection, reaped=100 freed=100 live=0 (the destroy count N minus the live).
# rc 0 all arms agree; rc 1 one differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/engr-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/ew.pl" <<'PL'
:- use_module(library(lists)).
:- use_module(library(aggregate)).
:- initialization(main).
:- dynamic held/1.
n(N) :- aggregate_all(count, current_engine(_), N).
settle(Target) :- ( between(1, 40, _), garbage_collect_atoms, garbage_collect, n(N), N =< Target -> true ; true ).
plain :- engine_create(x, true, _).
parked :- engine_create(X, between(1, 3, X), E), engine_next(E, _).
selfref :- engine_create(X, (engine_self(E), engine_yield(E-X), true), H), engine_next(H, _).
hold :- engine_create(X, between(1, 5, X), E), assertz(held(E)).
verdict(Name, Goal, Base) :- forall(between(1, 100, _), Goal), settle(Base + 25), n(N), D is N - Base,
    ( D =< 25 -> V = reclaimed ; D >= 50 -> V = kept ; V = partial ), format('~w: ~w~n', [Name, V]).
main :-
    n(B0), verdict(plain, plain, B0),
    n(B1), verdict(parked, parked, B1),
    n(B2), verdict(selfref, selfref, B2),
    hold, settle(0), held(H), engine_next(H, V1), engine_next(H, V2), format('held: ~w ~w~n', [V1, V2]),
    engine_create(Xa, between(1, 3, Xa), L1), engine_create(Xb, between(10, 13, Xb), L2), settle(0),
    findall(E, current_engine(E), Es), ( memberchk(L1, Es), memberchk(L2, Es) -> writeln(live_listed) ; writeln(live_missing) ),
    engine_next(L1, A1), engine_next(L2, A2), format('live_answer: ~w ~w~n', [A1, A2]),
    engine_destroy(L1), engine_destroy(L2), writeln(done).
PL
cat > "$T/ew.ref" <<'REF'
plain: reclaimed
parked: reclaimed
selfref: kept
held: 1 2
live_listed
live_answer: 1 10
done
REF
cat > "$T/ewb.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
:- dynamic held/1.
hold :- engine_create(X, between(1, 5, X), E), assertz(held(E)).
churn :- engine_create(X, between(1, 3, X), E), engine_next(E, _).
main :- hold, forall(between(1, 6, _), churn), garbage_collect, garbage_collect,
    held(H), engine_next(H, V1), engine_next(H, V2), format('held: ~w ~w~n', [V1, V2]),
    findall(E, current_engine(E), Es), ( memberchk(H, Es) -> writeln(held_listed) ; writeln(held_missing) ),
    garbage_collect, engine_next(H, V3), format('later: ~w~n', [V3]), engine_destroy(H), writeln(done).
PL
cat > "$T/ewb.ref" <<'REF'
held: 1 2
held_listed
later: 3
done
REF
cat > "$T/ewc.pl" <<'PL'
:- initialization(main).
plain :- engine_create(x, true, _).
main :- forall(between(1, 100, _), plain), garbage_collect, '$engine_stats'(M, R, F, L), format('made=~w reaped=~w freed=~w live=~w~n', [M, R, F, L]).
PL
printf 'made=100 reaped=100 freed=100 live=0\n' > "$T/ewc.ref"
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
[ -x ./scrip ] || { echo "REFUSE(2): no ./scrip"; exit 2; }
bad=0
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/ew.pl" "$T/ew.ref" "$T/ewb.pl" "$T/ewb.ref" 2>&1)"; rc=$?; echo "$out" | tail -4; [ $rc -eq 0 ] || { echo "ARM 1 (both modes) rc=$rc"; bad=1; }
out="$(SCRIP_GC_STRESS=1 bash "$HERE/test_witness_both_modes.sh" "$T/ewb.pl" "$T/ewb.ref" 2>&1)"; rc=$?; echo "$out" | tail -3; [ $rc -eq 0 ] || { echo "ARM 2 (a collection at every poll) rc=$rc"; bad=1; }
timeout -k 5 120 ./scrip -i2048k "$T/ew.pl" < /dev/null > "$T/o3.txt" 2>&1; diff -q "$T/ew.ref" "$T/o3.txt" > /dev/null && echo "ARM 3 (-i2048k) equal" || { echo "ARM 3 (-i2048k) DIFFERS:"; head -4 "$T/o3.txt"; bad=1; }
timeout -k 5 120 ./scrip "$T/ewc.pl" < /dev/null > "$T/o4.txt" 2>&1; diff -q "$T/ewc.ref" "$T/o4.txt" > /dev/null && echo "ARM 4 (counters) equal" || { echo "ARM 4 (counters) DIFFERS:"; head -3 "$T/o4.txt"; bad=1; }
[ $bad -eq 0 ] && { echo "GATE OK -- a dropped engine is reclaimed, a held or self-referencing one is kept, as swipl; the destroy count is N"; exit 0; }
echo "GATE FAIL -- engine reclamation differs from swipl's"; exit 1
