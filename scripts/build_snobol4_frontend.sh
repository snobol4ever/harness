#!/bin/bash
# build_snobol4_frontend.sh — build snobol4 frontend
set -e
. "$(dirname "$0")/lib_paths.sh"
ROOT="$S4E_SCRIP"
cd "$ROOT/src/parsers/snobol4" && make
echo "Built: snobol4 frontend"
