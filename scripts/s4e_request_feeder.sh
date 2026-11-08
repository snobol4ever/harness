#!/usr/bin/env bash
# s4e_request_feeder.sh [--probe] -- THE REQUEST FEEDER, RUN BY CRON EVERY TWO MINUTES (officer_05's design test-requests-are-fed-and-served-by-a-cron-feeder-without-the-controller-mode-3-only, COO-493, Lon's order mode 3 only COO-487).
# A landed row's test request (one .req in the request dir) is fed as one request-band grade job in mode m3 and served at once, with no controller: box_tick.py --feed-once, then
# up to 8 jobs of priority below 200 through s4e_grade_worker.sh 1 --once. It never reads CYCLE.STOP: requests are served while the cycle is stopped. REQUEST_FEEDER.STOP (Lon's hand) silences it.
#   crontab line (the coo's to install, in the grader root):  */2 * * * * XDG_RUNTIME_DIR=/run/user/1000 systemd-run --user --scope --slice=s4e-grader.slice -q bash /home/claude_grader/harness/scripts/s4e_request_feeder.sh >> /home/resources/progress/REQUEST_FEEDER.log 2>&1
#   bash s4e_request_feeder.sh --probe    a private beanstalkd, one planted .req in a scratch dir: one run feeds it (modes m3) and serves it, a second run feeds and serves nothing; prints REQUEST_FEEDER_PROBE ... ok=1
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROG=/home/resources/progress
STOP="${S4E_FEEDER_STOP:-$PROG/REQUEST_FEEDER.STOP}"
LOCK="${S4E_FEEDER_LOCK:-$PROG/.request_feeder.lock}"
TUBE="${S4E_GRADE_TUBE:-grade}"
run_once() {
    local fed served=0 head pri
    [ -e "$STOP" ] && { echo "REQUEST_FEEDER stopped ($STOP exists)"; return 0; }
    exec 9>"$LOCK"
    flock -n 9 || { echo "REQUEST_FEEDER busy (another instance holds $LOCK)"; return 0; }
    export S4E_HOME="$S4E" S4E_SEAT=grader S4E_CLASS=grader S4E_MODES=m3
    fed="$(python3 -I "$S4E/harness/scripts/box_tick.py" --feed-once | sed -n 's/^REQUEST_FEED fed=//p')"
    while [ "$served" -lt 8 ]; do
        head="$(python3 -I "$S4E/harness/scripts/util_queue.py" peek "$TUBE" 2>/dev/null)" || break
        pri="$(printf '%s\n' "$head" | awk 'NR==1{print $2}')"
        [ -n "$pri" ] && [ "$pri" -lt 200 ] || break
        bash "$S4E/harness/scripts/s4e_grade_worker.sh" 1 --once --tube "$TUBE" >/dev/null 2>&1 || break
        served=$((served + 1))
    done
    echo "REQUEST_FEEDER fed=${fed:-0} served=$served"
}
probe() {
    local port=$((21000 + ($$ % 20000))) bpid T suite entry name="20261108T000000-probe-feeder-sno-rungs.req" up=0 i o1 o2 fedline done
    [ "$port" = 11300 ] && port=$((port + 1))
    local dir="/tmp/s4e/${S4E_SEAT:-grader}"
    mkdir -p "$dir" && T="$(mktemp -d "$dir/request_feeder.XXXXXX")" || { echo "REFUSE(2) [request_feeder --probe]: cannot make $dir"; return 2; }
    beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bpid=$!
    trap "kill $bpid 2>/dev/null; wait $bpid 2>/dev/null; rm -rf '$T'" EXIT
    for i in $(seq 1 50); do S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_queue.py" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && { up=1; break; }; sleep 0.1; done
    { [ "$up" = 1 ] && kill -0 "$bpid" 2>/dev/null; } || { echo "REFUSE(2) [request_feeder --probe]: a private beanstalkd would not start on port $port"; return 2; }
    entry="$(python3 -c 'import sys
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if not l.startswith("#")]
h = rows[0]
print(next(r[h.index("entry")] for r in rows[1:] if r[h.index("part")] == "core"))' "$S4E/corpus/tests/snobol4/PARTITION.tsv")" || { echo "REFUSE(2) [request_feeder --probe]: no core entry in the snobol4 partition"; return 2; }
    mkdir -p "$T/record/test_requests"
    printf 'seat=probe-feeder\nsuite=sno-rungs\ntable=tests/snobol4\nfiled=probe-feeder (scratch only)\nentries=%s\nsince=probe-feeder\n' "$entry" > "$T/record/test_requests/$name"
    o1="$(S4E_SEAT=probe-feeder S4E_QUEUE_PORT="$port" S4E_GRADE_TUBE="grade-feeder-$$" S4E_GRADE_SCRATCH="$T/record" S4E_TEST_REQUEST_DIR="$T/record/test_requests" S4E_FEEDER_LOCK="$T/lock" S4E_FEEDER_STOP="$T/nostop" timeout 900 bash "${BASH_SOURCE[0]}" 2>&1)"
    fedline="$(grep -c '^fed=.* job=[0-9]' "$T/record/test_requests/done/$name" 2>/dev/null)"
    o2="$(S4E_SEAT=probe-feeder S4E_QUEUE_PORT="$port" S4E_GRADE_TUBE="grade-feeder-$$" S4E_GRADE_SCRATCH="$T/record" S4E_TEST_REQUEST_DIR="$T/record/test_requests" S4E_FEEDER_LOCK="$T/lock" S4E_FEEDER_STOP="$T/nostop" timeout 900 bash "${BASH_SOURCE[0]}" 2>&1)"
    done=0; [ -f "$T/record/test_requests/done/$name" ] && grep -q '^served=' "$T/record/test_requests/done/$name" && done=1
    echo "first: $o1"; echo "second: $o2"
    echo "REQUEST_FEEDER_PROBE first_fed1_served1=$([ "$o1" = "REQUEST_FEEDER fed=1 served=1" ] && echo 1 || echo 0) in_done_with_fed_and_served=$([ "$done" = 1 ] && [ "${fedline:-0}" = 1 ] && echo 1 || echo 0) second_idle=$([ "$o2" = "REQUEST_FEEDER fed=0 served=0" ] && echo 1 || echo 0)"
    [ "$o1" = "REQUEST_FEEDER fed=1 served=1" ] && [ "$done" = 1 ] && [ "${fedline:-0}" = 1 ] && [ "$o2" = "REQUEST_FEEDER fed=0 served=0" ]
}
[ "${1:-}" = --probe ] && { probe; exit $?; }
run_once
