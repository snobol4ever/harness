#!/usr/bin/env bash
# test_gate_seat_census_reads_the_grader_rate_and_the_acceptance_from_the_ledgers.sh -- ARCH-SHARED-DEVELOPMENT steps 5 and 9 (the cto, the fleet
# test, 2026-11-01; R-2041/2094). util_seat_census.py --grader-rate and --acceptance are DONE-WHENs read from the ledgers, so each arm plants
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
# the per-seat /tmp budget in the banner (ARCH-SHARED-DEVELOPMENT 2.3 /tmp move (2); the coo 2026-11-01, R-2095's admin backlog item 2): one LOAD run, seat a at 5000 MB, seat b at 10 MB
mkdir -p "$T/tmpb"; u=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf 'utc\tkind\tclass\tname\tcores\tmem_mb\tmem_peak_mb\toom_kills\tpids\tcc_slots\trun_slots\ttmp_mb\n%s\tUNIT\tSEAT\ta\t1.00\t500\t600\t0\t10\t0\t1\t5000\n%s\tUNIT\tSEAT\tb\t1.00\t500\t600\t0\t10\t0\t1\t10\n%s\tBOX\tBOX\tbox\tcores_busy=3.0 pressure_some_avg60=1.0\t-\t-\t-\t-\t-\t-\t-\n' "$u" "$u" "$u" > "$T/tmpb/LOAD.tsv"
barm() {   # barm <name> <seat> <want_text>: the banner line for one seat of the planted run
  local out; n=$((n + 1)); out="$(python3 -I "$CENSUS" banner "$2" --load "$T/tmpb/LOAD.tsv" 2>&1)"
  if printf '%s' "$out" | grep -q -- "$3"; then echo "  ok   ARM $n: $1"; else echo "  RED  ARM $n: $1 -- looking for '$3' in: $out"; fail=1; fi
}
barm "the banner shows a seat its /tmp against the 4 GB per-seat budget"        b "tmp 0.0G/4G cc"
barm "FAIL-ONCE: a seat at 5000 MB of /tmp reads OVER its budget in the banner" a "tmp 4.9G/4G OVER cc"
# THE HEALTH CHECK'S OWN CHECK (the coo 2026-11-01, Lon: "why did you not catch this when I asked you to do a health check? fix that health check" / "Add a
# health check to your health check"): --check read GREEN on a box at 16/16 cores and pressure 41 because no arm read CPU. These arms plant one LOAD run
# per case and prove --cpu-check reds by name on each condition, stays GREEN on a busy but healthy box, and that --health runs all three checks.
cpuplant() {   # cpuplant <dir> <busy> <p300> <run_held> <cc_held> <seat_a_cores> <seat_a_run> <grader_cores>
  mkdir -p "$1"; local u; u=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  { printf 'utc\tkind\tclass\tname\tcores\tmem_mb\tmem_peak_mb\toom_kills\tpids\tcc_slots\trun_slots\ttmp_mb\n'
    printf '%s\tUNIT\tSEAT\ta\t%s\t500\t600\t0\t10\t0\t%s\t10\n' "$u" "$6" "$7"
    printf '%s\tUNIT\tSEAT\tb\t1.00\t500\t600\t0\t10\t0\t1\t10\n' "$u"
    printf '%s\tCLASS\tGRADER\tgrader\t%s\t-\t-\t-\t-\t-\t-\t-\n' "$u" "$8"
    printf '%s\tBOX\tBOX\tbox\tcores_busy=%s load1=20 pressure_some_avg60=%s pressure_some_avg300=%s run_held=%s cc_held=%s\t-\t-\t-\t-\t-\t-\t-\n' "$u" "$2" "$3" "$3" "$4" "$5"; } > "$1/LOAD.tsv"
}
carm() {   # carm <name> <dir> <want_rc> <must_match> [must_not_match]
  local out; n=$((n + 1)); out="$(python3 -I "$CENSUS" --cpu-check --load "$2/LOAD.tsv" --root "$2/cg" --seats "$2/SEATS.tsv" 2>&1)"; local rc=$?
  if [ "$rc" = "$3" ] && printf '%s' "$out" | grep -q -- "$4" && { [ -z "${5:-}" ] || ! printf '%s' "$out" | grep -q -- "$5"; }; then echo "  ok   ARM $n: $1"
  else echo "  RED  ARM $n: $1 -- rc $rc wanted $3, looking for '$4':"; printf '%s\n' "$out" | sed 's/^/         /' | head -6; fail=1; fi
}
NC=$(python3 -c 'import os; print(os.cpu_count() or 16)')
cpuplant "$T/cpu_sat"  "$NC" 41 2 0 3.90 0 0.50
cpuplant "$T/cpu_ok"   "$NC" 10 8 4 1.80 0 2.50
cpuplant "$T/cpu_seat" 4     10 1 0 3.90 0 2.50
cpuplant "$T/cpu_pool" 4     10 1 0 3.90 2 2.50
cgwait() {   # cgwait <dir> <grader_avg300> [lon_avg300]: the grader slice's (and a LON scope's) cpu.pressure under <dir>/cg, and a SEATS fixture mapping lon
  mkdir -p "$1/cg/user@1000.service/s4e.slice/s4e-grader.slice" "$1/cg/lonscope"
  printf 'some avg10=%s avg60=%s avg300=%s total=1\nfull avg10=0 avg60=0 avg300=0 total=0\n' "$2" "$2" "$2" > "$1/cg/user@1000.service/s4e.slice/s4e-grader.slice/cpu.pressure"
  printf 'utc\tseat\tclass\tscope\tpid\tstart\tweighted\n' > "$1/SEATS.tsv"
  if [ -n "${3:-}" ]; then printf 'some avg10=%s avg60=%s avg300=%s total=1\n' "$3" "$3" "$3" > "$1/cg/lonscope/cpu.pressure"; printf 'x\tlon\tLON\t/user.slice/user-1000.slice/lonscope\t1\tx\tyes\n' >> "$1/SEATS.tsv"; fi
}
cpuplant "$T/cpu_lowdem" "$NC" 41 2 0 1.00 0 0.50
cgwait "$T/cpu_sat" 40.00 25.00; cgwait "$T/cpu_lowdem" 0.20; cgwait "$T/cpu_ok" 0.10 1.00; cgwait "$T/cpu_seat" 0.10; cgwait "$T/cpu_pool" 0.10
carm "FAIL-ONCE: a saturated box reds on cpu pressure"                                        "$T/cpu_sat"  1 "cpu pressure some avg300 41.0"
carm "FAIL-ONCE: a busy box with idle pools reds as load OUTSIDE the doors"                   "$T/cpu_sat"  1 "the load runs OUTSIDE the doors"
carm "FAIL-ONCE: a seat over 2 cores holding no slot is red BY NAME"                          "$T/cpu_seat" 1 "seat a runs 3.90 cores holding no run slot"
carm "FAIL-ONCE: the grader under 2 cores on a busy box reds"                                 "$T/cpu_sat"  1 "the grader reads 0.50 cores"
carm "FAIL-ONCE: Lon's terminal waiting 25 percent for a CPU reds by name"                  "$T/cpu_sat"  1 "Lon's terminal (lon) waited for a CPU 25.0 percent"
carm "control: the grader under 2 cores that waited 0.2 percent is its own demand, not red" "$T/cpu_lowdem" 1 "cpu pressure some avg300" "the grader reads"
carm "control: a busy box whose load is in the pools, the grader at 2.5, reads GREEN"         "$T/cpu_ok"   0 "GREEN cpu pressure under 30" "RED"
carm "control: a seat over 2 cores THROUGH the pools (2 run slots) is not named"              "$T/cpu_pool" 0 "GREEN" "seat a runs"
n=$((n + 1)); if grep -q 'for fn in (check, memory_check, cpu_check' "$CENSUS" && grep -q '"--health"' "$CENSUS"; then echo "  ok   ARM $n: --health runs --check, --memory-check and --cpu-check and returns the worst"; else echo "  RED  ARM $n: --health does not run all three arms"; fail=1; fi
tmpplant() {   # tmpplant <dir> <seat_a_tmp_mb> <seat_b_tmp_mb>
  mkdir -p "$1"; local u; u=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  { printf 'utc\tkind\tclass\tname\tcores\tmem_mb\tmem_peak_mb\toom_kills\tpids\tcc_slots\trun_slots\ttmp_mb\n'
    printf '%s\tUNIT\tSEAT\ta\t0.50\t500\t600\t0\t10\t0\t0\t%s\n' "$u" "$2"
    printf '%s\tUNIT\tSEAT\tb\t0.50\t500\t600\t0\t10\t0\t0\t%s\n' "$u" "$3"; } > "$1/LOAD.tsv"
}
tarm() {   # tarm <name> <dir> <want_rc> <must_match> [must_not_match]
  local out; n=$((n + 1)); out="$(python3 -I "$CENSUS" --tmp-check --load "$2/LOAD.tsv" 2>&1)"; local rc=$?
  if [ "$rc" = "$3" ] && printf '%s' "$out" | grep -q -- "$4" && { [ -z "${5:-}" ] || ! printf '%s' "$out" | grep -q -- "$5"; }; then echo "  ok   ARM $n: $1"
  else echo "  RED  ARM $n: $1 -- rc $rc wanted $3, looking for '$4':"; printf '%s\n' "$out" | sed 's/^/         /' | head -6; fail=1; fi
}
tmpplant "$T/tmp_over" 19968 5000
tmpplant "$T/tmp_ok"   3000  100
tarm "FAIL-ONCE: a seat over its /tmp budget is red BY NAME with its size"          "$T/tmp_over" 1 "seat a holds 19.5G of /tmp"
tarm "FAIL-ONCE: the largest holder is named first"                                  "$T/tmp_over" 1 "RED  seat a holds"
tarm "control: seats within budget read GREEN and nobody is named"                   "$T/tmp_ok"   0 "GREEN every seat" "RED"
n=$((n + 1)); if grep -q 'for fn in (check, memory_check, cpu_check, tmp_check' "$CENSUS"; then echo "  ok   ARM $n: --health runs the /tmp arm too"; else echo "  RED  ARM $n: --health does not run --tmp-check"; fail=1; fi
# THE PROCESS AND MEMORY ARMS (the coo 2026-11-01, Lon: "So does you periodic check look for orphans and such so it can find this problem sooner rather than
# later?"): planted ps lists, cgroup trees and pressure files prove --proc-check names an orphaned fleet run by seat, a stalled box and a throttled scope,
# and leaves a young orphan, a standing daemon and a child with a live parent alone.
procplant() {   # procplant <dir> <orphan_age_s> <scope_a_mb> <mem_avg60> [scope_a_anon_mb] -- scope a's memory.stat: anon (default all but 200 MB) and file the rest
  local cg="$1/cg/user@1000.service/app.slice/app-org.gnome.Terminal.slice" sl="0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Terminal.slice"
  mkdir -p "$cg/vte-a.scope" "$cg/vte-b.scope"
  echo $(( $3 * 1048576 )) > "$cg/vte-a.scope/memory.current"; echo $(( 4096 * 1048576 )) > "$cg/vte-a.scope/memory.high"
  local an="${5:-$(( $3 - 200 ))}"; printf 'anon %s\nfile %s\nkernel 0\n' $(( an * 1048576 )) $(( ($3 - an) * 1048576 )) > "$cg/vte-a.scope/memory.stat"
  echo $(( 1000 * 1048576 )) > "$cg/vte-b.scope/memory.current"; echo $(( 4096 * 1048576 )) > "$cg/vte-b.scope/memory.high"
  printf 'some avg10=%s avg60=%s avg300=%s total=1\nfull avg10=0 avg60=0 avg300=0 total=0\n' "$4" "$4" "$4" > "$1/pmem"
  { printf 'utc\tseat\tclass\tscope\tpid\tstart\tweighted\n'
    printf 'x\ta\tSEAT\t/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Terminal.slice/vte-a.scope\t1\tx\tyes\n'
    printf 'x\tb\tSEAT\t/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Terminal.slice/vte-b.scope\t1\tx\tyes\n'; } > "$1/SEATS.tsv"
  { echo "2575 1 99999 9000 0::/user.slice/user-1000.slice/user@1000.service/init.scope /usr/lib/systemd/systemd --user"
    echo "500 2575 $2 1572864 $sl/vte-a.scope timeout -k 10 1500 python3 /home/claude_a/harness/scripts/corpus_suite_harness.py smoke nl write"
    echo "510 2575 60 2000 $sl/vte-b.scope /home/claude_b/SCRIP/scrip --run young.pl"
    echo "520 2575 99999 4000 0::/user.slice/user-1000.slice/user@1000.service/s4e.slice/s4e-grader.slice/run-x.scope bash loop8.sh"
    echo "530 500 $2 9000 $sl/vte-a.scope /home/claude_a/SCRIP/scrip --run child.pl"
    echo "540 2575 $2 14000 $sl/vte-b.scope ugrep -G -rnoiE officer corpus"
    echo "560 2575 $2 4000 $sl/vte-a.scope ssh: /home/x/.ssh/cm-git@github.com-22 [mux]"
    echo "570 2575 $2 1000 $sl/vte-a.scope xclip -selection clipboard"
    echo "580 2575 $2 3000 $sl/vte-a.scope /usr/bin/bash /home/claude_cto/harness/scripts/util_jobserver.sh hold 8"
    echo "550 2575 $2 30000 0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Nautilus.slice/app.scope /usr/bin/nautilus --gapplication-service"
    echo "590 2575 59280 256000 $sl/vte-a.scope /usr/libexec/gnome-terminal-server"
    echo "600 2575 $2 900000 $sl/vte-b.scope claude --name B --model claude-haiku-5-5 --effort xhigh"
    echo "610 2575 $2 500000 $sl/vte-a.scope /usr/bin/gnome-shell"
    echo "620 2575 $2 12000 $sl/vte-a.scope python3 /home/claude_a/harness/scripts/util_queue.py reserve-hold seat-a,ask-haiku,tier-haiku --seat a --session A --claim-dir /x/claims --baton-dir /x/tasks --timeout 0"; } > "$1/ps.txt"
}
parm() {   # parm <name> <dir> <want_rc> <must_match> [must_not_match]
  local out; n=$((n + 1)); out="$(python3 -I "$CENSUS" --proc-check --ps "$2/ps.txt" --root "$2/cg" --seats "$2/SEATS.tsv" --pressure-memory "$2/pmem" 2>&1)"; local rc=$?
  if [ "$rc" = "$3" ] && printf '%s' "$out" | grep -q -- "$4" && { [ -z "${5:-}" ] || ! printf '%s' "$out" | grep -q -- "$5"; }; then echo "  ok   ARM $n: $1"
  else echo "  RED  ARM $n: $1 -- rc $rc wanted $3, looking for '$4':"; printf '%s\n' "$out" | sed 's/^/         /' | head -6; fail=1; fi
}
procplant "$T/proc_bad" 1500 3900 37.50
procplant "$T/proc_ok"  1500 1000 0.50; sed -i '/^5[04]0 /d' "$T/proc_ok/ps.txt"
procplant "$T/proc_young" 240 1000 0.50
procplant "$T/proc_cache" 1500 3900 0.50 300; sed -i '/^5[04]0 /d' "$T/proc_cache/ps.txt"
parm "FAIL-ONCE: a fleet run orphaned to the user manager 25 min is red BY SEAT"           "$T/proc_bad"   1 "orphan pid 500 of seat a, 25 min old, 1536 MB"
parm "FAIL-ONCE: box memory pressure 37.5 over a minute is red"                             "$T/proc_bad"   1 "box memory pressure some avg60 37.5"
parm "FAIL-ONCE: a seat scope at 3900 of 4096 MB memory.high by its own anon (3700 MB) is red BY SEAT" "$T/proc_bad" 1 "seat a's scope holds 3900 of its 4096 MB memory.high, anon=3700MB file=200MB"
parm "box-budget step 7: the same 3900 MB held by file pages (anon 300 MB) is RECLAIMED, never alarmed" "$T/proc_cache" 0 "RECLAIMED seat a: its scope held 3900 of its 4096 MB memory.high by file pages (anon=300MB file=3600MB); asked the kernel for 828 MB of file pages: ok" "RED"
n=$((n + 1)); rq="$(cat "$T/proc_cache/cg/user@1000.service/app.slice/app-org.gnome.Terminal.slice/vte-a.scope/memory.reclaim" 2>/dev/null)"
if [ "$rq" = "$(( 828 * 1048576 )) swappiness=0" ]; then echo "  ok   ARM $n: the reclaim asks for file pages only, down to 75 percent of memory.high (memory.reclaim '$rq')"; else echo "  RED  ARM $n: memory.reclaim reads '$rq', not '$(( 828 * 1048576 )) swappiness=0'"; fail=1; fi
n=$((n + 1)); [ -e "$T/proc_bad/cg/user@1000.service/app.slice/app-org.gnome.Terminal.slice/vte-a.scope/memory.reclaim" ] && { echo "  RED  ARM $n: an anon-held scope was reclaimed (that would swap its own memory)"; fail=1; } || echo "  ok   ARM $n: an anon-held scope is alarmed, never reclaimed"
n=$((n + 1)); out="$(python3 -I "$CENSUS" --memory-check --root "$T/proc_cache/cg" --seats "$T/proc_cache/SEATS.tsv" --load "$T/none.tsv" 2>&1)"
if printf '%s\n' "$out" | grep -F "  seat a scope cur=3900MB high=4096MB anon=300MB file=3600MB" >/dev/null && printf '%s\n' "$out" | grep -E 'anon=[0-9]+MB file=[0-9]+MB' >/dev/null; then echo "  ok   ARM $n: --memory-check prints each seat scope's anon against its file pages (the step-7 probe)"; else echo "  RED  ARM $n: --memory-check has no anon/file line: $(printf '%s' "$out" | head -3 | tr '\n' '|')"; fail=1; fi
parm "COO-461 FAIL-ONCE: any process of a seat scope orphaned 25 min is red BY SEAT, its command no fleet word (the cao's ugrep)" "$T/proc_bad" 1 "orphan pid 540 of seat b, 25 min old"
parm "control: a child whose parent lives, a standing daemon, a young orphan, a desktop app outside every seat scope, the git ssh mux, the clipboard holder and the jobserver holder are not named" "$T/proc_bad" 1 "orphans=2 " "pid 5[1235678]0"
parm "the coo 2026-11-06 09:02 (the 1836707 false positive): the session HOSTS in a seat's unit -- gnome-terminal-server 988 min old, a claude session, gnome-shell -- are never named, by path" "$T/proc_bad" 1 "orphans=2 " "pid \(590\|600\|610\)"
parm "fleet-queue 5: the lease holder a seat's next detached (util_queue.py reserve-hold, 25 min old) is a standing daemon, never an orphan (killing it releases the job)" "$T/proc_bad" 1 "orphans=2 " "pid 620"
parm "control: an orphan under five minutes is not named"                                    "$T/proc_young" 0 "GREEN no orphaned" "orphan pid"
parm "control: no orphan, calm memory, scopes under 90 percent read GREEN"                  "$T/proc_ok"    0 "GREEN no orphaned" "RED"
n=$((n + 1)); if grep -q 'tmp_check, proc_check' "$CENSUS"; then echo "  ok   ARM $n: --health runs the process and memory arm too"; else echo "  RED  ARM $n: --health does not run --proc-check"; fail=1; fi
# THE HEALTH CHECK OF THE HEALTH CHECK (Lon 2026-11-01: "add a health check to the healt check script"): --watch-check reds when a watcher is gone or stale.
watchplant() {   # watchplant <dir> <fleet_last_age_s> <with_tier1:1|0> [STOPfile]
  mkdir -p "$1/v"; echo $(( $(date +%s) - $2 )) > "$1/v/fleet.last"; [ -n "${4:-}" ] && touch "$1/v/$4"
  { echo "2575 1 99999 9000 0::/x /usr/lib/systemd/systemd --user"; echo "600 2575 99999 4000 0::/x bash loop8.sh"; echo "601 2575 99999 4000 0::/x /usr/bin/bash seatwatch.sh"
    [ "$3" = 1 ] && echo "602 2575 99999 4000 0::/x /usr/bin/bash tier1.sh"; } > "$1/ps.txt"
}
warm() {   # warm <name> <dir> <want_rc> <must_match> [must_not_match]
  local out; n=$((n + 1)); out="$(python3 -I "$CENSUS" --watch-check --ps "$2/ps.txt" --verifier-dir "$2/v" 2>&1)"; local rc=$?
  if [ "$rc" = "$3" ] && printf '%s' "$out" | grep -q -- "$4" && { [ -z "${5:-}" ] || ! printf '%s' "$out" | grep -q -- "$5"; }; then echo "  ok   ARM $n: $1"
  else echo "  RED  ARM $n: $1 -- rc $rc wanted $3, looking for '$4':"; printf '%s\n' "$out" | sed 's/^/         /' | head -6; fail=1; fi
}
watchplant "$T/w_dead"  60 0; watchplant "$T/w_stale" 1800 1; watchplant "$T/w_ok" 60 1; watchplant "$T/w_stop" 60 0 STOP1
warm "FAIL-ONCE: tier1 (the fleet watch) with no process and no STOP1 is red by name" "$T/w_dead"  1 "tier1 and its fleet watch is NOT RUNNING"
warm "FAIL-ONCE: a fleet watch whose last pass is 30 min old is red"                "$T/w_stale" 1 "last pass is 30 min old"
warm "control: every watcher running and a fresh pass read GREEN"                    "$T/w_ok"    0 "GREEN the loop" "RED"
warm "control: a watcher stopped on purpose (its STOP file) is not red"              "$T/w_stop"  0 "GREEN the loop" "RED"
n=$((n + 1)); if grep -q 'proc_check, watch_check)' "$CENSUS"; then echo "  ok   ARM $n: --health runs the watch arm too"; else echo "  RED  ARM $n: --health does not run --watch-check"; fail=1; fi
if [ "$fail" = 0 ]; then echo "GATE PASS(0) [$G]: $n arms -- the two DONE-WHENs read the ledgers, red by name on each planted defect, refused when the box was not busy; the banner shows the per-seat /tmp budget; the CPU arm of the health check reds by name on each condition and --health runs all six (the watchers themselves checked); the /tmp arm names each seat over its budget; the process arm names an orphaned run, a stalled box and a throttled scope"; exit 0
else echo "GATE FAIL(1) [$G]: see the RED arms"; exit 1; fi
