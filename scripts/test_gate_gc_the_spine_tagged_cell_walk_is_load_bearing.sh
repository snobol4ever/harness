#!/usr/bin/env bash
# test_gate_gc_the_spine_tagged_cell_walk_is_load_bearing.sh -- THE LICENCE FOR THE SPINE-CELL VERDICT IN THE
# SAFE-POINT CONTRACT CHECKER (cto 2026-09-22, MODE DUO/QUARTET; row gc-the-planner-gives-every-call-result-live-
# across-a-safe-point-a-slot-the-map-covers; ARCH-GC section 2b RULE 1a and section 3b, CEO-996/1108).
#
# WHAT IS HELD HERE, IN ONE SENTENCE.  util_gc_safe_point_contract.py stopped calling 222 findings over 111 sites
# K3 MEMBERS and started calling them SPINE-CELL, on the ground that a call result stored as rax at a 16-byte
# aligned k and rdx at k+8 below the region base is a TAGGED DESCR CELL, which ARCH-GC section 2b RULE 1a covers
# through gc_cell_visit inside gc_walk_words and which no frame map was ever meant to cover.  RECLASSIFYING A
# POPULATION IS EXACTLY HOW AN INSTRUMENT GOES QUIET WHILE LOOKING BUSY, so the reclassification is not allowed
# to rest on a reading of the design page.  This gate switches the mechanism OFF and requires the tree to notice.
#
# THE EXPERIMENT.  SCRIP_GC_NO_SPINE_CELL=1 makes gc_walk_words skip gc_cell_visit for the spine class ALONE --
# the mapped interior, the header words and the above-root range are untouched, so the only thing removed is the
# mechanism under test.  MEASURED over the declared 52-witness contract floor at SCRIP_HEAP_MB=1,
# SCRIP_GC_STRESS=3,: 16 witnesses change their answer, 15 of them from the 23 that carry a
# BELOW-REGION store.  hb_datblk dumps core, hb_nv trips the ZGC-STALE trap on a stale pointer, and
# hb_mkexpr_unmapped_spine_store -- the witness ARCH-GC section 3b is named after -- goes match to nomatch.
#
# ⛔ WHAT A GREEN HERE DOES NOT SAY.  It does not say the spine walk is as strong as a map: the walk FINDS a cell
# by stepping 8 bytes and trying, so a false cell earlier in the range can put it out of phase, and a tag word
# overwritten before the collection drops the cell to a raw word.  The grid half of that is held next door by
# test_gate_gc_the_spine_cell_grid_is_anchored_at_the_region_base.sh.  Making the coverage STATIC instead of
# discovered is still the planner's open row.  This gate says only: the mechanism the SPINE-CELL verdict names is
# LOAD-BEARING TODAY, so the verdict is a naming of a real covering road and not an amnesty.
#
# ⛔ AND IT IS WRITTEN TO EXPIRE.  Arm (c) NAMES every declared witness that no longer changes its answer.  When a
# planner cure moves these results into mapped slots the set empties, arm (b) goes red on purpose, and the answer
# is to RETIRE the SPINE-CELL verdict and re-cut the floor -- never to widen the population until the arm passes.
#
# ⛔ TWO OPERATIONAL FACTS THAT COST THE FLEET SOMETHING TODAY, BOTH MEASURED, BOTH BUILT IN HERE.
# (1) THE MEMORY BOUND, AND THE LEVER IS A CGROUP RATHER THAN A ulimit BECAUSE THE cfo MEASURED THE ulimit AND IT
#     IS A FORMALITY.  The B leg of this experiment on hb_dvec_sort_match read 26,857,344 KB peak RSS against
#     19,712 KB for the A leg, AND EXITED ZERO -- a lost root does not only print a plausible wrong answer, it can
#     commit the whole machine first, and no rc, no timeout and no arena cap sees it, because the arena cap bounds
#     the collected heap and not what the mutator asks malloc for (the cfo caught this one as a 1 GB-available box
#     at 10:51 and could not name its owner; it was mine).  RLIMIT_RSS is a no-op on this kernel, so the obvious
#     lever is ulimit -v -- and ulimit -v bounds RESERVED ADDRESS SPACE, which is not the quantity that hurt
#     anyone.  ⛔ THE cfo's READING, ON THEIR TREE AND AGAINST MY FIRST CUT: hb_defer_subject at the DEFAULT arena
#     aborts at 4 GB AND at 6 GB with the heap reserve mmap failing, runs at 8, and its actual peak RSS is 12,780
#     KB -- so the smallest ulimit that does not produce a false abort is 640x the memory the run uses, and at
#     that setting the 27 GB leg would still have been free to take 8.  A ceiling with 640x headroom is not a
#     bound.  ⭐ THEIR LEVER, RE-MEASURED HERE BEFORE IT WAS ADOPTED: systemd-run --user --scope with
#     MemoryMax=2G and MemorySwapMax=0 bounds RESIDENT pages, so the reserve passes straight through.  On this
#     tree the B leg on hb_dvec_sort_match is SIGKILLed, rc=137, and the A leg is rc=0 with correct stdout.
#     MemorySwapMax is load-bearing: with MemoryMax alone a 3 GB allocation SUCCEEDS by swapping and degrades
#     every seat without tripping anything.  ulimit -v is kept ONLY as the fallback where systemd-run is absent,
#     at 8 GB, which is the floor both trees agree on -- and the fallback SAYS SO in the population line rather
#     than pretending the two bounds are the same thing.  ⛔ MY OWN FIRST CUT AT 4 GB CRASHED hb_coexpr_sigma.icn
#     IN THE CONTROL ARM (a co-expression is a pthread with its own mmap'd stack), which is a gate-made crash that
#     reads exactly like a defect, and it is the second reason the cgroup is the right home for this.
# (2) setarch -R, ON THE coo's RULING OF THE SAME MORNING.  A cell graded once is a sample: 20 identical runs of
#     one Icon cell read CRASH 18 PASS 2 under ASLR and SEGV 20 of 20 under setarch -R, while a genuinely green
#     cell read rc=0 20 of 20 under both.  The flaky outcome is the PASS, so the variance runs in the direction
#     that closes rows.  Pinned in the GATE and never on an acceptance board, where the flake is a real shipped
#     silent-wrong-answer rate and pinning it would configure away a severity rather than measure it.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="$ROOT/scrip"
WITDIR="$ROOT/../harness/scripts/gc_witnesses"
FLOOR="$ROOT/../harness/scripts/gc_safe_point_contract_floor.tsv"
VBOUND="${SPINE_AB_VBOUND:-8388608}"
if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope -q -p MemoryMax=2G -p MemorySwapMax=0 /bin/true >/dev/null 2>&1; then
    CAP="cgroup MemoryMax=2G MemorySwapMax=0 (the cfo's lever, CFO 2026-09-22: a RESIDENT bound, not an address-space formality)"
    cap_run() { systemd-run --user --scope -q -p MemoryMax=2G -p MemorySwapMax=0 "$@"; }
else
    CAP="ulimit -v $VBOUND KB of ADDRESS SPACE -- FALLBACK ONLY, systemd-run is absent; this admits any run whose RESIDENT set fits in 8 GB"
    cap_run() { ( ulimit -v "$VBOUND" 2>/dev/null; exec "$@" ); }
fi
# THE DECLARED NAME SET (the coo's rule: a gate whose population is a directory glob cannot carry a blocking
# verdict when five seats write the directory).  Every member was measured to change its answer under the knob on
# 2026-09-22.  hb_dvec_sort_match and hb_dvec_data_convert are DELIBERATELY OUT despite qualifying: they are the
# two that reach tens of gigabytes in the B leg, and a landing gate is a shared resource.
# ⭐ AND ONE EXCLUSION RESTORED BY THE CURE THAT EARNED IT, KEPT HERE AS THE RECORD RATHER THAN DELETED.
# hb_coexpr_sigma.icn was excluded on 2026-09-22 because it could not pass arm (a): at SCRIP_HEAP_MB=1 with
# SCRIP_GC_STRESS=3 it answered its ref exactly at 14 lines, and adding alone took it to
# 7 LINES AT rc=0 -- half a co-expression's output lost with a zero exit, and a witness whose CONTROL leg is
# red proves nothing about a B leg.  That was the ceo's r13 row and the exclusion said in its own text that
# it went back the moment the row landed.  IT LANDED: SCRIP e42cc0909 turned the bare polls at bb_deref.cpp:39
# and bb_scan_upto.cpp:52 into x86_rt_gc_poll_rec_sigma with keep_rax zero, where the subject base was live in
# r13 across the poll.  RE-MEASURED BY THIS SEAT AT faddd1a00, 80 draws, four cells of 20: relocation OFF and
# ON, crossed with plain ASLR and setarch -R, 20 of 20 PASS AT 14 LINES IN EVERY CELL.  Arm (a) passes and the
# spine knob still changes its answer, so it qualifies for arm (b) as well and is a member again -- which is a
# reading of the ceo's board taken from the enforcement side and independent of it.
# ⛔ AND ONE HELD OUT, NAMED HERE WITH ITS ROW, REPORTED ON EVERY RUN AND NEVER SILENTLY DROPPED (cto 2026-09-22, evening).
# hb_nested_match_outer_subject.sno prints NO for OK-3-y2y under at stress 1, 3, 4, 6 and 8 and answers
# right at 0, 2, 5, 10 and 16 and at every stress WITHOUT relocation, at MB=1 and at the shipped 128 KB alike.  Bisected
# twice with a build per step: on main the first bad commit is the cfo's 58820a280 (the concat-slot bare poll REMOVED),
# and with that poll patched out at every step it is fa1dc84a5 (the asm poll's r13 probe) -- yet REVERTING fa1dc84a5 on
# HEAD leaves this witness red at 4 of 5 stress points and breaks hb_scan_subject_across_allocating_poll.icn at all 5.
# So neither commit is the cause; each only moved WHICH poll collects.  The walker's own telemetry reads s_raw_heap=1
# divergence=1 on main's C-stack walk: ONE RAW HEAP WORD the typed walk cannot see -- the outer match's subject across
# the deferred *GC() call, the unrooted deferred-call class hq_snobol4 owns (the standing chop's blocked bb_match_defer
# site).  A control leg red for a defect another lane owns proves nothing about the B leg, so the witness is HELD OUT:
# its control leg still runs and prints REPORTED below, and it returns to POP in the landing that roots that subject.
HELD_OUT="${SPINE_AB_HELD_OUT:-hb_nested_match_outer_subject.sno}"
POP="${SPINE_AB_POP:-hb_mkexpr_unmapped_spine_store.sno hb_datblk.sno hb_nv.sno hb_eval_names.sno hb_deferexpr_nodefer.sno hb_coexpr_sigma.icn}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [gc_the_spine_tagged_cell_walk_is_load_bearing]: $1"; exit 2; }

[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$FLOOR" ] || refuse "the declared contract floor $FLOOR is missing -- the verdict this gate licenses has no population"
command -v setarch >/dev/null 2>&1 || refuse "setarch is not on this box, so ASLR cannot be pinned and a single graded cell is a SAMPLE whose flaky outcome is the PASS (the coo, 2026-09-22) -- this gate refuses rather than publishing a coin flip"
echo "ARENA SCRIP_HEAP_KB=${SCRIP_HEAP_KB:-64} (the tiny arena of GC testing is the 64 KB floor -- CEO-1146: the old MB=1 knob is a 1024 KB window, eight times the shipped 128 KB, and ran the collector ZERO times on a 3000-string witness; the count of collections is read from the run, never assumed from the knob)"
echo "POPULATION (declared): $(printf '%s\n' $POP | wc -w) witness(es) NAMED above; ASLR pinned with setarch -R; each run bounded by $CAP. SPINE_AB_POP= narrows it."

run_leg() { # $1 witness path, $2 knob value ("" or 1)
    ( if [ -n "$2" ]; then k=1; else k=0; fi
      cap_run env SCRIP_GC_NO_SPINE_CELL="$k" SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_GC_STRESS=3 \
        setarch -R timeout -k 5 60s "$SCRIP" "$1" 2>&1; echo "rc=$?" )
}

# (a) THE CONTROL ARM.  A difference between two legs says nothing unless the A leg is RIGHT.
ctl_bad=""
for w in $POP; do
    p="$WITDIR/$w"; r="$WITDIR/${w%.*}.ref"
    [ -f "$p" ] || { ctl_bad="$ctl_bad $w(missing)"; continue; }
    [ -f "$r" ] || { ctl_bad="$ctl_bad $w(no-ref)"; continue; }
    a="$(run_leg "$p" "" | sed '$d')"
    if [ "$a" != "$(cat "$r")" ]; then ctl_bad="$ctl_bad $w"; fi
done
if [ -z "$ctl_bad" ]; then
    ck ok "(a) CONTROL: every declared witness answers its oracle-cut ref with the mechanism ON, at the tiny arena, stress 3, forced relocation -- the B leg below is a difference from a RIGHT answer and not from another wrong one"
else
    ck no "(a) CONTROL BROKEN, so nothing this gate says about the B leg means anything:$ctl_bad"
fi
for w in $HELD_OUT; do
    p="$WITDIR/$w"; r="$WITDIR/${w%.*}.ref"
    if [ -f "$p" ] && [ -f "$r" ]; then
        a="$(run_leg "$p" "" | sed '$d')"
        if [ "$a" = "$(cat "$r")" ]; then v="ANSWERS ITS REF -- the hold-out can be lifted, put it back in POP"
        else v="still red ($(printf '%s' "$a" | head -c 40 | tr '\n' '|')) -- the unrooted deferred-call subject, hq_snobol4's row"; fi
    else v="missing on disk"; fi
    echo "  REPORTED, NOT GRADED (held out, cto 2026-09-22): $w control leg $v"
done

# (b)+(c) THE LOAD-BEARING ARM, and the expiry that rides with it.
differ=0; same_names=""; differ_names=""
for w in $POP; do
    p="$WITDIR/$w"; [ -f "$p" ] || continue
    a="$(run_leg "$p" "")"; b="$(run_leg "$p" 1)"
    if [ "$a" = "$b" ]; then same_names="$same_names $w"; else differ=$((differ+1)); differ_names="$differ_names $w"; fi
done
if [ "$differ" -gt 0 ]; then
    ck ok "(b) THE MECHANISM IS LOAD-BEARING: $differ of $(printf '%s\n' $POP | wc -w) declared witness(es) change their answer when the spine tagged-cell visit alone is switched off --$differ_names"
else
    ck no "(b) NOT ONE declared witness noticed the spine tagged-cell visit being switched off. Either the knob stopped reaching gc_walk_words, or the planner cure landed and these results now live in mapped slots. EITHER WAY the SPINE-CELL verdict in util_gc_safe_point_contract.py is no longer licensed: RETIRE it and re-cut the floor. Do NOT widen this population until the arm passes."
fi
if [ -z "$same_names" ]; then
    ck ok "(c) EXPIRY WATCH: no declared witness has drifted out of the class"
else
    ck ok "(c) EXPIRY WATCH -- REPORTED, never blocking on its own:$same_names no longer need the spine walk. When this list swallows the whole set, arm (b) goes red BY DESIGN and the verdict retires."
fi

# (d) THE TIE TO THE INSTRUMENT THIS GATE LICENSES.  A licence for a verdict nobody issues is decoration.
sp="$(awk -F'\t' '!/^#/ && NF>=8 {s+=$8} END {print s+0}' "$FLOOR")"
k3="$(awk -F'\t' '!/^#/ && NF>=7 {s+=$5} END {print s+0}' "$FLOOR")"
if [ "$sp" -gt 0 ]; then
    ck ok "(d) the declared floor issues the verdict this gate licenses: spine_cell=$sp over the 52-witness name set (k3=$k3), so the licence is attached to a live population and not to an empty class"
else
    ck no "(d) the declared floor issues NO spine_cell verdict (spine_cell=$sp) -- this gate is licensing nothing, which means either the floor was re-cut without it or the column was dropped"
fi

# (e) PLANTED.  An arm that has never failed is an arm proven by reading.
pa="$(run_leg "$WITDIR/hb_datblk.sno" "")"; pb="$(run_leg "$WITDIR/hb_datblk.sno" "")"
if [ "$pa" = "$pb" ]; then plant=INERT; else plant=NOISY; fi
if [ "$plant" = INERT ]; then
    ck ok "(e) PLANTED -- the same witness run TWICE WITH THE KNOB OFF is byte-identical, so arm (b)'s difference is the knob and not run-to-run noise. This is the arm that fails if setarch stops pinning the address space."
else
    ck no "(e) PLANT BROKEN: two knob-OFF runs of hb_datblk.sno already differ ($plant), so arm (b) cannot attribute anything to the mechanism -- the comparison is measuring noise"
fi

# (f) the gate is in a runner; a gate in no runner is not measuring
if grep -q "test_gate_gc_the_spine_tagged_cell_walk_is_load_bearing.sh" "$ROOT/Makefile" 2>/dev/null; then
    ck ok "(f) this gate is named in the Makefile"
else
    ck no "(f) this gate is in NO runner -- a gate in no runner is not measuring (INSTRUMENT LAWS)"
fi

echo "population: $checks arm(s) graded, $fails FAIL"
if [ "$fails" = 0 ]; then
    echo "GATE PASS [gc_the_spine_tagged_cell_walk_is_load_bearing]: $checks of $checks arms hold"
    exit 0
fi
echo "⛔ GATE RED [gc_the_spine_tagged_cell_walk_is_load_bearing]: $fails of $checks arms FAIL"
exit 1
