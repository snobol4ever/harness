#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_bench_pascal_timed.sh -- ANGLE 1 of the Pascal three-angle triangulation (row bench-rivals-raku-pascal,
# mirroring test_bench_prolog_timed.sh / ARCH-BENCH-CAMPAIGN-README-TABLES.md THREE-ANGLE TRIANGULATION).
#
# Fixed WALL-TIME budget, iterations counted: a live doubling search over the kernel's OWN `reps` value
# (fed via stdin -- every kernel here opens with `readln(reps); for rep := 1 to reps do <body>`, so this
# needs no source rewriting the way the Prolog triangulator's mkwrap does) picks the largest reps whose
# single bench_rusage-wrapped run completes within TIME_BUDGET_MS, then reports rate = reps / cpu_seconds.
# ⛔ SCOPED TO THE 7 REPS-CAPABLE KERNELS ONLY (bubble/intmm/perm/queens/quick/sieve/towers). `uplevel2`/
# `uplevel3` have no `reps` knob -- fixed 30000x8000 workload baked into the source -- and need a
# PROCESS-LEVEL repeat mechanism this script does not implement; see corpus/benchmarks/pascal/EXCLUDED.tsv.
# `fbench` SIGSEGVs at compile time (row pascal-fbench-nested-function-self-assign-null-name) and `whet`
# has no committed `.ref` -- both excluded, not silently dropped.
#
# ⛔ CORRECTNESS GATES THE TIMING: every kernel's reps=1 output is verified against its `.ref` before ever
# being timed -- a kernel that fails this is SKIPped, never silently timed anyway. Per the row's own
# measured invariant (hq_C, 2026-08-27: "reps=1,2,3 -> 10414 every time" on the pre-fix `quick`), the
# PRINTED output does not vary with reps -- these kernels loop internally for cost, not for a changing
# answer -- so reps=1's output is the correctness oracle at every reps value, not just reps=1.
#
# ⛔⭐ THE exit= FIELD IS THE ONLY TRUSTED CRASH SIGNAL (same lesson as the Prolog triangulator, row
# bench-rivals-prolog, seat14 FINDING) -- a segfaulting child still writes a well-formed BENCH_RUSAGE
# line; only bench_rusage's own exit= field is trusted, never stderr text-sniffing.
#
# ⭐ SLOPE CURE (row readme-perf-grids-three-angles-all-seven, hq_P FINDING-2026-09-04-hq_P-pascal-angle-
# bias-is-a-per-run-fixed-cost-inside-the-program-not-process-startup.md): these kernels carry a large
# PER-RUN FIXED COST INSIDE THE PROGRAM (bubble m4 235.8ms, 107x process startup) that `rate = reps/cpu`
# leaves in the denominator, so the measured rate climbs with reps instead of being a constant of the
# kernel -- and the two angles amortize it over DIFFERENT reps, producing a one-sided bias. The cure,
# mirroring bench_ir_slope.sh's Ir(n)=OVERHEAD+n*WORK regression: reuse the existing doubling search to
# find the anchor reps value (unchanged budget/cap logic, call it n3), then also measure at n1=n3/4 and
# n2=n3/2 and report WORK = the SLOPE (us per rep, a COST -- lower is faster) fitted from (n2,n3) with
# (n1,n2)'s slope as the independent cross-check; the two must agree within LIN_TOL or the cell reads
# NONLINEAR rather than publishing a number. ⛔ WORK is COST-basis like bench_ir_slope.sh's WORK column,
# the OPPOSITE convention from the old rate (reps/s, bigger=faster) this replaces -- perf_mult callers
# downstream must pass (rival, ours), never (ours, rival), or the published multiple silently inverts.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/pascal}"
# ⛔ TIMEOUT WAS 30, RAISED TO 60 (matching angle 2's own default): measured live this session, one of
# five run1_min trials at bubble/m4 n3=64 hit the 30s wall (exit=124, a real `timeout` kill, not a crash)
# under this box's load (~10/16 cores) -- hq_P's own reference FINDING for this same kernel measured at
# load ~3-5, half of what this session saw, so a tighter timeout that worked for them is tighter than
# this session's actual contention warrants.
# ⛔ BUDGET_MS WAS 800, LOWERED TO 150 -- MEASURED LIVE, NOT A GUESS: with x1/x4/x16 spacing anchored on
# an 800ms budget, the TOP point (16x the anchor) runs ~16x800ms=12.8s regardless of kernel -- confirmed
# directly on fpc/bubble (n=65536, three back-to-back trials: 16.90/17.04/17.75s, TIGHTLY clustered, so
# NOT scheduling jitter) with a slope that climbs 35% between the (n1,n2) and (n2,n3) segments even
# though bubble.pas resets its seed and regenerates its array every single rep (verified in source --
# every rep is provably identical work, so a real per-rep cost cannot be nonlinear). The reproducible,
# non-random shape of the disagreement points at something correlated with a measurement's OWN wall-clock
# duration under this box's sustained ~10/16-core fleet load (CPU frequency scaling under sustained load
# is the leading candidate) -- not noise averaging fixes, since it is not per-trial-random, and not wider
# spacing, since that makes it WORSE (a longer top point spends more time in a different regime than the
# short bottom point). The fix is to keep ALL THREE points short and close in duration: at BUDGET_MS=150,
# the same x1/x4/x16 triple's top point runs ~150ms*16=2.4s, calculated and then confirmed short enough
# to avoid the effect on this box. Every engine's anchor shrinks proportionally, not just the slow ones.
T="${TIMEOUT:-60}"; BUDGET_MS="${TIME_BUDGET_MS:-150}"; NMAX="${NMAX:-200000}"; LIN_TOL="${LIN_TOL:-10}"
# whet joined 2026-09-26 (ceo CEO-1281, the quiet box CEO-1219 waited for): kernel form with a .ref since 2026-09-23, II read from stdin like every
#   other kernel's reps; measured this sitting 310 ms/rep on m3 and about 2 ms/rep on fpc -O2, both printing whet.ref at reps 1, 4 and 16.
KERNELS="${KERNELS:-bubble intmm perm queens quick sieve towers whet}"   # reps-capable set, measured not guessed (see header)
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE pascal corpus missing: $B"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh"; exit 2; }
FPC="$(fpc_bin)" || exit 2
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1281)"; exit 2; }
# ⛔ THE SCRIP ARMS RUN UNDER THE KERNEL'S OWN DECLARATION (ceo CEO-1281, 2026-09-26; RULES.md hard-cap rule clause 8 (f)): DECL_SW carries the
#   <k>.heap / <k>.stack sidecars as SPITBOL's -d<kb>k -s<kb>k switches on every m3 and m4 command line, the reps=1 correctness gate included.
declare -a DECL_SW=(); declare -A DECLW=()
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# fpc needs {$mode objfpc} prepended (default 16-bit `integer` silently corrupts the Hennessy RNG --
# corpus/benchmarks/pascal/README.md, hq_C 2026-08-27) and its own binary compiled once per kernel.
fpc_build() {
  local pas="$1" k out; k=$(basename "${pas%.pas}"); out="$W/fpc_$k"
  [ -x "$out" ] && { printf '%s\n' "$out"; return 0; }
  { printf '{$mode objfpc}\n'; cat "$pas"; } > "$W/fpc_$k.pas"
  "$FPC" -O2 -o"$out" "$W/fpc_$k.pas" >"$W/fpc_$k.buildlog" 2>&1 || return 1
  printf '%s\n' "$out"
}

# one bench_rusage-wrapped run feeding reps via stdin; echoes "cpu_us" or "- REASON"
run1() {
  local eng="$1" k="$2" reps="$3" out rl xc user sys bin
  case "$eng" in
    fpc) bin=$(fpc_build "$B/$k.pas") || { echo "- BUILD-ERR"; return; }
         out=$(printf '%d\n' "$reps" | "$WRAP" timeout -k 5 "$T" "$bin" >/dev/null 2>"$W/e.$$") ;;
    m3)  out=$(printf '%d\n' "$reps" | "$WRAP" timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$B/$k.pas" >/dev/null 2>"$W/e.$$") ;;
    m4)  local s="$W/$k.s" b="$W/$k.bin"
         if [ ! -x "$b" ]; then
           if ! (timeout -k 5 "$T" "$SCRIP" --compile "$B/$k.pas" </dev/null >"$s" 2>/dev/null) || [ ! -s "$s" ]; then echo "- BUILD-ERR"; return; fi
           if ! (as --64 -o "$W/$k.o" "$s" 2>/dev/null && gcc -no-pie -o "$b" "$W/$k.o" "$RT/libscrip_rt.so" -lm -Wl,-rpath,"$RT" 2>/dev/null); then echo "- LINKFAIL"; return; fi
         fi
         out=$(printf '%d\n' "$reps" | "$WRAP" timeout -k 5 "$T" "$b" "${DECL_SW[@]}" >/dev/null 2>"$W/e.$$") ;;
  esac
  rl=$(grep '^BENCH_RUSAGE:' "$W/e.$$" 2>/dev/null | tail -1)
  [ -n "$rl" ] || { echo "- DNF"; return; }
  xc=$(echo "$rl" | grep -oE 'exit=[0-9-]+' | cut -d= -f2)
  case "$xc" in ''|*[!0-9]*) echo "- CRASH(exit=${xc:-?})"; return ;; esac
  [ "$xc" -ge 128 ] && { echo "- CRASH(signal $((xc-128)))"; return; }
  [ "$xc" -ne 0 ] && { echo "- NONZERO($xc)"; return; }
  user=$(echo "$rl" | grep -oE 'user_us=[0-9]+' | cut -d= -f2); sys=$(echo "$rl" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
  echo "$(( ${user:-0} + ${sys:-0} ))"
}
# ⛔ PER-KERNEL, PER-ENGINE REPS CEILING (row pascal-quick-m3-recursive-reps-cliff-13, seat03 2026-08-28):
# `quick`'s recursive `qsort` SIGSEGVs under m3 (and m4, same SCRIP lowering) at a sharp, deterministic
# cliff -- reps=12 clean, reps=13+ crash, every trial -- found live by THIS script's own doubling search
# (nobody had timed `quick` past reps=3 before). Capping m3/m4's search below the cliff lets the OTHER
# engine/angle for `quick` still measure honestly instead of the whole kernel going UNPROVEN.
# ⛔ ENGINE-SCOPED, NOT KERNEL-WIDE -- FOUND LIVE THIS PASS: an earlier version of this function capped
# ALL THREE engines at 12, including fpc. fpc has no such defect, runs ~10000x faster than the cap needs,
# and at reps=12 its measurement is almost entirely fixed process-startup overhead (~1.3ms fixed vs
# ~10us/rep real cost) rather than steady-state throughput -- angle 1 and angle 2 disagreed 12-18x on
# fpc/quick as a direct, reproducible result (not noise -- it repeated in the same direction both times,
# unlike the genuine load-contention DISAGREEs elsewhere in this campaign, which flip direction run to
# run). The cap now applies only to the engines that actually crash.
# ⭐ THE CLIFF IS GONE (ceo CEO-1987, 2026-10-26): quick prints fpc's output at reps 12, 13, 100, 1000 and 5000 in m3 and m4 on SCRIP
# 9bd097fa9 (-O2) and 60ec01b8a (-O0), 0.3 s at 5000 -- the cap of 12 left both SCRIP arms too few reps to fit a slope, so both read
# UNPROVEN; no kernel carries a crash cap now, and a new one is named here with its row and its measurement.
kernel_reps_cap() { echo "$NMAX"; }
# kernel_crash_cap: a REAL reps ceiling past which a kernel/engine crashes, or empty if none is known.
# ⛔ DISTINCT FROM kernel_reps_cap/NMAX ABOVE, ON PURPOSE: NMAX just bounds angle 1's live search from
# running away on a kernel with negligible per-rep cost -- it is not a safety limit, and applying it to
# the x1/x4/x16 spacing decision below wrongly shrank fpc bases that have no crash risk at all (fpc's
# committed reps regularly exceed NMAX, e.g. queens=500000, and that is fine). Only quick:m3/m4 has a
# real crash boundary (pascal-quick-m3-recursive-reps-cliff-13).
kernel_crash_cap() { echo ""; }
# slope3 a b c na nb nc tol -> "WORK OVERHEAD LIN" where a/b/c are cpu-us measured at na/nb/nc reps (same
# fit as bench_ir_slope.sh's Ir(n)=OVERHEAD+n*WORK, applied to wall-clock cpu-us instead of Ir, generalised
# to unequal segment widths): WORK is the SLOPE (us/rep, fixed cost cancelled exactly) from the (nb,nc)
# segment, cross-checked against the independent (na,nb) segment's own slope; LIN is "ok" or "NONLINEAR"
# if the two disagree beyond tol%.
slope3() {
  awk -v a="$1" -v b="$2" -v c="$3" -v na="$4" -v nb="$5" -v nc="$6" -v tol="${7:-10}" 'BEGIN{
    s1=(b-a)/(nb-na); s2=(c-b)/(nc-nb)
    if (s1<=0 || s2<=0) { printf "0 0 NONLINEAR"; exit }
    d=(s1>s2 ? (s1-s2)/s2 : (s2-s1)/s1)*100
    printf "%.4f %.4f %s", s2, a-na*s1, (d<=tol ? "ok" : "NONLINEAR")
  }'
}
# ⛔⭐ LIVE MEASUREMENT, THIS SESSION: bubble/m3 at reps=16 read user_us of 8.5M/10.4M/10.6M across three
# back-to-back trials -- a ~25% spread AT THE SAME reps, on a box carrying FLEET-16's load (uptime
# reported load average ~10 on 16 cores at measurement time). That is scheduling contention, not the
# kernel: contention can only ADD delay, never remove it, so the MINIMUM of several trials approximates
# the uncontended cost far better than any single sample -- same principle every serious wall-clock
# microbenchmarking tool uses (hyperfine, perf stat --repeat), applied here because this box is not quiet
# and the row's own precedent (seat13's ledger, this same task file) accepts measuring under fleet load
# rather than waiting for a quiet window. Trials=5 matches hq_P's own best-of-5 in the FINDING this cure
# implements. run1_min replaces run1 at every point that ends up published.
run1_min() {
  local eng="$1" k="$2" reps="$3" trials="${4:-5}" i v best=""
  for ((i=0;i<trials;i++)); do
    v=$(run1 "$eng" "$k" "$reps")
    case "$v" in -\ *) echo "$v"; return ;; esac
    [ -z "$best" ] || [ "$v" -lt "$best" ] && best="$v"
  done
  echo "$best"
}
# pick_spacing crash_cap -> "mult1 mult2" (n2=mult1*n1, n3=mult2*n1). ⛔ WIDE (x4,x16) SPACING IS NOT
# OPTIONAL -- MEASURED, NOT A STYLE CHOICE: bench_ir_slope.sh's x2/x4 spacing (mult1=2,mult2=4) was tried
# here FIRST and discarded after live measurement -- with only a 4x spread top-to-bottom, bubble read
# NONLINEAR by 24%+ even with min-of-3 trials, because the ABSOLUTE cpu difference between points was
# still small enough for scheduling jitter to dominate it. hq_P's own FINDING for this exact kernel
# (5/20/80 = x4/x16) got 3.08% agreement -- the wider spread is what makes the true linear signal (which
# grows with Δreps) rise above a roughly fixed amount of jitter. Falls back to the narrow x2/x4 spacing
# ONLY when a real crash cap is too tight for x16 (quick's cap=12: even n1=1 gives n3=16>12).
pick_spacing() { local cap="$1"; if [ -z "$cap" ] || [ $((cap/16)) -ge 3 ]; then echo "4 16"; else echo "2 4"; fi; }
# measure the triple (n1,mult1*n1,mult2*n1) and fit the slope. Echoes "n3 WORK" or "n3 -" + reason.
search() {
  local eng="$1" k="$2" reps=1 cpu cap
  cap="$(kernel_reps_cap "$k" "$eng")"
  # UNCHANGED doubling-to-budget search (pre-slope behaviour) finds a reasonable single-point anchor,
  # exactly as angle 1 always has -- single-trial (run1, not run1_min): this loop only needs a ballpark
  # reps value, and fpc especially needs many doubling steps to reach the budget, so paying 5x the
  # process-spawn cost per step here (as an earlier version of this cure did) is wasted precision on a
  # number that gets thrown away. Only the three points that actually get PUBLISHED (below) use run1_min.
  while :; do
    cpu=$(run1 "$eng" "$k" "$reps")
    case "$cpu" in -\ *) echo "$reps $cpu"; return ;; esac
    if [ "$cpu" -ge $((BUDGET_MS*1000)) ] || [ "$reps" -ge "$cap" ]; then break; fi
    reps=$((reps*4)); [ "$reps" -gt "$cap" ] && reps="$cap"
  done
  local anchor="$reps" ccap mult1 mult2 n1 n2 n3 c1 c2 c3
  ccap="$(kernel_crash_cap "$k" "$eng")"
  read -r mult1 mult2 <<<"$(pick_spacing "$ccap")"
  if [ -z "$ccap" ] || [ $((anchor*mult2)) -le "$ccap" ]; then n1="$anchor"
  else n1=$((ccap/mult2)); [ "$n1" -lt 1 ] && n1=1; fi
  n2=$((n1*mult1)); n3=$((n1*mult2))
  c1=$(run1_min "$eng" "$k" "$n1"); case "$c1" in -\ *) echo "$n1 $c1"; return ;; esac
  c2=$(run1_min "$eng" "$k" "$n2"); case "$c2" in -\ *) echo "$n2 $c2"; return ;; esac
  c3=$(run1_min "$eng" "$k" "$n3"); case "$c3" in -\ *) echo "$n3 $c3"; return ;; esac
  read -r work _ovh lin <<<"$(slope3 "$c1" "$c2" "$c3" "$n1" "$n2" "$n3" "$LIN_TOL")"
  [ "$lin" = ok ] || { echo "$n3 - NONLINEAR(n1=$n1,n2=$n2,n3=$n3)"; return; }
  printf '%s %s' "$n3" "$work"
}

echo "TIME-BASED PASCAL BENCHMARKS -- angle 1: fixed wall-time budget (${BUDGET_MS}ms) finds an anchor reps"
echo "via live doubling search (unchanged), which becomes n1 of a x1/x4/x16 triple (narrowed to x1/x2/x4 only"
echo "when quick's crash cap forces it); WORK is the us/rep SLOPE fit across it (COST basis, lower=faster;"
echo "see the SLOPE CURE header note) -- NONLINEAR means the two segment slopes disagreed by >LIN_TOL%"
echo "engines: fpc m3 m4   corpus: $B   budget: TIME_BUDGET_MS=$BUDGET_MS cap NMAX=$NMAX LIN_TOL=$LIN_TOL%   external instrument: tools/bench_rusage"
echo
printf "%-10s %14s %14s %14s  %s\n" BENCHMARK fpc-us/rep m3-us/rep m4-us/rep check
printf "%-10s %14s %14s %14s  %s\n" "----------" "--------------" "--------------" "--------------" "-----"
tot_ok=0; tot_skip=0
for k in $KERNELS; do
  pas="$B/$k.pas"; ref="$B/$k.ref"
  [ -f "$pas" ] && [ -f "$ref" ] || { printf "%-10s MISSING kernel or .ref\n" "$k"; tot_skip=$((tot_skip+1)); continue; }
  want=$(cat "$ref")
  DECL_SW=(); dw=$(declared_switches_beside "$B/$k.pas") || { echo "⛔ REFUSED-TO-GRADE: $k: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }
  [ -n "$dw" ] && { read -r -a DECL_SW <<<"$dw"; DECLW["$k"]="$dw"; }
  m3o=$(printf '1\n' | timeout -k 5 15 "$SCRIP" --run "${DECL_SW[@]}" "$pas" 2>/dev/null)
  if [ "$m3o" != "$want" ]; then
    printf "%-10s %14s %14s %14s  %s\n" "$k" SKIP SKIP SKIP "correctness-fail(reps=1 m3 != .ref)"; tot_skip=$((tot_skip+1)); continue
  fi
  declare -A R=() C=()
  for eng in fpc m3 m4; do
    res=$(search "$eng" "$k"); n=$(awk '{print $1}' <<<"$res"); r=$(awk '{print $2}' <<<"$res")
    case "$r" in -) R[$eng]="NA"; C[$eng]="$eng@reps=$n:$(cut -d' ' -f3- <<<"$res")" ;; *) R[$eng]="$r" ;; esac
  done
  # ⛔ FIRST failing engine, not last: this loop used to keep overwriting ckstat on every match, so three
  # engines failing for three DIFFERENT reasons silently showed only the last one -- discovered live this
  # session when fpc's own failure reason was invisible behind m3's.
  ckstat=ok; for eng in fpc m3 m4; do [ "$ckstat" = ok ] && [ -n "${C[$eng]:-}" ] && ckstat="${C[$eng]}"; done
  [ "$ckstat" = ok ] && tot_ok=$((tot_ok+1))
  printf "%-10s %14s %14s %14s  %s\n" "$k" "${R[fpc]:-NA}" "${R[m3]:-NA}" "${R[m4]:-NA}" "$ckstat"
  unset R C
done
echo
echo "DECLARED SIDECARS carried as switches on the m3 and m4 command lines (lib_declared_arena.sh; CEO-1281): ${#DECLW[@]} kernel(s)"
for k in "${!DECLW[@]}"; do echo "  $k: ${DECLW[$k]}"; done
echo
echo "CHECK RESULT: measured=$tot_ok correctness-skip=$tot_skip"
[ "$tot_skip" -eq 0 ]
