#!/usr/bin/env bash
# test_gate_icn_scan_find_and_match_carry_a_literals_length.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. The scanning find() and match() boxes (bb_scan_find.cpp, bb_scan_match.cpp) took a literal needle's length
# from strlen() on its C string, although the lowerer attaches the literal's true length as its IR_LIT_INTEGER operand
# (lower_icon.c icn_attach_lit_len). So a literal carrying a NUL was cut at it -- find("a\x00") found "a", match("ab\x00")
# answered 3 where iconx answers 4 -- and a NUL-FIRST literal measured 0 and fell into find's "unhandled" branch, which
# emitted an alpha and a bomb but NO beta: `every find("\x00")` aborted m3 at emit time with an unresolved forward
# reference to its beta label. The same branch took find("") and every literal needle longer than 32 bytes, so any Icon
# program scanning for either crashed the compiler in m3. The variable-needle path measured the needle with strlen() too,
# although rt_scan_needle hands the carried length back in rdx.
#
# WHAT IS HERE. The emit case reads the literal's true length from its length operand into op_ival and both templates unroll,
# compare and emit their data (.string with its length) over it; find takes the literal path only for 1..32 true bytes and
# otherwise its general path, which now stores rt_scan_needle's rdx instead of calling strlen; both unhandled branches
# define their beta so a refusal can never leave a dangling label.
#
# ARM. Fifteen witnesses (eight needles for find under `every`, seven patterns for match) over a subject that carries NULs,
# graded against the LIVE oracle (icont/iconx 9.5.25a) in both media, byte for byte. A witness the oracle does not run
# refuses the gate rather than passing it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
LONG="$(printf 'q%.0s' $(seq 1 40))"
i=0; res=""; bad=0
for kind in find match; do
  for needle in '"\x00"' '"a\x00"' '"\x00a"' '""' "\"$LONG\"" '"ab"' 'n' '"ab\x00aq"'; do
    [ "$kind" = match ] && [ "$needle" = '"\x00a"' ] && continue
    i=$((i+1)); w="$T/w$i.icn"
    if [ "$kind" = find ]; then
      printf 'procedure main()\n   local x, s, n;\n   n := "\\x00" || "a";\n   s := "ab\\x00a" || repl("q", 45);\n   s ? every x := find(%s) do writes(x, " ");\n   write();\nend\n' "$needle" > "$w"
    else
      printf 'procedure main()\n   local s, n;\n   n := "ab" || "\\x00";\n   s := "ab\\x00a" || repl("q", 45);\n   s ? write(image(match(%s)) | "fails");\n   s ? { move(4); write(image(match("q")) | "fails2") };\nend\n' "$needle" > "$w"
    fi
    ( cd "$T" && "$ICONT" -s -o "w$i.x" "w$i.icn" ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses witness w$i ($kind $needle)"; exit 2; }
    want="$( cd "$T" && timeout -k 5 20 "./w$i.x" </dev/null 2>/dev/null )" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run witness w$i"; exit 2; }
    o3="$( cd "$T" && timeout -k 5 20 "$SCRIP" "w$i.icn" </dev/null 2>&1 )"
    o4=""; ( cd "$T" && "$SCRIP" --compile -o "w$i.s" "w$i.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "w$i.4" "w$i.s" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
      && o4="$( cd "$T" && timeout -k 5 20 "./w$i.4" </dev/null 2>&1 )"
    tag="$kind(${needle:0:10})"
    if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then res="$res $tag:ok"; else res="$res $tag:RED[m3=$(printf '%s' "$o3" | head -c 50 | tr '\n' '|') m4=$(printf '%s' "$o4" | head -c 50 | tr '\n' '|') iconx=$(printf '%s' "$want" | tr '\n' '|')]"; bad=1; fi
  done
done
echo "  HOLDS: scanning find() and match() carry a literal's true length -- a NUL in it, an empty one or one over 32 bytes -- in both media, as iconx does"
if [ "$bad" = 0 ]; then echo "  arm 1 PASS: $i witnesses match the live oracle in both media --$res"; echo "✅ GATE PASS [$G]"; exit 0; fi
echo "  arm 1 FAIL:$res"; echo "⛔ GATE FAIL [$G]"; exit 1
