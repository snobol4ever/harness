#!/usr/bin/env bash
# util_gc_witness_sweep.sh -- THE SECONDS-SCALE DETECTOR for a safe-point conversion batch (ceo CEO-1109,
# row gc-a-fast-witness-detector-grades-a-safe-point-conversion-batch-in-seconds-proven-against-the-known-bad-insertion).
#
# ⛔ WHY THIS EXISTS, AND THE NUMBER IS THE REASON.  On 2026-09-22 the ceo inserted 77 safe-point polls chosen by
# the callee's DECLARED RETURN CLASS -- VOID or a narrow scalar means nothing wide enough to be a pointer comes
# back in rax -- and the census read 133 -> 210 of 253.  ALL EIGHT PER-LANGUAGE SMOKES PASSED on 26 of them, and
# those 26 still cost 57 Icon programs when the Icon rungs ran: 823/826 m3 on a clean tree against 766/826 with
# the batch, plus a new hang.  The return class says what the CALLEE RETURNS and NOTHING about what is ALREADY
# LIVE in a register at that point -- the scan templates hold the Σ pair in r13/r15d, bb_to/bb_to_by hold the
# generator's state -- so a register-preserving poll hands those back STALE once the block moves.
# ⛔ THE SMOKE ARM IS NOT A DETECTOR FOR A COLLECTOR CHANGE.  The rungs is, and it costs five minutes a pass,
# which is too slow to iterate a hundred-site conversion against.  This sweep is the instrument in between.
#
# HOW IT GETS ITS TEETH, and neither half is optional:
#    every live block relocates on EVERY collection, so a surviving reference to an old address
#                     is wrong IMMEDIATELY rather than eventually.  Measured at 3e1b04476: 84.7% of live-block
#                     forwardings normally leave the block exactly where it was, which is why a lost root so
#                     often prints a plausible answer -- stale in principle and, five times in six, valid in fact.
#   SCRIP_GC_TRAP     (default ON) PROT_NONEs the vacated ground, so reading a stale pointer FAULTS instead of
#                     quietly returning whatever the arena re-issued.
#   a tiny arena      SCRIP_HEAP_KB=128, the shipped default since CEO-1095 and the peak of exasperation.
#   SCRIP_GC_STRESS   a band, because one point is a configuration and not an exercise.
#
# ⛔ THIS SWEEP IS NOT A BOARD AND NEVER REWRITES A SCORE ROW.  It grades the GC witness set, not a denominator
# anyone ships.  A green here licenses the NEXT step of a conversion, never a landing: the landing verdict is
# still the row's DONE-WHEN plus the cure's own language RUNGS with a clean-tree control arm (CEO-1107).
#
# Usage: util_gc_witness_sweep.sh [--stress "0 3 16"] [--arena-kb 128] [--modes m3|m3,m4] [--list-all]
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"; SCRIP="$ROOT/scrip"; WITDIR="$ROOT/../harness/scripts/gc_witnesses"
BAND="${GC_SWEEP_BAND:-0 5}"; ARENA_KB="${GC_SWEEP_ARENA_KB:-128}"; MODES="${GC_SWEEP_MODES:-m3}"; LIST_ALL=0
while [ $# -gt 0 ]; do case "$1" in
  --stress)   BAND="$2"; shift 2;;
  --arena-kb) ARENA_KB="$2"; shift 2;;
  --modes)    MODES="$2"; shift 2;;
  --list-all) LIST_ALL=1; shift;;
  *) echo "unknown argument: $1" >&2; exit 2;; esac; done
refuse() { echo "⛔ SWEEP REFUSED(2): $1"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -d "$WITDIR" ] || refuse "no witness directory at $WITDIR"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the runtime this sweep would measure is absent"
RTMD5="$(md5sum "$ROOT/out/libscrip_rt.so" 2>/dev/null | cut -c1-12)"
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
DIRTY=""; [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ] && DIRTY="-DIRTY"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0; crash=0; hang=0; graded=0; norefs=0; names=""
for src in "$WITDIR"/*.icn "$WITDIR"/*.sno "$WITDIR"/*.pl "$WITDIR"/*.raku; do
  [ -e "$src" ] || continue
  ref="${src%.*}.ref"
  if [ ! -r "$ref" ]; then norefs=$((norefs+1)); continue; fi
  base="$(basename "$src")"; stdin_f="${src%.*}.in"; [ -r "$stdin_f" ] || stdin_f=/dev/null
  for st in $BAND; do
    graded=$((graded+1))
    ( SCRIP_HEAP_KB="$ARENA_KB" SCRIP_GC_STRESS="$st" \
      timeout -k 5 25s "$SCRIP" "$src" < "$stdin_f" > "$T/out" 2>"$T/err" ) 2>/dev/null; rc=$?
    if [ "$rc" = 124 ]; then hang=$((hang+1)); names="$names $base:s$st:HANG"; continue; fi
    if [ "$rc" -ge 128 ]; then crash=$((crash+1)); names="$names $base:s$st:CRASH(rc=$rc)"; continue; fi
    if diff -q "$T/out" "$ref" >/dev/null 2>&1; then pass=$((pass+1));
    else fail=$((fail+1)); names="$names $base:s$st:DIFF"; fi
  done
done
[ "$graded" -gt 0 ] || refuse "ZERO witness/stress pairs graded -- a denominator of zero is a refusal, not a pass"
FLOOR="$ROOT/../harness/scripts/gc_witness_sweep_floor.tsv"
declared=""; [ -r "$FLOOR" ] && declared="$(grep -v '^#' "$FLOOR" | cut -f1 | tr '\n' ' ')"
newbad=""; dec_hit=""
for x in $names; do
  pair="${x%:DIFF}"; pair="${pair%%:CRASH*}"; pair="${pair%:HANG}"
  if printf '%s\n' $declared | grep -qx -- "$pair"; then dec_hit="$dec_hit $pair"; else newbad="$newbad $x"; fi
done
stale=""
for d in $declared; do printf '%s\n' $dec_hit | grep -qx -- "$d" || stale="$stale $d"; done
nnew=0;   for x in $newbad;  do nnew=$((nnew+1));     done
ndec=0;   for x in $dec_hit; do ndec=$((ndec+1));     done
nstale=0; for x in $stale;   do nstale=$((nstale+1)); done
echo "GC-WITNESS-SWEEP graded=$graded pass=$pass fail=$fail crash=$crash hang=$hang new=$nnew declared=$ndec stale=$nstale band=\"$BAND\" arena_kb=$ARENA_KB modes=$MODES reloc=1 tree=$TREE$DIRTY rt_md5=$RTMD5 norefs=$norefs"
[ "$ndec" = 0 ] || { echo "  DECLARED (standing on origin, named in $(basename "$FLOOR"), counted not silenced):"; for x in $dec_hit; do echo "    $x"; done; }
if [ "$nstale" != 0 ]; then
  echo "  ⛔ $nstale DECLARED pair(s) now PASS -- the floor outlived its defect and would silence the next regression:"
  for x in $stale; do echo "    $x"; done
  echo "SWEEP RED(1): move the cured line(s) out of the floor in the landing that cured them"
  RED=1
fi
if [ "$nnew" != 0 ]; then
  echo "  ⛔ $nnew NEW non-green pair(s). A count without names cannot be triaged:"
  n=0; for x in $newbad; do n=$((n+1)); [ "$LIST_ALL" = 0 ] && [ "$n" -gt 40 ] && { echo "    ... $((nnew-40)) more, re-run with --list-all"; break; }; echo "    $x"; done
  echo "SWEEP RED(1): the witness set does not survive forced relocation at this tree"
  RED=1
fi
[ "${RED:-0}" = 0 ] || exit 1
echo "SWEEP GREEN(0): every graded pair survives forced relocation except $ndec DECLARED ($graded pairs)"
exit 0
