#!/usr/bin/env bash
# s4e_probe_grade_a_job_the_root_lacks_runs_in_a_worker_worktree.sh -- THE PROBE of row grading-a-job-the-root-lacks-is-graded-in-a-request-worktree-with-no-root-lock (senior_06,
# from officer_05's design of 19:46 CST and his rulings of 20:2x: a pool of 2 request worktrees taken by flock, the default sparse corpus, a real make on a cache miss, the
# launch in the worktree and the record on the root). MEASURED: a job whose tree the grader root does not contain took root.lock EXCLUSIVE and waited for every shared
# holder, so one hanging board stopped every request behind it. Two seams in lib_grade_locks.py, proved on scratch git repos and a scratch lock dir: pool_take(names, lock_dir,
# wait) takes the flock of the first free pool name and returns (name, fd), or (None, None) when none is free and wait is false; move_worktree(wt, tree) moves a worktree of the
# four repos so SCRIP is at the job's tree and harness, corpus and .github at origin/main as the root last fetched it, and returns the repos that failed. And the grade worker
# must call both and name the pool worktrees wt-req-. One line: GRADE_POOL takes=0|1 second=0|1 none_when_full=0|1 retake=0|1 moved=0|1 wired=0|1 ok=0|1 (each 1 when it
# reads as said). rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
SC="$S4E/harness/scripts"
[ -f "$SC/lib_grade_locks.py" ] && [ -f "$SC/s4e_grade_worker.sh" ] || { echo "REFUSE(2): no lib_grade_locks.py or s4e_grade_worker.sh under $SC"; exit 2; }
t="$(mktemp -d "/tmp/s4e/$ME/gr_pool.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/wt" "$t/locks"
for r in SCRIP harness corpus .github; do
    g() { git -C "$t/src-$r" -c user.name=probe -c user.email=probe@localhost "$@"; }
    mkdir -p "$t/src-$r" && git -C "$t/src-$r" init -q . && git -C "$t/src-$r" checkout -q -b main 2>/dev/null
    for i in 1 2 3; do printf '%s\n' "$i" > "$t/src-$r/f"; g add f; g commit -q -m "c$i"; done
    g update-ref refs/remotes/origin/main HEAD
    g worktree add -q --detach "$t/wt/$r" HEAD~2 || { echo "REFUSE(2): could not make the scratch worktree of $r"; exit 2; }
done
c2="$(git -C "$t/src-SCRIP" rev-parse --short=9 HEAD~1)"; c3="$(git -C "$t/src-harness" rev-parse HEAD)"
r="$(python3 -I - "$SC" "$t" "$c2" <<'PY'
import sys, os, subprocess
sys.path.insert(0, sys.argv[1])
t, c2 = sys.argv[2], sys.argv[3]
out = [0, 0, 0, 0, 0]
try:
    import lib_grade_locks as GL
    L = os.path.join(t, "locks"); names = ["req-1", "req-2"]
    n1, f1 = GL.pool_take(names, L, wait=False); out[0] = int(n1 == "req-1")
    n2, f2 = GL.pool_take(names, L, wait=False); out[1] = int(n2 == "req-2")
    n3, f3 = GL.pool_take(names, L, wait=False); out[2] = int(n3 is None and f3 is None)
    GL.leave(f1)
    n4, f4 = GL.pool_take(names, L, wait=False); out[3] = int(n4 == "req-1")
    GL.leave(f4); GL.leave(f2)
    bad = GL.move_worktree(os.path.join(t, "wt"), c2)
    head = lambda r: subprocess.run(["git", "-C", os.path.join(t, "wt", r), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    sc = head("SCRIP"); full = subprocess.run(["git", "-C", os.path.join(t, "src-SCRIP"), "rev-parse", c2], capture_output=True, text=True).stdout.strip()
    others = all(head(r) == subprocess.run(["git", "-C", os.path.join(t, "src-" + r), "rev-parse", "origin/main"], capture_output=True, text=True).stdout.strip() for r in ("harness", "corpus", ".github"))
    out[4] = int(bad == [] and sc == full and others)
except Exception:
    pass
print(*out)
PY
)"
set -- $r; tk="$1"; sc="$2"; nf="$3"; rt="$4"; mv="$5"
wr=0; grep -q 'GL\.pool_take(' "$SC/s4e_grade_worker.sh" && grep -q 'GL\.move_worktree(' "$SC/s4e_grade_worker.sh" && grep -q 'wt-' "$SC/s4e_grade_worker.sh" && wr=1
ok=0; [ "$tk$sc$nf$rt$mv$wr" = 111111 ] && ok=1
echo "GRADE_POOL takes=$tk second=$sc none_when_full=$nf retake=$rt moved=$mv wired=$wr ok=$ok"
[ "$ok" = 1 ]
