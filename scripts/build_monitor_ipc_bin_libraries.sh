#!/usr/bin/env bash
# build_monitor_ipc_bin_libraries.sh
#
# Builds the binary-protocol sync-step monitor IPC .so modules for both
# the CSNOBOL4 and SPITBOL x64 ABIs.  Idempotent: skip rebuild if .so
# is newer than its .c source AND its monitor_wire.h dependency.
#
# Outputs:
#   harness/scripts/monitor/monitor_ipc_bin_csn.so   — CSNOBOL4 LOAD()able
#   x64/monitor_ipc_bin_spl.so                       — SPITBOL LOAD()able
#
# Per RULES.md:
#   - paths derived from $0
#   - idempotent (check timestamps)
#   - hardcoded oracle locations w/ SKIP if missing
#   - no symlinks
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MON_DIR="${HERE}/monitor"
WIRE_HDR="${MON_DIR}/monitor_wire.h"

[ -f "${WIRE_HDR}" ] || { echo "FAIL  missing ${WIRE_HDR}"; exit 1; }

# --- CSNOBOL4 ABI ---------------------------------------------------------
CSN_SRC="${MON_DIR}/monitor_ipc_bin_csn.c"
CSN_SO="${MON_DIR}/monitor_ipc_bin_csn.so"

if [ ! -f "${CSN_SRC}" ]; then
    echo "FAIL  missing ${CSN_SRC}"
    exit 1
fi

if [ -f "${CSN_SO}" ] \
    && [ "${CSN_SO}" -nt "${CSN_SRC}" ] \
    && [ "${CSN_SO}" -nt "${WIRE_HDR}" ]; then
    echo "SKIP  ${CSN_SO} up to date"
else
    gcc -shared -fPIC -O2 -Wall \
        -o "${CSN_SO}" "${CSN_SRC}"
    echo "OK    built ${CSN_SO}"
fi

# --- SPITBOL x64 ABI ------------------------------------------------------
SPL_DIR="$S4A/x64"
SPL_SRC="${SPL_DIR}/monitor_ipc_bin_spl.c"
SPL_SO="${SPL_DIR}/monitor_ipc_bin_spl.so"

if [ ! -d "${SPL_DIR}" ]; then
    echo "SKIP  ${SPL_DIR} missing — clone snobol4ever/x64 to build SPITBOL .so"
    exit 0
fi

if [ ! -f "${SPL_SRC}" ]; then
    echo "FAIL  missing ${SPL_SRC} — should be in x64/ checkout"
    exit 1
fi

if [ -f "${SPL_SO}" ] \
    && [ "${SPL_SO}" -nt "${SPL_SRC}" ] \
    && [ "${SPL_SO}" -nt "${WIRE_HDR}" ]; then
    echo "SKIP  ${SPL_SO} up to date"
else
    gcc -shared -fPIC -O2 -Wall \
        -I"${MON_DIR}" \
        -o "${SPL_SO}" "${SPL_SRC}"
    echo "OK    built ${SPL_SO}"
fi

echo "OK    monitor IPC binary libraries ready"
