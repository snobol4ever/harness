#!/usr/bin/env bash
# s4e_probe_grade_request_job_retries_nothing_on_an_idle_box.sh -- THE PROBE of row grading-a-request-job-runs-without-timeout-retry-on-an-idle-box (senior_06, from
# officer_05's design of 19:46 CST: one shared holder graded a hanging entry for over 1080 s under util_timeout_retry.sh's up-to-6x retry, and every request behind it
# waited; on an idle box a retry cannot rescue a hang). lib_grade_locks.launch_env(env, pri, psi_path) must return the env with S4E_TIMEOUT_RETRY=0 for a request-band job
# (priority below 200) while the cpu PSI "some avg60" reads under 20, and the env unchanged for a request job on a busy box (avg60 35), for a lap job (priority 900) on an
# idle box, and when the PSI file is unreadable; and the grade worker must call it. One line:
# GRADE_RETRY request_idle=0|1 request_busy=0|1 lap_idle=0|1 no_psi=0|1 wired=0|1 ok=0|1 (each 1 when it reads as said). rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
SC="$S4E/harness/scripts"
[ -f "$SC/lib_grade_locks.py" ] && [ -f "$SC/s4e_grade_worker.sh" ] || { echo "REFUSE(2): no lib_grade_locks.py or s4e_grade_worker.sh under $SC"; exit 2; }
t="$(mktemp -d "/tmp/s4e/$ME/gr_retry.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$t"' EXIT
printf 'some avg10=0.10 avg60=0.20 avg300=0.15 total=12345\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' > "$t/idle"
printf 'some avg10=40.10 avg60=35.00 avg300=20.15 total=99999\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' > "$t/busy"
r="$(python3 -I - "$SC" "$t" <<'PY'
import sys, os
sys.path.insert(0, sys.argv[1])
try:
    import lib_grade_locks as GL
    t = sys.argv[2]; env = {"A": "1", "S4E_TIMEOUT_RETRY": "6"}
    ri = GL.launch_env(env, 100, os.path.join(t, "idle")).get("S4E_TIMEOUT_RETRY") == "0"
    rb = GL.launch_env(env, 100, os.path.join(t, "busy")).get("S4E_TIMEOUT_RETRY") == "6"
    li = GL.launch_env(env, 900, os.path.join(t, "idle")).get("S4E_TIMEOUT_RETRY") == "6"
    np_ = GL.launch_env(env, 100, os.path.join(t, "absent")).get("S4E_TIMEOUT_RETRY") == "6"
    print(int(ri), int(rb), int(li), int(np_))
except Exception:
    print("0 0 0 0")
PY
)"
set -- $r; ri="$1"; rb="$2"; li="$3"; np="$4"
wr=0; grep -q 'GL\.launch_env(' "$SC/s4e_grade_worker.sh" && wr=1
ok=0; [ "$ri$rb$li$np$wr" = 11111 ] && ok=1
echo "GRADE_RETRY request_idle=$ri request_busy=$rb lap_idle=$li no_psi=$np wired=$wr ok=$ok"
[ "$ok" = 1 ]
