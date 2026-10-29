#!/usr/bin/env bash
# test_gate_sno_host_1_runs_the_command_and_returns_its_wait_status.sh -- HOST(1, s1 [, s2]) (v3.7 Appendix E, "Execute a command
# string": "Executes the command string s1 and returns the integer result code returned by the sub-process. The string s2 is
# ignored") runs s1 through the shell, after flushing the program's pending output, with the program's stdin, and answers the
# INTEGER sbl answers -- the raw wait status (exit 3 -> 768, exit 300 -> 11264, killed by signal 9 -> 9, a missing command ->
# 32512), 0 for an empty or absent command -- in both modes.
#
# ⛔ THE DEFECT: HOST(1) answered the process id as a STRING and ran nothing -- a wrong value with no error, the CEO-556 silent
# class (cfo, reviewing the find). Found in passing while reading X32T's host.spt; no graded program calls it today
# (dotnet code.sno and csnobol4_suite host.sno do, both outside the graded set).
# NO MONITOR BRACKET: one builtin call, no divergence in control flow to bracket.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME, each program fed the one-line stdin 'IN'):
#   1-2  m3 / m4: the nine-case matrix -- stdout (ordering included), the value and its DATATYPE          -- RED on base
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no /bin/sh).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_host_1_runs_the_command_and_returns_its_wait_status
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -x /bin/sh ] || refuse "no /bin/sh -- HOST(1) has no shell to run"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
CASES=("HOST(1,'exit 3')" "HOST(1,'echo hi')" "HOST(1,'')" "HOST(1)" "HOST(1,'kill -9 \$\$')" "HOST(1,'nosuchcmd_xyz_host1 2>/dev/null')"
       "HOST(1,'echo a; exit 300')" "HOST(1,'cat')" "HOST(1, 'echo x', 'ignored')")
for i in "${!CASES[@]}"; do
    printf '%s\n' "        OUTPUT = 'before'" "        X = ${CASES[$i]}" "        OUTPUT = '[' X '] ' DATATYPE(X)" END > "$T/c$i.sno"
    ( cd "$T" && echo IN | timeout -k 5 20 "$SBL" -bf "c$i.sno" > "c$i.oracle" 2>&1 )
done
grep -qx '\[768\] INTEGER' "$T/c0.oracle" && grep -qx 'hi' "$T/c1.oracle" && grep -qx 'IN' "$T/c7.oracle" || refuse "the oracle's HOST(1) answers moved: [$(tr '\n' '|' < "$T/c0.oracle")] [$(tr '\n' '|' < "$T/c7.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
run() { ( cd "$T" && if [ "$2" = m3 ]; then echo IN | timeout -k 5 20 "$SCRIP" "$1.sno"; else timeout -k 5 30 "$SCRIP" --compile --out="$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && echo IN | timeout -k 5 20 "./$1.bin"; fi ) 2>&1; }
matrix() { local bad=""
    for i in "${!CASES[@]}"; do
        run "c$i" "$1" > "$T/c$i.$1"
        cmp -s "$T/c$i.$1" "$T/c$i.oracle" || bad="$bad ${CASES[$i]} got [$(tr '\n' '|' < "$T/c$i.$1")] want [$(tr '\n' '|' < "$T/c$i.oracle")];"
    done; [ -z "$bad" ] && echo ok || echo "$bad"; }
arm "m3: HOST(1) runs the command and answers its wait status (${#CASES[@]} cases)" "$(matrix m3)"
arm "m4: HOST(1) runs the command and answers its wait status (${#CASES[@]} cases)" "$(matrix m4)"
[ "$fail" = 0 ] && { echo "GATE PASS [$NAME]: $n/$n arms"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
