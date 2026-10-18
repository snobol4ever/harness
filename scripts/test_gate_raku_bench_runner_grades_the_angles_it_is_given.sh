#!/usr/bin/env bash
# test_gate_raku_bench_runner_grades_the_angles_it_is_given.sh -- test_raku_bench_suite.sh GRADES EXACTLY THE ANGLES BENCH_ANGLES NAMES
# (Lon 2026-10-08, in-chat to the ceo, verbatim: "Why does RakBench take so long to run? Are the benchmarks parameters tunable so that could
# be reduced?"; ceo CEO-1564; the coo 2026-10-10). The coo's standing loop grades RakBench with BENCH_ANGLES=process -- the pristine kernel
# once per mode against its .ref -- and the three angles run on the publish cadence. This gate plants a fixture OUTSIDE the corpus tree
# (not a board, CEO-547: graded, nothing appended, nothing written) of two kernels and requires:
#   arm 1  BENCH_ANGLES=process: good reads PASS - - PASS and badref FAIL - - FAIL in both modes; the board line says angles=process and
#          all_pass=1 all_n=2; no wrapper is generated (the iter and time columns are "-")
#   arm 2  BENCH_ANGLES=time,process: the line names the angles in the runner's order, angles=process,time
#   arm 3  a name that is no angle, and an empty list, refuse rc 2 before anything is graded
#   arm 4  unset: the three angles, as before -- good PASS PASS PASS PASS, angles=process,iter,time
# Needs the build (it runs scrip in both modes); under a minute.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=raku_bench_runner_grades_the_angles_it_is_given
GATE_STRICT=1
gate_parse_args "$@"
R="$HERE/test_raku_bench_suite.sh"; B="$(cd "$ROOT/.." && pwd)/corpus/benchmarks/raku"
gate_require "$R" "the runner test_raku_bench_suite.sh" || exit 2
gate_require "$B/mb-hello.raku" "the corpus kernel mb-hello.raku" || exit 2
gate_require "$B/mb-hello.ref" "the corpus ref mb-hello.ref" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
F=$(mktemp -d "$SCRATCH/gate_raku_bench_angles_XXXXXX") || exit 2
trap '[ -n "${F:-}" ] && rm -rf "$F"' EXIT INT TERM
cp "$B/mb-hello.raku" "$F/good.raku" && cp "$B/mb-hello.ref" "$F/good.ref"
cp "$B/mb-hello.raku" "$F/badref.raku" && echo "not what it prints" > "$F/badref.ref"
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=process BENCH_BUD_MS=50 bash "$R" 2>&1); rc=$?
[ "$rc" = 2 ] && { echo "GATE UNPROVEN(2) [$GATE_NAME]: the runner refused -- $(printf '%s\n' "$out" | grep -m1 -E 'REFUS|UNPROVEN')"; gate_stamp; exit 2; }
has() { grep -qE "$1" <<<"$out"; }
ck "arm 1: the runner exits 1 over a population with a red (rc=$rc)" '[ "$rc" = 1 ]'
ck "arm 1: good reads PASS - - PASS in m3 and m4" 'has "^good +m3 +PASS +- +- +PASS" && has "^good +m4 +PASS +- +- +PASS"'
ck "arm 1: badref reads FAIL - - FAIL in m3 and m4" 'has "^badref +m3 +FAIL +- +- +FAIL" && has "^badref +m4 +FAIL +- +- +FAIL"'
ck "arm 1: the board line says angles=process all_pass=1 all_n=2" 'has "^SUITE_BOARD family=raku-bench-ref total=2 shipped=2 all_pass=1 all_n=2 .* angles=process "'
ck "arm 1: no wrapper ran -- no BENCH mode= scouting line" '! has "scouting .*BENCH mode="'
ck "arm 1: a population outside the corpus tree writes nothing and says so" 'has "OUTSIDE the corpus tree -- not a board"'
out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=time,process BENCH_BUD_MS=50 bash "$R" 2>&1); rc=$?
ck "arm 2: time,process grades both and the line reads angles=process,time (rc=$rc)" 'has " angles=process,time " && has "^good +m3 +PASS +- +PASS +PASS"'
out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=process,bogus bash "$R" 2>&1); rc=$?
ck "arm 3: an angle that is no angle refuses rc 2 naming it (rc=$rc)" '[ "$rc" = 2 ] && has "BENCH_ANGLES names .bogus."'
out=$(BENCH_RAKU_DIR="$F" BENCH_ANGLES=, bash "$R" 2>&1); rc=$?
ck "arm 3: an empty angle list refuses rc 2 (rc=$rc)" '[ "$rc" = 2 ]'
out=$(BENCH_RAKU_DIR="$F" BENCH_BUD_MS=50 bash "$R" 2>&1); rc=$?
ck "arm 4: unset, the three angles as before -- good PASS PASS PASS PASS, angles=process,iter,time (rc=$rc)" 'has "^good +m3 +PASS +PASS +PASS +PASS" && has " angles=process,iter,time "'
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n checks over a 2-kernel fixture -- the runner grades exactly the angles BENCH_ANGLES names"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails of $n checks red"; gate_stamp; exit 1
