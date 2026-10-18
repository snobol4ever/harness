#!/usr/bin/env bash
# test_gate_monitor_refuses_when_a_participant_never_starts.sh — the sync-step monitor must REFUSE (rc=2)
# with a NAMED reason when a participant never opens its FIFO pair, and must never hang to a timeout.
#
# ⛔ THE DEFECT THIS GRADES (hq_T 2026-09-09, ceo brief `the-ipc-sync-step-monitor-does-not-run-and-lon-is-
# counting-on-it`, red proof below). monitor_sync_bin.py's open_pair() was two BLOCKING os.open() calls on
# FIFOs. A FIFO opened O_RDONLY blocks until a writer appears and O_WRONLY until a reader appears -- with no
# timeout of their own -- so when a participant died during startup the controller blocked forever, printed
# NOTHING (its first log line comes after the open), and the harness sat in an unbounded `wait`. An external
# `timeout` eventually killed the process group, whose EXIT trap then deleted the scratch dir holding the
# only copy of the answer.
#
# ⭐ THE MEASURED RED, on the ceo's own witness (snoflake string-pad.sno): rc=124 after 180s, ctrl.out zero
# bytes, and `cat: .scratch/monitor_auto_XXX/ctrl.out: No such file or directory`. BOTH participants had
# exited INSIDE THE FIRST SECOND, each having written its reason to its .err file, while the controller went
# on waiting 141s+ for writers that no longer existed. The instrument could not tell "measured and clean"
# from "never ran" -- and it deleted the evidence on its way out. AFTER the cure: rc=2 in 20s, naming the
# participant, with that .err surfaced.
#
# ⭐ WHY THE FIXTURE USES A LOWERCASE `end`: under the mandated case-sensitive oracle flags (`sbl -bf`,
# lib_oracle_flags.sh) SPITBOL does not recognise `end` as END, so it refuses the file during startup and
# never reaches the monitor bridge. That is the cheapest way to produce a participant that legitimately
# never starts, and it needs no corpus program -- so this gate cannot be broken by a corpus re-grid.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=monitor_refuses_when_a_participant_never_starts
GATE_STRICT=1
gate_parse_args "$@"
gate_require_exec "/home/resources/x64/bin/sbl" || exit 2
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2

SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_monitor_refuse_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
FIX="$WORK/never_starts.sno"
printf '\toutput = "unreachable"\nend\n' > "$FIX"

fails=0; examined=0
OPEN_T=3        # keep the gate cheap; the cure is the REFUSAL, not the length of the wait
OUTER=90        # generous: if we ever hit THIS the cure has regressed to a hang

examined=$((examined+1))
t0=$(date +%s)
out=$(MONITOR_OPEN_TIMEOUT=$OPEN_T MONITOR_CTRL_TIMEOUT=$((OPEN_T*3)) \
      timeout -k 5 $OUTER bash "$HERE/test_monitor_2way_spitbol_vs_run.sh" "$FIX" 2>&1); rc=$?
t1=$(date +%s); elapsed=$((t1-t0))

# ARM 1 -- the verdict is a REFUSAL, never a result and never a timeout.
if [ "$rc" != "2" ]; then
    fails=$((fails+1))
    case "$rc" in
      124) echo "  FAIL arm1: rc=124 -- the harness HUNG to its outer timeout. This is the exact red the gate exists for." ;;
      0|1) echo "  FAIL arm1: rc=$rc -- a participant that never started was reported as a RESULT ($([ "$rc" = 0 ] && echo agreed || echo diverged)). An instrument that cannot measure must refuse." ;;
      *)   echo "  FAIL arm1: rc=$rc, expected 2" ;;
    esac
fi

# ARM 2 -- it refused PROMPTLY. A refusal that takes the whole window is a hang wearing a verdict.
examined=$((examined+1))
if [ "$elapsed" -ge $((OUTER/2)) ]; then
    fails=$((fails+1)); echo "  FAIL arm2: refused only after ${elapsed}s (bound ${OUTER}s) -- that is a hang, not a refusal."
fi

# ARM 3 -- the reason NAMES the participant. A refusal that will not say who is a refusal nobody can act on.
examined=$((examined+1))
if ! printf '%s' "$out" | grep -q 'REFUSING(2)'; then
    fails=$((fails+1)); echo "  FAIL arm3: no REFUSING(2) line in the output."
elif ! printf '%s' "$out" | grep -qE 'REFUSING\(2\).*\b(spl|scr)\b.*never opened'; then
    fails=$((fails+1)); echo "  FAIL arm3: the refusal does not NAME the participant that never started."
fi

# ARM 4 -- the participant's own stderr survives to the operator. Deleting it with the scratch dir was
# half the original defect: the answer existed the whole time and the harness threw it away.
examined=$((examined+1))
if ! printf '%s' "$out" | grep -qi 'No END statement'; then
    fails=$((fails+1)); echo "  FAIL arm4: the participant's stderr (its REASON) never reached the operator."
fi

GATE_EXAMINED=$examined
gate_verdict "$fails" "arm(s) failed (monitor must refuse rc=2 with a named reason, not hang)"
