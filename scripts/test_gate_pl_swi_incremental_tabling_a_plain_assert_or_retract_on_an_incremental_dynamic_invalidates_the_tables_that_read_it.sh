#!/bin/bash
# test_gate_pl_swi_incremental_tabling_a_plain_assert_or_retract_on_an_incremental_dynamic_invalidates_the_tables_that_read_it.sh -- SWI INCREMENTAL TABLING, THE
# GLUE (ceo CEO-1959; row prolog-swi-incremental-tabling-plain-assert-retract-invalidates-the-tables-ceo-1959). A predicate declared `:- dynamic d/1 as incremental`
# (alone or in an option list) is read by tables declared `as incremental`; a PLAIN assert/asserta/assertz/retract/retractall on it must invalidate those tables, and
# predicate_property(P, incremental) is true for the dynamic and for the tabled predicate. The program is the witness and the expected output was cut from swipl 9
# (a run of the same program): p/q/r over d/e, six changes (assertz, asserta, retract, retractall, assert), the option-list declaration, the property.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/incw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/incw.pl" <<'PL'
:- initialization(main).
:- table p/1 as incremental.
:- table q/1 as incremental.
:- dynamic d/1 as incremental.
:- dynamic e/1 as (incremental, abstract(0)).
p(X) :- d(X).
q(X) :- p(X), X > 1.
r(X) :- e(X).
:- table r/1 as incremental.
show(G) :- findall(X, call(G, X), L0), sort(L0, L), write(L), nl.
main :- show(p), show(q),
        assertz(d(1)), show(p), show(q),
        assertz(d(2)), show(p), show(q),
        asserta(d(3)), show(q),
        retract(d(1)), show(p), show(q),
        retractall(d(_)), show(p), show(q),
        assert(e(7)), show(r), assertz(e(8)), show(r), retractall(e(_)), show(r),
        ( predicate_property(d(_), incremental) -> write(d_incremental) ; write(d_not) ), nl,
        ( predicate_property(p(_), incremental) -> write(p_incremental) ; write(p_not) ), nl,
        ( predicate_property(e(_), incremental) -> write(e_incremental) ; write(e_not) ), nl.
PL
cat > "$T/incw.ref" <<'REF'
[]
[]
[1]
[]
[1,2]
[2]
[2,3]
[2,3]
[2,3]
[]
[]
[7]
[7,8]
[]
d_incremental
p_incremental
e_incremental
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/incw.pl" "$T/incw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes answer the incremental witness as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a plain assert or retract on an incremental dynamic left a table stale, or the property is missing"; exit 1;; esac
