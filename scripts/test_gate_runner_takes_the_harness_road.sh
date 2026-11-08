#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_runner_takes_the_harness_road.sh KEY ENTRY -- DESIGN-PLAN batch-grader steps 7c1 onward (officer_06, 2026-11-08, THING 1 families C
# and D: the suite runners with their own per-program loop; skill suites-and-grading reference section 5). One runner row's probe: KEY is the
# row's key in SUITE_RUNNERS.tsv, ENTRY one program the runner grades under S4E_CHUNK=entry:ENTRY. Three arms, every red named:
#   census  python3 -I util_runner_road_census.py --key KEY exits 0 (the runner takes the batch road and reads its modes from S4E_MODES);
#   road    under S4E_BATCH=1 S4E_MODES=m3 the runner prints HARNESS_ROAD rows=N recorded=N with N at least 1 (lib_harness_road.sh's hr_run);
#   verdict the mode-3 progress rows (program, outcome) of that run equal those of the same run per process (S4E_BATCH unset), each arm
#           writing to its own scratch S4E_PROGRESS_DB (or the scratch table the single-entry guard names in the log, moved into the gate's scratch), so the live
#           results.tsv is never touched.
# rc 0 GREEN, 1 RED, 2 could not measure (no key, a port row, an arm that graded nothing in mode 3).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_runner_takes_the_harness_road
KEY="${1:-}"; ENTRY="${2:-}"
[ -n "$KEY" ] && [ -n "$ENTRY" ] || { echo "REFUSE(2) [$G]: usage: $G.sh KEY ENTRY"; exit 2; }
ROW="$(awk -F'\t' -v k="$KEY" '$1 !~ /^#/ && $1 == k { print; exit }' "$HERE/SUITE_RUNNERS.tsv")"
[ -n "$ROW" ] || { echo "REFUSE(2) [$G]: no row $KEY in SUITE_RUNNERS.tsv"; exit 2; }
KIND="$(printf '%s' "$ROW" | cut -f2)"; RUNNER="$(printf '%s' "$ROW" | cut -f4)"
[ "$KIND" = port ] && { echo "REFUSE(2) [$G]: $KEY is a port row; the harness road is SCRIP's mode 3"; exit 2; }
read -r -a RW <<< "$RUNNER"
[ -f "$HERE/${RW[0]}" ] || { echo "REFUSE(2) [$G]: no runner $HERE/${RW[0]}"; exit 2; }
T="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-gate}/rtr.XXXXXX" 2>/dev/null || mktemp -d)" || { echo "REFUSE(2) [$G]: no scratch dir"; exit 2; }
trap 'rm -rf "$T"' EXIT
reds=""; k=0
red() { reds="$reds $1;"; k=$((k+1)); echo "  RED $1"; }
python3 -I "$HERE/util_runner_road_census.py" --key "$KEY" > "$T/census.txt" 2>&1; crc=$?
sed 's/^/  /' "$T/census.txt"
[ "$crc" = 2 ] && { echo "REFUSE(2) [$G]: the census refused"; exit 2; }
[ "$crc" = 0 ] || red "census(want BATCH_ROAD on and MODES s4e)"
arm() {  # arm NAME BATCH: run the runner on ENTRY in mode 3, its progress rows to a scratch table (ours, or the one the single-entry guard names)
  if [ "$2" = 1 ]; then
    S4E_PROGRESS_DB="$T/$1.tsv" S4E_BATCH=1 S4E_MODES=m3 S4E_CHUNK="entry:$ENTRY" timeout -k 5 1800 bash "$HERE/${RW[0]}" "${RW[@]:1}" < /dev/null > "$T/$1.log" 2>&1
  else
    env -u S4E_BATCH S4E_PROGRESS_DB="$T/$1.tsv" S4E_MODES=m3 S4E_CHUNK="entry:$ENTRY" timeout -k 5 1800 bash "$HERE/${RW[0]}" "${RW[@]:1}" < /dev/null > "$T/$1.log" 2>&1
  fi
  echo "  ARM $1 rc=$?"
  local sp; sp="$(sed -nE 's/.*SINGLE ENTRY.*scratch table ([^ )]+)\).*/\1/p' "$T/$1.log" | tail -1)"
  case "$sp" in */s4e-single-entry.*) [ -f "$sp" ] && mv "$sp" "$T/$1.single.tsv";; esac
  cat "$T/$1.tsv" "$T/$1.single.tsv" 2>/dev/null | awk -F'\t' '$1 != "ts_utc" && $9 == "m3" { print $8 "\t" $10 }' | LC_ALL=C sort > "$T/$1.m3"
}
arm batch 1
arm proc 0
nb=$(grep -c . "$T/batch.m3"); np=$(grep -c . "$T/proc.m3")
[ "$np" -gt 0 ] || { echo "REFUSE(2) [$G]: the per-process arm wrote no mode-3 progress row for $ENTRY; its log:"; tail -20 "$T/proc.log" | sed 's/^/  /'; exit 2; }
[ "$nb" -gt 0 ] || { echo "REFUSE(2) [$G]: the batch arm wrote no mode-3 progress row for $ENTRY; its log:"; tail -20 "$T/batch.log" | sed 's/^/  /'; exit 2; }
hl="$(grep -E '^HARNESS_ROAD rows=' "$T/batch.log" | tail -1)"
echo "  ${hl:-no HARNESS_ROAD line in the batch arm}"
n="$(printf '%s' "$hl" | sed -nE 's/^HARNESS_ROAD rows=([0-9]+) recorded=([0-9]+).*/\1 \2/p')"
if [ -z "$n" ] || [ "${n% *}" = 0 ] || [ "${n% *}" != "${n#* }" ]; then red "road(want HARNESS_ROAD rows=N recorded=N, N at least 1, under S4E_BATCH=1)"; fi
if ! cmp -s "$T/batch.m3" "$T/proc.m3"; then
  red "verdict(the mode-3 rows differ, batch < > per process)"
  diff "$T/batch.m3" "$T/proc.m3" | head -20 | sed 's/^/    /'
fi
echo "RUNNER_HARNESS_ROAD_BOARD key=$KEY entry=$ENTRY m3_rows=$np reds=$k (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$k" = 0 ] && { echo "GATE OK [$G]: $KEY takes the harness road in mode 3 and its $np mode-3 row(s) for $ENTRY equal the per-process run"; exit 0; }
echo "GATE FAIL [$G]: $k red(s):$reds"; exit 1
