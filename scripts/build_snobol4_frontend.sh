#!/bin/bash
# build_snobol4_frontend.sh — build snobol4 frontend
set -e
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$ROOT/src/parsers/snobol4" && make
echo "Built: snobol4 frontend"
