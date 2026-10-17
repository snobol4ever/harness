#!/usr/bin/env bash
# test_gate_a_cgroup_kill_is_a_refusal_not_a_red.sh -- ONE CGROUP SCOPE BOUNDS RESIDENT MEMORY AT THE OUTERMOST RUNNER, AND A
# CGROUP KILL IS A REFUSAL (the rc=2 family) THAT NAMES THE CAP AND THE PEAK, NEVER A RED.
#
# ⛔ THE DEFECT THIS GRADES (row instrument-698-runners-bound-the-clock-and-zero-bound-memory-one-cgroup-scope-bounds-resident-
# pages-and-a-cgroup-kill-is-a-refusal-not-a-red, the ceo's ruling on the cfo's measurement; the coo 2026-09-23). 698 files under
# ../harness/scripts/ bounded the wall clock and ZERO bounded memory; one process reached 23,343 MB RSS in 18 s on the 30 GB box ten seats
# share, and three of the cfo's jobs were reaped for it. The mechanism and every clause's evidence: ../harness/scripts/util_mem_scope.py.
#
# THE ARMS. Each "outermost" arm first steps into a NEUTRAL scope of its own (systemd-run --scope, a unit NOT named s4e-mem-),
# because under make test this gate already runs inside the blocking set's scope, where the mechanism correctly enters nothing.
#   1  FAIL-ONCE: a board runner (line 2: lib_one_runner.sh and one_runner_guard, admitted) allocates twice the cap -> the run is
#      REFUSE rc=2 naming cap= and peak=, never the child's 137 and never rc=1.
#   2  PASS-ONCE: the same runner under the cap -> its own rc=0, and the peak is printed beside the clock with oom_kill=0.
#   3  THE SCOPE IS THE RULED ONE, read from inside: memory.max == the cap, memory.swap.max == 0, OOMPolicy=continue.
#   4  ONE SCOPE, NOT TWO: a runner nested inside the scope stays in the same cgroup.
#   5  A RED STAYS A RED: a runner exiting 1 with no kill exits 1; a non-cgroup SIGKILL passes through as 137, not a refusal.
#   6  OOMPolicy=continue IS LOAD-BEARING: under the default policy the supervisor dies with its scope (SIGTERM, rc 143).
#   7  THE HARNESS grades a program the cgroup killed UNPROVEN with the kill named, and a self-inflicted SIGKILL still CRASH.
#   8  THE BLOCKING SET refuses an arm whose window saw a cgroup kill and still reds an arm that simply failed.
#   9  THE ROW WRITER writes no row over a run a cgroup kill cut, and the scratch board stays byte-unchanged.
#  10  THE WIRING, live: a real board runner (under the inert probe seat) and an ADMITTED harness run over a corpus suite (an inert
#      fixture seat, no binary: it refuses before grading) each stand inside the scope; run_blocking_set.sh enters it on the real
#      declaration (read, not run: a gate may not run make test).
#   (A verb that never calls the guard is not a board and is not scoped: scorecard_snobol4.sh oracle's last line is a protocol line
#   util_ref_mint.sh parses, and test_gate_ref_cutters_refuse_a_dead_oracle.sh reds if a supervisor line ever lands after it.)
#   R  REPORTED (printed, cannot fail the gate, needs free swap): MemorySwapMax=0 is load-bearing -- under MemoryMax alone the
#      same over-cap allocation succeeds by swapping.
# Fail-once/pass-once receipt: the Makefile line that wires this gate.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=a_cgroup_kill_is_a_refusal_not_a_red
GATE_STRICT=1
gate_parse_args "$@"
M="$HERE/util_mem_scope.py"
gate_require "$M" "the memory-scope mechanism util_mem_scope.py" || exit 2
gate_require "$HERE/lib_one_runner.sh" "lib_one_runner.sh" || exit 2
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2   # arm 8 drives run_blocking_set.sh, which refuses a stale binary
command -v systemd-run >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no systemd-run on PATH -- the mechanism cannot be measured here"; gate_stamp; exit 2; }
systemd-run --user --scope -q -- true >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: systemd-run --user --scope does not work here -- the mechanism cannot be measured"; gate_stamp; exit 2; }
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows"

SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_mem_scope_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
CAP=128; BIG=256; SMALL=16
fails=0; examined=0; out=""; rc=0
arm_fail() { fails=$((fails+1)); echo "  FAIL arm$1: $2"; printf '%s\n' "$out" | grep -aE 'mem_scope|REFUSE|Killed|rc=' | head -5 | sed 's/^/        /'; }
# neutral CMD... -- run CMD in a fresh scope that is NOT an s4e-mem one, so the mechanism under test starts from "outermost".
neutral() { systemd-run --user --scope -q --unit="s4e-gate-neutral-$$-$RANDOM" -- "$@"; }
alloc() { printf 'python3 -c "b = bytearray(%d * 1024 * 1024); print(\\"allocated\\", len(b))"' "$1"; }

# The fixture runner: line 2 is every board runner's line 2 -- source lib_one_runner.sh and call one_runner_guard -- so the scope is
# entered exactly where a real board enters it. It is a REBUS board by its name, and a scratch postoffice whose LANES line names an
# inert fixture seat for rebus ADMITS it: no override is used (those are reserved to one_runner_gate_arms.txt), no real lane's
# admission is borrowed, and its body grades nothing.
FIX_SEAT=__gate_mem_scope_fixture_seat__
mkdir -p "$WORK/post" && printf 'DECTET\nLANES: rebus=%s\n' "$FIX_SEAT" > "$WORK/post/MODE"
RUNNER="$WORK/test_rebus_memscope_fixture.sh"
cat > "$RUNNER" <<EOF_R
#!/usr/bin/env bash
source "$HERE/lib_one_runner.sh" && one_runner_guard "\${0##*/}" || exit 2
eval "\$RUNNER_BODY"
EOF_R
# fixture -- run the fixture runner from a neutral scope, admitted as the fixture seat (RUNNER_BODY and S4E_MEM_CAP_MB from the caller).
fixture() { S4E_POST="$WORK/post" S4E_SEAT="$FIX_SEAT" S4E_DONE_WHEN_RUN= S4E_ONE_RUNNER_OVERRIDE= neutral bash "$RUNNER"; }

# ARM 1 -- FAIL-ONCE: twice the cap under the scope is a REFUSAL naming the cap and the peak.
examined=$((examined+1))
out=$(RUNNER_BODY="$(alloc $BIG); echo \"body-done rc=\$?\"" S4E_MEM_CAP_MB=$CAP fixture 2>&1); rc=$?
if [ "$rc" != 2 ]; then arm_fail 1 "rc=$rc, want 2 -- a cgroup kill must be a REFUSAL (137 is the raw kill, 1 would be a phantom red, 0 a silent pass)"
elif ! printf '%s\n' "$out" | grep -q '^⛔ REFUSE(2) \[mem_scope\]: COULD NOT MEASURE: the cgroup memory cap killed 1 process'; then arm_fail 1 "no REFUSE(2) [mem_scope] line naming the kill"
elif ! printf '%s\n' "$out" | grep -qE "cap=$CAP MB \(memory.max\), peak=[0-9]+ MB \(memory.peak\)"; then arm_fail 1 "the refusal does not name cap=$CAP MB and the peak"
elif ! printf '%s\n' "$out" | grep -q 'body-done rc=137'; then arm_fail 1 "the over-cap child was not the one killed (want its rc 137 inside the runner)"
fi

# ARM 2 -- PASS-ONCE: under the cap the runner's own rc passes through and the peak is printed beside the clock.
examined=$((examined+1))
out=$(RUNNER_BODY="$(alloc $SMALL)" S4E_MEM_CAP_MB=$CAP fixture 2>&1); rc=$?
if [ "$rc" != 0 ]; then arm_fail 2 "rc=$rc, want 0"
elif ! printf '%s\n' "$out" | grep -qE "^\[mem_scope\] elapsed=[0-9]+s peak=[0-9]+ MB of cap=$CAP MB \(S4E_MEM_CAP_MB=$CAP; .*\(memory.swap.max=0, OOMPolicy=continue\) oom_kill=0  s4e-mem-"; then arm_fail 2 "no [mem_scope] line with elapsed, peak, cap=$CAP MB, swap 0 and oom_kill=0"
fi

# ARM 3 -- the scope is the ruled one, read from inside it.
examined=$((examined+1))
out=$(RUNNER_BODY='d=$(python3 '"$M"' dir); echo "max=$(cat $d/memory.max) swap=$(cat $d/memory.swap.max)"; systemctl --user show "$(basename "$d")" -p OOMPolicy' S4E_MEM_CAP_MB=$CAP fixture 2>&1); rc=$?
if [ "$rc" != 0 ]; then arm_fail 3 "rc=$rc, want 0"
elif ! printf '%s\n' "$out" | grep -qx "max=$((CAP*1024*1024)) swap=0"; then arm_fail 3 "memory.max / memory.swap.max are not $((CAP*1024*1024)) / 0 inside the scope"
elif ! printf '%s\n' "$out" | grep -qx 'OOMPolicy=continue'; then arm_fail 3 "the scope's OOMPolicy is not continue"
fi

# ARM 4 -- ONE scope: a runner inside the scope enters nothing new.
examined=$((examined+1))
out=$(RUNNER_BODY='echo "outer=$(python3 '"$M"' dir)"; RUNNER_BODY='"'"'echo "inner=$(python3 '"$M"' dir)"'"'"' bash '"$RUNNER" S4E_MEM_CAP_MB=$CAP fixture 2>&1); rc=$?
o=$(printf '%s\n' "$out" | sed -n 's/^outer=//p'); i=$(printf '%s\n' "$out" | sed -n 's/^inner=//p')
if [ "$rc" != 0 ] || [ -z "$o" ] || [ "$o" != "$i" ]; then arm_fail 4 "rc=$rc outer=[$o] inner=[$i] -- a nested runner must stay in the outer scope"
elif [ "$(printf '%s\n' "$out" | grep -c '^\[mem_scope\] elapsed=')" != 1 ]; then arm_fail 4 "more than one supervisor line -- a second scope was entered"
fi

# ARM 5 -- a red stays a red, and only the cgroup's own count turns a kill into a refusal.
examined=$((examined+1)); a5=""
out=$(RUNNER_BODY='exit 1' S4E_MEM_CAP_MB=$CAP fixture 2>&1); rc=$?
[ "$rc" = 1 ] || a5="a failing runner (no kill) exited $rc, want 1"
out=$(RUNNER_BODY='kill -9 $$' S4E_MEM_CAP_MB=$CAP fixture 2>&1); rc=$?
{ [ "$rc" = 137 ] && ! printf '%s\n' "$out" | grep -q 'REFUSE(2) \[mem_scope\]'; } || a5="${a5:+$a5; }a self-inflicted SIGKILL (no cgroup kill) exited $rc or refused, want a plain 137"
[ -z "$a5" ] || arm_fail 5 "$a5"

# ARM 6 -- OOMPolicy=continue is load-bearing: under the default policy the supervisor dies with its scope. The sleep is the
# race margin for systemd's stop on a loaded box; it costs nothing when the policy holds, because the stop kills it mid-sleep.
examined=$((examined+1))
out=$(neutral systemd-run --user --scope -q --unit="s4e-gate-default-policy-$$" -p MemoryMax=${CAP}M -p MemorySwapMax=0 -- bash -c "$(alloc $BIG); sleep 10; echo supervisor-survived" 2>&1); rc=$?
if printf '%s\n' "$out" | grep -q 'supervisor-survived'; then arm_fail 6 "under the DEFAULT OOMPolicy the supervisor survived (rc=$rc) -- the continue clause may no longer be load-bearing on this systemd; re-measure before trusting it"
fi

# ARM 7 -- the harness: a program the cgroup killed is UNPROVEN with the kill named; a self-inflicted SIGKILL is still CRASH.
examined=$((examined+1))
PYH="import sys; sys.path.insert(0, '$HERE'); import corpus_suite_harness as h"
out=$(S4E_MEM_CAP_MB=$CAP neutral python3 "$M" enter --kind board -- python3 -c "$PYH
v = h.classify(['python3', '-c', 'b = bytearray($BIG * 1024 * 1024)'], 60, '')
print('KILLED', v.kind, v.detail)
v = h.classify(['bash', '-c', 'kill -9 \$\$'], 60, '')
print('SELF', v.kind, v.detail)" 2>&1); rc=$?
if ! printf '%s\n' "$out" | grep -qE '^KILLED UNPROVEN COULD NOT MEASURE: the cgroup memory cap killed 1 process'; then arm_fail 7 "a program the cgroup killed is not graded UNPROVEN with the kill named"
elif ! printf '%s\n' "$out" | grep -qE '^SELF CRASH signal 9'; then arm_fail 7 "a self-inflicted SIGKILL is no longer CRASH -- the reclassification must read the cgroup's own count, not every SIGKILL"
fi

# ARM 8 -- the blocking set: an arm whose window saw a cgroup kill is REFUSED; an arm that simply failed is still RED.
examined=$((examined+1))
printf '%s\n' "$(alloc $BIG) >/dev/null; exit 1" 'exit 1' > "$WORK/arms.txt"
out=$(S4E_MEM_CAP_MB=$CAP S4E_BLOCKING_RUNSTATE="$WORK/runstate" neutral python3 "$M" enter --kind blocking-set -- bash "$HERE/run_blocking_set.sh" --arms-from "$WORK/arms.txt" 2>&1); rc=$?
if ! printf '%s\n' "$out" | grep -qE 'blocking set: arms=2 +green=0 +red=1 +refused=1'; then arm_fail 8 "want arms=2 green=0 red=1 refused=1 (the killed arm REFUSED, the plain failure RED): $(printf '%s\n' "$out" | grep -a 'blocking set:' | head -1)"
elif ! printf '%s\n' "$out" | grep -q 'the cgroup memory cap killed'; then arm_fail 8 "the refused arm does not name the cgroup kill"
fi

# ARM 9 -- the row writer writes no row over a run a cgroup kill cut; the scratch board stays byte-unchanged.
examined=$((examined+1))
B="$WORK/board"; mkdir -p "$B/.github" && cp "$ROOT/../.github/SCORE.md" "$B/.github/SCORE.md" 2>/dev/null || { echo "  UNPROVEN arm9: no .github/SCORE.md beside this tree to copy as a scratch board"; }
if [ -f "$B/.github/SCORE.md" ]; then
    before=$(md5sum < "$B/.github/SCORE.md")
    printf 'NONET\n# fixture\n' > "$WORK/MODE"
    # The write is called the way a runner calls it: the seat exported in a subshell, and the measurer argument in the ONE
    # call shape test_gate_seat_identity_one_map.sh requires, never a literal seat.
    out=$(RUNNER_BODY="$(alloc $BIG); ( export S4E_SEAT=hq_snocone; S4E_HOME='$B' S4E_MODE_FILE='$WORK/MODE' S4E_SCORE_WRITE='gate fixture' python3 '$HERE/util_score_row.py' write --lang snocone --column ladder --text 'fixture 1/1' --measurer \"\${S4E_SEAT:-}\" ); echo \"write-rc=\$?\"" S4E_MEM_CAP_MB=$CAP fixture 2>&1); rc=$?
    if ! printf '%s\n' "$out" | grep -q 'write-rc=2'; then arm_fail 9 "the row writer did not refuse rc=2 after a cgroup kill: $(printf '%s\n' "$out" | grep -a 'write-rc=' | head -1)"
    elif ! printf '%s\n' "$out" | grep -q 'REFUSED(2) util_score_row: A CGROUP MEMORY KILL CUT THE RUN'; then arm_fail 9 "the refusal does not name the cgroup kill"
    elif [ "$(md5sum < "$B/.github/SCORE.md")" != "$before" ]; then arm_fail 9 "the scratch board CHANGED -- a row was written over a killed run"
    fi
fi

# ARM 10 -- the wiring, live: a real board runner and the harness enter the scope; run_blocking_set.sh does on the real declaration.
examined=$((examined+1)); a10=""
PROBE="$(bash -c ". '$HERE/lib_one_runner.sh'; printf %s \"\$ONE_RUNNER_PROBE_SEAT\"")"
out=$(S4E_SEAT="$PROBE" S4E_DONE_WHEN_RUN= S4E_ONE_RUNNER_OVERRIDE= neutral bash "$HERE/test_snobol4_dotnet_suite.sh" 2>&1); rc=$?
{ [ "$rc" = 2 ] && printf '%s\n' "$out" | grep -q 'REFUSE(2) ONE RUNNER' && printf '%s\n' "$out" | grep -qE '^\[mem_scope\] elapsed=[0-9]+s peak=.* oom_kill=0  s4e-mem-'; } \
  || a10="a board runner under the probe seat did not refuse INSIDE a scope (rc=$rc)"
# The harness enters AFTER its one-runner guard admits, so its live proof needs an ADMITTED run that grades nothing: a scratch
# postoffice whose LANES line names an inert fixture seat for rebus, and SCRIP pointed at no binary -- check_scrip then refuses rc=2
# INSIDE the scope, before the first program, and the supervisor's line proves where it stood.
SUITE="$(ls "$ROOT"/../corpus/tests/rebus/ALL.reb 2>/dev/null | head -1)"
if [ -n "$SUITE" ]; then
    FIX_SEAT=__gate_mem_scope_fixture_seat__; mkdir -p "$WORK/post"; printf 'DECTET\nLANES: rebus=%s\n' "$FIX_SEAT" > "$WORK/post/MODE"
    out=$(S4E_POST="$WORK/post" S4E_SEAT="$FIX_SEAT" S4E_DONE_WHEN_RUN= S4E_ONE_RUNNER_OVERRIDE= SCRIP="$WORK/no-such-scrip" \
          neutral python3 "$HERE/corpus_suite_harness.py" run "$SUITE" "${SUITE%.*}.ref" --lang rebus 2>&1); rc=$?
    { [ "$rc" = 2 ] && printf '%s\n' "$out" | grep -q 'scrip is not built/executable' \
      && printf '%s\n' "$out" | grep -qE '^\[mem_scope\] elapsed=[0-9]+s peak=.* oom_kill=0  s4e-mem-'; } \
      || a10="${a10:+$a10; }an admitted harness run over a corpus suite did not stand inside a scope when it refused (rc=$rc)"
else
    a10="${a10:+$a10; }no corpus/tests/rebus/ALL.reb beside this tree to hand the harness"
fi
grep -q 'util_mem_scope.py" enter --kind blocking-set' "$HERE/run_blocking_set.sh" || a10="${a10:+$a10; }run_blocking_set.sh does not enter the blocking-set scope"
[ -z "$a10" ] || arm_fail 10 "$a10"

# R -- REPORTED: the swap clause is load-bearing (needs free swap; printed, never fails the gate).
out=$(neutral systemd-run --user --scope -q --unit="s4e-gate-swap-$$" -p MemoryMax=${CAP}M -p OOMPolicy=continue -- bash -c "$(alloc $BIG)" 2>&1); rc=$?
echo "  REPORTED swap clause: under MemoryMax=${CAP}M ALONE a ${BIG} MB allocation read rc=$rc ($(printf '%s' "$out" | tr '\n' ' ' | cut -c1-60)) -- rc=0 'allocated' means it swapped past the cap, which is why MemorySwapMax=0 is mandatory"

GATE_EXAMINED=$examined
gate_verdict "$fails" "arm(s) failed (one cgroup scope bounds resident memory; a cgroup kill is a refusal naming cap and peak, never a red)"
