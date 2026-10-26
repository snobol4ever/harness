#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_pascal_fixed_iter.sh -- ANGLE 2 of the Pascal three-angle triangulation (row bench-rivals-raku-pascal,
# mirroring bench_prolog_fixed_iter.sh / ARCH-BENCH-CAMPAIGN-README-TABLES.md THREE-ANGLE TRIANGULATION).
#
# Run each kernel's OWN internal `for rep := 1 to reps do <body>` loop EXACTLY N times, N fixed and
# COMMITTED in corpus/benchmarks/pascal/SCALE.tsv (calibrated once, see that file's own header -- never a
# live search, that is angle 1's job), and report throughput (reps/s) for fpc / m3 / m4. N is fed via
# stdin exactly like angle 1 -- these kernels need no source rewriting, unlike Prolog's vanroy/ wrappers.
# ⛔ TWO N COLUMNS, NOT ONE: fpc (-O2) is 100-3000x faster than SCRIP's -O0 arms on several kernels here --
# a single shared N cannot amortize a fast engine's fixed per-process overhead without being absurdly long
# for the slow one (measured: a shared N gave fpc a spurious 0.30x angle1-vs-angle2 DISAGREE, cured by
# splitting the column -- see SCALE.tsv's own header). m3 and m4 share `scrip_reps` -- empirically close
# enough in speed on every kernel measured so far that splitting them further wasn't warranted.
#
# ⛔ CORRECTNESS IS NOT RE-VERIFIED HERE -- angle 1 (test_bench_pascal_timed.sh) already re-checks every
# kernel's reps=1 output against .ref before timing anything; this script trusts that provenance (same
# split of duty the Prolog angle-2 script uses) and gates only on the run completing without crash/DNF.
#
# External CPU time via tools/bench_rusage, same instrument angle 3 (disk telemetry) and the SNOBOL4/
# Prolog triangulators both use -- never engine self-timing.
#
# ⭐ SLOPE CURE (row readme-perf-grids-three-angles-all-seven, hq_P FINDING-2026-09-04-hq_P-pascal-angle-
# bias-is-a-per-run-fixed-cost-inside-the-program-not-process-startup.md): SCALE.tsv's committed N used
# to be the SOLE measurement point (rate=N/cpu), which leaves the kernel's large per-run fixed cost in
# the denominator -- same defect as angle 1's old single-point rate, same cure. SCALE.tsv's committed N
# is now read as the TOP of a doubling triple (N/4, N/2, N): WORK is the us/rep SLOPE fitted from the
# (N/2,N) segment, cross-checked against the independent (N/4,N/2) segment, mirroring
# test_bench_pascal_timed.sh's search() and bench_ir_slope.sh's Ir(n)=OVERHEAD+n*WORK regression exactly.
# ⛔ quick's scrip_reps=12 SITS AT the m3/m4 crash cap (pascal-quick-m3-recursive-reps-cliff-13) -- N/4
# alone would still leave 4*(N/4)=N=12 as the top point, safely at (not past) the cap, but the SAME cap
# must gate the BASE derivation below for any future kernel/cap combination, not just quick's.
# ⛔ WORK is COST-basis (lower is faster), the OPPOSITE convention from the old rate (reps/s, bigger=
# faster) this replaces -- perf_mult callers downstream must pass (rival, ours), never (ours, rival).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/pascal}"
SCALE="${SCALE_TSV:-$B/SCALE.tsv}"
T="${TIMEOUT:-60}"; LIN_TOL="${LIN_TOL:-10}"; NMAX="${NMAX:-200000}"
KERNELS="${KERNELS:-}"   # optional allowlist, space-separated basenames -- same convention as the Prolog scripts
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -f "$SCALE" ] || { echo "⛔ REFUSED-TO-GRADE SCALE.tsv missing: $SCALE"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh"; exit 2; }
FPC="$(fpc_bin)" || exit 2
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1281)"; exit 2; }
declare -a DECL_SW=(); declare -A DECLW=()
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

fpc_build() {
  local pas="$1" k out; k=$(basename "${pas%.pas}"); out="$W/fpc_$k"
  [ -x "$out" ] && { printf '%s\n' "$out"; return 0; }
  { printf '{$mode objfpc}\n'; cat "$pas"; } > "$W/fpc_$k.pas"
  "$FPC" -O2 -o"$out" "$W/fpc_$k.pas" >"$W/fpc_$k.buildlog" 2>&1 || return 1
  printf '%s\n' "$out"
}
# kernel_crash_cap: a REAL reps ceiling past which a kernel/engine crashes, or empty if none is known --
# identical copy of test_bench_pascal_timed.sh's function (see that file's header for why this is kept
# distinct from any NMAX-style search ceiling: only quick:m3/m4 has a genuine crash boundary, and a
# generic "cap" would wrongly shrink bases like fpc's that have no crash risk at all).
# ⭐ quick's cliff is gone (ceo CEO-1987, 2026-10-26: fpc's output at reps 12..5000 in m3 and m4); no kernel carries a crash cap now.
kernel_crash_cap() { echo ""; }
# pick_spacing / slope3: identical copies of test_bench_pascal_timed.sh's functions (see that file's
# header for the full derivation and the live measurement that picked x4/x16 over x2/x4) -- kept as exact
# copies so the two angles cannot silently drift onto different formulas for the same quantity.
pick_spacing() { local cap="$1"; if [ -z "$cap" ] || [ $((cap/16)) -ge 3 ]; then echo "4 16"; else echo "2 4"; fi; }
slope3() {
  awk -v a="$1" -v b="$2" -v c="$3" -v na="$4" -v nb="$5" -v nc="$6" -v tol="${7:-10}" 'BEGIN{
    s1=(b-a)/(nb-na); s2=(c-b)/(nc-nb)
    if (s1<=0 || s2<=0) { printf "0 0 NONLINEAR"; exit }
    d=(s1>s2 ? (s1-s2)/s2 : (s2-s1)/s1)*100
    printf "%.4f %.4f %s", s2, a-na*s1, (d<=tol ? "ok" : "NONLINEAR")
  }'
}
# run1_min: minimum of several run1 trials -- same noise-cancelling rationale as
# test_bench_pascal_timed.sh's run1_min (measured live this session: ~25% spread between back-to-back
# trials at identical reps, on a box carrying FLEET-16's load). Trials=5 matches hq_P's best-of-5.
# Identical to that file's copy.
run1_min() {
  local eng="$1" k="$2" reps="$3" trials="${4:-5}" i v best=""
  for ((i=0;i<trials;i++)); do
    v=$(run1 "$eng" "$k" "$reps")
    case "$v" in -\ *) echo "$v"; return ;; esac
    [ -z "$best" ] || [ "$v" -lt "$best" ] && best="$v"
  done
  echo "$best"
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

# base_for k eng committed -> "n1 mult1 mult2": SCALE.tsv's committed reps IS n1 (the smallest of the
# triple) whenever that is safe -- matching hq_P's own FINDING exactly (bubble scrip_reps=5 used AS n1,
# giving the triple 5/20/80 that measured 3.08% agreement) -- shrunk only when a real crash cap forbids
# it (quick: committed=cap=12, so even the narrow x4 top would crash; shrink to cap/mult2 instead).
base_for() {
  local k="$1" eng="$2" committed="$3" ccap mult1 mult2 n1
  ccap="$(kernel_crash_cap "$k" "$eng")"
  read -r mult1 mult2 <<<"$(pick_spacing "$ccap")"
  if [ -z "$ccap" ] || [ $((committed*mult2)) -le "$ccap" ]; then n1="$committed"
  else n1=$((ccap/mult2)); [ "$n1" -lt 1 ] && n1=1; fi
  echo "$n1 $mult1 $mult2"
}

echo "FIXED-ITERATION PASCAL BENCHMARKS -- angle 2: reps fixed per kernel (committed in SCALE.tsv, now read"
echo "as n1, the BASE of a x1/x4/x16 triple -- narrowed to x1/x2/x4 only when quick's crash cap forces it);"
echo "WORK is the us/rep SLOPE fit across the triple (COST basis, lower=faster; see the SLOPE CURE header"
echo "note), cross-checked for linearity like angle 1's search()."
echo "engines: fpc m3 m4   SCALE: $SCALE (base columns shown = n1)   LIN_TOL=$LIN_TOL%   external instrument: tools/bench_rusage (user+sys cpu time)"
echo
printf "%-10s %10s %10s %14s %14s %14s  %s\n" BENCHMARK base_fpc base_scrip fpc-us/rep m3-us/rep m4-us/rep check
printf "%-10s %10s %10s %14s %14s %14s  %s\n" "----------" "----------" "----------" "--------------" "--------------" "--------------" "-----"
tot_ok=0; tot_bad=0
while IFS=$'\t' read -r k nf ns; do
  [[ "$k" == \#* || -z "$k" ]] && continue
  if [ -n "$KERNELS" ]; then case " $KERNELS " in *" $k "*) ;; *) continue ;; esac; fi
  [ -f "$B/$k.pas" ] || { printf "%-10s %10s %10s   MISSING kernel: %s\n" "$k" "$nf" "$ns" "$B/$k.pas"; tot_bad=$((tot_bad+1)); continue; }
  DECL_SW=(); dw=$(declared_switches_beside "$B/$k.pas") || { echo "⛔ REFUSED-TO-GRADE: $k: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }
  [ -n "$dw" ] && { read -r -a DECL_SW <<<"$dw"; DECLW["$k"]="$dw"; }
  ckstat=ok; declare -A RATE=(); base_fpc=""; base_scrip=""
  for eng in fpc m3 m4; do
    n="$ns"; [ "$eng" = fpc ] && n="$nf"
    read -r n1 mult1 mult2 <<<"$(base_for "$k" "$eng" "$n")"
    n2=$((n1*mult1)); n3=$((n1*mult2))
    [ "$eng" = fpc ] && base_fpc="$n1" || base_scrip="$n1"
    c1=$(awk '{print $1}' <<<"$(run1_min "$eng" "$k" "$n1")")
    if [ "$c1" = "-" ]; then RATE[$eng]="NA"; [ "$ckstat" = ok ] && ckstat="$eng:DNF/CRASH@n1=$n1"; continue; fi
    c2=$(awk '{print $1}' <<<"$(run1_min "$eng" "$k" "$n2")")
    if [ "$c2" = "-" ]; then RATE[$eng]="NA"; [ "$ckstat" = ok ] && ckstat="$eng:DNF/CRASH@n2=$n2"; continue; fi
    c3=$(awk '{print $1}' <<<"$(run1_min "$eng" "$k" "$n3")")
    if [ "$c3" = "-" ]; then RATE[$eng]="NA"; [ "$ckstat" = ok ] && ckstat="$eng:DNF/CRASH@n3=$n3"; continue; fi
    read -r work _ovh lin <<<"$(slope3 "$c1" "$c2" "$c3" "$n1" "$n2" "$n3" "$LIN_TOL")"
    if [ "$lin" != ok ]; then RATE[$eng]="NA"; [ "$ckstat" = ok ] && ckstat="$eng:NONLINEAR(n1=$n1,n2=$n2,n3=$n3)"; continue; fi
    RATE[$eng]="$work"
  done
  [ "$ckstat" = ok ] && tot_ok=$((tot_ok+1)) || tot_bad=$((tot_bad+1))
  printf "%-10s %10s %10s %14s %14s %14s  %s\n" "$k" "$base_fpc" "$base_scrip" "${RATE[fpc]}" "${RATE[m3]}" "${RATE[m4]}" "$ckstat"
  unset RATE
done < "$SCALE"
echo
echo "DECLARED SIDECARS carried as switches on the m3 and m4 command lines (lib_declared_arena.sh; CEO-1281): ${#DECLW[@]} kernel(s)"
for k in "${!DECLW[@]}"; do echo "  $k: ${DECLW[$k]}"; done
echo
echo "CHECK RESULT: ok=$tot_ok bad=$tot_bad   (bad = crash/DNF/build-fail on at least one engine this run; correctness itself is angle 1's job)"
[ "$tot_bad" -eq 0 ]
