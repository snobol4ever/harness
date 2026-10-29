#!/usr/bin/env bash
# harness/adapters/tiny_net/run.sh
# Run a .sno file through TINY NET (one4all -net) engine and emit stdout only.
#
# Usage: run.sh <file.sno> [< input]
# Calling convention: stdin → program stdin, stdout → program output.
#
# Pipeline: scrip-cc -net → ilasm → mono
#
# CACHING: ilasm is slow (~350ms). We cache the .exe by md5 of the .il so
# repeat runs of unchanged programs skip ilasm entirely.
#
# Requires: one4all built (scrip-cc binary), ilasm, mono.
# Env overrides:
#   TINY_REPO  — path to one4all checkout  (default: $HOME/one4all)
#   NET_CACHE  — cache dir for .il/.exe      (default: /tmp/one4all_net_cache)

set -uo pipefail

SNO_FILE="${1:-}"
[ -z "$SNO_FILE" ] && { echo "Usage: run.sh <file.sno>" >&2; exit 2; }

TINY_REPO="${TINY_REPO:-$HOME/one4all}"
SCRIP_CC="$TINY_REPO/scrip-cc"
NET_CACHE="${NET_CACHE:-/tmp/one4all_net_cache}"

# Validate toolchain
if [[ ! -x "$SCRIP_CC" ]]; then
    echo "SKIP: scrip-cc not found at $SCRIP_CC" >&2; exit 2
fi
if ! command -v ilasm >/dev/null 2>&1; then
    echo "SKIP: ilasm not found" >&2; exit 2
fi
if ! command -v mono >/dev/null 2>&1; then
    echo "SKIP: mono not found" >&2; exit 2
fi

mkdir -p "$NET_CACHE"

# Copy runtime DLLs into cache dir so mono finds them alongside .exe files
RUNTIME_NET="$TINY_REPO/src/runtime/net"
for dll in snobol4lib.dll snobol4run.dll; do
    src="$RUNTIME_NET/$dll"
    dst="$NET_CACHE/$dll"
    if [[ -f "$src" ]] && { [[ ! -f "$dst" ]] || ! diff -q "$src" "$dst" >/dev/null 2>&1; }; then
        cp "$src" "$dst"
    fi
done

# Derive a stable cache key from the canonical path
base="$(basename "$SNO_FILE" .sno)"
dir_hash="$(echo "$SNO_FILE" | md5sum | cut -c1-8)"
key="${base}_${dir_hash}"
il="$NET_CACHE/${key}.il"
exe="$NET_CACHE/${key}.exe"
stamp="$NET_CACHE/${key}.stamp"

# Emit .il (fast — ~1ms)
"$SCRIP_CC" -net --out="$il" "$SNO_FILE" 2>/dev/null

# Assemble .exe only if .il changed (slow — ~350ms)
il_md5="$(md5sum "$il" | cut -d' ' -f1)"
cached_md5="$(cat "$stamp" 2>/dev/null || echo '')"

if [[ "$il_md5" != "$cached_md5" ]] || [[ ! -f "$exe" ]]; then
    ilasm "$il" /output:"$exe" >/dev/null 2>&1
    echo "$il_md5" > "$stamp"
fi

# Run — stdin forwarded, stdout is program output
exec mono "$exe"
