#!/usr/bin/env bash
# s4e_grade_worker.sh [N] [--once] [--tube T] [--probe | --probe-record] -- THE GRADE WORKER (DESIGN-PLAN test-cycle steps 4b and 4c, CTO-522; the cio 2026-11-07; skill suites-and-grading section 7).
# Instance N reserves one job from tube `grade` (util_grade_job.py put's JSON: suite, cell, modes, tree, requester, pri, ttr_s, entries) and runs its cell as ONE harness
# launch: corpus_suite_harness.py run <lang ALL container> <ALL.ref> --lang L --modes M --partition P, under util_run_slot.sh. The reserving connection lives in the lease
# process (beanstalkd releases a reserved job when its connection closes), which touches the job every 60 s while the launch runs, deletes it on rc 0 or 1 (a red program
# is a reading), and buries it on any other rc (rc 2 is a refusal; beanstalkd has no reason field, so the reason goes on the GRADE_WORKERS.log line). Each job appends one
# line to /home/resources/progress/GRADE_WORKERS.log, never under S4E_PROGRESS_OFF=1. THE RUNNER TABLE (step 9): harness/scripts/SUITE_RUNNERS.tsv names each key's kind,
# lang, runner and table. A master (kind master) launches corpus_suite_harness.py as above; a package (kind pkg) runs S4E_CHUNK=<cell> bash harness/scripts/<runner>
# under the same util_run_slot.sh admission and the same verdict rule, and the master's record step does not run for it (its runner writes its own rows); any other kind refuses.
# After a launch that read (rc 0 or 1) the lease RECORDS what loop8 writes (step 4c): the suite row of the rungs key of the container it graded, through util_score_row.py
# from-progress (an incomplete population writes no row and says so); for a request-band job (pri 100) the verdict: the pending request of its seat that names its entries
# moves to test_requests/done/ with graded=/rc= pairs and one served= line. S4E_GRADE_SCRATCH=<dir> sends every record write and the harness's progress rows to a scratch
# copy under <dir> (copies of the progress DB, SUITES.tsv, SCORE.md and the request dir, made once). Under S4E_PROGRESS_OFF=1 without it nothing is recorded.
#   bash harness/scripts/s4e_grade_worker.sh N            the loop: reserve, run, record, repeat; an empty tube waits 5 s
#   bash harness/scripts/s4e_grade_worker.sh N --once     one job, then exit: rc 0 a job ran, rc 1 nothing reserved
#   --tube T          the tube to reserve from (default grade)
#   --probe           step 4b's probe: a private beanstalkd on a free port (never 11300), one request-band snobol4 entry put by util_grade_job.py into a scratch tube, one
#                     --once run under strace -f -e trace=execve; prints GRADE_WORKER reserved= launches= modes= deleted= progress=off (rc 0 only if all four read as wanted)
#   --probe-smoke     step 4d's probe: a scratch results table (a program PASS then FAIL), a scratch SMOKE.tsv and a scratch post office; drives lib_grade_cell.sh's
#                     grade_cell_after, the call the lease makes after record(); prints GRADE_SMOKE smoke_tsv= new_red_telegram= scratch= (rc 0 only if all three read 1)
#   --probe-record    step 4c's probe: the same private daemon, a planted pending request in a scratch dir, one --once run with S4E_GRADE_SCRATCH; prints GRADE_RECORD
#                     suite_row= verdict= scratch= (rc 0 only if all three read 1 and the request moved to done/)
#   --probe-package   step 9's probe: the same private daemon, one job for the puzzles package (its first partition entry, a one-entry cell) in a scratch tube, one
#                     --once run under strace with S4E_PROGRESS_OFF=1 and every progress path in a scratch copy; prints GRADE_WORKER package=1 runner=<runner>
#                     launches=1 modes=m3,m4 deleted=1 (rc 0 only if it reads so; else GRADE_WORKER package RED: <what differed>)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; N=1; ONCE=0; TUBE=grade; PROBE=0; LOG=/home/resources/progress/GRADE_WORKERS.log
while [ $# -gt 0 ]; do case "$1" in
    --once) ONCE=1; shift ;;
    --probe) PROBE=1; shift ;;
    --probe-record) PROBE=2; shift ;;
    --probe-smoke) PROBE=3; shift ;;
    --probe-package) PROBE=4; shift ;;
    --tube) TUBE="${2:?REFUSE(2) [grade_worker]: --tube takes a tube name}"; shift 2 ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{print}' "${BASH_SOURCE[0]}"; exit 0 ;;
    [0-9]*) N="$1"; shift ;;
    *) echo "REFUSE(2) [grade_worker]: unknown argument $1" >&2; exit 2 ;;
esac; done
[ "${S4E_PROGRESS_OFF:-}" = 1 ] && LOG=""
[ -n "${S4E_GRADE_SCRATCH:-}" ] && LOG="$S4E_GRADE_SCRATCH/GRADE_WORKERS.log"
probe() {
    local port=$((21000 + ($$ % 20000))) bpid tube="grade-probe-$$" T suite entry jid R L M D gone wrc up=0 i
    [ "$port" = 11300 ] && port=$((port + 1))
    local dir="/tmp/s4e/${S4E_SEAT:-grade}"
    mkdir -p "$dir" && T="$(mktemp -d "$dir/grade_probe.XXXXXX")" || { echo "REFUSE(2) [grade_worker --probe]: cannot make $dir"; return 2; }
    beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bpid=$!
    trap "kill $bpid 2>/dev/null; wait $bpid 2>/dev/null; rm -rf '$T'" EXIT
    for i in $(seq 1 50); do S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_queue.py" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && { up=1; break; }; sleep 0.1; done
    { [ "$up" = 1 ] && kill -0 "$bpid" 2>/dev/null; } || { echo "REFUSE(2) [grade_worker --probe]: a private beanstalkd would not start on port $port"; return 2; }
    suite="$(awk -F'\t' '$2=="master" && $3=="snobol4"{print $1; exit}' "$S4E/harness/scripts/SUITE_RUNNERS.tsv")"
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
probe_record() {
    local port=$((21000 + ($$ % 20000))) bpid tube="grade-record-$$" T suite entry jid wrc up=0 i REC name="20261107T000000-probe-record-sno-rungs.req"
    [ "$port" = 11300 ] && port=$((port + 1))
    local dir="/tmp/s4e/${S4E_SEAT:-grade}"
    mkdir -p "$dir" && T="$(mktemp -d "$dir/grade_record.XXXXXX")" || { echo "REFUSE(2) [grade_worker --probe-record]: cannot make $dir"; return 2; }
    beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bpid=$!
    trap "kill $bpid 2>/dev/null; wait $bpid 2>/dev/null; rm -rf '$T'" EXIT
    for i in $(seq 1 50); do S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_queue.py" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && { up=1; break; }; sleep 0.1; done
    { [ "$up" = 1 ] && kill -0 "$bpid" 2>/dev/null; } || { echo "REFUSE(2) [grade_worker --probe-record]: a private beanstalkd would not start on port $port"; return 2; }
    suite="$(awk -F'\t' '$2=="master" && $3=="snobol4"{print $1; exit}' "$S4E/harness/scripts/SUITE_RUNNERS.tsv")"
    entry="$(python3 -c 'import sys
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if not l.startswith("#")]
h = rows[0]
print(next(r[h.index("entry")] for r in rows[1:] if r[h.index("part")] == "core"))' "$S4E/corpus/tests/snobol4/PARTITION.tsv")" || { echo "REFUSE(2) [grade_worker --probe-record]: no core entry in the snobol4 partition"; return 2; }
    mkdir -p "$T/record/test_requests"
    printf 'seat=probe-record\nsuite=sno-rungs\ntable=tests/snobol4\nfiled=probe-record (step 4c probe, scratch only)\nentries=%s\nsince=probe-record\n' "$entry" > "$T/record/test_requests/$name"
    jid="$(S4E_SEAT=probe-record S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_grade_job.py" put --suite "$suite" --cell "entry:$entry" --band request --modes m3,m4 --tube "$tube" \
        | sed -n 's/^job=\([0-9][0-9]*\) .*/\1/p')"
    [ -n "$jid" ] || { echo "REFUSE(2) [grade_worker --probe-record]: util_grade_job.py put placed no job on $tube"; return 2; }
    S4E_SEAT=probe-record S4E_GRADE_SCRATCH="$T/record" S4E_QUEUE_PORT="$port" timeout 900 bash "${BASH_SOURCE[0]}" "$N" --once --tube "$tube" > "$T/worker.out" 2>&1; wrc=$?
    REC="$(sed -n 's/^RECORD .* \(suite_row=[0-9]*\) \(verdict=[0-9]*\) \(scratch=[0-9]*\).*/\1 \2 \3/p' "$T/worker.out" | head -1)"
    echo "GRADE_RECORD ${REC:-suite_row=0 verdict=0 scratch=0}"
    echo "GRADE_RECORD_PROBE job=$jid port=$port worker_rc=$wrc moved_to_done=$([ -f "$T/record/test_requests/done/$name" ] && echo 1 || echo 0) pending_left=$([ -f "$T/record/test_requests/$name" ] && echo 1 || echo 0)"
    tail -4 "$T/worker.out" | cut -c1-240
    [ "$REC" = "suite_row=1 verdict=1 scratch=1" ] && [ -f "$T/record/test_requests/done/$name" ]
}
probe_smoke() {
    local dir="/tmp/s4e/${S4E_SEAT:-grade}" T scr out nt inbox smoke nrt sc lsm0 lsm1 i H
    mkdir -p "$dir" && T="$(mktemp -d "$dir/grade_smoke.XXXXXX")" || { echo "REFUSE(2) [grade_worker --probe-smoke]: cannot make $dir"; return 2; }
    trap "rm -rf '$T'" EXIT
    scr="$T/smoke"; mkdir -p "$scr"
    H="$(printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig')"
    { echo "$H"
      printf '2026-11-07T10:00:00\taaa1111\tccc\tcoo\trungs\tfixture-smoke\tsnobol4\tfx_prog\tm3\tPASS\t0.01\t\t\t\n'
      printf '2026-11-07T10:00:00\taaa1111\tccc\tcoo\trungs\tfixture-smoke\tsnobol4\tfx_prog\tm4\tPASS\t0.01\t\t\t\n'; } > "$scr/snap.tsv"
    { cat "$scr/snap.tsv"
      printf '2026-11-07T11:00:00\tbbb2222\tccc\tcoo\trungs\tfixture-smoke\tsnobol4\tfx_prog\tm3\tFAIL\t0.01\t\t\t\n'
      printf '2026-11-07T11:00:00\tbbb2222\tccc\tcoo\trungs\tfixture-smoke\tsnobol4\tfx_prog\tm4\tPASS\t0.01\t\t\t\n'; } > "$scr/results.tsv"
    mkdir -p "$scr/post"; cp /home/resources/postoffice/MODE "$scr/post/MODE"
    for i in $(sed -n 's/^ROSTER: //p' "$scr/post/MODE"); do mkdir -p "$scr/post/$i/inbox"; done
    lsm0="$(wc -l < /home/resources/progress/SMOKE.tsv 2>/dev/null || echo 0)"
    out="$(S4E_HOME="$S4E" S4E_SEAT=worker_20 S4E_RESULTS="$scr/results.tsv" S4E_SMOKE_TSV="$scr/SMOKE.tsv" S4E_POST="$scr/post" S4E_TIERS="$S4E/.github/TIERS.tsv" \
        bash "$S4E/harness/scripts/lib_grade_cell.sh" grade_cell_after fixture-smoke bbb2222 smoke "$scr/snap.tsv" 1 fx_prog 2>&1)"
    lsm1="$(wc -l < /home/resources/progress/SMOKE.tsv 2>/dev/null || echo 0)"
    echo "$out" | sed 's/^/  | /' | head -6
    smoke=0; grep -q 'bbb2222' "$scr/SMOKE.tsv" 2>/dev/null && smoke=1
    nt="$(echo "$out" | sed -n 's/^GRADE_CELL_AFTER .* new_reds_told=\([0-9]*\).*/\1/p')"; inbox="$(ls "$scr/post/cto/inbox" 2>/dev/null | wc -l)"
    nrt=0; [ "${nt:-0}" = 1 ] && [ "$inbox" = 1 ] && nrt=1
    sc=0; [ "$lsm0" = "$lsm1" ] && [ "$smoke" = 1 ] && sc=1
    echo "GRADE_SMOKE smoke_tsv=$smoke new_red_telegram=$nrt scratch=$sc"
    [ "$smoke" = 1 ] && [ "$nrt" = 1 ] && [ "$sc" = 1 ]
}
probe_package() {
    local port=$((21000 + ($$ % 20000))) bpid tube="grade-package-$$" T suite entry jid R L M D gone wrc up=0 i runner rfile pat
    [ "$port" = 11300 ] && port=$((port + 1))
    local dir="/tmp/s4e/${S4E_SEAT:-grade}"
    mkdir -p "$dir" && T="$(mktemp -d "$dir/grade_package.XXXXXX")" || { echo "REFUSE(2) [grade_worker --probe-package]: cannot make $dir"; return 2; }
    beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bpid=$!
    trap "kill $bpid 2>/dev/null; wait $bpid 2>/dev/null; rm -rf '$T'" EXIT
    for i in $(seq 1 50); do S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_queue.py" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && { up=1; break; }; sleep 0.1; done
    { [ "$up" = 1 ] && kill -0 "$bpid" 2>/dev/null; } || { echo "REFUSE(2) [grade_worker --probe-package]: a private beanstalkd would not start on port $port"; return 2; }
    suite=puzzles
    runner="$(awk -F'\t' -v k="$suite" '$1 == k {print $4; exit}' "$S4E/harness/scripts/SUITE_RUNNERS.tsv")"
    [ -n "$runner" ] && [ "$runner" != "-" ] || { echo "REFUSE(2) [grade_worker --probe-package]: no runner for $suite in SUITE_RUNNERS.tsv"; return 2; }
    rfile="${runner%% *}"; pat="$(printf '%s' "$rfile" | sed 's/\./\\./g')"
    entry="$(python3 -c 'import sys
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if not l.startswith("#")]
h = rows[0]
print(rows[1][h.index("entry")])' "$S4E/corpus/packages/prolog/puzzles/PARTITION.tsv")" || { echo "REFUSE(2) [grade_worker --probe-package]: no entry in the puzzles partition"; return 2; }
    jid="$(S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_grade_job.py" put --suite "$suite" --cell "entry:$entry" --band request --modes m3,m4 --tube "$tube" \
        | sed -n 's/^job=\([0-9][0-9]*\) .*/\1/p')"
    [ -n "$jid" ] || { echo "REFUSE(2) [grade_worker --probe-package]: util_grade_job.py put placed no job on $tube"; return 2; }
    S4E_PROGRESS_OFF=1 S4E_GRADE_SCRATCH="$T/scratch" S4E_QUEUE_PORT="$port" strace -f -e trace=execve -s 4096 -o "$T/strace.txt" bash "${BASH_SOURCE[0]}" "$N" --once --tube "$tube" > "$T/worker.out" 2>&1; wrc=$?
    R="$(grep -c '^GRADE_RESERVED ' "$T/worker.out")"; D="$(grep -c '^GRADE_DONE .*action=delete' "$T/worker.out")"
    L="$(grep -c -E 'execve\("[^"]*bash", \["bash", "[^"]*util_run_slot\.sh", "bash", "[^"]*'"$pat"'"\].* = 0$' "$T/strace.txt")"
    M="$(sed -n 's/^GRADE_RESERVED .* modes=\([^ ]*\).*/\1/p' "$T/worker.out" | head -1)"
    S4E_QUEUE_PORT="$port" python3 "$S4E/harness/scripts/util_queue.py" stats-job "$jid" > /dev/null 2>&1; gone=$?
    if [ "$R" = 1 ] && [ "$L" = 1 ] && [ "$D" = 1 ] && [ "$gone" = 1 ] && [ "$M" = m3,m4 ]; then
        echo "GRADE_WORKER package=1 runner=$runner launches=$L modes=$M deleted=$D"; return 0
    fi
    echo "GRADE_WORKER package RED: reserved=$R launches=$L modes=${M:-none} deleted=$D job_gone=$gone runner=$runner entry=$entry worker_rc=$wrc"
    tail -n 12 "$T/worker.out" | sed 's/^/    /'
    return 1
}
if [ "$PROBE" = 1 ]; then probe; exit $?; fi
if [ "$PROBE" = 4 ]; then probe_package; exit $?; fi
if [ "$PROBE" = 2 ]; then probe_record; exit $?; fi
if [ "$PROBE" = 3 ]; then probe_smoke; exit $?; fi
while :; do
    python3 - "$S4E" "$TUBE" "$N" "$ONCE" "$LOG" 5 "${S4E_GRADE_SCRATCH:-}" <<'PY'
import os, sys, json, time, subprocess, shutil, re
S4E, TUBE, N, ONCE, LOG, TMO, SCR = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5], int(sys.argv[6]), sys.argv[7]
sys.path.insert(0, os.path.join(S4E, "harness", "scripts"))
import util_queue
import lib_grade_locks as GL
gs, c = util_queue.client()
EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "pascal": "pas", "raku": "raku", "rebus": "reb", "snocone": "sc"}
CONTAINER = {"snobol4": "sno-rungs", "icon": "icn-rungs", "prolog": "pl-rungs", "pascal": "pas-rungs", "raku": "raku-rungs", "snocone": "snc-rungs", "rebus": "reb-rungs"}
LIVE_PROG, LIVE_REQ = "/home/resources/progress", "/home/resources/postoffice/test_requests"
UR = os.path.join(S4E, "harness", "scripts", "util_score_row.py")
def scratch_env():
    if not SCR: return {}
    p = os.path.join(SCR, "progress"); os.makedirs(p, exist_ok=True); os.makedirs(os.path.join(SCR, "test_requests", "done"), exist_ok=True)
    for src, dst in ((LIVE_PROG + "/results.tsv", p + "/results.tsv"), (LIVE_PROG + "/SUITES.tsv", p + "/SUITES.tsv"), (os.path.join(S4E, ".github", "SCORE.md"), os.path.join(SCR, "SCORE.md"))):
        if not os.path.exists(dst): shutil.copyfile(src, dst)
    po = os.path.join(SCR, "post"); os.makedirs(po, exist_ok=True)
    if not os.path.exists(po + "/MODE"): shutil.copyfile("/home/resources/postoffice/MODE", po + "/MODE")
    for ln in open(po + "/MODE", encoding="utf-8", errors="replace"):
        if ln.startswith("ROSTER:"):
            for seat in ln.split()[1:]: os.makedirs(os.path.join(po, seat, "inbox"), exist_ok=True)
    return {"S4E_PROGRESS_DB": p + "/results.tsv", "S4E_SUITES_TSV": p + "/SUITES.tsv", "S4E_SCORE_MD": os.path.join(SCR, "SCORE.md"), "S4E_TEST_REQUEST_DIR": os.path.join(SCR, "test_requests"),
            "S4E_RESULTS": p + "/results.tsv", "S4E_SMOKE_TSV": os.path.join(SCR, "SMOKE.tsv"), "S4E_POST": po}
SENV = scratch_env(); ENV = dict(os.environ, S4E_HOME=S4E, S4E_CLASS="grader", **SENV)   # S4E_CLASS=grader: the runners admit seat grader as the coo's instrument (lib_one_runner.sh:one_runner_seat_admitted)
BAND = {100: "request", 200: "smoke", 500: "impact", 900: "lap"}
LIB = os.path.join(S4E, "harness", "scripts", "lib_grade_cell.sh")
PN_PY = "import sys; sys.path.insert(0, sys.argv[1]); import util_suite_rows_vs_progress as a; print(a.dbname(sys.argv[2]))"
def progress_name(key):
    r = subprocess.run([sys.executable, "-c", PN_PY, os.path.join(S4E, "harness", "scripts"), key], capture_output=True, text=True, env=ENV, timeout=120)
    return r.stdout.strip() or key
def say(m): print(m, flush=True)
RUNNERS = os.path.join(S4E, "harness", "scripts", "SUITE_RUNNERS.tsv")
def runner_row(key):
    for l in open(RUNNERS, encoding="utf-8"):
        f = l.rstrip("\n").split("\t")
        if len(f) == 5 and f[0] == key: return f
    return None
def lang_of(key):
    row = runner_row(key)
    if row is None: return None
    if row[1] != "master": return row[2]
    for l in open(LIVE_PROG + "/SUITES.tsv"):
        f = l.rstrip("\n").split("\t")
        if len(f) > 3 and f[0] == key: return f[3]
    return None
def part_of(cell):
    if cell == "core" or cell.startswith(("shell:", "chunk:")): return cell
    if cell.startswith("entry:") and len(cell) > 6: return ",".join("entry:" + e for e in cell[6:].split(","))
    return None
def pending_request(seat, key, entries):
    d = SENV.get("S4E_TEST_REQUEST_DIR", LIVE_REQ)
    for name in sorted(os.listdir(d)):
        if not name.endswith(".req"): continue
        path = os.path.join(d, name); txt = open(path, encoding="utf-8").read().splitlines()
        if any(l.startswith("served=") for l in txt): continue
        f = dict(l.split("=", 1) for l in txt if "=" in l and l.split("=", 1)[0] in ("seat", "suite", "entries"))
        if f.get("seat") == seat and f.get("suite") == key and set(entries) <= set(f.get("entries", "").split()): return path, txt
    return None, None
def entry_rcs(db, entries, lang):
    last = {}
    for line in open(db, encoding="utf-8", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if len(f) > 9 and f[6] == lang and f[7] in entries and f[8] in ("m3", "m4"): last[(f[7], f[8])] = f[9]
    return {e: (0 if last.get((e, "m3")) == "PASS" and last.get((e, "m4")) == "PASS" else 1) for e in entries}
def move_request(key, lang, entries, pri, requester, tree):
    """a request-band job's .req moves to done/ with graded=, rc= and served= lines, for a PACKAGE cell as for a master (the coo 2026-11-07 16:23: jobs 1147, 1172, 1173, 1214
    were deleted with their .req left standing, so a seat waiting on a package verdict never saw one); the rows themselves are the package runner's. Returns verdict 0|1."""
    if pri != 100 or not entries: return 0
    path, txt = pending_request(requester, key, entries)
    if path is None: return 0
    rcs = entry_rcs(ENV.get("S4E_PROGRESS_DB", LIVE_PROG + "/results.tsv"), entries, lang)
    overall = 0 if all(v == 0 for v in rcs.values()) else 1
    body = list(txt)
    for e in entries: body += ["graded=%s" % e, "rc=%d" % rcs[e]]
    body.append("served=%s tree=%s rc=%d rows=%d" % (time.strftime("%Y-%m-%d %H:%M:%S CST"), tree, overall, len(entries)))
    done = os.path.join(os.path.dirname(path), "done", os.path.basename(path))
    os.makedirs(os.path.dirname(done), exist_ok=True)
    with open(done, "w", encoding="utf-8") as f: f.write("\n".join(body) + "\n")
    os.remove(path); return 1
def record(lang, entries, pri, requester, tree):
    key = CONTAINER.get(lang)
    scratch = int(bool(SCR) and all(v.startswith(SCR + "/") for v in SENV.values()))
    if key is None: return 0, 0, scratch, "no rungs key for lang %s" % lang
    r = subprocess.run([sys.executable, UR, "from-progress", "--suite", key], env=ENV, capture_output=True, text=True, timeout=900)
    out = (r.stdout + r.stderr).strip()
    sr = 1 if r.returncode == 0 else 0
    why = "" if sr else ("population incomplete, no suite row" if "have no reading" in out else "from-progress rc %d: %s" % (r.returncode, out[-160:].replace("\n", " | ")))
    vd = 0
    if pri == 100 and entries:
        path, txt = pending_request(requester, key, entries)
        if path is None: why = (why + "; " if why else "") + "no pending request of %s names %s" % (requester, " ".join(entries))
        else:
            rcs = entry_rcs(ENV.get("S4E_PROGRESS_DB", LIVE_PROG + "/results.tsv"), entries, lang)
            overall = 0 if all(v == 0 for v in rcs.values()) else 1
            body = list(txt)
            for e in entries: body += ["graded=%s" % e, "rc=%d" % rcs[e]]
            body.append("served=%s tree=%s rc=%d rows=%d" % (time.strftime("%Y-%m-%d %H:%M:%S CST"), tree, overall, len(entries)))
            done = os.path.join(os.path.dirname(path), "done", os.path.basename(path))
            with open(done, "w", encoding="utf-8") as f: f.write("\n".join(body) + "\n")
            os.remove(path); vd = 1
    return sr, vd, scratch, why
def one():
    c.watch(TUBE); c.ignore("default")
    try:
        job = c.reserve(timeout=TMO)
    except gs.TimedOutError:
        return 1
    t0 = time.time(); why = None; suite = cell = modes = "?"; pri = 1000; j = {}; tree = requester = "?"
    try:
        j = json.loads(job.body); suite, cell, modes, pri = j["suite"], j["cell"], j.get("modes", "m3,m4"), int(j.get("pri", 1000))
        tree, requester = j.get("tree", "?"), j.get("requester", "?")
    except Exception as e:
        why = "refused: unreadable job body (%s)" % e
    say("GRADE_RESERVED job=%d tube=%s suite=%s cell=%s modes=%s worker=%s" % (job.id, TUBE, suite, cell, modes, N))
    rc = 2; lang = None; entries = []; row = runner_row(suite); kind = row[1] if row else "none"; words = []; script = ""
    if why is None:
        lang, part = lang_of(suite), part_of(cell)
        alls = os.path.join(S4E, "corpus", "tests", lang or "-", "ALL.%s" % EXT.get(lang, "-"))
        entries = cell[6:].split(",") if cell.startswith("entry:") else []
        if kind == "master":
            if lang not in EXT or part is None: why = "refused: suite %r lang %r cell %r" % (suite, lang, cell)
            elif not os.path.isfile(alls): why = "refused: no container %s" % alls
        elif kind == "pkg":
            words = row[3].split(); script = os.path.join(S4E, "harness", "scripts", words[0])
            if part is None: why = "refused: package %r cell %r" % (suite, cell)
            elif not os.path.isfile(script): why = "refused: no runner %s for %r" % (words[0], suite)
        else: why = "refused: suite %r is kind %s in SUITE_RUNNERS.tsv (the grade worker launches master and pkg rows)" % (suite, kind)
    def behind():
        head = subprocess.run(["git", "-C", os.path.join(S4E, "SCRIP"), "rev-parse", "--short=9", "HEAD"], capture_output=True, text=True).stdout.strip()
        return not head.startswith(tree[:7]) and not tree.startswith(head[:7])
    def resync():
        if not behind(): return None   # another worker synced to this tree while this one waited
        sy = subprocess.run(["bash", os.path.join(S4E, "harness", "scripts", "util_sync_root.sh")], env=ENV, capture_output=True, text=True, timeout=900)
        mk = subprocess.run(["make", "-j8", "-C", os.path.join(S4E, "SCRIP")], env=ENV, capture_output=True, text=True, timeout=1800) if sy.returncode == 0 else None
        if sy.returncode != 0 or mk.returncode != 0:
            return "refused: the grader root could not reach tree %s (sync rc %d, make rc %s): %s" % (tree, sy.returncode, mk.returncode if mk else "-", ((sy.stdout + sy.stderr) if sy.returncode else (mk.stdout + mk.stderr)).strip()[-160:].replace("\n", " | "))
        return None
    # THE ROOT LOCK (test-cycle, the cio's (2)(i), 2026-11-08): every launch holds the grader root shared from here to its record step; a sync takes it exclusive
    # (gate first, so no new board starts while it waits); the controller's sync never waits (rc 75). A job whose tree the root already carries takes no sync.
    held = None
    if why is None:
# fleet-control step 10b (the cio, 2026-11-07 14:3x): the grader's root is synced and
        # built to the job's tree before the launch, else the harness refuses rc 2 on a stale binary (jobs 1109 and 1110 were buried so at 20:31Z: the root sat
        # at b09977688 while the jobs named eedd882b7). The sync takes the fetch slot, the make the compile slots and the build cache (a clean tree fetches).
        need = not SCR and bool(re.fullmatch(r"[0-9a-f]{7,40}", tree or "")) and behind()
        t1 = time.time()
        held, w = GL.board_hold(need, resync, touch=lambda: c.touch(job), lock_dir=(SCR or None))
        why = why or w
        say("GRADE_TREE job=%d sync=%d waited=%ds" % (job.id, int(need), int(time.time() - t1)))
    if why is None:
        if kind == "master":
            cmd = ["bash", os.path.join(S4E, "harness", "scripts", "util_run_slot.sh"), "python3", os.path.join(S4E, "harness", "scripts", "corpus_suite_harness.py"),
                   "run", alls, os.path.join(os.path.dirname(alls), "ALL.ref"), "--lang", lang, "--modes", modes, "--partition", part]
            senv = ENV
        else:
            cmd = ["bash", os.path.join(S4E, "harness", "scripts", "util_run_slot.sh"), "bash", script] + words[1:]
            senv = dict(ENV, S4E_CHUNK=cell)
        # A PACKAGE RUNNER TAKES ONE ENTRY A RUN (S4E_CHUNK=entry:<name>; the coo measured 2026-11-07 15:2x that entry:a,b is refused by the runner's partition parse), so a
        # request cell of several entries is several runs of the runner, in order, one log; rc is the worst reading (1 if any entry read red; a refusal stops the list).
        launches = [(cmd, dict(ENV, S4E_CHUNK="entry:" + e)) for e in entries] if kind != "master" and len(entries) > 1 else [(cmd, senv)]
        d = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT", "grade"), "grade"); os.makedirs(d, exist_ok=True)
        res_path = ENV.get("S4E_RESULTS", LIVE_PROG + "/results.tsv")
        snap = os.path.join(d, "job.%d.snap.tsv" % job.id)
        if os.path.isfile(res_path): shutil.copyfile(res_path, snap)
        else: snap = ""
        rc = 0
        with open(os.path.join(d, "job.%d.log" % job.id), "ab") as out:
            for lcmd, lenv in launches:
                if len(launches) > 1: out.write(("GRADE_ENTRY %s\n" % lenv.get("S4E_CHUNK", "")).encode()); out.flush()
                p = subprocess.Popen(lcmd, cwd=S4E, env=lenv, stdout=out, stderr=subprocess.STDOUT)
                last = time.time()
                while p.poll() is None:
                    time.sleep(1)
                    if time.time() - last >= 60:
                        try: c.touch(job); last = time.time()
                        except Exception as e: say("GRADE_LEASE job=%d touch failed: %s" % (job.id, e))
                rc = p.returncode if p.returncode not in (0, 1) else max(rc, p.returncode)
                if rc not in (0, 1): break
        why = None if rc in (0, 1) else "rc=%d from the harness launch" % rc
        if rc in (0, 1) and kind != "master":
            try: pvd = move_request(suite, lang, entries, pri, requester, tree)
            except Exception as e: pvd = 0; say("RECORD job=%d package request not moved: %s" % (job.id, e))
            say("RECORD job=%d key=- suite_row=0 verdict=%d scratch=0 reason=package runner writes its own rows; the request moves to done/ here" % (job.id, pvd))
        elif rc in (0, 1):
            if SCR or os.environ.get("S4E_PROGRESS_OFF") != "1":
                try: sr, vd, sc, wy = record(lang, entries, pri, requester, tree)
                except Exception as e: sr, vd, sc, wy = 0, 0, int(bool(SCR)), "record refused: %s" % e
                say("RECORD job=%d key=%s suite_row=%d verdict=%d scratch=%d reason=%s" % (job.id, CONTAINER.get(lang, "-"), sr, vd, sc, wy or "-"))
                try:
                    ga = subprocess.run(["bash", LIB, "grade_cell_after", progress_name(CONTAINER[lang]), tree, BAND.get(pri, "other"), snap, str(int(time.time() - t0))] + entries,
                                        cwd=S4E, env=ENV, capture_output=True, text=True, timeout=900)
                    say((ga.stdout.strip().splitlines() or ["GRADE_CELL_AFTER no output"])[-1] + (" rc=%d" % ga.returncode if ga.returncode else ""))
                except Exception as e: say("GRADE_CELL_AFTER refused: %s" % e)
                if snap and os.path.isfile(snap): os.remove(snap)
            else: say("RECORD job=%d key=- suite_row=0 verdict=0 scratch=0 reason=progress off, nothing recorded" % job.id)
    GL.leave(held)
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
