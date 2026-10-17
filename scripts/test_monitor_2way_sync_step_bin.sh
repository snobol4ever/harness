#!/usr/bin/env bash
# test_monitor_2way_sync_step_bin.sh — 2-way binary sync-step monitor.
#
# Identical to test_monitor_2way_sync_step.sh — both run CSNOBOL4 (oracle)
# vs SPITBOL x64 over the auto-mode binary protocol.  Kept as a separate
# entry point because some callers historically distinguished "2way"
# (text protocol) from "2way-bin" (binary protocol).  After
# SN-26-harness-rewrite, both protocols converged on binary; the two
# names alias to the same harness.
#
# Usage:  bash test_monitor_2way_sync_step_bin.sh <file.sno>
# Exit:   same as test_monitor_3way_sync_step_auto.sh.
set -uo pipefail

SNO=${1:?Usage: test_monitor_2way_sync_step_bin.sh <file.sno>}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PARTICIPANTS="csn spl" exec bash "$HERE/test_monitor_3way_sync_step_auto.sh" "$SNO"
