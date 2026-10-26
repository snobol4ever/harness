#!/usr/bin/env bash
# util_gc_decidable_roots.sh -- hq_snocone's DECIDABLE TEST (coo, CEO-818/819 § 7 F6 step 6):
#   CAN A SUITE BE GREEN WHILE THE COLLECTOR DOES NOT FIND THE ROOTS?
#
# The question is decidable with one witness and three runs.  ../harness/scripts/fixtures/gc_roots_witness.sno holds one value of
# EVERY registered zeta slot kind (src/planner/frame_layout.h: ZK_DESCR, ZK_PTR_GC, ZK_PTR_CODE, ZK_RAW) live across the
# whole program and prints all of them at the end, so a lost root is a wrong byte and never a silence:
#
#   ORACLE     sbl -bf                                  -- the reference bytes; no oracle is rc=2, never a verdict
#   QUIET      mode 3 and mode 4, SCRIP_GC_STRESS=0     -- no collection runs: this is what a suite measures
#   COLLECTED  mode 3 and mode 4, SCRIP_GC_STRESS=1     -- with the poison fill ON, so a freed root reads 0xDB
#
# VERDICT (rc):
#   0  NO  -- QUIET green and COLLECTED green: a green reading implies the collector found every kind of root.
#   1  YES -- QUIET green and COLLECTED red: the suites are green because they never collect.  This is the state the
#             frozen design closes; it is the acceptance witness for the walker (F6 step 3) and the typed visitors (5).
#   2  NOT MEASURED -- no oracle, a stale binary, or QUIET itself red (then the red is not about the collector).
#
# Every run prints its bytes beside the oracle's, so the reader re-derives the verdict and never only reads it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || exit 2
W="$HERE/fixtures/gc_roots_witness.sno"
STRESS="${SCRIP_GC_STRESS_N:-1}"
refuse(){ echo "⛔ REFUSED-TO-DECIDE (rc=2): $*"; exit 2; }
[ -f "$W" ] || refuse "no witness at $W"
[ -x ./scrip ] || refuse "no ./scrip binary -- run make"
bash ../harness/scripts/util_require_fresh.sh >/dev/null 2>&1 || refuse "the binary is older than src/ -- could not measure"
# shellcheck source=/dev/null
source ../harness/scripts/lib_oracle_flags.sh 2>/dev/null || refuse "lib_oracle_flags.sh will not source"
SBL="$(sbl_correctness_bin)" || refuse "no correctness oracle (sbl -bf)"
[ -x "$SBL" ] || refuse "the oracle $SBL is not executable"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

ORACLE="$(timeout -k 5 60s "$SBL" -bf "$W" < /dev/null 2>/dev/null)"; orc=$?
[ "$orc" = 0 ] || refuse "the oracle itself exited $orc on the witness -- ORACLE-SWAP PROCEDURE, not a collector verdict"
echo "ORACLE    sbl -bf rc=0, $(printf '%s\n' "$ORACLE" | wc -l) line(s):"
printf '%s\n' "$ORACLE" | sed 's/^/    /'

# mode 4 once: one .s, one link, reused by both runs
m4=""
if ./scrip --compile "$W" > "$TMP/w.s" 2>/dev/null && gcc -c "$TMP/w.s" -o "$TMP/w.o" 2>/dev/null \
   && gcc "$TMP/w.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$PWD/out" -o "$TMP/w" 2>/dev/null; then m4="$TMP/w"; fi
[ -n "$m4" ] || echo "NOTE      mode 4 did not build from the witness -- mode 3 alone decides this run"

run(){  # run <label> <stress> <m3|m4>
  local out rc
  if [ "$3" = m3 ]; then
    out="$(SCRIP_GC_STRESS="$2" SCRIP_GC_POISON=1 timeout -k 5 120s ./scrip "$W" < /dev/null 2>/dev/null)"; rc=$?
  else
    out="$(SCRIP_GC_STRESS="$2" SCRIP_GC_POISON=1 timeout -k 5 120s "$m4" < /dev/null 2>/dev/null)"; rc=$?
  fi
  printf '%s' "$out" > "$TMP/$1.$3.out"; echo "$rc" > "$TMP/$1.$3.rc"
}
grade(){  # grade <label> <mode> -> prints one line, returns 0 green / 1 red
  local rc out lab="$1.$2"
  rc="$(cat "$TMP/$lab.rc")"; out="$(cat "$TMP/$lab.out")"
  if [ "$rc" != 0 ]; then
    echo "  $lab rc=$rc RED -- $( [ "$rc" = 139 ] && echo 'SEGV (a root the collector did not find)' || ([ "$rc" = 124 ] && echo 'HANG' || echo 'nonzero exit') ); last line printed: '$(printf '%s\n' "$out" | tail -1)'"
    return 1
  fi
  if [ "$out" = "$ORACLE" ]; then echo "  $lab rc=0 GREEN -- byte-identical to the oracle"; return 0; fi
  echo "  $lab rc=0 RED -- differs from the oracle:"
  diff <(printf '%s\n' "$ORACLE") <(printf '%s\n' "$out") | sed 's/^/      /' | head -12
  return 1
}

modes=(m3); [ -n "$m4" ] && modes+=(m4)
echo "QUIET     SCRIP_GC_STRESS=0 (no collection runs -- what a green suite measures):"
qred=0; for m in "${modes[@]}"; do run quiet 0 "$m"; grade quiet "$m" || qred=$((qred+1)); done
echo "COLLECTED SCRIP_GC_STRESS=$STRESS SCRIP_GC_POISON=1 (a freed root reads 0xDB):"
cred=0; for m in "${modes[@]}"; do run coll "$STRESS" "$m"; grade coll "$m" || cred=$((cred+1)); done

echo "population: 1 witness x 4 registered kinds (ZK_DESCR ZK_PTR_GC ZK_PTR_CODE ZK_RAW) x ${#modes[@]} mode(s) x 2 arms (quiet, collected)"
if [ "$qred" != 0 ]; then
  echo "⛔ REFUSED-TO-DECIDE (rc=2): the witness is red with NO collection ($qred of ${#modes[@]} quiet arm(s)) -- that red is not about the collector; cure it first"; exit 2
fi
if [ "$cred" = 0 ]; then
  echo "DECIDABLE-TEST rc=0 -- NO: every kind of root survived $STRESS-paced collection in ${#modes[@]} mode(s); a green reading implies the collector found the roots"; exit 0
fi
echo "⛔ DECIDABLE-TEST rc=1 -- YES, DECIDED: the witness is GREEN with no collection and RED in $cred of ${#modes[@]} mode(s) the moment the collector runs."
echo "   A SUITE CAN BE GREEN WHILE THE COLLECTOR DOES NOT FIND THE ROOTS -- the suites are green because they never collect."
echo "   This is the acceptance witness for the walker (§ 7 F6 step 3) and the typed heap visitors (step 5); it goes green only when the walker finds every kind."
exit 1
