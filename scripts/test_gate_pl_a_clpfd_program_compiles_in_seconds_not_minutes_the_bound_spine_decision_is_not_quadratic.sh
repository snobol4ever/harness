#!/bin/bash
# test_gate_pl_a_clpfd_program_compiles_in_seconds_not_minutes_the_bound_spine_decision_is_not_quadratic.sh
# -- THE PLANNER'S BOUND-SPINE DECISION COSTS ONE WALK PER BOUND, NOT ONE PER QUESTION (ceo CEO-1960 regression request; cfo, SCRIP 275416cf5; hq_packages). planner_bound_spine (zeta_plan.cpp) decides whether an
# if-then-else or negation BOUND's record lives on the spine, so that its committing UNMARK -- a DISCARD-LAW edge, restore = E_cont -- can pop it (ARCH-THREE-ZETAS-EMISSION.md, D3 kind 7). It was asked
# #BOUND x #UNMARK times by zst_plan's nested loop and once per node-edge by zd_k_own through zd_bcs_when, each ask a fence scan over every node plus a walk over every node's edges; on the 9,661-node clause
# proc_$clpfd_run_propagator$2F2 that is minutes, and every program that loads library(clpfd) pays it (Pl2Wam/all.pl 35.8 s before, past 130 s after; 88 of 191 Prolog programs timed out at 90 s). The fence's
# existence and the outside-edge boolean are STRUCTURAL facts of the graph and are cached per BOUND in its fcn record; the retaining walk, which reads plan state, stays per call, so the answer and the emitted
# code are unchanged (351 of 351 programs byte-identical .s). THE WITNESS: a six-line clpfd program must compile (scrip --compile) inside a 100 s cap -- measured 22-34 s with the cure and past 150 s without it,
# so the cap sits well clear of both. rc 0 compiled in time; rc 1 timed out or failed; rc 2 cannot measure (no ./scrip).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/bsp-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/c.pl" <<'PL'
:- use_module(library(clpfd)).
:- initialization(main).
main :- X in 1..5, X #> 3, label([X]), write(X), nl.
PL
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
[ -x ./scrip ] || { echo "REFUSE(2): no ./scrip -- run make -j8 in SCRIP"; exit 2; }
t0=$(date +%s); timeout -k 5 100 ./scrip --compile --out="$T/c.s" "$T/c.pl" < /dev/null > "$T/c.out" 2>&1; rc=$?; secs=$(( $(date +%s) - t0 ))
if [ $rc -eq 0 ] && [ -s "$T/c.s" ]; then echo "GATE OK -- a clpfd program compiled in ${secs}s (cap 100 s)"; exit 0; fi
if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then echo "GATE FAIL -- a clpfd program did not compile inside 100 s (rc=$rc): the planner's bound-spine decision is quadratic again"; exit 1; fi
echo "GATE FAIL -- the clpfd witness did not compile (rc=$rc): $(head -c 300 "$T/c.out")"; exit 1
