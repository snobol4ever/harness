#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_sno_rtx.sh — RTX GATE A/B MEASUREMENT RAIL (RTX-0b, s188).
#
# WHY THIS EXISTS (the s188 finding): bench_sno_rail.sh measures the five *-match DEMOS, and those
# demos DO NOT EXERCISE ANY PORTED RTX FAMILY.  Measured at N=64 on claws5-match: rt_gcheap_alloc 2,
# str_concat_d 2, rt_subscript_var/rt_deref/rt_num_arith 0, rt_call_arr 8 AND FLAT from N=1 to N=64.
# RTX-1..RTX-7 could be perfect or deleted outright and that board would not move.  Running the rail
# for an RTX rung reports a FALSE NULL and invites the misreading "the asm did nothing" when the truth
# is "these programs never call the asm."  This harness measures programs that DO call it.
#
# WHAT IT MEASURES: the A/B that the RTX ladder actually needs is GATE ON vs GATE OFF on ONE binary
# (SCRIP_RTX_<FAM>=1 vs 0) — not scrip-vs-sbl.  Same source, same build, same machine, same moment;
# the only variable is which body runs.  That isolates the port and nothing else.
#
# DISCIPLINE INHERITED FROM bench_sno_rail.sh (2026-07-24 all-day variance postmortem):
#   - self-timing only.  15 of 16 corpus/benchmarks/snobol4 programs already print "ms: <n>" from a
#     TIME() delta, so process startup/link/compile are excluded EXACTLY.  No startup-floor estimate.
#   - ADEQUATE WINDOW OR NO RATIO.  Sub-800ms windows swung 1.4x-3.9x run to run.  Here that lesson is
#     a HARD GATE, not a footnote: a program whose median window is < MIN_MS is reported BOGUS-WINDOW
#     and its ratio is SUPPRESSED.  It is not quietly printed in small type.
#   - N auto-ranging x4 until the window is adequate, by scaling the program's dominant LT(VAR,INT)
#     loop bound (covers 8 of the 9 sub-threshold programs; guard below).
#   - R interleaved rounds (default 5), medians, per-round ON/OFF alternation to cancel drift.
#
# IT ALSO GATES CORRECTNESS FOR FREE: ON and OFF output (minus the ms: line) must be byte-identical.
# A ratio from a run whose two arms disagree is meaningless, so a mismatch is fatal, not a warning.
#
# ⛔ RT_OPT: per RULES.md O2-DIRECTED-ONLY, the runtime is built -O0 unless Lon directed otherwise.
# Every number this prints is labelled with RT_OPT so it is never silently compared against an
# optimized oracle.  This harness NEVER passes -O1/-O2 itself.
#
# usage: bench_sno_rtx.sh <FAMILY> [program ...]
#   FAMILY = MISC | ALLOC | STR | CALL | AGG | ARITH | NV | MATCH | PAT   (sets SCRIP_RTX_<FAMILY>)
#   with no programs, runs that family's MEASURED-hot set (see FAMSET below).
# env: R=5 MIN_MS=800 NMAX_SCALE=64 SCRIP=../scrip RT_OPT=-O0
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
BENCH="${BENCH:-$S4E/corpus/benchmarks/snobol4}"
R="${R:-5}"; MIN_MS="${MIN_MS:-800}"; NMAX_SCALE="${NMAX_SCALE:-64}"; RT_OPT="${RT_OPT:--O0}"
FAM="${1:?usage: bench_sno_rtx.sh <FAMILY> [program ...]}"; shift || true
GATE="SCRIP_RTX_${FAM}"

# ---- FAMILY -> MEASURED-hot programs (s188 dynamic counts, mode 3, LD_PRELOAD interposer) ----
# ⛔ These sets are DYNAMIC measurements, NOT static call-site counts.  The static table ranks the
# CALL BOUNDARY and got CALL wrong by a factor of ~10^6 (see FINDING-2026-07-27d).  Re-measure, do
# not inherit: a program that stops exercising a family silently becomes a false null.
case "$FAM" in
  CALL)  FAMSET="string_manip eval_fixed roman" ;;          # rt_call_arr 10.0M / 1.0M / 400K
  AGG)   FAMSET="table_access mixed_workload" ;;            # rt_subscript_var 5.0M/1.0M, rt_deref 2.5M/500K
  ARITH) FAMSET="var_access func_call" ;;                                # ⛔ CHANGED s170 (BM-2, corpus): arith_mixed was RETIRED from benchmarks/snobol4 under Lon's "enough variations" deletion, and with it went the ONLY program in this corpus that reaches rt_num_arith (40,000,001 calls/run, RTX-0d s204). The set is NOT silently repointed to a substitute -- var_access/func_call remain valid for rt_cmp_d (10,000,001 each, s203) and NOTHING here measures rt_num_arith any more. ⚠ Do not read an ARITH ratio as evidence about rt_num_arith; re-minting a mixed int/real TIMED row (harness body) is the repair, and it is queued, not done. Text of the deleted program: corpus git history before a3604cc9.                   # arith_mixed: rt_num_arith 40,000,001/run (RTX-0d, s204 -- the ONLY program that reaches it). var_access/func_call: rt_cmp_d 10,000,001 each (s203). ⛔ CORRECTED s204: this set READ "mixed_workload arith_loop" until now — s203 MEASURED both to be useless (mixed_workload segfaults on pristine main rc=139; arith_loop calls rt_num_arith ZERO times, integer arith being fully inlined by the emitter) and wrote that finding into this comment, but LEFT THE LIVE SET UNCHANGED. A warning in a comment does not disarm a default: anyone running `bench_sno_rtx.sh ARITH` with no program list still got the guaranteed false null. Annotating a broken instrument is not fixing it. ⚠ `rt_num_arith` REMAINS UNMEASURABLE by this set — it needs a mixed int/real program (RTX-0d); do not read an ARITH ratio here as evidence about rt_num_arith.
  STR)   FAMSET="func_call var_access string_pattern table_access string_manip" ;;  # str_concat_d 10.0M x3
  ALLOC) FAMSET="table_access string_manip string_pattern" ;;            # ⛔ CHANGED s170 (BM-2, corpus): table_churn was RETIRED with the other eight legacy variants. It was the DENSEST alloc row measured (rt_agg_alloc 8.0M + rt_gcheap_alloc 8.0M, s204); table_access still exercises both paths at lower density, so this family stays valid but LESS SENSITIVE than it was. string_manip is rt_agg_alloc-BLIND (measured 0) and rides rt_gcheap_alloc 5.0M only.  # s204: table_churn ADDED and put FIRST -- it is the densest ALLOC program measured (rt_agg_alloc 8.0M + rt_gcheap_alloc 8.0M, scaling linearly). NOTE string_manip is rt_agg_alloc-BLIND (measured 0) though it is valid for the family via rt_gcheap_alloc 5.0M -- do not read an ALLOC ratio there as evidence about rt_agg_alloc.
  *)     FAMSET="string_manip table_access func_call" ;;
esac
PROGS="${*:-$FAMSET}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built at $SCRIP"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# ---- scale a program's dominant loop bound by factor F ----
# GUARD: only literals >= 1000 are scaled, so recursion base cases like fibonacci's LT(N,2) are never
# touched (scaling a base case changes the ALGORITHM, not the window — it would silently measure a
# different program).  If no literal qualifies, the program is returned unscaled and will be judged
# on its natural window.
scale() { python3 - "$1" "$2" "$3" << 'PY'
import re, sys
src, out, f = sys.argv[1], sys.argv[2], int(sys.argv[3])
s = open(src).read()
cands = [(int(m.group(2)), m.span()) for m in re.finditer(r'(LT\([A-Za-z0-9_.]+,\s*)(\d+)(\))', s) if int(m.group(2)) >= 1000]
if cands and f > 1:
    val, _ = max(cands)
    s = re.sub(r'(LT\([A-Za-z0-9_.]+,\s*)(' + str(val) + r')(\))', lambda m: m.group(1) + str(val * f) + m.group(3), s, count=1)
open(out, 'w').write(s)
PY
}
run1() { local prog="$1" gv="$2"; env "$GATE=$gv" timeout -k 5 600 "$SCRIP" --run "$prog" 2>/dev/null; }
msof() { sed -n 's/^ms: *//p' | head -1; }
med()  { python3 -c "
import sys; v=sorted(int(x) for x in sys.argv[1:] if x.strip().isdigit())
print(v[len(v)//2] if v else 0)" "$@"; }

echo "=== RTX GATE A/B RAIL — family $FAM (gate $GATE) — RT_OPT=$RT_OPT, mode 3, R=$R, MIN_MS=${MIN_MS} ==="
printf "%-18s %7s %9s %9s %7s  %s\n" PROGRAM N on_ms off_ms ratio VERDICT
FAILED=0
FOUND=0
for n in $PROGS; do
  src="$BENCH/$n.sno"
  [ -f "$src" ] || { printf "%-18s %7s %9s %9s %7s  %s\n" "$n" - - - - "MISSING"; continue; }
  FOUND=$((FOUND + 1))
  # ---- auto-range N until the OFF-arm window is adequate ----
  F=1; sc="$W/$n.sno"; cp "$src" "$sc"; w=$(run1 "$sc" 0 | msof); w="${w:-0}"
  while [ "${w:-0}" -lt "$MIN_MS" ] && [ "$F" -lt "$NMAX_SCALE" ]; do
    F=$((F * 4)); scale "$src" "$sc" "$F"; w=$(run1 "$sc" 0 | msof); w="${w:-0}"
  done
  # ---- correctness gate: ON and OFF must agree byte-for-byte (ms: line stripped) ----
  a=$(run1 "$sc" 1 | grep -v '^ms:'); b=$(run1 "$sc" 0 | grep -v '^ms:')
  if [ "$a" != "$b" ]; then
    printf "%-18s %7s %9s %9s %7s  %s\n" "$n" "x$F" - - - "⛔ OUTPUT MISMATCH ON!=OFF"; FAILED=1; continue
  fi
  # ---- R interleaved rounds ----
  ON=""; OFF=""
  for r in $(seq "$R"); do
    ON="$ON $(run1 "$sc" 1 | msof)"
    OFF="$OFF $(run1 "$sc" 0 | msof)"
  done
  on=$(med $ON); off=$(med $OFF)
  if [ "$off" -lt "$MIN_MS" ]; then
    printf "%-18s %7s %9s %9s %7s  %s\n" "$n" "x$F" "$on" "$off" "-" "⚠ BOGUS-WINDOW <${MIN_MS}ms — RATIO SUPPRESSED"
    continue
  fi
  ratio=$(python3 -c "print('%.3f' % ($off/$on)) if $on else print('inf')")
  printf "%-18s %7s %9s %9s %7s  %s\n" "$n" "x$F" "$on" "$off" "$ratio" "ok (off/on; >1 = asm faster)"
done
if [ "$FOUND" -eq 0 ]; then
  echo "⛔ NO-PROGRAMS: 0 of $(echo $PROGS | wc -w) requested program(s) found under BENCH=$BENCH for family $FAM — untested, not clean"
  FAILED=1
fi
echo "--- every number above is ${GATE}=1 vs =0 on ONE binary, RT_OPT=$RT_OPT, medians of $R interleaved rounds ---"
exit $FAILED
