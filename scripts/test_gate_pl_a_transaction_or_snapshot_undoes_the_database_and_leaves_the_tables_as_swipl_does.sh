#!/bin/bash
# test_gate_pl_a_transaction_or_snapshot_undoes_the_database_and_leaves_the_tables_as_swipl_does.sh -- TRANSACTIONS AND
# SNAPSHOTS OVER TABLES, ARCH-PROLOG-TABLING-IDG.md section 6 (hq_zetas, row prolog-tabling-transactions-and-snapshots-..., CEO-1960). transaction(G) runs once(G) and keeps its changes on success;
# on failure or an exception it undoes the changes made to the declared incremental and monotonic dynamics (a snapshot of each predicate at its first change) and leaves the tables as swipl does:
# an incremental table re-evaluated against the rolled-back database reads invalid, a monotonic table keeps its old answers and stays valid (the answers its inside deltas added are removed), a table
# the transaction created over untouched dependencies stays valid. snapshot(G) always undoes. The witness: incremental, eager and lazy monotonic tables, commit, failure, exception, snapshot, nested
# commit under an outer failure, retract and retractall inside a snapshot. The program is the witness and the expected output was cut from swipl 9.0.4 (a run of the same program).
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/txw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/txw.pl" <<'PL'
:- initialization(main).
:- use_module(library(increval)).
:- use_module(library(tables)).
:- dynamic di/1 as incremental.
:- dynamic dm/1 as monotonic.
:- dynamic dl/1 as monotonic.
:- table pi/1 as incremental.
:- table pm/1 as monotonic.
:- table pl/1 as (monotonic, lazy).
pi(X) :- di(X).
pm(X) :- dm(X).
pl(X) :- dl(X).
show(G) :- findall(X, call(G, X), L0), sort(L0, L), write(G-L), nl.
inv(G) :- functor(G, N, _), ( incr_is_invalid(G) -> write(invalid(N)) ; write(valid(N)) ), nl.
reset :- abolish_all_tables, retractall(di(_)), retractall(dm(_)), retractall(dl(_)).
main :-
    reset, assertz(di(1)), assertz(dm(1)), assertz(dl(1)), show(pi), show(pm), show(pl),
    transaction(( assertz(di(2)), assertz(dm(2)), assertz(dl(2)), show(pi), show(pm), show(pl) )),
    inv(pi(_)), inv(pm(_)), inv(pl(_)), show(pi), show(pm), show(pl),
    ( transaction(( assertz(di(3)), assertz(dm(3)), assertz(dl(3)), show(pi), show(pm), show(pl), fail )) -> write(committed) ; write(rolled_back) ), nl,
    inv(pi(_)), inv(pm(_)), inv(pl(_)), show(pi), show(pm), show(pl),
    catch(transaction(( assertz(di(4)), assertz(dm(4)), show(pm), throw(oops) )), E, ( write(caught(E)), nl )),
    inv(pi(_)), inv(pm(_)), show(pi), show(pm),
    snapshot(( assertz(di(5)), assertz(dm(5)), assertz(dl(5)), show(pi), show(pm), show(pl) )),
    inv(pi(_)), inv(pm(_)), inv(pl(_)), show(pi), show(pm), show(pl),
    transaction(( transaction(( assertz(dm(6)), show(pm) )), assertz(dm(7)), show(pm), fail ; true )), show(pm),
    ( transaction(( transaction(( assertz(dm(6)), show(pm) )), assertz(dm(7)), show(pm), fail )) -> true ; write(outer_failed), nl ), show(pm),
    snapshot(( retract(dm(2)), show(pm), retractall(dl(_)), show(pl) )), inv(pm(_)), inv(pl(_)), show(pm), show(pl),
    findall(X, dm(X), Dm), write(dm(Dm)), nl,
    findall(X, di(X), Di), write(di(Di)), nl.
PL
cat > "$T/txw.ref" <<'REF'
pi-[1]
pm-[1]
pl-[1]
pi-[1,2]
pm-[1,2]
pl-[1,2]
valid(pi)
valid(pm)
valid(pl)
pi-[1,2]
pm-[1,2]
pl-[1,2]
pi-[1,2,3]
pm-[1,2,3]
pl-[1,2,3]
rolled_back
invalid(pi)
valid(pm)
valid(pl)
pi-[1,2]
pm-[1,2]
pl-[1,2]
pm-[1,2,4]
caught(oops)
invalid(pi)
valid(pm)
pi-[1,2]
pm-[1,2]
pi-[1,2,5]
pm-[1,2,5]
pl-[1,2,5]
invalid(pi)
valid(pm)
valid(pl)
pi-[1,2]
pm-[1,2]
pl-[1,2]
pm-[1,2,6]
pm-[1,2,6,7]
pm-[1,2,6,7]
pm-[1,2,6,7]
pm-[1,2,6,7]
outer_failed
pm-[1,2,6,7]
pm-[1,6,7]
pl-[]
invalid(pm)
invalid(pl)
pm-[1,2,6,7]
pl-[1,2]
dm([1,2,6,7])
di([1,2])
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/txw.pl" "$T/txw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes undo a transaction and leave the tables as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a transaction or snapshot answered differently from swipl in a mode"; exit 1;; esac
