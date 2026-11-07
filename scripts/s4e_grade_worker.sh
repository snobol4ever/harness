#!/usr/bin/env bash
# s4e_grade_worker.sh [N] [--once] [--tube T] [--probe] -- THE GRADE WORKER (DESIGN-PLAN test-cycle step 4b, CTO-522; the cio 2026-11-07; skill suites-and-grading section 7).
# Instance N reserves one job from tube `grade` (util_grade_job.py put's JSON: suite, cell, modes, tree, requester, pri, ttr_s, entries) and runs its cell as ONE harness
# launch: corpus_suite_harness.py run <lang ALL container> <ALL.ref> --lang L --modes M --partition P, under util_run_slot.sh. The reserving connection lives in the lease
# process (beanstalkd releases a reserved job when its connection closes), which touches the job every 60 s while the launch runs, deletes it on rc 0 or 1 (a red program
# is a reading), and buries it on any other rc (rc 2 is a refusal; beanstalkd has no reason field, so the reason goes on the GRADE_WORKERS.log line). Each job appends one
# line to /home/resources/progress/GRADE_WORKERS.log, never under S4E_PROGRESS_OFF=1. Package suites: SUITES.tsv has no runner column, so only a language container runs here.
#   bash harness/scripts/s4e_grade_worker.sh N            the loop: reserve, run, repeat; an empty tube waits 5 s
#   bash harness/scripts/s4e_grade_worker.sh N --once     one job, then exit: rc 0 a job ran, rc 1 nothing reserved
#   --tube T     the tube to reserve from (default grade)
#   --probe      step 4b's probe: a private beanstalkd on a free port (never 11300), one request-band snobol4 entry put by util_grade_job.py into a scratch tube, one
#                --once run under strace -f -e trace=execve; prints GRADE_WORKER reserved= launches= modes= deleted= progress=off (rc 0 only if all three read 1)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; N=1; ONCE=0; TUBE=grade; PROBE=0; LOG=/home/resources/progress/GRADE_WORKERS.log
while [ $# -gt 0 ]; do case "$1" in
    --once) ONCE=1; shift ;;
    --probe) PROBE=1; shift ;;
    --tube) TUBE="${2:?REFUSE(2) [grade_worker]: --tube takes a tube name}"; shift 2 ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}"; exit 0 ;;
    [0-9]*) N="$1"; shift ;;
    *) echo "REFUSE(2) [grade_worker]: unknown argument $1" >&2; exit 2 ;;
esac; done
[ "${S4E_PROGRESS_OFF:-}" = 1 ] && LOG=""
probe() {
    local port=$((21000 + ($$ % 20000))) bpid tube="grade-probe-$$" T suite entry jid R L M D gone wrc up=0 i
    [ "$port" = 11300 ] && port=$((port + 1))
    local dir="/tmp/s4e/${S4E_SEAT:-grade}"
    mkdir -p "$dir" && T="$(mktemp -d "$dir/grade_probe.XXXXXX")" || { echo "REFUSE(2) [grade_worker --probe]: cannot make $dir"; return 2; }
    beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bpid=$!
    trap "kill $bpid 2>/dev/null; wait $bpid 2>/dev/null; rm -rf '$T'" EXIT
    for i in $(seq 1 50); do S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_queue.py" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && { up=1; break; }; sleep 0.1; done
    { [ "$up" = 1 ] && kill -0 "$bpid" 2>/dev/null; } || { echo "REFUSE(2) [grade_worker --probe]: a private beanstalkd would not start on port $port"; return 2; }
    suite="$(awk -F'\t' '$4=="snobol4"{print $1; exit}' /home/resources/progress/SUITES.tsv)"
    entry="$(python3 -c 'import sys
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if not l.startswith("#")]
h = rows[0]
print(next(r[h.index("entry")] for r in rows[1:] if r[h.index("part")] == "core"))' "$S4E/corpus/tests/snobol4/PARTITION.tsv")" || { echo "REFUSE(2) [grade_worker --probe]: no core entry in the snobol4 partition"; return 2; }
    jid="$(S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_grade_job.py" put --suite "$suite" --cell "entry:$entry" --band request --modes m3,m4 --tube "$tube" \
        | sed -n 's/^job=\([0-9][0-9]*\) .*/\1/p')"
    [ -n "$jid" ] || { echo "REFUSE(2) [grade_worker --probe]: util_grade_job.py put placed no job on $tube"; return 2; }
    S4E_PROGRESS_OFF=1 S4E_QUEUE_PORT="$port" strace -f -e trace=execve -s 4096 -o "$T/strace.txt" bash "${BASH_SOURCE[0]}" "$N" --once --tube "$tube" > "$T/worker.out" 2>&1; wrc=$?
    R="$(grep -c '^GRADE_RESERVED ' "$T/worker.out")"; D="$(grep -c '^GRADE_DONE .*action=delete' "$T/worker.out")"
    L="$(grep -c -E 'execve\("[^"]*bash", \["bash", "[^"]*util_run_slot\.sh", "python[^"]*", "[^"]*corpus_suite_harness\.py".* = 0$' "$T/strace.txt")"
    M="$(sed -n 's/^GRADE_RESERVED .* modes=\([^ ]*\).*/\1/p' "$T/worker.out" | head -1)"
    S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_queue.py" stats-job "$jid" > /dev/null 2>&1; gone=$?
    echo "GRADE_WORKER reserved=$R launches=$L modes=${M:-none} deleted=$D progress=off"
    echo "GRADE_PROBE job=$jid port=$port worker_rc=$wrc stats_job_rc=$gone (1 = not found, the job is gone)"
    cat "$T/worker.out"
    [ "$R" = 1 ] && [ "$L" = 1 ] && [ "$D" = 1 ] && [ "$gone" = 1 ] && return 0
    return 1
}
if [ "$PROBE" = 1 ]; then probe; exit $?; fi
while :; do
    python3 - "$S4E" "$TUBE" "$N" "$ONCE" "$LOG" 5 <<'PY'
import os, sys, json, time, subprocess
S4E, TUBE, N, ONCE, LOG, TMO = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5], int(sys.argv[6])
sys.path.insert(0, os.path.join(S4E, "harness", "scripts"))
import util_queue
gs, c = util_queue.client()
EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "pascal": "pas", "raku": "raku", "rebus": "reb", "snocone": "sc"}
def say(m): print(m, flush=True)
def lang_of(key):
    for l in open("/home/resources/progress/SUITES.tsv"):
        f = l.rstrip("\n").split("\t")
        if len(f) > 3 and f[0] == key: return f[3]
    return None
def part_of(cell):
    if cell == "core" or cell.startswith(("shell:", "chunk:")): return cell
    if cell.startswith("entry:") and len(cell) > 6: return ",".join("entry:" + e for e in cell[6:].split(","))
    return None
def one():
    c.watch(TUBE); c.ignore("default")
    try:
        job = c.reserve(timeout=TMO)
    except gs.TimedOutError:
        return 1
    t0 = time.time(); why = None; suite = cell = modes = "?"; pri = 1000
    try:
        j = json.loads(job.body); suite, cell, modes, pri = j["suite"], j["cell"], j.get("modes", "m3,m4"), int(j.get("pri", 1000))
    except Exception as e:
        why = "refused: unreadable job body (%s)" % e
    say("GRADE_RESERVED job=%d tube=%s suite=%s cell=%s modes=%s worker=%s" % (job.id, TUBE, suite, cell, modes, N))
    rc = 2
    if why is None:
        lang, part = lang_of(suite), part_of(cell)
        alls = os.path.join(S4E, "corpus", "tests", lang or "-", "ALL.%s" % EXT.get(lang, "-"))
        if lang not in EXT or part is None: why = "refused: suite %r lang %r cell %r" % (suite, lang, cell)
        elif not os.path.isfile(alls): why = "refused: no container %s" % alls
    if why is None:
        cmd = ["bash", os.path.join(S4E, "harness", "scripts", "util_run_slot.sh"), "python3", os.path.join(S4E, "harness", "scripts", "corpus_suite_harness.py"),
               "run", alls, os.path.join(os.path.dirname(alls), "ALL.ref"), "--lang", lang, "--modes", modes, "--partition", part]
        d = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT", "grade"), "grade"); os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "job.%d.log" % job.id), "ab") as out:
            p = subprocess.Popen(cmd, cwd=S4E, stdout=out, stderr=subprocess.STDOUT)
            last = time.time()
            while p.poll() is None:
                time.sleep(1)
                if time.time() - last >= 60:
                    try: c.touch(job); last = time.time()
                    except Exception as e: say("GRADE_LEASE job=%d touch failed: %s" % (job.id, e))
        rc = p.returncode; why = None if rc in (0, 1) else "rc=%d from the harness launch" % rc
    action = "delete" if rc in (0, 1) and why is None else "bury"
    try:
        c.delete(job) if action == "delete" else c.bury(job, priority=pri)
    except Exception as e:
        action = "lost"; why = "%s (the lease was gone: %s)" % (why or "", e)
    secs = int(time.time() - t0)
    say("GRADE_DONE job=%d rc=%d action=%s secs=%d suite=%s cell=%s modes=%s reason=%s" % (job.id, rc, action, secs, suite, cell, modes, why or "-"))
    if LOG:
        stamp = time.strftime("%FT%TZ", time.gmtime())
        with open(LOG, "a") as f: f.write("%s worker=%s job=%d suite=%s cell=%s modes=%s rc=%d action=%s secs=%d reason=%s\n" % (stamp, N, job.id, suite, cell, modes, rc, action, secs, why or "-"))
    return 0
sys.exit(0 if one() == 0 else 1)
PY
    rc=$?
    [ "$ONCE" = 1 ] && exit "$rc"
    [ "$rc" = 0 ] || sleep 5
done
