#!/bin/bash
# test_gate_pl_a_monotonic_tables_delta_step_resumes_after_the_source_call_and_never_reruns_the_clause_prefix_as_swipl.sh -- THE RESUME RECORD
# (ARCH-PROLOG-TABLING-IDG.md section 4b, the cto's ruling 2026-10-25; hq_zetas). A monotonic table's delta step is a continuation by construction: the lowerer emits, for every
# source call of a clause of a monotonic or lazy table (a call of a hooked dynamic or of a tabled predicate), a resume clause whose body is that call and the goals after it, and
# the call records rs(Source, Resume, LiveVariables) on the table's graph during an evaluation; a delta on the source runs the resume clause under the mono context, so the
# clause PREFIX (here an assert(reeval) before the call) never runs again, as swipl's continuation. The witness: plain and answer-subsumption (min, max) tables, eager and lazy,
# a disjunction arm holding the call, an if-then-else after it; chk reads whether reeval was asserted by a body re-run (swipl: never). The program is the witness and the expected
# output was cut from swipl 9.0.4 (a run of the same program). rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure.
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/rsw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/rsw.pl" <<'PL'
:- initialization(main).
:- dynamic d1/1 as monotonic.
:- dynamic d2/1 as monotonic.
:- dynamic reeval/0.
:- table p/1 as monotonic.
:- table q/1 as (monotonic, lazy).
:- table (pm(min), rm(min), qm(min)) as (monotonic, lazy).
:- table (pe(max), re(max)) as monotonic.
p(X) :- assert(reeval), d1(X).
q(X) :- assert(reeval), d1(A), ( A > 5 -> X = big(A) ; X = small(A) ).
rm(X) :- d1(X).
qm(X) :- d2(X).
pm(X) :- assert(reeval), rm(X) ; qm(X).
re(X) :- d1(X).
pe(X) :- assert(reeval), re(X).
sh(G) :- findall(X, call(G, X), L0), sort(L0, L), write(G-L), nl.
chk(T) :- ( reeval -> write(T-body_reran) ; write(T-no_rerun) ), nl, retractall(reeval).
main :- sh(p), sh(q), sh(pm), sh(pe), retractall(reeval),
    assert(d1(1)), sh(p), chk(a), sh(q), chk(b), sh(pm), chk(c), sh(pe), chk(d),
    assert(d1(0)), sh(p), sh(pm), chk(e), sh(pe), chk(f),
    assert(d2(-1)), sh(pm), chk(g), assert(d2(2)), sh(pm), chk(h),
    assert(d1(7)), sh(p), sh(q), sh(pm), sh(pe), chk(i).
PL
cat > "$T/rsw.ref" <<'REF'
p-[]
q-[]
pm-[]
pe-[]
p-[1]
a-no_rerun
q-[small(1)]
b-no_rerun
pm-[1]
c-no_rerun
pe-[1]
d-no_rerun
p-[0,1]
pm-[0]
e-no_rerun
pe-[1]
f-no_rerun
pm-[-1]
g-no_rerun
pm-[-1]
h-no_rerun
p-[0,1,7]
q-[big(7),small(0),small(1)]
pm-[-1]
pe-[7]
i-no_rerun
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/rsw.pl" "$T/rsw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes step a monotonic table by its resume records as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a monotonic table's delta step re-ran a clause prefix or answered differently from swipl in a mode"; exit 1;; esac
