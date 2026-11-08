#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_harness_road_lib_reads_the_per_process_verdict.sh -- DESIGN-PLAN batch-grader step 7c0 (officer_06, 2026-11-08, THING 1 families C and D:
# the suite runners with their own per-program loop). lib_harness_road.sh is the ONE library such a runner sources to take the harness road in mode 3:
# hr_begin DIR; hr_row [--merged] NAME SRC STDIN TIMEOUT_S CWD [SWITCH...] [-- ARGV...] once per program; hr_run SCRIP once; then hr_get NAME per
# program, rc 0 with HR_OUT HR_ERR HR_RC HR_KIND HR_SECS set when the record ran the row (RAN or CRASH), rc 1 when it did not (HANG, REFUSED, no row,
# or S4E_BATCH is not 1), so the runner keeps its per-process line as the fallback, where the timeout retry lives. This gate grades the library on four
# scratch SNOBOL4 programs against the per-process run of each: stdout and rc identical for hello, a stdin echo and an &CODE exit 3; a hang falls back;
# with S4E_BATCH unset nothing is listed and every hr_get falls back. rc 0 GREEN, 1 RED (named), 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
G=test_gate_harness_road_lib_reads_the_per_process_verdict
[ -x "$SCRIP" ] || { echo "REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-gate}/hrlib.XXXXXX" 2>/dev/null || mktemp -d)" || { echo "REFUSE(2) [$G]: no scratch dir"; exit 2; }
trap 'rm -rf "$T"' EXIT
cd "$T" || exit 2
printf "        OUTPUT = 'hello'\nEND\n" > hello.sno
printf "        OUTPUT = INPUT\nEND\n" > echo.sno
printf "abc\n" > echo.in
printf "        OUTPUT = 'three'\n        &CODE = 3\nEND\n" > code.sno
printf "LOOP    :(LOOP)\nEND\n" > hang.sno
for p in hello echo code; do
  i=/dev/null; [ -f "$p.in" ] && i="$p.in"
  timeout -k 5 30 "$SCRIP" --run "$p.sno" < "$i" > "$p.pp" 2>/dev/null; echo $? > "$p.pprc"
done
[ "$(cat hello.pp)" = hello ] && [ "$(cat code.pprc)" = 3 ] || { echo "REFUSE(2) [$G]: the per-process oracle runs did not read hello and rc 3 -- scrip itself is broken here"; exit 2; }
[ -f "$HERE/lib_harness_road.sh" ] || { echo "HARNESS_ROAD_LIB_BOARD reds=1 (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"; echo "GATE FAIL [$G]: harness/scripts/lib_harness_road.sh does not exist"; exit 1; }
. "$HERE/lib_harness_road.sh" || { echo "GATE FAIL [$G]: lib_harness_road.sh does not source"; exit 1; }
reds=""
red() { reds="$reds $1"; echo "  RED $1"; }
S4E_BATCH=1
export S4E_BATCH
hr_begin "$T/hr"
hr_row hello "$T/hello.sno" /dev/null 10 "$T"
hr_row echo "$T/echo.sno" "$T/echo.in" 10 "$T"
hr_row code "$T/code.sno" /dev/null 10 "$T"
hr_row hang "$T/hang.sno" /dev/null 2 "$T"
out="$(hr_run "$SCRIP")"
echo "$out"
printf '%s\n' "$out" | grep -qE '^HARNESS_ROAD rows=4 recorded=4 ' || red "hr_run-line(want HARNESS_ROAD rows=4 recorded=4)"
for p in hello echo code; do
  if hr_get "$p"; then
    [ "$(cat "$HR_OUT")" = "$(cat "$p.pp")" ] || red "$p-stdout"
    [ "$HR_RC" = "$(cat "$p.pprc")" ] || red "$p-rc(got=$HR_RC want=$(cat "$p.pprc"))"
    [ "$HR_KIND" = RAN ] || red "$p-kind(got=$HR_KIND)"
  else red "$p-hr_get-fell-back"; fi
done
if hr_get hang; then red "hang-was-graded(want the fallback)"; fi
unset S4E_BATCH
hr_begin "$T/off"
hr_row hello "$T/hello.sno" /dev/null 10 "$T"
hr_run "$SCRIP" > "$T/off.txt" 2>&1
[ -s "$T/off/harness.list" ] && red "off-listed-a-row(S4E_BATCH unset)"
if hr_get hello; then red "off-hr_get-graded(S4E_BATCH unset)"; fi
n=$(printf '%s\n' $reds | grep -c .)
echo "HARNESS_ROAD_LIB_BOARD reds=$n (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$n" = 0 ] && { echo "GATE OK [$G]: hr_* reads hello, the stdin echo and the &CODE 3 exactly as their per-process runs; the hang and S4E_BATCH unset fall back"; exit 0; }
echo "GATE FAIL [$G]: $n red(s):$reds"; exit 1
