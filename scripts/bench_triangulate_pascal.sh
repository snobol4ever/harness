#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_pascal.sh -- THE CROSS-PROOF for Pascal (row bench-rivals-raku-pascal), mirroring
# bench_triangulate_prolog.sh's architecture per ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE
# TRIANGULATION. Runs angle 1 (test_bench_pascal_timed.sh -- fixed TIME, live-searched reps) and angle 2
# (bench_pascal_fixed_iter.sh -- fixed reps, committed in SCALE.tsv) UNMODIFIED -- one authority per
# mechanism -- then compares the two independently-derived rates per kernel per engine (fpc/m3/m4). AGREE
# within TOL_PCT (flat 10%, UNBAKED -- no NOISE-FLOOR.tsv exists for pascal yet), DISAGREE otherwise.
#
# ⛔ SCOPE: the 7 reps-capable kernels only (bubble/intmm/perm/queens/quick/sieve/towers). `uplevel2`/
# `uplevel3` (fixed 30000x8000 workload, no reps knob), `fbench` (SIGSEGVs at compile time), and `whet`
# (no committed .ref) are named in corpus/benchmarks/pascal/EXCLUDED.tsv with their reasons -- never
# silently dropped, per test_gate_bench_rivals_coverage.sh's three-bucket (measured/declared/refuse) law.
#
# THE THIRD ANGLE (disk): one direct tools/bench_rusage sample per kernel (m3, reps=1) reads
# ru_inblock/ru_oublock. Expected ~0 for these in-memory kernels; nonzero is a finding, not folded into
# AGREE/DISAGREE (same role as the SNOBOL4/Prolog triangulators' disk angle).
#
# EXIT: 0 = every measured kernel/engine AGREEs (or all UNPROVEN, zero DISAGREE). 1 = at least one
# DISAGREE. 2 = REFUSED -- missing scrip/oracle/corpus, loud, never a plausible table.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
PDIR="${PASCAL_DIR:-$S4E/corpus/benchmarks/pascal}"
TOL="${TOL_PCT:-10}"
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_perf_fmt.sh -- the ONE authority for printing a multiple (s266)." >&2; exit 2; }
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared sidecars (CEO-1281)." >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED: scrip not built ($SCRIP)." >&2; exit 2; }
[ -d "$PDIR" ] || { echo "⛔ REFUSED: pascal corpus missing ($PDIR)." >&2; exit 2; }
WRAP="$ROOT/tools/bench_rusage"; [ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build." >&2; exit 2; }

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_TSV="${OUT_TSV:-$PDIR/triangulation-$TS.tsv}"

echo "PASCAL THREE-ANGLE TRIANGULATION -- angle 1 (fixed time) vs angle 2 (fixed reps) vs disk telemetry"
echo "both angles now report WORK (us/rep, COST basis -- lower is faster) via a 3-point slope fit, not the"
echo "old single-point rate=reps/cpu (SLOPE CURE, see test_bench_pascal_timed.sh / bench_pascal_fixed_iter.sh headers)"
echo "tolerance: flat TOL_PCT=$TOL% (UNBAKED -- no NOISE-FLOOR.tsv for pascal yet)"
echo

# Both angles grade THIS population (the coo 2026-10-03): they were called bare, so each read its own default corpus while the disk
# telemetry below read PASCAL_DIR -- a scratch PASCAL_DIR triangulated the real kernels' angles against its own sidecars.
A1_OUT="$(BENCH_DIR="$PDIR" bash "$HERE/test_bench_pascal_timed.sh" 2>/dev/null)"
A2_OUT="$(BENCH_DIR="$PDIR" bash "$HERE/bench_pascal_fixed_iter.sh" 2>/dev/null)"

# state-machine parse, same shape as bench_triangulate_snobol4.sh/bench_triangulate_prolog.sh's own
# parse_angle1/2: start on the dashes separator line, stop on the first blank line after.
parse() { awk -v ncol="$1" 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started&&NF>=ncol{print}' ; }
dehuman() { awk -v v="$1" 'BEGIN{ if (v=="NA"||v=="-"||v=="") {print ""; exit} print v+0 }'; }

declare -A A1 A2 KSEEN
while read -r k f m3 m4 rest; do
  [ -z "$k" ] && continue
  A1["$k:fpc"]="$f"; A1["$k:m3"]="$m3"; A1["$k:m4"]="$m4"; KSEEN["$k"]=1
done < <(printf '%s\n' "$A1_OUT" | parse 5)
while read -r k nf ns f m3 m4 rest; do
  [ -z "$k" ] && continue
  A2["$k:fpc"]="$f"; A2["$k:m3"]="$m3"; A2["$k:m4"]="$m4"; KSEEN["$k"]=1
done < <(printf '%s\n' "$A2_OUT" | parse 7)

{
  echo -e "# triangulation TSV -- $TS -- TOL_PCT=$TOL (flat, UNBAKED) -- never hand-edit, regenerate via bench_triangulate_pascal.sh"
  echo -e "kernel\tengine\tangle1_rate\tangle2_rate\tratio\tverdict\tdisk_inblock\tdisk_oublock"
} > "$OUT_TSV"

kernels=$(printf '%s\n' "${!KSEEN[@]}" | sort)
any_disagree=0
for k in $kernels; do
  ib=""; ob=""
  if [ -f "$PDIR/$k.pas" ]; then
    # a sidecar the reader refuses is could-not-measure, never the default (the coo 2026-10-03: this read `|| dsw=""` with the
    # reader's reason sent to /dev/null, so a malformed .heap or .stack ran the kernel at the shipped size and said nothing)
    dsw=$(declared_switches_beside "$PDIR/$k.pas") || { echo "⛔ REFUSED: $k: a .heap or .stack sidecar the reader refuses (it said why above)" >&2; exit 2; }
    dline=$(printf '1\n' | "$WRAP" "$SCRIP" --run $dsw "$PDIR/$k.pas" 2>&1 >/dev/null | grep '^BENCH_RUSAGE:' | tail -1)
    ib=$(echo "$dline" | grep -oE 'inblock=[0-9]+' | cut -d= -f2); ob=$(echo "$dline" | grep -oE 'oublock=[0-9]+' | cut -d= -f2)
  fi
  diskflag=""; { [ -n "$ib" ] && [ "$ib" -gt 0 ] 2>/dev/null; } && diskflag=" disk(inblock=$ib)"

  row_bits=""
  for eng in fpc m3 m4; do
    r1=$(dehuman "${A1["$k:$eng"]:-}"); r2=$(dehuman "${A2["$k:$eng"]:-}")
    if [ -n "$r1" ] && [ -n "$r2" ] && [ "$r1" != "0" ]; then
      verdict=$(awk -v a="$r1" -v b="$r2" -v t="$TOL" 'BEGIN{ ratio=b/a; lo=(100-t)/100; hi=(100+t)/100; print (ratio>=lo && ratio<=hi) ? "AGREE" : "DISAGREE" }')
      ratio=$(awk -v a="$r1" -v b="$r2" 'BEGIN{printf "%.4f", b/a}')
      [ "$verdict" = DISAGREE ] && any_disagree=1
      row_bits="$row_bits $eng=$verdict(${ratio}x)"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$eng" "$r1" "$r2" "$ratio" "$verdict" "${ib:-}" "${ob:-}" >> "$OUT_TSV"
    else
      row_bits="$row_bits $eng=UNPROVEN"
      printf '%s\t%s\t%s\t%s\t\tUNPROVEN\t%s\t%s\n' "$k" "$eng" "${r1:-NA}" "${r2:-NA}" "${ib:-}" "${ob:-}" >> "$OUT_TSV"
    fi
  done
  printf '%-10s%s%s\n' "$k" "$row_bits" "$diskflag"
done

echo
grid_incomplete=0
RT_OPT_READ=$(readelf --debug-dump=info "$ROOT/out/libscrip_rt.so" 2>/dev/null | grep -m1 -o ' -O[0-3sg]' | tr -d ' '); RT_OPT_READ="${RT_OPT_READ:-?}"
perf_grid_begin "FACT-RULE grid: m3 vs fpc, m4 vs fpc (angle 1 numbers; WORK metric, us/rep COST basis, axis named once here, RT_OPT=$RT_OPT_READ SCRIP read from libscrip_rt.so DWARF / fpc -O2 released default)"
# ⛔ perf_row/perf_mult (lib_perf_fmt.sh) take (LABEL, REF, OURS) and are documented as COST inputs
# (lower=better; multiple=ref/ours). fpc is the reference, m3/m4 are ours -- REF FIRST, OURS SECOND. The
# pre-slope code here fed RATE values (reps/s, bigger=better) with the args the OTHER way round (ours in
# the ref slot), which happened to cancel out for that inverted convention; now that angle 1 reports WORK
# (a genuine cost), that swap would silently invert every published multiple if left in place.
for k in $kernels; do
  rf=$(dehuman "${A1["$k:fpc"]:-}"); r3=$(dehuman "${A1["$k:m3"]:-}"); r4=$(dehuman "${A1["$k:m4"]:-}")
  perf_row_or_refuse "$k  m3 vs fpc" "$rf" "$r3"
  perf_row_or_refuse "$k  m4 vs fpc" "$rf" "$r4"
done
[ -z "$kernels" ] && echo "  (no kernel had both angle-1 and angle-2 numeric rates for any SCRIP engine this run)"
perf_grid_end || grid_incomplete=1

echo
echo "TSV: $OUT_TSV"
if [ "${CHECK_SHAPE:-0}" != 1 ]; then . "$HERE/lib_progress.sh"; progress_append_triangulation pascal "$OUT_TSV" || { echo "⛔ bench_triangulate_pascal: the progress database did not take this run's kernels (see above) -- a benchmark run that leaves the table untouched is a defect of the run (progress/README.md, CEO-331)"; exit 2; }; fi
if [ "$any_disagree" -eq 1 ]; then
  echo "⛔ DISAGREE present -- VOID: do not publish or cite those kernel/engine cells until re-measured."
  exit 1
fi
if [ "$grid_incomplete" -eq 1 ]; then
  echo "⛔ the FACT-RULE grid above is INCOMPLETE -- a cell REFUSED (its subject is named on stderr). VOID as a reading: a dark cell is worse than a red one (CEO-676), so do not publish or cite this grid until every cell measures."
  exit 1
fi
echo "no DISAGREE (measured cells, if any, all AGREE; UNPROVEN cells need an EXCLUDED.tsv line, not a citation)."
exit 0
