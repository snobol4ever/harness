#!/usr/bin/env bash
# test/crosscheck.sh — scrip crosscheck: same programs, all backends, outputs must agree
# Usage: CORPUS=/home/claude/corpus bash test/crosscheck.sh
# From:  /home/claude/SCRIP/
#
# Backends: x86 (nasm), JVM (jasmin+java), NET (ilasm+mono), WASM (wabt)
# Each backend skipped gracefully if tools not present.
# Oracle: SPITBOL x64 via $SPITBOL below -- NOTE (s255 audit): this variable is currently unused by
# any section in this file; the per-backend runners it delegates to (run_crosscheck_*_rung.sh) own
# their own oracle resolution. Left correctly S4A-fallback-formed in case a section starts using it,
# but do not assume sourcing this file gets you oracle grading -- check the delegate script.
#
# Sections:
#   1. x86  — compile .sno -> .s -> nasm -> run, diff vs .ref
#   2. JVM  — compile .sno -> .j -> jasmin -> java, diff vs .ref
#   3. NET  — compile .sno -> .il -> ilasm -> mono, diff vs .ref
#   4. WASM — compile .sno -> .wat -> wabt -> run, diff vs .ref
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/../scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
JASMIN="${JASMIN:-$ROOT/miscellaneous/jasmin.jar}"
SPITBOL="${SPITBOL:-$S4A/x64/bin/sbl}"
INC="${INC:-$CORPUS/include}"
TIMEOUT="${TIMEOUT:-15}"

PASS=0; FAIL=0; SKIP=0
FAILURES=""

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'

have() { command -v "$1" &>/dev/null; }

result() {
    local status="$1" label="$2"
    if [ "$status" = "PASS" ]; then
        PASS=$((PASS+1))
    elif [ "$status" = "SKIP" ]; then
        SKIP=$((SKIP+1))
    else
        FAIL=$((FAIL+1))
        FAILURES="${FAILURES}  FAIL ${label}\n"
    fi
}

echo "=== scrip crosscheck ==="
echo ""

# ── 1. x86 ───────────────────────────────────────────────────────────────────
echo "── x86 ──"
if ! have nasm; then
    echo -e "${YELLOW}SKIP${RESET} x86 section (nasm not found)"
    SKIP=$((SKIP+1))
else
    bash "$ROOT/../corpus/tests/scrip_test/crosscheck/run_crosscheck_x86_rung.sh" "$CORPUS/crosscheck/patterns" \
         "$CORPUS/crosscheck/assign" "$CORPUS/crosscheck/arith_new" \
         "$CORPUS/crosscheck/control_new" 2>/dev/null | tail -3
fi

# ── 2. JVM ───────────────────────────────────────────────────────────────────
echo "── JVM ──"
if ! have java || [ ! -f "$JASMIN" ]; then
    echo -e "${YELLOW}SKIP${RESET} JVM section (java or jasmin not found)"
    SKIP=$((SKIP+1))
else
    bash "$ROOT/../corpus/tests/scrip_test/crosscheck/run_crosscheck_jvm_rung.sh" "$CORPUS/crosscheck/patterns" \
         "$CORPUS/crosscheck/assign" "$CORPUS/crosscheck/arith_new" 2>/dev/null | tail -3
fi

# ── 3. NET ───────────────────────────────────────────────────────────────────
echo "── NET ──"
if ! have mono && ! have dotnet; then
    echo -e "${YELLOW}SKIP${RESET} NET section (mono/dotnet not found)"
    SKIP=$((SKIP+1))
else
    bash "$ROOT/../corpus/tests/scrip_test/crosscheck/run_crosscheck_net_rung.sh" "$CORPUS/crosscheck/patterns" \
         "$CORPUS/crosscheck/assign" 2>/dev/null | tail -3
fi

# ── 4. WASM ──────────────────────────────────────────────────────────────────
echo "── WASM ──"
if ! have wasm-interp && ! have wasmtime; then
    echo -e "${YELLOW}SKIP${RESET} WASM section (wasm runtime not found)"
    SKIP=$((SKIP+1))
else
    bash "$ROOT/../corpus/tests/scrip_test/run_wasm_corpus_rung.sh" 2>/dev/null | tail -3
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ -n "$FAILURES" ] && printf "$FAILURES" | head -40
[ $FAIL -eq 0 ]
