#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_ir_slope.sh -- THE TWO-NUMBER WORK/OVERHEAD BASIS FOR PROLOG KERNELS, AS AN Ir REGRESSION.
# Row prolog-has-no-ir-at-fixed-work-instrument-so-every-speed-number-in-the-lane-is-wall-clock-only
# (hq_prolog 2026-09-16, officer cto). Modelled on bench_ir_slope.sh (snobol4, hq_P, ceo audit CEO-192).
#
# ⛔⭐ WHY THIS EXISTS. MODE line 2 states the speed basis for every language HQ and it ends with an
# Ir-AT-FIXED-WORK CLAUSE BESIDE THE WALL-CLOCK BAR, NEVER INSTEAD OF IT. SNOBOL4 could produce that
# clause; PROLOG COULD NOT. Censused 2026-09-16 over all six bench_prolog_*.sh -- callgrind 0, perf stat
# 0, instructions 0 in every one of them (the two mentions in bench_prolog_wrap.sh are prose in its
# header, not invocations). All three Prolog angles -- vanroy, fixed_iter, perf -- are WALL-CLOCK, so on
# a fleet that routinely sits at load 16 to 34 with ten seats running, a Prolog speed number could not be
# taken at all. This board is LOAD-IMMUNE: Ir is deterministic, so it is the one angle that can be run on
# a busy box, and it was developed on one (load 8, 36 competing scrip/swipl/gprolog processes).
#
# ⛔⭐⭐ THE TWO NUMBERS ARE NEVER SUBTRACTED ACROSS, AND ON PROLOG THAT IS NOT BOOKKEEPING -- IT INVERTS
# THE ANSWER. Measured on nrev at the development of this script: SCRIP m4 WORK 4,543,131 Ir/iteration
# with OVERHEAD 3,474,531 Ir; gprolog WORK 224,837 with OVERHEAD 27,112,888; swipl WORK 230,875 with
# OVERHEAD 53,695,164. On WORK, SCRIP does 20.21x the work of gprolog per iteration. On OVERHEAD it is
# 7.80x CHEAPER. A single-shot whole-program number at a small n is dominated by the oracles' 27M-to-54M
# startup and SHOWS SCRIP WINNING. So any Prolog speed claim taken as one number at one n is reporting
# the ratio of the startups, and the sign of the answer depends on n.
#
# ⛔ WHAT THIS DOES NOT MEASURE, AND THE CLAUSE SITS BESIDE THE WALL CLOCK FOR THIS REASON. Ir counts
# instructions retired, not cycles: no cache misses, no branch mispredicts, no memory stalls. It is NOT a
# wall-clock predictor. corpus/benchmarks/prolog/bench/nrev.pl's own header records an honest
# engine-vs-engine WALL-CLOCK ratio of 6.68x against GNU where this board reads 20.21x on Ir -- both are
# right, and together they say SCRIP retires roughly 3x more instructions per unit time than gprolog on
# that kernel, which is what flat-wired straight-line x86 against a bytecode dispatch loop should look
# like. A reader who takes the WORK column as a time ratio will claim a 20x deficit that is not there.
#
# THE ADEQUACY CHECK IS BUILT IN. Two independent slopes are computed, from (N,2N) and from (2N,4N). In
# the linear regime they agree; if N is too small to have left the setup transient, or the kernel's
# per-iteration cost grows, they diverge and the row prints NONLINEAR rather than a number. ⭐ TWO POINTS
# ALWAYS FIT A LINE -- the third point is what makes this a measurement of the model rather than an
# assumption of it. Measured during development: SCRIP's pairwise slopes on nrev across n=20/40/60 read
# 4543131, 4543132, 4543133, and swipl's 230875, 230877, 230878, residual 0.000 percent.
#
# ⛔ N IS CALIBRATED PER KERNEL, NEVER FIXED. These kernels differ by orders of magnitude per iteration,
# so one N either starves a cheap kernel out of its linear regime or buries an expensive one under
# callgrind's ~50x slowdown. Each kernel is probed cheaply, then N is chosen to hit a fixed INSTRUCTION
# budget -- the thing that actually bounds both the runtime and the noise.
#
# EXIT: 0 = board printed, 1 = a kernel read UNPROVEN/NONLINEAR, 2 = REFUSED (could not measure).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="$HERE/../../SCRIP/out"
TMO="${IR_TIMEOUT:-900}"
BASE_N="${BASE_N:-40}"
TARGET_IR="${TARGET_IR:-60000000}"
LIN_TOL="${LIN_TOL:-2}"
ONLY="${KERNELS:-}"
refuse() { echo "⛔ PROLOG Ir SLOPE BOARD REFUSED (rc=2): $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
    case "$1" in
        --kernel) ONLY="${ONLY:+$ONLY }$2"; shift 2 ;;
        --base-n) BASE_N="$2"; shift 2 ;;
        --target-ir) TARGET_IR="$2"; shift 2 ;;
        *) refuse "unknown argument '$1' -- this board has no silent fall-through" ;;
    esac
done
[ -x "$SCRIP_BIN" ] || refuse "scrip not built at $SCRIP_BIN."
command -v valgrind >/dev/null 2>&1 || refuse "valgrind not on PATH -- this board reads Ir through callgrind and will not guess."
. "$HERE/lib_ir_measure.sh"   2>/dev/null || refuse "cannot load lib_ir_measure.sh -- this board will not read Ir by hand."
. "$HERE/lib_perf_fmt.sh"     2>/dev/null || refuse "lib_perf_fmt.sh unloadable (the ONE multiple-printing authority)."
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable (the ONE oracle-path authority)."
SWI="$(swipl_bin)"    || refuse "swipl oracle absent -- lib_oracle_flags refused it."
GNU="$(gprolog_bin)"  || refuse "gprolog oracle absent -- lib_oracle_flags refused it."
B="$S4E/corpus/benchmarks/prolog/bench"
[ -d "$B" ] || refuse "kernel dir missing: $B"
W="$(mktemp -d "${TMPDIR:-/tmp}/plirslope.XXXXXX")" || refuse "cannot make a work dir."
trap 'rm -rf "$W"' EXIT
# ⭐ A VOIDED ARM KEEPS ITS REASON. "not measured" and "measured and thrown away" are different facts and
# a board printing one word for both has destroyed the difference; the void stays (the slope math needs
# the empty) and the WHY goes to stderr.
ir_of() {
  local v; v="$(IR_TMO="$TMO" ir_measure "$@")"
  if ir_is_number "$v"; then echo "$v"; return 0; fi
  echo "⚠ Ir arm voided: $(ir_cell "$v") for [$*] -- $(ir_reason "$v")" >&2
  return 0
}
# ⛔ ONE WRAPPED SOURCE PER ENGINE, NOT ONE SHARED. bench_prolog_wrap.sh generates engine-specific
# prologue and halt conventions (--engine=scrip|gnu|swi); feeding a gnu-wrapped file to swipl measures
# the wrapper's mismatch, not the engine.
build_at() {
  local src="$1" n="$2" eng="$3"
  local o="$W/k_${eng}_$n.pl"
  bash "$HERE/bench_prolog_wrap.sh" "$src" -o "$o" --mode=iter --n="$n" --engine="$eng" >/dev/null 2>&1 || return 0
  [ -s "$o" ] || return 0; echo "$o"
}
ir_m3()  { ir_of "$SCRIP_BIN" --run "$1" < /dev/null; }
ir_swi() { ir_of "$SWI" -q -f "$1" -t halt < /dev/null; }
ir_gnu() { ir_of "$GNU" --quiet --consult-file "$1" < /dev/null; }
ir_m4() {
  local f="$1" d; d="$(mktemp -d "$W/m4.XXXXXX")"
  "$SCRIP_BIN" --compile "$f" --out="$d/p.s" < /dev/null >/dev/null 2>&1 || return 0
  gcc -no-pie "$d/p.s" -o "$d/p.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -lpthread >/dev/null 2>&1 || return 0
  ir_of "$d/p.bin" < /dev/null
}
TREE="$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null || echo '?')"
CTREE="$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "IR_SLOPE lang=prolog tree=SCRIP $TREE corpus $CTREE RT_OPT=-O0 instrument=callgrind-Ir-regression date=$(date -u +%Y-%m-%d)"
echo "  basis: Ir(n) = OVERHEAD + n*WORK fitted at n = N / 2N / 4N; WORK is the SLOPE (Ir per iteration,"
echo "         startup cancelled exactly), OVERHEAD is the INTERCEPT and is ITS OWN NUMBER -- the two are"
echo "         printed side by side and NEVER subtracted across (RULES.md FACT RULE, apples-to-apples)."
echo "  ⛔ Ir IS NOT TIME: instructions retired, not cycles. This board never replaces the timed angles."
echo "  linearity: slope(N,2N) vs slope(2N,4N) must agree within ${LIN_TOL}% or the row reads NONLINEAR."
echo "  multiple = oracle WORK / SCRIP m4 WORK (FASTER axis: above 1.00x SCRIP does less work per iteration)."
echo "  instrument is LOAD-IMMUNE, so no load stamp is required (CEO-743 binds wall-clock numbers only)."
echo "         For the record the box was at $(perf_load_stamp 2>/dev/null || cut -d' ' -f1-3 /proc/loadavg)."
printf '%-22s %8s %12s %12s %12s %12s %13s %13s %11s  %s\n' kernel N "m3 WORK" "m4 WORK" "gnu WORK" "swi WORK" "m4 OVERHEAD" "gnu OVERHEAD" "linearity" "x vs gnu (m4)"
N=0; RC=0
for src in "$B"/*.pl; do
  [ -f "$src" ] || continue
  k="$(basename "$src" .pl)"
  [ -z "$ONLY" ] || case " $ONLY " in *" $k "*) ;; *) continue;; esac
  grep -q '\*BENCH kernel=' "$src" || continue
  probe_a="$(build_at "$src" 4 scrip)"; probe_b="$(build_at "$src" 12 scrip)"
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
  declare -A SLOPE OVH LIN
  for eng in m3 m4 gnu swi; do
    case $eng in m3|m4) we=scrip;; gnu) we=gnu;; swi) we=swi;; esac
    f1="$(build_at "$src" "$n1" "$we")"; f2="$(build_at "$src" "$n2" "$we")"; f3="$(build_at "$src" "$n3" "$we")"
    if [ -z "$f1" ] || [ -z "$f2" ] || [ -z "$f3" ]; then SLOPE[$eng]=""; OVH[$eng]=""; LIN[$eng]="UNPROVEN"; continue; fi
    case $eng in
      m3)  a=$(ir_m3 "$f1");  b=$(ir_m3 "$f2");  c=$(ir_m3 "$f3");;
      m4)  a=$(ir_m4 "$f1");  b=$(ir_m4 "$f2");  c=$(ir_m4 "$f3");;
      gnu) a=$(ir_gnu "$f1"); b=$(ir_gnu "$f2"); c=$(ir_gnu "$f3");;
      swi) a=$(ir_swi "$f1"); b=$(ir_swi "$f2"); c=$(ir_swi "$f3");;
    esac
    if [ -z "$a" ] || [ -z "$b" ] || [ -z "$c" ]; then SLOPE[$eng]=""; OVH[$eng]=""; LIN[$eng]="UNPROVEN"; continue; fi
    read -r s o l <<<"$(awk -v a="$a" -v b="$b" -v c="$c" -v n="$n1" -v tol="$LIN_TOL" 'BEGIN{
        s1=(b-a)/n; s2=(c-b)/(2*n);
        if (s1<=0 || s2<=0) { print "0 0 NONLINEAR"; exit }
        d=(s1>s2? (s1-s2)/s2 : (s2-s1)/s1)*100;
        printf "%d %d %s", s2, a-n*s1, (d<=tol? "ok" : "NONLINEAR");
      }')"
    SLOPE[$eng]="$s"; OVH[$eng]="$o"; LIN[$eng]="$l"
  done
  lin="${LIN[m4]:-?}/${LIN[gnu]:-?}"
  if [ -n "${SLOPE[m4]:-}" ] && [ -n "${SLOPE[gnu]:-}" ] && [ "${LIN[m4]}" = ok ] && [ "${LIN[gnu]}" = ok ]; then
    mult="$(perf_mult "${SLOPE[gnu]}" "${SLOPE[m4]}")"
  else mult="-"; RC=1; fi
  printf '%-22s %8s %12s %12s %12s %12s %13s %13s %11s  %s\n' "$k" "$n1" "${SLOPE[m3]:-NA}" "${SLOPE[m4]:-NA}" "${SLOPE[gnu]:-NA}" "${SLOPE[swi]:-NA}" "${OVH[m4]:-NA}" "${OVH[gnu]:-NA}" "$lin" "$mult"
  N=$((N+1))
done
echo "IR_SLOPE_BOARD lang=prolog kernels=$N target_ir=$TARGET_IR"
[ "$N" -gt 0 ] || refuse "no kernel measured -- a grid of nothing is not a measurement."
exit $RC
