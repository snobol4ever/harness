#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "REFUSED(2): python3 is not installed"; exit 2; }
command -v nm >/dev/null 2>&1 || { echo "REFUSED(2): nm is not installed"; exit 2; }
python3 "$ROOT/../harness/scripts/util_rtx_twin_table_check.py"
rc=$?
[ "$rc" -eq 0 ] && echo "GATE PASS [rtx_declining_leaves_are_exactly_the_twin_table]: every asm leaf that declines is a row of rtx_twin_table.inc of its kind, every row is a leaf that declines, and both the leaf and its twin are defined by the runtime"
exit "$rc"
