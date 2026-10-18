#!/usr/bin/env bash
# ../harness/scripts/test_gate_orphaned_witnesses_do_not_grow.sh — ceo CEO-414 (minted hq_P 2026-09-08).
#
# WHAT IT GATES.  An ORPHANED WITNESS is a committed `<name><ext>` + `<name>.ref` pair under
# corpus/tests/<lang>/ whose name appears in NO `ALL.csv`, `ALL.xfail` or `ALL.excluded.txt`.
# It is not passing, not expected-failing and not excluded: NO DENOMINATOR CONTAINS IT, so no
# board has ever run it.  Of the 39 SNOBOL4 orphans measured at mint, FOUR ARE RED and one of
# those SEGFAULTS in both modes (nested_arbno_rpos, rc=139) -- while the SNOBOL4 rungs read
# 1894/1894 FAIL=0 on the same tree.  This count may FALL, never RISE.
#
# ⭐ WHY A RATCHET IS LEGITIMATE HERE — the question test_gate_term_wordref_ratchet.sh's header
# forces on anyone copying its shape is CAN THIS COUNT REACH ZERO BY DESIGN?  Here it can and is
# meant to: every witness pair we commit is supposed to end up in its language's rungs, so a
# remaining orphan is debt and 0 is the intended terminal value.  It never fires on legitimate
# work, because ABSORBING an orphan lowers the count and writing a NEW witness straight into the
# rungs never raises it.
#
# ⛔ THE CURE IS TO ABSORB, NEVER TO DELETE.  Deleting an orphan also makes this gate green and is
# the one move that would satisfy the ratchet while destroying the evidence.  Say so here because
# a ratchet cannot tell the two apart.
#
# ⛔ MEMBERSHIP IS SUBSTRING, NOT TOKEN — AND THAT IS A CORRECTION, NOT A PREFERENCE.  Absorbed
# files are RENAMED into the rungs and keep their original filename only inside a longer token:
# icon's `alt_arith` lives in ALL.csv as `parser_alt_arith__alt_arith`.  The first census of this
# defect used token matching, could not see that, and MANUFACTURED ~153 FALSE ICON ORPHANS (it
# reported icon 172 / total 213; the truth is icon 19 / total 59).  ⭐ It was control-armed in both
# directions -- ON SNOBOL4, whose naming happens not to use that form, so the control arm passed
# AND COULD NOT HAVE FAILED.  A control arm proves the instrument on the population you ran it on.
# Substring matching is deliberately GENEROUS: it UNDER-reports rather than inventing orphans,
# which is the only safe direction for a ratchet.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
CORPUS="${CORPUS:-$(cd .. && pwd)/corpus}"
CENSUS="$CORPUS/tests/ORPHANED-WITNESSES.tsv"
[ -d "$CORPUS/tests" ] || { echo "⛔ GATE REFUSES(2): no corpus tests tree at $CORPUS/tests"; exit 2; }
[ -f ../harness/scripts/util_orphaned_witness_census.py ] || { echo "⛔ GATE REFUSES(2): census generator missing"; exit 2; }
# ---- the floor, per language.  Lower a number ONLY in the commit that absorbs the witnesses.
# ⭐ FLOOR_icon 19 -> 20 (hq_V 2026-09-10, ceo CEO-516 landing). NET +1 FROM TWO MOVES IN OPPOSITE DIRECTIONS, named
# apart so neither hides the other: the cfo's EIGHTH pair (cset_membership_is_a_bit_test_not_a_name_lookup) was
# ABSORBED into the Icon rungs and its loose pair deleted, which REMOVED an orphan; and the cfo's SEVENTH pair
# (trace_call_line_prints_every_parameter_and_images_a_list) became a PERMANENT loose keeper, which ADDED one.
# ⛔ THE KEEPER IS NOT A DEBT AND THIS RAISE IS NOT A RATCHET LEAK: it prints its own file name in all 43 of its
# trace lines, so the rungs builder's rename would make it red by construction (86 differing lines, measured,
# with a control green under its own name) -- tests/icon/KEEP.md carries the measurement. It can never be absorbed,
# so its orphan is permanent and the floor is where that fact belongs.
# ⭐⛔ FLOOR_icon 20 -> 5 (hq_V 2026-09-10, ceo CEO-541 landing), AND FIFTEEN OF THE EIGHTEEN WERE ALREADY PAID FOR --
# THE CENSUS FILE JUST NEVER SAID SO. This landing absorbs eleven rung36_jcon keepers, which removes 0 orphans (they
# pair a .icn with a .expected, and the census only counts a .ref sibling). The fall is HQV-26's: that landing
# absorbed 18 long-loose witnesses and DID NOT REGENERATE corpus/tests/ORPHANED-WITNESSES.tsv, so the checked-in
# census kept naming absorbed files and this gate read STALE -- red on origin, for anyone who ran it, in a way that
# reads like someone else's debt. Regenerated here in the same commit. ⛔ THE DIRECTION IS THE ONLY MERCY: a stale
# census OVER-reports orphans, so the ratchet failed safe rather than hiding real debt. An absorb landing owes this
# file its regeneration, exactly as it owes ALL.csv one -- the count is not the artifact, the census is.
# ⭐ FLOOR_icon 5 -> 4 (hq_V 2026-09-10, same session, one landing later). Three more loose witnesses absorbed into the
# Icon rungs -- display_prints_the_frames_locals_and_the_globals and icon_display_builtin_unimplemented (handed green in
# BOTH modes by the cto on SCRIP 6c453e4d0, the mode-4 procedure-name-table cure) and
# a_section_of_the_null_value_raises_string_or_list_expected (handed by the cfo) -- each re-measured three ways here at
# absorb time rather than taken on the handing seat's word.
# ⚠ THE TWO PAIRS THAT AROSE IN MY EARLIER REBASE WINDOW ARE STILL ORPHANS AND ARE STILL THEIRS: corpus cfc826b0f
# (stop_writes_to_a_leading_file_argument_and_ends_its_line) and 2e8b94fe5
# (list_and_reads_check_their_size_argument_and_real_exponentiation_reports_no_value). The count fell past them because
# THREE absorbs outweighed TWO additions, not because either was resolved -- ORPHANED-WITNESSES.tsv still names both, by
# name, which is where a debt belongs. A floor is a ceiling on the count, never a receipt for what is under it.
# ⭐ AND ONE OF THE FIVE WAS NEVER A DEBT AT ALL -- IT WAS BOOKKEEPING LAG, WHICH THIS CENSUS CANNOT TELL APART FROM
# DEBT. corpus bc1b1f900 landed an_ordinary_call_chain_prints_every_frame_in_the_traceback, which hq_S DECLARED in
# KEEP.md in that same commit as a permanent name-echoing keeper -- correctly: its ref carries its own file name on 4
# lines, so the rungs builder's rename would manufacture a red. It counted as an orphan only because ALL.excluded.txt
# is written by the BUILDER and no build had run since. Verified the echo here before writing anything, then added the
# one line the builder emits verbatim. ⛔ A DECLARED KEEPER READS AS AN ORPHAN UNTIL SOMEBODY RUNS A BUILD: the census
# reads three files, and one of the three lags the declaration that governs it.
# ⭐ FLOOR_icon 4 -> 2 (hq_V 2026-09-10, third landing of the sitting): the cfo's two pairs -- the very two named above as
# still-theirs -- were handed over for absorption and are now IN the rungs as procedure_alt_list_replace_1 and
# procedure_every_to_52, three-way measured here first. So the debt named two commits ago is discharged rather than
# outlived, which is the only honest way for a named debt to leave a ratchet.
# ⭐⭐ FLOOR_icon 2 -> 0 (hq_V 2026-09-10/11). ICON REACHES THIS RATCHET'S INTENDED TERMINAL VALUE -- the header above says
# 0 is reachable by design and is what the count is for; icon is the first language to get there. ⛔ AND THE LAST STRETCH
# WAS NOT CONVERSION WORK AT ALL, which is why it sat still for a day: of the 20 files the conversion gate called "neither
# converted nor declared", EIGHTEEN WERE ALREADY IN THE RUNGS and only their loose copies had never been deleted. Two were
# genuinely new. A duplicate left beside its absorbed entry is indistinguishable, to both this census and that gate, from a
# witness nobody converted -- and the two want OPPOSITE cures, absorb versus delete. Every one of the 18 was content-verified
# against its existing rungs entry by the builder's own --delete-absorbed before removal, and the rungs' content diff over
# the whole landing is lost 0, gained exactly 2, changed 0.
# ⛔⭐ FLOOR_snobol4 39 -> 41 (cfo 2026-09-14, row snobol4-fence-then-an-operand-then-an-alternation-in-a-pattern-
# variable-never-backtracks). THIS IS A RAISE AND IT OWES AN ARGUMENT, because hq_I named raising a floor as the move worth
# NOT making -- it silences the gate without answering the question. THE TWO ARE ANSWERED AND THAT IS THE WHOLE DIFFERENCE:
# `fence_then_operand_then_alternation_never_backtracks` and `tpgm4_syntactic_recognizer` are DECLARED in
# corpus/tests/snobol4/PENDING.md, deferred to a LIVE row whose DONE-WHEN grades the first of them in both modes, and they
# convert into the rungs the day it is cured -- at which point this floor falls back to 39 and this gate is what says so.
# ⭐ FLOOR_snobol4 41 -> 39 (hq_snobol4 2026-09-27): cured at SCRIP 5f445d5fd -- 11c73f1e5 cured the minimal witness and 5f445d5fd the
# trailing-operand case tpgm4 needed (row snobol4-a-stored-fenced-pattern-with-an-operand-after-its-alternation-never-backtracks-into-
# it-tpgm4-two-part-gotos); both pairs converted into the rungs green in both modes by the builder's --absorb-only/--delete-absorbed,
# content diff lost 0 gained 2 changed 0, and PENDING.md retired with its last deferral.
# ⛔ WHY THEY ARE NOT SIMPLY ABSORBED RED, WHICH IS WHAT THE LADDER LAW ASKS FOR: util_build_rungs_suite.py runs every
# plain loose pair before absorbing it and mints `xfail = not green` with NO reason block and NO flag to decline (its own
# comment: "auto-XFAIL by source verdict"). I absorbed them once, measured the result -- two XFAIL entries carrying no
# reason -- and reverted it: that moves test_gate_no_xfail_survives.sh's population the wrong way on Lon's own ruling that
# there is no such thing as XFAIL, and test_gate_xfail_has_reason.sh would be right to call it a defect. So the sanctioned
# path into the rungs cannot carry a red witness honestly today, and until it can, a declared deferral is the honest shape.
# ⭐ THE THIRD THING THIS COST IS THE ONE WORTH FIXING FIRST, reported to hq_T rather than patched here: THIS CENSUS DOES
# NOT READ KEEP.md OR PENDING.md AT ALL. A pair the deferral contract has properly declared still reads as an orphan, so the
# one mechanism the tree offers for "loose on purpose, attached to a row" is invisible to the one gate that counts loose
# files. Teaching the census the two files it already has would make this raise unnecessary and would lower icon's argument
# from prose to code.
# ⭐ FLOOR_icon 0 -> 2 (the coo 2026-09-27, ceo CEO-1306, row instruments-five-corpus-and-suite-gates-red-or-refused-on-origin-
# 81aa23aff-...). The two are config/audit_return_forms/w_return_forms and w_control_structures, the coo's COO-183 audit witnesses the
# ceo homed there (CEO-1245, corpus 6b145b60a) as the DONE-WHEN witnesses of hq_icon's two parked return-variable rows. They are RED in
# both modes (error 111 where iconx assigns through the returned variable), so the builder cannot carry them into the rungs honestly
# today (the auto-XFAIL note above), and moving them would break the DONE-WHENs that name their path. tests/icon/PENDING.md declares
# them under the reopened row; they are absorbed when those rows cure and this floor falls in that commit. Named debt, not a leak.
# ⭐ FLOOR_icon 2 -> 0 (hq_icon 2026-10-17, row icon-absorb-every-owed-source-into-the-one-master-unabsorbed-census-reads-zero): both
# witnesses had cured and were already in the master byte for byte (ladder__rung02_proc_every_return_form_returns_its_variable and
# ladder__rung02_proc_an_if_case_block_or_limitation_is_a_variable_when_its_arm_is); w_control_structures is deleted, w_return_forms stays
# loose only because hq_zetas' live row spine-zd-planner-arms-... compiles it by path (tests/icon/PENDING.md re-points its deferral there,
# and the builder's regenerated ALL.excluded.txt records it, so this census no longer counts it an orphan).
# ⭐ FLOOR_snobol4 39 -> 1 (hq_snobol4 2026-10-17, row snobol4-absorb-every-owed-source-into-the-one-master-unabsorbed-census-
# reads-zero): 38 of the 39 pairs are master entries now (corpus 6fed95b5c, 542589286, f1ac5ce03 and the landings after it) and
# ORPHANED-WITNESSES.tsv is regenerated; the gates that compiled them by path extract them from the master by origin. The one left is
# nested_arbno_rpos: it SIGSEGVs again in both modes (rc 139) where sbl -bf prints match, first bad e53f5dcd6 (the spine flip; its
# parent prints match 3 of 3 per mode), and the builder absorbs a red pair only as an auto-minted XFAIL (the class named below), so it
# stays loose until the flip's cure lands and is absorbed green then.
# ⭐ FLOOR_snobol4 1 -> 0 (hq_snobol4 2026-10-17): nested_arbno_rpos cured at SCRIP 0c92d38f5 (a node of an ARBNO's body keeps its cells at its
# gamma into the ARBNO) and is the master entry arbno_rpos_alt_branch_4, its ref sbl -bf's.
FLOOR_icon=0 FLOOR_pascal=0 FLOOR_prolog=0 FLOOR_raku=0 FLOOR_rebus=0 FLOOR_snobol4=0 FLOOR_snocone=0
out="$(python3 ../harness/scripts/util_orphaned_witness_census.py "$CORPUS" --counts 2>&1)" || { echo "⛔ GATE REFUSES(2): census generator failed:"; echo "$out"; exit 2; }
printf %s "$out" | grep -q . || { echo "⛔ GATE REFUSES(2): census produced NO output -- an empty census is not a green board"; exit 2; }
rc=0 tot=0 seen=0
while IFS=$'\t' read -r lang n; do
  [ -n "${lang:-}" ] || continue
  seen=$((seen+1)); tot=$((tot+n))
  eval "floor=\${FLOOR_$lang-}"
  if [ -z "$floor" ]; then echo "  ⛔ $lang: $n orphan(s) — NO FLOOR PINNED for this language; add FLOOR_$lang to this gate"; rc=1; continue; fi
  if [ "$n" -gt "$floor" ]; then echo "  ⛔ $lang: $n orphan(s), floor $floor — GREW by $((n-floor))"; rc=1
  elif [ "$n" -lt "$floor" ]; then echo "  ⭐ $lang: $n orphan(s), floor $floor — FELL by $((floor-n)); lower FLOOR_$lang to $n in this commit"; rc=1
  else echo "  ok    $lang: $n orphan(s) at the floor"; fi
done <<< "$out"
[ "$seen" -gt 0 ] || { echo "⛔ GATE REFUSES(2): census listed no languages at all"; exit 2; }
if [ ! -f "$CENSUS" ]; then echo "  ⛔ the census file $CENSUS is MISSING — regenerate it"; rc=1
else
  fresh="$(python3 ../harness/scripts/util_orphaned_witness_census.py "$CORPUS")"
  if ! printf '%s\n' "$fresh" | diff -q - "$CENSUS" >/dev/null 2>&1; then
    echo "  ⛔ $CENSUS is STALE — it does not match the tree; regenerate:"
    echo "       python3 harness/scripts/util_orphaned_witness_census.py corpus > corpus/tests/ORPHANED-WITNESSES.tsv"; rc=1; fi
fi
echo "------------------------------------------------------------"
[ $rc -eq 0 ] && echo "✅ GATE PASS [orphaned_witnesses_do_not_grow]: $tot orphaned witness pair(s), none above its floor" \
              || echo "⛔ GATE FAIL [orphaned_witnesses_do_not_grow]: $tot orphaned witness pair(s) — see above"
exit $rc
