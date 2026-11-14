#!/bin/bash
# build_silly.sh — build silly-snobol4 from SCRIP/SILLY
set -e
. "$(dirname "$0")/lib_paths.sh"
ROOT="$(cd "$S4E_SCRIP" && pwd)"
cd "$ROOT/SILLY" && make
echo "Built: /tmp/silly-snobol4"
