#!/bin/bash
# build_bench.sh — build SCRIP benchmarks
set -e
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$ROOT/bench" && make
echo "Built: bench"
