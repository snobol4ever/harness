#!/usr/bin/env bash
# build_scrip.sh — build the scrip compiler from snobol4ever/SCRIP
# Idempotent. Safe to run multiple times.
# Usage: bash build/build_scrip.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIP="$ROOT/SCRIP"

[ -d "$SCRIP/.git" ] || { echo "FAIL clone snobol4ever/SCRIP to $SCRIP first"; exit 1; }

cd "$SCRIP" && make -j4 scrip > /tmp/build_full.log 2>&1 || { echo "BUILD FAILED — first error:"; grep -E "error:|fatal error" /tmp/build_full.log | head -5; exit 1; }
[ -x "$SCRIP/scrip" ] || { echo "FAIL scrip not found after build"; exit 1; }
echo "OK  scrip built"

# libscrip_rt.so — EVERY mode-4 (--compile) test links against it; a fresh container without it fails all
# mode-4 smokes at the gcc link step (s23 finding, same class as the s21 missing-dev-package one)
make libscrip_rt >> /tmp/build_full.log 2>&1 || { echo "BUILD FAILED (libscrip_rt) — first error:"; grep -E "error:|fatal error" /tmp/build_full.log | head -5; exit 1; }
[ -f "$SCRIP/out/libscrip_rt.so" ] || { echo "FAIL out/libscrip_rt.so not found after build"; exit 1; }
echo "OK  libscrip_rt built"

# scrip_jvm symlink (build_snobol4_jvm.sh expects scrip_jvm in $HOME)
[ -e "$HOME/scrip_jvm" ] || ln -sf "$SCRIP/scrip" "$HOME/scrip_jvm"
echo "OK  scrip: $SCRIP/scrip"
