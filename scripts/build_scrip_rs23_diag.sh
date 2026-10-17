#!/usr/bin/env bash
# build_scrip_rs23_diag.sh — RS-23 diagnostic build of scrip.
#
# Compiles + links scrip with src/driver/rs23_diag.c included and
# -Wl,--wrap=eval_ast so every eval_ast call routes through
# __wrap_eval_ast first.  The wrap logs any call whose stack
# contains a BB-adapter ancestor (bb_eval_value / bb_exec_stmt /
# coro_call / coro_eval / coro_drive).
#
# Output: a binary at $(ROOT)/scrip-rs23-diag.  When run, it emits
# RS23DIAG: lines on stderr.  Run gates with this binary, then
# aggregate the unique (kind, caller, via) tuples.
#
# This is a diagnostic — never commit a build using this binary.
# Run from SCRIP/.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"

# Run the normal build first to populate /tmp/si_objs with .o files.
make -j4 scrip 2>&1 | tail -3

OBJ="/tmp/si_objs$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd | tr '/' '-')"  # mirrors Makefile OBJ (per-tree, s150)
SRC="$ROOT/src"

# Compile the diag wrapper itself, with RS23_DIAG defined and the same
# include path the rest of the driver uses.
gcc -O0 -g -w \
    -DRS23_DIAG \
    -I"$SRC" -I"$SRC/runtime/x86" -I"$SRC/runtime" \
    -I"$SRC/parser/snobol4" \
    -DIR_DEFINE_NAMES \
    -c "$SRC/driver/rs23_diag.c" -o "$OBJ/rs23_diag.o"

# Relink the existing objs + the wrapper with --wrap=eval_ast.
gcc -m64 -no-pie -rdynamic \
    -Wl,--wrap=eval_ast \
    "$OBJ"/*.o \
    -lm \
    -o "$ROOT/scrip-rs23-diag"

[ -x "$ROOT/scrip-rs23-diag" ] || { echo "FAIL build"; exit 1; }
echo "OK  scrip-rs23-diag built — run with stderr to a log file to capture RS23DIAG: lines"
