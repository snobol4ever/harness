#!/usr/bin/env bash
# test_monitor_2way_sync_step.sh — 2-way sync-step monitor (CSNOBOL4 + SPITBOL).
#
# CSNOBOL4 oracle vs SPITBOL x64 — the cross-oracle reference path.
# Useful for confirming the two oracles produce byte-identical wires
# on a given source program (any disagreement is a real semantic gap
# between the two oracles, independent of scrip).
#
# Implementation: thin wrapper around test_monitor_3way_sync_step_auto.sh
# with PARTICIPANTS="csn spl".  The auto harness uses env-var driven
# binary IPC (MONITOR_BIN=1, MONITOR_READY_PIPE, MONITOR_GO_PIPE,
# MONITOR_NAMES_OUT) — no source preprocessing, no LOAD-chain.
# Per RULES.md "Sync-step monitor — keyword catch-alls only, no source
# preprocessing".
#
# Usage:  bash test_monitor_2way_sync_step.sh <file.sno>
# Exit:   0 = both participants agreed
#         1 = divergence
#         2 = timeout / EOF on a participant / setup failure
#         3 = protocol error
#
# Requires (run once per session):
#   bash ../harness/scripts/install_system_packages.sh
#   bash ../harness/scripts/build_csnobol4_oracle.sh   # SN-26-csn-bridge applied
#   bash ../harness/scripts/build_spitbol_oracle.sh    # SN-26-spl-bridge applied
#
# Path discipline (RULES.md): every path derived from $0; no env-var
# dependencies for tool location.
set -uo pipefail

SNO=${1:?Usage: test_monitor_2way_sync_step.sh <file.sno>}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PARTICIPANTS="csn spl" exec bash "$HERE/test_monitor_3way_sync_step_auto.sh" "$SNO"
