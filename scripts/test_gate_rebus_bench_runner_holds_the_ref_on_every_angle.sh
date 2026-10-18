#!/usr/bin/env bash
# test_gate_rebus_bench_runner_holds_the_ref_on_every_angle.sh -- THE REBUS BENCHMARK RUNNER FAILS WHAT A SINGLE-RUN TEST WOULD PASS.
#
# test_rebus_bench_suite.sh grades each benchmark under three angles in both modes (the process wrapper on the pristine kernel, then
# the program bench_wrap_rebus.py generates: fixed iterations and fixed time), the REF checked on every run and, in the generated
# angles, every repetition's VALUE held to the first and to the REF (row rebus-benchmarks-double-as-tests-..., the coo, CEO-1227).
# Lon, verbatim: "The reason to force a benchmark to also be a test is to guarantee it is not vacuous." This gate plants a fixture
# OUTSIDE the corpus tree (not a board, CEO-547: graded, nothing appended, nothing written) and requires the verdicts to be exactly:
#   good   `string_concat` copied from the corpus with its REF          -> PASS in m3 and m4
#   drift  prints 1 (its REF) on the first run, then each repetition computes another value -> the process angle PASSES and the
#          iteration and time angles FAIL naming `mismatched` -- the case a one-run test grades green
#   badref a correct kernel beside a wrong REF                           -> FAIL on all three angles, naming the value it computed
# and the board line all_pass=1 all_n=3. Needs the build (it runs scrip in both modes); ~5 s at BENCH_BUD_MS=50.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=rebus_bench_runner_holds_the_ref_on_every_angle
GATE_STRICT=1
gate_parse_args "$@"
R="$HERE/test_rebus_bench_suite.sh"; K="$(cd "$ROOT/.." && pwd)/corpus/benchmarks/rebus/string_concat"
gate_require "$R" "the runner test_rebus_bench_suite.sh" || exit 2
gate_require "$K.reb" "the corpus kernel string_concat.reb" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
F=$(mktemp -d "$SCRATCH/gate_rebus_bench_XXXXXX") || exit 2
trap '[ -n "${F:-}" ] && rm -rf "$F"' EXIT INT TERM
cp "$K.reb" "$F/good.reb" && cp "$K.ref" "$F/good.ref"
printf 'function main()\n  n := n + 1\n  OUTPUT := n\nend\n' > "$F/drift.reb"; echo 1 > "$F/drift.ref"
cp "$K.reb" "$F/badref.reb"; echo 99 > "$F/badref.ref"
out=$(BENCH_REBUS_DIR="$F" BENCH_BUD_MS=50 bash "$R" 2>&1); rc=$?
fails=0
ck() { if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
has() { grep -qE "$1" <<<"$out"; }
[ "$rc" = 2 ] && { echo "GATE UNPROVEN(2) [$GATE_NAME]: the runner refused -- $(printf '%s\n' "$out" | grep -m1 -E 'REFUS|UNPROVEN')"; gate_stamp; exit 2; }
ck "the runner exits 1 over a population with reds (rc=$rc)" '[ "$rc" = 1 ]'
ck "good passes all three angles in m3" 'has "^good +m3 +PASS +PASS +PASS +PASS"'
ck "good passes all three angles in m4" 'has "^good +m4 +PASS +PASS +PASS +PASS"'
ck "drift PASSES the process angle in m3 -- its first line IS its REF, which is why a one-run test grades it green" 'has "^drift +m3 +PASS +FAIL +FAIL +FAIL"'
ck "drift FAILS iterations and time in both modes, naming mismatched" 'has "^drift +m3 .*mismatched=[1-9]" && has "^drift +m4 +PASS +FAIL +FAIL +FAIL .*mismatched=[1-9]"'
ck "badref fails all three angles in both modes, naming the value it computed" 'has "^badref +m3 +FAIL +FAIL +FAIL +FAIL .*value=4000, the ref reads 99" && has "^badref +m4 +FAIL +FAIL +FAIL +FAIL"'
ck "the board line reads all_pass=1 all_n=3 m3_pass=1 m4_pass=1" 'has "^SUITE_BOARD family=rebus-bench-ref total=3 shipped=3 all_pass=1 all_n=3 m3_pass=1 m4_pass=1 "'
ck "a population outside the corpus tree writes nothing and says so" 'has "OUTSIDE the corpus tree -- not a board"'
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: 8 checks -- the runner holds the REF on every angle and fails the drift a single run passes"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails of 8 checks red -- the runner's output:"; printf '%s\n' "$out" | grep -vE '^ +scouting' | sed 's/^/    /' | head -30; gate_stamp; exit 1
