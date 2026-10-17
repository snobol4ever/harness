#!/usr/bin/env bash
# install_everything_full_stack.sh — full environment setup for a snobol4ever/SCRIP session
#
# One-shot full install: packages, scrip, oracles, smoke gate.
# Do NOT run this for a specific goal session — run only the scripts listed
# in the Goal file's ## Session Setup section instead.
#
# Usage: bash /home/claude/harness/scripts/install_everything_full_stack.sh
# Idempotent. Safe to run multiple times.
set -euo pipefail

SCRIP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
ROOT="$(cd "$SCRIP/.." && pwd)"

echo "=== snobol4ever session setup ==="
echo "ROOT:    $ROOT"
echo "SCRIP: $SCRIP"

# ── 1. git identity ───────────────────────────────────────────────────────────
git config --global user.name  "LCherryholmes"
git config --global user.email "lcherryh@yahoo.com"
for repo in SCRIP .github; do
    [ -d "$ROOT/$repo/.git" ] && git -C "$ROOT/$repo" config user.name  "LCherryholmes"
    [ -d "$ROOT/$repo/.git" ] && git -C "$ROOT/$repo" config user.email "lcherryh@yahoo.com"
done
echo "OK  git identity: LCherryholmes <lcherryh@yahoo.com>"

# ── 2. system packages (includes bison + flex) ────────────────────────────────
bash "$harness/scripts/install_system_packages.sh"

# ── 3. scrip ─────────────────────────────────────────────────────────────────
bash "$harness/scripts/build_scrip.sh"

# ── 4. SPITBOL x64 oracle ────────────────────────────────────────────────────
if [ -d "$ROOT/x64/.git" ]; then
    bash "$harness/scripts/build_spitbol_oracle.sh"
else
    echo "SKIP spitbol (x64 not cloned — clone snobol4ever/x64 to $ROOT/x64)"
fi

# ── 5. CSNOBOL4 oracle ───────────────────────────────────────────────────────
if [ -d "$ROOT/csnobol4/.git" ]; then
    bash "$harness/scripts/build_csnobol4_oracle.sh"
else
    echo "SKIP csnobol4 (not cloned — clone snobol4ever/csnobol4 to $ROOT/csnobol4)"
fi

# ── 6. smoke gate ────────────────────────────────────────────────────────────
echo "--- smoke gate ---"
cd "$SCRIP" && bash "$harness/scripts/test_smoke_scrip_all_modes.sh"
echo "=== setup complete ==="
