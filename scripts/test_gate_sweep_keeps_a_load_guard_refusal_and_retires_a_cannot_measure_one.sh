#!/usr/bin/env bash
# ../harness/scripts/test_gate_sweep_keeps_a_load_guard_refusal_and_retires_a_cannot_measure_one.sh
# ceo 2026-10-08 21:5x CDT (CEO-1574), closing the coo's row
# instruments-the-sweep-keeps-a-row-whose-finish-line-refused-on-a-load-guard-instead-of-retiring-it-ceo-1562.
#
# WHAT IT GRADES. The zero-base sweep (.github/scripts/util_queue_zero_base.py --apply, ceo CEO-1386) runs every FREE row's
# DONE-WHEN and RETIRES a row whose finish line reads rc 2 (cannot measure). A benchmark bar reads rc 2 under load by the
# two-number law -- a multiple is not load-invariant (CEO-743): its angles DISAGREE, or its harness prints no row because the
# kernel ran past its budget -- so every sweep that ran while the fleet built retired the live performance rows: eight on
# 2026-10-07 20:16, four on 2026-10-08 15:18, two more at 19:17 (CEO-1572), each re-minted by hand and each a row the fleet
# could not pick meanwhile.
# THE CURE this gate pins: an rc 2 whose output names the LOAD GUARD -- the words "load-guard", which the four bench bars print
# through perf_load_guard (lib_perf_fmt.sh) on a timing-shaped refusal when the box reads at or above BENCH_LOAD_GUARD_PER_CORE
# per core -- is KEPT exactly as a TIMEOUT is kept; its refusal line and the sweep's own load reading go to the baton as a LEDGER
# line that does NOT restart the PARKED-EXPIRED clock (a quiet sweep measures it); the salvage log names the class
# LOAD-GUARD-kept; --help names the rule. A plain rc 2 (no oracle, no binary, a wrong answer) stays CANNOT MEASURE and retires.
# The two refusals differ by one phrase, so both are planted side by side and graded side by side.
# THE FIXTURE is a five-row scratch postoffice (S4E_POSTOFFICE): a load-guard refusal, a plain cannot-measure, a red at rank 0
# (kept, re-ranked to 2, ledgered), a green (archived) and a criterion that sleeps past the timeout (kept; the KNIT arms below).
# ZB_SCRIPT points the gate at another copy of the sweep for the red-once proofs: against the pre-cure script (.github cfe569fb)
# arms H, L, B and S read RED; against the pre-knit script (.github a3248fbb) arm K reads RED; on the cured one all nine green.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
G=sweep_keeps_a_load_guard_refusal_and_retires_a_cannot_measure_one
ZB="${ZB_SCRIPT:-$S4E/.github/scripts/util_queue_zero_base.py}"
unproven() { echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
[ -f "$ZB" ] || unproven "no sweep script at $ZB"
command -v python3 > /dev/null || unproven "no python3"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_zb_guard.XXXXXX")" || unproven "mktemp failed"
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0; T=$'\t'
ok()  { PASS=$((PASS+1)); echo "  ✅ $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1 RED: $2"; }
mkdir -p "$W/tasks" "$W/salvage"; : > "$W/QUEUE.done.tsv"; : > "$W/QUEUE.retired.tsv"
printf '# fixture queue (CEO-1574 gate)\n' > "$W/QUEUE.tsv"
OLD="$(date -d '2 days ago' +%Y-%m-%dT%H:%M:%S)"
row()   { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; }
baton() { printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: %s\nLINKS: minted via `mint` by ceo, 2026-10-01T00:00:00Z\n## NEXT\n## LEDGER\n' "$1" "$2" > "$W/tasks/$1.task.md"; touch -d "$OLD" "$W/tasks/$1.task.md"; }
row 2 fx-load-guard-row coo FREE; baton fx-load-guard-row "echo 'REFUSE(2) load-guard: load 99.0 on 16 cores (6.19/core) at or above the 0.5/core guard -- fixture'; exit 2"
row 2 fx-cannot-row coo FREE;     baton fx-cannot-row "echo 'REFUSE(2): fixture cannot measure (no oracle)'; exit 2"
row 0 fx-red-row coo FREE;        baton fx-red-row "exit 1"
row 2 fx-green-row coo FREE;      baton fx-green-row "exit 0"
row 2 fx-timeout-row coo FREE;    baton fx-timeout-row "sleep 20; exit 0"
m0="$(stat -c %Y "$W/tasks/fx-load-guard-row.task.md")"
o="$(cd "$W" && S4E_POSTOFFICE="$W" S4E_HOME="$S4E" ZB_KNIT_CMD='echo knit' python3 "$ZB" --apply --timeout 1 2>&1)"; r=$?
[ "$r" = 0 ] || { printf '%s\n' "$o" | tail -5; unproven "the sweep exited $r on the fixture"; }
h="$(python3 "$ZB" --help 2>&1)"
grep -qi 'load-guard' <<<"$h" && ok H "--help names the load-guard rule" || red H "--help does not name load-guard"
if grep -qE "^2${T}fx-load-guard-row${T}coo${T}FREE$" "$W/QUEUE.tsv" && ! grep -q 'fx-load-guard-row' "$W/QUEUE.retired.tsv"; then
    ok L "the load-guard refusal (rc 2 naming load-guard) stays live, FREE at its rank, not retired"
else
    red L "the load-guard refusal: live [$(grep 'fx-load-guard-row' "$W/QUEUE.tsv" | cut -c1-60)] retired [$(grep 'fx-load-guard-row' "$W/QUEUE.retired.tsv" | cut -c1-80)] (want live FREE, not retired)"
fi
m1="$(stat -c %Y "$W/tasks/fx-load-guard-row.task.md")"
nl="$(grep -c '^- .*LOAD GUARD.*at or above the 0.5/core guard -- fixture' "$W/tasks/fx-load-guard-row.task.md")"
if [ "$nl" = 1 ] && [ "$m0" = "$m1" ]; then
    ok B "its baton gained one LEDGER line naming the LOAD GUARD and carrying the refusal line, and its mtime is unchanged (the expiry clock did not restart)"
else
    red B "baton: $nl LEDGER line(s) naming LOAD GUARD with the refusal line, mtime $m0 -> $m1 (want 1, unchanged)"
fi
grep -qE "^2${T}fx-cannot-row${T}coo${T}RETIRED:zero-base-ceo-1386-cannot-measure-rc2$" "$W/QUEUE.retired.tsv" && ! grep -q 'fx-cannot-row' "$W/QUEUE.tsv" \
    && ok C "the plain rc 2 beside it is still retired as cannot-measure-rc2" \
    || red C "plain rc 2: retired [$(grep 'fx-cannot-row' "$W/QUEUE.retired.tsv" | cut -c1-80)] live [$(grep -c 'fx-cannot-row' "$W/QUEUE.tsv")] (want retired cannot-measure-rc2, not live)"
grep -qE "^2${T}fx-red-row${T}coo${T}FREE$" "$W/QUEUE.tsv" && grep -q 'ran RED (rc=1)' "$W/tasks/fx-red-row.task.md" \
    && ok R "the rank-0 red is kept, re-ranked to 2, and ledgered RED" \
    || red R "red row: [$(grep 'fx-red-row' "$W/QUEUE.tsv" | cut -c1-60)] ledger RED lines $(grep -c 'ran RED' "$W/tasks/fx-red-row.task.md") (want rank 2 FREE, 1)"
grep -qE "^2${T}fx-green-row${T}coo${T}DONE:zero-base-green-ceo-1386$" "$W/QUEUE.done.tsv" \
    && ok G "the green is archived DONE" \
    || red G "green row: done [$(grep 'fx-green-row' "$W/QUEUE.done.tsv" | cut -c1-60)] (want DONE:zero-base-green-ceo-1386)"
s="$(ls "$W"/salvage/zero-base-*.tsv 2>/dev/null | head -1)"
[ -n "$s" ] && grep -qE "^fx-load-guard-row${T}coo${T}FREE${T}LOAD-GUARD-kept${T}2${T}KEEP$" "$s" \
    && ok S "the salvage log names the class LOAD-GUARD-kept with rc 2 and place KEEP" \
    || red S "salvage: [$( [ -n "$s" ] && grep 'fx-load-guard-row' "$s" | cut -c1-100)] (want class LOAD-GUARD-kept, rc 2, KEEP)"
# THE KNIT (ceo CEO-1574, measured on the first sweep under the guard): a criterion that builds in the root and is killed at the
# timeout leaves the tree half-built, and every later binary-running criterion refuses rc 2 -- nine false retirements on 2026-10-08.
# The sweep knits the tree (ZB_KNIT_CMD, by default make in the root) once before the run phase and again after every kill; the
# fixture plants a criterion that sleeps past --timeout 1 and hands the sweep an echo as its knit, so this gate never builds.
nk="$(grep -c '^KNIT ' <<<"$o")"
[ "$nk" = 2 ] && grep -q '^KNIT before the run phase: echo knit -> rc 0' <<<"$o" && grep -q '^KNIT after the killed criterion fx-timeout-row: echo knit -> rc 0' <<<"$o" \
    && ok K "the tree is knit once before the run phase and once after the killed criterion, each knit printed with its rc" \
    || red K "$nk KNIT line(s): $(grep '^KNIT ' <<<"$o" | cut -c1-80 | tr '\n' '|') (want 2: before the run phase, after the killed criterion fx-timeout-row, rc 0)"
grep -qE "^2${T}fx-timeout-row${T}coo${T}FREE$" "$W/QUEUE.tsv" && ! grep -q 'fx-timeout-row' "$W/QUEUE.retired.tsv" && ! grep -q 'fx-timeout-row' "$W/QUEUE.done.tsv" \
    && ok T "the criterion killed at the timeout is kept FREE, neither retired nor done" \
    || red T "timeout row: live [$(grep 'fx-timeout-row' "$W/QUEUE.tsv" | cut -c1-60)] retired [$(grep -c 'fx-timeout-row' "$W/QUEUE.retired.tsv")] done [$(grep -c 'fx-timeout-row' "$W/QUEUE.done.tsv")] (want FREE, 0, 0)"
echo "GATE $([ "$FAIL" = 0 ] && echo PASS || echo "FAIL($FAIL)") [$G]: $PASS of $((PASS + FAIL)) arms green (population: a five-row fixture postoffice swept by $ZB)"
[ "$FAIL" = 0 ]
