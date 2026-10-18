#!/usr/bin/env bash
# test_gate_preflight_arms_stay_cheap.sh -- the guard on `make preflight` (hq_T's ask 2026-09-06; hq_R wired it).
# ⛔ WHAT IT PREVENTS, in hq_T's own words: "the target will quietly acquire a 45-second arm and stop being the
# thing that made it worth running." The value of a preflight target is that nobody weighs whether to run it, and
# that value is destroyed by a single slow arm -- silently, because a slow arm is still a CORRECT arm.
# ⛔ MEMBERSHIP IS PINNED BY MEASURED DURATION, NEVER BY A PATTERN OVER THE TEXT. A static grep cannot see one
# level of indirection: test_gate_pl_quad_regs.sh (~45s) and test_gate_capture_stdin_and_red_exit.sh (~15s) reach
# the compiler through lib_ helpers without naming it, and a comment-stripped grep clears both.
# ⛔⭐ A LOADED BOX IS NOT A SLOW ARM (the cfo's measurement 2026-09-24 09:2x; ceo CEO-1234; row instruments-the-cheap-preflight-
# gate-reds-on-its-40-s-total-at-load-above-25-with-no-single-arm-slow-so-a-loaded-box-reads-a-false-red): at load 26-32 the 59
# arms took 50.5 s of WALL time against the 40 s total with no arm over 5 s, so this BLOCKING arm redded for every seat on the
# box's load, not on a slow arm -- the class CEO-1197(2) named for the death gate. Each arm is now timed for WALL and CPU (user +
# sys, which load does not inflate): CPU over its budget is RED at any load; WALL over its budget is RED only at or under the
# declared load ceiling (PREFLIGHT_LOAD_CEILING, default the core count; the load is the highest 1-minute average read before,
# during and after the run), and above it a WALL-only excess REFUSES rc=2 naming the load -- could not measure, never green,
# never red. ⛔ AND ONE INVOCATION PER ARM, THE ONE `make preflight` RUNS: a .py arm was timed on `bash -c`, which exec'd a
# non-executable script and failed in milliseconds (or ran an executable one), then run AGAIN by python3 untimed -- so no .py
# arm's duration was ever measured, and util_gate_wiring.py ran twice.
# SELF-PROOF (before the real list, on fixture arms under mktemp): a 1.2 s sleep against a 1 s budget reds at a ceiling no load
# reaches and refuses at a ceiling of 0; a 1.5 s CPU loop reds at a ceiling of 0 (CPU); so the gate can still red on load-proof
# evidence and can no longer red on load alone.
set -u
GATE_NAME=test_gate_preflight_arms_stay_cheap
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh"
LIST="$HERE/preflight_arms.txt"
BUDGET_S=${PREFLIGHT_ARM_BUDGET_S:-5}
TOTAL_BUDGET_S=${PREFLIGHT_TOTAL_BUDGET_S:-40}
CEIL=${PREFLIGHT_LOAD_CEILING:-$(nproc)}
[ -f "$LIST" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no $LIST -- the population is DECLARED, and an absent declaration is not an empty one"; exit 2; }
command -v bc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no bc"; exit 2; }
load1() { cut -d' ' -f1 /proc/loadavg; }
# run_list LIST BUDGET TOTAL CEILING -> prints each arm; sets R_BAD (reds), R_LOADED (wall-only excesses above the ceiling),
# R_N, R_WALL, R_CPU, R_LOAD (the highest 1-minute load seen)
run_list() {
    local list="$1" budget="$2" tbudget="$3" ceil="$4" arm script d c rc t out
    R_BAD=0; R_LOADED=0; R_N=0; R_WALL=0; R_CPU=0; R_LOAD=$(load1)
    while read -r arm; do
        case "$arm" in ""|\#*) continue ;; esac
        R_N=$((R_N + 1))
        script=${arm%% *}
        case "$script" in /*) [ -e "$script" ] ;; *) [ -e "$ROOT/$script" ] ;; esac || { echo "  MISSING  $script"; R_BAD=$((R_BAD + 1)); continue; }
        t=$( { TIMEFORMAT='%R %U %S'; time ( cd "$ROOT" && case "$arm" in *.py*) timeout -k 5 30 python3 $arm ;; *) timeout -k 5 30 bash $arm ;; esac </dev/null >/dev/null 2>&1; echo "rc=$?" ); } 2>&1 )
        rc=$(sed -n 's/^rc=//p' <<<"$t" | tail -1); read -r d u s <<<"$(grep -v '^rc=' <<<"$t" | tail -1)"
        c=$(echo "$u + $s" | bc)
        l=$(load1); [ "$(echo "$l > $R_LOAD" | bc)" = 1 ] && R_LOAD=$l
        if [ "$(echo "$c > $budget" | bc)" = 1 ]; then printf '  SLOW     %6.2fs cpu %6.2fs wall  %s  (budget %ss, CPU -- red at any load)\n' "$c" "$d" "$script" "$budget"; R_BAD=$((R_BAD + 1)); continue; fi
        if [ "$(echo "$d > $budget" | bc)" = 1 ]; then
            if [ "$(echo "$R_LOAD > $ceil" | bc)" = 1 ]; then printf '  LOADED   %6.2fs cpu %6.2fs wall  %s  (wall over %ss at load %s above the ceiling %s; CPU within)\n' "$c" "$d" "$script" "$budget" "$R_LOAD" "$ceil"; R_LOADED=$((R_LOADED + 1))
            else printf '  SLOW     %6.2fs cpu %6.2fs wall  %s  (budget %ss, wall at load %s, at or under the ceiling %s)\n' "$c" "$d" "$script" "$budget" "$R_LOAD" "$ceil"; R_BAD=$((R_BAD + 1)); continue; fi
        fi
        if [ "${rc:-1}" -ne 0 ]; then printf '  RED      rc=%-3s      %s\n' "$rc" "$script"; R_BAD=$((R_BAD + 1)); continue; fi
        R_WALL=$(echo "$R_WALL + $d" | bc); R_CPU=$(echo "$R_CPU + $c" | bc)
        printf '  ok       %6.2fs cpu %6.2fs wall  %s\n' "$c" "$d" "$script"
    done < "$list"
    l=$(load1); [ "$(echo "$l > $R_LOAD" | bc)" = 1 ] && R_LOAD=$l
    printf '  TOTAL    %6.2fs cpu %6.2fs wall over %d arm(s) at load %s (per-arm %ss, total %ss, load ceiling %s)\n' "$R_CPU" "$R_WALL" "$R_N" "$R_LOAD" "$budget" "$tbudget" "$ceil"
    if [ "$(echo "$R_CPU > $tbudget" | bc)" = 1 ]; then echo "  SLOW-TOTAL: the set's CPU time exceeds its budget -- a preflight nobody runs is the defect this target cures"; R_BAD=$((R_BAD + 1))
    elif [ "$(echo "$R_WALL > $tbudget" | bc)" = 1 ]; then
        if [ "$(echo "$R_LOAD > $ceil" | bc)" = 1 ]; then echo "  LOADED-TOTAL: the set's wall time exceeds its budget at load $R_LOAD above the ceiling $ceil while its CPU time is within"; R_LOADED=$((R_LOADED + 1))
        else echo "  SLOW-TOTAL: the set's wall time exceeds its budget at load $R_LOAD, at or under the ceiling $ceil"; R_BAD=$((R_BAD + 1)); fi
    fi
}
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_preflight_cheap.XXXXXX") || { echo "⛔ REFUSED(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
printf 'sleep 1.2\n' > "$W/sleepy.sh"
cat > "$W/busy.sh" <<'BUSY'
python3 -c "import time
t = time.process_time()
while time.process_time() - t < 1.5: pass"
BUSY
printf '%s\n' "$W/sleepy.sh" > "$W/sleepy.list"; printf '%s\n' "$W/busy.sh" > "$W/busy.list"
echo "=== self-proof on fixture arms (budget 1s) ==="
run_list "$W/sleepy.list" 1 40 100000 > "$W/p1" 2>&1; p1="$R_BAD/$R_LOADED"
run_list "$W/sleepy.list" 1 40 0 > "$W/p2" 2>&1; p2="$R_BAD/$R_LOADED"
run_list "$W/busy.list" 1 40 0 > "$W/p3" 2>&1; p3="$R_BAD/$R_LOADED"
proof=0
[ "$p1" = "1/0" ] && echo "  ok   a 1.2 s sleep reds when the load is under the ceiling (red/loaded $p1)" || { echo "  FAIL a 1.2 s sleep under the ceiling read red/loaded $p1, want 1/0: $(tr '\n' ' ' < "$W/p1")"; proof=1; }
[ "$p2" = "0/1" ] && echo "  ok   the same sleep above the ceiling is a load refusal, not a red (red/loaded $p2)" || { echo "  FAIL the sleep above the ceiling read red/loaded $p2, want 0/1: $(tr '\n' ' ' < "$W/p2")"; proof=1; }
[ "$p3" = "1/0" ] && echo "  ok   a 1.5 s CPU loop reds on CPU even above the ceiling (red/loaded $p3)" || { echo "  FAIL the busy loop above the ceiling read red/loaded $p3, want 1/0: $(tr '\n' ' ' < "$W/p3")"; proof=1; }
[ "$proof" = 0 ] || { echo "GATE FAIL(1) [$GATE_NAME]: the self-proof failed -- this gate cannot tell a slow arm from a loaded box"; gate_stamp; exit 1; }
echo "=== the declared preflight arms ($LIST) ==="
run_list "$LIST" "$BUDGET_S" "$TOTAL_BUDGET_S" "$CEIL"
[ "$R_N" -gt 0 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: graded ZERO arms -- a runner that cannot measure never prints the success shape"; exit 2; }
GATE_EXAMINED="$R_N"
if [ "$R_BAD" = 0 ] && [ "$R_LOADED" != 0 ]; then
    echo "⛔ REFUSED(2) [$GATE_NAME]: $R_LOADED wall-time excess(es) at load $R_LOAD above the ceiling $CEIL, every arm's CPU within ${BUDGET_S}s and the set's ${R_CPU}s CPU within ${TOTAL_BUDGET_S}s -- wall time cannot be judged on this box now; re-run when the load is at or under $CEIL (examined $R_N)"
    gate_stamp; exit 2
fi
gate_verdict "$R_BAD" "preflight arm(s) that are slow, red or missing (budget ${BUDGET_S}s each by CPU at any load and by wall at load <= $CEIL, examined $R_N)"
