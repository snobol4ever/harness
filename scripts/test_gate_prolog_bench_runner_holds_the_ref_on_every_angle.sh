#!/usr/bin/env bash
# test_gate_prolog_bench_runner_holds_the_ref_on_every_angle.sh -- THE PROLOG BENCHMARK RUNNER FAILS WHAT A SINGLE-RUN TEST WOULD PASS.
#
# test_prolog_bench_suite.sh grades each kernel under three angles in both modes (the process wrapper on the pristine kernel, then the
# programs bench_prolog_wrap.sh generates: fixed iterations and fixed time), the REF checked on every run -- in the iteration angle as
# N copies of the REF (loop_check), in the time angle as the answer once with every repetition held == to it (row prolog-benchmarks-
# double-as-tests-..., hq_prolog, CEO-1221; the Rebus twin is test_gate_rebus_bench_runner_holds_the_ref_on_every_angle.sh). Lon,
# verbatim: "The reason to force a benchmark to also be a test is to guarantee it is not vacuous." This gate plants a fixture OUTSIDE
# the corpus tree (not a board, CEO-547: graded, nothing appended, nothing written) and requires the verdicts to be exactly:
#   good   nrev copied from the corpus with its REF                     -> PASS in m3 and m4
#   drift  a kernel whose value moves every call: its first answer IS its REF, so the process angle PASSES, and the iteration and
#          time angles FAIL (LOOP-OUTPUT-MISMATCH, bench__mismatch) -- the case a one-run test grades green
#   badref fib beside a wrong REF                                      -> FAIL on all three angles
#   outk   fib with its true REF, named in the fixture's OUTSIDE.tsv (OUTSIDE_CLPFD) -> graded, PASS in m3 and m4, and OUT of the
#          denominator (hq_prolog's queens_clpfd, corpus 0bc5934ce; the coo 2026-10-10): total=3 shipped=4 excluded=1, all_pass unmoved
# and the board line all_pass=1 all_n=3; and an OUTSIDE.tsv that names no kernel refuses rc 2 before grading. Needs the build (it runs scrip in both modes); a few seconds at BENCH_BUD_MS=50.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=prolog_bench_runner_holds_the_ref_on_every_angle
GATE_STRICT=1
gate_parse_args "$@"
R="$HERE/test_prolog_bench_suite.sh"; B="$(cd "$ROOT/.." && pwd)/corpus/benchmarks/prolog/bench"
gate_require "$R" "the runner test_prolog_bench_suite.sh" || exit 2
gate_require "$B/nrev.pl" "the corpus kernel nrev.pl" || exit 2
gate_require "$B/fib.pl" "the corpus kernel fib.pl" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
F=$(mktemp -d "$SCRATCH/gate_prolog_bench_XXXXXX") || exit 2
trap '[ -n "${F:-}" ] && rm -rf "$F"' EXIT INT TERM
sed 's/kernel=nrev/kernel=good/' "$B/nrev.pl" > "$F/good.pl" && cp "$B/nrev.ref" "$F/good.ref"
printf '%% *BENCH kernel=drift\n:- dynamic(c/1).\nc(0).\nbench_work(X) :- retract(c(N)), X is N + 1, assertz(c(X)).\n:- initialization(main).\nmain :- bench_work(Res), write(Res), nl.\n' > "$F/drift.pl"; echo 1 > "$F/drift.ref"
sed 's/kernel=fib/kernel=badref/' "$B/fib.pl" > "$F/badref.pl"; echo 999 > "$F/badref.ref"
sed 's/kernel=fib/kernel=outk/' "$B/fib.pl" > "$F/outk.pl"; cp "$B/fib.ref" "$F/outk.ref"
printf '# fixture\noutk\tOUTSIDE_CLPFD\ta fixture kernel named outside the denominator, graded and not counted (gate fixture)\n' > "$F/OUTSIDE.tsv"
out=$(BENCH_PROLOG_DIR="$F" BENCH_BUD_MS=50 bash "$R" 2>&1); rc=$?
fails=0
ck() { if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
has() { grep -qE "$1" <<<"$out"; }
[ "$rc" = 2 ] && { echo "GATE UNPROVEN(2) [$GATE_NAME]: the runner refused -- $(printf '%s\n' "$out" | grep -m1 -E 'REFUS|UNPROVEN')"; gate_stamp; exit 2; }
ck "the runner exits 1 over a population with reds (rc=$rc)" '[ "$rc" = 1 ]'
ck "good passes all three angles in m3" 'has "^good +m3 +PASS +PASS +PASS +PASS"'
ck "good passes all three angles in m4" 'has "^good +m4 +PASS +PASS +PASS +PASS"'
ck "drift PASSES the process angle in both modes -- its first answer IS its REF, which is why a one-run test grades it green" 'has "^drift +m3 +PASS +FAIL +FAIL +FAIL" && has "^drift +m4 +PASS +FAIL +FAIL +FAIL"'
ck "drift FAILS the iteration angle on its loop output and the time angle on its first moved value, in both modes" 'has "^drift +m3 .*LOOP-OUTPUT-MISMATCH.*bench__mismatch\(1,2\)" && has "^drift +m4 .*LOOP-OUTPUT-MISMATCH.*bench__mismatch\(1,2\)"'
ck "badref fails all three angles in both modes" 'has "^badref +m3 +FAIL +FAIL +FAIL +FAIL" && has "^badref +m4 +FAIL +FAIL +FAIL +FAIL"'
ck "outk, named in OUTSIDE.tsv, is still graded: it passes all three angles in both modes" 'has "^outk +m3 +PASS +PASS +PASS +PASS" && has "^outk +m4 +PASS +PASS +PASS +PASS"'
ck "the board line reads total=3 shipped=4 excluded=1 all_pass=1 all_n=3 m3_pass=1 m4_pass=1 -- outk's PASS is not counted" 'has "^SUITE_BOARD family=prolog-bench-ref total=3 shipped=4 excluded=1 all_pass=1 all_n=3 m3_pass=1 m4_pass=1 "'
ck "the excluded kernel is named with its class" 'has "out of the denominator \(OUTSIDE.tsv\): outk\(OUTSIDE_CLPFD\)"'
printf 'ghost\tOUTSIDE_CLPFD\ta name with no kernel beside it, which the runner must refuse (gate fixture)\n' >> "$F/OUTSIDE.tsv"
out2=$(BENCH_PROLOG_DIR="$F" BENCH_BUD_MS=50 bash "$R" 2>&1); rc2=$?
ck "an OUTSIDE.tsv naming no kernel refuses rc 2 before grading (rc=$rc2)" '[ "$rc2" = 2 ] && grep -q "names ghost, which is no kernel" <<<"$out2"'
ck "a population outside the corpus tree writes nothing and says so" 'has "OUTSIDE the corpus tree -- not a board"'
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: 11 checks -- the runner holds the REF on every angle and fails the drift a single run passes"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails of 11 checks red -- the runner's output:"; printf '%s\n' "$out" | grep -vE '^ +scouting' | sed 's/^/    /' | head -30; gate_stamp; exit 1
