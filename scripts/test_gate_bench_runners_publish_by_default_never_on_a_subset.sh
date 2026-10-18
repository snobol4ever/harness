#!/usr/bin/env bash
# test_gate_bench_runners_publish_by_default_never_on_a_subset.sh -- EVERY BENCH RUNNER PUBLISHES ITS ROW BY DEFAULT ON A WHOLE-POPULATION
# PASS, AND A FILTERED, SUBSET OR SCRATCH PASS NEVER WRITES (ceo CEO-1302 (a), 2026-09-27: "all seven bench runners publish their row by
# default on a whole-population pass by the admitted LANES runner ... A filtered or subset pass never writes. One convention; you land
# it."). Six runners wrote only under --write and Pascal's always wrote, so whether a pass published depended on the runner.
#
#   F   lib_bench_write.sh's bench_row_writes: the published directory graded whole -> 1; --no-write -> 0; kernels named -> 0; another
#       directory (a fixture) -> 0; a directory that does not resolve -> 0, never 1
#   S   all seven runners source lib_bench_write.sh and compute WRITE from bench_row_writes, every util_score_row.py write sits under
#       `if [ "$WRITE" = 1 ]`, and none sets WRITE from --write any more
#   R   the Rebus runner on a scratch population (BENCH_REBUS_DIR at a one-kernel copy) prints "row write: no" naming the scratch
#       directory and reaches no leaderboard write
# FAIL-ONCE, MEASURED 2026-09-27 (coo) against origin 32aab0723's seven runners in a scratch copy of ../harness/scripts/ (this landing's lib kept so
# the gate reaches its arms): S red on all seven. R is an invariant, not a fail-once arm: the runners' own older guard (IS_BOARD,
# CEO-547) already kept a population outside the corpus from writing, and this landing keeps it so.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
G=bench_runners_publish_by_default_never_on_a_subset
unproven() { echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
L="$HERE/lib_bench_write.sh"; [ -f "$L" ] || unproven "no lib_bench_write.sh -- the one write rule is missing"
. "$L"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_benchwrite.XXXXXX")" || unproven "mktemp failed"
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1 RED: $2"; }
mkdir -p "$W/pub" "$W/other"
a="$(bench_row_writes "$W/pub" "$W/pub" "" 0 | cut -d' ' -f1)"; b="$(bench_row_writes "$W/pub" "$W/pub" "" 1 | cut -d' ' -f1)"
c="$(bench_row_writes "$W/pub" "$W/pub" " tak nrev " 0 | cut -d' ' -f1)"; d="$(bench_row_writes "$W/pub" "$W/other" "" 0 | cut -d' ' -f1)"
e="$(bench_row_writes "$W/pub" "$W/no_such_dir" "" 0 | cut -d' ' -f1)"
[ "$a$b$c$d$e" = 10000 ] && ok F "whole published population 1; --no-write, a named subset, another directory and an unresolvable one 0" \
    || red F "got $a $b $c $d $e (want 1 0 0 0 0)"
miss=""
for f in icon pascal prolog raku rebus snobol4 snocone; do
    r="$HERE/test_${f}_bench_suite.sh"; x="$(grep -v '^\s*#' "$r")"
    grep -q '"\$HERE/lib_bench_write.sh"' <<<"$x" && grep -q 'read -r WRITE WRITE_WHY <<<"$(bench_row_writes ' <<<"$x" \
      && ! grep -qE -- '--write\) *WRITE=1|= *--write \] *&& *WRITE=1' <<<"$x" \
      && awk '/util_score_row.py" write/ && !inside {bad=1} /if \[ "\$WRITE" = 1 \]; then/ {inside=1} /^ *fi *$/ {inside=0} END {exit bad}' "$r" \
      || miss="$miss $f"
done
[ -z "$miss" ] && ok S "all seven runners decide the write through bench_row_writes and write only under it" || red S "not on the one rule:$miss"
K="$(cd "$ROOT/.." && pwd)/corpus/benchmarks/rebus/string_concat"
if [ -f "$K.reb" ] && [ -f "$K.ref" ]; then
    mkdir -p "$W/rb"; cp "$K".* "$W/rb/"
    o="$(cd "$ROOT" && env S4E_SCORE_NO_WRITE="gate $G" S4E_PROGRESS_DB="$W/p.tsv" BENCH_REBUS_DIR="$W/rb" BENCH_BUD_MS=50 timeout -k 5 600 bash "$HERE/test_rebus_bench_suite.sh" 2>&1)"
    # the runner's own older guard (IS_BOARD, CEO-547) stops a population outside the corpus before the rule is even asked; either
    # word is the right answer -- the pass names the scratch directory and writes nothing -- and neither may reach the writer
    if grep -qE "row write: no -- this pass graded $W/rb|population $W/rb is OUTSIDE the corpus tree .* no suite row written" <<<"$o" \
       && ! grep -q 'LEADERBOARD WRITE\|lane owner: \|SCORE.md NOT UPDATED' <<<"$o"; then
        ok R "the Rebus runner on a scratch one-kernel population names it, writes no row and never reaches the writer"
    else
        red R "the scratch pass's row-write line: [$(grep -m1 'row write' <<<"$o" | cut -c1-120)] (want no, naming $W/rb)"
    fi
else
    unproven "the rebus kernel string_concat (.reb, .ref) is missing -- R has no witness"
fi
echo "GATE $([ "$FAIL" = 0 ] && echo PASS || echo "FAIL($FAIL)") [$G]: $PASS of $((PASS + FAIL)) arms green (population: the one rule, seven runners, one scratch pass)"
[ "$FAIL" = 0 ]
