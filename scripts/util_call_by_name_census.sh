#!/usr/bin/env bash
# util_call_by_name_census.sh -- CENSUS + RANK EVERY CALL-BY-STRING-NAME RUNTIME DISPATCH SITE.
# Row: perf-call-by-name-census-and-rank (hq_P, 2026-08-27). ONE DISEASE: a runtime mechanism
# reached through a generic string-keyed lookup (hash/strcmp/table scan) on every use, where a
# direct or cached reference would do -- measured three unrelated times in one day before this
# row existed (see .github/FINDING-2026-08-27-seat04-call-by-name-census-and-rank.md).
#
# WHAT THIS DOES, fresh every run (never reads a frozen snapshot):
#   1. Confirms every enumerated site's symbol still exists in the runtime source (a renamed or
#      deleted function makes the census REFUSE for that row rather than silently reporting stale
#      zeros -- FACT RULE: a watermark's command must still describe the tree it runs on).
#   2. Builds roman.sno's fixed-N=20000 timed twin (bench_wrap.sh --mode=iter, the project's
#      standard witness -- every cited FINDING in this cluster uses it) and profiles it with
#      profile_box_histogram.sh SIMS=0 (Ir-only; RULES.md: rank by Ir at fixed work, never
#      wall-clock/cycles -- this project measured cycle-derived numbers flip sign under FLEET
#      contention the same day).
#   3. Extracts each site's CURRENT attributable Ir from that one profile, ranks them, and prints
#      one table. A site the witness doesn't exercise is reported UNEXERCISED, never as zero cost.
#   4. Refuses (rc=2), never skips-as-success, when the compiler isn't built, the witness is
#      missing, or a cited symbol has vanished from the source it is supposed to describe.
#
# WHAT THIS DOES NOT DO: cure anything. This is a census-and-rank row, not an umbrella -- cures are
# child rows (RULES.md NO-PER-OP-FILTER's row-factory discipline). See the FINDING for the ranked
# recommendation list and which sites already have child rows landed/open/newly minted.
#
# Usage: bash ../harness/scripts/util_call_by_name_census.sh   (run from SCRIP/, matches every sibling script)
# Env:   SCRIP=./scrip  RT_DIR=./out  WITNESS=../corpus/benchmarks/snobol4/roman.sno  N=20000
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../../SCRIP" || { echo "REFUSE rc=2: cannot cd to SCRIP root" >&2; exit 2; }

BIN="${SCRIP:-$PWD/scrip}"
RT="${RT_DIR:-$PWD/out}"
WITNESS="${WITNESS:-../corpus/benchmarks/snobol4/roman.sno}"
N="${N:-20000}"
EXPECT_CHECK="${EXPECT_CHECK:-check: 1102}"

[ -x "$BIN" ]              || { echo "REFUSE rc=2: no compiler binary at $BIN -- build first (make)" >&2; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "REFUSE rc=2: no runtime .so at $RT/libscrip_rt.so -- build first (make)" >&2; exit 2; }
[ -f "$WITNESS" ]          || { echo "REFUSE rc=2: witness not found: $WITNESS (set WITNESS=)" >&2; exit 2; }
command -v valgrind >/dev/null || { echo "REFUSE rc=2: valgrind not on PATH -- profile_box_histogram.sh needs callgrind" >&2; exit 2; }

# ---------------------------------------------------------------------- SITE TABLE (the enumeration)
# cluster | rt-symbol (as profile_box_histogram.sh prints it, 'rt:<fn>') | source file | status note
# status: CLOSED(row) = a child row already landed a cure; OPEN(row) = known live work, not this row's
#         job to duplicate; NEW = flagged by this census, no row existed before it; SCOPE-NOTE = looked
#         at, deliberately not a dispatch site (recorded so the next census doesn't re-walk the same path).
SITES='
builtin-dispatch-chain|try_call_builtin_by_name_bl|by_name_dispatch.c|CLOSED(perf-dispatch-callsite-cache: 1.070x combined STEP2+STEP3)
builtin-dispatch-chain|rt_call_arr_impl|by_name_dispatch.c|CLOSED(perf-dispatch-gc-safepoint-necessity: safepoint ceremony inlined)
builtin-dispatch-chain|rt_call_arr_bl|by_name_dispatch.c|OPEN(setjmp-per-builtin-call: setjmp/longjmp scope cost, unclaimed)
var-by-name|NV_SET_fn|core/core.c|OPEN(perf-nv-set-fn-o0-overhead item3: fast-path-hit cost, PARKED, accounting gap now closed by seat07)
var-by-name|_var_hash|core/core.c|MITIGATED(SCRIP_NV_MEMO cache, default on, measured 1.51x native when populated)
var-by-name|_var_bucket_find|core/core.c|MITIGATED(same memo cache as _var_hash)
'
# NEW site this census adds (not yet a symbol-per-line grep target -- BID_SNOx24NAME is a case label,
# not a function -- tracked separately below rather than forced into the SITES loop's symbol-grep shape).
NEW_SITE_NOTE='name-indirection (\$-indirection) dispatch entry: SNO\$NAME, BID id 53 (builtin_ids.h), reached via
  try_call_builtin_by_name_bl exactly like any other by-name call. HAS a stable bid (structurally fast-path-
  eligible, g_bidjmp_on=1 already gives it a cheap post-resolution jump) but is NOT among perf-dispatch-
  callsite-cache STEP3'"'"'s 14-name C-only fast-path list (SIZE/TIME/TRIM/DATE/DUPL/LPAD/RPAD/REMDR/SUBSTR/
  REPLACE/REVERSE/INTEGER/IDENT/DIFFER -- all niladic; SNO\$NAME takes 1 argument, so whether STEP3'"'"'s exact
  mechanism transfers to a monadic builtin is UNVERIFIED, not assumed). Per FINDING-2026-08-27-seat05-nd2-
  subscript-narrowed-and-name-indirection-measured.md, this specific dispatch is the SINGLE LARGEST
  contributor in an isolated \$-indirection-vs-direct-access probe (~2.06M Ir, ~42% of that workload'"'"'s
  indirection overhead) -- larger than the entire NV_GET/SET+hash layer beneath it. NEW, flagged by this
  census; see the FINDING for the child-row recommendation.'

echo "=== call-by-name dispatch census -- $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '(date unavailable)') ==="
echo "witness: $WITNESS  N=$N  RT_OPT=-O0 (mandatory, s262 FACT RULE)  instrument: callgrind Ir (SIMS=0)"
echo

# ---------------------------------------------------------------------- STEP 1: symbol existence (static)
missing=0
while IFS='|' read -r cluster sym file note; do
  [ -n "${cluster:-}" ] || continue
  f="src/runtime/${file}"
  if ! grep -q "\b${sym}\b" "$f" 2>/dev/null; then
    echo "REFUSE-ROW rc=2 candidate: '$sym' not found in $f (renamed/removed since this census was written)" >&2
    missing=$((missing+1))
  fi
done <<< "$SITES"
if [ "$missing" -gt 0 ]; then
  echo "REFUSE rc=2: $missing cited site(s) no longer exist in source -- update the SITES table before trusting this census" >&2
  exit 2
fi
echo "STATIC: all $(grep -c '|' <<< "$SITES") cited runtime symbols confirmed present in src/runtime/. $NEW_SITE_NOTE"
echo

# ---------------------------------------------------------------------- STEP 2: build the fixed-N witness
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
if ! bash ../harness/scripts/bench_wrap.sh "$WITNESS" -o "$W/roman_timed.sno" --mode=iter --n="$N" 2>"$W/wrap.err"; then
  echo "REFUSE rc=2: bench_wrap.sh could not build the timed witness" >&2; cat "$W/wrap.err" >&2; exit 2
fi

# ---------------------------------------------------------------------- STEP 3: profile (Ir only, SIMS=0)
if ! SIMS=0 SCRIP="$BIN" RT_DIR="$RT" bash ../harness/scripts/profile_box_histogram.sh "$W/roman_timed.sno" /dev/null 400 > "$W/prof.out" 2>"$W/prof.err"; then
  echo "REFUSE rc=2: profile_box_histogram.sh failed" >&2; cat "$W/prof.err" >&2; exit 2
fi

if ! grep -q "$EXPECT_CHECK" "$W/prof.out"; then
  echo "REFUSE rc=2: witness output did not print '$EXPECT_CHECK' -- do not trust Ir numbers from an unverified run" >&2
  head -3 "$W/prof.out" >&2
  exit 2
fi
echo "CORRECTNESS: witness printed '$EXPECT_CHECK' as expected."
echo

# NOTE: profile_box_histogram.sh never prints one explicit "total kernel Ir" line (each row carries
# its OWN Ir% of the grand total instead) -- so this script reports an EXACT sum of the sites it
# measured (never a back-derived, percentage-rounded "total kernel" figure) plus each site's own
# Ir% straight from the tool, rather than fabricate a precision the tool doesn't hand us.
echo "=== RANKED (Ir, current HEAD, this run only -- re-run for a fresh number, never carry this one forward silently) ==="
while IFS='|' read -r cluster sym file note; do
  [ -n "${cluster:-}" ] || continue
  line=$(grep -E "rt:${sym}\$" "$W/prof.out" | head -1)
  if [ -z "$line" ]; then
    echo "UNEXERCISED	0	0	$sym	$note"
  else
    ir=$(awk '{print $3}' <<< "$line" | tr -d ',')
    irpct=$(awk '{print $4}' <<< "$line")
    echo "MEASURED	$ir	$irpct	$sym	$note"
  fi
done <<< "$SITES" > "$W/rows.tsv"
sort -t"$(printf '\t')" -k2,2rn "$W/rows.tsv" | while IFS="$(printf '\t')" read -r st ir irpct sym note; do
  if [ "$st" = MEASURED ]; then
    printf '  %-28s %14s Ir  %5s%%   %s\n' "$sym" "$ir" "$irpct" "$note"
  else
    printf '  %-28s %14s      --    %s\n' "$sym" "UNEXERCISED" "$note"
  fi
done

measured=$(grep -c '^MEASURED' "$W/rows.tsv")
sum_measured_ir=$(awk -F'\t' '$1=="MEASURED"{s+=$2} END{print s+0}' "$W/rows.tsv")
echo
echo "sum of MEASURED sites' Ir this run (exact partial total, NOT the kernel total -- profile_box_histogram.sh"
echo "attributes SELF cost per function (skips callgrind's calls= inclusive-at-callsite line, see its own"
echo "source), so self-costs of nested same-chain functions do NOT double-count and this sum is valid, the"
echo "same summing convention this cluster's own prior FINDINGs already use): $sum_measured_ir"
echo "sites measured (exercised by this witness): $measured / $(wc -l < "$W/rows.tsv")"
[ "$measured" -gt 0 ] || { echo "REFUSE rc=2: zero sites were exercised by the witness -- census produced nothing to rank" >&2; exit 2; }
echo
echo "Full narrative, additional \$-indirection-specific numbers (a second, dedicated witness -- roman.sno"
echo "alone does not isolate name-indirection cost), and the ranked child-row recommendation:"
echo ".github/FINDING-2026-08-27-seat04-call-by-name-census-and-rank.md"
exit 0
