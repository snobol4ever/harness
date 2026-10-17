#!/usr/bin/env bash
# util_gc_dead_oracle.sh — deterministic dead-function oracle for the scrip binary.
#
# Method: recompile every translation unit with -ffunction-sections -fdata-sections
# (injected through the Makefile WARN hook, which is concatenated into CBASE/CRT/CXXRT
# but NOT into the link line), then re-link scrip from the section-split objects with
# -Wl,--gc-sections -Wl,--print-gc-sections. The linker proves, from the static call
# graph rooted at main + every address-taken symbol, which .text.<fn> sections are
# unreachable and strips them. Each stripped section is a provably-dead function.
#
# Output: /tmp/dead_current.txt — one bare function name per line, sorted unique.
# This is the ground-truth list the dead-code sweep consumes. Re-run after every
# removal batch to regenerate the authoritative remaining set.
#
# Caveats the consumer MUST honour (NOT decided here):
#   * Backend KEEP policy: js_/jvm_/net_/wasm_ symbols are dead under X86-ONLY but
#     are RETAINED. Filter them before refuse.
#   * Symbols reached only by dynamic by-name lookup (dlsym) would be false-positives;
#     scrip resolves its own runtime by baked address (the emitter takes &rt_*, which
#     the linker sees), so this class is empty for the scrip binary — but verify if the
#     resolution mechanism ever changes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
cd "$ROOT"
OBJ="/tmp/si_objs$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd | tr '/' '-')"  # mirrors Makefile OBJ (per-tree, s150)
OUT=/tmp/dead_current.txt

echo "[oracle] recompiling all TUs with section splitting ..."
make -j4 scrip WARN="-w -ffunction-sections -fdata-sections" > /tmp/oracle_build.log 2>&1 || {
  echo "[oracle] FAIL section build — first error:"; grep -E "error:|fatal error" /tmp/oracle_build.log | head -5; exit 1; }

echo "[oracle] re-linking with --gc-sections --print-gc-sections ..."
g++ -m64 -no-pie "$OBJ"/*.o -lm \
    -Wl,--gc-sections -Wl,--print-gc-sections -o /tmp/scrip_gc 2> /tmp/oracle_gc_raw.txt || {
  echo "[oracle] FAIL gc-link"; tail -5 /tmp/oracle_gc_raw.txt; exit 1; }

# Parse "removing unused section '.text.<fn>'" → <fn>. Also catch .text.unlikely. variants.
grep -oE "\.text(\.unlikely)?\.[A-Za-z_][A-Za-z0-9_]*'" /tmp/oracle_gc_raw.txt \
  | sed -E "s/\.text(\.unlikely)?\.//; s/'//" | sort -u > "$OUT"

echo "[oracle] dead functions: $(wc -l < "$OUT")  →  $OUT"
echo "[oracle] backend-KEEP among them (NOT removable):"
grep -cE '^(js_|jvm_|net_|wasm_)' "$OUT" || true
