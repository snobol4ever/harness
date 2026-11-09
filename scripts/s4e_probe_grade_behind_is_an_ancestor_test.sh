#!/usr/bin/env bash
# s4e_probe_grade_behind_is_an_ancestor_test.sh -- THE PROBE of row grading-behind-is-a-merge-base-ancestor-test (senior_06, from officer_05's design of 19:46 CST on the coo's
# telegrams of 19:33 and 19:45: 24 requests pending and 0 served in 15 to 30 minutes because a job whose tree the grader root already carries was still sent into the
# EXCLUSIVE sync: behind() read the root's SCRIP HEAD and the job's tree as hash prefixes and called the job behind whenever they DIFFER). On a scratch git repo with
# three commits (HEAD the third) and a side-branch commit that is not an ancestor of HEAD, lib_grade_locks.tree_behind(scrip_dir, tree) must answer: an older commit
# of the root is NOT behind, the root's own HEAD is NOT behind, an object the repo does not have IS behind, a commit not contained in HEAD IS behind; and the grade
# worker's behind() must call it. One line: GRADE_BEHIND older=0|1 equal=0|1 unknown=0|1 diverged=0|1 wired=0|1 ok=0|1 (each 1 when it reads as said). rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
SC="$S4E/harness/scripts"
[ -f "$SC/lib_grade_locks.py" ] && [ -f "$SC/s4e_grade_worker.sh" ] || { echo "REFUSE(2): no lib_grade_locks.py or s4e_grade_worker.sh under $SC"; exit 2; }
t="$(mktemp -d "/tmp/s4e/$ME/gr_behind.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$t"' EXIT
g() { git -C "$t" -c user.name=probe -c user.email=probe@localhost "$@"; }
g init -q -b main . 2>/dev/null || { g init -q . && g checkout -q -b main; }
for i in 1 2 3; do printf '%s\n' "$i" > "$t/f"; g add f; g commit -q -m "c$i"; done
c1="$(g rev-parse --short=9 HEAD~2)"; c3="$(g rev-parse --short=9 HEAD)"
g checkout -q -b side "HEAD~2"; printf 'side\n' > "$t/s"; g add s; g commit -q -m side; d="$(g rev-parse --short=9 HEAD)"; g checkout -q main
[ "$(g rev-parse --short=9 HEAD)" = "$c3" ] || { echo "REFUSE(2): the scratch repo is not at its third commit"; exit 2; }
r="$(python3 -I - "$SC" "$t" "$c1" "$c3" "$d" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
try:
    import lib_grade_locks as GL
    b = GL.tree_behind
    root, c1, c3, d = sys.argv[2:6]
    print(int(b(root, c1) is False), int(b(root, c3) is False), int(b(root, "deadbeef0") is True), int(b(root, d) is True))
except Exception:
    print("0 0 0 0")
PY
)"
set -- $r; ol="$1"; eq="$2"; un="$3"; dv="$4"
wr=0; grep -q 'GL\.tree_behind(' "$SC/s4e_grade_worker.sh" && ! grep -q 'startswith(tree\[:7\])' "$SC/s4e_grade_worker.sh" && wr=1
ok=0; [ "$ol$eq$un$dv$wr" = 11111 ] && ok=1
echo "GRADE_BEHIND older=$ol equal=$eq unknown=$un diverged=$dv wired=$wr ok=$ok"
[ "$ok" = 1 ]
