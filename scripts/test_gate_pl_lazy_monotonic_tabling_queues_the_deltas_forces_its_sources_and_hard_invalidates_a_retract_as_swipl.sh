#!/bin/bash
# test_gate_pl_lazy_monotonic_tabling_queues_the_deltas_forces_its_sources_and_hard_invalidates_a_retract_as_swipl.sh -- LAZY MONOTONIC TABLING,
# ARCH-PROLOG-TABLING-IDG.md section 5 (the cto, CEO-1960; hq_zetas row prolog-tabling-lazy-monotonic-queues-and-forcing-sec-5-so-test-monotonic-lazy-agrees-with-swipl-ceo-1960).
# A table declared `as (monotonic, lazy)` queues the deltas of its sources and is invalidated softly (its dependents with it); a call of an invalid lazy table forces its
# invalid lazy sources first and then steps each queued delta; a retract or incr_invalidate_calls is a hard invalidation (forced, a full re-evaluation). The witness reads
# a lazy table over a dynamic, an intermediate lazy table, a lazy table over a dynamic and an eager-monotonic one over a lazy one, the retract that marks both tables forced,
# a dependency met only inside a step (pc(c) :- e(a), e(b)), and incr_propagate_calls / incr_invalidate_calls on a dynamic that has clauses of its own (a call site the
# SWI-dialect lowering must still hook). The program is the witness and the expected output was cut from swipl 9.0.4 (a run of the same program).
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/lzw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/lzw.pl" <<'PL'
:- initialization(main).
:- use_module(library(increval)).
:- use_module(library(tables)).
:- dynamic d/1 as monotonic.
:- dynamic dm/1 as monotonic.
:- dynamic xm/1 as monotonic.
:- dynamic e/1 as monotonic.
:- dynamic dq/1 as monotonic.
:- dynamic data/1.
:- table (p1/1, p2/1) as (monotonic, lazy).
:- table (aml/1, bml/1) as (monotonic, lazy).
:- table pc/1 as (monotonic, lazy).
:- table pe/1 as monotonic.
:- table pq/1 as (monotonic, lazy).
:- table pl/1 as (monotonic, lazy).
p1(X) :- d(X).
p2(X) :- p1(X).
bml(X) :- aml(X) ; xm(X).
aml(X) :- dm(X).
pc(c) :- e(a), e(b).
pe(X) :- pq(X).
pq(X) :- dq(X).
pl(X) :- dq(X).
dq(X) :- data(X).
show(G) :- findall(X, call(G, X), L0), sort(L0, L), write(G-L), nl.
inv(G) :- functor(G, N, _), ( incr_is_invalid(G) -> write(invalid(N)) ; write(valid(N)) ), nl.
fo(G) :- functor(G, N, _), ( get_call(G, T, _), '$idg_forced'(T) -> write(forced(N)) ; write(notforced(N)) ), nl.
main :-
    show(p2), assertz(d(1)), inv(p1(_)), inv(p2(_)), show(p2), inv(p1(_)), assertz(d(2)), show(p2), show(p1),
    assertz(dm(1)), assertz(dm(2)), show(bml), assertz(xm(3)), assertz(dm(4)), inv(aml(_)), inv(bml(_)), fo(aml(_)),
    retract(dm(1)), inv(aml(_)), inv(bml(_)), fo(aml(_)), fo(bml(_)), show(bml), fo(bml(_)),
    show(pc), assertz(e(a)), show(pc), assertz(e(b)), show(pc),
    show(pe), assertz(dq(5)), inv(pe(_)), inv(pq(_)), show(pe), show(pq), inv(pe(_)),
    assertz(data(1)), show(pl), assertz(data(2)), show(pl), incr_propagate_calls(dq(2)), show(pl),
    retractall(data(2)), show(pl), incr_invalidate_calls(dq(2)), show(pl).
PL
cat > "$T/lzw.ref" <<'REF'
p2-[]
invalid(p1)
invalid(p2)
p2-[1]
valid(p1)
p2-[1,2]
p1-[1,2]
bml-[1,2]
invalid(aml)
invalid(bml)
notforced(aml)
invalid(aml)
invalid(bml)
forced(aml)
forced(bml)
bml-[2,3,4]
notforced(bml)
pc-[]
pc-[]
pc-[c]
pe-[]
invalid(pe)
invalid(pq)
pe-[5]
pq-[5]
valid(pe)
pl-[1,5]
pl-[1,5]
pl-[1,2,5]
pl-[1,2,5]
pl-[1,5]
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/lzw.pl" "$T/lzw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes answer the lazy monotonic witness as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a lazy monotonic table answers differently from swipl in a mode"; exit 1;; esac
