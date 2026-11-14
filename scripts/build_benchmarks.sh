#!/bin/bash
# build_bench.sh — build SCRIP benchmarks
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib_paths.sh"
ROOT="$(cd "$S4E_SCRIP" && pwd)"
cd "$ROOT/bench" && make
echo "Built: bench"
