#!/bin/bash
# test_gate_pl_a_transaction_undoes_every_dynamic_predicate_and_a_clause_ref_taken_before_it_survives_the_rollback_as_swipl.sh -- THE
# RUNTIME'S CLAUSE ROAD IS THE TRANSACTION'S LOG (ARCH-PROLOG-TABLING-IDG.md section 6, the cto's rules A and B; hq_zetas). Every assert, retract, retractall and erase of any dynamic predicate,
# declared or not, passes through pl_db_store or pl_db_note_erase, which append an integer record (kind, the db's registry cell, the slot) to the current transaction's tx(Records) term; a rollback
# clears the erased mark of what the transaction removed and erases what it added, so a clause reference taken BEFORE the transaction stays valid after the rollback and the order of the clauses is
# the original one, as swipl does it. The witness: plain dynamic predicates, a rolled-back retract with asserts before and after, the reference probe, retractall, an exception, a snapshot, nested
# commit and nested failure, a nullary predicate. The program is the witness and the expected output was cut from swipl 9.0.4 (a run of the same program).
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/txr-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/txr.pl" <<'PL'
:- initialization(main).
:- dynamic p/1, q/2, r/0.
show(G) :- findall(X, call(G, X), L), write(G-L), nl.
showq :- findall(A-B, q(A, B), L), write(q-L), nl.
main :-
    assertz(p(1)), assertz(p(2)), assertz(p(3)), clause(p(1), true, R1), clause(p(2), true, R2),
    ( transaction(( retract(p(1)), assertz(p(4)), asserta(p(0)), fail )) -> true ; true ),
    show(p), ( clause(H1, B1, R1) -> write(ref_still(H1, B1)) ; write(ref_dead) ), nl,
    transaction(( retract(p(2)), assertz(p(5)) )), show(p), ( clause(_, _, R2) -> write(r2_alive) ; write(r2_dead) ), nl,
    assertz(q(1, a)), assertz(q(2, b)), assertz(q(1, c)),
    ( transaction(( retractall(q(1, _)), assertz(q(3, d)), showq, fail )) -> true ; true ), showq,
    catch(transaction(( retract(q(2, b)), assertz(q(9, z)), throw(boom) )), E, ( write(caught(E)), nl )), showq,
    snapshot(( retractall(p(_)), assertz(p(7)), show(p) )), show(p),
    transaction(( assertz(p(8)), transaction(( retract(p(8)), assertz(p(9)) )), show(p) )), show(p),
    ( transaction(( assertz(p(10)), transaction(( assertz(p(11)) )), fail )) -> true ; write(outer_failed), nl ), show(p),
    assertz(r), ( transaction(( retract(r), \+ r, fail )) -> true ; ( r -> write(r_back) ; write(r_gone) ), nl ).
PL
cat > "$T/txr.ref" <<'REF'
p-[1,2,3]
ref_still(p(1),true)
p-[1,3,5]
r2_dead
q-[2-b,3-d]
q-[1-a,2-b,1-c]
caught(boom)
q-[1-a,2-b,1-c]
p-[7]
p-[1,3,5]
p-[1,3,5,9]
p-[1,3,5,9]
outer_failed
p-[1,3,5,9]
r_back
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/txr.pl" "$T/txr.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes roll a transaction back over every dynamic predicate as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a transaction's rollback answered differently from swipl in a mode"; exit 1;; esac
