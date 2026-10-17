#!/bin/bash
# build_silly.sh — build silly-snobol4 from SCRIP/SILLY
set -e
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$ROOT/SILLY" && make
echo "Built: /tmp/silly-snobol4"
