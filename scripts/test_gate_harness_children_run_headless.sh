#!/usr/bin/env bash
# test_gate_harness_children_run_headless.sh -- EVERY CHILD THE HARNESS STARTS RUNS HEADLESS (the ceo 2026-10-23, after the coo's oracle
# re-measure opened "Hello, world" and "Click me !" windows on Lon's desktop at 11:09: rosetta-pascal's hello-world-graphical.pas and
# simple-windowed-application.pas, run by fpc_oracle_run.sh through corpus_suite_harness._run_raw, inherited the session's DISPLAY).
# corpus_suite_harness.py drops DISPLAY and WAYLAND_DISPLAY from its own environment at import, so every child it, or
# util_build_package_suite.py (which imports it), starts finds no display; lib_one_runner.sh, which every guarded runner sources first,
# unsets both for a bash runner's children. Each arm sets both variables in the parent and asks a child what it sees; the CONTROL arm
# asks a plain child, so a gate that saw nothing cannot pass. RED BEFORE THE CURE: on harness c9fd63b arms (1), (2) and (3) print
# ":99/wayland-fixture". No board, no row, no corpus.
# EXIT: 0 every arm holds · 1 an arm is red · 2 REFUSED -- cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in corpus_suite_harness.py util_build_package_suite.py lib_one_runner.sh; do [ -f "$HERE/$f" ] || { echo "GATE UNPROVEN(2): missing $HERE/$f"; exit 2; }; done
checks=0; fails=0; ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
PROBE='echo "${DISPLAY-unset}/${WAYLAND_DISPLAY-unset}"'
export DISPLAY=:99 WAYLAND_DISPLAY=wayland-fixture
echo "=== gate: every child the harness starts runs headless ==="
c="$(sh -c "$PROBE")"
[ "$c" = ":99/wayland-fixture" ] && ck ok "(0) CONTROL: a plain child sees the parent's display ($c) -- the probe can see it" || { echo "GATE UNPROVEN(2): the control child read '$c', so the probe cannot see a display"; exit 2; }
o="$(cd "$HERE" && python3 -c "
import sys; sys.path.insert(0, '.')
import corpus_suite_harness as h
k, out, err, rc = h._run_raw(['sh', '-c', '''$PROBE'''], 10)
print(out.decode().strip())" 2>&1)"
[ "$o" = "unset/unset" ] && ck ok "(1) a child of corpus_suite_harness._run_raw sees no display ($o)" || ck no "(1) corpus_suite_harness._run_raw's child reads '$o'"
o="$(cd "$HERE" && python3 -c "
import sys, subprocess; sys.path.insert(0, '.')
import util_build_package_suite
print(subprocess.run(['sh', '-c', '''$PROBE'''], capture_output=True, text=True).stdout.strip())" 2>&1)"
[ "$o" = "unset/unset" ] && ck ok "(2) a child of a process that imported util_build_package_suite sees no display ($o)" || ck no "(2) util_build_package_suite's child reads '$o'"
o="$(bash -c ". '$HERE/lib_one_runner.sh' && sh -c '$PROBE'" 2>&1)"
[ "$o" = "unset/unset" ] && ck ok "(3) a child of a bash runner that sourced lib_one_runner.sh sees no display ($o)" || ck no "(3) lib_one_runner.sh's child reads '$o'"
echo "population: 4 arms (1 control), $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [harness_children_run_headless]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [harness_children_run_headless]: $fails of $checks arms FAIL"; exit 1
