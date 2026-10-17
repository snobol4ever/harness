#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_demos_snobol4.sh -- THREE-ANGLE TRIANGULATION FOR THE **DEMO** PROGRAMS.
# Minted 2026-08-27 by hq_P on Lon's in-chat PIVOT, verbatim in substance: "Get numbers for 3-angle
# performance numbers on all the demo programs. claws5, treebank, json, calculator, beauty. And keep
# the numbers for the README.md". Law: .github/ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE
# TRIANGULATION. Sibling (kernels, NOT this): bench_triangulate_snobol4.sh.
#
# ⛔⭐ WHY THIS IS A SEPARATE SCRIPT AND NOT A FLAG ON THE KERNEL ONE -- THE UNIT OF WORK DIFFERS.
# A benchmarks/snobol4 kernel exposes a `*BENCH kernel=NAME` entry point and the harness loops it, so
# its rate is a SLOPE with startup divided away. A demo has no such entry point and no internal loop:
# it reads stdin, does its job once, and exits. So one "iteration" here is ONE WHOLE PROGRAM RUN, and
# every number this script prints is a **TOTAL** carrying process startup AND the compile.
# ⛔ FACT RULE CONSEQUENCE: a demo total may NEVER share a column, grid or sentence with a kernel
# slope. They are different instruments on different bases. This script prints its basis in its own
# header line so a pasted table cannot lose it.
#
# THE THREE ANGLES, mapped onto a whole-program unit:
#   Angle 1 -- TIME-mode : fixed wall-clock budget; count COMPLETED RUNS -> runs/s.
#   Angle 2 -- ITER-mode : fixed RUN COUNT (REPS_A2); measure total external CPU -> runs/s.
#   Angle 3 -- TELEMETRY : tools/bench_rusage wraps EVERY arm of angles 1 and 2 -- cpu(user+sys),
#              elapsed(CLOCK_MONOTONIC), maxrss, nivcsw, and ru_inblock/ru_oublock. Disk is a
#              CONTAMINATION signal, never folded into the verdict (same role it plays in the
#              kernel script): these demos read stdin from a file, so inblock is NOT expected to be
#              0 the way it is for the in-memory kernels -- it is reported, and judged by eye.
#   CROSS-PROVE OR VOID: angle 1 and angle 2 must land within TOL_PCT of each other per (demo,
#   engine). DISAGREE does not stop the run and does not delete the readings -- it marks that row
#   NOT CITABLE. Same posture as the kernel script.
#
# ⛔⭐ CORRECTNESS GATES THE NUMBER, AND EXIT STATUS IS **NOT** THE GATE (measured, 2026-08-27).
# On a too-large input the clean oracle prints "ERROR 246 -- stack overflow", emits an EMPTY answer,
# and STILL EXITS 0. A harness trusting rc would have published a fast, confident, wrong row. So the
# gate is CROSS-ENGINE OUTPUT AGREEMENT: sbl anchors where sbl runs; a mismatch VOIDs the row.
# ⛔ beauty has NO oracle column at all -- SPITBOL fails on it outright (exit=1, empty output; the
# s264 board recorded the same as ORACLE_FAIL sbl rc=139). Its row is m3/m4 only and prints NO
# multiple, because there is nothing to be a multiple OF. It is not dropped and not quietly zeroed.
#
# EXIT: 0 = every measured row AGREE. 1 = at least one DISAGREE or VOID (grid still printed, marked).
#       2 = REFUSED (scrip unbuilt, oracle missing/not -bf-capable, bench_rusage stale, corpus gone).
# USAGE: bash ../harness/scripts/bench_triangulate_demos_snobol4.sh [--check-shape] [--out FILE]
#        BUDGET_MS=3000 REPS_A2=5 TOL_PCT=15 ENGINES="sbl m3 m4" DEMOS="claws5 json" ...
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"
D="${DEMO_DIR:-$S4E/corpus/demos/snobol4}"
SCALETSV="${DEMO_SCALE:-$D/DEMO-SCALE.tsv}"
TOL="${TOL_PCT:-15}"
BUDGET_MS="${BUDGET_MS:-3000}"
REPS_A2="${REPS_A2:-5}"
ENGINES="${ENGINES:-sbl m3 m4}"
NOHUGE="${SCRIP_NOHUGE:-1}"
OUT=""; CHECK_SHAPE=0
while [ $# -gt 0 ]; do case "$1" in --check-shape) CHECK_SHAPE=1;; --out) OUT="$2"; shift;; esac; shift; done

. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200)." >&2; exit 2; }
# ⛔ NO SIZE IS TYPED HERE (ceo CEO-1485 over the equal-arena arm, RULES.md clause 8 (g)(3)-(4)): each engine runs at its own shipped defaults
# plus the PROGRAM's declaration, measured at its DEMO-SCALE.tsv scale -- its <stem>.oracle_args on sbl, its <stem>.heap/.stack as SCRIP's
# -d/-s in both modes -- read once per row by lib_declared_arena.sh; the window is never typed. CRITERION CHANGED 2026-10-03: readings
# before ran DEMO-SCALE.tsv's sbl_extra_flags (-d512m -i64m -s256m, now retired) on sbl, its -s as ulimit -s on all three engines, and
# SCRIP under SCRIP_HEAP_MB=4096, a 4 GB WINDOW.
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_declared_arena.sh -- the one reader of a declared size." >&2; exit 2; }
SWD=""; OAD=""
. "$HERE/lib_perf_fmt.sh"    2>/dev/null || { echo "⛔ REFUSED: cannot load lib_perf_fmt.sh -- the ONE authority for printing a multiple (s266)." >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED: scrip not built ($SCRIP) -- a table printed without it would be plausible and false." >&2; exit 2; }
SBL="$(sbl_clean_bin)" || { echo "⛔ REFUSED: clean SPITBOL benchmark oracle missing or not -bf-capable." >&2; exit 2; }
[ -d "$D" ] || { echo "⛔ REFUSED: demo corpus missing ($D)." >&2; exit 2; }
[ -f "$SCALETSV" ] || { echo "⛔ REFUSED: $SCALETSV missing -- scales are MEASURED ceilings, never guessed at run time." >&2; exit 2; }
WRAP="$ROOT/tools/bench_rusage"
if [ ! -x "$WRAP" ]; then gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build." >&2; exit 2; }; fi
if ! "$WRAP" true 2>&1 | grep -q 'inblock='; then
  echo "⛔ REFUSED: $WRAP predates the inblock/oublock fields -- angle 3 would report empty. Rebuild: gcc -O2 -o $WRAP $ROOT/tools/bench_rusage.c" >&2; exit 2; fi

W="${DEMO_WORK:-${TMPDIR:-/tmp}/demo3a.$$}"; mkdir -p "$W" || exit 2
RT="$ROOT/out"
trap 'rm -rf "$W"' EXIT

# ---- scaled input, built once and cached by (name,scale) -------------------------------------
scaled_input() {                       # $1=name $2=srcfile $3=scale ; echoes path
  local f="$W/$1.x$3"
  [ -s "$f" ] && { echo "$f"; return; }
  if [ "$3" = 1 ]; then ln -sf "$2" "$f"; else local i; for ((i=0;i<$3;i++)); do cat "$2"; done > "$f"; fi
  echo "$f"
}
# ---- ONE run. echoes: cpu_ms elapsed_ms inblock oublock rc <TAB> output-digest ----------------
run1() {                               # $1=engine $2=prog $3=input $4=stem $5=sblflags
  local eng="$1" prog="$2" in="$3" stem="$4" out rl u s el ib ob rc
  case "$eng" in                       # SWD and OAD: the row's program's declaration, read once per row
    sbl) out=$("$WRAP" timeout -k 5 300 "$SBL" $(sbl_lang_flags) $OAD "$prog" <"$in" 2>"$W/e.err") ;;
    m3)  out=$(SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 300 "$SCRIP" --run $SWD "$prog" <"$in" 2>"$W/e.err") ;;
    m4)  [ -x "$W/$stem.prog" ] || {
           "$SCRIP" --compile "$prog" > "$W/$stem.s" 2>/dev/null
           [ -s "$W/$stem.s" ] && gcc -no-pie "$W/$stem.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$stem.prog" 2>/dev/null \
             || { echo "- - - - BUILD-ERR	BUILD-ERR"; return; }; }
         out=$(SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 300 "$W/$stem.prog" $SWD <"$in" 2>"$W/e.err") ;;
  esac
  rl=$(grep '^BENCH_RUSAGE:' "$W/e.err" | tail -1)
  [ -n "$rl" ] || { echo "- - - - CRASH	CRASH"; return; }
  u=$(grep -oE 'user_us=[0-9]+' <<<"$rl"|cut -d= -f2); s=$(grep -oE 'sys_us=[0-9]+' <<<"$rl"|cut -d= -f2)
  el=$(grep -oE 'elapsed_ns=[0-9]+' <<<"$rl"|cut -d= -f2)
  ib=$(grep -oE 'inblock=[0-9]+' <<<"$rl"|cut -d= -f2); ob=$(grep -oE 'oublock=[0-9]+' <<<"$rl"|cut -d= -f2)
  rc=$(grep -oE 'exit=[0-9]+' <<<"$rl"|cut -d= -f2)
  # ⛔ the ANSWER, not the exit code, is the correctness signal. Empty output is never a pass.
  local dg; dg=$(printf '%s' "$out" | md5sum | cut -c1-12); [ -n "$out" ] || dg="EMPTY"
  awk -v u="${u:-0}" -v s="${s:-0}" -v e="${el:-0}" -v i="${ib:-0}" -v o="${ob:-0}" -v r="${rc:-?}" -v d="$dg" \
      'BEGIN{printf "%.2f %.2f %s %s %s\t%s\n",(u+s)/1000,e/1000000,i,o,r,d}'
}
# ---- ANGLE 1: fixed TIME budget, count completed runs ----------------------------------------
angle1() {                             # echoes: runs_per_s runs cpu_ms_total digest
  local eng="$1" prog="$2" in="$3" stem="$4" t0 now n=0 cpu=0 dg="" r
  t0=$(date +%s%N)
  while :; do
    r=$(run1 "$eng" "$prog" "$in" "$stem"); local c; c=$(awk '{print $1}' <<<"$r")
    [ "$c" = "-" ] && { echo "- 0 - $(cut -f2 <<<"$r")"; return; }
    n=$((n+1)); cpu=$(awk -v a="$cpu" -v b="$c" 'BEGIN{print a+b}'); dg=$(cut -f2 <<<"$r")
    now=$(date +%s%N); [ $(( (now-t0)/1000000 )) -ge "$BUDGET_MS" ] && break
  done
  awk -v n="$n" -v c="$cpu" -v d="$dg" 'BEGIN{printf "%.4f %d %.2f %s", (c>0)?n/(c/1000):0, n, c, d}'
}
# ---- ANGLE 2: fixed RUN count, measure total CPU ----------------------------------------------
angle2() {                             # echoes: runs_per_s runs cpu_ms_total digest ib ob el
  local eng="$1" prog="$2" in="$3" stem="$4" i n=0 cpu=0 dg="" ib=0 ob=0 el=0 r
  for ((i=0;i<REPS_A2;i++)); do
    r=$(run1 "$eng" "$prog" "$in" "$stem"); local c; c=$(awk '{print $1}' <<<"$r")
    [ "$c" = "-" ] && { echo "- 0 - $(cut -f2 <<<"$r") 0 0 0"; return; }
    n=$((n+1)); cpu=$(awk -v a="$cpu" -v b="$c" 'BEGIN{print a+b}')
    el=$(awk -v a="$el" -v b="$(awk '{print $2}' <<<"$r")" 'BEGIN{print a+b}')
    ib=$(awk '{print $3}' <<<"$r"); ob=$(awk '{print $4}' <<<"$r"); dg=$(cut -f2 <<<"$r")
  done
  awk -v n="$n" -v c="$cpu" -v d="$dg" -v i="$ib" -v o="$ob" -v e="$el" \
      'BEGIN{printf "%.4f %d %.2f %s %s %s %.2f", (c>0)?n/(c/1000):0, n, c, d, i, o, e}'
}

[ -n "$OUT" ] || OUT="$W/demo-triangulation.tsv"
echo "THREE-ANGLE DEMO TRIANGULATION -- SNOBOL4 demo programs"
echo "⛔ BASIS: one iteration = ONE WHOLE PROGRAM RUN. Every number is a TOTAL carrying process"
echo "   startup AND compile -- NOT a kernel slope. Never share a column with benchmarks/snobol4."
echo "instrument: tools/bench_rusage external cpu(user+sys); engines: $ENGINES; budget(a1)=${BUDGET_MS}ms; reps(a2)=$REPS_A2; tol=${TOL}%"
echo "oracle: $SBL $(sbl_lang_flags); RT_OPT=-O0; sizes: each program's own .oracle_args (sbl) and .heap/.stack (SCRIP -d/-s) over each engine's defaults -- CRITERION CHANGED 2026-10-03 (CEO-1485): earlier readings ran sbl -d512m -i64m -s256m, ulimit -s 262144 on all three engines and a 4 GB SCRIP window"
echo "trees: SCRIP $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)  corpus $(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)"
# ⛔ THE GRID OPENS HERE so no multiple below can print without the load it ran under, and so a cell that
# REFUSES is counted in THIS shell (perf_row is called directly, never inside $( ) -- arm G of the dark-cell gate).
perf_grid_begin "demo vs SPITBOL -- x on the FASTER axis (SPITBOL/ours) · TOTAL basis, whole-program run incl startup+compile · instrument tools/bench_rusage cpu(user+sys) · RT_OPT=-O0"
echo
printf "%-11s %-6s %12s %12s %9s %-9s %7s %7s %s\n" DEMO ENGINE "a1 runs/s" "a2 runs/s" "ratio" "VERDICT" "inblk" "oublk" "answer"
printf '%s\n' "-------------------------------------------------------------------------------------------------------"
: > "$OUT"
printf '# demo-triangulation -- basis=WHOLE-PROGRAM-RUN (total, incl startup+compile) -- never a kernel slope\n' >> "$OUT"
printf 'demo\tengine\tscale\ta1_runs_per_s\ta1_runs\ta2_runs_per_s\ta2_runs\ta2_cpu_ms_mean\tratio\tverdict\tinblock\toublock\tanswer_digest\n' >> "$OUT"

RC=0; ROWS=0
while IFS=$'\t' read -r fam prog input scale _retired note; do   # column 5 (sbl_extra_flags) is retired, "declared"
  case "$fam" in ''|\#*) continue;; esac
  [ -n "${DEMOS:-}" ] && ! grep -qw "$fam" <<<"$DEMOS" && continue
  [ "$CHECK_SHAPE" = 1 ] && [ "$ROWS" -ge 1 ] && break
  P="$D/$prog"; SRC="$D/$input"
  [ -f "$P" ] && [ -f "$SRC" ] || { echo "⛔ UNPROVEN $fam -- missing program or input ($prog / $input); NAMED, not dropped."; RC=1; continue; }
  IN="$(scaled_input "$fam" "$SRC" "$scale")"
  SWD="$(declared_switches_beside "$P")" && OAD="$(declared_oracle_args_beside "$P")" || { echo "⛔ UNPROVEN $fam -- its declared sizes are refused (named above); NAMED, not dropped."; RC=1; continue; }
  declare -A A1 A2 DG CPU IB OB
  for e in $ENGINES; do
    r1=$(angle1 "$e" "$P" "$IN" "$fam"); r2=$(angle2 "$e" "$P" "$IN" "$fam")
    A1[$e]=$(awk '{print $1}' <<<"$r1"); A2[$e]=$(awk '{print $1}' <<<"$r2")
    DG[$e]=$(awk '{print $4}' <<<"$r2"); CPU[$e]=$(awk -v c="$(awk '{print $3}' <<<"$r2")" -v n="$(awk '{print $2}' <<<"$r2")" 'BEGIN{print (n>0)?c/n:0}')
    IB[$e]=$(awk '{print $5}' <<<"$r2"); OB[$e]=$(awk '{print $6}' <<<"$r2")
  done
  # correctness anchor: sbl if it produced a real answer, else m3 (and say so)
  ANCH=""; for e in $ENGINES; do case "${DG[$e]:-}" in ''|EMPTY|CRASH|BUILD-ERR) ;; *) [ -z "$ANCH" ] && ANCH="$e";; esac; done
  for e in $ENGINES; do
    a1="${A1[$e]:--}"; a2="${A2[$e]:--}"; d="${DG[$e]:-CRASH}"
    if [ "$a1" = "-" ] || [ "$a2" = "-" ]; then v="UNPROVEN"; ratio="-"
    else
      ratio=$(awk -v a="$a1" -v b="$a2" 'BEGIN{m=(a>b)?a:b; n=(a<b)?a:b; printf "%.4f",(n>0)?m/n:0}')
      v=$(awk -v r="$ratio" -v t="$TOL" 'BEGIN{print ((r-1)*100<=t)?"AGREE":"DISAGREE"}')
    fi
    if [ -n "$ANCH" ] && [ "$d" != "${DG[$ANCH]}" ]; then v="VOID-ANSWER"; fi
    case "$d" in EMPTY|CRASH|BUILD-ERR) v="VOID-$d";; esac
    case "$v" in AGREE) ;; *) RC=1;; esac
    printf "%-11s %-6s %12s %12s %9s %-9s %7s %7s %s\n" "$fam" "$e" "$a1" "$a2" "$ratio" "$v" "${IB[$e]:--}" "${OB[$e]:--}" "$d"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$fam" "$e" "$scale" "$a1" "-" "$a2" "$REPS_A2" "${CPU[$e]:--}" "$ratio" "$v" "${IB[$e]:--}" "${OB[$e]:--}" "$d" >> "$OUT"
  done
  # ---- the published multiple ----------------------------------------------------------------
  # ⛔⭐ A MULTIPLE IS PRINTED ONLY WHEN BOTH SIDES ANSWERED, AND ANSWERED THE SAME. Measured
  # 2026-08-27, and it is why this guard is not merely defensive: the first cut of this script
  # gated only on "sbl produced something" and duly printed `calculator m3 vs SPITBOL 14.673x`
  # and `beauty m3 vs SPITBOL 0.001x` -- both spectacular, both fiction. SCRIP had emitted NOTHING
  # (ERROR 246) and was therefore very fast at it. ⭐ A WRONG ANSWER IS NEVER A FAST ANSWER, and a
  # VOID verdict two columns to the left does NOT stop a reader pasting the number: the row said
  # VOID-EMPTY and printed 14.673x on the very next line. So the suppression has to happen where
  # the number is FORMATTED, not where it is judged.
  if [ -z "${CPU[sbl]:-}" ] || [ "${CPU[sbl]}" = "0" ] || [ "${CPU[sbl]}" = "-" ]; then
    echo "    ⛔ $fam: NO ORACLE COLUMN -- SPITBOL did not run. No multiple; there is nothing to be a multiple OF."
  elif [ -z "${DG[sbl]:-}" ] || [ "${DG[sbl]}" = "EMPTY" ] || [ "${DG[sbl]}" = "CRASH" ]; then
    echo "    ⛔ $fam: NO ORACLE COLUMN -- SPITBOL produced no usable answer. No multiple."
  else
    for e in m3 m4; do
      [ -n "${CPU[$e]:-}" ] || continue
      if [ "${CPU[$e]}" = "0" ] || [ "${CPU[$e]}" = "-" ]; then
        echo "    ⛔ $fam $e: no usable timing -- NO MULTIPLE."
      elif [ "${DG[$e]:-}" != "${DG[sbl]}" ]; then
        echo "    ⛔ $fam $e: ANSWER DIVERGES FROM THE ORACLE (${DG[$e]:-none} vs ${DG[sbl]}) -- NO MULTIPLE IS PRINTED. A wrong answer is never a fast answer."
      else
        perf_row "  $fam $e vs SPITBOL" "${CPU[sbl]}" "${CPU[$e]}"
      fi
    done
  fi
  unset A1 A2 DG CPU IB OB; ROWS=$((ROWS+1)); echo
done < "$SCALETSV"

perf_grid_end || RC=1
echo "rows measured: $ROWS   TSV: $OUT"
[ "$RC" = 0 ] && echo "✅ every measured row AGREE across angle 1 and angle 2." \
              || echo "⛔ at least one row DISAGREE/VOID/UNPROVEN -- those rows are NOT CITABLE. Raw readings kept above."
exit $RC
