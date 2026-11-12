> MOVED 2026-11-12 by the cfo (row tests-consolidation-finish-cfo) from corpus/tests/prolog/lifo/KEEP.md: the witnesses this page names are now entries lifo__<name> of the prolog master (corpus/tests/prolog), staged for the step harness by lib_design_witness.sh design_witness_stage; read "standalone" and "kept loose" below as history.

# corpus/tests/prolog/lifo -- THE WITNESSES OF DESIGN-PLAN: prolog-lifo (the cto, 2026-10-28, CEO-1997/1998; ARCH-PROLOG-ACTIVATION-LIFETIME.md section 9)

These are standalone witness programs, NOT entries of the ProRungs master (ALL.pl): each `lifo_*.pl` has its `.ref` cut from swipl 9.0.4 (`swipl -q -t halt`, twice, equal), and STEPS.tsv assigns each to the design step whose landing turns it green. They are graded by `harness/scripts/test_design_prolog_lifo_steps.sh --step N` in both modes under `SCRIP_ZD_RTCHECK=1`, never by the suite runner; a witness that stays red after its step lands is that step's row, and one that reveals a defect outside the plan is harvested into the master through the usual road. Kept loose so an HQ can run one by name and so the step harness owns their grading.

| file | step | what it witnesses |
|---|---|---|
| `lifo_retry_fail_loop.pl` | 1, 6 | a clause retry after a failure-driven loop over a generator |
| `lifo_retract_fail_loop.pl` | 1 | a failure-driven loop over retract/1 whose folded fail is a backward gamma into the db walk (ed87ee3ac) |
| `lifo_clause_fail_loop.pl` | 1 | the same over clause/2 |
| `lifo_between_retaining_fold.pl` | 1 | a retaining call between the generator and the folded fail (the edge the TO beta anchor covers) |
| `lifo_db_walk_in_disjunction.pl` | 1 | a db walk inside a disjunction whose gamma pops its operands (c33d10f89) |
| `lifo_fd_label_neq.pl` | 2 | clpfd propagation and labeling, deterministic |
| `lifo_fd_sum.pl` | 3 | clpfd sum and ordering constraints: the depth check fires at a join in clpfd_run_propagator/2 at c33d10f89 |
| `lifo_fd_queens4.pl` | 3, 6 | 4-queens under clpfd, the reduced queens_clpfd: the same join fire |
| `lifo_ite_join_depths.pl` | 2, 3 | if-then-else and disjunction joins whose arms exit at different depths |
| `lifo_ite_throw_arms.pl` | 3, 4, 6 | ec65ae574's v(q(1)) witness: arms that throw or fail without reaching the join |
| `lifo_disjunction_retaining_arms.pl` | 3 | a disjunction both of whose arms retain |
| `lifo_soft_cut.pl` | 3, 4 | the soft cut |
| `lifo_soft_cut_det_condition.pl` | 3 | soft cuts whose condition cannot retain (X > 0, X == a), which slice 2b admits to the cells road, beside one whose condition retains (member/2), which it keeps on the frame word (ARCH-PROLOG-ACTIVATION-LIFETIME 9.12 (2); the cfo, 2026-10-29) |
| `lifo_ite_retaining_condition.pl` | 4 | a condition that retains, committed |
| `lifo_catch_findall.pl` | 4 | catch/3 and findall/3 BOUND records with a throw |
| `lifo_findall_catch_between.pl` | 4 | a catch around a findall over between(1, 9000000, X) that hits the stack limit: traps at the UNMARK alpha under SCRIP_ZD_RTCHECK=1 in both modes, identically with and without the generator beta anchor (hq_prolog 2026-10-28; the ProRungs core entry findall_catch_between_1) |
| `lifo_call_cleanup_ite_retry.pl` | 4 | a call_cleanup goal re-entered for its next solution, then an if-then-else on the cleanup flag (call_det/2 of GNU Prolog is this shape): the SHIPPED build segfaults in both modes (pc nil) on the second solution, plain, with no diagnostic switch; swipl prints 1-false 2-false 3-true (hq_prolog 2026-10-28; the GNU source driver BipsPl/call_driver) |
| `lifo_negation_retaining.pl` | 4 | negation over a retaining goal |
| `lifo_nested_conditions_throw.pl` | 4 | nested if-then-else conditions with a throw |
| `lifo_value_across_retaining_call.pl` | 5 | a value produced before a retaining call and read after it |
| `lifo_variable_across_excursion.pl` | 5 | a frame variable read after an excursion |
| `lifo_record_after_excursion.pl` | 5 | a construct record read after an excursion |
| `lifo_wakeup_concede.pl` | 5, 6 | a clause conceding from inside an attribute wakeup's indefinite run (freeze/2) |
| `lifo_dif_concede.pl` | 6 | the same through dif/2 |
| `lifo_cut_after_retaining_call.pl` | 6 | a cut after a retaining call then the next clause |
| `lifo_throw_through_clauses.pl` | 6 | a ball thrown from a clause while sibling clauses remain |
| `lifo_ite_arm_resumes_1.pl` | 3 | a then-arm that holds a disjunction, resumed through the GATE after the commit (clpfd labeling bisect over all_distinct; the cfo's bisect witness) |
| `lifo_ite_arm_resumes_2.pl` | 3 | the same through A*B #= C+D over 0..15 |
| `lifo_catch_retaining_goal.pl` | 3 | a catch around a nondeterministic goal called from a findall in a clause body keeps every solution in mode 3 (hq_runtime's catch_loses_alternatives_m3; the regression of SCRIP a7b92b0d8, whose unconditional GATE cells lost the alternatives in mode 3 only) |
| `lifo_repeat_read_loop_in_setup_call_cleanup.pl` | 3 | a repeat/read_term/if-then-else-with-a-cut/assertz loop inside setup_call_cleanup (xsb_builtins.pl load_dyn/1, hq_packages' witness): compiles and runs in both modes; SCRIP 49e8b05e1 (the omega rule of slice 1a) made it FATAL x86_zop at compile time (reverted at af8770cef) |
