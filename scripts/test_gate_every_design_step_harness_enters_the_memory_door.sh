#!/usr/bin/env bash
# test_gate_every_design_step_harness_enters_the_memory_door.sh -- EVERY DESIGN STEP HARNESS ENTERS THE BOX'S MEMORY DOOR AT ITS TOP, SO A WITNESS
# WITH A DECLARED HEAP NEVER RUNS INSIDE A SEAT'S OWN SCOPE (the cio 2026-11-10 12:3x, row fleet-every-design-step-harness-enters-the-memory-door-
# so-a-witness-with-a-declared-heap-never-runs-in-a-seats-scope; MEASURED by the cio 12:21: test_design_pascal_packed_arrays_steps.sh --step 5 ran
# pa08_wide at its declared 6291456 KB bare in the coo's terminal scope, 4.3 GB against memory.high 4 GB, and the whole session stalled).
# ARM 1, the population: every harness/scripts/test_design_*_steps.sh sources lib_one_runner.sh and calls one_runner_mem_scope within three lines
# after its HERE= line, before it reads an argument or runs anything; each one that does not is named.
# ARM 2, the door works: a scratch script built the same way, run from this shell, reads its own /proc/self/cgroup inside an s4e-mem- scope;
# FAIL ONCE in the same run: the same script without the call reads no s4e-mem- scope (so arm 2 can tell the two apart).
# rc 0 green · 1 red (each harness named) · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_every_design_step_harness_enters_the_memory_door
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib_one_runner.sh" ] && [ -f "$HERE/util_mem_scope.py" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no lib_one_runner.sh or util_mem_scope.py beside this gate"; exit 2; }
RED=0; N=0; MISSING=""
for f in "$HERE"/test_design_*_steps.sh; do
    [ -f "$f" ] || continue
    N=$((N + 1))
    h="$(grep -n -m1 '^HERE=' "$f" | cut -d: -f1)"
    d="$(grep -n -m1 '^\. "\$HERE/lib_one_runner.sh" && one_runner_mem_scope' "$f" | cut -d: -f1)"
    if [ -z "$h" ] || [ -z "$d" ] || [ "$d" -le "$h" ] || [ "$d" -gt $((h + 3)) ]; then RED=$((RED + 1)); MISSING="$MISSING $(basename "$f")"; fi
done
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no test_design_*_steps.sh beside this gate -- an empty population proves nothing"; exit 2; }
if [ "$RED" = 0 ]; then echo "  ok   arm 1: all $N design step harnesses enter the memory door after HERE"; else echo "  RED  arm 1: $RED of $N harnesses do not enter the memory door:$MISSING"; fi
T="$(mktemp -d "${TMPDIR:-/tmp}/memdoor_gate.XXXXXX")" || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
cp -p "$HERE/lib_one_runner.sh" "$HERE/util_mem_scope.py" "$T/" || { echo "⛔ REFUSE(2) [$GATE_NAME]: cannot copy the door into scratch"; exit 2; }
for k in lib_slots.sh lib_runner_out.sh; do [ -f "$HERE/$k" ] && cp -p "$HERE/$k" "$T/"; done
printf '#!/usr/bin/env bash\nHERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n. "$HERE/lib_one_runner.sh" && one_runner_mem_scope\ncat /proc/self/cgroup\n' > "$T/with.sh"
printf '#!/usr/bin/env bash\nHERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n. "$HERE/lib_one_runner.sh"\ncat /proc/self/cgroup\n' > "$T/without.sh"
in_scope="$(env -u S4E_MEM_SCOPE timeout -k 5 60 bash "$T/with.sh" < /dev/null 2>/dev/null | grep -c '/s4e-mem-')"
out_scope="$(env -u S4E_MEM_SCOPE timeout -k 5 60 bash "$T/without.sh" < /dev/null 2>/dev/null | grep -c '/s4e-mem-')"
if grep -qs '/s4e-mem-' /proc/self/cgroup; then
    echo "  --   arm 2 not read: this gate already runs inside an s4e-mem- scope, where the door does nothing by design"
elif [ "$out_scope" != 0 ]; then
    echo "⛔ REFUSE(2) [$GATE_NAME]: the script WITHOUT the call read an s4e-mem- scope -- arm 2 cannot tell the two apart"; exit 2
elif [ "$in_scope" -ge 1 ]; then
    echo "  ok   arm 2: a script that calls the door runs in an s4e-mem- scope (with $in_scope, without $out_scope)"
else
    RED=$((RED + 1)); echo "  RED  arm 2: a script that calls one_runner_mem_scope did not run in an s4e-mem- scope (systemd-run unusable, or the door broke)"
fi
echo "MEMORY_DOOR_BOARD harnesses=$N missing=$(( $(printf '%s' "$MISSING" | wc -w) )) door_in_scope=$in_scope control=$out_scope"
[ "$RED" = 0 ] && { echo "GATE OK [$GATE_NAME]: every design step harness enters the memory door"; exit 0; }
echo "GATE FAIL [$GATE_NAME]: $RED red (harnesses missing the door, and arm 2 when it reads red)"; exit 1
