#!/usr/bin/env bash
# test_gate_seat_census_reads_the_grader_rate_and_the_acceptance_from_the_ledgers.sh -- ARCH-SHARED-DEVELOPMENT steps 5 and 9 (the cto, the fleet
# test, 2026-11-01; CEO-2041/2094). util_seat_census.py --grader-rate and --acceptance are DONE-WHENs read from the ledgers, so each arm plants
# ledgers under a scratch directory (--load --results --waits --builds --repos) and reads the verdict: GREEN on the planted good day, RED naming
# the one planted defect (the grader slow, a seat hogging while another waited, pressure high, builds compiled not fetched, landings too few), and
# REFUSE(2) when the box was not busy or not for long enough -- a rate under no contention measures nothing. Hermetic: no cgroup, no real ledger.
# rc 0 every arm as expected; rc 1 an arm read the wrong verdict; rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; G=seat_census_reads_the_grader_rate_and_the_acceptance_from_the_ledgers
CENSUS="$HERE/util_seat_census.py"; [ -f "$CENSUS" ] && command -v python3 >/dev/null && command -v git >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: util_seat_census.py, python3 or git absent"; exit 2; }
T=$(mktemp -d /tmp/s4e-census-gate.XXXXXX); trap 'rm -rf "$T"' EXIT
plant() {   # plant <dir> <programs> <busy> <grader> <seat_a_cores> <wait_by_b 0|1> <pressure> <fetched> <built> <commits> <busy_runs_of_24>
python3 -I - "$@" <<'PY'
import sys, os, time, subprocess
d, progs, busy, grader, a_cores, wait_b, pressure, fetched, built, commits, busy_runs = sys.argv[1], int(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), int(sys.argv[6]), float(sys.argv[7]), int(sys.argv[8]), int(sys.argv[9]), int(sys.argv[10]), int(sys.argv[11])
os.makedirs(d, exist_ok=True); now = int(time.time())
st = lambda s: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(s))
L = ["\t".join(["utc", "kind", "class", "name", "cores", "mem_mb", "mem_peak_mb", "oom_kills", "pids", "cc_slots", "run_slots", "tmp_mb"])]
for k in range(24):
    u = st(now - 60 - k * 300); b = busy if k < busy_runs else 3.0
    L.append("\t".join([u, "UNIT", "SEAT", "a", "%.2f" % a_cores, "500", "600", "0", "10", "0", "1", "10"]))
    L.append("\t".join([u, "UNIT", "SEAT", "b", "1.00", "500", "600", "0", "10", "0", "1", "10"]))
    L.append("\t".join([u, "CLASS", "GRADER", "grader", "%.2f" % grader, "-", "-", "-", "-", "-", "-", "-"]))
    L.append("\t".join([u, "APP", "APP", "app.slice", "%.2f" % (a_cores + 1), "-", "-", "-", "-", "-", "-", "-"]))
    L.append("\t".join([u, "BOX", "BOX", "box", "cores_busy=%.1f load1=1 pressure_some_avg60=%.1f pressure_some_avg300=%.1f mem_available_mb=9000 swap_used_mb=0 tmp_pct=10 cc_held=0 run_held=0 slice_held=0 builds_fetched=0 compiles=0 checks_hit=- oracle_hit=0/0" % (b, pressure, pressure), "-", "-", "-", "-", "-", "-", "-"]))
open(d + "/LOAD.tsv", "w").write("\n".join(L) + "\n")
R = ["\t".join(["ts_utc", "scrip", "corpus", "measurer", "class", "suite", "lang", "program", "mode", "outcome", "secs", "note", "fingerprint", "config"])]
for i in range(progs):
    R.append("\t".join([time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now - 100 - (i * 7000 // max(1, progs)))), "abc", "def", "coo", "rungs", "x-rungs", "x", "p%d" % i, "m3", "PASS", "0.1", "-", "0", "partition=entry:p%d,rr=1" % i]))
open(d + "/results.tsv", "w").write("\n".join(R) + "\n")
W = ["# at_utc\tseat\tkind\twait_s\tcmd"] + (["\t".join([st(now - 60 - k * 300 + 30), "b", "run", "7.0", "scrip"]) for k in range(24)] if wait_b else [])
open(d + "/SLOT_WAITS.tsv", "w").write("\n".join(W) + "\n")
B = ["\t".join([st(now - 200 - i * 60), "a", "FETCHED", "k%d" % i, "/r"]) for i in range(fetched)] + ["\t".join([st(now - 250 - i * 60), "a", "BUILT", "k%d" % i, "/r"]) for i in range(built)]
open(d + "/BUILDS.tsv", "w").write("\n".join(B) + "\n")
r = d + "/repos/SCRIP"; os.makedirs(r, exist_ok=True)
env = dict(os.environ, GIT_AUTHOR_NAME="g", GIT_AUTHOR_EMAIL="g@x", GIT_COMMITTER_NAME="g", GIT_COMMITTER_EMAIL="g@x")
subprocess.run(["git", "-C", r, "init", "-q"], env=env, check=True)
for i in range(commits):
    open(r + "/f", "a").write("%d\n" % i); e = dict(env, GIT_AUTHOR_DATE="@%d" % (now - 120 - i * 200), GIT_COMMITTER_DATE="@%d" % (now - 120 - i * 200))
    subprocess.run(["git", "-C", r, "add", "f"], env=e, check=True); subprocess.run(["git", "-C", r, "commit", "-q", "-m", "c%d" % i], env=e, check=True)
subprocess.run(["git", "-C", r, "update-ref", "refs/remotes/origin/main", "HEAD"], env=env, check=True)
PY
}
cen() { local d="$1"; shift; python3 -I "$CENSUS" --load "$d/LOAD.tsv" --results "$d/results.tsv" --waits "$d/SLOT_WAITS.tsv" --builds "$d/BUILDS.tsv" --repos "$d/repos" "$@" 2>&1; }
fail=0; n=0
arm() {   # arm <name> <dir> <want_rc> <want_text> -- <census args>
  local name="$1" d="$2" want="$3" text="$4"; shift 5; n=$((n + 1))
  local out rc; out="$(cen "$d" "$@")"; rc=$?
  if [ "$rc" = "$want" ] && printf '%s' "$out" | grep -q -- "$text"; then echo "  ok   ARM $n: $name"
  else echo "  RED  ARM $n: $name -- rc $rc wanted $want, looking for '$text':"; printf '%s\n' "$out" | sed 's/^/         /' | head -4; fail=1; fi
}
plant "$T/good"   500 13 2.5 1.0 0 10 20 1 30 24
plant "$T/slow"   150 13 2.5 1.0 0 10 20 1 30 24
plant "$T/quiet"  500  5 2.5 1.0 0 10 20 1 30 24
plant "$T/grader" 500 13 1.0 1.0 0 10 20 1 30 24
plant "$T/hog"    500 13 2.5 5.0 1 10 20 1 30 24
plant "$T/nohog"  500 13 2.5 5.0 0 10 20 1 30 24
plant "$T/press"  500 13 2.5 1.0 0 40 20 1 30 24
plant "$T/built"  500 13 2.5 1.0 0 10  5 1 30 24
plant "$T/land"   500 13 2.5 1.0 0 10 20 1  3 24
plant "$T/short"  500 13 2.5 1.0 0 10 20 1 30  6
arm "the grader rate reads GREEN on a busy good day (500 programs in two hours)" "$T/good"   0 "GREEN the grader read" -- --grader-rate 7200
arm "FAIL-ONCE: 150 programs in two hours read RED by the number"                "$T/slow"   1 "under 200" -- --grader-rate 7200
arm "a quiet box (busy 5) REFUSES: the rate under no contention measures nothing" "$T/quiet"  2 "not busy" -- --grader-rate 7200
arm "the acceptance reads GREEN on the good day"                                 "$T/good"   0 "GREEN over 24 busy runs" -- --acceptance 7200
arm "FAIL-ONCE: the grader at 1.0 cores reads RED naming the grader"             "$T/grader" 1 "grader's mean" -- --acceptance 7200
arm "FAIL-ONCE: seat a at 5.0 cores while b waited reads RED naming a and b"     "$T/hog"    1 "a held 5.0 cores" -- --acceptance 7200
arm "seat a at 5.0 cores with nobody waiting is not a hog (control)"             "$T/nohog"  0 "GREEN over 24 busy runs" -- --acceptance 7200
arm "FAIL-ONCE: pressure 40 reads RED naming the pressure"                       "$T/press"  1 "pressure some avg300 mean" -- --acceptance 7200
arm "FAIL-ONCE: builds fetched 5 against built 1 reads RED"                      "$T/built"  1 "FETCHED 5 against BUILT 1" -- --acceptance 7200
arm "FAIL-ONCE: three landings in two hours reads RED"                           "$T/land"   1 "landings on origin/main" -- --acceptance 7200
arm "six busy runs of twenty-four REFUSES: not for long enough"                  "$T/short"  2 "busy run(s)" -- --acceptance 7200
# the per-seat /tmp budget in the banner (ARCH-SHARED-DEVELOPMENT 2.3 /tmp move (2); the coo 2026-11-01, CEO-2095's admin backlog item 2): one LOAD run, seat a at 5000 MB, seat b at 10 MB
mkdir -p "$T/tmpb"; u=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf 'utc\tkind\tclass\tname\tcores\tmem_mb\tmem_peak_mb\toom_kills\tpids\tcc_slots\trun_slots\ttmp_mb\n%s\tUNIT\tSEAT\ta\t1.00\t500\t600\t0\t10\t0\t1\t5000\n%s\tUNIT\tSEAT\tb\t1.00\t500\t600\t0\t10\t0\t1\t10\n%s\tBOX\tBOX\tbox\tcores_busy=3.0 pressure_some_avg60=1.0\t-\t-\t-\t-\t-\t-\t-\n' "$u" "$u" "$u" > "$T/tmpb/LOAD.tsv"
barm() {   # barm <name> <seat> <want_text>: the banner line for one seat of the planted run
  local out; n=$((n + 1)); out="$(python3 -I "$CENSUS" banner "$2" --load "$T/tmpb/LOAD.tsv" 2>&1)"
  if printf '%s' "$out" | grep -q -- "$3"; then echo "  ok   ARM $n: $1"; else echo "  RED  ARM $n: $1 -- looking for '$3' in: $out"; fail=1; fi
}
barm "the banner shows a seat its /tmp against the 4 GB per-seat budget"        b "tmp 0.0G/4G cc"
barm "FAIL-ONCE: a seat at 5000 MB of /tmp reads OVER its budget in the banner" a "tmp 4.9G/4G OVER cc"
if [ "$fail" = 0 ]; then echo "GATE PASS(0) [$G]: $n arms -- the two DONE-WHENs read the ledgers, red by name on each planted defect, refused when the box was not busy; the banner shows the per-seat /tmp budget"; exit 0
else echo "GATE FAIL(1) [$G]: see the RED arms"; exit 1; fi
