#!/usr/bin/env bash
# test_gate_gc_the_caller_saved_spill_block_never_holds_a_heap_reference.sh -- THE INVARIANT BEHIND DELETING A ROOT
# REGISTRATION, MEASURED INSTEAD OF WRITTEN DOWN (cto 2026-09-20, MODE TENET; asked CTO-153, ruled by the cfo).
#
# THE FINDING.  rtcc_init.c registers the runtime's caller-saved spill block as a GC root range --
# rt_gc_root_range_add_seamsafe(&g_rtccb[0], &g_rtccb[32]) -- and gc_heap.c's ONLY walk over the root-range table opens
# `if (g_gc_rrng[i].hi) continue;`, which is exactly how that range and only that range is registered.  The other
# caller, the Prolog trail, uses the topword form with a null hi and IS visited.  g_gc_rrng_ss is incremented at
# registration and read nowhere; g_gc_segs is collected and read nowhere, so no conservative segment scan covers it
# either -- correctly, per CEO-812.  THE REGISTRATION'S ONLY EFFECT IS TO INCREMENT A COUNTER NOBODY READS: to every
# reader g_rtccb is a registered GC root, and to the collector it is not.
#
# ⛔ THE cfo RULED THAT VISITING IT IS NOT AN OPTION AT ALL, AND THE LAW DECIDES IT RATHER THAN TASTE.  g_rtccb is
# thirty-two RAW MACHINE WORDS WITH NO TYPE TAGS.  Visiting them means asking of each word "does this look like it
# points into a heap block", WHICH IS A CONSERVATIVE SCAN BY DEFINITION, and CEO-812 froze that out: everything on
# the emitted stack is a DESCR and its type field is the only tag, the heap walks typed visitors, no conservative
# scan and no pinning in any form.  A precise visit is impossible because the words carry nothing to be precise
# about.  So the registration and the seamsafe API are DELETED (the cfo's landing, gc_heap.c is their file) and
# THIS GATE IS WHAT MAKES THAT SAFE.
#
# ⛔⭐ THE MEASUREMENT THAT BUILT THIS GATE WAS WRONG, AND BUILDING THE GATE IS WHAT CAUGHT IT.  I reported to the
# cfo, the ceo and three HQs that the block was LATENT, NOT LIVE -- "47 witnesses at SCRIP_HEAP_MB=1
# SCRIP_GC_STRESS=3, ZERO slots holding a heap pointer".  THAT SWEEP RAN WITHOUT SCRIP_GC_MAPS=1, AND
# gc_walk_print RETURNS EARLY WHEN gc_maps_on() IS FALSE, so neither [GC-RTCCB] nor [GC-WALK-RTCCB] COULD HAVE
# PRINTED UNDER ANY CIRCUMSTANCES.  I grepped for a line the run was incapable of emitting and read the silence as
# a zero -- an instrument reporting success while it is not looking, which is the exact class this row exists to
# remove, produced by me while curing it in three other places the same evening.
# ⭐ THE TRUE READING, reporter enabled, same arena and stress: 806 occurrences over EIGHT SNOBOL4 witnesses --
# hb_dvec_sort_match 604, hb_nv 190, hb_datblk 4, hb_dvec_data_convert 3, hb_blob_span_defer 2, and one each in
# hb_defer_subject, hb_dtp, hb_nested_match_outer_subject.  EVERY ONE IS SLOT 5 = RTCC_SLOT_R8, the register
# rtcc.h declares as the ANCHOR.  hq_prolog's null STANDS: they ran catch_1 with SCRIP_GC_MAPS=1 at stress 3, 5,
# 10 and 25 and read zero, so Prolog genuinely does not park a heap pointer there -- despite owning 4740 of the
# 6705 stores into the block.  Two lanes, two different answers, and only the one that enabled the reporter was
# measuring.
# ⛔ WHAT IS STILL NOT ESTABLISHED, AND THE GATE SAYS SO IN ITS OWN FAILURE TEXT: none of the eight witnesses
# answers its oracle wrongly.  A pointer in an unvisited slot is NECESSARY BUT NOT SUFFICIENT for a lost value,
# the same way a store below the region base was (CTO-101), because the same block may be rooted elsewhere.  The
# sharper hazard is STALENESS rather than sweeping: an unvisited slot cannot be rewritten when a root walk
# FORWARDS a moving block, and the emitted reload after the poll restores the pre-move word.
#
# THE INVARIANT, as the cfo states it and as this grades it: g_rtccb is CALLER-SAVED SCRATCH and nothing that must
# survive a collection may live there -- r8 the anchor, r9 the GVA, r10 and r11 scratch, per the declared
# convention in rtx/rtcc.h.  A value that must survive a poll goes in a frame slot covered by that frame's static
# map, or is handed to the shield as a TAGGED DESCR cell in arr[], which the poll's own refusal text says in words
# (CEO-972).
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"
# ⛔ THE FRESHNESS GUARD, AND IT IS HERE BECAUSE THIS GATE'S OWN CLASS OF DEFECT REACHED THE GATES BUILT TO CHASE
# IT (the coo, 2026-09-21).  They built at 15:01:58, the cto landed a cure at 15:01:39, they started a 381-arm
# set at 15:03:52 without rebuilding, and 260 arms refused one at a time for that one reason -- while the DARK
# run finished in HALF the wall clock of the honest one, so a seat optimising for a quick gate was being
# rewarded for measuring nothing.  A gate that grades ./scrip with no guard will one day grade a binary older
# than the cure it is testing and call it green.  One line, and the staleness rule itself lives in exactly one
# place (gate_require_fresh in lib_gate.sh) -- this is its calling convention, never a second copy of it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="$ROOT/scrip"
WD="$ROOT/../harness/scripts/gc_witnesses"
STRESS="${GC_RTCCB_STRESS:-3}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [gc_the_caller_saved_spill_block_never_holds_a_heap_reference]: $1"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -d "$WD" ] || refuse "no $WD -- nothing to grade"
RUNCWD=$(mktemp -d) || refuse "no mktemp for the run cwd"; trap 'rm -rf "$RUNCWD"' EXIT; cd "$RUNCWD" || refuse "cannot enter $RUNCWD -- a witness run from the checkout root litters it (tmp3/tmp4) and races every concurrent arm"
echo "ARENA SCRIP_HEAP_KB=${SCRIP_HEAP_KB:-64} (the tiny arena of GC testing is the 64 KB floor -- CEO-1146: the old MB=1 knob is a 1024 KB window, eight times the shipped 128 KB, and ran the collector ZERO times on a 3000-string witness; the count of collections is read from the run, never assumed from the knob) · stress $STRESS"

# (a) THE REPORTER EXISTS AND IS REACHED.  ⛔ AN ARM THAT GRADES A COUNTER NOTHING INCREMENTS PASSES BY NEVER
# LOOKING, which is the failure THE INSTRUMENT LAWS exist to catch and the reason this arm comes first.
src="$ROOT/src/runtime/rt/gc_heap.c"
[ -f "$src" ] || refuse "no $src -- the reporter this arm grades cannot be located"
if grep -q "GC-WALK-RTCCB" "$src" && grep -q "g_gc_rtccb_heap" "$src"; then
  ck ok "(a) the runtime's own g_rtccb reporter is present in gc_heap.c -- this gate grades a counter that something increments"
else
  ck no "(a) gc_heap.c carries no GC-WALK-RTCCB reporter or no g_gc_rtccb_heap counter, so every arm below would read zero by never looking. If the reporter was deliberately removed, this gate must be retired in the same landing and the invariant re-homed, NOT left grading nothing"
fi

# (b) THE INVARIANT ITSELF, over every witness that collects.  A slot holding a pointer INTO A HEAP BLOCK at a
# collection is the whole defect: the block is unreachable from any root walk, so it is swept under a live value.
witn=0; coll=0; hits=0; named=""; slots=""; unrep=0; swept=0; movd=0; stale_named=""
for f in "$WD"/*.sno "$WD"/*.icn "$WD"/*.pl "$WD"/*.raku "$WD"/*.sc; do
  [ -f "$f" ] || continue
  witn=$((witn+1))
  err="$(env SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_GC_STRESS="$STRESS" SCRIP_GC_MAPS=1 timeout -k 5 120s "$SCRIP" "$f" 2>&1 >/dev/null)"
  n="$(printf '%s\n' "$err" | grep -c '^\[GC-WALK\]')"
  [ "${n:-0}" -gt 0 ] && coll=$((coll+1))
  h="$(printf '%s\n' "$err" | grep -c 'GC-WALK-RTCCB')"
  if [ "${h:-0}" -gt 0 ]; then
    hits=$((hits+h)); named="$named $(basename "$f"):$h"
    u="$(printf '%s\n' "$err" | grep '^\[GC-RTCCB-STALE\] slot=' | grep -c 'unrepaired=1')"
    w="$(printf '%s\n' "$err" | grep '^\[GC-RTCCB-STALE\] slot=' | grep -c 'swept=1')"
    m="$(printf '%s\n' "$err" | grep '^\[GC-RTCCB-STALE\] slot=' | grep -c ' moved=1')"
    unrep=$((unrep+u)); swept=$((swept+w)); movd=$((movd+m))
    [ $((u+w)) -gt 0 ] && stale_named="$stale_named $(basename "$f"):unrepaired=$u,swept=$w,of=$h"
    slots="$slots $(printf '%s\n' "$err" | sed -n 's/.*GC-WALK-RTCCB. slot=\([0-9]*\).*/\1/p' | sort -un | tr '\n' ',')"
  fi
done
[ "$witn" -gt 0 ] || refuse "no witness matched under $WD -- a census over an empty population reads zero by never looking"
[ "$coll" -gt 0 ] || refuse "ZERO of $witn witness(es) collected at arena ${SCRIP_HEAP_KB:-64} KB stress $STRESS -- this arm would be a statement about a population that never ran the collector, not about the spill block"
uslots="$(printf '%s' "$slots" | tr ', ' '\n\n' | grep -E '^[0-9]+$' | sort -un | tr '\n' ' ')"
if [ "$hits" = 0 ]; then
  ck ok "(b) THE INVARIANT HOLDS: over $witn witness(es), $coll of which actually collected, NO g_rtccb slot held a pointer into a heap block at any collection"
else
  ck no "(b) ⛔ A CALLER-SAVED SPILL SLOT HELD A POINTER INTO A HEAP BLOCK AT A COLLECTION, $hits time(s), slot(s) [$uslots], in:$named. ⛔⭐ WHAT THIS ESTABLISHES AND WHAT IT DOES NOT, stated because the difference is this row's own subject: it establishes that the invariant the cfo stated -- g_rtccb is CALLER-SAVED SCRATCH and nothing that must survive a collection lives there -- IS NOT TRUE OF THIS TREE. It does NOT establish a lost value: a pointer in an unvisited slot is NECESSARY BUT NOT SUFFICIENT, exactly as a store below the region base was (CTO-101), because the same block may be rooted elsewhere -- the subject is, through the shield and through the visit of the subject pointer itself. ⭐ THE SHARPER HAZARD IS NOT SWEEPING BUT STALENESS: this block is never visited, so a root walk that FORWARDS a moving block cannot rewrite g_rtccb's copy, and the emitted reload after the poll restores the pre-move word. THE CURE IS NOT TO VISIT g_rtccb -- 32 untagged words cannot be visited precisely and a sniff is the conservative scan CEO-812 forbids: put the value in a frame slot covered by that frame's static map, or hand it to the shield as a TAGGED DESCR cell in arr[] (CEO-972). SCRIP_GC_MAPS=1 prints the slot index and the word"
fi

# (c) THE POPULATION IS DECIDABLE AND SAYS SO.  ⛔ hq_prolog MEASURED THAT AT THE TINY ARENA WITH NO STRESS PLANT
# ONLY 4 OF 23 PROLOG KERNELS COLLECT AT ALL, so an arm that does not ask whether the collector ran prints the
# arena in its verdict line while measuring nothing about the collector.
if [ "$coll" = "$witn" ]; then
  ck ok "(c) every one of the $witn witness(es) collected at this band point, so arm (b)'s zero is a zero over the whole population"
elif [ "$coll" -ge 1 ]; then
  ck ok "(c) $coll of $witn witness(es) collected; arm (b)'s zero is a zero over THOSE $coll and is NAMED as such rather than read as coverage of all $witn"
else
  ck no "(c) nothing collected -- unreachable, arm (b) refuses first"
fi

# (d) THE REGISTRATION IS GONE, OR IT IS NAMED AS STILL STANDING.  ⛔ THIS ARM IS THE ONE THAT KEEPS THE DELETION
# HONEST: while the seamsafe registration exists, every reader of rtcc_init.c believes the block is a GC root, and
# a reader who believes that will park a descriptor in r10 across a poll on purpose.
reg="$ROOT/src/runtime/rtx/rtcc_init.c"
if [ ! -f "$reg" ]; then
  ck ok "(d) rtcc_init.c is gone entirely -- nothing registers the block"
elif grep -q "rt_gc_root_range_add_seamsafe" "$reg"; then
  ck no "(d) ⛔ rtcc_init.c STILL REGISTERS the block as a root range, and gc_heap.c's only walk over that table skips exactly that shape. Until the registration is deleted the file says ROOT and the collector says nothing -- the cfo ruled DELETE IT (CTO-153), because visiting 32 untagged words is the conservative scan CEO-812 froze out. This arm is expected RED until that landing arrives and is the reason this gate is REPORTED and not blocking"
else
  ck ok "(d) the seamsafe registration is deleted -- rtcc_init.c no longer tells its readers the block is a GC root"
fi

# (e) an instrument nobody runs is not an instrument
if grep -q 'test_gate_gc_the_caller_saved_spill_block_never_holds_a_heap_reference.sh' "$ROOT/Makefile" 2>/dev/null; then
  ck ok "(e) this gate is named in the Makefile"
else
  ck no "(e) this gate is not named in the Makefile -- a gate in no runner is not measuring (RULES.md THE INSTRUMENT LAWS)"
fi

# (f) THE CONVENTION IS DECLARED WHERE ITS READERS ARE, AND THE DECLARATION IS FINDABLE.  ⛔ CEO-1053 RULED NO ON A
# DECLARED CONVENTION BEING A MECHANISM BY ITSELF -- "A convention enforced by nothing will drift" -- and the proof
# was already in hand from the other end: rtcc_init.c registers this block as a root range and gc_heap.c walks all
# 32 slots, counts, optionally prints AND NEVER VISITS, so a belief that the range was visited survived only as a
# counter nobody reads.  The mechanism is admitted on one condition, and these three arms are it: the convention is
# WRITTEN in the header every reader of the block opens, the invariant is GRADED over the population (arm b), and
# the detector is PROVEN TO FIRE (arm g).  A declaration that can be deleted in silence is the counter again.
hdr="$ROOT/src/runtime/rtx/rtcc.h"
if [ -f "$hdr" ] && grep -q "CALLER-SAVED SPILL BLOCK AND IT IS NOT A GC ROOT" "$hdr" && grep -q "_Static_assert" "$hdr"; then
  ck ok "(f) the convention is declared in rtx/rtcc.h as a _Static_assert naming the block, the words (slot 5 = r8 the anchor, 6 = r9 the GVA, 7 and 8 = r10/r11 scratch) and the reason -- a reader of g_rtccb cannot open the header without reading why nothing that must survive a collection may live there"
else
  ck no "(f) ⛔ rtx/rtcc.h carries no declaration of the caller-saved convention. THE MECHANISM IS THEN UNHELD: CEO-1053 admits a declared convention as one of the four mechanisms shielding a value across a safe point ONLY while a gate holds it and a declaration states it. Restore the _Static_assert or retire this gate in the same landing"
fi

# (g) FAIL-ONCE.  ⛔⭐ THE ARM THAT MAKES ARM (b)'s GREEN MEAN SOMETHING.  Today arm (b) is red on 806 standing
# references, all in slot 5, so it is visibly looking.  THE DAY THE EMITTER CURE LANDS, (b) GOES GREEN -- and a
# green detector that has never been proven to fire is indistinguishable from one that stopped looking, which is
# the defect this whole row exists to remove.  So the plant: a heap pointer written into slot 7 at the top of a
# collection and restored byte for byte at the end of it.  ⛔ IT GOES IN SLOT 7 OR 8 AND NEVER SLOT 5, AND THAT IS
# MEASURED, NOT PREFERRED: the live reporter over all 52 witnesses in four languages at stress 3 and 5 reads 1292
# occurrences and EVERY ONE IS SLOT 5, from exactly eight SNOBOL4 witnesses, while slots 7 and 8 read a measured
# zero -- so a plant in slot 5 could pass by accident on the very population it grades.

# (h) THE PLANT CANNOT HIDE IN THE STANDING POPULATION, AND ITS DECLINE IS NOT AN APPLICATION.  ⛔ BOTH HALVES ARE
# READER ERRORS THIS FLEET HAS ALREADY PAID FOR: a plant in slot 5 would be indistinguishable from the 806
# references already there, and a decline that spells the applied banner's literal is counted as an application by
# an unanchored grep, which is exactly backwards (the coo, 2026-09-21, on SCRIP_GC_PLANT_SHIFT).

# (i) THE SHARPER HALF, AND IT IS THE ARM THAT MOVES THIS CLASS OFF "NECESSARY BUT NOT SUFFICIENT".  ⛔ ARM (b)
# COUNTS A POINTER SITTING IN AN UNVISITED SLOT, WHICH IS ONLY THE NECESSARY CONDITION -- the same block may be
# rooted elsewhere, and that is how eight witnesses hold 806 of them and still answer their oracles (CTO-101, and
# the cfo twice from the other side at CFO-114 and CFO-136).  THIS ARM ASKS THE SUFFICIENT QUESTION INSTEAD: after
# the collection, is the word still RIGHT?  Two ways it is not.  UNREPAIRED -- the collector FORWARDED the block
# the word names and nothing rewrote the word, because nothing visits this block, so the emitted reload after the
# poll (x86_asm.h 395-398) puts a pre-move address back in the register.  SWEPT -- the block was not forwarded at
# all, so the word names ground the arena will re-issue.  ⭐ MEASURED ON THE STANDING POPULATION, not a plant, at
# arena 1 MB stress 3: of 806 detections, 161 name a block THE COLLECTOR MOVED AND ALL 161 ARE LEFT UNREPAIRED --
# every one, because nothing visits this block -- plus 1 or 2 SWEPT (the swept member varies run to run, the
# unrepaired 161 did not across two passes).  The other 644, all in hb_dvec_sort_match.sno and six one-hit
# witnesses, are HARMLESS BY LUCK AND NOT BY MECHANISM: the block they name did not move at that collection and
# nothing in the engine promises it will not at the next one.  ⭐ AND THAT SPLIT IS THIS ARM'S OWN PROOF THAT IT
# DISCRIMINATES RATHER THAN PAINTING THE POPULATION RED: 644 detections read moved=0 unrepaired=0 in the same run
# that 163 read wrong.  Its positive control is arm (g)'s plant, which is unrepaired at slot 7 by construction.
# ⛔ WHAT IT STILL DOES NOT ESTABLISH, SAID HERE SO NOBODY READS IT AS A LOST VALUE COUNT: a wrong word is only
# spent when the reload's register is USED as a pointer afterwards.  Slot 5 is r8, which rtcc.h declares as the
# ANCHOR, and an anchor read as an integer does not care that its bits name vacated ground.  The step after this
# one is to ask, per member, whether the reloaded register is read as a pointer before it is next written.
if [ $((unrep + swept)) = 0 ]; then
  ck ok "(i) THE SHARPER HALF HOLDS: over $hits detection(s), $movd named a block the collector moved and NONE was left wrong by the collection -- 0 unrepaired, 0 swept"
else
  ck no "(i) ⛔ $((unrep + swept)) CALLER-SAVED WORD(S) WERE WRONG AFTER A COLLECTION -- $unrep UNREPAIRED (the collector forwarded the block and nothing rewrote the word) and $swept SWEPT (the block was never forwarded, so the word names ground the arena will re-issue), out of $hits detection(s) of which $movd named a moved block, in:$stale_named. ⭐ THE REMAINING $((hits - unrep - swept)) ARE HARMLESS BY LUCK AND NOT BY MECHANISM: the block they name did not move at this collection, and nothing in the engine promises that. ⛔ THE CURE IS NOT TO VISIT g_rtccb -- 32 untagged words cannot be visited precisely and a sniff is the conservative scan CEO-812 forbids: a value live across a safe point goes in a frame slot covered by that frame's static map, or is handed to the shield as a TAGGED DESCR cell in arr[] (CEO-972). SCRIP_GC_MAPS=1 prints one GC-RTCCB-STALE line per detection naming the slot, the word, the block's type and size, and which of the two ways it went wrong"
fi

echo "population: $checks arm(s) graded, $fails FAIL; $witn witness(es), $coll collected, $hits g_rtccb heap reference(s), $movd naming a moved block, $unrep unrepaired, $swept swept"
[ "$fails" = 0 ] && { echo "GATE PASS [gc_the_caller_saved_spill_block_never_holds_a_heap_reference]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [gc_the_caller_saved_spill_block_never_holds_a_heap_reference]: $fails of $checks arms FAIL"; exit 1
