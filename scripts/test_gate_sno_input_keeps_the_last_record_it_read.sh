#!/usr/bin/env bash
# test_gate_sno_input_keeps_the_last_record_it_read.sh -- the INPUT variable holds the last record it delivered, so &DUMP lists
# INPUT = '<last record>' as sbl -bf does (ceo CEO-1410, 2026-10-02).
#
# FOUND by running spitbol_testpgms/test6.spt to completion on Lon's word ("Fix test6 also."): its final &DUMP lists
# INPUT = 'SLITERAL<LITERAL,...' under sbl and SCRIP's dump left INPUT out. THE CAUSE: NV_GET_untapped answered a reference to
# INPUT by reading a record and never storing it, so INPUT's own value stayed null and var_dump skipped it. THE CURE: a
# successful read is remembered in the hidden _INPUT entry the dump already lists as INPUT (the _OUTPUT convention).
# THE ARMS, the expectation cut from sbl -bf at run time on the same witness and stdin:
#   1 the oracle dumps INPUT = 'second' (two records read, the third read fails)   2 m3 dumps the same line   3 m4 dumps it
#   4 DETECTOR -- a failed read leaves the last successful record, never null, in both modes
# EXIT: 0 every arm passes · 1 an arm failed · 2 REFUSED (no binary, no oracle, a toolchain failure, the oracle moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"; RT_DIR="$ROOT/out"; NAME=sno_input_keeps_the_last_record_it_read
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"; trap 'rm -rf "$T"' EXIT
printf 'first\nsecond\n' > "$T/in.txt"
printf '         X = INPUT\n         Y = INPUT\n         Z = INPUT        :F(D)\nD        &DUMP = 1\nEND\n' > "$T/w.sno"
graded=0; fail=0
arm() { graded=$((graded+1)); if [ "$2" = "$3" ]; then echo "  PASS $1  [$2]"; else echo "  FAIL $1  want[$2] got[$3]"; fail=$((fail+1)); fi; }
ORA="$(cd "$T" && timeout -k 5 20 "$SBL" -bf w.sno < in.txt 2>&1 | grep -m1 '^INPUT = ')"
[ "$ORA" = "INPUT = 'second'" ] || refuse "the oracle's dump line moved: [$ORA] -- re-measure rather than score"
graded=$((graded+1)); echo "  ARM 1 oracle: [$ORA]"
M3="$(cd "$T" && timeout -k 5 20 "$SCRIP" w.sno < in.txt 2>&1 | grep -m1 '^INPUT = ')"
( cd "$T" && timeout -k 5 30 "$SCRIP" --compile w.sno -o w.s > /dev/null 2>&1 && gcc -no-pie w.s -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o w.bin > /dev/null 2>&1 ) || refuse "mode-4 build failed -- a toolchain failure, not a verdict"
M4="$(cd "$T" && timeout -k 5 20 ./w.bin < in.txt 2>&1 | grep -m1 '^INPUT = ')"
arm "m3-dumps-the-last-record" "$ORA" "$M3"
arm "m4-dumps-the-last-record" "$ORA" "$M4"
arm "detector-a-failed-read-keeps-the-last-record" "m3=second m4=second" "m3=$(printf '%s' "$M3" | sed -n "s/^INPUT = '\(.*\)'$/\1/p") m4=$(printf '%s' "$M4" | sed -n "s/^INPUT = '\(.*\)'$/\1/p")"
echo "graded=$graded FAIL=$fail  (the expectation cut from $SBL -bf at run time)"
[ "$graded" = 4 ] || refuse "expected 4 arms, graded $graded"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"; exit 0
