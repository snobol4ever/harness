#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_instr_budget.sh -- INSTRUCTION-COUNT REGRESSION GATE, queue row `instr-budget-gate` (rank 3, PERF INFRASTRUCTURE).
#
# WHY THIS GATE EXISTS (HQ s251, ARCH-PERF-TOOLING.md §5).  Wall clock on this Zen 4 mobile part is noisy
# (beauty measured +-8% run to run even with governor=performance) but callgrind's Ir total is EXACT and
# reproducible to the instruction.  Pinning Ir for two workloads with a tolerance band turns a silent 5%
# instruction-count regression into an immediate gate failure instead of something found three weeks later
# under other drift.  s249 named the idiom "arith loop instruction budget" -- this gate generalises it.
#
# WORKLOADS.  (1) roman -- corpus/demos/snobol4/roman/roman.sno, fully self-contained (no external input
# file) -- DEFINE/recursion/REPLACE over ~345 roman-numeral conversions, chosen because it is RUNTIME-C-
# dominated (pattern REPLACE + string building through libscrip_rt.so), the counterpart of the compiler-
# emitted-dominated arith_loop s249 already budgets.  ⛔ porter.sno was the original choice but CANNOT BE
# BUILT in m4 at all -- duplicate assembler symbol .Lx865_40, a label-minting collision already filed as
# queue row `porter-m4-duplicate-label` (rank 1; not this row's problem, and NOT a reason to hand-encode
# around the emitter).  treebank-match / claws5-match were also tried and rejected: their "matched bytes=N"
# .ref values are stale false-green oracles from the TT_VLIST-not-lowered defect (queue row
# `vlist-expr-alternation`) -- today's CORRECT output legitimately diverges from those pinned .ref files, which
# would make this gate's correctness pre-check permanently red for the wrong reason.  Reconsider the workload
# once either queued row lands (porter is the better fit long-term per ARCH-PERF-TOOLING.md's own "table path
# is 91%" framing). (2) beauty self-host -- the MILESTONE-1 fixed point, beauty.sno < beauty.sno.  Both are
# gated on CORRECTNESS FIRST (roman vs its .ref, beauty vs the fixed-point identity) so a silently truncated or
# early-erroring run can never masquerade as "instructions went down" (ARCH-PERF-TOOLING.md §7: "optimizing
# against a false measurement is worse than not optimizing" applies equally to a false-green instruction count
# here).
#
# TOLERANCE.  A one-sided budget with a +-TOL_PCT% band: FAIL only above watermark*(1+TOL_PCT/100), which is
# the actual regression this gate exists to catch.  Below watermark*(1-TOL_PCT/100) is reported, not failed --
# failing on an instruction-count IMPROVEMENT would fight the entire ARCH-PERF-TOOLING campaign this row serves.
#
# RT_OPT.  Pinned watermarks below are RT_OPT=-O0 (O0-DEV-O2-BENCH: the default for all normal development),
# measured 2026-08-22 on a `make pristine` build (HQ-27; PRISTINE_RC=0, scrip + out/libscrip_rt.so both fresh,
# rebuilt AFTER rebasing onto SCRIP `cd13321e` -- the prior measurement at `2659558e` was re-proven stale by
# that rebase per RULES.md "re-prove your gate after a rebase" and re-measured, not assumed: roman +0.56%
# (concurrent template churn), beauty -4.49% (a real win from the concurrent free-r10/free-r11 campaign).
# This gate measures whichever out/libscrip_rt.so is already built; it does not itself rebuild the runtime.
#
# TABLE_ACCESS / ARRAY_SUM (added 2026-08-24, seat04, row `perf-table-array-runtime` NEXT step -- see
# FINDING-2026-08-24-seat04-post-fix-table-array-callgrind-remeasurement.md; TABLE_ACCESS_IR_WATERMARK
# RE-PINNED same day by seat01, row `perf-table-subscript-fastpath`, after RTX-31 (rtx_icnsub.s) +
# RTX-NEW-ICNVAR (rtx_icnvar.s) closed two dead asm-fast-path gaps for SNOBOL4 table subscript/assign --
# see FINDING-2026-08-24-seat01-table-subscript-fastpath-rtx31-icnvar-table-store.md.  ARRAY_SUM_IR_WATERMARK
# untouched: confirmed OK (not NOTE) post-fix, those arms never touch the DT_A array path.  Both are run STANDALONE
# (no bench_wrap.sh fixed-iter twin, no fixed_n) exactly like roman/beauty above: table_access.sno's own
# MAIN calls TABLE_ACCESS(1) then TABLE_ACCESS(20) and array_sum.sno's calls ARRAY_SUM(1) then (20) --
# 21 total outer builds each, small and fast, each with a real .ref from the s265 standalone revamp.
# ⛔ THIS IS NOT THE SAME MEASUREMENT AS THE FINDING'S SPITBOL-RATIO NUMBERS.  That FINDING used
# bench_wrap.sh --mode=iter at N=2,000/100/8,192 to get a large, statistically stable Ir/iter figure
# comparable against SPITBOL.  This gate has a different job -- catch a REGRESSION against SCRIP's OWN
# prior instruction count, same shape as roman/beauty above -- so it uses the smaller un-wrapped
# standalone run, same as they do, and never compares across engines.  Watermarks below are RT_OPT=-O0,
# `make pristine` at SCRIP `eca52780`, mode-4, plain `valgrind --tool=callgrind` (no --smc-check flag,
# matching this gate's own measure_ir, not profile_callgrind.sh's pattern-blob flag).
#
# PROVING THE FAIL PATH (recorded once, not re-run every invocation -- 2026-08-22, this pristine build).
# ROMAN_IR_WATERMARK=1000000 bash ../harness/scripts/test_gate_instr_budget.sh negative-tests the budget arithmetic by
# injection (the established idiom for this codebase's gates -- see e.g. test_gate_argnote_sweep.sh's
# off-limits-count injection): roman still matches its .ref (correctness untouched), beauty stays within its
# real budget, and the script correctly reports "FAIL roman: Ir=... > budget 1000000 ... REGRESSION" and exits
# 1 -- proving check_budget's comparison, not faking the exit code.
# ⛔ THREE ORGANIC LEVERS WERE TRIED FIRST AND ALL THREE BROKE SOMETHING ELSE INSTEAD OF CLEANLY INFLATING Ir,
# each a real, separate, PRE-EXISTING instability outside this row's scope (flagged to HQ, not fixed here):
# SCRIP_OPT=0 -- undefined `*_define_β`/`*_goto_deferred_β` symbols at LINK time on BOTH roman and beauty (the
# optimizer is apparently load-bearing for DEFINE-related label resolution, not just a speed lever);
# --zeta-storage=cell-heap -- roman SIGSEGVs at runtime; --zeta-storage=frame-rsp -- beauty aborts
# ("IR_MATCH_CAPTURE_SAVE: no home ... classifier and ZD plan disagree"). Only the compiled default
# (optimizer on, cell-stack) is solid across both workloads today.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -u
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
CORPUS_ROOT="${CORPUS:-$S4E/corpus}"
# ⛔ demo/ -> demos/ (corpus re-grid). Dead since the rename; this gate refused correctly and named
# the exact missing file ("scrip: cannot open .../corpus/demo/snobol4/roman/roman.sno"), which is why it
# cost minutes rather than months -- unlike its two neighbours, which went green instead.
DEMO="$CORPUS_ROOT/demos/snobol4"
BEAUTY_DIR="$CORPUS_ROOT/demos/snobol4/beauty"
BENCH="$CORPUS_ROOT/benchmarks/snobol4"

TOL_PCT="${TOL_PCT:-2}"
# ⭐ ROMAN RE-PINNED 2026-08-24 hq_P s272: 22522863 -> 10224491, RT_OPT=-O0, `make pristine`, SCRIP `1177e66e`, mode-4, correctness OK
# against roman.ref.  That is 2.20x on the faster axis (watermark/measured) and it is NOT one commit: it is the s262-s264 roman
# campaign, unpinned for two days.  Bisected ladder, EVERY ARM RE-MEASURED AT -O0 BY THIS GATE'S OWN measure_ir -- the commit
# messages below quote their own -O2 figures, which is why the ladder had to be re-walked rather than summed from them
# (RULES.md: a number carried into a new column must be re-measured, not copied):
#   cd13321e 22,521,791  the old watermark tree -- reproduces the pinned 22,522,863 to 0.005%, so the pin itself was sound
#   646b8047 23,073,347  +2.45% ABOVE the pin -- a real small regression, never chased, swamped by what follows (see FINDING)
#   6c3f081c 23,070,607
#   db8f96d6 19,790,962  -14.2%  NV_* vrblk memo, ordinary-variable fast path   [runtime only: emitted .s md5 unchanged]
#   97ef3c3a 19,380,226  -2.1%   first-char guard on the FAIL strcmp, defer path
#   454b5190 17,012,452  -12.2%  one name resolution per deferred node instead of two
#   f8081604 15,283,650  -10.2%  drop the unobservable dfx frame on the merged defer path
#   3342581a 10,238,326  -33.0%  COMPOUND of ~6 named roman wins in a82768c2..3342581a (84aaef7e -26.7%, a16598a2 -13.2%,
#                                e3951bae -10.4%, cb743fe9 -6.7%, 69030b07 -6.3%, 083d106f -5.6%) -- the s262 ladder proper
#   eca52780 10,217,267  flat    (seat04 measured table/array here and correctly left roman alone: not their row)
#   1177e66e 10,224,491  flat    the pin -- emitted .s BYTE-IDENTICAL to eca52780 (md5 ac1f4619), so today's cures moved nothing here
#   22971235 10,224,807  +0.003% RE-PROVEN after rebasing onto seat01's RTX-31/RTX-NEW-ICNVAR runtime work (rtx_icnsub.s,
#                                rtx_icnvar.s).  A rebase is a NEW TREE and its gate must be re-proven, not assumed: those
#                                are table-subscript fast paths and roman touches none of them, but that was MEASURED, not argued.
# ⛔ FIXED WORK VERIFIED BEFORE BELIEVING ANY OF IT: demo/snobol4/roman/roman.sno is unchanged since 2026-08-18 and roman.ref since April
# (345 conversions); only path moves touched either.  A shrunken workload is the way this measurement lies, and it did not.
# ⭐ Independently cross-checked the same day (seat06, queue row `defer-nv-read-by-pointer-not-name`): 10225516/10224807/10224052
# across three separate make-pristine measurements at nearby commits, converging on this same number within noise -- two
# independent methodologies (this ladder; seat06's --separate-callers=2 profile showing NV_GET_fn'rt_defer_nv_read gone from
# the hot-line list) agree.  Receipts: FINDING-2026-08-24-seat06-defer-nv-read-by-pointer-already-landed-repin.md.
# Watermarks: RT_OPT=-O0, measured on a `make pristine` build.  Re-pin with the FINDING that changed them.
# ⭐⭐ RE-PINNED 2026-08-30 hq_P (hq_B routed it after repointing this gate's dead corpus path, SCRIP 3fa3f557 —
# it had been REFUSING rc=2 for the demo/ -> demos/ re-grid while two neighbouring gates hit the same missing
# directory and went GREEN instead). Three watermarks were stale LOW and could not detect a regression short of
# catastrophe — green by construction, which is the vacuous-gate shape with a number instead of a hash:
#     roman         10224491 -> 8225814
#     table_access  11879659 -> 10249870
#     array_sum     10912565 -> 9287873
# Measured RT_OPT=-O0, mode-4, `make` at SCRIP a9defbae, all three correctness arms OK, TOL_PCT=2%.
# ⭐ DETERMINISM CHARACTERISED, NOT ASSUMED (hq_B raised machine load as a caveat and left the judgment here).
# LOAD-INSENSITIVE: four runs at load 7.29/16 gave byte-identical Ir for all four programs, and three of the
# four sat within 0.015% of hq_B's independent run on a different tree. Ir is an instruction count, so load
# cannot move it — confirmed rather than asserted.
# ⛔ BUT IT IS ENVIRONMENT-SIZE SENSITIVE, and I nearly published "byte-identical" before noticing: a run with
# ONE extra environment variable set reads roman at 8228588 instead of 8225814 (+2774, +0.034%), and lengthening
# that variable's VALUE moves it again (8228592). Measured deliberately once the negative-test run — which sets
# ROMAN_IR_WATERMARK in the env — came back 987 higher than the four clean runs. Same env-size sensitivity this
# project already documented for the Defect C witnesses; the stack shifts, the instruction count follows.
# ✅ CONSEQUENCE FOR THESE PINS: 0.034% against TOL_PCT=2% is two orders of magnitude inside tolerance, so the
# watermarks are safe to pin and safe to check from a different shell. ⛔ But do NOT chase a few-thousand-Ir
# "regression" between environments, and do not tighten TOL_PCT toward 0.1% without re-measuring this spread —
# a tolerance below the environment noise floor turns this gate into a flake.
# ⛔⛔ BEAUTY IS DELIBERATELY *NOT* RE-PINNED, AND ITS BUDGET IS NOT STALE — THE MEASUREMENT IS BROKEN.
# The arm fails its own precondition: `beauty.sno < beauty.sno` no longer reaches the Milestone-1 fixed point.
# It emits "Parse Error" at line 8 and produces 10 lines against beauty.sno's 618, dying at the -INCLUDE block.
# So Ir=299,962,038 is the cost of a program that stops after ten lines, not a 6x improvement over 1,897,159,187.
# ⛔ Re-pinning it down would freeze a BROKEN program's cost as the target, and the eventual real FIX would then
# read as a ~6x REGRESSION and fail this gate. The budget stays where it is until the fixed point is restored;
# the arm's own FAIL line is the correct signal in the meantime. Routed as its own finding.
# ⛔⭐ ALL FOUR WATERMARKS REBASED 2026-10-02 (the coo, on the ceo's ask; row instruments-test-gate-instr-budget-watermarks-are-
# stale-...): measured RT_OPT=-O0, mode-4, `make` at SCRIP 496798c3b, corpus 3e9976d2b, all four correctness arms OK, one run
# (Ir is an instruction count: load cannot move it, see DETERMINISM above). The gate is wired into no recipe; it read FAIL on
# every tree since some landing nobody re-based for (CEO-803), which taught readers to ignore it. Each move, with its cause:
#     roman          8225814 -> 12872014  (+56.5%)  SAME PROGRAM (roman.sno unchanged since the pin but for the 08-29 demos rename):
#                    a real compiler/runtime cost accrued since the a9defbae-era pin, NOT ATTRIBUTED here -- reported to the
#                    ceo, who holds the speed concern. The new pin is a fresh basis so the NEXT regression reds; it blesses nothing.
#     beauty      1897159187 -> 1430567872  (-24.6%)  SAME beauty.sno and still the FIXED POINT; the drop is unattributed
#                    (compiler, runtime or its -INCLUDE set) -- quote it as no win until decomposed the way hq_P did on 08-24.
#     table_access  10249870 -> 15480433  (+51.0%)  DIFFERENT PROGRAM: the kernel was rewritten (corpus 723e5aa08, cb366317c,
#     array_sum      9287873 ->  8989531   (-3.2%)  2026-09-24/25, simple snippets with no TABLE_ACCESS(1)/(20) MAIN), so neither
#                    delta is a compiler reading and no comparison across this line may be made.
ROMAN_IR_WATERMARK="${ROMAN_IR_WATERMARK:-12872014}"
# ⛔⭐ BEAUTY RE-PINNED 2026-08-24 hq_P s272 as a WORKLOAD REBASE, NOT A WIN: 2,215,545,392 -> 1,897,159,187 (SCRIP `22971235`).
# The gate reported -14.4% "improved; consider re-pinning down" and that invitation was a TRAP: beauty.sno was HAND-EDITED by
# Lon the same day (corpus b131a913d, the DECLARED_CONSTANT beauty.sno deleted; then e63689fae, Lon's 4-line edit), 630 -> 618
# lines with 266 lines changed.  The watermark had outlived the program it measured, so pinning the new number as an
# improvement would have credited a hand edit as a 14.4% compiler win.  DECOMPOSED INSTEAD, by re-measuring the PIN-ERA
# beauty.sno (corpus 8e309aa4, with its own .inc set) on TODAY's compiler -- the only apples-to-apples arm available:
#   2,215,545,392  pin-era program, pin-era compiler   (the 2026-08-22 pin)
#   2,185,743,429  pin-era program, TODAY's compiler   -> -1.35%  <- THE ONLY REAL COMPILER DELTA, and it is still a FIXED POINT
#   1,897,159,187  new program, today's compiler       -> -13.2% of the drop is the EDITED WORKLOAD, not the compiler
# ⭐ CLEAN A/B OF THE TWO BEAUTY FORMS (ceo s271 task 1), ONE TREE, ONE SITTING, one pristine -O0 build at SCRIP `22971235`
# with NO src change between arms -- ceo's own two runs were hours apart with script commits between them, so this re-runs
# it properly rather than quoting across trees.  All three arms VERIFIED SELF-HOST FIXED POINTS:
#   2,185,743,429  DECLARED_CONSTANT form, 630 lines  (corpus 8e309aa4)
#   1,888,454,918  classic frozen,         622 lines  (corpus 1ce15a5ac, the pre-BEAUTY-CN snapshot)
#   1,897,159,187  classic + Lon's 4-line edit, 618 lines  (corpus e63689fae -- what ships, and what is pinned above)
# ⭐ THE MULTIPLE, on the faster axis, reference = the constants form: classic is 1.16x.  Stated as percentages with the
# basis NAMED, because a percent without its basis is the trap: the constants form spends +15.7% MORE instructions than
# classic (percent OF classic); equivalently classic spends -13.6% (percent OF the constants total).  ceo measured 1.15x
# / ~13% hours apart across trees -- independent agreement to 0.2%, so that reading was sound and is now tight.
# ⛔ LON'S 4-LINE EDIT IS NOT RESOLVABLE BY THIS INSTRUMENT: +0.46% against a workload whose own run-to-run jitter is
# ~0.4% (three runs: 1,890,181,588 / 1,897,159,187 / 1,898,412,363).  It sits AT the noise floor -- do not quote it as a cost.
# ⛔ So the honest reading of a -14.4% NOTE here was: -1.35% earned, -13.2% is a different program.  The new pin is a fresh
# basis, and NO cross-workload comparison may be made against the old one (RULES.md: a SLOPE is not a TOTAL; a number carried
# into a new column must be re-measured).  Beauty remains the Milestone-1 self-host fixed point under the new source.
# ⛔⭐ BEAUTY RE-PINNED 2026-10-11 by the ceo (row snobol4-the-instruction-budget-gate-reads-beauty-at-1622m-ir-...-ceo-1637; GOAL-CEO.md CEO-1640): 1,430,567,872 -> 1,626,072,751 (SCRIP `3cb3126a5`, HEAD
# `7cf8878ba` whose only difference is the generated allocating table), THE PRICE OF ONE RULED FEATURE, NAMED, not a workload change (beauty.sno unchanged since corpus 924bd8bd0, 618 lines,
# every arm below a verified fixed point).  BISECTED from the pin tree with this gate's own measure_ir in a scratch worktree (callgrind, -O0, mode 4), the staircase, each step a
# parent -> child pair unless noted:
#   1,430,285,467  496798c3b  the pin tree re-measured: reproduces the pin to 0.02%, so the pin was sound
#   1,448,889,372  974557f25  the parent of the step below (+1.3% over 10-02..10-05: under the band)
#   1,619,272,123  6ec5871c8  gc: the chain over the maps, STEP A (ARCH-GC s13, CEO-1492) -- +170,382,751, +11.76%, THE WHOLE RED: the runtime emitter (beauty resolves deferred expressions
#                             at run time, rt_defer_resolve 491,254 calls, bb_emit_x86 4,211) scans every box twice for the per-site tables and re-asks frame membership per instruction
#                             (xop_frame_member 9,365 -> 89,717 calls, zd_k 14,164 -> 95,481, zdp_scratch_cell 16,380 -> 204,922) with linear scans over its rsp snapshot vectors (+37M in
#                             std::vector<x86_rsp_snap_t> iteration alone).  The site tables are the ruled design; the dry-run scan, the re-classification and the linear scans are the
#                             cto's row gc-the-emitters-rsp-prepass-of-the-chain-over-the-maps-step-a-costs-beauty-170m-ir-...-ceo-1639 (DONE-WHEN: this gate with BEAUTY_IR_WATERMARK=1448889372).
#                             When it lands this gate reads "improved; consider re-pinning down" and the owner re-pins to the reading, naming the cure.
#   1,633,132,812  e3421a999  10-07, the peak measured
#   1,502,416,860 -> 1,501,577,470  ea03e8627 -> dc6654135  the ACCESS trace callback road: -0.06%, neutral
#   1,567,768,103 -> 1,516,094,868  badc713de -> 2356c4868  the C name-save stack deleted (CEO-1542): -51,673,235, -3.3%, a win kept
#   1,560,638,441  dbd4b7cf1  10-10 18:46, the cto's reading reproduced
#   1,621,141,491 -> 1,621,212,235  302521554 -> 7210bcef1  the KEYWORD trace road (CEO-1635): +71K, 0.004%
#   1,620,291,817 -> 1,624,407,409  1ba942a4a -> 4030b0d03  the VALUE trace inside a match (CEO-1636): +4.1M, +0.25%, of which +2.9M is strcmp in the variable hash walk (layout) and
#                             +0.7M the NV_SET_fn -> NV_SET_p_fn wrapper layer; no capture, cursor or pump probe shows in the per-function diff (beauty runs no cursor assignment)
#   1,624,515,945 -> 1,626,072,751  666108ad4 -> 3cb3126a5  the DATA TWEAK hook road (CEO-1638): +1.56M, +0.10%
# Two readings of one tree differ by up to 0.14% (6ec5871c8 twice: 1,618,721,415 / 1,619,272,123; 4030b0d03 by this gate 1,622,070,134, by the worktree 1,624,407,409), inside the band.
# ⛔⭐ BEAUTY RE-PINNED DOWN 2026-10-11 by the cto, the owner the block above names (row gc-the-emitters-rsp-prepass-of-the-chain-over-the-maps-step-a-costs-beauty-170m-ir-...-ceo-1639):
# 1,626,072,751 -> 1,466,981,489, this gate's own reading of the cure over 299e125f8 (fixed point kept, beauty.s byte-identical to its base at every step, 465 of 518 programs across every
# language byte-identical and the other 53 refused alike by both trees). THE CURE, five steps on the runtime emitter, each a callgrind reading of beauty fed its own source:
#   1,624,099,019  56c4ad49a  the base re-measured
#   1,556,750,617  step 1     the rsp snapshot scans read raw pointers and the dry-run commit restores its state without copying it (x86_rsp_pre_t)
#   1,491,181,143  step 2     frame_slot_scan reads a per-graph memo of each node's frame-slot candidacy and units, validated once per scan
#   1,480,814,759  step 2b    frame_slot_scan answers from per-graph prefix sums of slot units and the query's index through xci_probe
#   1,476,537,849  step 3     the dry-run commit copies only the jumps added since the last commit; the real pass holds one reference to the rsp state
#   1,466,644,494  step 4     the snapshot scans walk backward by pointer comparing the key first (each kind and key is unique in its list), a define scans only when not aligned
# TRIED AND REVERTED: an open-addressing index over the snapshot vectors read 3.9M WORSE at -O0 (the per-graph lists are short; the hashing's calls cost more than the walks).
# The remaining ~18M over the 974557f25 parent (1,448,889,372) is the site tables themselves, the ruled design.
BEAUTY_IR_WATERMARK="${BEAUTY_IR_WATERMARK:-1466981489}"
# Watermarks: RT_OPT=-O0, `make pristine`, SCRIP `eca52780`, 2026-08-24 (seat04).  Re-pin with the FINDING that changed them.
# TABLE_ACCESS re-pinned 2026-08-24 (seat01, post RTX-31 + RTX-NEW-ICNVAR): 15267937 -> 12986443.
# TABLE_ACCESS re-pinned 2026-08-27 (seat12, row perf-table-subscript-fastpath lever 2, post subscript+assign fusion
# for T[I]=v -- bb_assign_var_sub.cpp/c_rt_table_assign_fast): 12986443 -> 11879659.  Reproduced twice, identical.
TABLE_ACCESS_IR_WATERMARK="${TABLE_ACCESS_IR_WATERMARK:-15480433}"
ARRAY_SUM_IR_WATERMARK="${ARRAY_SUM_IR_WATERMARK:-8989531}"

[ -x "$SCRIP_BIN" ] || { echo "GATE FAIL(2): scrip not built at $SCRIP_BIN"; exit 2; }
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "GATE FAIL(2): libscrip_rt.so not built at $RT_DIR"; exit 2; }
command -v valgrind >/dev/null 2>&1 || { echo "GATE FAIL(2): valgrind not installed"; exit 2; }
. "$(dirname "${BASH_SOURCE[0]}")/lib_ir_measure.sh" 2>/dev/null || { echo "GATE FAIL(2): cannot load lib_ir_measure.sh -- this gate will not read Ir by hand"; exit 2; }
[ "$ROMAN_IR_WATERMARK" -gt 0 ] && [ "$BEAUTY_IR_WATERMARK" -gt 0 ] && [ "$TABLE_ACCESS_IR_WATERMARK" -gt 0 ] && [ "$ARRAY_SUM_IR_WATERMARK" -gt 0 ] || { echo "GATE FAIL(2): watermark(s) not pinned yet"; exit 2; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
FAIL=0

measure_ir() {  # name sno input cwd_or_empty  -> sets IR_TOTAL, RUN_OUT on success (rc 0)
    local name="$1" sno="$2" input="$3" cwd="$4"
    local s="$WORK/$name.s" bin="$WORK/$name.bin" cg="$WORK/$name.cg.out"
    if [ -n "$cwd" ]; then ( cd "$cwd" && timeout -k 5 120 "$SCRIP_BIN" --compile --out="$s" "$sno" ) >"$WORK/$name.cc.err" 2>&1
    else timeout -k 5 120 "$SCRIP_BIN" --compile --out="$s" "$sno" >"$WORK/$name.cc.err" 2>&1; fi
    if [ ! -s "$s" ]; then echo "GATE FAIL(2): $name mode-4 compile produced nothing"; sed 's/^/    /' "$WORK/$name.cc.err"; return 1; fi
    gcc -no-pie "$s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$bin" 2>"$WORK/$name.ld.err"
    if [ ! -x "$bin" ]; then echo "GATE FAIL(2): $name mode-4 link failed"; sed 's/^/    /' "$WORK/$name.ld.err"; return 1; fi
    # ⛔⭐ A DEAD RUN'S Ir READS AS AN IMPROVEMENT HERE, WHICH IS THE WORST DIRECTION FOR THIS GATE TO FAIL
    # IN.  callgrind prints a well-formed PROGRAM TOTALS whatever the client does, and a program that dies
    # early does LESS work -- so an uncaught SEGV arrives as a number BELOW the watermark and check_budget
    # prints "improved; consider re-pinning down".  The crash would have argued for lowering the budget it
    # broke.  ⭐ So the exit status decides whether a reading exists at all, before any grading touches it.
    # The rule and its wording live in lib_ir_measure.sh -- the ONE authority for taking an Ir reading.
    local irv; irv="$(IR_PROG_OUT="$WORK/$name.out" IR_PROG_ERR="$WORK/$name.vg.err" ir_measure "$bin" < "$input")"
    RUN_OUT="$WORK/$name.out"
    if ! ir_is_number "$irv"; then echo "GATE UNPROVEN(2) [$name]: $(ir_cell "$irv") -- $(ir_reason "$irv")"; IR_TOTAL=""; return 1; fi
    IR_TOTAL="$irv"
    [ "$IR_TOTAL" -gt 0 ] 2>/dev/null
}

check_budget() {  # label ir watermark
    local label="$1" ir="$2" wm="$3" hi lo
    hi=$(( wm * (100 + TOL_PCT) / 100 )); lo=$(( wm * (100 - TOL_PCT) / 100 ))
    if [ "$ir" -gt "$hi" ]; then
        echo "FAIL $label: Ir=$ir > budget $wm (+${TOL_PCT}% = $hi) -- REGRESSION"; FAIL=1
    elif [ "$ir" -lt "$lo" ]; then
        echo "NOTE $label: Ir=$ir < budget $wm (-${TOL_PCT}% = $lo) -- improved; consider re-pinning down"
    else
        echo "OK   $label: Ir=$ir within budget $wm +-${TOL_PCT}% [$lo,$hi]"
    fi
}

echo "=== instr-budget-gate: RT_OPT=-O0 pinned watermarks, TOL_PCT=${TOL_PCT}% ==="

if measure_ir roman "$DEMO/roman/roman.sno" /dev/null ""; then
    roman_ir="$IR_TOTAL"
    if diff -q "$RUN_OUT" "$DEMO/roman/roman.ref" >/dev/null 2>&1; then
        echo "OK   roman: output matches roman.ref"
    else
        echo "FAIL roman: output DIFFERS from roman.ref -- Ir count below is not trustworthy"; FAIL=1
    fi
    check_budget roman "$roman_ir" "$ROMAN_IR_WATERMARK"
else
    echo "GATE FAIL(2): roman measurement did not produce an Ir count"; exit 2
fi

if measure_ir beauty "$BEAUTY_DIR/beauty.sno" "$BEAUTY_DIR/beauty.sno" "$BEAUTY_DIR"; then
    beauty_ir="$IR_TOTAL"
    if cmp -s "$RUN_OUT" "$BEAUTY_DIR/beauty.sno"; then
        echo "OK   beauty: output is the FIXED POINT (byte-identical to beauty.sno)"
    else
        echo "FAIL beauty: output is NOT the fixed point -- Ir count below is not trustworthy"; FAIL=1
    fi
    check_budget beauty "$beauty_ir" "$BEAUTY_IR_WATERMARK"
else
    echo "GATE FAIL(2): beauty measurement did not produce an Ir count"; exit 2
fi

if measure_ir table_access "$BENCH/table_access.sno" /dev/null ""; then
    table_access_ir="$IR_TOTAL"
    if diff -q "$RUN_OUT" "$BENCH/table_access.ref" >/dev/null 2>&1; then
        echo "OK   table_access: output matches table_access.ref"
    else
        echo "FAIL table_access: output DIFFERS from table_access.ref -- Ir count below is not trustworthy"; FAIL=1
    fi
    check_budget table_access "$table_access_ir" "$TABLE_ACCESS_IR_WATERMARK"
else
    echo "GATE FAIL(2): table_access measurement did not produce an Ir count"; exit 2
fi

if measure_ir array_sum "$BENCH/array_sum.sno" /dev/null ""; then
    array_sum_ir="$IR_TOTAL"
    if diff -q "$RUN_OUT" "$BENCH/array_sum.ref" >/dev/null 2>&1; then
        echo "OK   array_sum: output matches array_sum.ref"
    else
        echo "FAIL array_sum: output DIFFERS from array_sum.ref -- Ir count below is not trustworthy"; FAIL=1
    fi
    check_budget array_sum "$array_sum_ir" "$ARRAY_SUM_IR_WATERMARK"
else
    echo "GATE FAIL(2): array_sum measurement did not produce an Ir count"; exit 2
fi

if [ "$FAIL" -ne 0 ]; then
    echo "GATE FAIL: instruction budget exceeded or a correctness check failed."
    exit 1
fi
echo "GATE OK: all four workloads within their pinned instruction budget."
exit 0
