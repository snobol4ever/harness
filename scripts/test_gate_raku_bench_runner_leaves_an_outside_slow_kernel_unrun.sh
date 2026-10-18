#!/usr/bin/env bash
# test_gate_raku_bench_runner_leaves_an_outside_slow_kernel_unrun.sh -- a RakBench kernel named in the population's OUTSIDE.tsv under
# class OUTSIDE_SLOW is NOT generated, built or run by test_raku_bench_suite.sh, is named on its own board line, and leaves the
# denominator (total/all_n) while shipped counts it (shipped = total + excluded). LON'S WORD (2026-10-10, in-chat to the cto,
# verbatim): "Fix RakBench not to take 1 hour." then "Well then, just remove the four slow ones and keep the rest." THE MEASUREMENT
# (the cto, the process angle once per kernel per mode, load about 8): four raku-bench whole programs at 29-52 s a run were 341 of
# the 399 s the 84 kernels take, and under three angles the hour. The Prolog bench's OUTSIDE_CLPFD still GRADES its kernel; this
# class must not, which is what arm 2 proves: the same fixture with the record removed runs the slow kernel until this gate's own
# timeout kills the runner. Fixture: mb-hello as good, an endless loop as slow, OUTSIDE.tsv naming slow.
# ARMS: (1) with the record, BENCH_ANGLES=process: rc 0 inside 90 s, good PASS in both modes, slow reads OUT on its line and never a
# verdict, the board line reads total=1 shipped=2 excluded=1 all_pass=1 all_n=1, the not-run line names slow(OUTSIDE_SLOW), no BENCH
# scouting line; (2) FAIL-ONCE: without the record the runner is still running slow when a 20 s timeout fires (rc 124); (3) a row
# with another class, (4) a row naming no kernel, (5) a row with no evidence each refuse rc 2 naming the fault before grading.
# FAIL_ONCE=1 writes the record with the class misspelled, so arm 1 reds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=raku_bench_runner_leaves_an_outside_slow_kernel_unrun
GATE_STRICT=1
gate_parse_args "$@"
R="$HERE/test_raku_bench_suite.sh"; B="$(cd "$ROOT/.." && pwd)/corpus/benchmarks/raku"
gate_require "$R" "the runner test_raku_bench_suite.sh" || exit 2
gate_require "$B/mb-hello.raku" "the corpus kernel mb-hello.raku" || exit 2
gate_require "$B/mb-hello.ref" "the corpus ref mb-hello.ref" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
F=$(mktemp -d "$SCRATCH/gate_raku_bench_outside_XXXXXX") || exit 2
trap '[ -n "${F:-}" ] && rm -rf "$F"' EXIT INT TERM
cp "$B/mb-hello.raku" "$F/good.raku" && cp "$B/mb-hello.ref" "$F/good.ref"
printf 'my $i = 0;\nwhile $i < 1000000000000 { $i++; }\nsay $i;\n' > "$F/slow.raku"; printf '1000000000000\n' > "$F/slow.ref"
CLS=OUTSIDE_SLOW; [ "${FAIL_ONCE:-0}" = 1 ] && CLS=OUTSIDE_SLOWLY
record() { printf '# OUTSIDE.tsv fixture\nslow\t%s\t%s\n' "$1" "$2" > "$F/OUTSIDE.tsv"; }
record "$CLS" "an endless loop standing in for a 50 s kernel (the gate's fixture)"
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
has() { grep -qE "$1" <<<"$out"; }
t0=$(date +%s); out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=process BENCH_BUD_MS=50 timeout -k 5 90 bash "$R" 2>&1); rc=$?; t1=$(date +%s)
ck "arm 1: with the record the runner exits 0 in $((t1-t0)) s, never its 90 s timeout (rc=$rc)" '[ "$rc" = 0 ]'
ck "arm 1: good reads PASS - - PASS in m3 and m4" 'has "^good +m3 +PASS +- +- +PASS" && has "^good +m4 +PASS +- +- +PASS"'
ck "arm 1: slow reads OUT on its own line and carries no verdict" 'has "^slow +both +OUT OUTSIDE_SLOW" && ! has "^slow +m[34] "'
ck "arm 1: the board line reads total=1 shipped=2 excluded=1 all_pass=1 all_n=1" 'has "^SUITE_BOARD family=raku-bench-ref total=1 shipped=2 excluded=1 all_pass=1 all_n=1 "'
ck "arm 1: the not-run line names slow(OUTSIDE_SLOW)" 'has "not run, out of the denominator \(OUTSIDE.tsv.*: slow\(OUTSIDE_SLOW\)"'
ck "arm 1: nothing of slow was built or scouted" '! has "scouting slow" && ! has "^slow .*FAIL"'
rm -f "$F/OUTSIDE.tsv"
t0=$(date +%s); out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=process BENCH_BUD_MS=50 timeout -k 5 20 bash "$R" 2>&1); rc=$?; t1=$(date +%s)
ck "arm 2 FAIL-ONCE: without the record the runner is still running slow when the 20 s timeout fires (rc=$rc after $((t1-t0)) s)" '[ "$rc" = 124 ]'
record OUTSIDE_CLPFD "the Prolog class, which this runner does not take"
out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=process timeout -k 5 60 bash "$R" 2>&1); rc=$?
ck "arm 3: another class refuses rc 2 naming it (rc=$rc)" '[ "$rc" = 2 ] && has "OUTSIDE.tsv names slow with class .OUTSIDE_CLPFD."'
printf '# fixture\nnobody\tOUTSIDE_SLOW\tnamed but no kernel\n' > "$F/OUTSIDE.tsv"
out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=process timeout -k 5 60 bash "$R" 2>&1); rc=$?
ck "arm 4: a name that is no kernel refuses rc 2 (rc=$rc)" '[ "$rc" = 2 ] && has "OUTSIDE.tsv names nobody, which is no kernel"'
printf '# fixture\nslow\tOUTSIDE_SLOW\t \n' > "$F/OUTSIDE.tsv"
out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=process timeout -k 5 60 bash "$R" 2>&1); rc=$?
ck "arm 5: a row with no evidence refuses rc 2 (rc=$rc)" '[ "$rc" = 2 ] && has "OUTSIDE.tsv names slow with no evidence"'
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n checks over a 2-kernel fixture -- an OUTSIDE_SLOW kernel is named, not run, and out of the denominator"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails of $n checks red"; gate_stamp; exit 1
