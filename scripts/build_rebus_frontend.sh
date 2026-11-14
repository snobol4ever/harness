#!/bin/bash
# build_rebus.sh — build rebus frontend
set -e
. "$(dirname "${BASH_SOURCE[0]}")/lib_paths.sh"
ROOT="$S4E_SCRIP"
cd "$ROOT/src/parsers/rebus" && make
echo "Built: rebus"
