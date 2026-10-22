#!/usr/bin/env bash
# test_gate_gc_nv_cell_caches_honour_the_memo_generation.sh -- a cached interior pointer into an NV_t block is wrong
# after every collection, and the cache that holds one must join the invalidation protocol the collector already calls
# (cfo CFO-116, 2026-09-20, SCRIP 621c08866).
#
# MEASURED: `user_function_eval_arbno_replace_branch_2` of the snobol4 rungs, extracted through the harness's OWN
# extract and run with SNO_LIB and the cwd the grader uses, died rc=139 at SCRIP_GC_STRESS=21 and 35 under a 1 MB arena,
# 3 of 3, stable partial md5 ae252bdf. core_gc_roots (core/core.c) followed _var_buckets[192] into a block whose header
# read size=32 type=2 -- DT_S, a STRING -- because rt_dcap_pump's `*cell = d` (pattern_match.c) wrote 16 bytes through a
# DESCR_t* cached before gc_collect_ex slid the heap, landing on the `next` field of the live NV_t named "thy". A
# hardware watchpoint on that field named the writer; the collector's own [GC-SHIFT] banner states the law it broke.
# The protocol already existed and the collector already called it (rt_nv_memo_invalidate, gc_heap.c, six lines after
# the slide) and _var_find_cached already joined it; g_dcap_nv_cell never did. Cure: g_dcap_nv_seen[] compared against
# g_nv_memo_gen at BOTH read sites. Origin vs cured over a 10-point band, 3 of 3: byte-identical at stress
# 0/1/2/3/5/8/13/55, and rc=139 -> rc=0 at 21 and 35.
#
# ⛔⭐ ARM 1 IS GRADED WITH SCRIP_GC_TRAP=0 SINCE 2026-09-21, AND THE KNOB IS DECLARED HERE RATHER THAN HIDDEN.
# The stale-read trap (cfo, rung 1 of ARCH-GC § 9) turns a read of vacated ground into a SIGSEGV at the instruction
# that used the stale pointer. This entry has TWO defects -- the cached DESCR_t* write this gate cured, and the
# a84e1945 wrong answer that is hq_snobol4's row -- and the trap makes the SECOND one die of signal 11 at stress 21
# and 35, measured 3 of 3. An rc-only arm cannot tell that from the first defect coming back, so the GRADED runs use
# the pre-trap configuration where the criterion is exact, and one REPORTED trap-on run per stress point names what
# the trap sees. ⛔ A SIGNAL DEATH UNDER THE TRAP WITH NO [ZGC-STALE] REPORT IS STILL THIS GATE'S RED: the trap must
# CLAIM the death or the death is unexplained, and an unexplained death is the thing this gate exists to catch.
#
# ⛔ THIS GATE GRADES rc ONLY, AND THAT IS DELIBERATE. The entry still prints a WRONG ANSWER under collection
# (a84e1945 at most of the band, present identically on origin) -- a second, independent defect that is hq_snobol4's row.
# Grading stdout here would red on someone else's open defect and make this arm unreadable. A crash is the thing cured
# and a crash is the thing measured.
#
# Arms: (1) BEHAVIOUR -- the witness must not die of a signal at the two stress levels that crashed on origin;
#       (2) STRUCTURE -- every read of g_dcap_nv_key[] that compares a key must also compare g_dcap_nv_seen[], so a
#           future edit cannot generation-check one read site and miss its sibling (the CFO-111 shape: a census
#           complete for the spelling it grepped and not for the thing it named).
# FAIL_ONCE=1 drops the generation check from the structure arm's view to prove arm 2 trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
unset SCRIP_HEAP_MB; : "${SCRIP_HEAP_KB:=128}"; export SCRIP_HEAP_KB
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SUITE="$ROOT/../corpus/tests/snobol4/ALL.sno"; SREF="$ROOT/../corpus/tests/snobol4/ALL.ref"
INC="${INC:-$ROOT/../corpus/include}"
ENTRY=user_function_eval_arbno_replace_branch_2
[ -f "$SUITE" ] && [ -f "$SREF" ] || { echo "⛔ REFUSE(2): snobol4 rungs absent ($SUITE)"; exit 2; }
[ -d "$INC" ] || { echo "⛔ REFUSE(2): the -INCLUDE companion dir is absent ($INC) -- the witness needs its 16 companions"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
python3 "$HERE/corpus_suite_harness.py" extract "$SUITE" "$SREF" "$ENTRY" "$T/w.sno" --out-ref "$T/w.ref" >/dev/null 2>&1 \
  || { echo "⛔ REFUSE(2): the harness's own extract could not materialize $ENTRY"; exit 2; }
[ -s "$T/w.sno" ] || { echo "⛔ REFUSE(2): extract produced an empty witness"; exit 2; }
nincl=$(grep -c -- '-INCLUDE' "$T/w.sno" || true)
[ "$nincl" -ge 16 ] || { echo "⛔ REFUSE(2): witness carries $nincl -INCLUDE lines, expected >= 16 -- a witness without its companions is a different program"; exit 2; }
RC=0; examined=0
echo "ARM 1 -- BEHAVIOUR: no signal death under collection (arena SCRIP_HEAP_KB=$SCRIP_HEAP_KB, entry $ENTRY)"
for ST in 21 35; do
  for i in 1 2 3; do
    examined=$((examined+1))
    ( cd "$T" && SNO_LIB="$INC" SCRIP_GC_STRESS="$ST" SCRIP_GC_TRAP=0 timeout -k 5 120 "$SCRIP" w.sno ) >"$T/o.$ST.$i" 2>"$T/e.$ST.$i"; r=$?
    if [ "$r" -ge 128 ]; then
      echo "  FAIL stress=$ST run=$i rc=$r -- died of signal $((r-128)); a cached DESCR_t* survived a collection (md5 $(md5sum "$T/o.$ST.$i" | cut -c1-8))"; RC=1
    else
      echo "  ok   stress=$ST run=$i rc=$r (stdout md5 $(md5sum "$T/o.$ST.$i" | cut -c1-8) -- NOT graded here, see the banner)"
    fi
  done
  ( cd "$T" && SNO_LIB="$INC" SCRIP_GC_STRESS="$ST" timeout -k 5 120 "$SCRIP" w.sno ) >"$T/t.$ST" 2>"$T/te.$ST"; tr=$?
  if [ "$tr" -ge 128 ] && grep -q ZGC-STALE "$T/te.$ST" 2>/dev/null; then
    echo "  note stress=$ST TRAP ON rc=$tr -- REPORTED, NOT GRADED: $(grep -m1 'QUARANTINED\|SIGSEGV touching' "$T/te.$ST" | sed 's/^\[ZGC-STALE\] *//' | cut -c1-140)"
    echo "       that is this entry's OTHER defect (the a84e1945 wrong answer, hq_snobol4's row) made LOUD AND LOCATED by the stale-read trap, not the cached-DESCR_t* write graded above"
  elif [ "$tr" -ge 128 ]; then
    echo "  FAIL stress=$ST TRAP ON rc=$tr -- died of a signal with NO [ZGC-STALE] report: an UNEXPLAINED death is this gate's defect wherever the trap is, and the trap did not claim it"; RC=1
  else
    echo "  note stress=$ST TRAP ON rc=$tr -- the trap found no stale read at this point (stdout md5 $(md5sum "$T/t.$ST" | cut -c1-8))"
  fi
done
echo "ARM 2 -- STRUCTURE: every g_dcap_nv_key[] comparison is generation-checked"
SRC="$ROOT/src/runtime/pattern_match.c"
[ -f "$SRC" ] || { echo "⛔ REFUSE(2): $SRC absent"; exit 2; }
nsite=0; nbad=0
while IFS= read -r line; do
  case "$line" in *'g_runtime.abi.dcap_nv_key['*'=='*) ;; *) continue ;; esac
  nsite=$((nsite+1)); examined=$((examined+1))
  probe="$line"; [ -n "${FAIL_ONCE:-}" ] && probe="${probe//g_runtime.abi.dcap_nv_seen/g_XXXX_removed}"
  case "$probe" in *'g_runtime.abi.dcap_nv_seen['*) echo "  ok   generation-checked: $(echo "$line" | sed 's/^ *//' | cut -c1-110)" ;;
    *) echo "  FAIL read site compares a key but not the generation: $(echo "$line" | sed 's/^ *//' | cut -c1-110)"; nbad=$((nbad+1)); RC=1 ;; esac
done < "$SRC"
[ "$nsite" -ge 2 ] || { echo "⛔ REFUSE(2): found $nsite g_dcap_nv_key comparison sites, expected >= 2 -- the cache was renamed or removed and this gate is measuring nothing"; exit 2; }
echo "sites=$nsite ungenerationed=$nbad examined=$examined"
[ "$RC" = 0 ] && echo "PASS -- the witness survives collection and every NV-cell cache read is generation-checked" || echo "FAIL"
exit $RC
