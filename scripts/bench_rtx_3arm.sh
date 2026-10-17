#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# ../harness/scripts/bench_rtx_3arm.sh -- RTX-0e: THE THREE-ARM INTERLEAVED HARNESS.
#
# WHY THIS EXISTS (s209, and it retro-qualifies numbers already in the ladder)
# ---------------------------------------------------------------------------
# Every RTX rung before this one graded itself with a TWO-arm A/B: SCRIP_RTX_<FAM>=1
# against SCRIP_RTX_<FAM>=0.  That control is NOT pristine C.  With the gate off,
# every call to a ported symbol still executes:
#
#       endbr64 ; cmp byte ptr [rip+rtx_gate_<fam>],0 ; je c_<sym>@plt ; jmp <C body>
#
# i.e. a gate compare, a TAKEN branch, and a PLT stub indirection -- on EVERY call --
# which a pristine-C build never pays.  Measured s209 on two programs: the OFF arm is
# 5.8% (func_call) and 7.8% (fibonacci) SLOWER than pristine C.  That bias is
#   (a) ONE-DIRECTIONAL: it always flatters the asm, never the C; and
#   (b) LARGER than the +/-3% null floor the ladder grades against.
# A rung reporting "1.07x" from a two-arm A/B may have measured nothing but its own
# kill-switch.  s209's RTX-4 slice 3 did exactly that: 1.066x two-arm, 1.007x vs pristine.
#
# WHAT THIS DOES DIFFERENTLY
#   Three arms, INTERLEAVED WITHIN EACH ROUND so they share the same thermal/scheduler
#   moment, round 1 discarded (hugepage + page-cache warmup), medians reported:
#     PRISTINE  a .so built with the port absent entirely   (the HONEST baseline)
#     OFF       the ported .so, gate 0                      (kill-switch fallback path)
#     ON        the ported .so, gate 1                      (the asm)
#   Arms are selected by LD_LIBRARY_PATH, so ONE scrip binary runs all three and the
#   only thing that varies is the runtime .so -- no recompile, no relink between arms.
#
# WHAT IT REPORTS AND WHY BOTH RATIOS MATTER
#   ON/PRISTINE  <- THE REAL ANSWER. This is what the rung actually bought.
#   ON/OFF       <- the LEGACY two-arm number, printed ONLY so a rung can see how much
#                   of its historical claim was the artifact.
#   OFF/PRISTINE <- the kill-switch tax itself. If this is ~1.00 the family's gate is
#                   cheap (cold symbol); if it is well under 1.00 the family is hot and
#                   any two-arm number for it is suspect.
#
# USAGE
#   ../harness/scripts/bench_rtx_3arm.sh --fam CALL --pristine <dir> --rtx <dir> [-r N] prog.sno ...
#   Both dirs must contain a libscrip_rt.so.  Build them by stashing the port for the
#   pristine one; keep the source tree on the PORTED state afterwards.
#
# CAVEATS THAT MUST TRAVEL WITH ANY NUMBER THIS PRINTS
#   - Label every result with RT_OPT (default -O0; -O2 only if Lon directed it).
#   - Programs must be SELF-TIMED (they must print "ms: <n>"); process startup is
#     excluded on purpose, so these are window ratios, not wall-clock ratios.
#   - This box is noisy (s200 recorded a 1.340/2.497/2.606/0.510 spread on table_access).
#     Medians can separate cleanly while per-run RANGES still overlap -- the script
#     prints every raw sample so that overlap is visible rather than hidden.
#   - A ~1.00 ON/PRISTINE is THE ANSWER, not a failed measurement (s187/s204 rule).
#     State the expected band BEFORE running this.
# ⛔ RETIRED 2026-09-23 -- see the refusal on the next line; the header below is kept as the record of what this measured.
echo "⛔ RETIRED(2) bench_rtx_3arm.sh: superseded 2026-09-23 by ../harness/scripts/bench_triangulate_icon.sh (hq_icon, CEO-567 THE KERNEL CONVENTION, CEO-1221). It read timing the KERNEL printed itself -- rate/*.icn self-timed with &time, rtx/*.icn wrote ms: -- and every Icon benchmark is now a pristine kernel with a .ref and no clock in its source; the harness generates the wrapper and times it (fixed iterations, fixed time, tools/bench_rusage)." >&2; exit 2

set -u
FAM="CALL"; PRISTINE=""; RTX=""; ROUNDS=5; USE_MIN=0; ASLR_OFF=0; RTCC_MODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fam)      FAM="$2"; shift 2 ;;
    --pristine) PRISTINE="$2"; shift 2 ;;
    --rtx)      RTX="$2"; shift 2 ;;
    -r)         ROUNDS="$2"; shift 2 ;;
    --min)      USE_MIN=1; shift ;;
    --aslr-off) ASLR_OFF=1; shift ;;
    --rtcc)     RTCC_MODE=1; shift ;;
    *)          break ;;
  esac
done
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
GATE="SCRIP_RTX_${FAM}"
# RC-0(a) RTCC stability mode: --rtcc collapses all three arms to the same .so with no gate.
# --pristine and --rtx may point to the same dir; ON/OFF are not set (no SCRIP_RTX_* exists yet).
# Reports ON/PRISTINE = 1.000 ±noise to prove the rail is stable before any code changes land.
ASLR_PRE=""; [ "$ASLR_OFF" = "1" ] && ASLR_PRE="setarch -R"

[ -x "$SCRIP" ]                        || { echo "⛔ REFUSED-TO-GRADE: scrip not built"; exit 2; }
[ -f "$PRISTINE/libscrip_rt.so" ]      || { echo "FAIL: no libscrip_rt.so in --pristine '$PRISTINE'"; exit 1; }
[ -f "$RTX/libscrip_rt.so" ]           || { echo "FAIL: no libscrip_rt.so in --rtx '$RTX'"; exit 1; }
[ $# -gt 0 ]                           || { echo "FAIL: no programs given"; exit 1; }

med() { echo "$1" | tr ' ' '\n' | grep -v '^$' | sort -n \
        | awk '{a[NR]=$1} END{ if(!NR){print "NA"; exit} print (NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2 }'; }
# min-of-N: the minimum is stable under hugepage bimodality (s224 diagnosis).
# Use --min when the box shows clean fast/slow bimodal splits that defeat medians.
minof() { echo "$1" | tr ' ' '\n' | grep -v '^$' | sort -n | awk 'NR==1{print; exit} END{if(!NR)print "NA"}'; }
stat()  { if [ "$USE_MIN" = "1" ]; then minof "$1"; else med "$1"; fi; }
ratio() { awk -v a="$1" -v b="$2" 'BEGIN{ if(b+0==0){print "NA"; exit} printf "%.3f", a/b }'; }

# one sample: $1 = .so dir, $2 = gate value ("" = leave unset, pristine has no gate)
run1() {
  local dir="$1" g="$2" prog="$3" out
  if [ -n "$g" ]; then
    out=$(LD_LIBRARY_PATH="$dir" $ASLR_PRE env "$GATE=$g" timeout -k 5 300 "$SCRIP" --run "$prog" </dev/null 2>/dev/null)
  else
    out=$(LD_LIBRARY_PATH="$dir" $ASLR_PRE timeout -k 5 300 "$SCRIP" --run "$prog" </dev/null 2>/dev/null)
  fi
  echo "$out" | awk '/^ms: /{print $2; found=1} END{if(!found) print ""}'
}
# In --rtcc mode there is no gate variable yet; collapse all three arms to the same .so with no env override.
# ON=OFF=PRISTINE by construction; the harness proves its own null floor (should read 1.000 ±noise).
run1_rtcc() {
  local dir="$1" prog="$2" out
  out=$(LD_LIBRARY_PATH="$dir" $ASLR_PRE timeout -k 5 300 "$SCRIP" --run "$prog" </dev/null 2>/dev/null)
  echo "$out" | awk '/^ms: /{print $2; found=1} END{if(!found) print ""}'
}

STAT_MODE=$([ "$USE_MIN" = "1" ] && echo "MIN-OF-N" || echo "MEDIAN")
ASLR_LABEL=$([ "$ASLR_OFF" = "1" ] && echo "ASLR=off(setarch -R)" || echo "ASLR=on")
RTCC_LABEL=$([ "$RTCC_MODE" = "1" ] && echo " [--rtcc: 3 arms = same .so, no gate; proves null floor]" || echo "")
echo "=== RTX 3-ARM INTERLEAVED HARNESS — family $FAM — rounds=$ROUNDS (round 1 discarded) — stat=$STAT_MODE — $ASLR_LABEL$RTCC_LABEL ==="
echo "    pristine=$PRISTINE"
echo "    rtx     =$RTX"
echo "    RT_OPT  =${RT_OPT:--O0 (Makefile default; label every number with this)}"
rc=0
for prog in "$@"; do
  [ -f "$prog" ] || { echo "  SKIP $prog (missing)"; continue; }
  P=""; F=""; N=""
  for r in $(seq 1 "$ROUNDS"); do
    # interleaved WITHIN the round: same moment, same thermal state, rotating order
    if [ "$RTCC_MODE" = "1" ]; then
      # --rtcc: no gate exists; all three arms are identical runs of the same .so (null-floor probe)
      p=$(run1_rtcc "$PRISTINE" "$prog")
      f=$(run1_rtcc "$RTX"      "$prog")
      n=$(run1_rtcc "$RTX"      "$prog")
    else
      p=$(run1 "$PRISTINE" ""  "$prog")
      f=$(run1 "$RTX"      "0" "$prog")
      n=$(run1 "$RTX"      "1" "$prog")
    fi
    if [ "$r" -gt 1 ]; then P="$P $p"; F="$F $f"; N="$N $n"; fi
  done
  mp=$(stat "$P"); mf=$(stat "$F"); mn=$(stat "$N")
  if [ "$mp" = "NA" ] || [ "$mn" = "NA" ]; then
    echo "  $(basename "$prog"): NO 'ms:' WINDOW — program is not self-timed, or it crashed. NOT GRADED."
    rc=1; continue
  fi
  # ARM-STABILITY PRECONDITION (added s209, after ALLOC/string_manip's PRISTINE arm ran
  # 4769 3903 1898 6509 -- a 3.4x spread INSIDE ONE ARM -- and the harness happily printed
  # "2.416x" from it. A median computed over a bimodal or wildly dispersed arm is a coin flip,
  # not a measurement. If any arm's own spread is comparable to the gap BETWEEN arms, the ratio
  # is unsupported and this refuses to print it as a result. table_churn's OFF arm is the other
  # documented shape: 2397 1400 2616 1392 -- BIMODAL, median meaningless, and it is exactly what
  # made the legacy two-arm number read 1.464x against a true 1.084x.
  spread() { echo "$1" | tr ' ' '\n' | grep -v '^$' | sort -n \
             | awk '{a[NR]=$1} END{ if(NR<2||a[1]+0==0){print 0; exit} printf "%.3f", a[NR]/a[1] }'; }
  sp=$(spread "$P"); sf=$(spread "$F"); sn=$(spread "$N")
  gap=$(awk -v a="$mp" -v b="$mn" 'BEGIN{ if(a+0==0||b+0==0){print 0; exit} printf "%.3f", (a>b)?a/b:b/a }')
  worst=$(awk -v x="$sp" -v y="$sf" -v z="$sn" 'BEGIN{m=x; if(y>m)m=y; if(z>m)m=z; printf "%.3f", m}')
  unstable=$(awk -v w="$worst" -v g="$gap" 'BEGIN{ print (w > g) ? 1 : 0 }')
  echo "  $(basename "$prog")"
  echo "      PRISTINE=${mp}ms   OFF=${mf}ms   ON=${mn}ms  [stat=$STAT_MODE]"
  echo "      arm spreads (max/min): PRISTINE=${sp}x OFF=${sf}x ON=${sn}x   |   ON-vs-PRISTINE gap=${gap}x"
  if [ "$unstable" = "1" ] && [ "$USE_MIN" = "0" ]; then
    echo "      ⛔ UNGRADEABLE — worst intra-arm spread (${worst}x) EXCEEDS the inter-arm gap (${gap}x)."
    echo "         The ratio below is NOT a result. Re-run with more rounds, or fix the benchmark."
    rc=1
  elif [ "$unstable" = "1" ] && [ "$USE_MIN" = "1" ]; then
    echo "      ⚠ SPREAD NOTE (--min mode): intra-arm max/min spread (${worst}x) exceeds gap (${gap}x) —"
    echo "        hugepage bimodality present; --min selects the fast-path floor. Treat result as a lower bound."
  fi
  echo "      ON/PRISTINE = $(ratio "$mp" "$mn")x   <-- THE REAL ANSWER"
  echo "      ON/OFF      = $(ratio "$mf" "$mn")x   (legacy two-arm number; the gap vs the line above IS the artifact)"
  echo "      OFF/PRISTINE= $(ratio "$mp" "$mf")x   (the kill-switch tax on this family)"
  echo "      raw PRISTINE:$P"
  echo "      raw OFF     :$F"
  echo "      raw ON      :$N"
done
exit $rc
