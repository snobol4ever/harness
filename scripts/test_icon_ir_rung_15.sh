#!/bin/bash
# ../harness/scripts/test_icon_ir_rung_15.sh — IC-5 gate: real output, swap, lconcat
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/scrip}"
CORPUS="$S4E/corpus/tests/icon"
if [ ! -f "$SCRIP" ]; then echo "SKIP scrip not found"; exit 0; fi
if [ ! -d "$CORPUS" ]; then echo "SKIP corpus not found"; exit 0; fi
pass=0; fail=0
for icn in "$CORPUS"/rung15_*.icn; do
    name=$(basename "${icn%.icn}")
    exp=$(cat "${icn%.icn}.ref" 2>/dev/null)
    got=$(timeout -k 5 8 "$SCRIP" --run "$icn" < /dev/null 2>/dev/null)
    if [ "$got" = "$exp" ]; then echo "  PASS $name"; pass=$((pass+1))
    else echo "  FAIL $name"; echo "    exp: $exp"; echo "    got: $got"; fail=$((fail+1)); fi
done
echo ""; echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
