#!/bin/bash
# build_ss_monitor.sh — build ss-monitor test harness
set -e
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$ROOT/../corpus/tests/scrip_test/ss-monitor" && make
echo "Built: ss-monitor"
