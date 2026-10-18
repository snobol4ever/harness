#!/usr/bin/env bash
# test_gate_timeout_under_load_is_could_not_measure_and_retried_once.sh -- A PER-PROGRAM TIMEOUT WHILE THE 1-MINUTE LOAD EXCEEDS THE
# CORES IS COULD NOT MEASURE: THE HARNESS RE-RUNS THAT ONE PROGRAM ONCE, AND ONLY A SECOND TIMEOUT GRADES HANG (ceo CEO-1335; row
# instruments-a-per-program-timeout-while-load1-exceeds-the-cores-is-could-not-measure-retried-once-serially-before-fail-and-the-
# retry-stamped-on-the-progress-row-ceo-1335; the coo 2026-10-09).
# MEASURED: at load 39 two Prolog rung entries that run in 0.1 to 0.6 s read m4 TIMEOUT under a graded run (CEO-1335's origin), and
# at load ~25 pass 42's RakBench lost point_class_add's iter angle to rc 124 the same way -- the timeout measured the scheduler.
# THE FIXTURE, under mktemp, through corpus_suite_harness.classify itself: a program that times out on its first run (it leaves a
# marker and sleeps past a 1 s timeout) and answers on its second, the load planted through lib_fanout's FANOUT_PROC seam.
#   ARM 1  load planted over the cores: the first timeout is retried, the retry PASSES, the verdict says retried=1 and both loads
#   ARM 2  FAIL-ONCE, the retry disabled (S4E_TIMEOUT_RETRY=0): the same program at the same load reads HANG
#   ARM 3  load planted under the cores: a timeout is graded HANG at once, never retried (the program ran once: one marker write)
#   ARM 4  a program that never answers, under load: retried once, HANG, and the detail says it timed out twice
#   ARM 5  the progress note of a retried verdict carries retried=1 and load1=<first>/<second> (the row's stamp)
# THE PACKAGE RUNNERS' HALF -- util_timeout_retry.sh, timeout's own argv for a runner's graded run (lib_progress.sh's $TIMEOUT_RETRY):
#   ARM 6  load over the cores, stdin a file, 2>&1: the first timeout is retried, the retry answers from the SAME stdin, only the
#          standing attempt's bytes come out in the program's own interleaving, rc 0, and a stamp line names the key and the mode
#   ARM 7  load under the cores: rc 124 at once, run once, no stamp
#   ARM 8  FAIL-ONCE, S4E_TIMEOUT_RETRY=0: plain timeout -- rc 124, run once, the first attempt's partial output stands
#   ARM 9  util_progress_append.py attaches a stamp to the row it names (m3 to m3 only, never another program), consumes the file,
#          and says aloud a stamp that names no row
#   ARM 10 test_pascal_fpc_suite.sh over a scratch suite (a program that never finishes, FPC_SUITE_RUN_TIMEOUT=1): under planted
#          load its m3 and m4 rows read FAIL timeout-at-1s carrying retried=1 ... timeout-twice; under a cool load the same rows
#          carry no retry -- the runner's graded timeouts go through the tool and its stamps reach the progress table
#   ARM 11 lib_timeout_retry.run (the Python graders' face, subprocess.run's own signature): under load the retry's result comes
#          back and a stamp names the key; under a cool load and with S4E_TIMEOUT_RETRY=0 TimeoutExpired is raised after one run
#   ARM 12 THE CENSUS (audit_bare_timeout_census.py): no runner of the population times a graded run out bare -- every guarded
#          runner of one_runner_boards.txt, test_demos_suite.sh, lib_ladder.sh and util_logtalk_grade.py; a line that is not a
#          graded unit says so with `timeout-retry: exempt -- <reason>`
#   ARM 13 FAIL-ONCE for the census: a planted runner with one bare shell timeout, one bare two-line subprocess.run(timeout=),
#          one exempt line and one echo reads exactly 2 bare, rc 1
#   ARM 14 the tool never reads a stdin its command does not: a `while read` loop over three lines that calls the tool (on a
#          command reading nothing) once per line sees all three lines -- an eager stdin buffer swallowed the roast runner's file
#          list on 2026-10-09 (its two-file fixture graded one)
# ⛔⭐ AMENDED (Lon 2026-10-15 15:3x CDT, in-chat to the coo, verbatim: "So timeout SHOULD NOT count as valid." and "The strategy should
# be to accumulate a list of timeouts, and do a retry with longer timeouts."): EVERY timeout is now retried once, whatever the load, at
# lib_timeout_retry.longer(T) -- 6 x T capped at 600 s unless T is longer -- and the stamp carries at=<limit>s. Arms 3, 7, 10 and 11
# read the cool load as retried too; arm 15 holds the three faces to one longer() (1 s -> 6 s, 300 s -> 600 s, 1000 s -> 1000 s).
# EXIT: 0 all arms pass · 1 an arm failed · 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/corpus_suite_harness.py" ] && [ -f "$HERE/lib_fanout.py" ] || { echo "GATE UNPROVEN(2): the harness or lib_fanout.py is missing"; exit 2; }
W="$(mktemp -d)" || { echo "GATE UNPROVEN(2): mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/hot" "$W/cool"
printf '999.00 999.00 999.00 9/999 1\n' > "$W/hot/loadavg"; printf '0.10 0.10 0.10 1/99 1\n' > "$W/cool/loadavg"
out="$(cd "$W" && python3 - "$HERE" "$W" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1]); w = sys.argv[2]
import corpus_suite_harness as h
def once_then_answer(d):
    os.makedirs(d, exist_ok=True)
    return ["bash", "-c", "echo run >> runs; if [ -e marker ]; then echo ok; else touch marker; sleep 5; fi"], d
def runs(d):
    return sum(1 for _ in open(os.path.join(d, "runs"))) if os.path.exists(os.path.join(d, "runs")) else 0
os.environ["FANOUT_PROC"] = w + "/hot"
a, d = once_then_answer(w + "/a1"); v = h.classify(a, 1, "ok", cwd=d)
print("ARM1", v.kind, runs(d), getattr(v, "retry", "") or "-")
os.environ["S4E_TIMEOUT_RETRY"] = "0"
a, d = once_then_answer(w + "/a2"); v = h.classify(a, 1, "ok", cwd=d)
print("ARM2", v.kind, runs(d), getattr(v, "retry", "") or "-")
del os.environ["S4E_TIMEOUT_RETRY"]
os.environ["FANOUT_PROC"] = w + "/cool"
a, d = once_then_answer(w + "/a3"); v = h.classify(a, 1, "ok", cwd=d)
print("ARM3", v.kind, runs(d), getattr(v, "retry", "") or "-")
os.environ["FANOUT_PROC"] = w + "/hot"
os.makedirs(w + "/a4", exist_ok=True)
v = h.classify(["bash", "-c", "echo run >> runs; sleep 8"], 1, "ok", cwd=w + "/a4")   # longer than the retry's limit, lib_timeout_retry.longer(1) = 6 s
print("ARM4", v.kind, runs(w + "/a4"), "twice" if "twice" in v.detail else "once", getattr(v, "retry", "") or "-")
v5 = h.Verdict("FAIL", b"x", b"", 1)
try:
    v5.retry = "retried=1 load1=31.00/12.50 nproc=16"
    print("ARM5", h._entry_note(False, v5))
except AttributeError:
    print("ARM5 a verdict carries no retry stamp")
PY
)"; rc=$?
[ "$rc" = 0 ] || { echo "GATE UNPROVEN(2): the fixture did not run (rc=$rc): $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; exit 2; }
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
l() { printf '%s\n' "$out" | grep "^$1 " | head -1; }
a1="$(l ARM1)"; a2="$(l ARM2)"; a3="$(l ARM3)"; a4="$(l ARM4)"; a5="$(l ARM5)"
echo "=== gate: a timeout under load is could-not-measure, retried once, and only a second timeout grades HANG ==="
case "$a1" in "ARM1 PASS 2 retried=1 load1=999.00/999.00 nproc="*) ck ok "load over the cores: the timeout was retried once and the retry PASSED ($a1)";; *) ck no "arm 1: $a1";; esac
case "$a2" in "ARM2 HANG 1 -") ck ok "FAIL-ONCE: with the retry disabled the same program at the same load reads HANG ($a2)";; *) ck no "arm 2: $a2";; esac
case "$a3" in "ARM3 PASS 2 retried=1 load1=0.10/0.10 nproc="*" at=6s") ck ok "load under the cores: retried too, at the longer 6 s limit, and the retry PASSED ($a3)";; *) ck no "arm 3: $a3";; esac
case "$a4" in "ARM4 HANG 2 twice retried=1"*) ck ok "a program that never answers, under load: run twice, HANG, the detail says twice";; *) ck no "arm 4: $a4";; esac
case "$a5" in *"retried=1"*"load1=31.00/12.50"*"nproc=16"*) ck ok "the progress note carries the retry stamp ($a5)";; *) ck no "arm 5: $a5";; esac
TR="$HERE/util_timeout_retry.sh"
[ -x "$TR" ] || { echo "GATE UNPROVEN(2): $TR is missing or not executable"; exit 2; }
P='read -r x; echo "in=$x"; echo err1 >&2; echo out2; echo run >> runs; if [ -e marker ]; then echo answered; else touch marker; echo partial; sleep 5; fi'
mkdir -p "$W/t6" "$W/t7" "$W/t8"
printf 'hello\n' > "$W/t6.in"
o6="$(cd "$W/t6" && FANOUT_PROC="$W/hot" S4E_TIMEOUT_STAMP="$W/t6.stamp" S4E_TIMEOUT_KEY=unit6 "$TR" 1 bash -c "$P" < "$W/t6.in" 2>&1)"; r6=$?
n6="$(wc -l < "$W/t6/runs" 2>/dev/null)"; st6="$(cat "$W/t6.stamp" 2>/dev/null)"
if [ "$r6" = 0 ] && [ "$(printf '%s' "$o6" | tr '\n' '|')" = "in=hello|err1|out2|answered" ] && [ "$n6" = 2 ] && [[ "$st6" == unit6$'\t'm4$'\t'"retried=1 load1=999.00/999.00 nproc="* ]]; then
    ck ok "the tool under load: retried once, the retry read the same stdin, only its bytes in their own order, rc 0, stamp '$(printf '%s' "$st6" | tr '\t' ' ')'"
else ck no "arm 6: rc=$r6 runs=$n6 out=[$(printf '%s' "$o6" | tr '\n' '|')] stamp=[$st6]"; fi
o7="$(cd "$W/t7" && printf 'hello\n' | FANOUT_PROC="$W/cool" S4E_TIMEOUT_STAMP="$W/t7.stamp" "$TR" 1 bash -c "$P" 2>&1)"; r7=$?
n7="$(wc -l < "$W/t7/runs" 2>/dev/null)"
st7="$(cat "$W/t7.stamp" 2>/dev/null)"
if [ "$r7" = 0 ] && [ "$n7" = 2 ] && [[ "$st7" == *"retried=1 load1=0.10/0.10 nproc="*" at=6s stdin-not-replayed" ]]; then ck ok "the tool under a cool load: retried at the longer 6 s limit, rc 0, run twice, stamped (a piped stdin is named as not replayed)"
else ck no "arm 7: rc=$r7 runs=$n7 stamp=[$st7]"; fi
o8="$(cd "$W/t8" && printf 'hello\n' | FANOUT_PROC="$W/hot" S4E_TIMEOUT_RETRY=0 S4E_TIMEOUT_STAMP="$W/t8.stamp" "$TR" 1 bash -c "$P" 2>&1)"; r8=$?
n8="$(wc -l < "$W/t8/runs" 2>/dev/null)"
if [ "$r8" = 124 ] && [ "$n8" = 1 ] && printf '%s' "$o8" | grep -q partial; then ck ok "FAIL-ONCE: S4E_TIMEOUT_RETRY=0 is plain timeout -- rc 124, run once, the partial attempt stands"
else ck no "arm 8: rc=$r8 runs=$n8 out=[$(printf '%s' "$o8" | tr '\n' '|')]"; fi
printf 'package\tfx\tpascal\tgamma\tm3\tPASS\t0\t\npackage\tfx\tpascal\tgamma\tm4\tFAIL\t0\ttimeout-at-1s\npackage\tfx\tpascal\tdelta\tm3\tPASS\t0\t\n' > "$W/t9.rows"
printf 'gamma\tm3\tretried=1 load1=31.00/12.50 nproc=16\nnobody\tm4\tretried=1 load1=40.00/41.00 nproc=16 timeout-twice\n' > "$W/t9.stamp"
e9="$(S4E_TIMEOUT_STAMP="$W/t9.stamp" S4E_PROGRESS_DB="$W/t9.tsv" python3 "$HERE/util_progress_append.py" rows-tsv "$W/t9.rows" 2>&1)"; r9=$?
g3="$(awk -F'\t' '$8=="gamma" && $9=="m3" {print $12}' "$W/t9.tsv" 2>/dev/null)"; g4="$(awk -F'\t' '$8=="gamma" && $9=="m4" {print $12}' "$W/t9.tsv" 2>/dev/null)"
d3="$(awk -F'\t' '$8=="delta" {print $12}' "$W/t9.tsv" 2>/dev/null)"
if [ "$r9" = 0 ] && [[ "$g3" == *"retried=1 load1=31.00/12.50 nproc=16"* ]] && [[ "$g4" != *retried* ]] && [[ "$d3" != *retried* ]] && [ ! -e "$W/t9.stamp" ] && printf '%s' "$e9" | grep -q 'matched no row (key nobody'; then
    ck ok "the writer: gamma's m3 row carries the stamp, gamma m4 and delta do not, the file is consumed, the stamp naming no row is said aloud"
else ck no "arm 9: rc=$r9 gamma.m3=[$g3] gamma.m4=[$g4] delta=[$d3] stamp-left=$([ -e "$W/t9.stamp" ] && echo yes || echo no) said=[$(printf '%s' "$e9" | grep -c 'matched no row')]"; fi
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
if [ -x "$ROOT/scrip" ] && "$HERE/util_require_fresh.sh" --gate test_gate_timeout_under_load_is_could_not_measure_and_retried_once "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1; then
    mkdir -p "$W/fpc"
    printf 'program spin(input, output);\nvar i: integer;\nbegin\n  i := 0;\n  while true do i := (i + 1) mod 7;\n  writeln(i)\nend.\n' > "$W/fpc/spin.pas"
    printf '0\n' > "$W/fpc/spin.ref"
    printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n1,spin,fpc_tests__spin,fpc_tests,7,0,0,131072,4096,,\n' > "$W/fpc/ALL.csv"
    for arm in hot cool; do
        (cd "$W" && FANOUT_PROC="$W/$arm" FPC_SUITE="$W/fpc" FPC_SUITE_RUN_TIMEOUT=1 S4E_PROGRESS_DB="$W/fpc.$arm.tsv" S4E_TIMEOUT_STAMP="$W/fpc.$arm.stamp" timeout -k 5 300 bash "$HERE/test_pascal_fpc_suite.sh" > "$W/fpc.$arm.out" 2>&1)
    done
    h3="$(awk -F'\t' '$8=="spin" && $9=="m3" {print $10, $12}' "$W/fpc.hot.tsv" 2>/dev/null)"; h4="$(awk -F'\t' '$8=="spin" && $9=="m4" {print $10, $12}' "$W/fpc.hot.tsv" 2>/dev/null)"
    c3="$(awk -F'\t' '$8=="spin" && $9=="m3" {print $10, $12}' "$W/fpc.cool.tsv" 2>/dev/null)"; c4="$(awk -F'\t' '$8=="spin" && $9=="m4" {print $10, $12}' "$W/fpc.cool.tsv" 2>/dev/null)"
    if [[ "$h3" == "FAIL timeout-at-1s retried=1 load1=999.00/999.00 nproc="*" timeout-twice" ]] && [[ "$h4" == "FAIL timeout-at-1s retried=1 load1=999.00/999.00 nproc="*" timeout-twice" ]] && [[ "$c3" == "FAIL timeout-at-1s retried=1 load1=0.10/0.10 nproc="*" at=6s timeout-twice" ]] && [[ "$c4" == "FAIL timeout-at-1s retried=1 load1=0.10/0.10 nproc="*" at=6s timeout-twice" ]]; then
        ck ok "test_pascal_fpc_suite.sh: hot and cool alike, spin's m3 and m4 rows read FAIL timeout-at-1s retried=1 ... at=6s timeout-twice"
    elif [ -z "$h3$c3" ]; then echo "GATE UNPROVEN(2): the fpc runner wrote no progress row for the fixture: $(grep -m1 -E 'REFUS|⛔' "$W/fpc.hot.out" | cut -c1-200)"; exit 2
    else ck no "arm 10: hot m3=[$h3] m4=[$h4] cool m3=[$c3] m4=[$c4]"; fi
else
    echo "GATE UNPROVEN(2): arm 10 grades the fpc runner and needs a current $ROOT/scrip (make first)"; exit 2
fi
mkdir -p "$W/t11"
o11="$(cd "$W/t11" && python3 - "$HERE" "$W" <<'PY11'
import os, subprocess, sys
sys.path.insert(0, sys.argv[1]); w = sys.argv[2]
import lib_timeout_retry as R
P = "echo run >> runs; if [ -e marker ]; then echo answered; else touch marker; sleep 5; fi"
def runs(): return sum(1 for _ in open("runs")) if os.path.exists("runs") else 0
os.environ["FANOUT_PROC"] = w + "/hot"; os.environ["S4E_TIMEOUT_STAMP"] = w + "/t11.stamp"
r = R.run(["bash", "-c", P], timeout=1, key="unit11", capture_output=True, text=True)
print("HOT", r.returncode, r.stdout.strip(), runs(), open(w + "/t11.stamp").read().replace("\t", "|").strip())
for tag, env in (("COOL", {"FANOUT_PROC": w + "/cool"}), ("OFF", {"FANOUT_PROC": w + "/hot", "S4E_TIMEOUT_RETRY": "0"})):
    os.remove("marker"); os.remove("runs"); os.environ.update(env)
    try:
        R.run(["bash", "-c", P], timeout=1, capture_output=True, text=True); print(tag, "returned", runs())
    except subprocess.TimeoutExpired:
        print(tag, "raised", runs())
PY11
)"
if printf '%s\n' "$o11" | grep -qx 'HOT 0 answered 2 unit11|m4|retried=1 load1=999.00/999.00 nproc=[0-9]* at=6s' && printf '%s\n' "$o11" | grep -qx 'COOL returned 2' && printf '%s\n' "$o11" | grep -qx 'OFF raised 1'; then
    ck ok "lib_timeout_retry.run: hot and cool alike the 6 s retry's result returns (a stamp names unit11); disabled raises after one run"
else ck no "arm 11: $(printf '%s' "$o11" | tr '\n' ' ')"; fi
c12="$(python3 "$HERE/audit_bare_timeout_census.py" 2>&1)"; r12=$?
if [ "$r12" = 0 ] && printf '%s' "$c12" | grep -qE 'bare graded timeouts: 0;'; then ck ok "THE CENSUS: $(printf '%s' "$c12" | tail -1)"
elif [ "$r12" = 2 ]; then echo "GATE UNPROVEN(2): the census could not read its population: $(printf '%s' "$c12" | tail -1)"; exit 2
else ck no "arm 12: $(printf '%s' "$c12" | grep -E 'BARE|population' | head -4 | tr '\n' ' ')"; fi
mkdir -p "$W/t13"
printf '#!/bin/bash\nout=$(timeout -k 5 "$T" "$SCRIP" --run x.sno < /dev/null)\nok=$("$TIMEOUT_RETRY" "$T" "$SCRIP" --run y.sno)\nfetch=$(timeout -k 5 20s git fetch)  # timeout-retry: exempt -- a git fetch\necho "timeout -k 5 $T seconds"\n' > "$W/t13/runner.sh"
printf 'import subprocess\nr = subprocess.run(["scrip", "x.pl"], capture_output=True,\n                   timeout=10)\nq = subprocess.run(["ls"])\n' > "$W/t13/grader.py"
c13="$(python3 "$HERE/audit_bare_timeout_census.py" --files "$W/t13/runner.sh" "$W/t13/grader.py" 2>&1)"; r13=$?
if [ "$r13" = 1 ] && printf '%s' "$c13" | grep -qE 'bare graded timeouts: 2;' && printf '%s' "$c13" | grep -q 'runner.sh:2' && printf '%s' "$c13" | grep -q 'grader.py:2'; then
    ck ok "FAIL-ONCE for the census: the planted runner and grader read exactly 2 bare (runner.sh:2, grader.py:2), rc 1"
else ck no "arm 13: rc=$r13 $(printf '%s' "$c13" | tr '\n' ' ' | cut -c1-200)"; fi
o14="$(printf 'a\nb\nc\n' | while read -r x; do FANOUT_PROC="$W/hot" "$TR" 5 true; printf 'got-%s ' "$x"; done)"
if [ "$o14" = "got-a got-b got-c " ]; then ck ok "the tool never reads a stdin its command does not: a while-read loop around it sees all three lines"
else ck no "arm 14: the loop saw [$o14] -- the tool consumed its caller's stdin"; fi
o15="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import lib_timeout_retry as R; print(" ".join("%g" % R.longer(t) for t in (1, 10, 300, 1000)))' "$HERE" 2>&1)"
b15="$(for d in 1 10s 300s 1000; do FANOUT_PROC="$W/cool" S4E_TIMEOUT_STAMP="$W/t15.stamp" S4E_TIMEOUT_RETRY_CAP=600 "$TR" "$d" true >/dev/null 2>&1; done; awk -F'\t' '{print $3}' "$W/t15.stamp" 2>/dev/null | wc -l)"
l15="$(S4E_TIMEOUT_STAMP="$W/t15b.stamp" FANOUT_PROC="$W/cool" "$TR" 0.2 bash -c 'echo run >> '"$W"'/t15.runs; [ -e '"$W"'/t15.m ] || { touch '"$W"'/t15.m; sleep 0.5; }' >/dev/null 2>&1; grep -o 'at=[0-9.]*s' "$W/t15b.stamp" 2>/dev/null)"
if [ "$o15" = "6 60 600 1000" ] && [ "$b15" = 0 ] && [ "$l15" = "at=1.2s" ]; then ck ok "one longer() for every face: python 1/10/300/1000 s -> $o15 s; the bash tool retried a 0.2 s limit at 1.2 s, and a command that answers in time is never retried"
else ck no "arm 15: python=[$o15] bash-untimed-stamps=[$b15] bash-retry=[$l15]"; fi
echo "population: $checks arm(s), $fails failed (mktemp fixtures through corpus_suite_harness.classify, util_timeout_retry.sh, lib_timeout_retry.py, util_progress_append.py and test_pascal_fpc_suite.sh, the load planted through FANOUT_PROC; the census over the runner population)"
[ "$fails" = 0 ] && { echo "GATE PASS(0) [timeout_under_load_is_could_not_measure_and_retried_once]: $checks of $checks arms hold"; exit 0; }
echo "GATE FAIL(1) [timeout_under_load_is_could_not_measure_and_retried_once]: $fails of $checks arms red"; exit 1
