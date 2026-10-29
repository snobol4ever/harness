#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_ir_slope.sh -- THE TWO-NUMBER BASIS FOR **SLOPE** KERNELS, MEASURED AS AN Ir REGRESSION.
# Row readme-perf-grids-three-angles-all-seven (I26), hq_P 2026-09-03, ceo audit CEO-192.
#
# ⛔⭐ WHY THIS EXISTS AND WHY bench_two_number_ir.sh IS NOT ENOUGH -- MEASURED, NOT THEORISED.
# A benchmarks/snobol4 kernel is not a whole program you run once: it exposes a `*BENCH kernel=NAME`
# entry point and a harness LOOPS it N times, so its published number is a SLOPE with startup divided
# away. Running such a kernel once (which is what a whole-program Ir board does) answers a DIFFERENT,
# NARROWER QUESTION -- "what does one default-sized run cost, startup included" -- and nothing in the
# output says so. hq_P measured the consequence on this row: a whole-program Ir board over the 21
# SNOBOL4 kernels put 12 of them into the CEO-173 >=50%-startup refusal and printed multiples as low
# as 0.140x, because SCRIP's 2.79M-Ir process startup swamped kernels doing ~80K Ir of actual work.
# Those numbers were all correctly measured and all answering the wrong question (RULES.md § THE
# INSTRUMENT LAWS, batch 15 §1 -- the instrument that answers a narrower question never says so).
#
# THE METHOD -- A REGRESSION, WHICH GIVES **BOTH** NUMBERS OF THE TWO-NUMBER BASIS EXACTLY.
# Build the same kernel at N, 2N and 4N iterations (../harness/scripts/bench_wrap.sh --mode=iter), count Ir for
# each, and fit the straight line Ir(n) = OVERHEAD + n*WORK:
#   WORK     = the SLOPE     = instructions per iteration -- startup CANCELS EXACTLY in the difference,
#              it is not estimated and not subtracted from a separate empty program.
#   OVERHEAD = the INTERCEPT = Ir(N) - N*WORK -- process startup + one-time setup, its own number.
# ⭐ This is strictly better than the law's "marked interim" (empty-program subtraction): the interim
# approximates startup with a DIFFERENT program's startup, while the intercept measures THIS program's
# own. It is the same two numbers the law asks for, obtained without the subtraction that CEO-173 had
# to add a refusal for.
#
# THE ADEQUACY CHECK IS BUILT IN, AND IT IS THE Ir ANALOGUE OF THE ANGLE-1-vs-ANGLE-2 CROSS-PROOF.
# Two independent slopes are computed -- from (N,2N) and from (2N,4N). If the kernel is in its linear
# regime they agree; if it is not (a kernel whose per-iteration cost grows, an N too small to have left
# the setup transient), they diverge and the row prints NONLINEAR instead of a number. That is exactly
# what angles 1 and 2 do for each other on the wall clock, minus the noise: RULES.md calls the
# triangulation "itself the adequacy check that the measurement ran long enough".
# ⛔ WHAT THIS DOES NOT MEASURE: Ir counts instructions retired, not cycles. It cannot see cache
# misses, branch mispredicts or memory stalls, so it is NOT a wall-clock predictor and never replaces
# the timed angles -- it answers "how much work does the engine do per iteration", which is the
# question the WORK column asks. Every grid fed by it says so.
#
# EXIT: 0 = board printed, 1 = a kernel was UNPROVEN/NONLINEAR, 2 = REFUSED.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="$HERE/../../SCRIP/out"
TMO="${IR_TIMEOUT:-900}"
BASE_N="${BASE_N:-160}"      # fallback only; N is calibrated per kernel below
TARGET_IR="${TARGET_IR:-60000000}"   # aim each measured run at ~60M Ir: deep into the linear regime, seconds under callgrind
LIN_TOL="${LIN_TOL:-2}"          # percent; Ir is deterministic so real nonlinearity is what shows up
ONLY="${KERNELS:-}"
refuse() { echo "⛔ Ir SLOPE BOARD REFUSED (rc=2): $*" >&2; exit 2; }
[ -x "$SCRIP_BIN" ] || refuse "scrip not built at $SCRIP_BIN."
command -v valgrind >/dev/null 2>&1 || refuse "valgrind not on PATH."
. "$HERE/lib_ir_measure.sh" 2>/dev/null || refuse "cannot load lib_ir_measure.sh -- this board will not read Ir by hand."
. "$HERE/lib_perf_fmt.sh"     2>/dev/null || refuse "lib_perf_fmt.sh unloadable (the ONE multiple-printing authority)."
# CEO-743 welded a load stamp onto every standalone perf_mult/perf_pct. THIS SCRIPT COMPOSES ITS OWN CELLS
# from captured multiples, so the stamp must not land INSIDE a cell -- it is emitted once, above, with the
# shared axes, which is where the FACT RULE says a grid names anything it shares.
PERF_STAMP_OFF=1
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable (the ONE oracle-path authority)."
SBL="$(sbl_clean_bin)"; [ -x "$SBL" ] || refuse "clean SPITBOL benchmark oracle absent: $SBL"
SBL_FLAGS="$(sbl_lang_flags)"
B="$S4E/corpus/benchmarks/snobol4"
[ -d "$B" ] || refuse "kernel dir missing: $B"
W="$(mktemp -d "${TMPDIR:-/tmp}/irslope.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$W"' EXIT
# ⛔⭐ THE EXIT-STATUS VOID WAS ALREADY RIGHT HERE; WHAT WAS MISSING IS THE REASON.  Returning silence for a
# crashed arm is correct arithmetic and a bad record: downstream this became a bare `UNPROVEN`, identical to
# the one printed when valgrind is not installed at all.  ⭐ "not measured" and "measured and thrown away"
# are different facts, and a board that prints one word for both has destroyed the difference -- so the void
# stays (the slope math needs the empty), and the WHY now goes to stderr.  Rule: lib_ir_measure.sh.
ir_of() {  # argv -> Ir, or NOTHING unless the program exited 0 -- with the reason on stderr when it is nothing
  local v; v="$(IR_TMO="$TMO" ir_measure "$@")"
  if ir_is_number "$v"; then echo "$v"; return 0; fi
  echo "⚠ Ir arm voided: $(ir_cell "$v") for [$*] -- $(ir_reason "$v")" >&2
  return 0
}
build_at() {  # $1=kernel-src $2=N -> path to wrapped source, or empty
  # ⛔ SPLIT, NOT ONE `local` LINE: bash expands ALL of a `local` builtin's arguments BEFORE it performs
  # any of the assignments, so `local n="$2" o="...$n..."` reads $n while it is still unset -- which
  # under `set -u` aborts the function and reported every kernel as UNPROVEN(wrap).
  local src="$1" n="$2"
  local o="$W/k_$n.sno"
  bash "$HERE/bench_wrap.sh" "$src" -o "$o" --mode=iter --n="$n" >/dev/null 2>&1 || return 0
  [ -s "$o" ] || return 0; echo "$o"
}
ir_m3() { ir_of "$SCRIP_BIN" --run "$1" < /dev/null; }
ir_sbl(){ ir_of "$SBL" $SBL_FLAGS "$1" < /dev/null; }
ir_m4() {
  local f="$1" d; d="$(mktemp -d "$W/m4.XXXXXX")"
  "$SCRIP_BIN" --compile "$f" --out="$d/p.s" < /dev/null >/dev/null 2>&1 || return 0
  gcc -no-pie "$d/p.s" -o "$d/p.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -lpthread >/dev/null 2>&1 || return 0
  ir_of "$d/p.bin" < /dev/null
}
TREE="$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null || echo '?')"
CTREE="$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "IR_SLOPE lang=snobol4 tree=SCRIP $TREE corpus $CTREE RT_OPT=-O0 instrument=callgrind-Ir-regression date=$(date -u +%Y-%m-%d)"
echo "  basis: Ir(n) = OVERHEAD + n*WORK fitted at n = $BASE_N / $((BASE_N*2)) / $((BASE_N*4)); WORK is the SLOPE"
echo "         (Ir per iteration, startup cancelled exactly), OVERHEAD is the INTERCEPT (its own number)."
echo "         Linearity cross-check: slope(N,2N) vs slope(2N,4N) must agree within ${LIN_TOL}% or the row reads NONLINEAR."
echo "         Multiple = SPITBOL WORK / SCRIP WORK (FASTER axis: above 1.00x SCRIP does less work per iteration)."
echo "  instrument = callgrind Ir regression, LOAD-IMMUNE: no load stamp is required on this board (CEO-743 binds"
echo "         wall-clock numbers). For the record the box was at $(perf_load_stamp)."
printf '%-20s %9s %13s %13s %13s %13s %13s %11s  %s\n' kernel "N" "m3 WORK/it" "m4 WORK/it" "sbl WORK/it" "m4 OVERHEAD" "sbl OVERHEAD" "linearity" "x vs SPITBOL (m4)"
N=0; RC=0
for src in "$B"/*.sno; do
  [ -f "$src" ] || continue
  k="$(basename "$src" .sno)"
  case "$k" in *_twin) continue;; esac
  [ -z "$ONLY" ] || case " $ONLY " in *" $k "*) ;; *) continue;; esac
  grep -q '^\*BENCH kernel=' "$src" || continue          # only reps-capable kernels have a slope
  # ---- CALIBRATE N PER KERNEL, DO NOT ASSUME ONE N FITS ALL ----------------------------------
  # ⛔ A FIXED BASE_N IS WRONG BY CONSTRUCTION HERE: these kernels differ by orders of magnitude in
  # per-iteration cost (SCALE.tsv commits N=90,000,000 for arith_loop and far less for the recursive
  # ones), so one N either starves the cheap kernels out of their linear regime -- measured: array_sum
  # read NONLINEAR on the SPITBOL arm at N=40 and went linear and stable at N=160/400 -- or buries the
  # expensive ones under callgrind's ~50x slowdown. So probe the kernel cheaply, then choose N to hit a
  # fixed INSTRUCTION budget, which is the thing that actually bounds both the runtime and the noise.
  probe_a="$(build_at "$src" 4)"; probe_b="$(build_at "$src" 12)"
  n1="$BASE_N"
  if [ -n "$probe_a" ] && [ -n "$probe_b" ]; then
    pa="$(ir_m4 "$probe_a")"; pb="$(ir_m4 "$probe_b")"
    if [ -n "$pa" ] && [ -n "$pb" ]; then
      n1="$(awk -v a="$pa" -v b="$pb" -v tgt="$TARGET_IR" -v dflt="$BASE_N" 'BEGIN{
             s=(b-a)/8; if (s<=0) { print dflt; exit }
             n=int(tgt/s); if (n<8) n=8; if (n>2000000) n=2000000; print n }')"
    fi
  fi
  n2=$((n1*2)); n3=$((n1*4))
  f1="$(build_at "$src" "$n1")"; f2="$(build_at "$src" "$n2")"; f3="$(build_at "$src" "$n3")"
  if [ -z "$f1" ] || [ -z "$f2" ] || [ -z "$f3" ]; then printf '%-20s %13s\n' "$k" "UNPROVEN(wrap)"; RC=1; continue; fi
  declare -A SLOPE OVH LIN
  for eng in m3 m4 sbl; do
    case $eng in m3) a=$(ir_m3 "$f1"); b=$(ir_m3 "$f2"); c=$(ir_m3 "$f3");;
                 m4) a=$(ir_m4 "$f1"); b=$(ir_m4 "$f2"); c=$(ir_m4 "$f3");;
                 sbl) a=$(ir_sbl "$f1"); b=$(ir_sbl "$f2"); c=$(ir_sbl "$f3");; esac
    if [ -z "$a" ] || [ -z "$b" ] || [ -z "$c" ]; then SLOPE[$eng]=""; OVH[$eng]=""; LIN[$eng]="UNPROVEN"; continue; fi
    read -r s o l <<<"$(awk -v a="$a" -v b="$b" -v c="$c" -v n="$n1" -v tol="$LIN_TOL" 'BEGIN{
        s1=(b-a)/n; s2=(c-b)/(2*n);
        if (s1<=0 || s2<=0) { print "0 0 NONLINEAR"; exit }
        d=(s1>s2? (s1-s2)/s2 : (s2-s1)/s1)*100;
        printf "%d %d %s", s2, a-n*s1, (d<=tol? "ok" : "NONLINEAR");
      }')"
    SLOPE[$eng]="$s"; OVH[$eng]="$o"; LIN[$eng]="$l"
  done
  lin="${LIN[m4]:-?}/${LIN[sbl]:-?}"
  if [ -n "${SLOPE[m4]:-}" ] && [ -n "${SLOPE[sbl]:-}" ] && [ "${LIN[m4]}" = ok ] && [ "${LIN[sbl]}" = ok ]; then
    mult="$(perf_mult "${SLOPE[sbl]}" "${SLOPE[m4]}")"
  else mult="-"; RC=1; fi
  printf '%-20s %9s %13s %13s %13s %13s %13s %11s  %s\n' "$k" "$n1" "${SLOPE[m3]:-NA}" "${SLOPE[m4]:-NA}" "${SLOPE[sbl]:-NA}" "${OVH[m4]:-NA}" "${OVH[sbl]:-NA}" "$lin" "$mult"
  N=$((N+1))
done
echo "IR_SLOPE_BOARD lang=snobol4 kernels=$N base_n=$BASE_N"
[ "$N" -gt 0 ] || refuse "no kernel measured -- a grid of nothing is not a measurement."
exit $RC
