#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_prolog.sh -- THE CROSS-PROOF for Prolog (row bench-rivals-prolog), mirroring
# bench_triangulate_snobol4.sh's architecture per ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE
# TRIANGULATION. Runs angle 1 (test_bench_prolog_timed.sh -- fixed TIME, live-searched iters) and angle 2
# (bench_prolog_fixed_iter.sh -- fixed ITERS, committed N, measured time) UNMODIFIED -- one authority per
# mechanism, this script does not re-implement either -- then compares the two independently-derived
# iters/s rates per kernel per engine (gnu/swi/m3/m4). AGREE within TOL_PCT (flat 10%, UNBAKED -- no
# NOISE-FLOOR.tsv exists for prolog yet; a future bake_noise_floor_prolog.sh could add the same per-row
# floor the SNOBOL4 side uses), DISAGREE otherwise. A kernel/engine either angle could not measure
# (correctness-skip, crash, DNF) is UNPROVEN, never silently dropped -- the gate
# (test_gate_bench_rivals_coverage.sh) requires every corpus kernel to be MEASURED (AGREE row here) or
# DECLARED (a named line in EXCLUDED.tsv); an UNPROVEN row satisfies neither, by design, so a kernel stuck
# at UNPROVEN must get its own EXCLUDED.tsv line naming why -- this script never writes that file itself.
#
# ⛔⛔ THIS WARNING WAS RETIRED BY ceo ON 2026-08-30 AND IS HEREBY REINSTATED — THE RETIREMENT WAS MADE
# ON A MEASUREMENT OF MINE THAT WAS WRONG, AND I AM THE ONE WHO SUPPLIED IT (hq_B). ceo's note read
# "STALE WARNING RETIRED ... the fixed-iteration angles are AVAILABLE". They are NOT. I had reported that
# 50 repeated entries run clean in both modes; that is true and it is IRRELEVANT, because the repro I ran
# was tail-recursive and the kernels are not. Running the real instrument afterwards, m3 CRASHES ON ALL 21
# VANROY KERNELS (signal 11 x10, signal 6 x5 in the first 15) while gnu/swi fill normally. A probe that
# does not reproduce the caller's invocation measures a different program — and I committed that error
# hours after writing the rule down. Retraction and full evidence: .github 69b5cfe0.
# ⛔ EXPECT ZERO AGREE ROWS FOR m3/m4 -- STILL TRUE 2026-08-30, BUT FOR A MUCH NARROWER REASON THAN THIS
# HEADER USED TO STATE, AND THE NARROWING IS THE USEFUL PART (hq_B, FINDING-2026-08-30-hq_B-angle2-
# blocked-by-one-goal-after-a-binding-call-8-line-witness.md).
# This header used to say the backend "crashes on ANY repeated entry into a compiled user predicate
# (backtrack-driven, flat-sequential, or tail-recursive alike)". MEASURED 2026-08-30, that is OVER-BROAD:
#     tail-recursive repeated entry              -> WORKS (50 reps clean, m3 23617us / m4 23096us)
#     plain between/3 + fail failure-driven loop -> WORKS
# What actually crashes is a NAMED VARIABLE BOUND BY A USER-PREDICATE CALL FOLLOWED BY ONE MORE GOAL,
# re-entered by backtracking. One trailing `true` is the entire difference:
#     bench__main :- fib(10,_).               rc=0     bench__main :- fib(10,F).               rc=0
#     bench__main :- fib(10,F), true.         rc=134   bench__main :- fib(10,F), write(F), nl. rc=134
# ("stack smashing detected", BOTH m3 and m4; swipl runs the same program at rc=0.)
# ⭐ THAT IS WHY ALL 21 KERNELS CRASH AT ONCE instead of a scattered subset: every vanroy kernel is
# bench__main :- <compute>(...,F), write(F), nl. -- exactly the crashing shape, all 21. A population that
# is UNIFORM in the deciding variable can never localize the defect it is uniform in, which is why this
# board was the wrong instrument for it and an 8-line witness was the right one.
# ⛔ WHY THE OVER-BROAD FORM COST SOMETHING: it tells a seat that all repeated entry is broken, so nobody
# tries the two shapes that DO work -- pessimism in a header stops attempts that would have succeeded,
# exactly as optimism hides failures. Keep this narrowed if the defect moves; do not widen it back for
# safety. Original claim and its provenance -- see FINDING-2026-08-27-seat14-prolog-second-call-into-any-user-predicate-
# crashes-m3-m4.md. This is not a harness defect: the harness is correctly reporting CRASH/UNPROVEN for
# every m3/m4 cell because that is what is actually happening. Re-run this script (no code change needed)
# once the underlying compiler gap (GOAL-PROLOG-100.md PZ-4) lands -- coverage should improve automatically.
#
# THE THIRD ANGLE (disk): one direct tools/bench_rusage sample per kernel (m3, single rep, the raw
# bench/<k>.pl standalone -- every kernel is directly runnable per corpus/benchmarks/prolog/README.md's
# own convention) reads ru_inblock/ru_oublock. Expected ~0 for these in-memory kernels; nonzero is a
# finding, not folded into AGREE/DISAGREE (same role as the SNOBOL4 triangulator's disk angle).
#
# EXIT: 0 = every measured kernel/engine AGREEs (or all UNPROVEN, zero DISAGREE). 1 = at least one
# DISAGREE. 2 = REFUSED -- missing scrip/oracle/corpus, loud, never a plausible table.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/prolog/bench}"
# ⛔ THE TSV LIVES AT THE LANGUAGE ROOT, NOT IN bench/ -- test_gate_bench_rivals_coverage.sh globs
# "$CORPUS/benchmarks/$lang"/triangulation-*.tsv (non-recursive; DIR is corpus/benchmarks/prolog, one
# level above $B). A TSV written into $B would be invisible to the gate the moment a real AGREE row
# needs it (found live, this row, before it could bite -- both dirs happened to be interchangeable for
# an EXCLUDED-everything run, which is why it didn't fail loudly the first time).
PDIR="${PROLOG_DIR:-$S4E/corpus/benchmarks/prolog}"
TOL="${TOL_PCT:-10}"
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_perf_fmt.sh -- the ONE authority for printing a multiple (s266)." >&2; exit 2; }
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1281)." >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED: scrip not built ($SCRIP)." >&2; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED: bench corpus missing ($B)." >&2; exit 2; }
WRAP="$ROOT/tools/bench_rusage"; [ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build." >&2; exit 2; }

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_TSV="${OUT_TSV:-$PDIR/triangulation-$TS.tsv}"

echo "PROLOG THREE-ANGLE TRIANGULATION -- angle 1 (fixed time) vs angle 2 (fixed iters) vs disk telemetry"
echo "tolerance: flat TOL_PCT=$TOL% (UNBAKED -- no NOISE-FLOOR.tsv for prolog yet)"
echo

# KERNELS, if set by the caller, restricts angle 1's OWN correctness-recheck+search to this allowlist too
# (not just angle 2) -- useful to re-verify a known-live subset fast without re-walking the whole corpus's
# correctness gate (which, on a corpus this broken, spends most of its wall-clock timing out on kernels
# already known to crash). Unset (bare use) keeps discovering the live set from the full corpus each run.
A1_OUT="$(KERNELS="${KERNELS:-}" bash "$HERE/test_bench_prolog_timed.sh" 2>/dev/null)"
# angle 1's own correctness gate names the live kernel set (bench/ with .ref, minus correctness-skips) --
# angle 2 is restricted to exactly that set so it never wastes wall-clock re-timing a kernel angle 1 already
# knows is unmeasurable, and the two tables describe the identical kernel set by construction.
# ⛔ SAME FIRST-BLOCK-ONLY RULE AS parse() BELOW, AND FOR THE SAME REASON.  NF>=6 happens to exclude
#   angle 1's 5-field basis grids TODAY, but that is the same column-count coincidence documented at
#   parse(): one column either way and the live-kernel list silently grows duplicates from the N grid.
measured_kernels=$(printf '%s\n' "$A1_OUT" | awk 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started&&NF>=7{print $1}')   # 7 since the gplc column (CEO-1281): kernel + five rates + check
# ⛔ A TRUNCATED KERNEL POPULATION REFUSES, BEFORE ANGLE 2 SPENDS A SECOND ON IT (row prolog-bench-triangulation-silently-dropped-14-
# kernels-and-every-verdict, ceo CEO-1309, the coo 2026-09-27): this script took its kernel set from whatever angle 1 printed, so an
# angle 1 killed, timed out or crashed part-way wrote a shorter table and the triangulation silently graded the survivors -- 14 kernels
# and every verdict dropped once. Angle 1 prints one row per kernel it examines, a rate row or a SKIP row, over every $B/*.pl with a
# .ref beside it narrowed by KERNELS (test_bench_prolog_timed.sh's own loop), so that set is the population and a table naming fewer
# is a truncated reading. An empty population refuses too: a triangulation over nothing is not a grid.
expected_kernels=$(for pl in "$B"/*.pl; do [ -e "$pl" ] || continue; k=$(basename "${pl%.pl}"); [ -f "${pl%.pl}.ref" ] || continue
  if [ -n "${KERNELS:-}" ]; then case " $KERNELS " in *" $k "*) ;; *) continue ;; esac; fi; printf '%s\n' "$k"; done | LC_ALL=C sort -u)
[ -n "$expected_kernels" ] || { echo "⛔ REFUSED (rc=2): no kernel in $B carries a .ref${KERNELS:+ among KERNELS=$KERNELS} -- a population of zero is not a grid" >&2; exit 2; }
missing_kernels=$(LC_ALL=C comm -23 <(printf '%s\n' "$expected_kernels") <(printf '%s\n' "$measured_kernels" | grep . | LC_ALL=C sort -u))
if [ -n "$missing_kernels" ]; then
  echo "⛔ REFUSED (rc=2): angle 1 named $(printf '%s\n' "$measured_kernels" | grep -c .) of the $(printf '%s\n' "$expected_kernels" | grep -c .) kernels in $B -- a truncated population, never triangulated; missing: $(printf '%s' "$missing_kernels" | tr '\n' ' ')" >&2
  exit 2
fi
A2_OUT=""
if [ -n "$measured_kernels" ]; then
  A2_OUT="$(KERNELS="$(printf '%s' "$measured_kernels" | tr '\n' ' ')" bash "$HERE/bench_prolog_fixed_iter.sh" 2>/dev/null)"
fi

# state-machine parse, same shape as bench_triangulate_snobol4.sh's parse_angle1/2: start on the dashes
# separator line, stop on the first blank line after -- NEVER a fixed line-number offset (a trailing
# "CHECK RESULT: ok=.. bad=.." summary line has enough whitespace-separated fields to slip past a bare
# NF>=ncol filter and get misread as a fake kernel named "CHECK"; a hardcoded NR>N is equally fragile
# against either script's header growing by a line).
# ⛔⭐ THE FIRST DASHED BLOCK ONLY, AND THE "done" FLAG IS THE WHOLE POINT (hq_P 2026-09-13).
#   This state machine used to RESTART on every /^-{5,}/ line, which was harmless only while each angle
#   printed exactly one table.  Both angles now publish the two-number basis UNDER the rate table, each
#   grid introduced by its own dashed rule -- so the machine re-armed and kept reading, and because the
#   consuming `while read` loop assigns by KEY, THE LAST GRID SILENTLY WON: the triangulator would have
#   compared angle 1's OVERHEAD MICROSECONDS against angle 2's ITERATION RATES and printed a full,
#   plausible agreement table out of two different quantities.
#   ⛔ MEASURED, and the measurement is the reason this comment is long: angle 2 is UNAFFECTED TODAY --
#   but only BY ACCIDENT.  Its rate table carries 7 fields and its basis grids 5, so the NF>=6 filter
#   happens to exclude them.  Angle 1's rate table carries 6 and is parsed at NF>=5, so its 5-field
#   grids sail straight in.  ⭐ THE PROTECTION WAS A COLUMN-COUNT COINCIDENCE, NEVER A GUARD -- one
#   added column on either side and angle 2 joins angle 1.  Stopping at the first blank line after the
#   first rule does not care how many columns anybody has.
parse() { awk -v ncol="$1" 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started&&NF>=ncol{print}' ; }
# parseblk N ncol -- the Nth dashed block (the rows after the Nth /^-{5,}/ rule up to the first blank line), for the WORK grids both
# angles print under their rate table: angle 1's third block is SELF-MEASURED WORK PER ITERATION (us/iter = work_us / N), angle 2's
# second block is SELF-MEASURED WORK PER ITERATION over each engine's own committed count (N or N_rival). Same first-blank-line rule as parse(), indexed instead of first.
parseblk() { awk -v want="$1" -v ncol="$2" '/^-{5,}/{blk++; started=(blk==want); next} started&&NF==0{started=0; next} started&&NF>=ncol{print}' ; }
# ⛔ A NON-NUMBER IS EMPTY, NEVER 0 (hq_P 2026-09-02): angle 1 prints SKIP for a kernel that failed its correctness gate, and `v+0`
# turned that into a rate of 0 that then printed as a `0 0 n/a` FACT-RULE row -- a zero in a summary is an assertion (RULES.md
# THE INSTRUMENT LAWS, eighth batch §3). Only a numeric cell is a number.
dehuman() { awk -v v="$1" 'BEGIN{ if (v !~ /^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) {print ""; exit} print v+0 }'; }

declare -A A1 A2 KSEEN A1W A2W A2N
while read -r k g gp s m3 m4 rest; do
  [ -z "$k" ] && continue
  A1["$k:gnu"]="$g"; A1["$k:gplc"]="$gp"; A1["$k:swi"]="$s"; A1["$k:m3"]="$m3"; A1["$k:m4"]="$m4"; KSEEN["$k"]=1
done < <(printf '%s\n' "$A1_OUT" | parse 6)
while read -r k n g gp s m3 m4 rest; do
  [ -z "$k" ] && continue
  A2["$k:gnu"]="$g"; A2["$k:gplc"]="$gp"; A2["$k:swi"]="$s"; A2["$k:m3"]="$m3"; A2["$k:m4"]="$m4"; KSEEN["$k"]=1; A2N["$k"]="$n"
done < <(printf '%s\n' "$A2_OUT" | parse 7)
# ⭐ THE WORK BASIS (ceo CEO-1281, 2026-09-26; RULES.md § THE TWO-NUMBER BENCHMARK BASIS: multiples are computed on WORK). The CPU-rate
#   cross-proof above compares N / process CPU at two different N, so a fixed cost inside the process -- mode 3's in-process compile,
#   ~130 ms on deriv -- reads as a per-iteration cost that shrinks with N, and the two angles DISAGREEd on mode 3 for 14 of 23 kernels
#   at 10% while agreeing on mode 4 (the same code with the compile outside the process). The self-measured bracket excludes it.
#   MEASURED on deriv: (a2 CPU - a1 CPU) / (a2 N - a1 N) = 105 us/it, mode 4's own reading, with 134 ms left over -- the compile.
#   So the CITATION verdict (columns ratio/verdict, what the coverage gate and the README read) is the WORK-per-iteration cross-proof
#   whenever both brackets report, and the CPU-rate cross-proof only where a bracket is DARK; the basis column says which, and the
#   CPU columns stay in the record beside it.
while read -r k g gp s m3 m4 rest; do
  [ -z "$k" ] && continue
  A1W["$k:gnu"]="$g"; A1W["$k:gplc"]="$gp"; A1W["$k:swi"]="$s"; A1W["$k:m3"]="$m3"; A1W["$k:m4"]="$m4"
done < <(printf '%s\n' "$A1_OUT" | parseblk 3 6)
while read -r k g gp s m3 m4 rest; do
  [ -z "$k" ] && continue
  A2W["$k:gnu"]="$g"; A2W["$k:gplc"]="$gp"; A2W["$k:swi"]="$s"; A2W["$k:m3"]="$m3"; A2W["$k:m4"]="$m4"
done < <(printf '%s\n' "$A2_OUT" | parseblk 2 6)

{
  echo -e "# triangulation TSV -- $TS -- TOL_PCT=$TOL (flat, UNBAKED) -- never hand-edit, regenerate via bench_triangulate_prolog.sh -- ratio/verdict are the CITATION cross-proof: angle 2 over angle 1 on the self-measured WORK per iteration (us/it, the two-number basis) when both brackets report, else on the CPU rates (basis says which); angle1_rate/angle2_rate are the CPU rates (iterations/s) and cpu_ratio/cpu_verdict their own cross-proof; the declared sidecars ride the SCRIP command lines as -d/-s switches (CEO-1281)"
  echo -e "kernel\tengine\tangle1_rate\tangle2_rate\tratio\tverdict\tdisk_inblock\tdisk_oublock\tbasis\tangle1_work_us_it\tangle2_work_us_it\twork_ratio\tcpu_ratio\tcpu_verdict"
} > "$OUT_TSV"

kernels=$(printf '%s\n' "${!KSEEN[@]}" | sort)
any_disagree=0
for k in $kernels; do
  ib=""; ob=""
  if [ -f "$B/$k.pl" ]; then
    dsw=$(declared_switches_beside "$B/$k.pl" 2>/dev/null) || dsw=""
    dline=$("$WRAP" "$SCRIP" --run $dsw "$B/$k.pl" < /dev/null 2>&1 >/dev/null | grep '^BENCH_RUSAGE:' | tail -1)
    ib=$(echo "$dline" | grep -oE 'inblock=[0-9]+' | cut -d= -f2); ob=$(echo "$dline" | grep -oE 'oublock=[0-9]+' | cut -d= -f2)
  fi
  diskflag=""; { [ -n "$ib" ] && [ "$ib" -gt 0 ] 2>/dev/null; } && diskflag=" disk(inblock=$ib)"

  row_bits=""
  for eng in gnu gplc swi m3 m4; do
    r1=$(dehuman "${A1["$k:$eng"]:-}"); r2=$(dehuman "${A2["$k:$eng"]:-}")
    w1=$(dehuman "${A1W["$k:$eng"]:-}"); w2=$(dehuman "${A2W["$k:$eng"]:-}")   # both angles print WORK PER ITERATION since CEO-1281 (each over its own count)
    cpu_ratio=""; cpu_verdict=""; work_ratio=""; work_verdict=""
    if [ -n "$r1" ] && [ -n "$r2" ] && [ "$r1" != "0" ]; then
      cpu_verdict=$(awk -v a="$r1" -v b="$r2" -v t="$TOL" 'BEGIN{ ratio=b/a; lo=(100-t)/100; hi=(100+t)/100; print (ratio>=lo && ratio<=hi) ? "AGREE" : "DISAGREE" }')
      cpu_ratio=$(awk -v a="$r1" -v b="$r2" 'BEGIN{printf "%.4f", b/a}')
    fi
    if [ -n "$w1" ] && [ -n "$w2" ] && [ "$w1" != "0" ] && [ "$w2" != "0" ]; then
      work_verdict=$(awk -v a="$w1" -v b="$w2" -v t="$TOL" 'BEGIN{ ratio=b/a; lo=(100-t)/100; hi=(100+t)/100; print (ratio>=lo && ratio<=hi) ? "AGREE" : "DISAGREE" }')
      work_ratio=$(awk -v a="$w1" -v b="$w2" 'BEGIN{printf "%.4f", b/a}')
    fi
    if [ -n "$work_verdict" ]; then verdict="$work_verdict"; ratio="$work_ratio"; basis=work
    elif [ -n "$cpu_verdict" ]; then verdict="$cpu_verdict"; ratio="$cpu_ratio"; basis=cpu
    else verdict=UNPROVEN; ratio=""; basis=none; fi
    [ "$verdict" = DISAGREE ] && any_disagree=1
    if [ "$verdict" = UNPROVEN ]; then row_bits="$row_bits $eng=UNPROVEN"; else row_bits="$row_bits $eng=$verdict(${ratio}x $basis)"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$eng" "${r1:-NA}" "${r2:-NA}" "$ratio" "$verdict" "${ib:-}" "${ob:-}" "$basis" "${w1:-NA}" "${w2:-NA}" "$work_ratio" "$cpu_ratio" "${cpu_verdict:-UNPROVEN}" >> "$OUT_TSV"
  done
  printf '%-14s%s%s\n' "$k" "$row_bits" "$diskflag"
done

echo
grid_incomplete=0
perf_grid_begin "FACT-RULE grid: m3 and m4 vs gnu ("$(gprolog_bin)" --consult-file, the byte-code WAM), vs gplc (GNU Prolog compiled native) and vs swi (angle 1's self-measured WORK per iteration, us/it -- the two-number basis, a COST: rival us / SCRIP us, axis named once here; RT_OPT=-O0)"
# ⛔ perf_row_or_refuse takes (LABEL, REF, OURS) as COSTS (lower is faster; multiple = ref / ours): the rival's us/it first, SCRIP's second.
#   The rate form this grid carried until CEO-1281 passed (ours, ref) RATES, which yields the same multiple for a rate and the inverse
#   for a cost -- so the order below is not cosmetic.
for k in $kernels; do
  wg=$(dehuman "${A1W["$k:gnu"]:-}"); wp=$(dehuman "${A1W["$k:gplc"]:-}"); ws=$(dehuman "${A1W["$k:swi"]:-}"); w3=$(dehuman "${A1W["$k:m3"]:-}"); w4=$(dehuman "${A1W["$k:m4"]:-}")
  perf_row_or_refuse "$k  m3 vs gnu" "$wg" "$w3"
  perf_row_or_refuse "$k  m3 vs gplc" "$wp" "$w3"
  perf_row_or_refuse "$k  m3 vs swi" "$ws" "$w3"
  perf_row_or_refuse "$k  m4 vs gnu" "$wg" "$w4"
  perf_row_or_refuse "$k  m4 vs gplc" "$wp" "$w4"
  perf_row_or_refuse "$k  m4 vs swi" "$ws" "$w4"
done
[ -z "$kernels" ] && echo "  (no kernel had both angle-1 and angle-2 numeric rates for any SCRIP engine this run)"
perf_grid_end || grid_incomplete=1

echo
echo "TSV: $OUT_TSV"
if [ "${CHECK_SHAPE:-0}" != 1 ]; then . "$HERE/lib_progress.sh"; progress_append_triangulation prolog "$OUT_TSV" || { echo "⛔ bench_triangulate_prolog: the progress database did not take this run's kernels (see above) -- a benchmark run that leaves the table untouched is a defect of the run (progress/README.md, CEO-331)"; exit 2; }; fi
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
