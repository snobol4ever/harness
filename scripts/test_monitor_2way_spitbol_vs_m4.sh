#!/usr/bin/env bash
# test_monitor_2way_spitbol_vs_m4.sh — SPITBOL x64 (oracle) vs scrip MODE 4 (--compile --monitor, baked taps).
# s196 (Lon: m4 in the 2-way monitor configuration outranks m3).  Sibling of test_monitor_2way_spitbol_vs_run.sh.
set -uo pipefail
SNO=${1:?Usage: test_monitor_2way_spitbol_vs_m4.sh <file.sno>}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARTICIPANTS="spl scr" SCRIP_RUN_FLAG=--m4 \
    exec bash "$HERE/test_monitor_3way_sync_step_auto.sh" "$SNO"
