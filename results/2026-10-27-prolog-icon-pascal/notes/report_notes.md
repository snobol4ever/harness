# Session notes (2026-10-26/27)

## Done and pushed earlier
- SCRIP 0371148: README Pascal benchmark grid re-measured on an -O2 build (geomean 0.087x fpc in m4, 0.086x in m3).
- corpus 839f83b: the two triangulation TSVs.

## Prolog LIFO (ARCH-PROLOG-ACTIVATION-LIFETIME 8.1/8.2)
Census (util_pl_rbp_operand_classes population, ops_rbp):
- b8f2218 (start): 16,356
- step 4: 6,864
- step 6: 4,286
- step 10: 1,395 (pre-alloc 0)
- step 14 (landing): TBD

Mechanisms built:
1. Call resume record on the spine (CALL_PROC_STAGED, block protocol): 32-byte cell, record at +16.
2. call/N (CALL_VALUE goal road) same record; args read in place via r9.
3. TO generator state on the spine (32 / 80 trailed with limit at +64; db walk 64 + frame record).
4. Definite BOUND records on the spine (rbp alias for UNMARK reads), whatever the condition nests.
5. If-then-else gate index: arm pushes {RAW, idx} below the join wall; GATE beta reads [rsp+8].
6. Definiteness predictor mirrors the plan; verdicts frozen at frame layout (no pre-allocation).

Regressions found and fixed in-session:
- between/3 (trailed TO limit under the value's payload word) -> limit at +64.
- clause/2 db walk (carve removed) -> 64-byte carve restored.
- soft-cut else-gate (beta entered by a gamma edge) -> keeps its frame word.
- nested ITE in a condition with a popping join wall -> cell written before the wall.

Next:
- BOUND records of catch/soft-cut/findall when definite (relax GATE/fence requirement).
- The hop (8.3) for indefinite BOUNDs with retaining conditions.
- Then: Prolog suites to 100% with REFs from oracles; Pascal suites.

## 2026-10-27 (continued)
- Landed LIFO: SCRIP ec65ae5, harness a4d64c1 (ops_rbp 16,356 -> 4,088, prealloc 0, core differential clean, smokes green).
- Trealla suite then showed 10 LIFO regressions (13 crashes) the core differential missed. Fixed on pl-suites:
  cleanup-read bounds keep frame record; backward gamma into a retaining box's beta pops to the family landing;
  zst exemption only for slotless vars; predictor mirrors plan runs (retaining DJ arms, run back-marking, no restore exemption);
  TO beta anchors rsp when definite. Trealla 277/329 both modes, 0 crashes (main pre-LIFO SCORE: 272).
- Remaining predictor/plan mismatches (latent, outputs correct): clpfd neq/equal_ shape (entry run left without base), $clpfd_optimise.
- Harness: fresh-vars compare mode (ISO 7.10.5 fresh variable names) -- pending application to package CSVs.

## 2026-10-27 morning (batch 2 = "Trealla batch 1" + LIFO bound regression)
- INRIA (ed87ee3): 442/442 both modes (3 OUTSIDE).
- Trealla 290/329 at ed87ee3; batch fixes 9 more in scratch runs (1110, 1140, test0113, cut_after_call, shift_again/compiled/det/no_reset/soft_cut).
- Found a LIFO regression on main via test_gate_pl_a_bounded_conditional...: home_frame widening of spine BOUNDs aborts x86_zop for an indefinite bound
  (forall(recorded..), forall(between..), forall(between..)) -- passes at b8f2218. Fixed in dev4 (widening only for predicted-definite bounds).
- Coroutine (reset/3) trail: caller tidy dropped a parked coroutine's live sentinels; pl_keep floor. Pre-existing (pre-LIFO crashed).
- Gate harness note: gates test $HERE/../../SCRIP physically -- run them from a layout dir (g4/g5/gL/gO) with a real harness copy.
- Pre-existing gate reds at b8f2218 too: pl_a_zero_arity_term_is_the_atom_in_both_modes (m4).
- Rosetta/XSB gradings at ed87ee3 hit the 2h cap under load; regrade after landing without the cap.
- Deferred Trealla: '[|]' list functor (SWI-7), var order, clpb sat/1, threads/sockets/process/uri/filesex, unget_char in SWI dialect,
  tabled answer order (SWI trie hash), listing var names, cyclic print depth, module-qualified existence errors, 0' number quirk.
- Two more blockers found while validating the batch:
  - reclaim regression (spine resume records invisible to the assertz reclaim) and the db-walk beta over-pop (clause_2 gate) -- fixed.
  - writef/clpfd gate went red on dev4 only: NOT a planner bug in the batch but a latent stale-cache bug. Runtime fragment
    compiles (every clause of a program the db loads) IR_free their graph but never reset the node-address-keyed fcn table;
    the next fragment's nodes reuse the addresses and read the dead graph's facts (frozen bound-spine verdicts), so the same
    is_stream/1 clause planned differently run to run. Declaring '$rec'/3 dynamic shifted one allocation and exposed it.
    Fix: pl_runtime_define_pred_x calls fc_tables_reset() beside zls_reset() (the pattern/SNOBOL4 runtime paths already did).
  - only_tree_t gate: my non-callable-body check crossed parser->lower; replaced by a local checker in the parser.
- Witnesses (100 scratch programs) dev4 vs land: 79 same, 21 differ -- all fixes (match swipl, or error-context only).
