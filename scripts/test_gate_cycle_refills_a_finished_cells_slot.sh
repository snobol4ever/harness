#!/usr/bin/env bash
# test_gate_cycle_refills_a_finished_cells_slot.sh -- THE CYCLE KEEPS ITS WIDTH OF CELLS RUNNING (row cycle-keeps-its-width-of-cells-running-a-finished-cells-slot-is-refilled-at-once;
# the cio's design 2026-11-10 on the coo's finding: lap 11 stood 1 h 40 min on one xsb cell with three of four slots idle behind a batch barrier).
# A scratch home holds a planted runner table of five one-cell suites (s1 sleeps 20 s, s2..s5 sleep 1 s) and stand-ins for every outside call the cycle
# makes (sync, make, budget, run slot, the harness, the score row); the real harness/scripts/s4e_cycle.sh beside this gate runs over it at width 2 with
# S4E_CYCLE_PROG and S4E_CYCLE_TMP scratch. GREEN: the four short cells' CELL lines come before the long one's, and the fifth CELL line is written under
# 25 s after the lap starts (a barrier logs s1 first: the batch is logged in index order after its slowest cell). No live store is read or written:
# the progress dir, the request folder, the postoffice and the results table are all scratch.
# rc 0 GREEN, rc 1 RED, rc 2 could not measure.
set -u
G=test_gate_cycle_refills_a_finished_cells_slot
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYC="$HERE/s4e_cycle.sh"
[ -f "$CYC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $CYC"; exit 2; }
w="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-gate}-cyclepool.XXXXXX" 2>/dev/null || mktemp -d)" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
cpid=""
trap '[ -n "$cpid" ] && kill -- -"$cpid" 2>/dev/null; rm -rf "$w"' EXIT
H="$w/home"; mkdir -p "$H/harness/scripts" "$H/SCRIP" "$H/.github" "$w/prog" "$w/tmp"
printf 'all:\n\t@true\n' > "$H/SCRIP/Makefile"
: > "$H/harness/scripts/SUITE_RUNNERS.tsv"
for s in s1 s2 s3 s4 s5; do
    mkdir -p "$H/pkg/$s"; printf 'entry\tpart\n%s_e\tcore\n' "$s" > "$H/pkg/$s/PARTITION.tsv"; : > "$H/pkg/$s/ALL.sno"; : > "$H/pkg/$s/ALL.ref"
    printf '%s\tpkg\tsnobol4\tcorpus_suite_harness.py\tpkg/%s\n' "$s" "$s" >> "$H/harness/scripts/SUITE_RUNNERS.tsv"
done
printf '#!/usr/bin/env bash\nexit 0\n' > "$H/harness/scripts/util_sync_root.sh"
printf '#!/usr/bin/env bash\nexec "$@"\n' > "$H/harness/scripts/util_run_slot.sh"
printf 'import sys\nprint("BUDGET ttr_s=120")\n' > "$H/harness/scripts/util_grade_job.py"
printf 'import sys\n' > "$H/harness/scripts/util_score_row.py"
printf 'import sys, time\ntime.sleep(20 if "/pkg/s1/" in sys.argv[2] else 1)\nsys.exit(0)\n' > "$H/harness/scripts/corpus_suite_harness.py"
t0=$(date +%s)
mkdir -p "$w/rq" "$w/po"; : > "$w/results.tsv"   # every live store the cycle reads or writes is scratch: the request folder, the postoffice, the results table (2026-11-10: without them this gate's scratch cycle served the five live requests as refusals)
setsid env S4E_HOME="$H" S4E_CYCLE_PROG="$w/prog" S4E_CYCLE_TMP="$w/tmp" S4E_CYCLE_WIDTH=2 S4E_TEST_REQUEST_DIR="$w/rq" S4E_POST="$w/po" S4E_RESULTS="$w/results.tsv" bash "$CYC" > "$w/cycle.out" 2>&1 < /dev/null & cpid=$!
n=0; for i in $(seq 1 90); do n=$(grep -c ' CELL lap=1 ' "$w/prog/CYCLE.log" 2>/dev/null); [ "${n:-0}" -ge 5 ] && break; sleep 0.5; done
el=$(( $(date +%s) - t0 ))
kill -- -"$cpid" 2>/dev/null; wait "$cpid" 2>/dev/null; cpid=""
grep -q ' LAP 1 start ' "$w/prog/CYCLE.log" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the scratch cycle never started its lap: $(head -c 300 "$w/cycle.out" "$w/prog/CYCLE.log" 2>/dev/null | tr '\n' ' ')"; exit 2; }
[ "${n:-0}" -ge 5 ] || { echo "CYCLE_POOL_BOARD cells=${n:-0}/5 secs=$el"; echo "⛔ GATE FAIL(1) [$G]: only ${n:-0} of 5 CELL lines in 45 s"; exit 1; }
order="$(grep ' CELL lap=1 ' "$w/prog/CYCLE.log" | sed -n 's/.* CELL lap=1 [0-9]*\/[0-9]* \([^ ]*\) .*/\1/p' | tr '\n' ',')"
last="$(grep ' CELL lap=1 ' "$w/prog/CYCLE.log" | tail -1 | sed -n 's/.* CELL lap=1 [0-9]*\/[0-9]* \([^ ]*\) .*/\1/p')"
idx_ok=1; grep ' CELL lap=1 ' "$w/prog/CYCLE.log" | grep -q ' CELL lap=1 1/5 s1 ' || idx_ok=0
echo "CYCLE_POOL_BOARD width=2 cells=5 order=${order%,} last=$last secs=$el own_index=$idx_ok (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$last" = s1 ] && [ "$el" -lt 25 ] && [ "$idx_ok" = 1 ] && { echo "GATE OK [$G]: the long cell finished last while the four short ones refilled its neighbour's slot, ${el} s"; exit 0; }
echo "⛔ GATE FAIL(1) [$G]: last=$last (want s1), ${el} s (want under 25), own_index=$idx_ok: a finished cell's slot was not refilled at once"; exit 1
