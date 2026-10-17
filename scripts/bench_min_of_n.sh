#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# ../harness/scripts/bench_min_of_n.sh -- MIN-OF-N benchmark rail for the SNOBOL4 RTX ladder.
#
# WHY THIS EXISTS. bench_rtx_3arm.sh reports a MEDIAN and refuses on intra-arm spread. s220
# established that on this machine only the MINIMUM is stable, and s224 measured the MEDIAN
# verdict getting WORSE with more rounds (1.071x -> 1.922x on an UNCHANGED binary). A statistic
# that moves on an unchanged binary cannot grade a port, so every speed claim on this ladder has
# been blocked behind this instrument for four sessions running.
#
# THE STATISTIC. Wall time under contention is a MINIMUM plus non-negative noise: an interfering
# process can only ever make a run SLOWER, never faster. The minimum of N is therefore the best
# available estimator of the true cost and is monotone-stable as N grows -- adding rounds can only
# lower it or leave it alone, never flip a verdict the way a median can. We report MIN as THE
# answer and carry med/max/spread only as a health readout on the measurement environment.
#
# HONESTY RULES BAKED IN (they are the whole point):
#   - Every number is labelled with its RT_OPT level. -O0 unless Lon directed otherwise (RULES.md
#     O2-DIRECTED-ONLY). An unlabelled number is not quotable against an optimized oracle.
#   - SPREAD is printed per arm. If spread exceeds SPREAD_WARN% of min, the row is flagged NOISY
#     and the ratio is NOT to be quoted -- it is not refused outright (that hides data), it is
#     marked, because "the window was too short" was FALSIFIED at 5704 ms in s224.
#   - A ratio below RATIO_FLOOR (default 1.10) prints as "~null" per ARCH SNOBOL4-RTX rung 4:
#     NO TWO-ARM NUMBER BELOW ~1.10x IS TRUSTWORTHY on this rail.
#
# USAGE
#   bash ../harness/scripts/bench_min_of_n.sh                        # all benchmarks, gates untouched, N=5
#   N=7 bash ../harness/scripts/bench_min_of_n.sh                    # more rounds
#   ARM_A=on ARM_B=off FAMILY=ARITH bash ../harness/scripts/bench_min_of_n.sh   # A/B one family's kill-switch
#   PROGS="arith_int fibonacci" bash ../harness/scripts/bench_min_of_n.sh
#   ASLR=off bash ../harness/scripts/bench_min_of_n.sh               # pin address layout (setarch -R)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../../SCRIP"
SCRIP="${SCRIP:-$ROOT/scrip}"
BENCH="${BENCH:-$S4E/corpus/benchmarks/snobol4}"
SNO_LIB_DIR="${SNO_LIB_DIR:-$S4E/corpus/library}"
N="${N:-5}"
TIMEOUT="${TIMEOUT:-180}"
RT_OPT="${RT_OPT:--O0}"
SPREAD_WARN="${SPREAD_WARN:-15}"
RATIO_FLOOR="${RATIO_FLOOR:-1.10}"
FAMILY="${FAMILY:-}"
ARM_A="${ARM_A:-}"
ARM_B="${ARM_B:-}"
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
# ASLR DEFAULTS TO **off** (s11).  RC-0(a)'s exit criterion is stated "at ASLR=off (setarch -R)", so the
# instrument defaults to the layout its acceptance test is defined on.  The min-of-N statistic does move with
# the layout draw (measured: min 427ms unpinned vs 448ms pinned), so the min is only a stable floor WITHIN one
# layout -- and for an A/B RATIO, a shared fixed layout removes layout as a variable that differs between arms.
#
# ⛔ DO NOT REPEAT THE "PINNING REDUCES SPREAD" CLAIM -- FALSIFIED HERE (s11).  Measured INTERLEAVED (arms
# alternated run-by-run, so thermal/scheduler drift is shared rather than confounded with the arm), fibonacci,
# unchanged binary, N=12: ASLR=on max/min=1.075 (spread 7.5%) vs ASLR=off max/min=1.085 (spread 8.5%).  Pinning
# did NOT reduce spread; it converts layout variance into a fixed unknown BIAS, and this box drew a slow layout
# (~5% slower across the whole distribution).  A first, SEQUENTIAL measurement had suggested the opposite --
# arm-ordered runs on a 1-core box confound drift with the arm.  Interleave, or do not compare.
#
# ⛔ RC-0(a)'s EXIT CRITERION IS NOT MET IN THIS CONTAINER: it requires max/min <= 1.05x at N=12 with ASLR=off;
# this box measures 1.085x pinned and 1.075x unpinned.  ⇒ NO RATIO BELOW ~1.09x IS TRUSTWORTHY HERE, which
# independently corroborates RATIO_FLOOR=1.10 below.  The rail is not yet an accepted instrument on this box.
ASLR="${ASLR:-off}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built at $SCRIP"; exit 2; }
if [ -n "${PROGS:-}" ]; then LIST=""; for p in $PROGS; do LIST="$LIST $BENCH/$p.sno"; done
else LIST=$(ls "$BENCH"/*.sno 2>/dev/null); fi
[ -n "$LIST" ] || { echo "no benchmarks found under $BENCH"; exit 1; }
# Capability-probe rather than assume: setarch may be missing, or its personality syscall blocked by seccomp
# in a container.  A silently-ignored `setarch -R` would label rows ASLR=off while measuring ASLR=on, which is
# a mislabelled number -- the one thing this instrument exists to prevent.  Degrade loudly instead.
PRE=""
if [ "$ASLR" = "off" ]; then
  if command -v setarch >/dev/null 2>&1 && setarch -R /bin/true >/dev/null 2>&1; then PRE="setarch -R"
  else echo "WARN setarch -R unavailable here -- falling back to ASLR=on; rows are labelled accordingly."; ASLR="on(forced)"; fi
fi
# run one program N times under a given gate setting; echo "min med max" in ms
run_arm() {
    local prog="$1" gate="$2" i s e ms; local times=()
    for i in $(seq 1 "$N"); do
        s=$(date +%s%N)
        if [ -n "$gate" ]; then
            env $gate SNO_LIB="$SNO_LIB_DIR" $PRE timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$prog" </dev/null >/dev/null 2>&1
        else
            env SNO_LIB="$SNO_LIB_DIR" $PRE timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$prog" </dev/null >/dev/null 2>&1
        fi
        e=$(date +%s%N); ms=$(( (e-s)/1000000 )); times+=("$ms")
    done
    printf '%s\n' "${times[@]}" | sort -n | awk '{v[NR]=$1} END{printf "%d %d %d", v[1], v[int((NR+1)/2)], v[NR]}'
}
echo "=== MIN-OF-N BENCH RAIL -- N=$N  RT_OPT=$RT_OPT  ASLR=$ASLR ==="
echo "    statistic of record = MIN (monotone-stable); med/max are environment health only"
if [ -n "$FAMILY" ] && [ -n "$ARM_A" ] && [ -n "$ARM_B" ]; then
    GA=""; GB=""
    [ "$ARM_A" = "off" ] && GA="SCRIP_RTX_${FAMILY}=0"; [ "$ARM_A" = "on" ] && GA="SCRIP_RTX_${FAMILY}=1"
    [ "$ARM_B" = "off" ] && GB="SCRIP_RTX_${FAMILY}=0"; [ "$ARM_B" = "on" ] && GB="SCRIP_RTX_${FAMILY}=1"
    echo "    A/B on SCRIP_RTX_${FAMILY}: A=$ARM_A  B=$ARM_B"
    printf "\n%-26s %10s %10s %8s   %s\n" "program" "A_min(ms)" "B_min(ms)" "B/A" "note"
    for f in $LIST; do
        b=$(basename "${f%.sno}")
        read -r amin amed amax < <(run_arm "$f" "$GA")
        read -r bmin bmed bmax < <(run_arm "$f" "$GB")
        note=""
        [ "$amin" -gt 0 ] && aspr=$(( (amax-amin)*100/amin )) || aspr=0
        [ "$bmin" -gt 0 ] && bspr=$(( (bmax-bmin)*100/bmin )) || bspr=0
        [ "$aspr" -gt "$SPREAD_WARN" ] && note="NOISY(A ${aspr}%)"
        [ "$bspr" -gt "$SPREAD_WARN" ] && note="$note NOISY(B ${bspr}%)"
        ratio=$(awk -v a="$amin" -v b="$bmin" 'BEGIN{ if(a>0) printf "%.3f", b/a; else print "n/a"}')
        below=$(awk -v r="$ratio" -v f="$RATIO_FLOOR" 'BEGIN{print (r<f && r>1/f)?"1":"0"}')
        [ "$below" = "1" ] && note="$note ~null(<${RATIO_FLOOR}x)"
        printf "%-26s %10s %10s %8s   %s\n" "$b" "$amin" "$bmin" "$ratio" "$note"
    done
else
    printf "\n%-26s %8s %8s %8s %8s   %s\n" "program" "min(ms)" "med" "max" "spread%" "note"
    for f in $LIST; do
        b=$(basename "${f%.sno}")
        read -r mn md mx < <(run_arm "$f" "")
        [ "$mn" -gt 0 ] && spr=$(( (mx-mn)*100/mn )) || spr=0
        note=""; [ "$spr" -gt "$SPREAD_WARN" ] && note="NOISY -- do not quote a ratio from this row"
        printf "%-26s %8s %8s %8s %8s   %s\n" "$b" "$mn" "$md" "$mx" "$spr" "$note"
    done
fi
echo
echo "ALL NUMBERS ABOVE ARE RT_OPT=$RT_OPT. Quoting them against an optimized oracle without that label is a false comparison."
