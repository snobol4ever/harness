#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_snobol4.sh -- THE CROSS-PROOF, item 3 of row bench-triangulation-3angle
# (Lon 2026-08-24, in-chat, verbatim in substance: "I want to cross prove ... All of it wrapped in
# the perf-like process measuring CPU time, disk time, elapsed time -- program-reported numbers
# triangulated with the PERF telemetry. I'm trusting these numbers."). Full law text:
# .github/ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE TRIANGULATION.
#
# WHAT THIS DOES: runs angle 1 (test_bench_snobol4_timed.sh -- fixed TIME, iterations counted) and
# angle 2 (bench_snobol4_fixed_iter.sh -- fixed ITERATIONS, time measured) unmodified -- ONE
# AUTHORITY per mechanism, this script does not re-implement either -- then, per kernel per engine
# (sbl/m3/m4), compares the two independently-derived iters/s rates. AGREE if they land within
# their per-row noise tolerance -- 3*sqrt(cv1^2+cv2^2) read from NOISE-FLOOR.tsv, floored at TOL_PCT
# (default 10%) -- and DISAGREE otherwise. ⛔ TOL_PCT IS A FLOOR, NOT THE TOLERANCE: it was the flat
# tolerance until s277, when it was measured to sit BELOW the noise it was judging (0.94 sigma for
# pattern_bt/sbl => ~35% of rows DISAGREEing from noise alone). A DISAGREE
# VOIDS that kernel's numbers for publication -- the run still completes and the raw readings still
# land in the TSV (the never-redo record), but the verdict says loudly not to cite them.
#
# THE THIRD ANGLE (disk): one direct tools/bench_rusage sample per kernel (m3, single rep, the raw
# .sno run standalone -- every corpus/benchmarks/snobol4 kernel is directly runnable per its own
# header) reads ru_inblock/ru_oublock (added to bench_rusage.c by this same row, item 2). Expected
# ~0 for these in-memory kernels; nonzero is reported as a finding, not folded into AGREE/DISAGREE --
# block-I/O has no "rate" to cross-prove against, it is a contamination signal, same role as nivcsw.
#
# EXIT: 0 = every kernel AGREE (or UNPROVEN with zero DISAGREE). 1 = at least one DISAGREE present
# (published grid printed anyway, loudly marked). 2 = REFUSED -- missing oracle/binary/corpus, loud,
# never a plausible table (SCRIP unbuilt, clean SPITBOL oracle absent/not -bf-capable, bench_rusage
# fails to build). Never silently narrows the kernel set -- a kernel neither angle could measure is
# UNPROVEN and named, not dropped.
#
# --check-shape: proves the MECHANISM cheaply -- one kernel (default array_sum, override with
# CHECK_SHAPE_KERNEL) run end-to-end through both angles + the disk sample, verdict line printed.
# Does not touch the committed TSV (writes to a tmp file instead) -- a smoke test is not a
# measurement campaign and should not proliferate committed data files.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"          # the REAL corpus dir -- always the SCALE.tsv home
TOL="${TOL_PCT:-10}"
CHECK_SHAPE=0
for a in "$@"; do case "$a" in --check-shape) CHECK_SHAPE=1 ;; esac; done
KERNEL="${CHECK_SHAPE_KERNEL:-array_sum}"

. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200)." >&2; exit 2; }
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_perf_fmt.sh -- the ONE authority for printing a multiple (s266)." >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED: scrip not built ($SCRIP) -- a table printed without it would be plausible and false." >&2; exit 2; }
SBL="$(sbl_clean_bin)" || { echo "⛔ REFUSED: clean SPITBOL benchmark oracle missing or not -bf-capable -- see lib_oracle_flags.sh." >&2; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED: benchmark corpus missing ($B)." >&2; exit 2; }
WRAP="$ROOT/tools/bench_rusage"
if [ ! -x "$WRAP" ]; then gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build." >&2; exit 2; }; fi
# item 2's disk columns are load-bearing for this script's own telemetry angle -- refuse rather than
# silently reporting inblock/oublock as empty if a stale pre-item-2 binary is sitting in tools/.
WRAP_SELFTEST="$(mktemp)"; "$WRAP" true >"$WRAP_SELFTEST" 2>&1
if ! grep -q 'inblock=' "$WRAP_SELFTEST"; then
  rm -f "$WRAP_SELFTEST"
  echo "⛔ REFUSED: $WRAP predates the inblock/oublock fields (item 2) -- rebuild: gcc -O2 -o $WRAP $ROOT/tools/bench_rusage.c" >&2
  exit 2
fi
rm -f "$WRAP_SELFTEST"

RUN_B="$B"
CLEANUP=""
if [ "$CHECK_SHAPE" -eq 1 ]; then
  [ -f "$B/$KERNEL.sno" ] || { echo "⛔ REFUSED: --check-shape kernel '$KERNEL' has no $B/$KERNEL.sno" >&2; exit 2; }
  RUN_B="$(mktemp -d)"; CLEANUP="$RUN_B"
  for ext in sno ref dat xfail; do [ -f "$B/$KERNEL.$ext" ] && cp "$B/$KERNEL.$ext" "$RUN_B/"; done
  [ -f "$B/harness.inc" ] && cp "$B/harness.inc" "$RUN_B/"   # bench_wrap.sh looks beside the program for this
fi
trap '[ -n "$CLEANUP" ] && rm -rf "$CLEANUP"' EXIT

TS="$(date -u +%Y%m%dT%H%M%SZ)"
if [ "$CHECK_SHAPE" -eq 1 ]; then OUT_TSV="${OUT_TSV:-$(mktemp)}"; else OUT_TSV="${OUT_TSV:-$B/triangulation-$TS.tsv}"; fi

echo "THREE-ANGLE TRIANGULATION -- angle 1 (fixed time) vs angle 2 (fixed iters) vs disk telemetry"
echo "tree=SCRIP $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?') corpus $(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo '?') RT_OPT=-O0 date=$(date -u +%Y-%m-%d)"
echo "tolerance: PER-ROW, = 3*sqrt(cv_angle1^2 + cv_angle2^2) from $([ -f "${FLOORTSV:-$B/NOISE-FLOOR.tsv}" ] && echo NOISE-FLOOR.tsv || echo '<UNBAKED -- flat floor only>'), floored at TOL_PCT=$TOL%; each row prints the tolerance it was judged against"
[ "$CHECK_SHAPE" -eq 1 ] && echo "mode: --check-shape (kernel=$KERNEL, RUN_B=$RUN_B, OUT_TSV is scratch, not committed)"
echo

# ---- run both angles, unmodified, against RUN_B --------------------------------------------------
A1_OUT="$(BENCH_DIR="$RUN_B" SCALETSV="$B/SCALE.tsv" bash "$HERE/test_bench_snobol4_timed.sh" 2>/dev/null)"
A2_OUT="$(BENCH_DIR="$RUN_B" SCALETSV="$B/SCALE.tsv" bash "$HERE/bench_snobol4_fixed_iter.sh" 2>/dev/null)"

# ---- parse each angle's printed table into kernel<TAB>engine<TAB>human-rate ----------------------
parse_angle1() { awk 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started{print $1"\tsbl\t"$2; print $1"\tm3\t"$3; print $1"\tm4\t"$4}'; }
parse_angle2() { awk 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started{print $1"\tsbl\t"$3; print $1"\tm3\t"$4; print $1"\tm4\t"$5}'; }
# ⛔ "Correctness gates the timing" (ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE, binding): each
# angle already gates its OWN check column (all engines agree + match sbl); a kernel whose rate is
# numeric but whose check column is not ok/ok(x-eng) ran, but its answer is not trusted -- a rate
# agreement on a WRONG answer must never read as AGREE. Last field ($NF) is the check column in both.
parse_angle1_check() { awk 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started{print $1"\t"$NF}'; }
parse_angle2_check() { awk 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started{print $1"\t"$NF}'; }
dehuman() { awk -v v="$1" 'BEGIN{
  if (v=="NA"||v=="-"||v=="") {print ""; exit}
  u=substr(v,length(v),1)
  if (u=="G") {print substr(v,1,length(v)-1)*1e9; exit}
  if (u=="M") {print substr(v,1,length(v)-1)*1e6; exit}
  if (u=="K") {print substr(v,1,length(v)-1)*1e3; exit}
  print v+0 }'; }

declare -A A1 A2 A1C A2C KSEEN
while IFS=$'\t' read -r k e v; do A1["$k:$e"]="$v"; KSEEN["$k"]=1; done < <(printf '%s\n' "$A1_OUT" | parse_angle1)
while IFS=$'\t' read -r k e v; do A2["$k:$e"]="$v"; KSEEN["$k"]=1; done < <(printf '%s\n' "$A2_OUT" | parse_angle2)
while IFS=$'\t' read -r k c; do A1C["$k"]="$c"; done < <(printf '%s\n' "$A1_OUT" | parse_angle1_check)
while IFS=$'\t' read -r k c; do A2C["$k"]="$c"; done < <(printf '%s\n' "$A2_OUT" | parse_angle2_check)
checkok() { case "$1" in ok|ok\(x-eng\)) return 0 ;; *) return 1 ;; esac; }
# ⭐⭐ THE AGREE TOLERANCE IS A PROPERTY OF THE MEASUREMENT, NOT A CONSTANT (hq_P s277, Lon in-chat: "I think it is
# starting at much too low a milli-second value.  I think you have invalid all over the place." -- he was right, and
# it is quantified below).  ⛔ THE DEFECT THIS REPLACES: TOL_PCT was a flat 10% applied to every (kernel, engine),
# while NOISE-FLOOR.tsv -- baked beside this very corpus, by our own script, and carrying MEASURED per-row cv from
# 0.2% to 34.6% -- sat unread.  For pattern_bt/sbl the two angles carry cv 10.4% (angle 1, a 500 ms budget) and 2.4%
# (angle 2, a multi-second window); their RATIO therefore carries cv = sqrt(10.4^2 + 2.4^2) = 10.7%.  A 10% tolerance
# on a 10.7%-cv quantity is 0.94 SIGMA, so ~35% of kernel-engine rows DISAGREE FROM NOISE ALONE -- and a DISAGREE
# VOIDS the kernel for publication.  The instrument was manufacturing its own refusals and reporting them as findings:
# the observed pattern_bt/sbl "DISAGREE 1.1724x" is 1.61 sigma, entirely unremarkable, and it VOIDED a kernel that was
# fine.  ⭐ THIS IS THE PROJECT'S OWN NAMED CLASS FROM THE OTHER SIDE: CLAUDE.md already warns that "a bound tuned to a
# job's measured duration is not tight, it is flaky" about `timeout N`; a TOLERANCE set BELOW its quantity's noise is
# the same error inverted, and it fails the same way -- intermittently, on good data, while looking like a real signal.
# ⛔ A DISAGREE MUST MEAN "THESE TWO MECHANISMS DISAGREE", NEVER "THE BOX WAS BUSY".
# ⭐ CURE: tolerance = 3 * sqrt(cv_angle1^2 + cv_angle2^2), per (kernel, engine), read from the BAKED floor -- 3 sigma
# to match NOISE-FLOOR.tsv's own "min-det = 3*cv" convention -- floored at TOL_PCT so it can only ever widen, never
# narrow, past the caller's intent.  ⛔ NEVER SILENTLY: a row with no baked floor keeps the flat TOL and is LABELLED
# (UNBAKED) in the printed verdict, because an unlabelled fallback is how this defect survived in the first place.
FLOORTSV="${FLOORTSV:-$B/NOISE-FLOOR.tsv}"
declare -A CVROW
if [ -f "$FLOORTSV" ]; then
  while IFS=$'\t' read -r fk fe _thp _reps _rate fcv _rest; do
    case "$fk" in \#*|"") continue ;; esac
    [ -n "$fe" ] && CVROW["$fk:$fe"]="$fcv"
  done < "$FLOORTSV"
fi
# angle 1 rows are keyed by the bare engine name, angle 2 rows by "<engine>-fixed" (as baked).
tol_for() {
  local k="$1" e="$2" c1="${CVROW["$1:$2"]:-}" c2="${CVROW["$1:$2-fixed"]:-}"
  if [ -z "$c1" ] || [ -z "$c2" ]; then printf '%s\tUNBAKED' "$TOL"; return; fi
  awk -v a="$c1" -v b="$c2" -v floor="$TOL" 'BEGIN{ t=3*sqrt(a*a+b*b); if (t<floor) t=floor; printf "%.1f\tBAKED", t }'
}

{
  echo -e "# triangulation TSV -- $TS -- TOL_PCT=$TOL (FLOOR only; the live per-row tolerance is 3*sqrt(cv1^2+cv2^2) from NOISE-FLOOR.tsv) -- never hand-edit, regenerate via bench_triangulate_snobol4.sh"
  echo -e "kernel\tengine\tangle1_rate\tangle2_rate\tratio\tverdict\tdisk_inblock\tdisk_oublock"
} > "$OUT_TSV"

kernels=$(printf '%s\n' "${!KSEEN[@]}" | sort)
any_disagree=0
for k in $kernels; do
  # ---- angle 3 first: direct disk telemetry sample (m3, single rep, raw standalone .sno) ----
  ib=""; ob=""
  if [ -f "$RUN_B/$k.sno" ]; then
    dline=$("$WRAP" "$SCRIP" --run "$RUN_B/$k.sno" < /dev/null 2>&1 >/dev/null | grep '^BENCH_RUSAGE:' | tail -1)
    ib=$(echo "$dline" | grep -oE 'inblock=[0-9]+' | cut -d= -f2)
    ob=$(echo "$dline" | grep -oE 'oublock=[0-9]+' | cut -d= -f2)
  fi
  parts=""
  [ -n "$ib" ] && [ "$ib" -gt 0 ] && parts="inblock=$ib"
  [ -n "$ob" ] && [ "$ob" -gt 0 ] && parts="${parts:+$parts,}oublock=$ob"
  diskflag=""; [ -n "$parts" ] && diskflag=" disk($parts)"

  # ---- correctness gates the timing (binding, ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE):
  # a numeric rate on top of a failed/disagreeing check column is a wrong answer, never a fast one --
  # gate BEFORE rate agreement, don't let a coincidentally-matching rate read as AGREE.
  a1c="${A1C["$k"]:-MISSING}"; a2c="${A2C["$k"]:-MISSING}"
  if ! checkok "$a1c" || ! checkok "$a2c"; then
    any_disagree=1
    printf '%s\t-\t-\t-\t-\tCHECK-FAIL\t%s\t%s\n' "$k" "$ib" "$ob" >> "$OUT_TSV"
    printf '%-20s %-9s angle1_check=%s angle2_check=%s%s\n' "$k" "CHECK-FAIL" "$a1c" "$a2c" "$diskflag"
    continue
  fi

  # ---- angle-1 vs angle-2 per engine ----
  k_disagree=0; k_measured=0; row_bits=""
  for eng in sbl m3 m4; do
    r1h="${A1["$k:$eng"]:-}"; r2h="${A2["$k:$eng"]:-}"
    r1=$(dehuman "$r1h"); r2=$(dehuman "$r2h")
    if [ -n "$r1" ] && [ -n "$r2" ] && [ "$r1" != "0" ]; then
      k_measured=1
      IFS=$'\t' read -r etol etolsrc <<<"$(tol_for "$k" "$eng")"
      verdict=$(awk -v a="$r1" -v b="$r2" -v t="$etol" 'BEGIN{ ratio=b/a; lo=(100-t)/100; hi=(100+t)/100; print (ratio>=lo && ratio<=hi) ? "AGREE" : "DISAGREE" }')
      ratio=$(awk -v a="$r1" -v b="$r2" 'BEGIN{printf "%.4f", b/a}')
      [ "$verdict" = DISAGREE ] && k_disagree=1
      tlbl="${etol}%"; [ "$etolsrc" = UNBAKED ] && tlbl="${etol}%UNBAKED"
      row_bits="$row_bits $eng=$verdict(${ratio}x,tol=${tlbl})"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$eng" "$r1" "$r2" "$ratio" "$verdict" "$ib" "$ob" >> "$OUT_TSV"
    else
      row_bits="$row_bits $eng=UNPROVEN"
      printf '%s\t%s\t%s\t%s\t\tUNPROVEN\t%s\t%s\n' "$k" "$eng" "${r1:-NA}" "${r2:-NA}" "$ib" "$ob" >> "$OUT_TSV"
    fi
  done
  if [ "$k_measured" -eq 0 ]; then kverdict="UNPROVEN"; elif [ "$k_disagree" -eq 1 ]; then kverdict="DISAGREE"; any_disagree=1; else kverdict="AGREE"; fi
  printf '%-20s %-9s%s%s\n' "$k" "$kverdict" "$row_bits" "$diskflag"
done

echo
# ⛔ lib_perf_fmt.sh's perf_mult(reference,ours) is authored for COST metrics (lower=better: time,
# instructions) -- reference/ours > 1 means we're faster. sbl/s, m3/s, m4/s are RATE metrics (higher
# is better), the reciprocal polarity, so the two call args are swapped here (ours first, reference
# second) to keep ">= 1.00x GREEN means we're faster" true for a rate too. Same m3-vs-sbl, m4-vs-m3
# comparisons the two angle scripts already print as sp3/sp4 (hand-rolled there); this is angle 1's
# numbers through the ONE authority instead.
grid_incomplete=0
perf_grid_begin "FACT-RULE grid: m3 vs sbl, m4 vs m3 (angle 1 numbers; RATE metric so the operands are swapped -- see the note above; axis named once per row group here)"
for k in $kernels; do
  r1sbl=$(dehuman "${A1["$k:sbl"]:-}"); r1m3=$(dehuman "${A1["$k:m3"]:-}"); r1m4=$(dehuman "${A1["$k:m4"]:-}")
  perf_row_or_refuse "$k  m3 vs sbl" "$r1m3" "$r1sbl"
  perf_row_or_refuse "$k  m4 vs m3"  "$r1m4" "$r1m3"
done
perf_grid_end || grid_incomplete=1

echo
echo "TSV: $OUT_TSV"
if [ "${CHECK_SHAPE:-0}" != 1 ]; then . "$HERE/lib_progress.sh"; progress_append_triangulation snobol4 "$OUT_TSV" || { echo "⛔ bench_triangulate_snobol4: the progress database did not take this run's kernels (see above) -- a benchmark run that leaves the table untouched is a defect of the run (progress/README.md, CEO-331)"; exit 2; }; fi
if [ "$any_disagree" -eq 1 ]; then
  echo "⛔ DISAGREE or CHECK-FAIL present -- VOID: do not publish or cite those kernels' numbers until re-measured (or their correctness fixed)."
  exit 1
fi
if [ "$grid_incomplete" -eq 1 ]; then
  echo "⛔ the FACT-RULE grid above is INCOMPLETE -- a cell REFUSED (its subject is named on stderr). VOID as a reading: a dark cell is worse than a red one (CEO-676), so do not publish or cite this grid until every cell measures."
  exit 1
fi
echo "all measured kernels AGREE (each within its OWN baked noise tolerance -- see the per-row tol= values above, not a flat ${TOL}%)."
exit 0
