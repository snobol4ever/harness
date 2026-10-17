#!/usr/bin/env bash
# util_bb_graph.sh — render a program's Byrd-box graph as one self-contained HTML file
# Usage: bash ../harness/scripts/util_bb_graph.sh prog.sno [out.html]
# Runs `scrip --dump-bb`, injects the JSON into tools/bb_viewer.html's
# <script id="bb-data"> slot, and writes a standalone viewer beside the source
# (default <prog>.bb.html). Open it in any browser; no server, no install.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SRC="${1:?usage: util_bb_graph.sh prog.src [out.html]}"
OUT="${2:-${SRC%.*}.bb.html}"
[ -x "$ROOT/scrip" ] || { echo "FAIL build scrip first (../harness/scripts/build_scrip.sh)"; exit 1; }
TMP="$(mktemp)"
"$ROOT/scrip" --dump-bb "$SRC" < /dev/null > "$TMP"
python3 - "$ROOT/tools/bb_viewer.html" "$TMP" "$OUT" << 'PY'
import sys
tpl = open(sys.argv[1]).read()
data = open(sys.argv[2]).read().strip().replace("</", "<\\/")
marker = '<script id="bb-data" type="application/json">'
out = tpl.replace(marker + "</script>", marker + "\n" + data + "\n</script>", 1)
assert out != tpl, "injection marker not found in bb_viewer.html"
open(sys.argv[3], "w").write(out)
PY
rm -f "$TMP"
echo "OK  $OUT"
