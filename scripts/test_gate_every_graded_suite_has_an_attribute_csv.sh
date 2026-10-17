#!/usr/bin/env bash
# test_gate_every_graded_suite_has_an_attribute_csv.sh -- every row of SUITES.tsv (the machine-read SUITE TABLE) names a suite
# whose attribute file ALL.csv exists, so a program's declared memory (heap_kb, Lon 2026-09-23 CEO-1167/1168) has a place to
# live for EVERY graded suite. Cheap, no build, hermetic (reads the checkout only). PASS rc=0, FAIL rc=1 naming each missing
# file, REFUSE rc=2 when SUITES.tsv cannot be read or maps a key this table does not know (a suite this gate cannot place is
# not silently green). The key->directory table is DECLARED here because SUITES.tsv carries no path column.
# ⛔ A BENCHMARK ROW (key *-bench-ref, CEO-1221) HAS NO ALL.csv BY RULING: the coo 2026-09-23, answering hq_snocone -- a benchmark
# declares its memory in a per-program NAME.heap sidecar beside the program (the harness's own heap_sidecar_path format), never a
# per-tree attribute file. So a *-bench-ref key is PLACED when its benchmark directory exists, counted apart from the ALL.csv
# suites. Its first row (snocone-bench-ref) refused this gate for every seat's preflight for one push -- hq_pascal's report.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh"; T="$(suites_tsv "$S4E")"
[ -r "$T" ] || { echo "REFUSE(2): cannot read $T"; exit 2; }
declare -A DIR=(
  [gimpel]=corpus/packages/snobol4/gimpel [csnobol4]=corpus/packages/snobol4/csnobol4_suite [snoflake]=corpus/packages/snobol4/snoflake_suite
  [aisnobol]=corpus/packages/snobol4/aisnobol [dotnet]=corpus/packages/snobol4/dotnet [testpgms]=corpus/packages/snobol4/spitbol_testpgms
  [x64tests]=corpus/packages/snobol4/spitbol_x64_tests [x32tests]=corpus/packages/snobol4/spitbol_x32_tests [arizona]=corpus/packages/icon/arizona_tests [jcon]=corpus/packages/icon/jcon_tests
  [ipl]=corpus/packages/icon/ipl [inria]=corpus/packages/prolog/inriasuite [swi]=corpus/packages/prolog/swi_tests [gnu]=corpus/packages/prolog/gnu_prolog
  [gnu_fd]=corpus/packages/prolog/gnu_fd [logtalk]=corpus/packages/prolog/logtalk_iso [fpc]=corpus/packages/pascal/fpc_tests [pat]=corpus/packages/pascal/pat [rosetta-pascal]=corpus/packages/pascal/rosetta-pascal [rosetta-prolog]=corpus/packages/prolog/rosetta-prolog
  [roast]=corpus/packages/raku/roast [sno-rungs]=corpus/tests/snobol4 [icn-rungs]=corpus/tests/icon [pl-rungs]=corpus/tests/prolog
  [pas-rungs]=corpus/tests/pascal [raku-rungs]=corpus/tests/raku [snc-rungs]=corpus/tests/snocone [reb-rungs]=corpus/tests/rebus
  [snocone-bench-ref]=corpus/benchmarks/snocone [snobol4-bench-ref]=corpus/benchmarks/snobol4 [icon-bench-ref]=corpus/benchmarks/icon
  [prolog-bench-ref]=corpus/benchmarks/prolog [pascal-bench-ref]=corpus/benchmarks/pascal [raku-bench-ref]=corpus/benchmarks/raku
  [rebus-bench-ref]=corpus/benchmarks/rebus
  [snobol4-demos]=corpus/demos/snobol4 [snocone-demos]=corpus/demos/snocone [icon-demos]=corpus/demos/icon [prolog-demos]=corpus/demos/prolog
  [scriptix-demos]=corpus/demos/scriptix [puzzles]=corpus/packages/prolog/puzzles [trealla]=corpus/packages/prolog/trealla_tests [xsb]=corpus/packages/prolog/xsb_tests [pascal-demos]=corpus/demos/pascal [raku-demos]=corpus/demos/raku
)
rows=0; ok=0; okb=0; missing=(); unknown=()
while IFS=$'\t' read -r key rest; do
  [ -z "$key" ] && continue; case "$key" in \#*|key) continue;; esac
  rows=$((rows+1))
  d="${DIR[$key]:-}"
  if [ -z "$d" ]; then unknown+=("$key"); continue; fi
  # ⭐ A DEMO ROW (key *-demos, CEO-1312/1313; coo COO-206) is a benchmark row too: every demo declares its memory, command line and
  # workhorse run in sidecars beside it (NAME.heap/.stack/.cmdline/.workhorse), never a per-tree attribute file -- placed like *-bench-ref.
  case "$key" in *-bench-ref|*-demos) if [ -d "$S4E/$d" ]; then okb=$((okb+1)); else missing+=("$key -> $d (its benchmark or demo tree)"); fi; continue;; esac
  if [ -s "$S4E/$d/ALL.csv" ]; then ok=$((ok+1)); else missing+=("$key -> $d/ALL.csv"); fi
done < "$T"
echo "ATTRIBUTE-FILES suites=$rows with_all_csv=$ok benchmark_rows_by_sidecar=$okb missing=${#missing[@]} unknown=${#unknown[@]}"
for m in "${missing[@]}"; do echo "  MISSING $m"; done
for u in "${unknown[@]}"; do echo "  UNKNOWN-KEY $u (add it to this gate's table)"; done
[ "$rows" -gt 0 ] || { echo "REFUSE(2): SUITES.tsv has no rows -- a denominator of zero is a refusal"; exit 2; }
[ "${#unknown[@]}" -eq 0 ] || { echo "REFUSE(2): ${#unknown[@]} suite key(s) this gate cannot place"; exit 2; }
[ "${#missing[@]}" -eq 0 ] && { echo "GATE PASS(0) [every_graded_suite_has_an_attribute_csv]: $ok of $rows suites carry ALL.csv and $okb benchmark row(s) declare memory by NAME.heap sidecar"; exit 0; }
echo "GATE FAIL(1) [every_graded_suite_has_an_attribute_csv]: ${#missing[@]} of $rows suites have no attribute file"; exit 1
