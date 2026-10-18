#!/usr/bin/env bash
# test_gate_x32t_and_x64t_a_print_nothing_engine_passes_no_program.sh -- THE FALSE-GREEN WITNESS of X32T and X64T (ceo to the coo
# 2026-10-18, rank 1, "DARK is worse than RED", from hq_jvm's measurement while it ports the package runners): test_snobol4_spitbol_x32_suite.sh
# and test_snobol4_spitbol_x64_suite.sh run every program with stdin from /dev/null, many are SPITBOL's own build-time filters that read
# INPUT, so under sbl -bf they print nothing and exit 0, and the stream arm (gate_oracle_stdout_match: rc 0 plus a cmp of the two stdouts)
# passes ANY engine that prints nothing and exits 0. A grade that proves only that a program compiles and terminates is not a grade.
# THE WITNESS: a staged root in the real shape (a COPY of this folder at <root>/harness/scripts, a stub SCRIP at <root>/SCRIP/scrip that
# prints nothing and exits 0 under --run and emits one comment line under --compile so the build-behaviour probe can sign it) and a COPY
# of each package as a scratch suite, so each runner grades with its own body against the live oracle and, by its own rule, writes no
# progress row and no score row. GREEN iff the stub passes NO program of either package in mode 3 except one whose package's
# EMPTY_ANSWER.tsv declares that nothing is its answer (named; mode 4 cannot link a stub's output, so mode 3 reads the false green). The passers are named. THE CURE it waits for: each filter carries a .in sidecar cut
# from the program's purpose (the testpgms runner's stdin_of shape, CEO-1410), and the stream arm refuses a PASS over an empty oracle
# stdout unless the unit declares an empty answer. RED on harness e29b7ef and corpus a5735c4a9, measured by the coo 2026-10-18 11:00 CDT in
# 11 s: X32T 14 stub passers (arcget arcput c cc d def e en enum equ lower op rev tbl), X64T 7 (arcget arcput cfreq def lower map-x64 trim).
# GREEN on the cure (corpus 1934ffa50 and the runners' stdin_of and empty-answer rule beside this gate), 11 s, 4 checks: the stub passes
# only X32T's e and en, declared in EMPTY_ANSWER.tsv; its fail-once proof: with lower.in moved aside the ungraded-set check reds naming lower.spt.
# rc 0 green, 1 red, 2 could not measure.
set -u
unset S4E_DONE_WHEN_RUN S4E_ONE_RUNNER_OVERRIDE S4E_ONE_RUNNER_FIXTURE S4E_ENGINE S4E_BIN_AT_START S4E_PROGRESS_DB S4E_CHUNK S4E_RR_REQUEST S4E_CRITERION_CHANGED
H="$(cd "$(dirname "$0")" && pwd)"; G=x32t_and_x64t_a_print_nothing_engine_passes_no_program; C="$H/../../corpus/packages/snobol4"
for p in spitbol_x32_tests spitbol_x64_tests; do
    [ -d "$C/$p" ] || { echo "REFUSE(2) [$G]: the package $C/$p is missing -- cannot measure"; exit 2; }
done
for r in test_snobol4_spitbol_x32_suite.sh test_snobol4_spitbol_x64_suite.sh; do
    [ -r "$H/$r" ] || { echo "REFUSE(2) [$G]: the runner $r is missing beside this gate -- cannot measure"; exit 2; }
done
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/root"; mkdir -p "$R/harness/scripts" "$R/SCRIP/out" "$R/corpus"
cp -r "$H/." "$R/harness/scripts/"
cat > "$R/SCRIP/scrip" <<'STUB'
#!/bin/sh
c=0; o=""
while [ $# -gt 0 ]; do case "$1" in --compile) c=1;; -o) shift; o="${1:-}";; esac; shift; done
[ "$c" = 1 ] || exit 0
if [ -n "$o" ]; then echo "# stub engine: prints nothing" > "$o"; else echo "# stub engine: prints nothing"; fi
exit 0
STUB
chmod +x "$R/SCRIP/scrip"; : > "$R/SCRIP/out/libscrip_rt.so"
fail=0; examined=0
grade() {  # grade <key> <package> <runner> <suite-var> <board-tag> <ext>
    local s="$T/$1" out="$T/$1.out" line pass all failed ung xg passers
    cp -R "$C/$2" "$s"
    env "$4=$s" bash "$R/harness/scripts/$3" > "$out" 2>&1 < /dev/null
    line="$(grep -m1 "^$5 " "$out")"
    [ -n "$line" ] || { echo "REFUSE(2) [$G]: $3 printed no $5 line under the stub -- cannot measure; its tail:"; tail -5 "$out" | sed 's/^/    /'; exit 2; }
    pass="$(printf '%s' "$line" | grep -oE 'm3_pass=[0-9]+' | cut -d= -f2)"
    all="$(cd "$s" && ls *."$6" 2>/dev/null | sed "s/\\.$6\$//" | sort)"
    failed="$(grep -m1 '^FAIL-M3:' "$out" | sed 's/^FAIL-M3://' | tr ' ' '\n' | sed 's/(.*//' | grep . | sort)"
    ung="$(grep -E '^UNGRADED	' "$out" | cut -f2 | sed "s/\\.$6\$//" | grep -v '^(none' | sort)"
    xg="$(grep -m1 '^EXCLUDED-GRADED' "$out" | sed 's/^[^:]*://' | tr ' ' '\n' | sed 's/(.*//' | grep . | sort)"
    passers="$(comm -23 <(printf '%s\n' "$all" | grep .) <(printf '%s\n' $failed $ung $xg | grep . | sort -u) | tr '\n' ' ')"
    examined=$((examined + $(printf '%s\n' "$all" | grep -c .)))
    declared="$( [ -f "$s/EMPTY_ANSWER.tsv" ] && awk -F'\t' 'NF>1 && $1 !~ /^#/ && $2 != "" {print $1}' "$s/EMPTY_ANSWER.tsv" | sed "s/\\.$6\$//" | sort)"
    offending="$(comm -23 <(printf '%s\n' $passers | grep . | sort) <(printf '%s\n' "$declared" | grep .) | tr '\n' ' ')"
    excused="$(comm -12 <(printf '%s\n' $passers | grep . | sort) <(printf '%s\n' "$declared" | grep .) | tr '\n' ' ')"
    [ -n "${pass:-}" ] || { echo "REFUSE(2) [$G]: $3's board line carries no m3_pass -- cannot measure"; exit 2; }
    if [ -z "$offending" ]; then echo "  ok   $1: the print-nothing stub passes no undeclared program in mode 3 (m3_pass=$pass, declared empty answers: ${excused:-none})"
    else echo "  FAIL $1: the print-nothing stub passes $(printf '%s\n' $offending | grep -c .) undeclared program(s) in mode 3: $offending(declared empty answers: ${excused:-none})"; fail=$((fail+1)); fi
    if grep -q '^UNGRADED.tsv agrees with the measured ungraded set' "$out"; then echo "  ok   $1: every program the oracle leaves unanswered is declared in UNGRADED.tsv, so every filter's .in made the oracle answer"
    else echo "  FAIL $1: the measured ungraded set is not UNGRADED.tsv's: $(grep -E '^⚠ UNGRADED.tsv' "$out" | sed -E 's/^⚠ (UNGRADED.tsv [A-Z]+) .*: /\1: /' | tr '\n' ' ')"; fail=$((fail+1)); fi
}
grade x32tests spitbol_x32_tests test_snobol4_spitbol_x32_suite.sh SPITBOL_X32_SUITE SPITBOL_X32_BOARD spt
grade x64tests spitbol_x64_tests test_snobol4_spitbol_x64_suite.sh SPITBOL_X64_SUITE SPITBOL_X64_BOARD sbl
if [ "$fail" = 0 ]; then echo "GATE PASS [$G]: a print-nothing engine passes no undeclared program of X32T or X64T and every ungraded one is declared (4 checks, $examined programs examined)"; exit 0; fi
echo "GATE FAIL [$G]: $fail check(s) of 4 red: a print-nothing engine passes an undeclared program, or a filter is ungraded undeclared ($examined programs examined) -- their PASS proves only compile-and-terminate"; exit 1
