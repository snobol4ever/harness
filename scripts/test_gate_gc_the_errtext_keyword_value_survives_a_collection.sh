#!/usr/bin/env bash
# test_gate_gc_the_errtext_keyword_value_survives_a_collection.sh
#   hq_snobol4 2026-09-20, row `snobol4-errtext-keyword-value-is-an-unrooted-collected-heap-string-so-reading-it-
#   after-a-collection-prints-heap-garbage` (CEO-1019, Lon: "make sure that all language specific constructs at
#   runtime have ROOTED GC allocations"; granted to this seat by the `cfo` as CFO-156).
#
# WHAT IT GATES.  `&ERRTEXT` holds its value in `g_sno_errtext` (keywords.c:34), which takes an
# `rt_heap_strdup_c` block -- memory in the COLLECTED HEAP -- at four write sites (keywords.c:311, keywords.c:341,
# runtime_eval.c:255, runtime_eval.c:489) and is read back at keywords.c:289.  Before this row NO ROOT WALK AND NO
# VISITOR NAMED IT, so a collection between the write and the read reclaimed the block and the keyword read back
# SIX KILOBYTES OF HEAP GARBAGE -- rc=0, no diagnostic, a plausible wrong answer.  Two lines of SNOBOL4 show it.
#
# ⛔ WHY THE SWEEP THAT WAS LOOKING FOR THIS EXACT CLASS COULD NOT SEE IT, WHICH IS THE TRANSFERABLE PART.  The
# CEO-1019 candidate list was built by grepping NON-SCALAR STATICS under src/runtime.  `g_sno_errtext` is NEITHER
# `static` NOR non-scalar -- it fails that filter TWICE -- while sitting in the SAME FILE as two candidates the
# filter does name.  The `cfo`'s `g_sno_defer_cells[4096]` fails it from the opposite direction, being a heap
# address wearing `uint64_t`, and `hq_icon`'s `g_fh` is a C global holding a heap string that no root walk names.
# THE CLASS IS: A POINTER INTO THE COLLECTED HEAP HELD SOMEWHERE A ROOT WALK DOES NOT LOOK -- and NEITHER its
# storage class NOR its declared type is a reliable index of it.  Any declaration-shaped grep under-reports it,
# and THE UNDER-REPORT READS AS A CLEAN SWEEP, which is the same instrument-that-is-not-looking shape as the DT_X
# hole one row over.  The `cfo` has re-cut their sweep's population to the WRITE SITES of the heap-string
# allocators for this reason.
#
# ⭐ WHY THE CURE IS A ROOT AND NOT AN INVALIDATION, because copying the neighbouring cure would have produced a
# QUIETER BUG RATHER THAN A FIX.  CFO-117 cured `g_dcap_nv_cell` by INVALIDATING it against the memo generation:
# correct there, because that slot is a CACHE and a later read may legitimately recompute.  `&ERRTEXT` is not a
# cache -- a later read must return THE SAME VALUE -- so invalidation would make the keyword silently FORGET its
# value instead of printing garbage, and a silent forget is strictly harder to find than six kilobytes of heap.
# THE TEST: if a later read must return the same value, the cure is a ROOT; if it may recompute, the cure is
# INVALIDATION.  (`hq_pascal` drew the same distinction from the other side; the `cfo` is carrying both to
# ARCH-GC.)  `rt_gc_visit_raw` marks the block AND registers the slot, so the value survives the sliding
# compaction rather than merely outliving one mark.
#
# ⛔⭐ THE PLACEMENT IS LOAD-BEARING AND IT IS MEASURED, NOT REASONED -- ARM (c) EXISTS BECAUSE THE OBVIOUS
# PLACEMENT IS A NO-OP.  The visit lives in `kw_errtext_gc_root()`, called from `kw_cset_gc_roots()` BEFORE that
# function's `if (!g_kw_cset_names) return;` early return.  Putting it at the natural spot -- the END of the walk,
# beside the sibling `rt_gc_visit_raw` calls it most resembles -- was BUILT AND MEASURED FIRST: the band came back
# BYTE-IDENTICAL TO BASE, all five reds still red, because a program that never interns a cset leaves
# `g_kw_cset_names` NULL and the walk returns before ever reaching the visit.  ⛔ AN INERT CURE IS WORSE THAN NO
# CURE: it reads as "I rooted it and the band did not move, so the diagnosis is wrong" and sends the next reader
# at the wrong cause with a cure already in the tree.  Arm (c) pins the ORDER so a later edit cannot quietly
# reintroduce it, and the SNOBOL4 witness is deliberately a program that touches no cset keyword.
#
# THE POPULATION, two witnesses, and they are graded by DIFFERENT standards ON PURPOSE:
#   hb_errtext_keyword       ORACLE-GRADED.  `&ERRTEXT = 'ABCDEFGH'` then OUTPUT it.  The oracle says ABCDEFGH;
#                            base printed 6384 bytes of heap at m3 {1,5} and m4 {1,5,25}, fingerprint 31009eac.
#   hb_errtext_eval_capture  STABILITY-GRADED, against its OWN stress-0 answer and NOT against the oracle, and
#                            the reason is named rather than hidden: it reaches `g_sno_errtext` through the EVAL
#                            capture road (runtime_eval.c:255/489), where OUR message text for a parse error
#                            ("parse error: syntax error") differs from the oracle's ("syntax error: missing
#                            operand").  That is a SEPARATE, non-GC, language-correctness defect on this seat's
#                            lane; grading it here would red this gate on somebody else's open bug.  What it can
#                            still say is that the answer does not CHANGE across the band, which is the whole GC
#                            question for it.
# ⛔ AND ITS BASE COLUMN IS A NULL RESULT, LABELLED AS ONE: hb_errtext_eval_capture is GREEN ON BASE at all 34
# points.  It does NOT demonstrate that the cure reaches the other three write sites -- it demonstrates that this
# program does not reach the hazard window.  A NULL RESULT BOUNDS THE PROBE AND NEVER THE CLASS.  The claim that
# all four write sites are covered is STRUCTURAL and is stated as structure: the cure roots the SLOT, not the
# write, so whatever wrote the pointer, the root walk visits the same `g_sno_errtext` -- one slot, one root.
#
# BAND: default 0 1 2 3 4 5 6 8 16 25.  `GC_BAND_FULL=1` walks the full 17 points to 50.
# ⛔⭐ 16 AND 25 ARE IN THE DEFAULT BAND PER CEO-1024 (measured by `hq_raku`, who paid for it by reversing their
# own green: the raku rungs at the tiny arena lost 65 gradings over 36 DISTINCT programs at stress 16, every one
# exit 0 with a plausible wrong answer).  THIS WITNESS ARGUES IT FROM THE OTHER SIDE AND THE SHAPE IS WHY THE BAND
# IS WALKED RATHER THAN SAMPLED: base is RED at m4 25 and GREEN at 10, 12, 16, 20, 30, 35, 40 and 50.  NOT
# MONOTONE, NOT AN INTERVAL.  A two-point DONE-WHEN at 30 and 200 reads clean and banks the defect (CEO-807).
#
# FAIL-ONCE, PROVEN IN BOTH DIRECTIONS ON A COPY BEFORE THIS LANDED, NEVER ASSERTED:
#   arm (b) rc=1  -- backing the cure out of keywords.c reds 5 of 34 oracle arms at exactly m3 {1,5} m4 {1,5,25}
#   arm (c) rc=1  -- moving the visit BELOW the early return leaves arm (c) red with the band byte-identical to
#                    base, which is the measurement that put arm (c) in this gate in the first place
#   refusal rc=2  -- a missing ./scrip, and an EMPTY oracle answer (an empty expectation makes every arm pass)
# ⛔ AND ONE OF THOSE REFUSALS IS HERE BECAUSE THIS GATE COMMITTED THE DEFECT ITSELF, BEFORE IT LANDED.  The
# first version read the ref from "$T/<wit>.ref" -- a path it had verified, compared against the live oracle, and
# then NEVER COPIED TO.  `cat` failed, the expectation was the EMPTY STRING, and all 34 oracle arms went red with
# the witness printing the RIGHT ANSWER (8 bytes) at every one of them.  It failed loudly, which is the only
# reason it was cheap; had the witness also printed nothing it would have PASSED VACUOUSLY over an empty
# expectation.  The guard on a non-empty expectation is now an explicit refusal rather than a consequence.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
G=gc_the_errtext_keyword_value_survives_a_collection
refuse(){ echo "⛔ GATE REFUSES(2) [$G]: $*"; exit 2; }
[ -x ./scrip ] || refuse "no ./scrip binary -- run make"
LIBDIR="$(pwd)/out"
[ -f "$LIBDIR/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the m4 arms could not be built"
# shellcheck source=../harness/scripts/lib_oracle_flags.sh
. ../harness/scripts/lib_oracle_flags.sh 2>/dev/null || refuse "../harness/scripts/lib_oracle_flags.sh did not load -- the oracle is reached by accessor, never by a PATH probe"
SBL="$(sbl_correctness_bin)" || refuse "the GRADING oracle is not reachable by its accessor; a missing oracle prints a full, plausible, entirely false all-FAIL table"
FLAGS="$(sbl_lang_flags)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
WIT=../harness/scripts/gc_witnesses
KW=src/runtime/keywords.c
ORACLE_WIT=hb_errtext_keyword
STABLE_WIT=hb_errtext_eval_capture
if [ "${GC_BAND_FULL:-0}" = 1 ]; then PTS="0 1 2 3 4 5 6 8 10 12 16 20 25 30 35 40 50"; else PTS="0 1 2 3 4 5 6 8 16 25"; fi
for n in "$ORACLE_WIT" "$STABLE_WIT"; do
  [ -f "$WIT/$n.sno" ] || refuse "witness $WIT/$n.sno is missing -- a shorter population is not a greener gate"
  cp "$WIT/$n.sno" "$T/$n.sno"
  ( cd "$T" && timeout -k 5 60s "$OLDPWD/scrip" --compile --out="$n.s" "$n.sno" < /dev/null > /dev/null 2>&1 \
      && gcc -m64 -no-pie -rdynamic "$n.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$n.x4" 2> "$n.ld.log" ) \
      || refuse "mode-4 compile or link failed for $n, so every m4 arm measured nothing ($(head -c 160 "$T/$n.ld.log" 2>/dev/null))"
done
[ -f "$WIT/$ORACLE_WIT.ref" ] || refuse "witness $WIT/$ORACLE_WIT.ref is missing -- there is nothing to grade $ORACLE_WIT against"
"$SBL" $FLAGS "$T/$ORACLE_WIT.sno" > "$T/$ORACLE_WIT.live" 2>&1 || refuse "the oracle did not run $ORACLE_WIT cleanly -- nothing here is graded against our own output"
[ -s "$T/$ORACLE_WIT.live" ] || refuse "the oracle's answer for $ORACLE_WIT is EMPTY; an empty expectation makes every arm pass"
cmp -s "$T/$ORACLE_WIT.live" "$WIT/$ORACLE_WIT.ref" || refuse "the committed ref for $ORACLE_WIT has DRIFTED from the oracle -- committed [$(tr '\n' '|' < "$WIT/$ORACLE_WIT.ref")] vs live [$(tr '\n' '|' < "$T/$ORACLE_WIT.live")]; a ref is cut from the oracle, never from our output"
echo "=== gate: the &ERRTEXT keyword's value survives a collection ==="
echo "    oracle $SBL $FLAGS (ref re-checked live, this run) · SCRIP_HEAP_KB=128 · band: $PTS · modes m3 m4"
fails=0
run_band(){ # $1 witness  $2 want  $3 label
  local n="$1" want="$2" lbl="$3" m N got rc row
  for m in m3 m4; do
    printf '    %-24s %-3s' "$n" "$m"; row=""
    for N in $PTS; do
      if [ "$m" = m3 ]; then got="$(cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 SCRIP_GC_STRESS="$N" timeout -k 5 60s "$OLDPWD/scrip" "$n.sno" < /dev/null 2>&1)"; rc=$?
      else got="$(cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 SCRIP_GC_STRESS="$N" timeout -k 5 60s "./$n.x4" < /dev/null 2>&1)"; rc=$?; fi
      arms=$((arms+1))
      if [ "$got" = "$want" ] && [ "$rc" = 0 ]; then row="$row   ."
      else row="$row   X"; fails=$((fails+1)); redset="$redset $n/$m/$N(rc=$rc,${#got}B)"; fi
    done
    echo "$row  [$lbl]"
  done
}
printf '    %-24s %-3s' "" ""; for N in $PTS; do printf '%4s' "$N"; done; echo
arms=0; redset=""
ORACLE_WANT="$(cat "$WIT/$ORACLE_WIT.ref")"
[ -n "$ORACLE_WANT" ] || refuse "the expectation for $ORACLE_WIT came back EMPTY -- an empty expectation makes every arm pass, and this guard exists because the first version of this gate read the ref from a path it had never copied to and graded 68 arms against nothing"
run_band "$ORACLE_WIT" "$ORACLE_WANT" "ORACLE"
STABLE_REF="$(cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 timeout -k 5 60s "$OLDPWD/scrip" "$STABLE_WIT.sno" < /dev/null 2>&1)"
[ -n "$STABLE_REF" ] || refuse "$STABLE_WIT produced an EMPTY answer with no collection forced; an empty expectation makes every stability arm pass"
run_band "$STABLE_WIT" "$STABLE_REF" "STABILITY vs own stress-0, NOT the oracle -- see header"
echo "------------------------------------------------------------"
ok=0; no=0
ck(){ if [ "$1" = ok ]; then ok=$((ok+1)); echo "  ok   $2"; else no=$((no+1)); echo "  no   $2"; fi; }
if [ "$fails" = 0 ]; then ck ok "(a) BOTH witnesses answer at every one of the $arms arms walked -- the &ERRTEXT block survives every collection point"
else ck no "(a) $fails of $arms arms RED. ⛔ THE UNIT IS THE NAME SET, NEVER THE COUNT, and a band point is a property of WHERE the collection lands:$redset"; fi
if grep -q 'rt_gc_visit_raw(&g_runtime.kw.sno_errtext)' "$KW"; then ck ok "(b) g_sno_errtext is VISITED BY A ROOT WALK -- the slot is marked and registered for the slide, not merely reachable"
else ck no "(b) NO ROOT WALK VISITS g_sno_errtext in $KW. The keyword's value is an unrooted collected heap string again and arm (a)'s green, if it is green, is a lottery over where the plant happens to collect"; fi
ORD="$(awk '/^void kw_cset_gc_roots/,/^}/' "$KW" | grep -n 'kw_errtext_gc_root()\|g_runtime.kw.kw_cset_names) return' | head -2 | cut -d: -f1 | tr '\n' ' ')"
set -- $ORD
if [ "${1:-0}" != 0 ] && [ "${2:-0}" != 0 ] && [ "$1" -lt "$2" ]; then
  ck ok "(c) the errtext visit is called BEFORE kw_cset_gc_roots' early return (lines $1 < $2 of the function) -- measured load-bearing: below it, the cure is INERT and the band reads BYTE-IDENTICAL TO BASE"
else
  ck no "(c) ⛔ THE ERRTEXT VISIT IS NOT ORDERED BEFORE kw_cset_gc_roots' 'if (!g_kw_cset_names) return;' (found positions '$ORD'). THIS IS NOT A STYLE ARM. A program that interns no cset leaves g_kw_cset_names NULL, the walk returns early, and the visit NEVER RUNS -- measured on this row before landing, with the whole band byte-identical to base. An inert cure reads as a refuted diagnosis and sends the next reader at the wrong cause"
fi
echo "------------------------------------------------------------"
if [ "$no" = 0 ]; then
  echo "✅ GATE PASS [$G]: $ok check(s), $arms band arms -- &ERRTEXT is rooted, the root is ordered ahead of the early return, and both witnesses hold across the band"
  exit 0
fi
echo "❌ GATE FAIL(1) [$G]: $no of $((ok+no)) check(s) failed over $arms band arms"
exit 1
