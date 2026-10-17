#!/usr/bin/env bash
# build_snobol4_jvm.sh — compile + run a .sno file via scrip-cc JVM backend
# Usage: build_snobol4_jvm.sh <file.sno>
# MONITOR_FIFO env var: if set, trace events written there via JVM runtime
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -euo pipefail

SNO="${1:?Usage: build_snobol4_jvm.sh <file.sno>}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP_CC="${SCRIP_CC_JVM:-$S4E/scrip-cc_jvm}"
JASMIN="${JASMIN:-$DIR/miscellaneous/jasmin.jar}"
JVM_CACHE="${JVM_CACHE:-/tmp/scrip_cc_jvm_cache}"

mkdir -p "$JVM_CACHE"

base="$(basename "$SNO" .sno)"
dir_hash="$(echo "$SNO" | md5sum | cut -c1-8)"
key="${base}_${dir_hash}"
jfile="$JVM_CACHE/${key}.j"
stamp="$JVM_CACHE/${key}.stamp"

"$SCRIP_CC" -jvm "$SNO" > "$jfile" 2>/dev/null

# Extract classname from first .j line: ".class public <name>"
classname=$(grep '\.class' "$jfile" | head -1 | awk '{print $NF}')

j_md5="$(md5sum "$jfile" | cut -d' ' -f1)"
cached_md5="$(cat "$stamp" 2>/dev/null || echo '')"

if [[ "$j_md5" != "$cached_md5" ]] || [[ ! -f "$JVM_CACHE/${classname}.class" ]]; then
    java -jar "$JASMIN" "$jfile" -d "$JVM_CACHE" >/dev/null 2>&1
    echo "$j_md5" > "$stamp"
fi

exec java -cp "$JVM_CACHE" "$classname"
