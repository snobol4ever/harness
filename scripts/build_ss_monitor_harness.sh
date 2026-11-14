#!/bin/bash
# build_ss_monitor.sh — build ss-monitor test harness
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib_paths.sh"; ROOT="$(cd "$S4E_SCRIP" && pwd)"
cd "$S4E_HARNESS/scripts/ss_monitor" && make
echo "Built: ss-monitor"
