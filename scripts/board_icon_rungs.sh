#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "$(one_runner_population_of "$@")" || exit 2
# board_icon_rungs.sh — THE SET-LEVEL BOARD OVER corpus/tests/icon/ALL.icn (row icon-all-master-board).
# Authors: LCherryholmes · Claude Opus 5   DATE: 2026-08-30
#
# ⛔⭐⭐ WHY THIS EXISTS: UNTIL TODAY, ICON'S COVERAGE SAFETY RESTED ON A NAMING CONVENTION.
# `test_icon_all_rungs.sh` and its kin grade the rungs suite FAMILY BY FAMILY, by name (`SUITE
# rung30_builtins_misc: pass=5`, ...). That covers whatever families those scripts happen to name —
# and NOTHING checks that the named families still add up to the whole set. An entry whose family is
# renamed, or a family nobody re-points a grader at, simply stops being graded, and every board stays
# green because no board ever knew the denominator. MEASURED at mint: ALL.csv carries **534** entries;
# the aggregate rung grader names a strict subset. That gap is the same absorbed-population class that
# hid NINE gradings in the Prolog rungs and 143 more behind rc=2 refusals — this board closes the door
# on the Icon side by grading the SET and printing its own denominator.
#
# ⛔ THIS IS A WATERMARK CENSUS BOARD, NOT A FAIL=0 GATE, AND THAT IS DELIBERATE.
# MEASURED at mint (pristine -O0, both modes): total=534 · m3 pass=393 fail=122 crash=16 hang=2 ·
# m4 pass=393 fail=122 crash=1 hang=2 skip=15.  RE-PINNED the same day to m3/m4 pass=398 (fail=120,
# m3 crash=13, m4 skip=12) after Icon cures landed from other seats -- and the re-pin happened because
# THIS BOARD'S OWN "WATERMARK MOVED UP" ARM SAID SO on the first re-run against a moved tree, which is
# the arm earning its keep on day one. Icon is nowhere near green on the whole set, so a
# FAIL=0 bar here would be a gate nobody can satisfy — and hq_P's standing ruling on exactly that
# shape (the RETIRED optbypass watermark gate; lesson kept in .github/GOAL-TEST-SUITE-CONSISTENCY.md
# ignored gate is worse than no gate. So the verdict is a RATCHET: red only if the graded population
# SHRINKS or the pass counts REGRESS below the pinned watermark. Curing Icon is not this board's job;
# noticing that it moved is.
#
# ⛔ NOT WIRED INTO THE BLOCKING SET. `make test`'s membership is a ruling, not a script's to take —
# and a board that is red-by-construction must never be made blocking. Routed to ceo at mint.
#
# ⭐ FLOOR, NOT A PINNED TOTAL (RULES.md § the denominator law): growth needs no re-pin; only an
# ATTRIBUTED retirement may lower these, in the same commit that shrinks the rungs.
#
# ⛔⭐ THE AST-SHAPE COUNT IS INFORMATIONAL ONLY, NEVER A GATE (ast-dump-refs-are-self-pins-not-
# oracles, 2026-09-05): the parser-ladder fixtures' .ref is SCRIP's own past self-dumped AST, pinned
# against no external oracle -- no oracle emits SCRIP's AST shape, so that count can only ever answer
# "did the shape change since it was last decided", never "is it right". This board used to let that
# count set RED and feed a pass/fail floor on this SCORED board, which manufactures phantom defects
# out of drift the moment someone re-decides the shape. It is still measured and printed every run
# (Icon's parser-ladder population is NOT left ungated) but it no longer participates in this board's
# verdict, its floor, or the leaderboard's pass/fail framing -- a mismatch here means RE-DECIDE THE
# SHAPE AND REGENERATE the ref, never "N programs FAIL".
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ⛔⭐ RECORD THE TREE THIS RUN GRADES, AT ITS START (hq_T 2026-09-08). A board takes ten to forty minutes and its
# SCORE.md write happens at the END; a seat who commits and pushes mid-run -- which the CEO-174 dirty-tree guard
# actively pushes you toward, since a dirty tree skips the write entirely -- moves HEAD under a measurement that
# already happened, and the row then names a tree carrying commits it never ran. Measured three times in one
# sitting, twice while doing the disciplined thing. util_score_row.py stamps this instead of HEAD, and says so
# when the two differ; unset, it behaves exactly as it always did.
# ⛔ THE HAND-SPELLED export S4E_TREE_AT_START THAT STOOD HERE IS RETIRED ONTO gate_tree_watch (coo
# 2026-09-10, COO-54). It was written out in THREE runners and ABSENT from the three Icon package
# boards the one runner runs every hour, so three of four boards stamped HEAD AT WRITE TIME -- which is
# CEO-524 (1)'s defect in its second form. One spelling, in lib_gate.sh, set by the same call that takes
# the baseline: a board cannot now acquire the stamp without also acquiring the refusal.
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
HARNESS="$HERE/corpus_suite_harness.py"
RUNGS_ICN="$CORPUS/ALL.icn"
RUNGS_REF="$CORPUS/ALL.ref"
RUNGS_CSV="$CORPUS/ALL.csv"
ENTRY_FLOOR="${ICON_RUNGS_ENTRY_FLOOR:-534}"
# ⛔⭐ THE PASS FLOORS ARE OVER THE RUN-GRADED POPULATION (381), NOT THE SUITE (534), and the old 398 is VOID.
# Until 2026-09-03 this board graded all 534 entries by RUNNING them, including the 153 parser-ladder fixtures
# whose .ref is a self-pinned AST-shape dump (SCRIP's own past output, see the AST-SHAPE note above) -- so its
# number mixed two populations graded against two different kinds
# of expected output and could not be read as anything. Re-pinned from the honest split measured on
# SCRIP 4f847224 / corpus 53477317: run-graded m3/m4 PASS=377 of 381, ast-graded PASS=153 of 153.
# ⭐ Note which way the old instrument moved when the corpus got BETTER: the ceo's re-cut of 30 stale AST pins
# (corpus 53477317) gave those fixtures correct dumps, which match RUN output even less, so the old board fell
# 398 -> 377. An instrument that gets worse as its subject improves is not miscalibrated, it is measuring
# something else.
# RE-PINNED 377 -> 379 (row icon-level-keyword-not-tracked, this same commit): &level's entry-side increment
# was landing but its &level READ (keywords.c) still returned the raw un-adjusted counter (g_kw_fnclevel's own
# "-1" convention never applied to Icon's "level" keyword string), and *&subject's word0 was a bare `mov`
# of the DT_S tag that clobbered slen along with it whenever built from the in-scan r13/r15 fast path
# (bb_keyword_icon.cpp) -- both cured this commit, procedure_alt_fail_replace_1 and procedure_scan_write_1
# move FAIL -> PASS in both modes; procedure_every_alt_replace_4 still shows &progname mismatch, which is
# the consolidation rename itself (correct compiler behavior), not a defect -- see the FINDING.
# ⭐ 380/381 (seat03, icon-master-six-run-graded-reds-cured, re-verified 2026-09-03): the rungs' last
# open "red" among the original six -- procedure_record_limit_replace_1 and procedure_record_every_replace_2
# -- were never compiler defects: both need companion fixture files (prepro.dat / fncs1.dat, staged from
# corpus/tests/icon/config/ by _copy_companions) that a bare `extract`+direct-invoke repro never supplies,
# so they read FAIL only when tested outside run_suite_entry's own methodology; under it (this board) both
# already PASS. The sixth, procedure_scan_while_1, WAS the rungs' one XFAIL (probe_witness__witness_icn_options_
# dash_branch): main(args) needed real argv, and corpus_suite_harness.py's suite format carries stdin/want-rc
# sidecars and NO argv sidecar. ⛔ RETIRED 2026-09-04 (hq_B, corpus 1520d35d1) under THERE IS NO XFAIL: the test
# was faulty FOR THIS HARNESS, so the test was fixed -- opt2(["-x"]) over a literal list, ref re-cut from icont,
# marker dropped, ALL.xfail deleted -- and the rungs reads XFAIL=0 with 596/596 both modes. A real argv-through-
# the-harness witness is still owed once the argv sidecar lands (hq_T's harness row); this comment is not it.
# ⭐ RE-PINNED 596 -> 607 (hq_B 2026-09-05 ~16:0x, MODE OCTET, on the ceo's order to re-pin the watermark).
# ⛔ THE ORDER SAID 601 AND 601 IS ALREADY STALE — pinned to the MEASURED number, not the relayed one.
# hq_P measured 601/601 both modes on SCRIP `7e190f16a`; corpus `bb5ee2b69` then minted the 8 declared-missing
# isolation-phase witnesses, so the run-graded population is 609, not 601. Measured here on SCRIP `b812fb6d1`
# corpus `8972babeb` RT_OPT=-O0, incremental make: entries=762 · m3 PASS=607 · m4 PASS=607 of 609.
# Pinning 601 would have sat SIX passes BELOW the tree and silently stopped protecting them — a watermark under
# the water is not a ratchet, and it fails in the direction nobody looks, because the board still prints OK.
# ⛔ THE TWO REDS ARE NAMED, NOT XFAILED (RULES.md § THERE IS NO XFAIL) and are NOT a regression: both are new
# entries (ALL.csv rows 761-762) minted by `bb5ee2b69` that have never passed —
# ladder_rung26_pow_pow_negbase_real and ladder_rung26_pow_pow_zero_negexp. They are open Icon defects to cure,
# which is why 607 and not 609: a floor is what today already holds, never what tomorrow owes.
# ⭐ RE-PINNED 607 -> 707 (cfo 2026-09-08 22:5x CDT, MODE NONET): board_icon_rungs.sh on SCRIP 259fddd68 + the three absorbed cfo witnesses (corpus, --absorb-only): entries=860 · m3 PASS=707 · m4 PASS=707 of 707, both modes, load 5.
# ⭐ RE-PINNED 707 -> 709 (hq_C 2026-09-09, CEO-445): the board asks for the re-pin in the commit that earned it. Measured on corpus af179eebd
# (the five Jcon A-I absorptions, of which rung36_jcon_image PASSES) plus the ladder-rung absorptions other seats landed in the same window:
# entries=879 · run-graded 726 · m3 PASS=709 · m4 PASS=709; per-entry identity 0 regressions / 0 vanished over 1557 examined.
# ⛔ THE DENOMINATOR MOVED 707 -> 726 IN THE SAME BREATH, so the floor rising by 2 while 17 reds appeared is NOT a contradiction: growth needs
# no re-pin (RULES.md § the denominator law) and the floor guards the PASS SET, never the fraction. Reading 709/726 as "worse than 707/707" is
# the error this comment exists to stop -- the earlier number was over a population that HELD ITS REDS OUT, which is what CEO-445 retired.
# ⚠ A CONCURRENT SEAT PINNED 708 IN THIS SAME MINUTE and it is superseded, not disagreed with: 708 and 709 are two honest measurements of a
# tree that grew between them. Kept the higher because a floor is a ratchet over the pass SET; if 709 ever reds, the entry that fell is the
# finding, not this pin.
# ⭐ RE-PINNED 708 -> 713 (cfo 2026-09-09 09:4x CDT, MODE NONET): board_icon_rungs.sh on the ilib cure (x <- e enters at α; case arms lowered onto their result) + hq_V's CEO-445 rungs in the denominator: entries=881 · m3 PASS=713 · m4 PASS=713 of 728, both modes, load ~5; the 13 FAIL + 2 CRASH are hq_V's rungs minted BEFORE their cures, by design.
# ⭐ 713 SUPERSEDES 709 THE SAME WAY 709 SUPERSEDED 708 (cfo, resolving the rebase at 09:5x): two honest measurements of a tree that grew between them; the floor is a ratchet over the pass SET and takes the later, higher run.
# ⭐ RE-PINNED 713 -> 714 (cfo 2026-09-09 09:5x CDT) on the REBASED tree: the ilib cure + f046ef00b (:=: against a static or global) measured together, entries=881 · m3 714 · m4 714 of 728; the 11 FAIL + 2 CRASH + 1 HANG are hq_V's pre-cure rungs and hq_C's three starved Jcon entries (the HANG is one of them waiting on the stdin it has no sidecar for).
# ⭐ RE-PINNED 714 -> 718 (hq_V 2026-09-09 10:39 CDT, MODE NONET) on SCRIP `f48a3f0c7` + corpus `23638085f`, the tree this seat's own landing made: the cfo's ilib rung-4 witness absorbed as rung21 (procedure_write_269, green both modes) plus the cures other seats landed in the same window. entries=885 · run-graded 732 · m3 PASS=718 · m4 PASS=718, both modes equal. ⚠ THE DENOMINATOR GREW 728 -> 732 IN THE SAME BREATH and growth needs no re-pin: the floor is a ratchet over the PASS SET, never the fraction.
# ⛔ TWO OF THE REMAINING 14 ARE GREEN THAT ASSERT NOTHING AND THE FLOOR CANNOT SEE IT: procedure_write_264 PASSES while five of its six oracle trace lines are absent, because lib_ladder.sh discards stderr -- FINDING-2026-09-09-hq_V-the-ladder-cannot-see-stderr-so-two-trace-rungs-grade-green-while-five-of-six-oracle-lines-are-missing.md. A watermark ratchets what is measured; it does not make an unmeasured line safe.
# ⭐ hq_I 2026-09-09 (CEO-452): at the rebase, the sort type-class comparator measured 720/732 both modes on SCRIP 1848637a7 +
# corpus a059b477d while hq_V measured 718 on f48a3f0c7 + 23638085f. ⛔ NEITHER READING DOMINATED -- 720 carried the comparator cure
# on an older tree, 718 a newer tree without it -- so the floor was LEFT AT 718 and the MERGED tree was measured afterwards rather
# than picking the bigger number. ⭐ RE-PINNED 718 -> 720 on that measurement: SCRIP 21fdd28f7 + corpus a059b477d, entries=885 ·
# run-graded 732 · m3 PASS=720 · m4 PASS=720, per-entry identity 0 regressions / 0 vanished over 1557 examined. ⭐ THE +2 IS THIS
# LANE'S AND THE ARITHMETIC SAYS SO RATHER THAN THE AUTHOR: hq_V's 718 came off this same merged tree WITHOUT the comparator, and with
# it the same tree reads 720 -- procedure_write_261 and procedure_write_263, both modes. That is also why the number went into a
# SECOND commit and not the cure's own: a floor written before the tree it guards exists is a guess wearing a measurement's clothes.
# ⭐ RE-PINNED 720 -> 738 (hq_V 2026-09-09 17:0x CDT, MODE NONET) on SCRIP `63efd8436` + corpus `ca2b8a110`, both on origin: entries=903 · run-graded 750 · m3 PASS=738 · m4 PASS=738, both modes equal, xfail=0 xpass=0.
# ⛔ MOST OF THE +18 OVER 720 IS NOT NEW CURING, IT IS A READING OF MINE BEING CORRECTED: hq_C's alt-bound cure `b3039f014` was already on origin when I measured the previous board, my build predated it by minutes, and the four entries I had recorded as red -- hq_C's eleven-shape probe and my three CEO-461 rungs -- are GREEN in both modes on the cured tree. The cell was RE-MEASURED, never annotated.
# ⭐ RE-PINNED 738 -> 739 (hq_I 2026-09-09, CEO-452 follow-on): sortf on a SET and on a RECORD, a defaulted/negative field index,
# and the field-tie order, all cut from icont. SCRIP 170baeda2 + corpus 36f9e9ea9, entries=904 · run-graded 751 · m3 PASS=739 ·
# m4 PASS=739; per-entry identity 0 regressions / 0 vanished over 1557 examined. ⛔⭐ WORTH THE LINE BECAUSE IT COST ME A FALSE RED:
# measured against hq_V's 738 on a tree whose CORPUS I had not pulled, this same binary read 721/732 and the board printed RED with
# two lines naming a regression below the watermark. NOTHING HAD REGRESSED -- 738 was measured over 750 run-graded entries and I was
# grading 732, so the ratchet compared a pass count against a floor from a LARGER POPULATION. A floor is a scalar and carries no
# denominator, so it cannot tell a stale corpus from a real regression, and it reads in the alarming direction. PULL EVERY REPO,
# THEN MEASURE: the board was green on the merged tree with no code change at all.
# ⭐ RE-PINNED 739 -> 740 (hq_I 2026-09-09, CEO-468): `f ! record` spreads the record's fields as arguments, as icont does, and a
# non-container raises 126. procedure_write_260 (ladder__rung24_records_apply_bang_spreads_the_fields) flips in both modes.
# entries=904 · run-graded 751 · m3 PASS=740 · m4 PASS=740; per-entry identity 0 regressions / 0 vanished over 1557 examined.
# ⭐ RE-PINNED 740 -> 742 (hq_R 2026-09-09, CEO-476): element generation over a SET concurrent with deletion no longer
# skips every second element -- `table_icn_nth` indexed the LIVE ordered vector, so `delete` compacted it under a cursor
# that had already advanced.  Flips procedure_write_258 and procedure_every_elemgen_replace_9; ALL NINE delete cases of
# jcon's own gener.icn torture test read [ok] where seven of nine failed on the clean tree.
# entries=906 · run-graded 753 · m3 PASS=742 · m4 PASS=742.  SNOBOL4 rungs as the shared-node control arm on the same
# tree: both-modes PASS=1893/1917, m3 FAIL=0, m4 FAIL=0.
# ⭐ RE-PINNED 742 -> 743 (hq_I 2026-09-09, CEO-474, hq_U co-signing): the procedure-value discriminator -- proc(name,0) yields the
# BUILT-IN even where a user procedure of that name exists, proc(name) yields what the global holds, and image(), type() and the
# call path read the marker instead of guessing from the name. entries=909 · run-graded 756 · m3 PASS=743 · m4 PASS=743.
# ⭐ RE-PINNED 743 -> 748 (hq_I 2026-09-09): read and reads take a FILE first, as icont does; the reads(count) shape we invented is
# deleted and a non-file first argument raises 105. entries=909 · run-graded 756 · m3 PASS=748 · m4 PASS=748. ⛔ TWO OF THE FIVE ARE
# THIS LANDING'S (rung27_read_reads_bytes and call_through_a_static_variable_reads_the_static, both modes, measured by stashing the
# change and re-running the identity gate: improved 12 -> 14). The other three arrived with the same pull and are read forward.
# ⭐ RE-PINNED 748 -> 750 (hq_S 2026-09-10): loadfunc resolves a symbol AND returns a callable, so procedure_write_254
# flips green in both modes (row icon-loadfunc-exits-1-with-no-output-master-procedure-write-254, CEO-476/485; the
# nulldesc grant). entries=909 · run-graded 756 · m3 PASS=750 · m4 PASS=750, SCRIP 64292dee1.
# ⭐ RE-PINNED 750 -> 756 (hq_V 2026-09-10, MODE NONET / ICON ONLY) on SCRIP `8410097ca` + corpus `726448e76`, both
# on origin. entries=911 · run-graded 758 · m3 PASS=756 · m4 PASS=756, both modes equal, xfail=0 xpass=0. TWO
# SOURCES, NAMED SEPARATELY because only one of them is this seat's: +1 population and +1 pass from this landing's
# absorption of the cfo's sixth handed witness (a_string_held_by_a_frame_variable_is_not_extended_in_place ->
# procedure_every_suspend_replace_3), absorbed GREEN after re-cutting its ref from icont on this tree; and +1 pass
# from procedure_write_256, which arrived with the pull and is NOT this seat's. ⛔ THE SIBLING COMMIT NAMED HERE
# WAS CORRECTED BY THE coo's AUDIT (09:59): this pin first credited the co-expression landing 8410097ca, and the
# coo, which extracted the entry and ran it, attributes it to hq_C's 98d75ebe0 reaching the board through that
# landing. The half that mattered -- that the flip is not mine -- was right either way; the half I had not
# measured myself was the one I got wrong, and a disclaimed flip still deserves the right owner. The two remaining reds are unchanged and named on the row:
# CRASH procedure_record_every_replace_12, FAIL procedure_every_scan_replace_13.
# ⭐ RE-PINNED 756 -> 826 (hq_icon 2026-09-16, MODE DECTET) in the same commit that makes this board able to
# MEASURE again: the ast-population guard had refused every run since 2026-09-03 (668b308b9), so the floors
# below stood at the last value a WRITING board produced while the suite itself walked to 826/826 both modes.
# Leaving them at 756 would let a 70-program regression pass this board in silence, which is the whole thing
# a watermark exists to stop. Measured on SCRIP 319e8e7ad + corpus aaadcb56d, m3 826/826 m4 826/826 FAIL=0.
# ⭐ RE-PINNED 826 -> 828 (hq_icon 2026-09-25, MODE TENET): corpus e3b18cb9a added the two crawl witnesses
# (rung22_lists_lconcat_alternation_right, rung42_kw_dateline_fields_unpadded) with the cures a94044665 and
# b74152578, and this board read them green on SCRIP 628c6b4dc, m3 828/828 m4 828/828 FAIL=0.
# ⭐ RE-PINNED 828 -> 830 (hq_icon 2026-09-25, MODE TENET): corpus 6169b7ff6 added the preprocessor port's two witnesses
# (rung42_kw_line_after_a_line_directive, rung42_kw_features_symbol_defined_without_a_dollar, cure 999a62f58), and this
# board read them green on SCRIP 6ea9dfaf5, m3 830/830 m4 830/830 FAIL=0.
M3_PASS_FLOOR="${ICON_RUNGS_M3_PASS_FLOOR:-900}"
M4_PASS_FLOOR="${ICON_RUNGS_M4_PASS_FLOOR:-900}"
# ⛔ NO AST_PASS_FLOOR: a self-pin has no floor to regress below, only a CURRENT-run comparison of
# ap (matched) vs at (total) -- see the AST-SHAPE note above. Removed under ast-dump-refs-are-self-
# pins-not-oracles rather than kept-but-unused, so a reader cannot mistake its presence for gating.

# ⛔ A BOARD THAT CANNOT MEASURE REFUSES rc=2 — never skip-as-success (RULES.md). Each arm below names
# what is missing, because "cannot enumerate" and "enumerated zero" are different facts and a single
# exit code for both is how a vanished corpus reads as a clean run.
if [ ! -x "$SCRIP" ];       then echo "⛔ BOARD REFUSES (rc=2): scrip not built at $SCRIP"; exit 2; fi
if [ ! -f "$HARNESS" ];     then echo "⛔ BOARD REFUSES (rc=2): corpus_suite_harness.py missing at $HARNESS"; exit 2; fi
if [ ! -f "$RUNGS_ICN" ] || [ ! -f "$RUNGS_REF" ]; then
    echo "⛔ BOARD REFUSES (rc=2): the Icon rungs suite is missing at $RUNGS_ICN"
    echo "   Do NOT read a family-by-family rung grader's smaller total as this board — that substitution"
    echo "   is the exact failure this board was minted to make impossible. Pull corpus."
    exit 2
fi
if [ ! -f "$RUNGS_CSV" ]; then echo "⛔ BOARD REFUSES (rc=2): ALL.csv missing at $RUNGS_CSV — no per-entry provenance to attribute a shrink to"; exit 2; fi

CSV_ENTRIES=$(( $(wc -l < "$RUNGS_CSV") - 1 ))
echo "=== Icon RUNGS board — corpus/tests/icon/ALL.icn ==="
# ⛔ `|| true` IS LOAD-BEARING, NOT SLOPPINESS: the harness exits NON-ZERO whenever any entry fails, and
# this board is a census over a suite that is legitimately red today. Under `set -euo pipefail` the bare
# pipeline aborted the script after printing only its header — a board that dies silently on the very
# condition it exists to report. The refusal arms below are what distinguish "could not measure" from
# "measured a red suite"; the exit status of the harness never does.
# ⛔⭐⭐ STDERR IS CAPTURED, NOT DISCARDED -- IT IS WHERE THE FAILURE NAMES LIVE. This line read
# `2>/dev/null` and therefore threw away the only per-entry information the run produces: the harness
# DOES print `FAIL <mode> <entry>: <why>` rows on stderr, and this board was
# deleting them before anyone could read them. hq_C measured the consequence from the other end
# (2026-09-03): the icon row accumulated THREE readings of one board in one day -- 377/381, 378/381, and
# a pinned floor of 379, on three different trees -- and none of them could be reconciled against the
# others, because a board that says "two of these regressed" without saying WHICH two produces numbers
# that can only ever be compared, never diffed. Their diagnosis was that the harness lacks a verbose
# flag in this mode; measured here, the harness was printing the rows all along and the BOARD was
# dropping them, which is a cheaper fix and a different file.
# ⛔ Kept in a SEPARATE stream, deliberately: folding stderr into $_raw would put arbitrary diagnostic
# text through the `grep '^SUITE_BOARD '` parses below, and a board that mis-parses its own verdict to
# gain a fail list has traded the number for the names rather than getting both.
# ⛔⭐ THE BINARY MOVED UNDER THIS BOARD (ceo CEO-524 (1), wired by the coo 2026-09-10 as THE ONE RUNNER).
# This board hands a 763-entry rungs to the harness under a 1800 s cap -- the longest window on the fleet and
# therefore the widest swap hazard. The staleness checks inside the harness prove the binary is CURRENT AT THE
# START and the dirty guard downstream reads the tree at WRITE time; neither can see a rebuild that lands while
# the run is still grading, which is how hq_R's board published m3 635/759 with a CLEAN stamp while the correct
# 756/759 was refused as dirty. ⛔ gate_bin_watch/gate_bin_unmoved ALREADY EXISTED for exactly this (lib_gate.sh,
# hq_S 2026-09-06) AND NO BOARD CALLED THEM. Both artifacts are watched: ./scrip is a ~40 KB driver and the
# emitter lives in the .so, so a scrip-only fingerprint is vacuous exactly when an emitter change is what moved.
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ BOARD REFUSES (rc=2): lib_gate.sh unloadable -- this board cannot tell whether its binary moves under it"; exit 2; }
GATE_NAME=board_icon_rungs gate_bin_watch "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so"
# ⛔⭐ THE TREE MOVED UNDER THIS BOARD, and the stamp that names the tree this row actually graded
# (coo 2026-09-10, COO-54, on the coo's own witness: a pass recorded one corpus hash and a background job
# moved corpus eight seconds later; gate_bin_watch stayed silent and was right to, because the BINARY had
# not moved). One call: gate_tree_watch exports S4E_TREE_AT_START in util_score_row's own vocabulary AND
# takes the baseline, so this board stops stamping HEAD-at-WRITE-time and starts refusing a split reading.
GATE_NAME=board_icon_rungs gate_tree_watch "$(cd "$HERE/../.." && pwd)"
_errf=$(mktemp); trap 'rm -f "$_errf"' EXIT
# ⛔⭐ THE OUTSIDE LIST RIDES ONLY IF IT EXISTS, and its absence is not an error: a suite with nothing outside
# its baseline has no file, exactly as a package without one does. When it IS there the harness REFUSES on a
# name it cannot find in the suite, so a stale list cannot quietly shrink the denominator (ceo ruling
# 2026-09-08: a rung suite entry the oracle cannot run is outside the rungs' baseline, recorded with the
# oracle's own words and never masked per line).
OUTSIDE_TSV="$CORPUS/ALL.outside.tsv"
_outside_arg=""; [ -f "$OUTSIDE_TSV" ] && _outside_arg="--outside $OUTSIDE_TSV"
_raw=$(timeout -k 5 1800 python3 "$HARNESS" run "$RUNGS_ICN" "$RUNGS_REF" --lang icon --modes m3,m4 $_outside_arg 2>"$_errf" || true)  # timeout-retry: exempt -- a whole-suite cap around the harness, which retries per entry itself
# ⛔ THE OUTSIDE SET IS ECHOED, NEVER SWALLOWED. This board captures the harness into $_raw and prints only
# what it greps, so without this the entries dropped from the denominator would be INVISIBLE on the very
# board whose number they changed -- which is precisely the masking the ruling forbids. Printed before the
# counts, so a reader sees what left the population before reading the population.
# ⛔ BEFORE THE FIRST NUMBER IS PRINTED AND BEFORE ANY SCORE.md WRITE, NEVER AFTER (ceo CEO-524 (1)): a refusal
# that fires after the row is published is an annotation, not a refusal. Placed here rather than beside the
# score-row call because this board PRINTS its counts long before it writes them, and a printed number gets
# quoted. gate_bin_unmoved exits 2 itself when the fingerprint moved.
GATE_NAME=board_icon_rungs gate_bin_unmoved
# ⛔ BEFORE THE FIRST PUBLISHED NUMBER, beside the binary check and for the same reason: an annotation that
# the tree moved is not a refusal -- util_score_row would happily write "graded; HEAD moved during the run"
# onto a number that describes no single tree.
GATE_NAME=board_icon_rungs gate_tree_unmoved
printf '%s\n' "$_raw" | grep '^OUTSIDE_BASELINE' || true
board=$(printf '%s\n' "$_raw" | grep '^SUITE_BOARD ' | tail -1 || true)
if [ -z "$board" ]; then
    echo "⛔ BOARD REFUSES (rc=2): harness produced no SUITE_BOARD line for the Icon rungs suite"
    echo "   Measured nothing. That is NOT a pass — see RULES.md: a test that cannot measure refuses."
    # ⛔⭐ THE HARNESS'S OWN WORDS, ECHOED HERE: the commonest cause of this refusal is the stale-binary REFUSAL ("binary older
    # than the tree it names -- make scrip"), and a refusal that does not carry the refusing layer's own message is
    # indistinguishable from a red by the time anyone reads it (hq_C 2026-09-10).
    if [ -s "$_errf" ]; then echo "   --- what the harness actually said (last 12 lines of its stderr) ---"; tail -12 "$_errf" | sed 's/^/   /'; fi
    exit 2
fi
field() { echo "$board" | grep -oE "$1=[0-9]+" | cut -d= -f2; }
mt=$(field total)
m3p=$(field m3_pass); m3f=$(field m3_fail); m3c=$(field m3_crash); m3h=$(field m3_hang); m3u=$(field m3_unproven); m3x=$(field m3_xfail); m3xp=$(field m3_xpass)
m4p=$(field m4_pass); m4f=$(field m4_fail); m4c=$(field m4_crash); m4h=$(field m4_hang); m4u=$(field m4_unproven); m4s=$(field m4_skip); m4x=$(field m4_xfail); m4xp=$(field m4_xpass)
# ⛔⭐ THE AND PER PROGRAM (ceo-372, 2026-09-06): the number this board's leaderboard row states is the count of
# entries green in EVERY mode they were graded in. It is read from the harness, never re-derived here -- m3p and
# m4p cannot yield it, because the AND is a fact about each ENTRY and the board line has already thrown the
# entries away. That is precisely why this row published one mode until now.
# ⛔ REFUSE RATHER THAN READ A ZERO. An older harness prints no all_pass=, `field` returns empty, and a row
# written over an empty string is a plausible false number -- this board's whole failure class.
mall=$(field all_pass)
# ⛔⭐ THE XFAIL OUTCOME SPLIT (ceo CEO-432 item 2): xfail says EXPECTED RED and nothing about WHICH red, so a
# crash, a hang, a wrong answer and a compile refusal are four different repairs wearing one count -- and an entry
# that crashes in one mode and merely answers wrong in the other cannot show at all without a re-run.
xfsplit() { # $1=mode prefix -> "wrong=A crash=B hang=C unproven=D skip=E"; an absent bucket is not a zero
    local m="$1" k v out=""
    for k in wrong crash hang unproven skip; do
        v="$(field "${m}_xfail_${k}")"
        [ -n "$v" ] || { echo "⛔ BOARD REFUSES: SUITE_BOARD carries no ${m}_xfail_${k}= field -- the outcome split cannot be assembled (CEO-432 item 2)." >&2; exit 2; }
        out="${out}${out:+ }${k}=${v}"
    done
    printf '%s' "$out"
}
# ⛔ THE `|| exit 2` IS LOAD-BEARING: xfsplit runs inside a command substitution, so its own `exit 2`
# leaves only the SUBSHELL -- the refusal would print to stderr and the run would carry on with an
# empty split, publishing "xfail=25 ()" as though that were a reading. The assignment's status IS the
# substitution's status, so this is where the refusal actually crosses back out.
m3xs="$(xfsplit m3)" || exit 2
m4xs="$(xfsplit m4)" || exit 2
[ -n "$mall" ] || { echo "⛔ BOARD REFUSES: SUITE_BOARD carries no all_pass= field -- this row is the AND per program (ceo-372) and cannot be assembled without it; corpus_suite_harness.py beside this script emits it."; exit 2; }
# ⛔⭐ AND THE SAME REFUSAL FOR THE xfail/xpass FIELDS, because this row now PUBLISHES them (coo 2026-09-08): a
# headline that holds N constant while xfail and xpass trade underneath it is blind to movement inside its own
# known-red set -- a cured bug and a stale marker are both invisible in it, in opposite directions. `field` returns
# the EMPTY STRING for a field the harness never emitted, and "xpass=" in a cell is not a zero; it is a reading that
# was never taken, wearing the shape of one that was, and it would read as "no stale markers" to every consumer.
for _f in m3_xfail:m3x m3_xpass:m3xp m4_xfail:m4x m4_xpass:m4xp; do
    _fld="${_f%%:*}"; _var="${_f##*:}"
    [ -n "${!_var}" ] || { echo "⛔ BOARD REFUSES: SUITE_BOARD carries no ${_fld}= field -- this row publishes the xpass count beside its fraction and cannot assemble it; corpus_suite_harness.py beside this script emits it."; exit 2; }
done
if [ -z "$mt" ] || [ "$mt" -eq 0 ]; then
    echo "⛔ BOARD REFUSES (rc=2): the harness graded ZERO entries over a rung suite file that exists"; exit 2
fi

graded=$mt
echo "entries=$graded  (every entry graded in both modes -- there is no modes column; ALL.csv rows=$CSV_ENTRIES, floor=$ENTRY_FLOOR)"
echo "population: $mt entries, each graded in both modes"
echo "mode-3 (--run):     PASS=$m3p FAIL=$m3f CRASH=$m3c HANG=$m3h UNPROVEN=$m3u XFAIL=$m3x ($m3xs) XPASS=$m3xp   / $mt"
echo "mode-4 (--compile): PASS=$m4p FAIL=$m4f CRASH=$m4c HANG=$m4h UNPROVEN=$m4u SKIP=$m4s XFAIL=$m4x ($m4xs) XPASS=$m4xp   / $mt"
echo "rerun a single mode: python3 $HARNESS run $RUNGS_ICN $RUNGS_REF --lang icon --modes m3   (per-entry attributes: ALL.csv)"
# ⭐ THE NAMES, so two runs of this board can be DIFFED and not merely compared. Capped, because the
# point is to make a regression identifiable, not to paste a census into a terminal -- and the cap says
# so out loud rather than truncating silently, which would be a smaller version of the same defect.
# ⛔ `grep -c` PRINTS "0" *AND* EXITS 1 on no match, so `|| echo 0` printed a SECOND zero and every green board printed
# "[: 0\n0: integer expression expected" twice and carried on (measured 2026-09-04, hq_B; rc stayed 0, so nothing caught it).
# ⛔ AND THE FIRST CURE (08c96e2b9, drop the fallback) KILLED EVERY GREEN BOARD: this script runs under `set -e`, and
# `grep -c` exits 1 on zero matches, so the bare assignment aborted the board silently right after the "rerun a
# single mode" line -- measured by the strip row's `done` 20 minutes later. `|| true` keeps grep's own "0" and its
# failing status out of set -e; the empty-case default stays for a missing file.
# OOM is a red the harness names on its own line (CEO-1229 (2): every out-of-memory program by name, so each gets its heap declaration);
# it is counted inside FAIL on SUITE_BOARD, and this filter dropped it until 2026-10-03 (the coo, gate (b)'s Icon arm: a 2 MB-capped
# entry read FAIL=2 per mode with one name printed) -- so a board's OOM reds were counted and never named.
_nfail=$(grep -cE '^[[:space:]]*(FAIL|OOM|CRASH|HANG|XPASS|UNPROVEN) ' "$_errf" 2>/dev/null || true); _nfail=${_nfail:-0}
if [ "${_nfail:-0}" -gt 0 ]; then
    echo ""
    echo "--- the $_nfail non-PASS entries by name (showing up to 40; stderr of the run above) ---"
    grep -E '^[[:space:]]*(FAIL|OOM|CRASH|HANG|XPASS|UNPROVEN) ' "$_errf" | head -40
    [ "$_nfail" -gt 40 ] && echo "    ... and $((_nfail - 40)) more (rerun and keep stderr to see them all)"
fi

RED=0
# ⛔ THE DENOMINATOR CHECK IS THE POINT OF THIS BOARD — a shrink is the silent-orphan class itself.
if [ "$graded" -lt "$ENTRY_FLOOR" ]; then
    echo "⛔ RED: graded population $graded is UNDER the floor $ENTRY_FLOOR — $((ENTRY_FLOOR-mt)) entries vanished from the rungs,"
    echo "        or this checkout is behind origin. An entry that stops being graded is exactly what this board exists to catch."
    RED=1
fi
# ⛔⭐ THE DRIFT CHECK MUST SUBTRACT WHAT WAS DELIBERATELY REMOVED, OR IT ACCUSES THE SUITE OF DRIFT ON EVERY
# GREEN RUN. MEASURED (hq_V 2026-09-09, CEO-476): ALL.icn carried 905 banner markers, ALL.ref 905 and ALL.csv 905
# rows with the three name-sets IDENTICAL -- nothing had drifted by any reading -- and this check still printed
# "the suite file and its provenance index disagree", because `graded` excludes the entries the CEO-390/391
# outside-baseline ruling removes from the denominator and `CSV_ENTRIES` still counts their rows. The harness
# prints that population as OUTSIDE_BASELINE_COUNT and names every member with the oracle's own reason on every
# run, so the number to reconcile against was already on screen and merely was not being read.
# ⛔ WHY IT WAS WORTH CURING RATHER THAN TOLERATING: a warning that is permanently true and permanently
# meaningless sits one line above the numbers a reader acts on, and it teaches that reader to scroll past the one
# check whose entire job is to catch a REAL silent shrink -- so the check had been disabled by its own output.
# Reconciled, it can speak again: it now fires only when the three populations genuinely fail to add up, and it
# SHOWS the arithmetic so the next reader can see which term is wrong instead of re-deriving it.
# ⛔⭐ `|| true` IS WHAT KEEPS THE PROMISE MADE 119 LINES ABOVE (hq_V 2026-09-10, MEASURED). The OUTSIDE list
# "rides only if it exists, and its absence is not an error" -- and the `${_outside_n:-0}` fallback on this very
# line was written for exactly that case. Under `set -o pipefail` it never got the chance: with no outside list
# the harness prints no OUTSIDE_BASELINE_COUNT at all, this grep exits 1, the pipeline fails, and `set -e` kills
# the board HERE -- one line before the denominator reconciliation, the watermark verdict and the SCORE.md write.
# MEASURED when CEO-503 retired the last outside row: the board ran all 759 entries, printed its full numbers and
# the six non-PASS names, then vanished with rc=1 and wrote NO row. That is the worst shape an instrument can
# fail in -- it looks like a completed run in the log and leaves the board silently stale, which the FACT RULE
# counts as a defect of the session. An empty outside list must read as ZERO OUTSIDE, never as a dead board.
_outside_n=$(echo "$_raw" | grep -oE '^OUTSIDE_BASELINE_COUNT [0-9]+' | awk '{print $2}' | tail -1 || true); _outside_n=${_outside_n:-0}
if [ "$(( graded + _outside_n ))" -ne "$CSV_ENTRIES" ]; then
    echo "⚠️  NOTE: harness graded $graded entries and $_outside_n are outside the baseline ($((graded + _outside_n)) accounted for),"
    echo "        but ALL.csv carries $CSV_ENTRIES rows — the suite file and its provenance index genuinely disagree by"
    echo "        $(( CSV_ENTRIES - graded - _outside_n )). Neither number is wrong on its face; they must not drift apart."
fi
# ⭐ PASS WATERMARKS: red on regression only. These are NOT a claim that the remainder is acceptable —
# 122 m3 failures are real and belong to hq_C's lane; this board's job is to notice movement.
if [ "$m3p" -lt "$M3_PASS_FLOOR" ]; then echo "⛔ RED: m3 PASS $m3p regressed below watermark $M3_PASS_FLOOR"; RED=1; fi
if [ "$m4p" -lt "$M4_PASS_FLOOR" ]; then echo "⛔ RED: m4 PASS $m4p regressed below watermark $M4_PASS_FLOOR"; RED=1; fi
if [ "$((m3p+m4p))" -gt "$((M3_PASS_FLOOR+M4_PASS_FLOOR))" ]; then
    echo "⭐ WATERMARK MOVED UP (m3 $m3p vs $M3_PASS_FLOOR, m4 $m4p vs $M4_PASS_FLOOR) — re-pin the floors in the commit that earned it."
fi
[ "$((m3xp+m4xp))" -gt 0 ] && echo "⭐ XPASS>0: a bug got FIXED and its XFAIL marker was never promoted — as actionable as a failure, in the opposite direction."

# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05). Records what this script just
# measured into .github/SCORE.md; runs nothing itself. Non-fatal: a bookkeeping failure must never
# turn a real measurement into a red board.
# ⭐ THE CELL CARRIES THE NAMES, not just the count. A leaderboard cell reading "2 below the floor" makes
# the next reader re-run a 20-minute board to find out WHICH two; the names make the row diffable against
# the next run, which is the whole complaint that row icon-master-board-is-two-below-watermark-and-the-
# board-never-names-the-failures was raised about. Capped at six so a genuinely broken board does not
# paste a census into a markdown table, and the overflow is stated rather than silently dropped.
_named=""
if [ "${_nfail:-0}" -gt 0 ]; then
    _names=$(grep -E '^[[:space:]]*(FAIL|OOM|CRASH|HANG|XPASS|UNPROVEN) ' "$_errf" \
             | sed -E 's/^[[:space:]]*([A-Z]+) [a-z0-9]+ ([^:]+):.*/\1 \2/' | sort -u | head -6 | paste -sd'; ' -)
    _named=" — reds by name: $_names"
    _uniq=$(grep -E '^[[:space:]]*(FAIL|OOM|CRASH|HANG|XPASS|UNPROVEN) ' "$_errf" \
            | sed -E 's/^[[:space:]]*[A-Z]+ [a-z0-9]+ ([^:]+):.*/\1/' | sort -u | wc -l)
    [ "${_uniq:-0}" -gt 6 ] && _named="$_named (and $((_uniq - 6)) more entries)"
fi
# ⛔ PLACED ABOVE THE RED EXIT ON PURPOSE. A red board is still a MEASUREMENT, and the FACT RULE says
# ANY run -- recording only green boards would make the leaderboard a trophy cabinet, showing each
# suite's best remembered day rather than its state, which is the exact opposite of what it is for.
# ⛔⭐ DECLARE THE PAIR RATHER THAN RELY ON THE TEXT HAPPENING TO CARRY ONE FRACTION (hq_T 2026-09-06,
# ceo CEO-363). This row auto-resolved until now only because its board line prints m3 and m4 with the SAME
# numbers, so the two fractions collapsed to one reading; the day the modes diverge -- which is exactly the
# day the number matters -- it would have started refusing instead. A mechanism that works because two
# values happen to be equal is not wired, it is lucky.
# ⛔⭐ AND THE DECLARED PAIR IS THE AND PER PROGRAM (ceo-372): the entries green in EVERY graded mode, never
# m4 alone (what this row published until now), never m3 alone, never min(m3p,m4p). ⭐ NOTE THIS BOARD'S OWN
# HISTORY IS THE ARGUMENT FOR IT: m3p and m4p have been EQUAL here, which reads as "both modes agree" and is
# not the same claim at all -- equal COUNTS are consistent with two disjoint sets of reds. Only the AND can
# tell those apart, and where the two numbers really did describe the same programs it changes nothing.
python3 "$HERE/util_score_row.py" write --lang icon --column board --modes m3,m4 \
    --suite-pass "$mall" --suite-total "$mt" \
    --measurer "${S4E_SEAT:-}" \
    --text "$([ "$RED" -ne 0 ] && echo "⛔ RED — ")run-graded both-modes $mall/$mt · m3 $m3p/$mt xfail=$m3x ($m3xs) xpass=$m3xp · m4 $m4p/$mt xfail=$m4x ($m4xs) xpass=$m4xp (entries=$graded, floors m3 $M3_PASS_FLOOR / m4 $M4_PASS_FLOOR, \`board_icon_rungs.sh\`)$_named" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
# ⭐ THE PROGRESS LINE, after the rewrite.  This runner writes its row DIRECTLY rather than through
# lib_gate.sh's gate_score_row, so it needs the call the shared path already carries -- same one line,
# not a second implementation (both ends run `util_score_row.py progress`, which reads SCORE.md and
# runs no suite).  Non-fatal by construction: it must not be able to change this board's verdict.
# ⛔ THE PROGRESS LINE IS DELETED (Lon 2026-09-13, verbatim: "All bogus. Delete that. Do not show
# that ever again."). The call that stood here printed it; util_score_row.py progress is now a silent
# no-op and this call is removed so the intent is visible rather than inferred from an empty output.
if [ "$RED" -ne 0 ]; then echo "⛔ ICON RUNGS BOARD RED"; exit 1; fi
echo "✅ ICON RUNGS BOARD OK: entries=$graded at/above floor $ENTRY_FLOOR · run-graded both-modes PASS=$mall/$mt (the AND, what the leaderboard row states) · m3 PASS=$m3p m4 PASS=$m4p / $mt (watermarks held)"
