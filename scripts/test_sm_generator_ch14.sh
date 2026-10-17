#!/usr/bin/env bash
# test_sm_generator_ch14.sh — CHUNKS-step14 gate
#
# Compiles sm_interp_test.c against the full set of scrip object files
# (already built in /tmp/si_objs by build_scrip.sh), then runs it.
# The test includes test_generator_suspend_resume which drives a hand-built
# SM program via bb_broker_drive_sm and verifies 3 values are yielded in order.
#
# Prerequisite: build_scrip.sh must have run (populates /tmp/si_objs/*.o).
# Exit 0 = PASS, Exit 1 = FAIL.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../../SCRIP"
SRC="$ROOT/src/runtime/x86"
OBJ_DIR="/tmp/si_objs$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd | tr '/' '-')"  # mirrors Makefile OBJ (per-tree, s150)
BUILD_DIR="/tmp/ch14_test"

mkdir -p "$BUILD_DIR"

if [ ! -d "$OBJ_DIR" ] || [ -z "$(ls "$OBJ_DIR"/*.o 2>/dev/null)" ]; then
    echo "SKIP  CH-14 gate: $OBJ_DIR missing — run build_scrip.sh first"
    exit 0
fi

echo "=== CH-14 gate: building sm_interp_test against full scrip objects ==="

# Compile test translation unit
gcc -O0 -g \
    -I"$SRC" \
    -I"$ROOT/src" \
    -I"$ROOT/src/runtime" \
    -I"$ROOT/src/runtime/x86" \
    -DFULL_RUNTIME_LINKED \
    -w \
    -c "$SRC/sm_interp_test.c" \
    -o "$BUILD_DIR/sm_interp_test.o" 2>&1

# Link: all scrip objects EXCEPT the main driver (scrip_driver.o has main()),
# plus our test object.
OBJS=$(ls "$OBJ_DIR"/*.o | grep -v scrip_driver.o | tr '\n' ' ')

gcc -m64 -no-pie \
    "$BUILD_DIR/sm_interp_test.o" \
    $OBJS \
    -lm \
    -o "$BUILD_DIR/sm_interp_test" 2>&1

echo "=== Running sm_interp_test ==="
"$BUILD_DIR/sm_interp_test"
RC=$?

if [ $RC -eq 0 ]; then
    echo ""
    echo "PASS  CH-14 generator gate"
    exit 0
else
    echo ""
    echo "FAIL  CH-14 generator gate (exit $RC)"
    exit 1
fi
