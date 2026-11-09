#!/usr/bin/env bash
# s4e_probe_grade_worker_pkg_is_the_one_launch.sh -- THE PROBE of row fleet-grade-worker-launches-a-package-row-as-the-one-harness-launch-not-bash (CIO-18, the cio 2026-11-09).
# A package request (kind pkg in SUITE_RUNNERS.tsv) makes the SAME one harness launch as a master, over its container dir (column 5), never bash over the
# Python runner. One request-band job (suite rosetta-pascal, cell entry:zeckendorf-number-representation, modes m3) is served by one --once grade worker on a
# private beanstalkd under a scratch S4E_GRADE_SCRATCH. Checks: the GRADE_WORKERS line for the job reads rc=0 or rc=1 with action=delete (never rc=2); the job
# log holds no "syntax error"; the scratch results table gained a row for the entry during this run. One line:
# GRADE_WORKER_PKG_PROBE ok=1 rc 0, else the failing checks and rc 1. rc 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
SC="$S4E/harness/scripts"
[ -x "$SC/s4e_grade_worker.sh" ] && [ -f "$SC/util_grade_job.py" ] || { echo "REFUSE(2): no s4e_grade_worker.sh or util_grade_job.py under $SC"; exit 2; }
ENT="zeckendorf-number-representation"; PSEAT="probe-pkg-$$"; port=$((22000 + ($$ % 10000))); tube="grade-pkg-probe-$$"
T="$(mktemp -d "/tmp/s4e/$ME/grade_pkg.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
SCR="$T/scratch"; mkdir -p "$SCR"
beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bpid=$!
trap 'kill $bpid 2>/dev/null; wait $bpid 2>/dev/null; rm -rf "$T" "/tmp/s4e/$PSEAT"' EXIT
up=0
for i in $(seq 1 50); do S4E_QUEUE_PORT="$port" python3 "$SC/util_queue.py" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && { up=1; break; }; sleep 0.1; done
{ [ "$up" = 1 ] && kill -0 "$bpid" 2>/dev/null; } || { echo "REFUSE(2): a private beanstalkd would not start on port $port"; exit 2; }
tree="$(git -C "$S4E/SCRIP" rev-parse HEAD 2>/dev/null)"
jid="$(S4E_SEAT="$PSEAT" S4E_QUEUE_PORT="$port" python3 "$SC/util_grade_job.py" put --suite rosetta-pascal --cell "entry:$ENT" --band request --modes m3 --tree "$tree" --requester "$PSEAT" --tube "$tube" \
    | sed -n 's/^job=\([0-9][0-9]*\) .*/\1/p')"
[ -n "$jid" ] || { echo "REFUSE(2): util_grade_job.py put placed no job on $tube"; exit 2; }
t0="$(date -u +%Y-%m-%dT%H:%M:%S)"
S4E_HOME="$S4E" S4E_SEAT="$PSEAT" S4E_GRADE_SCRATCH="$SCR" S4E_QUEUE_PORT="$port" timeout 900 bash "$SC/s4e_grade_worker.sh" 1 --once --tube "$tube" > "$T/worker.out" 2>&1; wrc=$?
line="$(grep "job=$jid " "$SCR/GRADE_WORKERS.log" 2>/dev/null | tail -1)"
wr="$(printf '%s' "$line" | sed -n 's/.* rc=\([0-9]*\) action=\([a-z]*\) .*/\1/p')"
wa="$(printf '%s' "$line" | sed -n 's/.* rc=\([0-9]*\) action=\([a-z]*\) .*/\2/p')"
jl="/tmp/s4e/$PSEAT/grade/job.$jid.log"
c_rc=0; { [ "$wr" = 0 ] || [ "$wr" = 1 ]; } && [ "$wa" = delete ] && c_rc=1
c_log=0; [ -f "$jl" ] && ! grep -q "syntax error" "$jl" && c_log=1
n="$(awk -F'\t' -v t="$t0" -v e="$ENT" 'NR > 1 && $1 >= t && $8 == e {n++} END {print n + 0}' "$SCR/progress/results.tsv" 2>/dev/null)"
c_row=0; [ "${n:-0}" -ge 1 ] && c_row=1
if [ "$c_rc$c_log$c_row" = 111 ]; then
    echo "GRADE_WORKER_PKG_PROBE ok=1 rc 0 job=$jid worker_rc=$wrc line=$(printf '%s' "$line" | cut -c1-200) new_rows=$n"
    exit 0
fi
bad=""; [ "$c_rc" = 1 ] || bad="$bad rc_line"; [ "$c_log" = 1 ] || bad="$bad job_log"; [ "$c_row" = 1 ] || bad="$bad results_row"
echo "GRADE_WORKER_PKG_PROBE ok=0 rc 1 failing:$bad job=$jid worker_rc=$wrc line=$(printf '%s' "$line" | cut -c1-200) new_rows=${n:-0}"
exit 1
