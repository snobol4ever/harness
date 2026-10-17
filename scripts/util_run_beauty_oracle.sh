#!/usr/bin/env bash
# util_run_beauty_oracle.sh — run SPITBOL oracle on beauty.sno for a given input.
#
# -INCLUDE files resolve from corpus/include (the canonical SNOBOL4 include home).
# Outputs beautified SNOBOL4 to stdout.
#
# Usage:
#   bash ../harness/scripts/util_run_beauty_oracle.sh [OPTIONS]
#
# Options:
#   --input  FILE   SNOBOL4 source to beautify (required, or use stdin with -)
#   --beauty PATH   path to beauty.sno (default: corpus/demos/snobol4/beauty/beauty.sno)
#   --corpus PATH   path to corpus root (default: /home/claude/corpus)
#   --oracle PATH   path to sbl binary (default: /home/claude/x64/bin/sbl)
#   --timeout N     seconds (default: 30)
#   --output FILE   write ref output to FILE instead of stdout
#
# Exit codes:
#   0  oracle ran successfully
#   1  oracle not found (SKIP)
#   2  oracle error
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT_FILE=""
CORPUS="${CORPUS:-$S4E/corpus}"
ORACLE="${ORACLE:-$S4A/x64/bin/sbl}"
BEAUTY_SRC=""
TIMEOUT=30
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)   INPUT_FILE="$2";  shift 2 ;;
        --beauty)  BEAUTY_SRC="$2";  shift 2 ;;
        --corpus)  CORPUS="$2";      shift 2 ;;
        --oracle)  ORACLE="$2";      shift 2 ;;
        --timeout) TIMEOUT="$2";     shift 2 ;;
        --output)  OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

[[ -z "$BEAUTY_SRC" ]] && BEAUTY_SRC="$CORPUS/beauty/beauty.sno"
BEAUTY_INC="$CORPUS/include"

if [[ ! -x "$ORACLE" ]]; then
    echo "SKIP oracle not found: $ORACLE" >&2; exit 1
fi
if [[ ! -f "$BEAUTY_SRC" ]]; then
    echo "SKIP beauty.sno not found: $BEAUTY_SRC" >&2; exit 1
fi
if [[ ! -d "$BEAUTY_INC" ]]; then
    echo "SKIP beauty include dir not found: $BEAUTY_INC" >&2; exit 1
fi

run_oracle() {
    # Must cd to the include dir so -INCLUDE 'global.inc' etc. resolve.
    # -bf: -b suppress banner, -f case-sensitive (per RULES.md SN-30, SETL4PATH).
    (cd "$BEAUTY_INC" && SETL4PATH=. timeout -k 5 "$TIMEOUT" "$ORACLE" -bf "$BEAUTY_SRC")
}

if [[ -z "$INPUT_FILE" || "$INPUT_FILE" == "-" ]]; then
    # read from stdin
    if [[ -n "$OUTPUT_FILE" ]]; then
        run_oracle < /dev/stdin > "$OUTPUT_FILE"
    else
        run_oracle < /dev/stdin
    fi
elif [[ -f "$INPUT_FILE" ]]; then
    if [[ -n "$OUTPUT_FILE" ]]; then
        run_oracle < "$INPUT_FILE" > "$OUTPUT_FILE"
    else
        run_oracle < "$INPUT_FILE"
    fi
else
    echo "FAIL input not found: $INPUT_FILE" >&2; exit 2
fi
